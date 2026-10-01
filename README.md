# OTP Guard

A corporate authenticator that protects one-time codes from leaking through the screen.

> Work in progress. See the [roadmap](#roadmap) for what is done.

## The problem

One-time codes rarely leak because someone broke the cryptography. They leak through the screen:

- a screenshot that syncs to a cloud photo library;
- a screen recording or a screen share during a video call;
- the app preview in the task switcher.

Banks and corporate services have to close these channels and keep a record of such events. Flutter alone cannot do this: screen protection and capture detection are platform APIs, and they differ between Android and iOS.

## What the app does

- Adds accounts by scanning an `otpauth://` QR code and generates TOTP codes (RFC 6238).
- Stores secrets in the Keychain / Keystore and locks the app behind a PIN or biometrics.
- Hides codes and writes an entry to a security log when the user takes a screenshot or starts a screen recording.
- Blocks screenshots on Android and hides the app preview in the task switcher on iOS.

## How it is built

```
otp_guard/
  packages/device_security/   native module: platform channels, Kotlin, Swift
  lib/                        the authenticator app (Clean Architecture, BLoC)
  .github/workflows/          CI
```

The native work lives in [`packages/device_security`](packages/device_security/README.md), a separate plugin with its own API, so it can be reused by other apps. It talks to the platforms through a `MethodChannel` for commands and an `EventChannel` for the stream of security events.

## Roadmap

- [x] Project and plugin scaffold, strict linting
- [ ] `device_security`: screen protection over `MethodChannel` (Kotlin, Swift)
- [ ] `device_security`: screenshot and screen-recording events over `EventChannel`
- [ ] `device_security`: hardware-backed key and signing (Pigeon)
- [ ] Channel tests with a mocked platform side
- [ ] TOTP generation with the RFC 6238 test vectors
- [ ] Accounts via QR code, secure storage, PIN and biometric lock
- [ ] Security log and reaction to capture events
- [ ] CI on GitHub Actions, release with Fastlane
