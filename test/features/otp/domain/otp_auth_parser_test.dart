import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';
import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';

// JBSWY3DPEHPK3PXP in Base32.
final helloSecret = Uint8List.fromList([
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21, 0xde, 0xad, 0xbe, 0xef, //
]);

OtpAuthParseResult parse(String uri) => parseOtpAuthUri(uri, newId: () => 'id');

// The account of a link that is expected to be read.
OtpAccount parsed(String uri) {
  final result = parse(uri);
  expect(result, isA<OtpAuthParsed>(), reason: '$uri gave $result');
  return (result as OtpAuthParsed).account;
}

void main() {
  group('parseOtpAuthUri, a good link', () {
    test('reads the example of the task, field by field', () {
      final account = parsed(
        'otpauth://totp/GitHub:alex@example.com'
        '?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA1'
        '&digits=6&period=30',
      );

      expect(account.id, 'id');
      expect(account.issuer, 'GitHub');
      expect(account.name, 'alex@example.com');
      expect(account.secret, helloSecret);
      expect(account.algorithm, OtpAlgorithm.sha1);
      expect(account.digits, 6);
      expect(account.period, 30);
    });

    test('uses SHA-1, 6 digits and 30 seconds when they are not given', () {
      final account = parsed('otpauth://totp/alex?secret=JBSWY3DPEHPK3PXP');

      expect(account.algorithm, OtpAlgorithm.sha1);
      expect(account.digits, 6);
      expect(account.period, 30);
    });

    test('reads values other than the defaults', () {
      final account = parsed(
        'otpauth://totp/alex?secret=JBSWY3DPEHPK3PXP'
        '&algorithm=SHA512&digits=8&period=60',
      );

      expect(account.algorithm, OtpAlgorithm.sha512);
      expect(account.digits, 8);
      expect(account.period, 60);
    });

    test('ignores spaces around the link', () {
      final account = parsed('  otpauth://totp/alex?secret=JBSWY3DPEHPK3PXP\n');

      expect(account.name, 'alex');
    });

    test('takes the scheme and the type in any case', () {
      final account = parsed('OTPAUTH://TOTP/alex?secret=JBSWY3DPEHPK3PXP');

      expect(account.name, 'alex');
    });

    test('gives the account the id that the generator makes', () {
      var count = 0;
      final first = parseOtpAuthUri(
        'otpauth://totp/a?secret=JBSWY3DPEHPK3PXP',
        newId: () => 'id-${++count}',
      );
      final second = parseOtpAuthUri(
        'otpauth://totp/a?secret=JBSWY3DPEHPK3PXP',
        newId: () => 'id-${++count}',
      );

      expect((first as OtpAuthParsed).account.id, 'id-1');
      expect((second as OtpAuthParsed).account.id, 'id-2');
    });

    test('makes a random id when no generator is given', () {
      const uri = 'otpauth://totp/a?secret=JBSWY3DPEHPK3PXP';
      final first = (parseOtpAuthUri(uri) as OtpAuthParsed).account.id;
      final second = (parseOtpAuthUri(uri) as OtpAuthParsed).account.id;

      expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(first, isNot(second));
    });
  });

  group('parseOtpAuthUri, the label and the issuer', () {
    test('decodes %20, %3A and %40 in the label', () {
      final account = parsed(
        'otpauth://totp/Example%20Corp%3Aalex%40example.com'
        '?secret=JBSWY3DPEHPK3PXP',
      );

      expect(account.issuer, 'Example Corp');
      expect(account.name, 'alex@example.com');
    });

    test('decodes the issuer parameter, + as a space included', () {
      expect(
        parsed(
          'otpauth://totp/alex?secret=JBSWY3DPEHPK3PXP&issuer=Example%20Corp',
        ).issuer,
        'Example Corp',
      );
      expect(
        parsed(
          'otpauth://totp/alex?secret=JBSWY3DPEHPK3PXP&issuer=Example+Corp',
        ).issuer,
        'Example Corp',
      );
    });

    test('the issuer parameter wins over the issuer in the label', () {
      final account = parsed(
        'otpauth://totp/OldName:alex?secret=JBSWY3DPEHPK3PXP&issuer=NewName',
      );

      expect(account.issuer, 'NewName');
      expect(account.name, 'alex');
    });

    test('the issuer is the same in the label and the parameter', () {
      final account = parsed(
        'otpauth://totp/GitHub:alex?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      );

      expect(account.issuer, 'GitHub');
    });

    test('a label without an issuer is the account name only', () {
      final account = parsed(
        'otpauth://totp/alex@example.com?secret=JBSWY3DPEHPK3PXP',
      );

      expect(account.issuer, isNull);
      expect(account.name, 'alex@example.com');
    });

    test('an issuer only in the parameter is used', () {
      final account = parsed(
        'otpauth://totp/alex?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      );

      expect(account.issuer, 'GitHub');
    });

    test('an empty issuer parameter falls back to the label', () {
      final account = parsed(
        'otpauth://totp/GitHub:alex?secret=JBSWY3DPEHPK3PXP&issuer=',
      );

      expect(account.issuer, 'GitHub');
    });

    test('spaces around the colon of the label are dropped', () {
      final account = parsed(
        'otpauth://totp/GitHub:%20alex?secret=JBSWY3DPEHPK3PXP',
      );

      expect(account.issuer, 'GitHub');
      expect(account.name, 'alex');
    });

    test('the label splits at the first colon only', () {
      final account = parsed(
        'otpauth://totp/Issuer:name:with:colons?secret=JBSWY3DPEHPK3PXP',
      );

      expect(account.issuer, 'Issuer');
      expect(account.name, 'name:with:colons');
    });

    test('no label, or nothing after the issuer, is MissingLabel', () {
      for (final uri in [
        'otpauth://totp/?secret=JBSWY3DPEHPK3PXP',
        'otpauth://totp?secret=JBSWY3DPEHPK3PXP',
        'otpauth://totp/GitHub:?secret=JBSWY3DPEHPK3PXP',
        'otpauth://totp/%20?secret=JBSWY3DPEHPK3PXP',
      ]) {
        expect(parse(uri), const MissingLabel(), reason: uri);
      }
    });
  });

  group('parseOtpAuthUri, the secret', () {
    test('reads a secret in lower case, with spaces and with padding', () {
      final account = parsed(
        'otpauth://totp/a?secret=jbsw%20y3dp%20ehpk%203pxp%3D%3D',
      );

      expect(account.secret, helloSecret);
    });

    test('no secret parameter, or an empty one, is MissingSecret', () {
      for (final uri in [
        'otpauth://totp/a',
        'otpauth://totp/a?issuer=GitHub',
        'otpauth://totp/a?secret=',
        'otpauth://totp/a?secret=%20%20',
      ]) {
        expect(parse(uri), const MissingSecret(), reason: uri);
      }
    });

    test('a secret that is not Base32 is InvalidSecret', () {
      for (final secret in ['abc1', 'JBSWY3DP0', 'JBSWY3DP!', '====', 'M']) {
        expect(
          parse('otpauth://totp/a?secret=$secret'),
          const InvalidSecret(),
          reason: secret,
        );
      }
    });

    test('the failure for a bad secret has no trace of it', () {
      final result = parse('otpauth://totp/a?secret=JBSWY3DPEHPK3PXP1');

      expect(result, isA<InvalidSecret>());
      expect(result.toString(), isNot(contains('JBSWY3DPEHPK3PXP')));
    });
  });

  group('parseOtpAuthUri, what is not a supported link', () {
    test('hotp and any other type are UnsupportedOtpType', () {
      expect(
        parse('otpauth://hotp/a?secret=JBSWY3DPEHPK3PXP&counter=1'),
        const UnsupportedOtpType('hotp'),
      );
      expect(
        parse('otpauth://steam/a?secret=JBSWY3DPEHPK3PXP'),
        const UnsupportedOtpType('steam'),
      );
    });

    test('the type is checked before the rest', () {
      // A hotp link without a secret is reported as hotp, not as no secret.
      expect(parse('otpauth://hotp/a'), const UnsupportedOtpType('hotp'));
    });

    test('another scheme, or no link at all, is NotAnOtpAuthUri', () {
      for (final text in [
        '',
        '   ',
        'hello',
        'JBSWY3DPEHPK3PXP',
        'https://totp/a?secret=JBSWY3DPEHPK3PXP',
        'otpauth:totp/a?secret=JBSWY3DPEHPK3PXP',
        'otpauth://',
        'otpauth:///a?secret=JBSWY3DPEHPK3PXP',
      ]) {
        expect(parse(text), const NotAnOtpAuthUri(), reason: '"$text"');
      }
    });

    test('percent-encoding that is not valid UTF-8 is NotAnOtpAuthUri', () {
      for (final uri in [
        'otpauth://totp/a%ffb?secret=JBSWY3DPEHPK3PXP',
        'otpauth://totp/a%c3?secret=JBSWY3DPEHPK3PXP',
        'otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&issuer=%ff',
      ]) {
        expect(parse(uri), const NotAnOtpAuthUri(), reason: uri);
      }
    });

    test('a % that is not a sequence at all is kept as it is', () {
      // Uri does not decode %zz and does not fail on it.
      final account = parsed('otpauth://totp/a%zz?secret=JBSWY3DPEHPK3PXP');

      expect(account.name, 'a%zz');
    });
  });

  group('parseOtpAuthUri, the parameters', () {
    const base = 'otpauth://totp/a?secret=JBSWY3DPEHPK3PXP';

    test('algorithm is SHA1, SHA256 or SHA512 in any case', () {
      expect(parsed('$base&algorithm=sha256').algorithm, OtpAlgorithm.sha256);
      expect(parsed('$base&algorithm=SHA512').algorithm, OtpAlgorithm.sha512);
      expect(parsed('$base&algorithm=Sha1').algorithm, OtpAlgorithm.sha1);
    });

    test('any other algorithm is InvalidParameter', () {
      for (final value in ['MD5', 'SHA224', 'SHA-1', '']) {
        expect(
          parse('$base&algorithm=$value'),
          InvalidParameter('algorithm', value),
          reason: 'algorithm "$value"',
        );
      }
    });

    test('digits from 6 to 8 are read', () {
      for (final digits in [6, 7, 8]) {
        expect(parsed('$base&digits=$digits').digits, digits);
      }
    });

    test(
      'digits outside 6 to 8, or not a whole number, are InvalidParameter',
      () {
        for (final value in ['5', '9', '0', '-6', '10', 'abc', '6.5', '']) {
          expect(
            parse('$base&digits=$value'),
            InvalidParameter('digits', value),
            reason: 'digits "$value"',
          );
        }
      },
    );

    test('a positive period is read', () {
      for (final period in [1, 15, 60, 300]) {
        expect(parsed('$base&period=$period').period, period);
      }
    });

    test(
      'a period that is not positive or not a number is InvalidParameter',
      () {
        for (final value in ['0', '-30', 'abc', '30.5', '']) {
          expect(
            parse('$base&period=$value'),
            InvalidParameter('period', value),
            reason: 'period "$value"',
          );
        }
      },
    );
  });

  group('the results', () {
    test('equal results are equal', () {
      expect(
        const UnsupportedOtpType('hotp'),
        const UnsupportedOtpType('hotp'),
      );
      expect(
        const InvalidParameter('digits', '5'),
        const InvalidParameter('digits', '5'),
      );
      expect(const MissingSecret(), isNot(const InvalidSecret()));
      expect(
        const InvalidParameter('digits', '5'),
        isNot(const InvalidParameter('period', '5')),
      );
    });

    test(
      'the exhaustive switch over a result compiles and picks a message',
      () {
        String message(OtpAuthParseResult result) => switch (result) {
          OtpAuthParsed() => 'ok',
          NotAnOtpAuthUri() => 'not an otpauth link',
          UnsupportedOtpType(:final type) => 'unsupported $type',
          MissingLabel() => 'no account name',
          MissingSecret() => 'no secret',
          InvalidSecret() => 'bad secret',
          InvalidParameter(:final name) => 'bad $name',
        };

        expect(
          message(parse('otpauth://totp/a?secret=JBSWY3DPEHPK3PXP')),
          'ok',
        );
        expect(message(parse('otpauth://hotp/a')), 'unsupported hotp');
        expect(
          message(parse('otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&digits=5')),
          'bad digits',
        );
      },
    );
  });

  group('buildOtpAccount, what a person typed', () {
    OtpAccount built({String? issuer, String name = 'alex', String? secret}) {
      final result = buildOtpAccount(
        issuer: issuer,
        name: name,
        secret: secret ?? 'JBSWY3DPEHPK3PXP',
        newId: () => 'id',
      );
      expect(result, isA<OtpAuthParsed>(), reason: '$result');
      return (result as OtpAuthParsed).account;
    }

    test('makes an account with the defaults of the authenticators', () {
      final account = built(issuer: 'GitHub', name: 'alex@example.com');

      expect(account.id, 'id');
      expect(account.issuer, 'GitHub');
      expect(account.name, 'alex@example.com');
      expect(account.secret, helloSecret);
      expect(account.algorithm, OtpAlgorithm.sha1);
      expect(account.digits, 6);
      expect(account.period, 30);
    });

    test('drops spaces around the issuer and the name', () {
      final account = built(issuer: '  GitHub ', name: ' alex ');

      expect(account.issuer, 'GitHub');
      expect(account.name, 'alex');
    });

    test('no issuer, or an empty one, is no issuer', () {
      expect(built().issuer, isNull);
      expect(built(issuer: '').issuer, isNull);
      expect(built(issuer: '   ').issuer, isNull);
    });

    test('takes a secret written in groups and in lower case', () {
      expect(built(secret: 'jbsw y3dp ehpk 3pxp').secret, helloSecret);
    });

    test('an empty name is MissingLabel', () {
      for (final name in ['', '   ']) {
        expect(
          buildOtpAccount(name: name, secret: 'JBSWY3DPEHPK3PXP'),
          const MissingLabel(),
          reason: 'name "$name"',
        );
      }
    });

    test('an empty secret is MissingSecret', () {
      for (final secret in ['', '   ']) {
        expect(
          buildOtpAccount(name: 'alex', secret: secret),
          const MissingSecret(),
          reason: 'secret "$secret"',
        );
      }
    });

    test('a secret that is not Base32 is InvalidSecret', () {
      for (final secret in ['abc1', 'JBSWY3DP0', '====', 'M']) {
        expect(
          buildOtpAccount(name: 'alex', secret: secret),
          const InvalidSecret(),
          reason: 'secret "$secret"',
        );
      }
    });

    test('makes a random id when no generator is given', () {
      final result = buildOtpAccount(name: 'alex', secret: 'JBSWY3DPEHPK3PXP');

      expect(
        (result as OtpAuthParsed).account.id,
        matches(RegExp(r'^[0-9a-f]{32}$')),
      );
    });
  });
}
