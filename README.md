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

The native work lives in [`packages/device_security`](packages/device_security/README.md), a separate plugin with its own API, so it can be reused by other apps. It talks to the platforms through a `MethodChannel` for commands, an `EventChannel` for the stream of security events, and a [Pigeon](https://pub.dev/packages/pigeon)-generated API for the device key, so the key calls are type-checked on Dart, Kotlin and Swift.

## The lock

The app is locked at start, and again when it comes back from the background after a minute or more. A PIN opens it, or a fingerprint or a face if the user turned them on. Every route goes through the lock: `LockCubit` is `PinNotSet`, `Locked` or `Unlocked` (and `LockLoading` and `LockLoadFailed` while it reads its state), and `go_router` checks its `redirect` again at every change of it through `refreshListenable`, so while the app is locked every path leads to the lock screen.

The lock and the blur of the plugin are two different things. The blur closes the content in the task switcher and in a recording. The lock makes the user prove who they are. The app needs both.

### The PIN

- The PIN itself is never stored. The record holds PBKDF2-HMAC-SHA256 of it with a random 16-byte salt and 300,000 iterations, in the format `{v, alg, iter, salt, hash}`. The parameters sit next to the hash, so they can be made stronger: a PIN is checked with the parameters it was made with, and when it is typed right and the app wants more iterations, the hash is made again.
- The hash is worked out in an isolate, because it takes a noticeable time, and compared in constant time, byte by byte, with no early exit.
- The number of iterations is a constant (`PinHasher.defaultIterations`). It was picked for about a second on a recent phone; measure it on the weakest device you support.

### Wrong PINs

| Wrong PINs in a row | Wait before the next try |
|---|---|
| 1–4 | none |
| 5 | 30 seconds |
| 6 | 1 minute |
| 7 | 5 minutes |
| 8 | 15 minutes |
| 9 | 1 hour |
| 10 | **blocked for good** |

A try is written down **before** the hash is checked and cleared only by a right PIN, so killing the app while it checks does not give a free try. The count and the time to wait are stored, so a restart does not reset them. The time comes from the `Clock` of the app. If the clock shows a time before the last try, it was turned back, and the wait counts in full again. Biometric tries are not counted: the system limits them itself.

**The waits are not a limit, the block is.** An hour per try is slow, but it never ends, and a patient guesser would get through a million PINs in a lifetime. So the PIN is good for ten tries in a row. After the tenth wrong one the PIN is **blocked for good**: the field and the button are gone, the right PIN is refused and not even checked, and the lock screen says so. The block does not depend on the clock, so neither waiting nor changing the time opens it, and it is stored, so a restart does not either. Two ways out are left. A fingerprint or a face, if they are on, opens the app and clears the count. Or the reset of the app (see below), which deletes the accounts. The block does not erase anything by itself, so a child at the keypad cannot cost the user the accounts.

### Biometrics: the chip signs, not a boolean

`local_auth` and its kind answer "yes" or "no", and that answer is one value in the memory of the app that anything which controls the app can set. Here the answer is a signature:

1. **Turning on.** The plugin makes a P-256 key pair in the Secure Enclave (iOS) or the Keystore (Android), usable only after a biometric check. The app keeps the **public** key. The private key never leaves the chip.
2. **Unlocking.** The app makes a random 32-byte challenge and calls `sign`. The system shows the prompt, and only after the user confirms does the chip sign the challenge.
3. **Checking.** The app checks the signature over the challenge with the stored public key (`verifyP256Signature`). A challenge is new every time, so an old signature is no good.

A "yes" cannot be made without the private key, and the private key can be used only with the user's finger or face. The texts of the prompt (`title`, `subtitle`, `cancelText`) come from the ARB files, in the language of the app.

**`KEY_INVALIDATED`.** When a fingerprint or a face is added to the device, the key stops working on purpose. The app notices it at the next try, shows the PIN screen with the reason, and remembers it, so the next start goes straight to the PIN. After the PIN opens the app, it offers to turn the biometrics on again with a new key. If the user declines, the biometrics stay off.

### A forgotten PIN

"Forgot the PIN?" on the lock screen resets the app. It needs no PIN, because the user has none to give, and that is safe only because it **destroys what the PIN guards**: whoever resets the app gets an empty app, not the accounts. After a confirmation that names the loss, it erases every account (also the records that cannot be read), deletes the key of the biometrics from the hardware, forgets the PIN, the attempts and the biometric setting, and asks for a new PIN. It works during a wait, too.

The same reset is the way out of a lock whose record is **damaged**: the record of the PIN or of the attempts cannot be parsed, or is of a version this one does not know. The app does not take that for "no PIN", which would open it to anyone. Reading a damaged record gives the same bytes every time, so a retry is pointless, and the screen says so and offers the reset, with the same confirmation. A storage that merely failed is told apart from it (`FormatException` against any other exception) and gets no reset. A damaged record of the biometrics costs only the biometrics: the PIN still works.

The order is what makes it safe. The accounts go first and the PIN last, and the app asks for a new PIN only when no PIN is stored. If anything fails half-way, the old PIN is still there, the app stays locked, shows that the reset failed and lets the user try again. It never reaches "no PIN" while an account is left.

### When it locks

`AppLifecycleListener` reports `hidden` and `show`, and `LockCubit` compares the time between them, taken from the `Clock`, with the timeout. The app becoming `inactive` does not count. The system prompt for Face ID makes the app inactive, and locking on that locks the app again at the moment the fingerprint opened it, which is a common mistake. The user can also lock the app at once from the menu.

### What the lock is not

It is a barrier in the interface, and this is on purpose.

- **It encrypts nothing.** The secrets are protected by the Keychain and the Keystore. The PIN has no part in it: it is not a key and nothing is derived from it. Whoever gets the unlocked storage gets the secrets without the PIN.
- **The checks run on the device.** A person who controls the app process can skip the lock screen altogether. The signature of the chip is a strong proof for a server that checks it; here it shows that the answer comes from the chip and not from a flag, and it protects against a fake answer of the system, not against a changed app.
- **The wait relies on the clock of the device.** Turning the clock back does not help, but turning it forward shortens the wait. The wait slows down a guesser on a lost phone; it does not stop an attacker who can change the settings.
- **A lock that cannot be read stays shut.** If the storage fails, the app says so and offers to try again, and nothing more: a storage that failed once may work the next time, and a reset would cost the accounts for nothing. A **damaged** record is another case, see above.
- **A forgotten PIN is not recovered, only reset, and a reset loses the accounts.** There is no recovery by e-mail or by a question, on purpose: anything that could bring the PIN back could be used by someone else. Reinstalling the app does not help on iOS, where the Keychain outlives the app.
- **The PIN passes through the memory of the app as a `String`**, which cannot be cleared. The text field is emptied as soon as the PIN is sent.

## Localization

The interface is in Russian and English and follows the language of the device; any other language gets English. The texts are in [`lib/l10n`](lib/l10n): `intl_ru.arb` is the template and `intl_en.arb` the translation. `flutter pub get` generates the class `S` from them (see `l10n.yaml`), and the generated files are committed. A text is read as `S.of(context).name`. To add a language, add `intl_<code>.arb` with the same keys.

## Roadmap

- [x] Project and plugin scaffold, strict linting
- [x] `device_security`: screen protection over `MethodChannel` (Kotlin, Swift)
- [x] `device_security`: screenshot and screen-recording events over `EventChannel`
- [x] `device_security`: hardware-backed key and signing (Pigeon)
- [x] Channel tests with a mocked platform side
- [x] TOTP generation with the RFC 6238 test vectors
- [x] Accounts via QR code, secure storage, PIN and biometric lock
- [ ] Security log and reaction to capture events
- [ ] CI on GitHub Actions, release with Fastlane
