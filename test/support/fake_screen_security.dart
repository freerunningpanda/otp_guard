import 'dart:async';

import 'package:device_security/device_security.dart';
import 'package:flutter/services.dart';
import 'package:otp_guard/core/security/screen_security.dart';

/// A [ScreenSecurity] that a test drives: it sends events on demand and
/// records how the protection was switched.
class FakeScreenSecurity implements ScreenSecurity {
  final _controller = StreamController<SecurityEvent>.broadcast();

  /// Every value `setProtection` was called with, in order.
  final protectionCalls = <bool>[];

  /// If true, `setProtection` throws.
  bool failSettingProtection = false;

  /// If set, turning the protection on waits for it before it answers, so a
  /// test can look at the moment between the call and the answer. Turning it
  /// off is not held, or closing a cubit would wait as well.
  Future<void>? protectionAnswer;

  @override
  Future<void> setProtection({required bool enabled}) async {
    protectionCalls.add(enabled);
    if (enabled) await protectionAnswer;
    if (failSettingProtection) {
      // What the plugin throws when it has no window, or is missing.
      throw PlatformException(code: 'NO_ACTIVITY');
    }
  }

  @override
  Stream<SecurityEvent> get events => _controller.stream;

  /// Whether somebody listens to the events.
  bool get hasListeners => _controller.hasListener;

  /// A screenshot is taken.
  void screenshot() {
    _controller.add(ScreenshotTaken(timestamp: DateTime.utc(2026)));
  }

  /// The screen recording starts or stops.
  void recording({required bool isRecording}) {
    _controller.add(
      ScreenRecordingChanged(
        timestamp: DateTime.utc(2026),
        isRecording: isRecording,
      ),
    );
  }

  /// A damaged event, which the plugin reports as an error of the stream.
  void damagedEvent() {
    _controller.addError(const FormatException('damaged'));
  }
}
