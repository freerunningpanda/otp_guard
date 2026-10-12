import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/lock/domain/pin_policy.dart';

void main() {
  group('PinPolicy.check', () {
    test('accepts from the shortest to the longest', () {
      expect(PinPolicy.check('1' * PinPolicy.minLength), isNull);
      expect(PinPolicy.check('1' * PinPolicy.maxLength), isNull);
      expect(PinPolicy.check('012345'), isNull);
    });

    test('refuses a short one', () {
      expect(PinPolicy.check(''), PinProblem.tooShort);
      expect(
        PinPolicy.check('1' * (PinPolicy.minLength - 1)),
        PinProblem.tooShort,
      );
    });

    test('refuses a long one', () {
      expect(
        PinPolicy.check('1' * (PinPolicy.maxLength + 1)),
        PinProblem.tooLong,
      );
    });

    test('refuses what is not a digit of 0 to 9', () {
      expect(PinPolicy.check('12345a'), PinProblem.notDigits);
      expect(PinPolicy.check('12 456'), PinProblem.notDigits);
      expect(PinPolicy.check('12345٣'), PinProblem.notDigits);
      expect(PinPolicy.check('１２３４５６'), PinProblem.notDigits);
      expect(PinPolicy.check('123456\n'), PinProblem.notDigits);
    });
  });
}
