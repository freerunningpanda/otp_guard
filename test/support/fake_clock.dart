import 'dart:async';

import 'package:otp_guard/core/time/clock.dart';

/// A [Clock] that a test winds by hand. It does not move by itself.
class FakeClock implements Clock {
  FakeClock(DateTime start) : _now = start;

  /// A clock that stands at [seconds] after the start of 1970 (UTC).
  factory FakeClock.atUnix(int seconds) {
    return FakeClock(
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    );
  }

  DateTime _now;
  // Synchronous, so a tick is delivered inside `advance`. With the default
  // asynchronous delivery the tick can reach the widget after the frame that a
  // test pumps right away, and the test would read a stale value.
  final _controller = StreamController<DateTime>.broadcast(sync: true);

  @override
  DateTime now() => _now;

  @override
  Stream<DateTime> get ticks => _controller.stream;

  /// Moves the time on by [duration] and sends a tick.
  void advance(Duration duration) {
    _now = _now.add(duration);
    _controller.add(_now);
  }

  /// How many listeners the ticks have right now.
  bool get hasListeners => _controller.hasListener;
}
