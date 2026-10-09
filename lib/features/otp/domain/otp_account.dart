import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';
import 'package:otp_guard/features/otp/domain/totp.dart';

/// One account of the authenticator: where the codes come from and how.
///
/// A value: two accounts with the same fields are equal, the bytes of the
/// secret included, so a state that holds accounts can tell a change from a
/// repeat.
///
/// The secret is copied on the way in and on the way out, so nothing outside
/// can change it, and [toString] does not show it.
@immutable
class OtpAccount {
  /// Creates an account.
  ///
  /// [id] names the account in the storage and must not be empty. [issuer] is
  /// the service (GitHub) and may be `null`; [name] is the account on it
  /// (alex@example.com) and must not be empty. [digits] is 6 to 8 and [period]
  /// a positive number of seconds. A wrong value throws an [ArgumentError]
  /// that never contains the secret.
  OtpAccount({
    required this.id,
    required this.name,
    required Uint8List secret,
    this.issuer,
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
  }) : _secret = Uint8List.fromList(secret) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
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

  /// Names the account in the storage. Random, see `generateAccountId`.
  final String id;

  /// The service that issued the account, such as GitHub, or `null`.
  final String? issuer;

  /// The account on the service, such as alex@example.com.
  final String name;

  /// The shared secret. A copy: changing it does not change the account.
  Uint8List get secret => Uint8List.fromList(_secret);

  final Uint8List _secret;

  /// The hash function of the codes.
  final OtpAlgorithm algorithm;

  /// The length of a code.
  final int digits;

  /// How many seconds a code lives.
  final int period;

  /// The generator of the codes of this account.
  Totp toTotp() {
    return Totp(
      secret: _secret,
      digits: digits,
      period: period,
      algorithm: algorithm,
    );
  }

  /// Whether [other] gives the same codes under the same label: all fields
  /// equal except [id]. Scanning the same QR code twice makes two accounts
  /// that are the same source.
  bool isSameSourceAs(OtpAccount other) {
    return issuer == other.issuer &&
        name == other.name &&
        algorithm == other.algorithm &&
        digits == other.digits &&
        period == other.period &&
        _sameBytes(_secret, other._secret);
  }

  @override
  bool operator ==(Object other) {
    return other is OtpAccount && id == other.id && isSameSourceAs(other);
  }

  @override
  int get hashCode => Object.hash(
    id,
    issuer,
    name,
    algorithm,
    digits,
    period,
    Object.hashAll(_secret),
  );

  @override
  String toString() {
    return 'OtpAccount(id: $id, issuer: $issuer, name: $name, '
        'algorithm: ${algorithm.name}, digits: $digits, period: $period)';
  }
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
