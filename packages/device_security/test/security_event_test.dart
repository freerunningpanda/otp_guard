import 'package:device_security/security_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecurityEvent.fromMap', () {
    test('builds ScreenshotTaken', () {
      final event = SecurityEvent.fromMap(<Object?, Object?>{
        'type': 'screenshotTaken',
        'timestamp': 1000,
      });

      expect(event, isA<ScreenshotTaken>());
      expect(
        event?.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
    });

    test('builds ScreenRecordingChanged for both values of isRecording', () {
      for (final isRecording in [true, false]) {
        final event = SecurityEvent.fromMap(<Object?, Object?>{
          'type': 'screenRecordingChanged',
          'timestamp': 2000,
          'isRecording': isRecording,
        });

        expect(
          event,
          isA<ScreenRecordingChanged>()
              .having((e) => e.isRecording, 'isRecording', isRecording)
              .having(
                (e) => e.timestamp,
                'timestamp',
                DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
              ),
        );
      }
    });

    test('returns null for an unknown type', () {
      final event = SecurityEvent.fromMap(<Object?, Object?>{
        'type': 'somethingNew',
        'timestamp': 1000,
      });

      expect(event, isNull);
    });

    test('returns null for an unknown type without other fields', () {
      expect(SecurityEvent.fromMap(<Object?, Object?>{'type': 'x'}), isNull);
    });

    test('returns null when type is missing or not a string', () {
      expect(SecurityEvent.fromMap(<Object?, Object?>{}), isNull);
      expect(SecurityEvent.fromMap(<Object?, Object?>{'type': 1}), isNull);
    });

    test('throws when timestamp is missing or not an int', () {
      expect(
        () => SecurityEvent.fromMap(<Object?, Object?>{
          'type': 'screenshotTaken',
        }),
        throwsFormatException,
      );
      expect(
        () => SecurityEvent.fromMap(<Object?, Object?>{
          'type': 'screenshotTaken',
          'timestamp': '1000',
        }),
        throwsFormatException,
      );
    });

    test('throws when isRecording is missing or not a bool', () {
      expect(
        () => SecurityEvent.fromMap(<Object?, Object?>{
          'type': 'screenRecordingChanged',
          'timestamp': 2000,
        }),
        throwsFormatException,
      );
      expect(
        () => SecurityEvent.fromMap(<Object?, Object?>{
          'type': 'screenRecordingChanged',
          'timestamp': 2000,
          'isRecording': 'yes',
        }),
        throwsFormatException,
      );
    });
  });

  group('equality', () {
    final time = DateTime.utc(2026);

    test('events of the same type and fields are equal', () {
      expect(
        ScreenshotTaken(timestamp: time),
        ScreenshotTaken(timestamp: time),
      );
      expect(
        ScreenshotTaken(timestamp: time).hashCode,
        ScreenshotTaken(timestamp: time).hashCode,
      );
      expect(
        ScreenRecordingChanged(timestamp: time, isRecording: true),
        ScreenRecordingChanged(timestamp: time, isRecording: true),
      );
      expect(
        ScreenRecordingChanged(timestamp: time, isRecording: true).hashCode,
        ScreenRecordingChanged(timestamp: time, isRecording: true).hashCode,
      );
    });

    test('events that differ in any field are not equal', () {
      expect(
        ScreenshotTaken(timestamp: time),
        isNot(ScreenshotTaken(timestamp: time.add(const Duration(seconds: 1)))),
      );
      expect(
        ScreenRecordingChanged(timestamp: time, isRecording: true),
        isNot(ScreenRecordingChanged(timestamp: time, isRecording: false)),
      );
      expect(
        ScreenRecordingChanged(timestamp: time, isRecording: true),
        isNot(
          ScreenRecordingChanged(
            timestamp: time.add(const Duration(seconds: 1)),
            isRecording: true,
          ),
        ),
      );
    });

    test('events of different types are not equal', () {
      expect(
        ScreenshotTaken(timestamp: time),
        isNot(ScreenRecordingChanged(timestamp: time, isRecording: true)),
      );
    });
  });
}
