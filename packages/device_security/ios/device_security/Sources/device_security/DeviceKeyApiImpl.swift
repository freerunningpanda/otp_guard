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
final class DeviceKeyApiImpl: DeviceKeyApi {
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
    // may be used for private-key operations, that is for signing. Biometrics will be added here.
    guard let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      .privateKeyUsage,
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
