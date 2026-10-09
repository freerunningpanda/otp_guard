import 'dart:typed_data';

import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';

/// The HOTP code of RFC 4226: a code for a [secret] and a [counter].
///
/// TOTP is HOTP whose counter is the number of the current time interval.
///
/// [digits] is 6 to 8, the range of the RFC. The result is a string, because
/// a code has leading zeros that a number would lose: `07081804`, not
/// `7081804`.
///
/// Throws an [ArgumentError] for an empty [secret], a negative [counter] or
/// [digits] outside 6 to 8. The error never contains the secret.
String hotp({
  required Uint8List secret,
  required int counter,
  int digits = 6,
  OtpAlgorithm algorithm = OtpAlgorithm.sha1,
}) {
  if (secret.isEmpty) {
    throw ArgumentError.value('<empty>', 'secret', 'must not be empty');
  }
  if (counter < 0) {
    throw ArgumentError.value(counter, 'counter', 'must not be negative');
  }
  if (digits < 6 || digits > 8) {
    throw ArgumentError.value(digits, 'digits', 'must be from 6 to 8');
  }

  final mac = algorithm.hmac(secret, _counterBytes(counter));

  // Dynamic truncation (RFC 4226, section 5.3). The low 4 bits of the last byte
  // say where to start, 4 bytes are taken from there, and the top bit is
  // cleared, so the result is a 31-bit number and is never negative.
  final offset = mac.last & 0x0F;
  final binary =
      ((mac[offset] & 0x7F) << 24) |
      ((mac[offset + 1] & 0xFF) << 16) |
      ((mac[offset + 2] & 0xFF) << 8) |
      (mac[offset + 3] & 0xFF);

  var modulus = 1;
  for (var i = 0; i < digits; i++) {
    modulus *= 10;
  }
  return (binary % modulus).toString().padLeft(digits, '0');
}

// The counter as 8 bytes, the most significant first. It is built byte by byte,
// not as a 32-bit number, so a large counter is not cut short. Division is used
// instead of shifts, because bit operations on a web platform work on 32 bits
// only.
Uint8List _counterBytes(int counter) {
  final bytes = Uint8List(8);
  var rest = counter;
  for (var i = 7; i >= 0; i--) {
    bytes[i] = rest % 256;
    rest ~/= 256;
  }
  return bytes;
}
