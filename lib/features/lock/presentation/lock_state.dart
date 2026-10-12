import 'package:equatable/equatable.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';

/// Why the last try to unlock did not work.
enum UnlockProblem {
  /// The PIN is wrong.
  wrongPin,

  /// Biometrics are not available now: not set up, or locked out by the
  /// system. The PIN is the way in.
  biometricUnavailable,

  /// The biometric check failed, or its proof did not hold. The PIN is the way
  /// in.
  biometricFailed,

  /// The lock could not write what it must remember before it let a try in,
  /// so it did not let it in.
  storageFailed,

  /// The reset could not erase everything. The app stays locked, and the
  /// reset can be tried again.
  resetFailed,
}

/// What the lock asks the user to do after an unlock.
enum BiometricOffer {
  /// Nothing.
  none,

  /// A PIN was just set: offer the biometric sign-in.
  setup,

  /// The key stopped working (the fingerprints or faces changed): offer to set
  /// the biometric sign-in up again.
  renewal,
}

/// Where the app stands with its lock.
sealed class AppLockState extends Equatable {
  const AppLockState();

  @override
  List<Object?> get props => const [];
}

/// The lock is reading what it remembers. Nothing is shown but the lock
/// screen.
final class LockLoading extends AppLockState {
  /// Creates the state.
  const LockLoading();
}

/// What the lock remembers could not be read. The app stays closed: with no
/// way to tell whether a PIN is set, opening it would be a way round the lock.
final class LockLoadFailed extends AppLockState {
  /// Creates the state.
  const LockLoadFailed({this.isDamaged = false, this.resetFailed = false});

  /// Whether a record is damaged, as against a storage that failed.
  ///
  /// A damaged record stays damaged: trying again reads the same bytes, and
  /// the only way out is to reset the app. A storage that failed may work at
  /// the next try, and a reset would cost the accounts for nothing, so it is
  /// not offered.
  final bool isDamaged;

  /// Whether the last reset could not erase everything.
  final bool resetFailed;

  @override
  List<Object?> get props => [isDamaged, resetFailed];
}

/// No PIN is set yet, so the user is asked to create one.
final class PinNotSet extends AppLockState {
  /// Creates the state.
  const PinNotSet();
}

/// The app is locked: a PIN or a fingerprint or a face opens it.
final class Locked extends AppLockState {
  /// Creates the state.
  const Locked({
    this.biometric = BiometricStatus.off,
    this.retryAt,
    this.problem,
    this.isBusy = false,
    this.isPinBlocked = false,
  });

  /// Whether the biometric sign-in is on, off or has to be set up again.
  final BiometricStatus biometric;

  /// When the next try at the PIN is allowed, in UTC, or null if it is now.
  final DateTime? retryAt;

  /// Why the last try did not work, or null.
  final UnlockProblem? problem;

  /// Whether a PIN or a biometric check is being worked on.
  final bool isBusy;

  /// Whether the tries at the PIN are used up, and the PIN is blocked for good.
  /// Only a fingerprint or a face, if they are on, or a reset of the app opens
  /// the app then.
  final bool isPinBlocked;

  @override
  List<Object?> get props => [
    biometric,
    retryAt,
    problem,
    isBusy,
    isPinBlocked,
  ];
}

/// The app is open.
final class Unlocked extends AppLockState {
  /// Creates the state.
  const Unlocked({
    this.biometric = BiometricStatus.off,
    this.offer = BiometricOffer.none,
  });

  /// Whether the biometric sign-in is on, off or has to be set up again.
  final BiometricStatus biometric;

  /// What to ask the user, if anything.
  final BiometricOffer offer;

  @override
  List<Object?> get props => [biometric, offer];
}
