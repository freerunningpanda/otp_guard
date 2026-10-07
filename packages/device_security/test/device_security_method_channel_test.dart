import 'package:device_security/device_security_method_channel.dart';
import 'package:device_security/security_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelDeviceSecurity();
  final channel = platform.methodChannel;
  MethodCall? receivedCall;

  setUp(() {
    receivedCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          receivedCall = methodCall;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setScreenProtection', () async {
    await platform.setScreenProtection(enabled: true);

    expect(receivedCall?.method, 'setScreenProtection');
    expect(receivedCall?.arguments, <String, dynamic>{'enabled': true});
  });

  group('securityEvents', () {
    late MethodChannelDeviceSecurity eventsPlatform;

    // Stands in for the native side: onListen runs when Dart subscribes and
    // sends events through the sink, like the real handler would.
    void mockNative({
      void Function(MockStreamHandlerEventSink events)? onListen,
      void Function()? onCancel,
    }) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            eventsPlatform.eventChannel,
            MockStreamHandler.inline(
              onListen: (arguments, events) => onListen?.call(events),
              onCancel: (arguments) => onCancel?.call(),
            ),
          );
    }

    setUp(() {
      eventsPlatform = MethodChannelDeviceSecurity();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventsPlatform.eventChannel, null);
    });

    test('emits the events the native side sends', () async {
      mockNative(
        onListen: (events) {
          events
            ..success(<String, Object?>{
              'type': 'screenshotTaken',
              'timestamp': 1000,
            })
            ..success(<String, Object?>{
              'type': 'screenRecordingChanged',
              'timestamp': 2000,
              'isRecording': true,
            });
        },
      );

      final received = await eventsPlatform.securityEvents.take(2).toList();

      expect(
        received[0],
        isA<ScreenshotTaken>().having(
          (e) => e.timestamp,
          'timestamp',
          DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        ),
      );
      expect(
        received[1],
        isA<ScreenRecordingChanged>()
            .having((e) => e.isRecording, 'isRecording', true)
            .having(
              (e) => e.timestamp,
              'timestamp',
              DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
            ),
      );
    });

    test('skips an event with an unknown type', () async {
      mockNative(
        onListen: (events) {
          events
            ..success(<String, Object?>{
              'type': 'somethingNew',
              'timestamp': 500,
            })
            ..success(<String, Object?>{
              'type': 'screenshotTaken',
              'timestamp': 1000,
            });
        },
      );

      // The unknown event neither arrives nor breaks the stream: the first
      // event received is the one sent after it.
      final first = await eventsPlatform.securityEvents.first;

      expect(
        first,
        isA<ScreenshotTaken>().having(
          (e) => e.timestamp,
          'timestamp',
          DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        ),
      );
    });

    test('reports an event that is not a map as a stream error', () {
      mockNative(onListen: (events) => events.success('not a map'));

      expect(
        eventsPlatform.securityEvents,
        emitsError(isA<FormatException>()),
      );
    });

    test('returns the same stream on every access', () {
      expect(
        identical(eventsPlatform.securityEvents, eventsPlatform.securityEvents),
        isTrue,
      );
    });

    test('listens natively once and cancels after the last listener', () async {
      var listenCount = 0;
      var cancelCount = 0;
      mockNative(
        onListen: (events) => listenCount++,
        onCancel: () => cancelCount++,
      );

      final first = eventsPlatform.securityEvents.listen((_) {});
      final second = eventsPlatform.securityEvents.listen((_) {});
      await pumpEventQueue();

      expect(listenCount, 1);

      await first.cancel();
      await pumpEventQueue();
      expect(cancelCount, 0);

      await second.cancel();
      await pumpEventQueue();
      expect(cancelCount, 1);
    });
  });
}
