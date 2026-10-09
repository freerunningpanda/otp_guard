import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/domain/hotp.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';

Uint8List ascii(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  // RFC 4226, appendix D: the secret is the ASCII string below, 6 digits,
  // SHA-1, counters from 0 to 9.
  final secret = ascii('12345678901234567890');

  group('hotp, the vectors of RFC 4226 appendix D', () {
    const expected = [
      '755224',
      '287082',
      '359152',
      '969429',
      '338314',
      '254676',
      '287922',
      '162583',
      '399871',
      '520489',
    ];
    for (var counter = 0; counter < expected.length; counter++) {
      test('counter $counter gives ${expected[counter]}', () {
        expect(hotp(secret: secret, counter: counter), expected[counter]);
      });
    }
  });

  group('hotp, other lengths and counters', () {
    test('7 and 8 digits are the tail of the same 31-bit number', () {
      expect(hotp(secret: secret, counter: 0, digits: 7), '4755224');
      expect(hotp(secret: secret, counter: 0, digits: 8), '84755224');
    });

    test('a code keeps its leading zeros', () {
      // RFC 6238 gives 07081804 for the time 1111111109: 7081804 as a number
      // would be 7 digits.
      final code = hotp(secret: secret, counter: 37037036, digits: 8);

      expect(code, '07081804');
      expect(code, hasLength(8));
    });

    test('a counter above 32 bits is not cut short', () {
      // The expected values were made with Python's hmac, not with this code.
      const expected = {
        4294967295: '117190', // 2^32 - 1
        4294967296: '999456', // 2^32
        4294967297: '108930', // 2^32 + 1
        1099511627781: '726206', // 2^40 + 5
      };
      for (final entry in expected.entries) {
        expect(
          hotp(secret: secret, counter: entry.key),
          entry.value,
          reason: 'counter ${entry.key}',
        );
      }
    });

    test('the algorithm changes the code', () {
      final sha1 = hotp(secret: secret, counter: 1);
      final sha256 = hotp(
        secret: secret,
        counter: 1,
        algorithm: OtpAlgorithm.sha256,
      );
      final sha512 = hotp(
        secret: secret,
        counter: 1,
        algorithm: OtpAlgorithm.sha512,
      );

      expect({sha1, sha256, sha512}, hasLength(3));
    });
  });

  group('hotp, wrong arguments', () {
    test('an empty secret is an ArgumentError', () {
      expect(
        () => hotp(secret: Uint8List(0), counter: 0),
        throwsArgumentError,
      );
    });

    test('a negative counter is an ArgumentError', () {
      expect(() => hotp(secret: secret, counter: -1), throwsArgumentError);
    });

    test('digits outside 6 to 8 is an ArgumentError', () {
      for (final digits in [0, 5, 9, 10]) {
        expect(
          () => hotp(secret: secret, counter: 0, digits: digits),
          throwsArgumentError,
          reason: 'digits $digits',
        );
      }
    });
  });
}
