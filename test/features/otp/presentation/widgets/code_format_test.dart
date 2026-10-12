import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/presentation/widgets/code_format.dart';

void main() {
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
