import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/lock/presentation/format_wait.dart';

void main() {
  group('formatWait', () {
    test('seconds', () {
      expect(formatWait(const Duration(seconds: 30)), '0:30');
      expect(formatWait(const Duration(seconds: 5)), '0:05');
      expect(formatWait(const Duration(seconds: 1)), '0:01');
    });

    test('minutes and seconds', () {
      expect(formatWait(const Duration(minutes: 1)), '1:00');
      expect(formatWait(const Duration(minutes: 5)), '5:00');
      expect(formatWait(const Duration(minutes: 15, seconds: 9)), '15:09');
      expect(formatWait(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('hours from an hour on', () {
      expect(formatWait(const Duration(hours: 1)), '1:00:00');
      expect(
        formatWait(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('a part of a second counts as a second, never as zero', () {
      expect(formatWait(const Duration(milliseconds: 1)), '0:01');
      expect(formatWait(const Duration(milliseconds: 29001)), '0:30');
      expect(formatWait(const Duration(milliseconds: 29000)), '0:29');
    });

    test('no wait, and a wait below zero, are zero', () {
      expect(formatWait(Duration.zero), '0:00');
      expect(formatWait(const Duration(seconds: -5)), '0:00');
    });
  });
}
