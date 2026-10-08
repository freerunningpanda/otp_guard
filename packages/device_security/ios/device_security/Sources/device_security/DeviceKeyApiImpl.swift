import CryptoKit
import Flutter
import LocalAuthentication
import Security

// The keys of the device, kept in the Secure Enclave: the private key never leaves it. The
// Pigeon-generated DeviceKeyApi is the contract with Dart: Dart calls a method of it, and the
// generated code runs the method below and sends the result back. A thrown PigeonError reaches
// Dart as a PlatformException with the same code and message.
//
// A SecKey is not the key itself but a reference to it. For a key in the Secure Enclave the
// private bytes cannot be read at all: the app can only ask the chip to use the key.
//
// The class keeps no state of its own, so it may be used from any thread. That is why it can be
// declared Sendable, which the background queue of `sign` needs.
final class DeviceKeyApiImpl: DeviceKeyApi, @unchecked Sendable {
  // The start of a DER-encoded SubjectPublicKeyInfo (X.509) for a P-256 key. The 65 bytes of the
  // public key itself follow it, which makes 91 bytes in total. Byte by byte:
  private static let p256PublicKeyHeader: [UInt8] = [
    0x30, 0x59,  // SEQUENCE, 89 bytes follow
    0x30, 0x13,  //   SEQUENCE, 19 bytes: the algorithm
    0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01,  //     OID id-ecPublicKey
    0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07,  //     OID prime256v1 (P-256)
    0x03, 0x42, 0x00,  //   BIT STRING, 66 bytes: 0 unused bits, then the 65-byte key
  ]

  // True when the device has a passcode set (or biometrics): the user can be asked to prove they
  // own the device. Without a passcode there is nothing to protect the keys with.
  func isDeviceSecure() throws -> Bool {
    return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
  }

  // Returns the public key as X.509 SubjectPublicKeyInfo in DER, the same format as on Android.
  // The system gives only the raw point (X9.63, 65 bytes), so the header is put in front of it.
  func generateKey(alias: String) throws -> FlutterStandardTypedData {
    // The simulator and devices without the chip have none: report it instead of creating a
    // software key, which would not be what the app asks for.
    guard SecureEnclave.isAvailable else {
      throw PigeonError(
        code: "UNAVAILABLE",
        message: "The Secure Enclave is not available on this device",
        details: nil
      )
    }
    // The key requires biometrics for every use. Without enrolled biometrics it could be made
    // but never used, so say so now.
    try requireBiometrics()
    // A second key with the same tag would silently be a different key than the server knows.
    if try hasKey(alias: alias) {
      throw PigeonError(
        code: "KEY_EXISTS",
        message: "A key with the alias '\(alias)' already exists",
        details: nil
      )
    }

    // Many Security functions report a failure through an out-parameter instead of throwing:
    // on failure they return nil and put the reason into `error` (passed as `&error`).
    var error: Unmanaged<CFError>?

    // When the key may be used. "WhenUnlockedThisDeviceOnly": only while the device is unlocked,
    // and the key never leaves this device (no backup, no iCloud). ".privateKeyUsage": the key
    // may be used for private-key operations, that is for signing. ".biometryCurrentSet": only
    // after Face ID or Touch ID succeeds, and only for the fingerprints or faces enrolled right
    // now: when one is added or removed, the key stops working for good. The chip enforces this,
    // not this code, so there is no check in the app to bypass.
    guard let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      [.privateKeyUsage, .biometryCurrentSet],
      &error
    ) else {
      throw generationError(error)
    }

