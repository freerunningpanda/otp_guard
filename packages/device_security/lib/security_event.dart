import 'package:flutter/foundation.dart';

/// An event the native side reports over the events channel.
@immutable
sealed class SecurityEvent {
  const SecurityEvent({required this.timestamp});

  /// Builds an event from a map sent by the native side, by its `type` field.
  ///
  /// Returns `null` for a `type` this version does not know, so that a native
  /// side which starts sending a new type does not break an older Dart side.
  /// The caller drops the `null`.
  ///
  /// Throws a [FormatException] when the `type` is known but a field is
  /// missing or has the wrong type. That is a broken contract, not a new event.
  static SecurityEvent? fromMap(Map<Object?, Object?> map) {
    return switch (map['type']) {
      'screenshotTaken' => ScreenshotTaken(timestamp: _readTimestamp(map)),
      'screenRecordingChanged' => ScreenRecordingChanged(
        timestamp: _readTimestamp(map),
        isRecording: _readBool(map, 'isRecording'),
      ),
      _ => null,
    };
  }

  /// When the event happened on the device, in UTC.
  final DateTime timestamp;

  static DateTime _readTimestamp(Map<Object?, Object?> map) {
    final value = map['timestamp'];
    if (value is! int) {
      throw FormatException('Field "timestamp" must be an int', map);
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  static bool _readBool(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw FormatException('Field "$key" must be a bool', map);
    }
    return value;
  }
}

/// The user took a screenshot.
final class ScreenshotTaken extends SecurityEvent {
  /// Creates a [ScreenshotTaken] event.
  const ScreenshotTaken({required super.timestamp});

  @override
  bool operator ==(Object other) =>
      other is ScreenshotTaken && other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(ScreenshotTaken, timestamp);
}

/// Screen recording started or stopped.
final class ScreenRecordingChanged extends SecurityEvent {
  /// Creates a [ScreenRecordingChanged] event.
  const ScreenRecordingChanged({
    required super.timestamp,
    required this.isRecording,
  });

  /// Whether the screen is being recorded after this change.
  ///
  /// On iOS this is `UIScreen.isCaptured`, so it is also true while the screen
  /// is mirrored with AirPlay or to an external display.
  final bool isRecording;

  @override
  bool operator ==(Object other) =>
      other is ScreenRecordingChanged &&
      other.timestamp == timestamp &&
      other.isRecording == isRecording;

  @override
  int get hashCode =>
      Object.hash(ScreenRecordingChanged, timestamp, isRecording);
}
