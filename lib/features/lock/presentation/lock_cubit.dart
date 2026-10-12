import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/features/lock/domain/biometric_auth.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/lock_repository.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';
import 'package:otp_guard/features/lock/domain/pin_hasher.dart';
import 'package:otp_guard/features/lock/domain/pin_policy.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';
import 'package:otp_guard/features/otp/domain/account_repository.dart';

/// What came of setting a PIN.
enum SetPinResult {
  /// The PIN is set and the app is open.
  done,

  /// The PIN does not fit `PinPolicy`, or the lock is not waiting for one.
  invalid,

  /// The PIN could not be stored.
  failed,
}

/// What came of turning the biometric sign-in on.
enum EnableBiometricsResult {
  /// It is on.
  enabled,

  /// The device can not do it: no secure hardware for the key, or no
  /// fingerprints or faces are set up.
  unavailable,

  /// It failed for another reason.
  failed,
}

/// Decides whether the app is open: asks for a PIN or a fingerprint or a face
/// when it starts, and again when the app has been away for long.
///
/// The lock is a barrier in the interface. It does not encrypt anything: the
/// secrets are protected by the Keychain or the Keystore, and the PIN has no
/// part in that.
class LockCubit extends Cubit<AppLockState> {
  /// Creates the cubit.
  ///
  /// The app locks again when it comes back from the background after at least
  /// [lockTimeout].
  LockCubit({
    required this._repository,
    required this._accounts,
    required this._hasher,
    required this._biometrics,
    required this._clock,
    this.lockTimeout = defaultLockTimeout,
  }) : super(const LockLoading());

  /// How long the app may be in the background before it locks.
  static const defaultLockTimeout = Duration(minutes: 1);

  /// How long the app may be in the background before it locks.
  final Duration lockTimeout;

  final LockRepository _repository;
  final AccountRepository _accounts;
  final PinHasher _hasher;
  final BiometricAuth _biometrics;
  final Clock _clock;

  PinCredential? _credential;
  PinAttempts _attempts = PinAttempts.none;
  BiometricSetting _biometric = BiometricSetting.off;

  DateTime? _hiddenAt;
  bool _isAuthenticating = false;
  bool _isSettingPin = false;
  bool _isEnrolling = false;

  /// Reads what the lock remembers and shows the lock screen, or asks for a
  /// PIN if there is none. Does nothing once it has loaded, so it is safe to
  /// call at every start; after a failure it tries again.
  Future<void> load() async {
    if (state is! LockLoading && state is! LockLoadFailed) return;
    if (state is LockLoadFailed) emit(const LockLoading());
    try {
      final credential = await _repository.readPin();
      final attempts = await _repository.readAttempts();
      final biometric = await _readBiometric();
      if (isClosed) return;
      _credential = credential;
      _attempts = attempts;
      _biometric = biometric;
    } on FormatException {
      // A record that is damaged, or of a version this one does not know, is
      // not "no PIN": that would open the app to anyone. The lock stays shut.
      // Reading it again gives the same bytes, so the way out is the reset.
      if (!isClosed) emit(const LockLoadFailed(isDamaged: true));
      return;
    } on Exception {
      // The storage failed. It may work at the next try.
      if (!isClosed) emit(const LockLoadFailed());
      return;
    }
    emit(_credential == null ? const PinNotSet() : _locked());
  }

  /// Sets the first PIN and opens the app. The PIN is hashed in an isolate, so
  /// the screen does not freeze.
  Future<SetPinResult> setPin(String pin) async {
    if (state is! PinNotSet || _isSettingPin) return SetPinResult.invalid;
    if (PinPolicy.check(pin) != null) return SetPinResult.invalid;
    _isSettingPin = true;
    try {
      final credential = await _hasher.create(pin);
      await _repository.writePin(credential);
      // A new PIN starts with no history: no attempts, and no biometrics left
      // from an earlier PIN.
      await _repository.writeAttempts(PinAttempts.none);
      await _repository.writeBiometric(BiometricSetting.off);
      if (isClosed) return SetPinResult.failed;
      _credential = credential;
      _attempts = PinAttempts.none;
      _biometric = BiometricSetting.off;
    } on Exception {
      return SetPinResult.failed;
    } finally {
      _isSettingPin = false;
    }
    emit(const Unlocked(offer: BiometricOffer.setup));
    return SetPinResult.done;
  }