    // What to create: an elliptic-curve key of 256 bits (P-256), generated inside the Secure
    // Enclave. The private part is stored permanently (in the keychain, as a reference) under the
    // alias, which is saved as the "application tag": the key is found by it later.
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag(alias),
        kSecAttrAccessControl as String: access,
      ],
    ]

    // Create the key (a reference to the private key comes back). If this fails, nothing was
    // stored, and `error` holds the reason.
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      throw generationError(error)
    }

    // From here on the key is already stored in the keychain. If anything below fails, the call
    // fails, but the key would stay, and the next call would answer KEY_EXISTS for a key that no
    // caller ever received. So it is deleted unless the call succeeds. (Best effort: a failed
    // delete cannot be reported better than the error that brought us here.)
    var succeeded = false
    defer {
      if !succeeded {
        SecItemDelete(query(alias) as CFDictionary)
      }
    }

    // Take the public part of the key and ask for it as bytes. Either step may fail.
    guard let publicKey = SecKeyCopyPublicKey(privateKey),
          let point = SecKeyCopyExternalRepresentation(publicKey, &error) as Data?
    else {
      throw generationError(error)
    }

    // The public key must be an uncompressed point: 0x04, then X and Y of 32 bytes each. The
    // header below is valid only for that.
    guard point.count == 65, point.first == 0x04 else {
      throw PigeonError(
        code: "KEY_GENERATION_FAILED",
        message: "The public key is not an uncompressed P-256 point",
        details: nil
      )
    }
    // Remember that this plugin made a key under the alias: if the system later removes it, that
    // tells "the biometrics changed" apart from "there never was a key". See missingKeyError.
    setMarker(alias)
    succeeded = true
    return FlutterStandardTypedData(bytes: Data(Self.p256PublicKeyHeader) + point)
  }

  // Looks the key up in the keychain by its tag. Only whether it exists matters, so no data is
  // requested (the second argument is nil).
  func hasKey(alias: String) throws -> Bool {
    let status = SecItemCopyMatching(query(alias) as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      return false
    default:
      throw keyStoreError(status)
    }
  }

  // Removes the key reference from the keychain, which also destroys the key in the Secure
  // Enclave. A missing key is not an error: the end result is the same.
  func deleteKey(alias: String) throws {
    let status = SecItemDelete(query(alias) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw keyStoreError(status)
    }
    clearMarker(alias)
  }

  // Asks the Secure Enclave for a signature of the challenge: ECDSA over its SHA-256, in DER,
  // the same format as on Android. The chip lets the key be used only after Face ID or Touch ID
  // succeeds, and the system shows that prompt by itself during SecKeyCreateSignature.
  //
  // That call blocks until the user answers, which can take any time, so it must not run on the
  // main thread or on a thread of the async pool. It runs on its own background queue, and this
  // function resumes when it is done.
  //
  // The texts of the prompt come from the app: a title, an optional subtitle and the label of
  // the cancel button. The plugin has no texts of its own, so the app can translate them and
  // word them for its scenario. Face ID shows no text of its own beyond the system's.
  func sign(
    alias: String,
    challenge: FlutterStandardTypedData,
    title: String,
    subtitle: String?,
    cancelText: String
  ) async throws -> FlutterStandardTypedData {
    // The same rule as on Android, where the prompt refuses an empty title or cancel button.
    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || cancelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      throw PigeonError(
        code: "INVALID_ARGUMENT",
        message: "title and cancelText must not be empty",
        details: nil
      )
    }
    let data = challenge.data
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let signature = try self.signBlocking(
            alias: alias,
            challenge: data,
            reason: subtitle ?? title,
            cancelText: cancelText
          )
          continuation.resume(returning: FlutterStandardTypedData(bytes: signature))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func signBlocking(
    alias: String,
    challenge: Data,
    reason: String,
    cancelText: String
  ) throws -> Data {
    // The context carries the texts of the prompt: the reason that the system shows, and the
    // label of the cancel button. (Face ID shows the text of NSFaceIDUsageDescription from the
    // Info.plist of the app the first time instead.)
    let context = LAContext()
    context.localizedReason = reason
    context.localizedCancelTitle = cancelText

    // Find the key again, this time asking for the reference to it, not just for its existence.
    // Finding it does not show the prompt: that happens when the key is used.
    var lookup = query(alias)
    lookup[kSecReturnRef as String] = true
    lookup[kSecUseAuthenticationContext as String] = context
    var item: CFTypeRef?
    let status = SecItemCopyMatching(lookup as CFDictionary, &item)
    guard status == errSecSuccess, let key = item else {
      throw missingKeyError(alias: alias, status: status)
    }
    let privateKey = key as! SecKey

    // The signature. The prompt is shown here, and the call returns when the user has answered.
    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
      privateKey,
      .ecdsaSignatureMessageX962SHA256,
      challenge as CFData,
      &error
    ) as Data? else {
      throw signingError(error)
    }
    return signature
  }

  // Throws BIOMETRY_UNAVAILABLE unless the device has enrolled biometrics (Face ID or Touch ID)
  // that can be used.
  private func requireBiometrics() throws {
    var error: NSError?
    guard LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    else {
      throw PigeonError(
        code: "BIOMETRY_UNAVAILABLE",
        message: error?.localizedDescription ?? "Biometrics are not available",
        details: nil
      )
    }
  }

  // The lookup of a key failed. If the key is simply missing, there are two reasons that look
  // the same to the keychain. Either there never was a key (KEY_NOT_FOUND), or the system
  // removed it because the fingerprints or faces changed (KEY_INVALIDATED). The marker told
  // them apart: it is set when the plugin creates a key and cleared only when the app deletes it.
  private func missingKeyError(alias: String, status: OSStatus) -> PigeonError {
    guard status == errSecItemNotFound else {
      return keyStoreError(status)
    }
    if hasMarker(alias) {
      return PigeonError(
        code: "KEY_INVALIDATED",
        message: "The biometrics changed, so the key is no longer valid. "
          + "Create a new key and register it again",
        details: nil
      )
    }
    return PigeonError(
      code: "KEY_NOT_FOUND",
      message: "No key with the alias '\(alias)'",
      details: nil
    )
  }

  // Turns the error of the signing call into a PigeonError with the code that Dart gets.
  private func signingError(_ error: Unmanaged<CFError>?) -> PigeonError {
    guard let cfError = error?.takeRetainedValue() else {
      return PigeonError(
        code: "SIGNING_FAILED",
        message: "The signature could not be created",
        details: nil
      )
    }
    let nsError = cfError as Error as NSError
    return PigeonError(
      code: Self.signingErrorCode(domain: nsError.domain, code: nsError.code),
      message: nsError.localizedDescription,
      details: nil
    )
  }

  // Which code Dart gets for an error of the signing call. The user closing the prompt, or the
  // system or the app closing it, is USER_CANCELED. Biometrics that are not set up, not
  // available, or locked out after failed attempts are BIOMETRY_UNAVAILABLE. Anything else,
  // for example a finger that did not match, is SIGNING_FAILED with the system's message.
  static func signingErrorCode(domain: String, code: Int) -> String {
    if domain == LAError.errorDomain, let laCode = LAError.Code(rawValue: code) {
      switch laCode {
      case .userCancel, .systemCancel, .appCancel:
        return "USER_CANCELED"
      case .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout, .passcodeNotSet:
        return "BIOMETRY_UNAVAILABLE"
      default:
        return "SIGNING_FAILED"
      }
    }
    if domain == NSOSStatusErrorDomain, code == Int(errSecUserCanceled) {
      return "USER_CANCELED"
    }
    return "SIGNING_FAILED"
  }

  // The marker: a note that this plugin created a key under the alias. See missingKeyError.
  //
  // It is an item of the keychain with the same "ThisDeviceOnly" accessibility as the key, so it
  // lives and dies with the key. UserDefaults would be wrong: a restore from a backup onto a new
  // phone brings it back, but not the key, and then a key that never existed there would be
  // reported as invalidated.
  private func markerQuery(_ alias: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "device_security.key",
      kSecAttrAccount as String: alias,
    ]
  }

  // Best effort: without the marker, a key that the system removed is reported as KEY_NOT_FOUND
  // instead of KEY_INVALIDATED, and that is a lesser harm than failing a key that was made.
  private func setMarker(_ alias: String) {
    var item = markerQuery(alias)
    SecItemDelete(item as CFDictionary)
    item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    SecItemAdd(item as CFDictionary, nil)
  }

  private func clearMarker(_ alias: String) {
    SecItemDelete(markerQuery(alias) as CFDictionary)
  }

  private func hasMarker(_ alias: String) -> Bool {
    return SecItemCopyMatching(markerQuery(alias) as CFDictionary, nil) == errSecSuccess
  }

  // The alias as bytes. This is how the key is named inside the keychain.
  private func tag(_ alias: String) -> Data {
    return Data(alias.utf8)
  }

  // The search for the key of an alias: a key (not a password or a certificate), of the elliptic
  // curve type, with this tag. Used by both hasKey and deleteKey.
  private func query(_ alias: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: tag(alias),
    ]
  }

  // Turns the error the system put into the out-parameter into a PigeonError. It is a
  // reference-counted C object, so its ownership is taken before reading the message.
  private func generationError(_ error: Unmanaged<CFError>?) -> PigeonError {
    // SecKeyCopyPublicKey fails without filling `error`, so there may be no reason to report.
    let message = error.map { ($0.takeRetainedValue() as Error).localizedDescription }
      ?? "The key could not be created"
    return PigeonError(code: "KEY_GENERATION_FAILED", message: message, details: nil)
  }

  // Keychain functions return a numeric status. This gives it a readable message.
  private func keyStoreError(_ status: OSStatus) -> PigeonError {
    let message = SecCopyErrorMessageString(status, nil) as String?
    return PigeonError(code: "KEY_STORE_FAILED", message: message, details: nil)
  }
}
