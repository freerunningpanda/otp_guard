import 'package:device_security/device_security_method_channel.dart';
import 'package:device_security/security_event.dart';
import 'package:device_security/src/device_key_api.g.dart';
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

  group('device key api', () {
    const codec = DeviceKeyApi.pigeonChannelCodec;
    const methods = [
      'isDeviceSecure',
      'generateKey',
      'hasKey',
      'deleteKey',
      'sign',
    ];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final received = <String, Object?>{};

    String channelName(String method) =>
        'dev.flutter.pigeon.device_security.DeviceKeyApi.$method';

    // Stands in for the native side: Pigeon sends the arguments as a list and
    // expects a list back, [value] on success or [code, message, details].
    void mockHost(String method, Object? reply) {
      messenger.setMockMessageHandler(channelName(method), (message) async {
        received[method] = codec.decodeMessage(message);
        return codec.encodeMessage(reply);
      });
    }

    setUp(received.clear);

    tearDown(() {
      for (final method in methods) {
        messenger.setMockMessageHandler(channelName(method), null);
      }
    });

    test('isDeviceSecure returns the native answer', () async {
      mockHost('isDeviceSecure', <Object?>[true]);

      expect(await platform.isDeviceSecure(), isTrue);
    });

    test('generateKey sends the alias and returns the public key', () async {
      final publicKey = Uint8List.fromList([4, 5, 6]);
      mockHost('generateKey', <Object?>[publicKey]);

      expect(await platform.generateKey('login'), publicKey);
      expect(received['generateKey'], <Object?>['login']);
    });

    test('hasKey sends the alias and returns the native answer', () async {
      mockHost('hasKey', <Object?>[true]);

      expect(await platform.hasKey('login'), isTrue);
      expect(received['hasKey'], <Object?>['login']);
    });

    test('deleteKey sends the alias', () async {
      mockHost('deleteKey', <Object?>[null]);

      await platform.deleteKey('login');

      expect(received['deleteKey'], <Object?>['login']);
    });

    test(
      'sign sends the arguments, texts included, and returns the signature',
      () async {
        final challenge = Uint8List.fromList([1, 2, 3, 4]);
        final signature = Uint8List.fromList([0x30, 0x06, 1, 2]);
        mockHost('sign', <Object?>[signature]);

        final result = await platform.sign(
          'login',
          challenge,
          title: 'Confirm sign-in',
          subtitle: 'Sign the challenge',
          cancelText: 'Cancel',
        );

        expect(result, signature);
        expect(received['sign'], <Object?>[
          'login',
          challenge,
          'Confirm sign-in',
          'Sign the challenge',
          'Cancel',
        ]);
      },
    );

    test('sign sends a missing subtitle as null', () async {
      mockHost('sign', <Object?>[Uint8List(1)]);

      await platform.sign(
        'login',
        Uint8List(1),
        title: 'Confirm',
        cancelText: 'Cancel',
      );

      expect((received['sign']! as List<Object?>)[3], isNull);
    });

    test('every error code of sign arrives as a PlatformException', () async {
      for (final code in [
        'KEY_NOT_FOUND',
        'USER_CANCELED',
        'BIOMETRY_UNAVAILABLE',
        'KEY_INVALIDATED',
        'SIGNING_FAILED',
      ]) {
        mockHost('sign', <Object?>[code, 'message of $code', null]);

        await expectLater(
          platform.sign(
            'login',
            Uint8List(1),
            title: 'Confirm',
            cancelText: 'Cancel',
          ),
          throwsA(
            isA<PlatformException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.message, 'message', 'message of $code'),
          ),
        );
      }
    });

    test('a native error arrives as a PlatformException', () {
      mockHost('generateKey', <Object?>[
        'KEY_EXISTS',
        "A key with the alias 'login' already exists",
        null,
      ]);

      expect(
        platform.generateKey('login'),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'KEY_EXISTS')
              .having(
                (e) => e.message,
                'message',
                "A key with the alias 'login' already exists",
              ),
        ),
      );
    });
  });
}
