import 'package:equatable/equatable.dart';

/// How long to wait after so many attempts at the PIN.
abstract final class AttemptPolicy {
  /// The attempts that cost nothing: a slip of a finger is not an attack.
  static const freeAttempts = 4;

  /// The wait that comes with the [attempts]-th attempt in a row.
  ///
  /// None for the first few, then it grows fast and stops at an hour: a PIN of
  /// six digits has a million values, and an hour per attempt makes guessing
  /// them take longer than anyone lives.
  static Duration delayAfter(int attempts) {
    if (attempts <= freeAttempts) return Duration.zero;
    return switch (attempts - freeAttempts) {
      1 => const Duration(seconds: 30),
      2 => const Duration(minutes: 1),
      3 => const Duration(minutes: 5),
      4 => const Duration(minutes: 15),
      _ => const Duration(hours: 1),
    };
  }
}

/// The attempts at the PIN since it was last typed right, and when the next
/// one is allowed.
///
/// It is stored, so closing the app does not reset it. The time comes from the
/// `Clock` of the app, never from the widget.
class PinAttempts extends Equatable {
  /// Creates the record.
  const PinAttempts({
    this.attempts = 0,
    this.lastAttemptAt,
    this.lockedUntil,
  });

  /// No attempts.
  static const none = PinAttempts();

  /// How many attempts in a row were not confirmed by a right PIN. An attempt
  /// is counted when it starts, not when it fails, see `LockCubit`.
  final int attempts;

  /// When the last attempt was made, in UTC.
  final DateTime? lastAttemptAt;

  /// Until when the next attempt is not allowed, in UTC. Null if it is.
  final DateTime? lockedUntil;

  /// The record after an attempt made at [now].
  PinAttempts afterAttempt(DateTime now) {
    final next = attempts + 1;
    final delay = AttemptPolicy.delayAfter(next);
    return PinAttempts(
      attempts: next,
      lastAttemptAt: now.toUtc(),
      lockedUntil: delay == Duration.zero ? null : now.toUtc().add(delay),
    );
  }

  /// How long until the next attempt is allowed, at [now]. Zero if it is.
  ///
  /// If the clock shows a time before the last attempt, it was turned back,
  /// perhaps to skip the wait. The wait then counts in full from the last
  /// attempt, so turning the clock back never shortens it.
  Duration remaining(DateTime now) {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final last = lastAttemptAt;
    if (last != null && now.isBefore(last)) return until.difference(last);
    final left = until.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  List<Object?> get props => [attempts, lastAttemptAt, lockedUntil];
}
