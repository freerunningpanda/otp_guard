import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';

import '../../../support/fake_clock.dart';

void main() {
  group('AttemptPolicy.delayAfter', () {
    test('the first few attempts cost nothing', () {
      for (
        var attempts = 0;
        attempts <= AttemptPolicy.freeAttempts;
        attempts++
      ) {
        expect(AttemptPolicy.delayAfter(attempts), Duration.zero);
      }
    });

    test('then the wait grows with every attempt', () {
      final waits = [
        for (var i = 1; i <= 6; i++)
          AttemptPolicy.delayAfter(AttemptPolicy.freeAttempts + i),
      ];

      expect(waits, [
        const Duration(seconds: 30),
        const Duration(minutes: 1),
        const Duration(minutes: 5),
        const Duration(minutes: 15),
        const Duration(hours: 1),
        const Duration(hours: 1),
      ]);
      for (var i = 1; i < 5; i++) {
        expect(waits[i], greaterThan(waits[i - 1]));
      }
    });

    test('and stops at an hour', () {
      expect(AttemptPolicy.delayAfter(50), const Duration(hours: 1));
      expect(AttemptPolicy.delayAfter(100000), const Duration(hours: 1));
    });
  });

  group('the limit of attempts', () {
    PinAttempts after(int count) {
      var attempts = PinAttempts.none;
      for (var i = 0; i < count; i++) {
        attempts = attempts.afterAttempt(
          DateTime.utc(2026).add(Duration(days: i)),
        );
      }
      return attempts;
    }

    test('the PIN is good for ten tries in a row', () {
      expect(AttemptPolicy.maxAttempts, 10);
    });

    test('the tries before the last leave the PIN open', () {
      for (var count = 0; count < AttemptPolicy.maxAttempts; count++) {
        expect(after(count).isBlocked, isFalse, reason: '$count tries');
      }
    });

    test('the last try used up blocks the PIN', () {
      expect(after(AttemptPolicy.maxAttempts).isBlocked, isTrue);
    });

    test('and it stays blocked with more tries', () {
      expect(after(AttemptPolicy.maxAttempts + 1).isBlocked, isTrue);
      expect(after(500).isBlocked, isTrue);
    });

    test('time does not open it', () {
      final blocked = after(AttemptPolicy.maxAttempts);

      expect(blocked.isBlocked, isTrue);
      expect(blocked.remaining(DateTime.utc(2100)), Duration.zero);
      expect(blocked.isBlocked, isTrue, reason: 'no clock is asked');
    });

    test('the waits before the limit are not shortened by it', () {
      expect(
        AttemptPolicy.delayAfter(AttemptPolicy.maxAttempts - 1),
        const Duration(hours: 1),
      );
    });
  });

  group('PinAttempts', () {
    test('no attempts, no wait', () {
      const attempts = PinAttempts.none;

      expect(attempts.attempts, 0);
      expect(attempts.remaining(DateTime.utc(2026)), Duration.zero);
    });

    test('free attempts leave no wait', () {
      final clock = FakeClock.atUnix(1000);
      var attempts = PinAttempts.none;

      for (var i = 0; i < AttemptPolicy.freeAttempts; i++) {
        attempts = attempts.afterAttempt(clock.now());
      }

      expect(attempts.attempts, AttemptPolicy.freeAttempts);
      expect(attempts.lockedUntil, isNull);
      expect(attempts.remaining(clock.now()), Duration.zero);
    });

    test('the next attempt starts a wait, which grows', () {
      final clock = FakeClock.atUnix(1000);
      var attempts = PinAttempts.none;
      for (var i = 0; i < AttemptPolicy.freeAttempts; i++) {
        attempts = attempts.afterAttempt(clock.now());
      }

      attempts = attempts.afterAttempt(clock.now());
      expect(attempts.remaining(clock.now()), const Duration(seconds: 30));

      clock.advance(const Duration(seconds: 30));
      attempts = attempts.afterAttempt(clock.now());
      expect(attempts.remaining(clock.now()), const Duration(minutes: 1));

      clock.advance(const Duration(minutes: 1));
      attempts = attempts.afterAttempt(clock.now());
      expect(attempts.remaining(clock.now()), const Duration(minutes: 5));
    });

    test('the wait runs down with the clock and ends', () {
      final clock = FakeClock.atUnix(1000);
      final attempts = PinAttempts(
        attempts: 5,
        lastAttemptAt: clock.now(),
        lockedUntil: clock.now().add(const Duration(seconds: 30)),
      );

      clock.advance(const Duration(seconds: 10));
      expect(attempts.remaining(clock.now()), const Duration(seconds: 20));

      clock.advance(const Duration(seconds: 20));
      expect(attempts.remaining(clock.now()), Duration.zero);

      clock.advance(const Duration(hours: 5));
      expect(attempts.remaining(clock.now()), Duration.zero);
    });

    test('turning the clock back does not shorten the wait', () {
      final clock = FakeClock.atUnix(1000);
      final attempts = PinAttempts(
        attempts: 5,
        lastAttemptAt: clock.now(),
        lockedUntil: clock.now().add(const Duration(seconds: 30)),
      );

      clock.advance(const Duration(seconds: -3600));

      expect(attempts.remaining(clock.now()), const Duration(seconds: 30));
    });

    test('times are kept in UTC', () {
      final local = DateTime.fromMillisecondsSinceEpoch(5000);
      var attempts = PinAttempts.none;
      for (var i = 0; i < 5; i++) {
        attempts = attempts.afterAttempt(local);
      }

      expect(attempts.lastAttemptAt!.isUtc, isTrue);
      expect(attempts.lockedUntil!.isUtc, isTrue);
    });
  });
}
