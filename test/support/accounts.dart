import 'dart:convert';
import 'dart:typed_data';

import 'package:otp_guard/features/otp/domain/otp_account.dart';

/// The secret of the reference tests of RFC 4226 and RFC 6238 for SHA-1.
final referenceSecret = Uint8List.fromList(utf8.encode('12345678901234567890'));

/// The bytes of the Base32 secret JBSWY3DPEHPK3PXP.
final referenceSecretOfHello = Uint8List.fromList([
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21, 0xde, 0xad, 0xbe, 0xef, //
]);

/// An account with the reference secret. With it the codes are known:
/// counter 0 gives 755224, counter 1 gives 287082 (6 digits, SHA-1).
OtpAccount testAccount({
  String id = 'id-1',
  String? issuer = 'GitHub',
  String name = 'alex@example.com',
  Uint8List? secret,
  int digits = 6,
  int period = 30,
}) {
  return OtpAccount(
    id: id,
    issuer: issuer,
    name: name,
    secret: secret ?? referenceSecret,
    digits: digits,
    period: period,
  );
}
