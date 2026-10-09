import 'dart:convert';

import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';

// The version of the record. A record of another version is not read, so a
// later change of the format can not be mistaken for a damaged record.
const _version = 1;

/// The record of [account] as JSON.
///
/// JSON has no bytes, so the secret is Base64. The record is the value of one
/// storage entry, and the storage encrypts it.
String encodeAccount(OtpAccount account) {
  return jsonEncode({
    'v': _version,
    'id': account.id,
    'issuer': account.issuer,
    'name': account.name,
    'secret': base64Encode(account.secret),
    'algorithm': account.algorithm.name,
    'digits': account.digits,
    'period': account.period,
  });
}

/// The account from a [record] that [encodeAccount] made.
///
/// [expectedId] is the id from the key of the entry; a record that says
/// another id was moved or damaged. Throws a [FormatException] for anything
/// wrong. The message is always one fixed text: the record holds a secret, and
/// an exception message ends up in logs.
OtpAccount decodeAccount(String record, {required String expectedId}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(record);
  } on FormatException {
    throw const FormatException('The record is not JSON');
  }
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('The record is not an object');
  }
  if (decoded['v'] != _version) {
    throw const FormatException('The record has an unknown version');
  }
  final id = decoded['id'];
  if (id != expectedId) {
    throw const FormatException('The record has another id than its key');
  }

  final issuer = decoded['issuer'];
  final name = decoded['name'];
  final secret = decoded['secret'];
  final algorithm = decoded['algorithm'];
  final digits = decoded['digits'];
  final period = decoded['period'];
  if ((issuer != null && issuer is! String) ||
      name is! String ||
      secret is! String ||
      algorithm is! String ||
      digits is! int ||
      period is! int) {
    throw const FormatException('The record has a field of a wrong type');
  }

  // The record is untrusted input. The account reports a value that it does not
  // allow, and an unknown algorithm name does the same, as an ArgumentError.
  // That must end as an unreadable record, never as a crash of the whole list.
  try {
    return OtpAccount(
      id: expectedId,
      issuer: issuer as String?,
      name: name,
      secret: base64Decode(secret),
      algorithm: OtpAlgorithm.values.byName(algorithm),
      digits: digits,
      period: period,
    );
  } on FormatException {
    throw const FormatException('The secret is not Base64');
    // See above: this is the one place where an Error is caught on purpose.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    throw const FormatException('The record is not a valid account');
  }
}
