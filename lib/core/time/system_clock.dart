import 'dart:async';

import 'package:otp_guard/core/time/clock.dart';

/// The [Clock] of the device.
class SystemClock implements Clock {
  /// Creates the clock.
  SystemClock();

  late final StreamController<DateTime> _controller =
      StreamController<DateTime>.broadcast(
        onListen: _scheduleNextTick,
        onCancel: _stop,
      );

  Timer? _timer;

  @override
  DateTime now() => DateTime.now();

  @override
  Stream<DateTime> get ticks => _controller.stream;

  // The timer waits for the start of the next second instead of running every
  // 1000 ms, so it does not drift: a code that changes at :30.000 is redrawn at
  // :30.00x, not up to a second later.
  void _scheduleNextTick() {
    final untilNextSecond = 1000 - now().millisecond;
    _timer = Timer(Duration(milliseconds: untilNextSecond), () {
      _controller.add(now());
      _scheduleNextTick();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
