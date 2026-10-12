import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/presentation/security/screen_security_cubit.dart';

import '../../../../support/fake_screen_security.dart';

void main() {
  late FakeScreenSecurity security;
  late ScreenSecurityCubit cubit;

  setUp(() {
    security = FakeScreenSecurity();
    cubit = ScreenSecurityCubit(security);
  });

  tearDown(() => cubit.close());

  test('nothing happens before start', () {
    expect(cubit.state, const ScreenSecurityState());
    expect(security.protectionCalls, isEmpty);
    expect(security.hasListeners, isFalse);
  });

  test('start turns the protection on and listens', () async {
    await cubit.start();

    expect(security.protectionCalls, [true]);
    expect(security.hasListeners, isTrue);
  });

  group('the status of the protection', () {
    test('is pending until the platform answers', () async {
      final answer = Completer<void>();
      security.protectionAnswer = answer.future;

      final started = cubit.start();
      await pumpEventQueue();
      expect(cubit.state.protection, ProtectionStatus.pending);

      answer.complete();
      await started;
      expect(cubit.state.protection, ProtectionStatus.enabled);
    });

    test('is enabled when the platform turned the protection on', () async {
      await cubit.start();

      expect(cubit.state.protection, ProtectionStatus.enabled);
    });

    test('is failed when the platform could not turn it on', () async {
      security.failSettingProtection = true;

      await cubit.start();

      expect(cubit.state.protection, ProtectionStatus.failed);
    });

    test('is not touched by the events', () async {
      security.failSettingProtection = true;
      await cubit.start();

      security
        ..screenshot()
        ..recording(isRecording: true);
      await pumpEventQueue();

      expect(cubit.state.protection, ProtectionStatus.failed);
    });

    test('is not emitted when the screen is gone before the answer', () async {
      final answer = Completer<void>();
      security.protectionAnswer = answer.future;
      final started = cubit.start();
      await pumpEventQueue();

      await cubit.close();
      answer.complete();

      await expectLater(started, completes);
    });
  });

  test('a screenshot is counted, every one of them', () async {
    await cubit.start();

    security
      ..screenshot()
      ..screenshot();
    await pumpEventQueue();

    expect(cubit.state.screenshotCount, 2);
    expect(cubit.state.isRecording, isFalse);
  });

  test('recording is on from its start to its end', () async {
    await cubit.start();

    security.recording(isRecording: true);
    await pumpEventQueue();
    expect(cubit.state.isRecording, isTrue);

    security.recording(isRecording: false);
    await pumpEventQueue();
    expect(cubit.state.isRecording, isFalse);
  });

  test('a screenshot does not end a recording', () async {
    await cubit.start();
    security.recording(isRecording: true);
    await pumpEventQueue();

    security.screenshot();
    await pumpEventQueue();

    expect(cubit.state.isRecording, isTrue);
    expect(cubit.state.screenshotCount, 1);
  });

  test('a damaged event is dropped and the stream goes on', () async {
    await cubit.start();

    security
      ..damagedEvent()
      ..screenshot();
    await pumpEventQueue();

    expect(cubit.state.screenshotCount, 1);
  });

  test(
    'events are still followed when the protection can not be turned on',
    () async {
      security.failSettingProtection = true;

      await cubit.start();
      security.recording(isRecording: true);
      await pumpEventQueue();

      expect(cubit.state.isRecording, isTrue);
    },
  );

  test('closing turns the protection off and stops listening', () async {
    await cubit.start();

    await cubit.close();

    expect(security.protectionCalls, [true, false]);
    expect(security.hasListeners, isFalse);
  });

  test(
    'closing does not fail when the protection can not be turned off',
    () async {
      await cubit.start();
      security.failSettingProtection = true;

      await expectLater(cubit.close(), completes);
    },
  );
}
