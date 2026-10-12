import 'dart:async';

import 'package:device_security/device_security.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/core/security/screen_security.dart';

/// Whether the native protection of the screen is on.
enum ProtectionStatus {
  /// [ScreenSecurityCubit.start] has not been answered yet. Not a warning: the
  /// answer comes in a moment, and a warning now would flash at every start.
  pending,

  /// The platform turned the protection on.
  enabled,

  /// The platform refused or could not be reached, so nothing blocks a
  /// screenshot or a recording. The screen must tell the user.
  failed,
}

/// What the screen knows about screenshots and screen recording.
class ScreenSecurityState extends Equatable {
  /// Creates the state.
  const ScreenSecurityState({
    this.protection = ProtectionStatus.pending,
    this.isRecording = false,
    this.screenshotCount = 0,
  });

  /// Whether the protection of the screen is on. The screen promises it, so a
  /// failure must not pass unseen.
  final ProtectionStatus protection;

  /// Whether the screen is being recorded or mirrored right now. The codes are
  /// hidden while it is.
  final bool isRecording;

  /// How many screenshots were taken since the screen opened. A counter, not a
  /// flag, so every screenshot is a new state and the screen can notify about
  /// each.
  final int screenshotCount;

  /// A copy with the given fields changed.
  ScreenSecurityState copyWith({
    ProtectionStatus? protection,
    bool? isRecording,
    int? screenshotCount,
  }) {
    return ScreenSecurityState(
      protection: protection ?? this.protection,
      isRecording: isRecording ?? this.isRecording,
      screenshotCount: screenshotCount ?? this.screenshotCount,
    );
  }

  @override
  List<Object?> get props => [protection, isRecording, screenshotCount];
}

/// Protects the screen with the codes while it is open, and follows the events
/// of the plugin.
///
/// The protection is turned on by [start] and off when the cubit closes. The
/// plugin watches for events only while somebody listens, so the subscription
/// lives exactly as long as the screen.
class ScreenSecurityCubit extends Cubit<ScreenSecurityState> {
  /// Creates the cubit.
  ScreenSecurityCubit(this._security) : super(const ScreenSecurityState());

  final ScreenSecurity _security;
  StreamSubscription<SecurityEvent>? _subscription;

  /// Turns the protection on and starts to listen.
  Future<void> start() async {
    // Listen first: the plugin reports at once a recording that is already
    // running, and that report must not be missed.
    _subscription = _security.events.listen(_onEvent, onError: _ignore);
    var protection = ProtectionStatus.enabled;
    try {
      await _security.setProtection(enabled: true);
    } on Exception {
      // The codes are still shown and the events still come: the plugin may be
      // missing on this platform, or have no window yet. But the user is told
      // that nothing blocks a screenshot, as the screen promises it does.
      protection = ProtectionStatus.failed;
    }
    // The screen may have gone while the platform was answering.
    if (isClosed) return;
    emit(state.copyWith(protection: protection));
  }

  void _onEvent(SecurityEvent event) {
    if (isClosed) return;
    switch (event) {
      case ScreenshotTaken():
        emit(state.copyWith(screenshotCount: state.screenshotCount + 1));
      case ScreenRecordingChanged(:final isRecording):
        emit(state.copyWith(isRecording: isRecording));
    }
  }

  // A damaged event is dropped. The plugin reports one as a stream error.
  void _ignore(Object error) {}

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    try {
      await _security.setProtection(enabled: false);
    } on Exception {
      // Nothing to do if it can not be turned off: the screen is going away.
    }
    return super.close();
  }
}
