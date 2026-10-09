import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/data/account_json.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';

OtpAccount account({
  String? issuer = 'GitHub',
  Uint8List? secret,
  OtpAlgorithm algorithm = OtpAlgorithm.sha1,
  int digits = 6,
  int period = 30,
}) {
  return OtpAccount(
    id: 'id-1',
    issuer: issuer,
    name: 'alex@example.com',
    secret: secret ?? Uint8List.fromList([1, 2, 3, 4, 5]),
    algorithm: algorithm,
    digits: digits,
    period: period,
  );
}

// A valid record as a map, to be damaged one field at a time.
Map<String, Object?> record([OtpAccount? source]) {
  return jsonDecode(encodeAccount(source ?? account())) as Map<String, Object?>;
}

String damaged(Map<String, Object?> Function(Map<String, Object?>) change) {
  return jsonEncode(change(record()));
}

void main() {
  group('encodeAccount and decodeAccount', () {
    test('give back the same account', () {
      for (final original in [
        account(),
        account(issuer: null),
        account(algorithm: OtpAlgorithm.sha256, digits: 8, period: 60),
        account(algorithm: OtpAlgorithm.sha512, digits: 7, period: 15),
      ]) {
        expect(
          decodeAccount(encodeAccount(original), expectedId: 'id-1'),
          original,
        );
      }
    });

    test('keep every byte value of the secret', () {
      final secret = Uint8List.fromList(List.generate(256, (i) => i));

      final restored = decodeAccount(
        encodeAccount(account(secret: secret)),
        expectedId: 'id-1',
      );

      expect(restored.secret, secret);
    });

    test('write a versioned record with the secret in Base64', () {
      final fields = record();

      expect(fields['v'], 1);
      expect(fields['id'], 'id-1');
      expect(fields['issuer'], 'GitHub');
      expect(fields['name'], 'alex@example.com');
      expect(fields['secret'], base64Encode([1, 2, 3, 4, 5]));
      expect(fields['algorithm'], 'sha1');
      expect(fields['digits'], 6);
      expect(fields['period'], 30);
    });
  });

  group('decodeAccount refuses a record that is', () {
    final cases = <String, String>{
      'not JSON': 'not json at all',
      'empty': '',
      'a JSON array': '[]',
      'a JSON string': '"text"',
      'an object without fields': '{"v":1,"id":"id-1"}',
      'of an unknown version': damaged((r) => {...r, 'v': 2}),
      'without a version': damaged((r) => {...r}..remove('v')),
      'under another id': damaged((r) => {...r, 'id': 'id-2'}),
      'with a name that is not a string': damaged((r) => {...r, 'name': 5}),
      'with an issuer that is not a string': damaged(
        (r) => {...r, 'issuer': 5},
      ),
      'with digits as a string': damaged((r) => {...r, 'digits': '6'}),
      'with a period as a double': damaged((r) => {...r, 'period': 30.5}),
      'with a secret that is not Base64': damaged(
        (r) => {...r, 'secret': '!!!'},
      ),
      'with an empty secret': damaged((r) => {...r, 'secret': ''}),
      'with an unknown algorithm': damaged((r) => {...r, 'algorithm': 'md5'}),
      'with digits outside 6 to 8': damaged((r) => {...r, 'digits': 5}),
      'with a period of zero': damaged((r) => {...r, 'period': 0}),
      'with an empty name': damaged((r) => {...r, 'name': ''}),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(
          () => decodeAccount(entry.value, expectedId: 'id-1'),
          throwsFormatException,
        );
      });
    }
  });

  test('no error message contains the secret, in Base64 or in the clear', () {
    final secret = Uint8List.fromList(utf8.encode('SUPERSECRETSUPERSECRET'));
    final secretInBase64 = base64Encode(secret);
    // Every kind of damage, with the secret still inside the record.
    final records = [
      damaged((r) => {...r, 'secret': secretInBase64, 'v': 2}),
      damaged((r) => {...r, 'secret': secretInBase64, 'id': 'id-2'}),
      damaged((r) => {...r, 'secret': secretInBase64, 'algorithm': 'md5'}),
      damaged((r) => {...r, 'secret': secretInBase64, 'digits': 99}),
      damaged((r) => {...r, 'secret': secretInBase64, 'name': 5}),
      '{"secret":"$secretInBase64"',
      secretInBase64,
    ];
    for (final text in records) {
      try {
        decodeAccount(text, expectedId: 'id-1');
        fail('a FormatException was expected');
      } on FormatException catch (e) {
        expect(e.toString(), isNot(contains('SUPERSECRET')));
        expect(e.toString(), isNot(contains(secretInBase64)));
      }
    }
  });
}