  /// Tries [pin].
  ///
  /// While a wait from earlier wrong tries is on, the try is refused and does
  /// not count. Otherwise it is counted before it is checked, and the count is
  /// cleared only by a right PIN: if the app is killed while the hash is being
  /// worked out, the try has still been paid for, and killing the app is not a
  /// way to try again for free.
  Future<void> unlockWithPin(String pin) async {
    final current = state;
    final credential = _credential;
    if (current is! Locked || current.isBusy || credential == null) return;

    // A PIN whose tries are used up is not tried at all, whatever is typed and
    // however long ago the last try was: the right PIN is refused, too.
    final now = _clock.now();
    if (_attempts.isBlocked || _attempts.remaining(now) > Duration.zero) {
      emit(_locked());
      return;
    }

    emit(_locked(isBusy: true));
    final attempt = _attempts.afterAttempt(now);
    try {
      await _repository.writeAttempts(attempt);
    } on Exception {
      // If the try can not be written down, it is not let in.
      if (!isClosed) emit(_locked(problem: UnlockProblem.storageFailed));
      return;
    }
    _attempts = attempt;

    final bool isRight;
    try {
      isRight = await _hasher.verify(pin, credential);
    } on Exception {
      if (!isClosed) emit(_locked(problem: UnlockProblem.storageFailed));
      return;
    }
    if (isClosed) return;

    if (!isRight) {
      emit(_locked(problem: UnlockProblem.wrongPin));
      return;
    }
    await _clearAttempts();
    if (isClosed) return;
    emit(_unlocked());
    await _upgradeCredential(pin, credential);
  }

  /// Asks for a fingerprint or a face, with the texts of the prompt, and opens
  /// the app if the proof holds.
  Future<void> unlockWithBiometrics(BiometricPromptTexts texts) async {
    final current = state;
    final publicKey = _biometric.publicKey;
    if (current is! Locked ||
        current.isBusy ||
        _biometric.status != BiometricStatus.on ||
        publicKey == null) {
      return;
    }

    emit(_locked(isBusy: true));
    _isAuthenticating = true;
    BiometricAttempt result;
    try {
      result = await _biometrics.authenticate(
        publicKey: publicKey,
        texts: texts,
      );
    } on Exception {
      result = const BiometricFailed();
    } finally {
      _isAuthenticating = false;
    }
    if (isClosed) return;

    switch (result) {
      case BiometricVerified():
        await _clearAttempts();
        if (isClosed) return;
        emit(_unlocked());
      case BiometricCanceled():
        emit(_locked());
      case BiometricKeyInvalidated():
        // The fingerprints or faces changed. The PIN opens the app, and after
        // it the user is asked to set the biometrics up again.
        await _store(BiometricSetting.needsRenewal);
        if (isClosed) return;
        emit(_locked());
      case BiometricUnavailable():
        emit(_locked(problem: UnlockProblem.biometricUnavailable));
      case BiometricSignatureInvalid() || BiometricFailed():
        emit(_locked(problem: UnlockProblem.biometricFailed));
    }
  }

  /// Turns the biometric sign-in on: makes a key in the secure hardware and
  /// keeps its public part. Only while the app is open.
  Future<EnableBiometricsResult> enableBiometrics() async {
    if (state is! Unlocked || _isEnrolling) {
      return EnableBiometricsResult.failed;
    }
    _isEnrolling = true;
    try {
      final enrollment = await _biometrics.enroll();
      if (isClosed) return EnableBiometricsResult.failed;
      switch (enrollment) {
        case BiometricEnrolled(:final publicKey):
          if (!await _store(BiometricSetting.enabled(publicKey))) {
            await _biometrics.remove();
            await declineBiometricOffer();
            return EnableBiometricsResult.failed;
          }
          if (!isClosed) emit(_unlocked());
          return EnableBiometricsResult.enabled;
        case BiometricEnrollUnavailable():
          await declineBiometricOffer();
          return EnableBiometricsResult.unavailable;
        case BiometricEnrollFailed():
          await declineBiometricOffer();
          return EnableBiometricsResult.failed;
      }
    } finally {
      _isEnrolling = false;
    }
  }

  /// Ends what the lock offered: the user does not want it, or it did not
  /// work. A key that stopped working is forgotten, so the offer does not come
  /// back at every unlock.
  Future<void> declineBiometricOffer() async {
    if (state is! Unlocked) return;
    if (_biometric.status == BiometricStatus.needsRenewal &&
        await _store(BiometricSetting.off)) {
      await _biometrics.remove();
    }
    if (!isClosed) emit(Unlocked(biometric: _biometric.status));
  }

  /// Turns the biometric sign-in off and deletes the key. Returns whether it
  /// is off.
  Future<bool> disableBiometrics() async {
    if (state is! Unlocked) return false;
    // The setting goes first. If it can not be written, the key stays and the
    // biometrics stay on, instead of being on with no key.
    if (!await _store(BiometricSetting.off)) return false;
    await _biometrics.remove();
    if (!isClosed) emit(_unlocked());
    return true;
  }

