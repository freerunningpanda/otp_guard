import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/domain/hotp.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';
import 'package:otp_guard/features/otp/domain/totp.dart';

Uint8List ascii(String text) => Uint8List.fromList(utf8.encode(text));

DateTime unix(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

DateTime unixMs(int milliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

void main() {
  // RFC 6238, appendix B. The table is made with three different secrets, one
  // for each algorithm. All are the digits 1234567890 repeated up to the size
  // of the hash: 20, 32 and 64 bytes. A secret of the wrong size gives other
  // codes, though the code is right.
  final secrets = {
    OtpAlgorithm.sha1: ascii('12345678901234567890'),
    OtpAlgorithm.sha256: ascii('12345678901234567890123456789012'),
    OtpAlgorithm.sha512: ascii(
      '1234567890123456789012345678901234567890123456789012345678901234',
    ),
  };

  test('the reference secrets have the sizes of the hashes', () {
    expect(secrets[OtpAlgorithm.sha1], hasLength(20));
    expect(secrets[OtpAlgorithm.sha256], hasLength(32));
    expect(secrets[OtpAlgorithm.sha512], hasLength(64));
  });

  group('Totp.codeAt, the vectors of RFC 6238 appendix B', () {
    // time, SHA-1, SHA-256, SHA-512; 8 digits, period 30.
    const table = [
      (59, '94287082', '46119246', '90693936'),
      (1111111109, '07081804', '68084774', '25091201'),
      (1111111111, '14050471', '67062674', '99943326'),
      (1234567890, '89005924', '91819424', '93441116'),
      (2000000000, '69279037', '90698825', '38618901'),
      (20000000000, '65353130', '77737706', '47863826'),
    ];
    for (final (seconds, sha1, sha256, sha512) in table) {
      final expected = {
        OtpAlgorithm.sha1: sha1,
        OtpAlgorithm.sha256: sha256,
        OtpAlgorithm.sha512: sha512,
      };
      for (final algorithm in OtpAlgorithm.values) {
        test('time $seconds, ${algorithm.name}: ${expected[algorithm]}', () {
          final totp = Totp(
            secret: secrets[algorithm]!,
            digits: 8,
            algorithm: algorithm,
          );

          expect(totp.codeAt(unix(seconds)), expected[algorithm]);
        });
      }
    }
  });

  group('Totp.codeAt, the boundary of the period', () {
    final totp = Totp(secret: secrets[OtpAlgorithm.sha1]!, digits: 8);
    final secret = secrets[OtpAlgorithm.sha1]!;

    test('the code changes exactly at the end of the period', () {
      final last = totp.codeAt(unixMs(29999));
      final first = totp.codeAt(unixMs(30000));

      expect(last, hotp(secret: secret, counter: 0, digits: 8));
      expect(first, hotp(secret: secret, counter: 1, digits: 8));
      expect(last, isNot(first));
    });

    test('the code is the same through the whole period', () {
      final code = totp.codeAt(unixMs(30000));

      expect(totp.codeAt(unixMs(30001)), code);
      expect(totp.codeAt(unixMs(45000)), code);
      expect(totp.codeAt(unixMs(59999)), code);
      expect(totp.codeAt(unixMs(60000)), isNot(code));
    });

    test('the code does not depend on the time zone of the DateTime', () {
      final utc = unix(1111111109);
      final local = DateTime.fromMillisecondsSinceEpoch(
        utc.millisecondsSinceEpoch,
      );

      expect(totp.codeAt(local), totp.codeAt(utc));
    });

    test('a period of 60 seconds changes the code at 60', () {
      final minute = Totp(secret: secret, digits: 8, period: 60);

      expect(
        minute.codeAt(unixMs(59999)),
        hotp(secret: secret, counter: 0, digits: 8),
      );
      expect(
        minute.codeAt(unixMs(60000)),
        hotp(secret: secret, counter: 1, digits: 8),
      );
    });

    test('the defaults are 6 digits, 30 seconds and SHA-1', () {
      final defaults = Totp(secret: secret);

      expect(defaults.digits, 6);
      expect(defaults.period, 30);
      expect(defaults.algorithm, OtpAlgorithm.sha1);
      // The last 6 digits of the 8-digit code 94287082 for the time 59.
      expect(defaults.codeAt(unix(59)), '287082');
    });

    test('a time before 1970 is an ArgumentError', () {
      expect(
        () => totp.codeAt(DateTime.utc(1969, 12, 31, 23, 59, 59)),
        throwsArgumentError,
      );
    });
  });

  group('Totp.intervalAt', () {
    final secret = secrets[OtpAlgorithm.sha1]!;
    final totp = Totp(secret: secret, digits: 8);

    test('counts the whole periods since 1970', () {
      expect(totp.intervalAt(unixMs(0)), 0);
      expect(totp.intervalAt(unixMs(29999)), 0);
      expect(totp.intervalAt(unixMs(30000)), 1);
      expect(totp.intervalAt(unixMs(59999)), 1);
      expect(totp.intervalAt(unixMs(60000)), 2);
    });

    test('is the counter that the code is made of', () {
      final time = unix(1111111109);

      expect(
        totp.codeAt(time),
        hotp(secret: secret, counter: totp.intervalAt(time), digits: 8),
      );
    });

    test('follows the period', () {
      final minute = Totp(secret: secret, period: 60);

      expect(minute.intervalAt(unixMs(59999)), 0);
      expect(minute.intervalAt(unixMs(60000)), 1);
    });

    test('a time before 1970 is an ArgumentError', () {
      expect(
        () => totp.intervalAt(DateTime.utc(1969, 12, 31, 23, 59, 59)),
        throwsArgumentError,
      );
    });
  });

  group('Totp.remaining', () {
    final totp = Totp(secret: secrets[OtpAlgorithm.sha1]!);

    test('at the start of an interval a whole period is left', () {
      expect(totp.remaining(unix(0)), const Duration(seconds: 30));
      expect(totp.remaining(unix(30)), const Duration(seconds: 30));
      expect(totp.remaining(unix(1111111110)), const Duration(seconds: 30));
    });

    test('at the end of an interval a millisecond is left', () {
      expect(totp.remaining(unixMs(29999)), const Duration(milliseconds: 1));
      expect(totp.remaining(unixMs(59999)), const Duration(milliseconds: 1));
    });

    test('in the middle of an interval it counts down', () {
      expect(totp.remaining(unix(1)), const Duration(seconds: 29));
      expect(totp.remaining(unix(59)), const Duration(seconds: 1));
      expect(
        totp.remaining(unixMs(10500)),
        const Duration(milliseconds: 19500),
      );
    });

    test('at the boundary the next code has begun, so it is never zero', () {
      for (final ms in [0, 30000, 60000, 1111111110000]) {
        expect(totp.remaining(unixMs(ms)), const Duration(seconds: 30));
      }
    });

    test('the remaining time ends exactly when the code changes', () {
      final time = unixMs(12345678);
      final before = totp.codeAt(time);
      final change = time.add(totp.remaining(time));

      expect(
        totp.codeAt(change.subtract(const Duration(milliseconds: 1))),
        before,
      );
      expect(totp.codeAt(change), isNot(before));
    });

    test('it follows the period', () {
      final minute = Totp(secret: secrets[OtpAlgorithm.sha1]!, period: 60);

      expect(minute.remaining(unix(0)), const Duration(seconds: 60));
      expect(minute.remaining(unix(45)), const Duration(seconds: 15));
    });

    test('a time before 1970 is an ArgumentError', () {
      expect(() => totp.remaining(unix(-1)), throwsArgumentError);
    });
  });

  group('Totp, the secret', () {
    final bytes = ascii('12345678901234567890');

    test('an empty secret is an ArgumentError', () {
      expect(() => Totp(secret: Uint8List(0)), throwsArgumentError);
    });

    test('digits outside 6 to 8 and a period below 1 are ArgumentErrors', () {
      expect(() => Totp(secret: bytes, digits: 5), throwsArgumentError);
      expect(() => Totp(secret: bytes, digits: 9), throwsArgumentError);
      expect(() => Totp(secret: bytes, period: 0), throwsArgumentError);
      expect(() => Totp(secret: bytes, period: -30), throwsArgumentError);
    });

    test('the secret is copied, so a later change of the list is harmless', () {
      final list = Uint8List.fromList(bytes);
      final totp = Totp(secret: list);
      final before = totp.codeAt(unix(59));

      list.fillRange(0, list.length, 0);

      expect(totp.codeAt(unix(59)), before);
    });

    test('toString does not show the secret', () {
      final totp = Totp(secret: ascii('SUPERSECRETSUPERSECRET'));

      expect(totp.toString(), isNot(contains('SUPERSECRET')));
      expect(totp.toString(), contains('digits: 6'));
    });
  });
}
