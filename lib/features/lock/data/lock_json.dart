import 'dart:convert';
import 'dart:typed_data';

import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';

// The version of a record. A record of another version is not read, so a later
// change of the format can not be mistaken for a damaged record.
const _version = 1;

// A record that says more rounds than this is not believed: it would keep the
// device busy for hours, and nobody sets a PIN that way.
const _maxIterations = 10000000;

/// The record of [credential] as JSON.
String encodePinCredential(PinCredential credential) {
  return jsonEncode({
    'v': _version,
    'alg': credential.algorithm.id,
    'iter': credential.iterations,
    'salt': base64Encode(credential.salt),
    'hash': base64Encode(credential.hash),
  });
}

/// The credential from a [record] that [encodePinCredential] made.
///
/// Throws a [FormatException] for anything wrong. The message is a fixed text:
/// an exception message ends up in logs, and the record holds a hash.
PinCredential decodePinCredential(String record) {
  final json = _object(record);
  final algorithm = switch (json['alg']) {
    final String id => PinHashAlgorithm.fromId(id),
    _ => null,
  };
  if (algorithm == null) {
    throw const FormatException('The PIN record has an unknown algorithm');
  }
  final iterations = json['iter'];
  if (iterations is! int || iterations < 1 || iterations > _maxIterations) {
    throw const FormatException('The PIN record has a wrong number of rounds');
  }
  final salt = _bytes(json['salt'], 'salt');
  final hash = _bytes(json['hash'], 'hash');
  return PinCredential(
    algorithm: algorithm,
    iterations: iterations,
    salt: salt,
    hash: hash,
  );
}

/// The record of [attempts] as JSON.
String encodeAttempts(PinAttempts attempts) {
  return jsonEncode({
    'v': _version,
    'attempts': attempts.attempts,
    'last': attempts.lastAttemptAt?.millisecondsSinceEpoch,
    'until': attempts.lockedUntil?.millisecondsSinceEpoch,
  });
}

/// The attempts from a [record] that [encodeAttempts] made. Throws a
/// [FormatException] for anything wrong.
PinAttempts decodeAttempts(String record) {
  final json = _object(record);
  final attempts = json['attempts'];
  if (attempts is! int || attempts < 0) {
    throw const FormatException('The attempts record has a wrong count');
  }
  return PinAttempts(
    attempts: attempts,
    lastAttemptAt: _time(json['last']),
    lockedUntil: _time(json['until']),
  );
}

/// The record of [setting] as JSON. [BiometricSetting.off] has none: it is
/// the absence of a record.
String encodeBiometricSetting(BiometricSetting setting) {
  return jsonEncode({
    'v': _version,
    'status': setting.status.name,
    if (setting.publicKey != null)
      'publicKey': base64Encode(setting.publicKey!),
  });
}

/// The setting from a [record] that [encodeBiometricSetting] made. Throws a
/// [FormatException] for anything wrong.
BiometricSetting decodeBiometricSetting(String record) {
  final json = _object(record);
  switch (json['status']) {
    case 'on':
      return BiometricSetting.enabled(_bytes(json['publicKey'], 'public key'));
    case 'needsRenewal':
      return BiometricSetting.needsRenewal;
  }
  throw const FormatException('The biometric record has an unknown status');
}

Map<String, Object?> _object(String record) {
  final Object? decoded;
  try {
    decoded = jsonDecode(record);
  } on FormatException {
    throw const FormatException('The lock record is not JSON');
  }
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('The lock record is not an object');
  }
  if (decoded['v'] != _version) {
    throw const FormatException('The lock record has an unknown version');
  }
  return decoded;
}

Uint8List _bytes(Object? value, String what) {
  if (value is! String) {
    throw FormatException('The lock record has no $what');
  }
  final Uint8List bytes;
  try {
    bytes = base64Decode(value);
  } on FormatException {
    throw FormatException('The lock record has a $what that is not Base64');
  }
  if (bytes.isEmpty) {
    throw FormatException('The lock record has an empty $what');
  }
  return bytes;
}

DateTime? _time(Object? value) {
  if (value == null) return null;
  if (value is! int) {
    throw const FormatException('The attempts record has a wrong time');
  }
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}
