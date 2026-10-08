# device_security

Native screen protection and security events for Flutter apps that show sensitive data.

The API below is implemented on Android and iOS.

## Channels

| Channel | Name | Direction |
|---|---|---|
| `MethodChannel` | `com.freerunningpanda.device_security/methods` | Dart calls native |
| `EventChannel` | `com.freerunningpanda.device_security/events` | native streams to Dart |
| Pigeon (generated) | `dev.flutter.pigeon.device_security.DeviceKeyApi.*` | Dart calls native, see [Key API](#key-api) |

## Methods

| Method | Arguments | Returns | Android | iOS |
|---|---|---|---|---|
| `setScreenProtection` | `enabled: bool` | `void` | `FLAG_SECURE` on the activity window: blocks screenshots, screen recording and the task-switcher preview | Covers every window with a blur while the app is inactive or the screen is captured, so the task switcher and a recording show no content |

Errors are returned as `PlatformException` with these codes and mapped to typed failures on the Dart side:

| Code | Meaning |
|---|---|
| `INVALID_ARGUMENT` | A required argument is missing or empty: `enabled` in `setScreenProtection`, or `title` and `cancelText` of `sign`. The call changes nothing, so protection that is on stays on |
| `NO_ACTIVITY` | Android: the plugin is not attached to an activity, so there is no window to protect and no place for the biometric prompt |
| `UNAVAILABLE` | The platform API is missing on this OS version, or the device has no secure hardware for the key: no Secure Enclave on iOS (the simulator), or a key that the Android Keystore could create only in software (most emulators). The key is not kept |
| `KEY_EXISTS` | `generateKey` was called with an alias that already has a key. Nothing is replaced: delete the key first |
| `KEY_GENERATION_FAILED` | The Keystore or the Secure Enclave failed to create the key. The message carries the system's reason |
| `KEY_STORE_FAILED` | `hasKey` or `deleteKey` failed to reach the Keystore or the keychain |
| `KEY_NOT_FOUND` | `sign` was called with an alias that has no key |
| `USER_CANCELED` | The user closed the biometric prompt of `sign` |
| `BIOMETRY_UNAVAILABLE` | Biometrics are not set up, not available or locked out. Also from `generateKey`: a key that needs biometrics cannot be made without enrolled ones |
| `KEY_INVALIDATED` | The set of fingerprints or faces changed, so the key no longer works. This is a normal case, see [Signing](#signing) |
| `SIGNING_FAILED` | `sign` failed for any other reason. The message carries the system's reason |
| `ACTIVITY_NOT_SUPPORTED` | Android: `sign` needs a `FragmentActivity`, see [What the app must provide](#what-the-app-must-provide) |
| `SIGNING_IN_PROGRESS` | Android: `sign` was called while a biometric prompt is already shown |

## Key API

The key API is described in [`pigeons/device_key.dart`](pigeons/device_key.dart). [Pigeon](https://pub.dev/packages/pigeon) generates the channel code for Dart, Kotlin and Swift from it, so a wrong method name or argument type fails to compile instead of failing at runtime. After changing the description, regenerate the code from this directory:

```
dart run pigeon --input pigeons/device_key.dart
```

The generated files are committed, so the project builds without running the generator. Do not edit them by hand: the next generation overwrites the edits. Errors reach Dart as `PlatformException` with the codes above.

| Method | Arguments | Returns | Android | iOS |
|---|---|---|---|---|
| `isDeviceSecure` | none | `bool` | `KeyguardManager.isDeviceSecure` | `LAContext.canEvaluatePolicy(.deviceOwnerAuthentication)` |
| `generateKey` | `alias: String` | `Uint8List`, the public key | EC key pair, curve secp256r1, purpose sign, digest SHA-256, in the Android Keystore, with `setUserAuthenticationRequired(true)` and `setInvalidatedByBiometricEnrollment(true)`. Afterwards `KeyInfo` is checked: only a key in the TEE or StrongBox is kept (`securityLevel` from Android 12, `isInsideSecureHardware` before) | EC key pair, 256 bits, in the Secure Enclave (`kSecAttrTokenIDSecureEnclave`), with the access control `.privateKeyUsage` and `.biometryCurrentSet`, stored in the keychain with the alias as application tag |
| `hasKey` | `alias: String` | `bool` | `KeyStore.containsAlias` | `SecItemCopyMatching` by application tag |
| `deleteKey` | `alias: String` | `void` | `KeyStore.deleteEntry` | `SecItemDelete` by application tag |
| `sign` | `alias: String`, `challenge: Uint8List`, `title: String`, `cancelText: String`, `subtitle: String?` | `Uint8List`, the signature | `BiometricPrompt` with a `CryptoObject` around `Signature` (`SHA256withECDSA`) | `SecKeyCreateSignature` with `.ecdsaSignatureMessageX962SHA256`; the system shows Face ID or Touch ID |

`generateKey`, `hasKey` and `deleteKey` run on a background thread (Pigeon `@TaskQueue`, one serial queue for the three), because the Keystore and the Secure Enclave can take from tens to hundreds of milliseconds and the interface would freeze on the main thread. `isDeviceSecure` is quick and stays on the main thread.

The private key is created inside the Keystore or the Secure Enclave and never leaves it. Not even the app can read it, it can only ask the chip to sign something, and the chip does that only after a biometric check (see [Signing](#signing)).

### Public key format

The two platforms return the key in different formats, and a server wants one. The plugin converts it, so `generateKey` returns the same bytes layout on both: X.509 SubjectPublicKeyInfo in DER, 91 bytes for a P-256 key. This is what servers load directly, for example Java's `X509EncodedKeySpec`, `openssl ec -pubin -inform DER` or Python's `cryptography.hazmat.primitives.serialization.load_der_public_key`.

- **Android** already gives it: `PublicKey.encoded` is that format.
- **iOS** gives only the raw point (X9.63, 65 bytes: `04`, then X and Y). The plugin puts the fixed 26-byte DER header of a P-256 key in front of it.

The conversion lives in the plugin, not in Dart or on the server, so no caller needs a platform check.

### Signing

`sign(alias, challenge, title:, cancelText:, subtitle:)` is the second half of the sign-in scenario. The server sends a random `challenge`, the user confirms with a fingerprint or a face, the device returns a signature, and the server checks it with the public key from `generateKey`.

**The biometric check is not a gate in front of the signature.** The key is created with the condition that the chip lets it be used only after a successful biometric check, and the chip, not the code of the app, enforces it. On Android the `Signature` object is initialized with the key first and handed to the `BiometricPrompt` as a `CryptoObject`: the prompt unlocks that object, nothing else can. On iOS the system shows Face ID or Touch ID inside `SecKeyCreateSignature`. An attacker who patches the app still cannot sign without the user's finger or face. Every use needs its own check, and only a strong biometric counts, not the PIN.

**The signature** is ECDSA over the SHA-256 of the challenge bytes, in DER (`SEQUENCE { INTEGER r, INTEGER s }`). Both platforms produce the same format, so nothing is converted and a server needs one parser. Together with the public key format above, a server checks it in one step, for example Java's `Signature.getInstance("SHA256withECDSA")` or Python's `cryptography` `ec.ECDSA(hashes.SHA256())`.

**`KEY_INVALIDATED` is a normal case, not a failure.** When a fingerprint or a face is added (and on iOS also removed), the key stops working on purpose. Otherwise a stranger who adds their own finger would get access. The app must then create a new key with `generateKey` (after `deleteKey` if the old one is still there) and register the new public key on the server again.

**Keys made before this step do not require biometrics.** `deleteKey` them and create new ones.

**The texts of the prompt belong to the app, not to the plugin.** `title`, `subtitle` and `cancelText` are parameters of `sign`, so the app can translate them and word them for its scenario ("Confirm sign-in", "Confirm the transfer"). `title` and `cancelText` must not be empty, otherwise the call fails with `INVALID_ARGUMENT` before anything is shown. `subtitle` is optional. On Android they become the title, the subtitle and the negative button of the `BiometricPrompt`. On iOS the `subtitle` (or the `title` if there is none) is the reason that the system shows, and `cancelText` is the label of the cancel button; Face ID itself shows no text beyond the system's, apart from `NSFaceIDUsageDescription` the first time.

**Threading.** `sign` is `@async` in Pigeon, because the answer comes after the user answers. It does not use the serial background queue of the other key calls, which a waiting prompt would block. On Android the prompt is shown from the main thread and the call is a coroutine that waits for it. On iOS `SecKeyCreateSignature` blocks until the user answers, so it runs on its own background queue.

### What the app must provide

- **Android: `MainActivity` extends `FlutterFragmentActivity`**, not `FlutterActivity`. `BiometricPrompt` works only with a `FragmentActivity`. With another activity, `sign` fails with `ACTIVITY_NOT_SUPPORTED`. The plugin declares `USE_BIOMETRIC`, a normal permission that merges into the manifest of the app.
- **iOS: `NSFaceIDUsageDescription` in `Info.plist`.** Without it the app crashes at the first Face ID request.

## Events

Each event is a map: `{"type": String, "timestamp": int, ...}`. `timestamp` is milliseconds since the Unix epoch. The Dart side skips an event with a `type` it does not know, so the native side can add new types without breaking older Dart code. A known `type` with a missing or mistyped field is a contract violation and raises a `FormatException`.

| Event | Payload | Android | iOS |
|---|---|---|---|
| `screenshotTaken` | none | `Activity.ScreenCaptureCallback`, Android 14+ | `UIApplication.userDidTakeScreenshotNotification` |
| `screenRecordingChanged` | `isRecording: bool` | `WindowManager.addScreenRecordingCallback`, Android 15+ | `UIScreen.capturedDidChangeNotification` |

The platform watches for these events only while Dart listens: it subscribes in `onListen` and unsubscribes in `onCancel`. The one exception is the iOS screen-capture notification: the blur needs it, so it is observed for the whole life of the plugin, but no event is sent without a listener. A recording can already be running when Dart subscribes, and no event announces it, so the platform then sends `screenRecordingChanged` with `isRecording: true` right away. Otherwise the app would show codes to someone who started recording before the screen opened. When no recording is running nothing is sent, so on the Dart side the screen counts as not recorded until a `screenRecordingChanged` with `isRecording: true` arrives.

On Android both callbacks belong to the activity, so they are registered only while Dart listens and an activity is attached. The plugin declares the permissions `DETECT_SCREEN_CAPTURE` and `DETECT_SCREEN_RECORDING`. They are normal permissions: they merge into the manifest of the app and the user confirms nothing.

## Platform limitations

These come from the platforms and are part of the design, not bugs:

- **iOS cannot block a screenshot.** It can only report that one was taken, after the fact. The app reacts by hiding codes and logging the event.
- **iOS cannot block a screen recording, but it hides the content.** While protection is on and the screen is captured, every window is covered with a blur, so the recording shows a blur instead of codes. The blur stays until the capture ends. The system reports a capture a moment after it starts, so the first frames can still show content, and a window that opens during the capture is not covered.
- **Android can block, but detects only on new versions.** `FLAG_SECURE` works on every supported version. Screenshot detection needs Android 14, screen-recording detection needs Android 15. On older versions the stream stays silent, and protection relies on `FLAG_SECURE`.
- **With `FLAG_SECURE` enabled, Android produces no screenshot events**, because the screenshot does not happen.
- **On iOS, `screenRecordingChanged` means any screen capture, not only recording.** `isRecording` is `UIScreen.isCaptured`, which is also true while the screen is mirrored with AirPlay or to an external display. For an authenticator this is the wanted behavior: the codes leave the device in all these cases.
- **Simulators and emulators have no secure hardware, and the plugin refuses to fake it.** On iOS the Secure Enclave is missing, so `generateKey` fails with `UNAVAILABLE`. On Android the Keystore creates the key anyway, but in software on an emulator or on a device without a TEE, so the plugin reads `KeyInfo` after creating it, deletes a software key and fails with `UNAVAILABLE` the same way. A key that is not in hardware would defeat the point of the feature, and the app could not tell the difference. The behavior is the same on both platforms. Check the key operations on a real iPhone and a real Android phone. Everything else (`isDeviceSecure`, `hasKey`, `deleteKey`, the error codes) works on simulators and emulators.
- **`KEY_INVALIDATED` on iOS is inferred.** iOS does not report a changed biometric set as a separate error: the key is no longer found in the keychain. The plugin keeps a marker, a small keychain item with the same `ThisDeviceOnly` accessibility as the key, saying that it created a key under the alias. A missing key with the marker is reported as `KEY_INVALIDATED`, a missing key without it as `KEY_NOT_FOUND`. The marker is in the keychain and not in `UserDefaults` on purpose: a restore from a backup onto a new phone brings `UserDefaults` back but not a `ThisDeviceOnly` key, and the plugin would report `KEY_INVALIDATED` for a key that never existed there. The marker vanishes together with the key. This relies on iOS dropping the key, and it has been checked on a device only up to the point of creating the key and signing; the invalidation itself has not been verified yet. Android reports the invalidation directly.
- **The iOS blur appears on every loss of focus, not only in the task switcher.** `willResignActive` also fires for Control Center, an incoming call and system prompts such as Face ID, so the screen blurs under them too. For an authenticator this is the wanted behavior.

## Planned next

Nothing planned yet. Key attestation (proving to the server that the key lives in secure hardware, with Android Key Attestation and Apple App Attest) would be the next step.
