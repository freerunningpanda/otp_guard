# device_security

Native screen protection and security events for Flutter apps that show sensitive data.

The API below is implemented on Android and iOS. Signing with the device key is the next step and is not part of it yet.

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
| `INVALID_ARGUMENT` | A required argument is missing, for example `enabled` in `setScreenProtection`. The call changes nothing, so protection that is on stays on |
| `NO_ACTIVITY` | Android: the plugin is not attached to an activity, so there is no window to protect |
| `UNAVAILABLE` | The platform API is missing on this OS version, or on iOS the device has no Secure Enclave (the simulator) |
| `KEY_EXISTS` | `generateKey` was called with an alias that already has a key. Nothing is replaced: delete the key first |
| `KEY_GENERATION_FAILED` | The Keystore or the Secure Enclave failed to create the key. The message carries the system's reason |
| `KEY_STORE_FAILED` | `hasKey` or `deleteKey` failed to reach the Keystore or the keychain |

## Key API

The key API is described in [`pigeons/device_key.dart`](pigeons/device_key.dart). [Pigeon](https://pub.dev/packages/pigeon) generates the channel code for Dart, Kotlin and Swift from it, so a wrong method name or argument type fails to compile instead of failing at runtime. After changing the description, regenerate the code from this directory:

```
dart run pigeon --input pigeons/device_key.dart
```

The generated files are committed, so the project builds without running the generator. Do not edit them by hand: the next generation overwrites the edits. Errors reach Dart as `PlatformException` with the codes above.

| Method | Arguments | Returns | Android | iOS |
|---|---|---|---|---|
| `isDeviceSecure` | none | `bool` | `KeyguardManager.isDeviceSecure` | `LAContext.canEvaluatePolicy(.deviceOwnerAuthentication)` |
| `generateKey` | `alias: String` | `Uint8List`, the public key | EC key pair, curve secp256r1, purpose sign, digest SHA-256, in the Android Keystore | EC key pair, 256 bits, in the Secure Enclave (`kSecAttrTokenIDSecureEnclave`), stored in the keychain with the alias as application tag |
| `hasKey` | `alias: String` | `bool` | `KeyStore.containsAlias` | `SecItemCopyMatching` by application tag |
| `deleteKey` | `alias: String` | `void` | `KeyStore.deleteEntry` | `SecItemDelete` by application tag |

`generateKey`, `hasKey` and `deleteKey` run on a background thread (Pigeon `@TaskQueue`, one serial queue for the three), because the Keystore and the Secure Enclave can take from tens to hundreds of milliseconds and the interface would freeze on the main thread. `isDeviceSecure` is quick and stays on the main thread.

The private key is created inside the Keystore or the Secure Enclave and never leaves it. Not even the app can read it, it can only ask the chip to sign something. The keys do not require user authentication yet: the biometric check comes with signing.

### Public key format

The two platforms return the key in different formats, and a server wants one. The plugin converts it, so `generateKey` returns the same bytes layout on both: X.509 SubjectPublicKeyInfo in DER, 91 bytes for a P-256 key. This is what servers load directly, for example Java's `X509EncodedKeySpec`, `openssl ec -pubin -inform DER` or Python's `cryptography.hazmat.primitives.serialization.load_der_public_key`.

- **Android** already gives it: `PublicKey.encoded` is that format.
- **iOS** gives only the raw point (X9.63, 65 bytes: `04`, then X and Y). The plugin puts the fixed 26-byte DER header of a P-256 key in front of it.

The conversion lives in the plugin, not in Dart or on the server, so no caller needs a platform check.

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
- **The iOS simulator has no Secure Enclave.** `generateKey` fails there with `UNAVAILABLE` instead of creating a software key, which would not be the hardware-backed key the app asks for. Check the key operations on a real iPhone.
- **The iOS blur appears on every loss of focus, not only in the task switcher.** `willResignActive` also fires for Control Center, an incoming call and system prompts such as Face ID, so the screen blurs under them too. For an authenticator this is the wanted behavior.

## Planned next

Signing a server challenge with the device key after a biometric check. It will be added to the Pigeon API above.
