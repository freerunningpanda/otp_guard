# device_security

Native screen protection and security events for Flutter apps that show sensitive data.

> API draft. Nothing below is implemented yet; this file is the contract the implementation will follow.

## Channels

| Channel | Name | Direction |
|---|---|---|
| `MethodChannel` | `com.freerunningpanda.device_security/methods` | Dart calls native |
| `EventChannel` | `com.freerunningpanda.device_security/events` | native streams to Dart |

## Methods

| Method | Arguments | Returns | Android | iOS |
|---|---|---|---|---|
| `setScreenProtection` | `enabled: bool` | `void` | `FLAG_SECURE` on the activity window: blocks screenshots, screen recording and the task-switcher preview | Covers the window with a blur while the app is inactive, so the task switcher shows no content |
| `isDeviceSecure` | none | `bool` | `KeyguardManager.isDeviceSecure` | `LAContext.canEvaluatePolicy(.deviceOwnerAuthentication)` |

Errors are returned as `PlatformException` with these codes and mapped to typed failures on the Dart side:

| Code | Meaning |
|---|---|
| `INVALID_ARGUMENT` | A required argument is missing, for example `enabled` in `setScreenProtection`. The call changes nothing, so protection that is on stays on |
| `NO_ACTIVITY` | Android: the plugin is not attached to an activity, so there is no window to protect |
| `UNAVAILABLE` | The platform API is missing on this OS version |

## Events

Each event is a map: `{"type": String, "timestamp": int, ...}`. `timestamp` is milliseconds since the Unix epoch. The Dart side skips an event with a `type` it does not know, so the native side can add new types without breaking older Dart code. A known `type` with a missing or mistyped field is a contract violation and raises a `FormatException`.

| Event | Payload | Android | iOS |
|---|---|---|---|
| `screenshotTaken` | none | `Activity.ScreenCaptureCallback`, Android 14+ | `UIApplication.userDidTakeScreenshotNotification` |
| `screenRecordingChanged` | `isRecording: bool` | `WindowManager.addScreenRecordingCallback`, Android 15+ | `UIScreen.capturedDidChangeNotification` |

The platform watches for these events only while Dart listens: it subscribes in `onListen` and unsubscribes in `onCancel`. A recording can already be running when Dart subscribes, and no event announces it, so the platform then sends `screenRecordingChanged` with `isRecording: true` right away. Otherwise the app would show codes to someone who started recording before the screen opened.

## Platform limitations

These come from the platforms and are part of the design, not bugs:

- **iOS cannot block a screenshot.** It can only report that one was taken, after the fact. The app reacts by hiding codes and logging the event.
- **Android can block, but detects only on new versions.** `FLAG_SECURE` works on every supported version. Screenshot detection needs Android 14, screen-recording detection needs Android 15. On older versions the stream stays silent, and protection relies on `FLAG_SECURE`.
- **With `FLAG_SECURE` enabled, Android produces no screenshot events**, because the screenshot does not happen.
- **On iOS, `screenRecordingChanged` means any screen capture, not only recording.** `isRecording` is `UIScreen.isCaptured`, which is also true while the screen is mirrored with AirPlay or to an external display. For an authenticator this is the wanted behavior: the codes leave the device in all these cases.
- **The iOS blur appears on every loss of focus, not only in the task switcher.** `willResignActive` also fires for Control Center, an incoming call and system prompts such as Face ID, so the screen blurs under them too. For an authenticator this is the wanted behavior.

## Planned next

A hardware-backed key (Android Keystore, iOS Secure Enclave) that signs a server challenge after a biometric check. This part will use [Pigeon](https://pub.dev/packages/pigeon) to generate type-safe channel code, next to the hand-written channels above.
