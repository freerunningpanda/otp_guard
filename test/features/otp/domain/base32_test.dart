import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/domain/base32.dart';

String text(Uint8List bytes) => utf8.decode(bytes);

void main() {
  group('decodeBase32, the vectors of RFC 4648', () {
    const vectors = {
      'MY======': 'f',
      'MZXQ====': 'fo',
      'MZXW6===': 'foo',
      'MZXW6YQ=': 'foob',
      'MZXW6YTB': 'fooba',
      'MZXW6YTBOI======': 'foobar',
    };
    for (final entry in vectors.entries) {
      test('${entry.key} is "${entry.value}"', () {
        expect(text(decodeBase32(entry.key)), entry.value);
      });
    }
  });

  group('decodeBase32, what is accepted', () {
    test('an empty string is no bytes', () {
      expect(decodeBase32(''), isEmpty);
    });

    test('the case does not matter', () {
      expect(text(decodeBase32('mzxw6ytboi')), 'foobar');
      expect(text(decodeBase32('MzXw6yTbOi')), 'foobar');
    });

    test('spaces and line breaks are ignored', () {
      expect(text(decodeBase32('mzxw 6ytb\n oi')), 'foobar');
      expect(text(decodeBase32(' MZXW\t6YTB OI== ==== ')), 'foobar');
    });

    test('the padding at the end is optional', () {
      expect(text(decodeBase32('MY')), 'f');
      expect(text(decodeBase32('MZXQ')), 'fo');
      expect(text(decodeBase32('MZXW6YQ')), 'foob');
    });

    test('decodes a secret that services use in their examples', () {
      expect(
        decodeBase32('JBSWY3DPEHPK3PXP'),
        Uint8List.fromList([
          0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21, 0xde, 0xad, 0xbe, 0xef, //
        ]),
      );
    });
  });

  group('decodeBase32, what is refused', () {
    test('a character outside A-Z and 2-7 is a FormatException', () {
      // 0, 1, 8 and 9 are not in the alphabet, nor is anything else.
      for (final input in ['MZXW6YT0', 'MZXW6Y1B', 'MZXW68TB', '9ZXW6YTB']) {
        expect(() => decodeBase32(input), throwsFormatException, reason: input);
      }
      for (final input in ['MZXW-YTB', 'MZXW6YT!', 'MZXW6éTB']) {
        expect(() => decodeBase32(input), throwsFormatException, reason: input);
      }
    });

    test('a = that is not at the end is a FormatException', () {
      expect(() => decodeBase32('MY==MZXQ'), throwsFormatException);
      expect(() => decodeBase32('=MZXQ'), throwsFormatException);
    });

    test('a length that can not be whole bytes is a FormatException', () {
      // 1, 3 and 6 characters in the last group of 8.
      for (final input in ['M', 'MZX', 'MZXW6Y', 'MZXW6YTBM']) {
        expect(() => decodeBase32(input), throwsFormatException, reason: input);
      }
    });

    test('the message does not contain the input, which is a secret', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      try {
        decodeBase32('${secret}1');
        fail('a FormatException was expected');
      } on FormatException catch (e) {
        expect(e.toString(), isNot(contains(secret)));
        expect(e.message, isNot(contains(secret)));
      }
    });
  });
}
