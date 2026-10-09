import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/core/time/system_clock.dart';

void main() {
  test('now is the time of the device', () {
    final before = DateTime.now();
    final now = SystemClock().now();
    final after = DateTime.now();

    expect(now.isBefore(before), isFalse);
    expect(now.isAfter(after), isFalse);
  });

  test('ticks come at the start of a second, and stop with the last '
      'listener', () async {
    final clock = SystemClock();
    final ticks = <DateTime>[];
    final subscription = clock.ticks.listen(ticks.add);

    await Future<void>.delayed(const Duration(milliseconds: 2300));
    await subscription.cancel();
    final count = ticks.length;

    // Two or three, by where in the second the test started.
    expect(count, inInclusiveRange(2, 3));
    // A tick comes a few milliseconds after the second begins, never before.
    for (final tick in ticks) {
      expect(tick.millisecond, lessThan(200));
    }

    // Nobody listens now, so the timer is stopped and nothing arrives.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(ticks, hasLength(count));
  });

  test('two listeners get the same ticks from one timer', () async {
    final clock = SystemClock();
    final first = <DateTime>[];
    final second = <DateTime>[];
    final subscriptions = [
      clock.ticks.listen(first.add),
      clock.ticks.listen(second.add),
    ];

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }

    expect(first, isNotEmpty);
    expect(first, second);
  });
}
