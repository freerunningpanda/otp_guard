import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/domain/account_id.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';

Uint8List ascii(String text) => Uint8List.fromList(utf8.encode(text));

OtpAccount account({
  String id = 'id-1',
  String? issuer = 'GitHub',
  String name = 'alex@example.com',
  Uint8List? secret,
  OtpAlgorithm algorithm = OtpAlgorithm.sha1,
  int digits = 6,
  int period = 30,
}) {
  return OtpAccount(
    id: id,
    issuer: issuer,
    name: name,
    secret: secret ?? ascii('12345678901234567890'),
    algorithm: algorithm,
    digits: digits,
    period: period,
  );
}

void main() {
  group('OtpAccount equality', () {
    test('accounts with the same fields are equal, the secret included', () {
      expect(account(), account());
      expect(account().hashCode, account().hashCode);
    });

    test('a different value in any field makes accounts different', () {
      final differences = [
        account(id: 'id-2'),
        account(issuer: 'GitLab'),
        account(issuer: null),
        account(name: 'bob@example.com'),
        account(algorithm: OtpAlgorithm.sha256),
        account(digits: 8),
        account(period: 60),
        account(secret: ascii('12345678901234567891')),
      ];
      for (final other in differences) {
        expect(other, isNot(account()), reason: '$other');
      }
    });

    test('the secrets are compared by content, not by identity', () {
      final first = account(secret: Uint8List.fromList([1, 2, 3]));
      final second = account(secret: Uint8List.fromList([1, 2, 3]));

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('isSameSourceAs ignores the id and nothing else', () {
      expect(account().isSameSourceAs(account(id: 'id-2')), isTrue);
      expect(account().isSameSourceAs(account(name: 'bob')), isFalse);
      expect(account().isSameSourceAs(account(digits: 7)), isFalse);
      expect(
        account().isSameSourceAs(account(secret: ascii('another secret!!!!!'))),
        isFalse,
      );
    });
  });

  group('OtpAccount, the secret', () {
    test('the secret is copied in, so the caller can not change it', () {
      final bytes = ascii('12345678901234567890');
      final original = account(secret: bytes);

      bytes.fillRange(0, bytes.length, 0);

      expect(original, account());
    });

    test('the secret is copied out, so the caller can not change it', () {
      final original = account();

      original.secret.fillRange(0, 20, 0);

      expect(original, account());
    });

    test('toString does not show the secret in any form', () {
      final secret = ascii('SUPERSECRETSUPERSECRET');
      final text = account(secret: secret).toString();

      expect(text, isNot(contains('SUPERSECRET')));
      expect(text, isNot(contains(base64Encode(secret))));
      expect(text, contains('GitHub'));
      expect(text, contains('alex@example.com'));
    });
  });

  group('OtpAccount, values it does not allow', () {
    test('an empty id, name or secret is an ArgumentError', () {
      expect(() => account(id: ''), throwsArgumentError);
      expect(() => account(name: ''), throwsArgumentError);
      expect(() => account(secret: Uint8List(0)), throwsArgumentError);
    });

    test('digits outside 6 to 8 and a period below 1 are ArgumentErrors', () {
      expect(() => account(digits: 5), throwsArgumentError);
      expect(() => account(digits: 9), throwsArgumentError);
      expect(() => account(period: 0), throwsArgumentError);
      expect(() => account(period: -1), throwsArgumentError);
    });
  });

  test('toTotp makes the generator of the same codes', () {
    final totp = account(digits: 8).toTotp();

    // RFC 6238, appendix B: time 59, SHA-1, 8 digits.
    expect(totp.codeAt(DateTime.utc(1970, 1, 1, 0, 0, 59)), '94287082');
  });

  group('generateAccountId', () {
    test('is 32 hex digits', () {
      expect(generateAccountId(), matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('is different every time', () {
      final ids = {for (var i = 0; i < 100; i++) generateAccountId()};

      expect(ids, hasLength(100));
    });

    test('follows the generator it is given', () {
      expect(generateAccountId(Random(7)), generateAccountId(Random(7)));
      expect(generateAccountId(Random(7)), isNot(generateAccountId(Random(8))));
    });
  });
}
