import 'dart:typed_data';

import 'package:otp_guard/features/otp/domain/hotp.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';

/// A time-based one-time password generator (TOTP, RFC 6238).
///
/// The time is a parameter of every method, never read inside, so the code can
/// be checked against the reference values and a clock can be faked in the UI.
///
/// The secret is kept inside and is not readable from outside, and
/// [toString] does not show it.
class Totp {
  /// Creates a generator for [secret].
  ///
  /// The secret is copied, so a later change of the list does not affect the
  /// generator. [digits] is 6 to 8 and [period] is a positive number of
  /// seconds; a [digits] or [period] outside that, or an empty secret, throws
  /// an [ArgumentError].
  Totp({
    required Uint8List secret,
    this.digits = 6,
    this.period = 30,
    this.algorithm = OtpAlgorithm.sha1,
  }) : _secret = Uint8List.fromList(secret) {
    if (secret.isEmpty) {
      throw ArgumentError.value('<empty>', 'secret', 'must not be empty');
    }
    if (digits < 6 || digits > 8) {
      throw ArgumentError.value(digits, 'digits', 'must be from 6 to 8');
    }
    if (period <= 0) {
      throw ArgumentError.value(period, 'period', 'must be positive');
    }
  }

  final Uint8List _secret;

  /// The length of a code.
  final int digits;

  /// How many seconds one code lives.
  final int period;

  /// The hash function of the HMAC.
  final OtpAlgorithm algorithm;

  /// The code valid at [time].
  ///
  /// The counter is the number of whole [period]s since 1970-01-01 UTC, so the
  /// code changes exactly at the boundary of an interval. Throws an
  /// [ArgumentError] for a time before 1970.
  String codeAt(DateTime time) {
    return hotp(
      secret: _secret,
      counter: _unixSeconds(time) ~/ period,
      digits: digits,
      algorithm: algorithm,
    );
  }

  /// How long the code valid at [time] stays valid.
  ///
  /// It is a full [period] at the very start of an interval and gets down to a
  /// millisecond before the code changes. At the boundary itself the next code
  /// has started, so the answer is a full period again, never zero.
  Duration remaining(DateTime time) {
    _unixSeconds(time); // rejects a time before 1970
    final periodMs = period * 1000;
    final elapsedMs = time.millisecondsSinceEpoch % periodMs;
    return Duration(milliseconds: periodMs - elapsedMs);
  }

  int _unixSeconds(DateTime time) {
    final milliseconds = time.millisecondsSinceEpoch;
    if (milliseconds < 0) {
      throw ArgumentError.value(time, 'time', 'must not be before 1970');
    }
    return milliseconds ~/ 1000;
  }

  @override
  String toString() {
    return 'Totp(digits: $digits, period: $period, '
        'algorithm: ${algorithm.name})';
  }
}
