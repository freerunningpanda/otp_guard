import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/lock/domain/constant_time.dart';

void main() {
  group('constantTimeEquals', () {
    test('equal bytes are equal', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(constantTimeEquals(<int>[], <int>[]), isTrue);
    });

    test('a difference is seen at any place', () {
      expect(constantTimeEquals([9, 2, 3], [1, 2, 3]), isFalse);
      expect(constantTimeEquals([1, 9, 3], [1, 2, 3]), isFalse);
      expect(constantTimeEquals([1, 2, 9], [1, 2, 3]), isFalse);
    });

    test('a single bit is enough', () {
      final a = Uint8List.fromList(List.filled(32, 0xAB));
      final b = Uint8List.fromList(a)..[31] ^= 1;

      expect(constantTimeEquals(a, b), isFalse);
    });

    test('a different length is a difference, in either order', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
      expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
      expect(constantTimeEquals([1, 2, 0], [1, 2]), isFalse);
      expect(constantTimeEquals([], [0]), isFalse);
    });
  });
}
