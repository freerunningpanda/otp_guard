import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/app/otp_auth_failure_message.dart';
import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';

import '../support/localizations.dart';

void main() {
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

  for (final (language, texts) in [('Russian', ru), ('English', en)]) {
    group('S.forFailure in $language', () {
      test('every kind of failure has its own message', () {
        final messages = failures.map(texts.forFailure).toList();

        expect(messages, everyElement(isNotEmpty));
        expect(messages.toSet(), hasLength(failures.length));
      });

      test('names the value that is wrong', () {
        expect(
          texts.forFailure(const UnsupportedOtpType('steam')),
          contains('steam'),
        );
        expect(
          texts.forFailure(const InvalidParameter('algorithm', 'MD5')),
          contains('MD5'),
        );
        expect(
          texts.forFailure(const InvalidParameter('digits', '5')),
          contains('5'),
        );
        expect(
          texts.forFailure(const InvalidParameter('period', '0')),
          contains('0'),
        );
        expect(
          texts.forFailure(const InvalidParameter('color', 'red')),
          allOf(contains('red'), contains('color')),
        );
      });

      test('says what to do about hotp', () {
        expect(
          texts.forFailure(const UnsupportedOtpType('hotp')),
          allOf(contains('HOTP'), contains('TOTP')),
        );
      });
    });
  }

  test('says what is allowed for the digits and the algorithm', () {
    expect(
      ru.forFailure(const InvalidParameter('digits', '5')),
      contains('6, 7 и 8'),
    );
    expect(
      en.forFailure(const InvalidParameter('digits', '5')),
      contains('6, 7 and 8'),
    );
    expect(
      ru.forFailure(const InvalidParameter('algorithm', 'MD5')),
      contains('SHA256'),
    );
  });
}
