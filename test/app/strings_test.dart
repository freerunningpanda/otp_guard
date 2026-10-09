import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/app/strings.dart';
import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';
import 'package:otp_guard/features/otp/presentation/widgets/code_format.dart';

void main() {
  group('Strings.forFailure', () {
    const failures = <OtpAuthFailure>[
      NotAnOtpAuthUri(),
      UnsupportedOtpType('hotp'),
      UnsupportedOtpType('steam'),
      MissingLabel(),
      MissingSecret(),
      InvalidSecret(),
      InvalidParameter('algorithm', 'MD5'),
      InvalidParameter('digits', '5'),
      InvalidParameter('period', '0'),
      InvalidParameter('color', 'red'),
    ];

    test('every kind of failure has its own message', () {
      final messages = failures.map(Strings.forFailure).toList();

      expect(messages, everyElement(isNotEmpty));
      expect(messages.toSet(), hasLength(failures.length));
    });

    test('says what to do about hotp and about an unknown type', () {
      expect(
        Strings.forFailure(const UnsupportedOtpType('hotp')),
        contains('HOTP'),
      );
      expect(
        Strings.forFailure(const UnsupportedOtpType('steam')),
        contains('steam'),
      );
    });

    test('names the value that is wrong, and what is allowed', () {
      expect(
        Strings.forFailure(const InvalidParameter('digits', '5')),
        allOf(contains('5'), contains('6, 7 и 8')),
      );
      expect(
        Strings.forFailure(const InvalidParameter('algorithm', 'MD5')),
        allOf(contains('MD5'), contains('SHA256')),
      );
      expect(
        Strings.forFailure(const InvalidParameter('period', '0')),
        contains('0'),
      );
    });
  });

  group('formatCode', () {
    test('splits 6 digits in two groups of 3', () {
      expect(formatCode('123456'), '123 456');
    });

    test('splits 8 digits in two groups of 4', () {
      expect(formatCode('12345678'), '1234 5678');
    });

    test('splits 7 digits into 3 and 4', () {
      expect(formatCode('1234567'), '123 4567');
    });

    test('keeps the leading zeros', () {
      expect(formatCode('007081'), '007 081');
    });
  });
}