  /// Resets the app for a user who forgot the PIN: erases every account, the
  /// key of the biometrics and everything the lock remembers, and asks for a
  /// new PIN. Returns whether it did.
  ///
  /// It needs no PIN, because the user has none to give. That is safe only
  /// because it destroys what the PIN guards: whoever resets the app gets an
  /// empty one, not the accounts. So the accounts go first, and the PIN last.
  /// If anything fails, the PIN is still stored, the app stays locked, and the
  /// reset can be tried again; it never asks for a new PIN while an account is
  /// left.
  ///
  /// It is offered by the lock screen, and by the screen of a lock whose
  /// record is damaged, which would otherwise be a dead end. A lock that could
  /// not be read because the storage failed does not reset: the storage may
  /// work at the next try, and a reset would cost the accounts for nothing.
  Future<bool> resetApp() async {
    final before = state;
    final canReset =
        (before is Locked && !before.isBusy) ||
        (before is LockLoadFailed && before.isDamaged);
    if (!canReset) return false;

    emit(before is Locked ? _locked(isBusy: true) : const LockLoading());
    try {
      await _accounts.removeAll();
      await _biometrics.remove();
      await _repository.erase();
    } on Exception {
      if (!isClosed) {
        emit(
          before is Locked
              ? _locked(problem: UnlockProblem.resetFailed)
              : const LockLoadFailed(isDamaged: true, resetFailed: true),
        );
      }
      return false;
    }
    if (isClosed) return false;
    _credential = null;
    _attempts = PinAttempts.none;
    _biometric = BiometricSetting.off;
    _hiddenAt = null;
    emit(const PinNotSet());
    return true;
  }

  /// Locks the app now.
  void lock() {
    if (state is! Unlocked) return;
    _hiddenAt = null;
    emit(_locked());
  }

  /// The app is no longer on the screen: it went to the background, or the
  /// phone was locked.
  ///
  /// Only this counts, not the app becoming inactive. The system prompt for a
  /// fingerprint or a face makes the app inactive and nothing more, and a lock
  /// on that would lock the app again at the very moment it was opened.
  void appHidden() {
    if (_isAuthenticating || state is! Unlocked) return;
    _hiddenAt ??= _clock.now();
  }

  /// The app is on the screen again. It locks if it was away for at least
  /// [lockTimeout].
  void appShown() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || state is! Unlocked || _isAuthenticating) return;
    if (_clock.now().difference(hiddenAt) >= lockTimeout) lock();
  }

  Future<BiometricSetting> _readBiometric() async {
    try {
      return await _repository.readBiometric();
    } on FormatException {
      // A damaged record only costs the convenience: the PIN still works.
      return BiometricSetting.off;
    }
  }

  Locked _locked({UnlockProblem? problem, bool isBusy = false}) {
    final now = _clock.now();
    final wait = _attempts.remaining(now);
    final isBlocked = _attempts.isBlocked;
    return Locked(
      biometric: _biometric.status,
      // A blocked PIN has no wait to show: the time does not open it.
      retryAt: !isBlocked && wait > Duration.zero ? now.add(wait) : null,
      problem: problem,
      isBusy: isBusy,
      isPinBlocked: isBlocked,
    );
  }

  Unlocked _unlocked() {
    return Unlocked(
      biometric: _biometric.status,
      offer: _biometric.status == BiometricStatus.needsRenewal
          ? BiometricOffer.renewal
          : BiometricOffer.none,
    );
  }

  Future<void> _clearAttempts() async {
    _attempts = PinAttempts.none;
    try {
      await _repository.writeAttempts(PinAttempts.none);
    } on Exception {
      // The user has proved who they are. A count that stays in the storage
      // only makes the next lock stricter.
    }
  }

  // Makes the credential as strong as new ones are, now that the PIN is at
  // hand. A failure leaves the old, weaker one, which still works.
  Future<void> _upgradeCredential(String pin, PinCredential old) async {
    if (!_hasher.needsUpgrade(old)) return;
    try {
      final stronger = await _hasher.create(pin);
      await _repository.writePin(stronger);
      _credential = stronger;
    } on Exception {
      // Tried again at the next right PIN.
    }
  }

  // Keeps [setting] and uses it, if the storage took it.
  Future<bool> _store(BiometricSetting setting) async {
    try {
      await _repository.writeBiometric(setting);
    } on Exception {
      return false;
    }
    _biometric = setting;
    return true;
  }
}
