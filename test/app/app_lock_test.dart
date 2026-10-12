import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:otp_guard/app/app.dart';
import 'package:otp_guard/app/router.dart';
import 'package:otp_guard/core/security/screen_security.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/features/lock/data/secure_lock_repository.dart';
import 'package:otp_guard/features/lock/domain/biometric_auth.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';

import '../support/accounts.dart';
import '../support/fake_account_repository.dart';
import '../support/fake_screen_security.dart';
import '../support/localizations.dart';
import '../support/lock_harness.dart';

const String alias = BiometricAuth.defaultAlias;

final Finder pinField = find.byKey(const Key('pin-field'));
final Finder confirmField = find.byKey(const Key('pin-confirm-field'));
final Finder unlockButton = find.byKey(const Key('unlock-button'));
final Finder biometricButton = find.byKey(const Key('biometric-button'));
final Finder createButton = find.byKey(const Key('pin-create-button'));

void main() {
  late LockHarness lock;
  late GetIt getIt;

  // The accounts are the ones the lock erases when the app is reset, so the
  // list and the lock see the same storage.
  FakeAccountRepository repository() => lock.accounts;

  setUp(() {
    lock = LockHarness();
    getIt = GetIt.asNewInstance()
      ..registerSingleton<Clock>(lock.clock)
      ..registerSingleton<ScreenSecurity>(FakeScreenSecurity())
      ..registerFactory<AccountsCubit>(() => AccountsCubit(repository()));
  });

  // The app closes the lock with its tree.
  tearDown(() => getIt.reset());

  // Starts the app as it starts on a phone: with a lock that has not read
  // anything yet, on a storage that [lock] has prepared.
  Future<LockCubit> startApp(WidgetTester tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final appLock = lock.newCubit();
    getIt.registerSingleton<LockCubit>(appLock);
    await tester.pumpWidget(
      App(
        getIt: getIt,
        router: createRouter(lock: appLock),
      ),
    );
    await tester.pumpAndSettle();
    return appLock;
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    await tester.enterText(pinField, pin);
    await tester.tap(unlockButton);
    await tester.pumpAndSettle();
  }

  Future<void> createPin(
    WidgetTester tester,
    String pin, {
    String? confirm,
  }) async {
    await tester.enterText(pinField, pin);
    await tester.enterText(confirmField, confirm ?? pin);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
  }

  // What the system does when the app goes to the background and comes back.
  void toBackground(WidgetTester tester) {
    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
  }

  Future<void> fromBackground(WidgetTester tester) async {
    [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pumpAndSettle();
  }

  // Turns the biometrics on in the storage of an app that is locked, as the
  // user did on an earlier run.
  Future<void> biometricsOn() async {
    await lock.cubit.unlockWithPin(testPin);
    await lock.cubit.enableBiometrics();
    lock.cubit.lock();
  }

  bool isDisabled(WidgetTester tester, Finder button) {
    return tester.widget<FilledButton>(button).onPressed == null;
  }

  group('the first start', () {
    testWidgets('asks for a PIN, and shows nothing of the app', (
      tester,
    ) async {
      await startApp(tester);

      expect(find.text(ru.pinSetupTitle), findsOneWidget);
      expect(find.text(ru.pinSetupHint), findsOneWidget);
      expect(find.text(ru.emptyTitle), findsNothing);
      expect(find.text(ru.addAccount), findsNothing);
    });

    testWidgets('says that the PIN does not encrypt anything', (tester) async {
      await startApp(tester);

      expect(ru.pinSetupHint, contains('не шифрует'));
      expect(en.pinSetupHint, contains('does not encrypt'));
    });

    testWidgets('a PIN opens the list and offers the biometrics', (
      tester,
    ) async {
      await startApp(tester);

      await createPin(tester, testPin);

      expect(find.text(ru.emptyTitle), findsOneWidget);
      expect(find.text(ru.biometricOfferTitle), findsOneWidget);
      expect(find.text(ru.biometricOfferBody), findsOneWidget);
    });

    testWidgets('"not now" leaves the biometrics off', (tester) async {
      await startApp(tester);
      await createPin(tester, testPin);

      await tester.tap(find.byKey(const Key('offer-decline')));
      await tester.pumpAndSettle();

      expect(find.text(ru.biometricOfferTitle), findsNothing);
      expect(find.text(ru.emptyTitle), findsOneWidget);
      expect(lock.keys.generateCount, 0);
    });

    testWidgets('"turn on" makes the key in the hardware', (tester) async {
      final appLock = await startApp(tester);
      await createPin(tester, testPin);

      await tester.tap(find.byKey(const Key('offer-accept')));
      await tester.pumpAndSettle();

      expect(lock.keys.hasKey(alias), isTrue);
      expect(appLock.state, isA<Unlocked>());
      expect((appLock.state as Unlocked).biometric, BiometricStatus.on);
      expect(find.text(ru.biometricOfferTitle), findsNothing);
    });

    testWidgets('a device without biometrics is told so', (tester) async {
      await startApp(tester);
      await createPin(tester, testPin);
      lock.keys.generateFailsWith = 'UNAVAILABLE';

      await tester.tap(find.byKey(const Key('offer-accept')));
      await tester.pumpAndSettle();

      expect(find.text(ru.biometricUnavailableOnDevice), findsOneWidget);
      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    testWidgets('a PIN that is too short is refused, with the rule', (
      tester,
    ) async {
      await startApp(tester);

      await createPin(tester, '1234');

      expect(find.text(ru.pinLengthError(6, 12)), findsOneWidget);
      expect(find.text(ru.pinSetupTitle), findsOneWidget);
      expect(lock.store.entries, isEmpty);
    });

    testWidgets('two PINs that differ are refused', (tester) async {
      await startApp(tester);

      await createPin(tester, testPin, confirm: '654321');

      expect(find.text(ru.pinMismatch), findsOneWidget);
      expect(find.text(ru.pinSetupTitle), findsOneWidget);
      expect(lock.store.entries, isEmpty);
    });

    testWidgets('only digits can be typed', (tester) async {
      await startApp(tester);

      await tester.enterText(pinField, '12ab34');

      expect(tester.widget<TextField>(pinField).controller!.text, '1234');
    });

    testWidgets('a storage that fails is reported, and nothing is set', (
      tester,
    ) async {
      await startApp(tester);
      lock.breakStorage(writes: (key) => true);

      await createPin(tester, testPin);

      expect(find.text(ru.pinSaveFailed), findsOneWidget);
      expect(find.text(ru.pinSetupTitle), findsOneWidget);
      expect(find.text(ru.emptyTitle), findsNothing);
    });

    testWidgets('the back button does not leave the setup', (tester) async {
      await startApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(ru.pinSetupTitle), findsOneWidget);
    });

    testWidgets('the PIN is typed hidden', (tester) async {
      await startApp(tester);

      expect(tester.widget<TextField>(pinField).obscureText, isTrue);
      expect(tester.widget<TextField>(confirmField).obscureText, isTrue);
    });
  });

  group('the lock screen', () {
    setUp(() async => lock.setUpLocked());

    testWidgets('is the first thing shown, and the list is not', (
      tester,
    ) async {
      await startApp(tester);

      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(find.text(ru.emptyTitle), findsNothing);
      expect(find.text(ru.addAccount), findsNothing);
      expect(biometricButton, findsNothing);
    });

    testWidgets('the right PIN opens the list', (tester) async {
      await startApp(tester);

      await typePin(tester, testPin);

      expect(find.text(ru.emptyTitle), findsOneWidget);
      expect(find.text(ru.lockTitle), findsNothing);
    });

    testWidgets('no question about biometrics after an ordinary unlock', (
      tester,
    ) async {
      await startApp(tester);

      await typePin(tester, testPin);

      expect(find.text(ru.biometricOfferTitle), findsNothing);
    });

    testWidgets('a wrong PIN is refused, and the field is empty again', (
      tester,
    ) async {
      await startApp(tester);

      await typePin(tester, '000000');

      expect(find.text(ru.pinWrong), findsOneWidget);
      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(tester.widget<TextField>(pinField).controller!.text, isEmpty);
    });

    testWidgets('the PIN is typed hidden', (tester) async {
      await startApp(tester);

      expect(tester.widget<TextField>(pinField).obscureText, isTrue);
    });

    testWidgets('the back button does not leave the lock', (tester) async {
      await startApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(ru.lockTitle), findsOneWidget);
    });

    testWidgets('after several wrong PINs a countdown is shown', (
      tester,
    ) async {
      await startApp(tester);

      for (var i = 0; i < 5; i++) {
        await typePin(tester, '000000');
      }

      expect(find.text(ru.pinWait('0:30')), findsOneWidget);
      expect(tester.widget<TextField>(pinField).enabled, isFalse);
      expect(isDisabled(tester, unlockButton), isTrue);
    });

    testWidgets('the countdown runs down with the clock, then ends', (
      tester,
    ) async {
      await startApp(tester);
      for (var i = 0; i < 5; i++) {
        await typePin(tester, '000000');
      }

      lock.clock.advance(const Duration(seconds: 10));
      await tester.pump();
      expect(find.text(ru.pinWait('0:20')), findsOneWidget);

      lock.clock.advance(const Duration(seconds: 20));
      await tester.pump();
      expect(find.textContaining('0:'), findsNothing);
      expect(tester.widget<TextField>(pinField).enabled, isTrue);
      expect(isDisabled(tester, unlockButton), isFalse);
    });

    testWidgets('the right PIN opens the list when the wait is over', (
      tester,
    ) async {
      await startApp(tester);
      for (var i = 0; i < 5; i++) {
        await typePin(tester, '000000');
      }

      lock.clock.advance(const Duration(seconds: 31));
      await tester.pump();
      await typePin(tester, testPin);

      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    testWidgets('the wait is still there after the app is started again', (
      tester,
    ) async {
      await startApp(tester);
      for (var i = 0; i < 5; i++) {
        await typePin(tester, '000000');
      }

      await tester.pumpWidget(const SizedBox());
      await getIt.unregister<LockCubit>();
      await startApp(tester);

      expect(find.text(ru.pinWait('0:30')), findsOneWidget);
      expect(isDisabled(tester, unlockButton), isTrue);
    });

    testWidgets('the screen speaks English on an English device', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final appLock = lock.newCubit();
      getIt.registerSingleton<LockCubit>(appLock);

      await tester.pumpWidget(
        App(
          getIt: getIt,
          router: createRouter(lock: appLock),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.lockTitle), findsOneWidget);
      expect(find.text(en.unlock), findsOneWidget);
      expect(find.text(ru.lockTitle), findsNothing);
    });
  });

  group('a PIN whose tries are used up', () {
    final blockedText = find.byKey(const Key('pin-blocked'));
    final forgotButton = find.byKey(const Key('forgot-pin-button'));

    setUp(() async => lock.setUpLocked());

    // Wrong PINs through the screen, waiting out each wait as a patient
    // guesser would.
    Future<void> useUpTries(WidgetTester tester, int count) async {
      for (var i = 0; i < count; i++) {
        await typePin(tester, '000000');
        lock.clock.advance(const Duration(hours: 2));
        await tester.pump();
      }
    }

    testWidgets('the tries before the last leave the field open', (
      tester,
    ) async {
      await startApp(tester);

      await useUpTries(tester, AttemptPolicy.maxAttempts - 1);

      expect(blockedText, findsNothing);
      expect(pinField, findsOneWidget);
      expect(unlockButton, findsOneWidget);
    });

    testWidgets('the last wrong try blocks the PIN: nothing to type', (
      tester,
    ) async {
      await startApp(tester);

      await useUpTries(tester, AttemptPolicy.maxAttempts);

      expect(blockedText, findsOneWidget);
      expect(find.text(ru.pinBlocked), findsOneWidget);
      expect(pinField, findsNothing);
      expect(unlockButton, findsNothing);
    });

    testWidgets('it shows no countdown, as time does not open it', (
      tester,
    ) async {
      await startApp(tester);

      await useUpTries(tester, AttemptPolicy.maxAttempts);

      expect(find.textContaining('Повторите через'), findsNothing);
    });

    testWidgets('only the reset is left when the biometrics are off', (
      tester,
    ) async {
      await startApp(tester);

      await useUpTries(tester, AttemptPolicy.maxAttempts);

      expect(biometricButton, findsNothing);
      expect(forgotButton, findsOneWidget);
    });

    testWidgets('it stays blocked when the app is started again', (
      tester,
    ) async {
      await startApp(tester);
      await useUpTries(tester, AttemptPolicy.maxAttempts);

      await tester.pumpWidget(const SizedBox());
      await getIt.unregister<LockCubit>();
      lock.clock.advance(const Duration(days: 365));
      await startApp(tester);

      expect(blockedText, findsOneWidget);
      expect(pinField, findsNothing);
    });

    testWidgets('it is read from the storage, too', (tester) async {
      await lock.repository.writeAttempts(
        PinAttempts(
          attempts: AttemptPolicy.maxAttempts,
          lastAttemptAt: lock.clock.now(),
          lockedUntil: lock.clock.now().add(const Duration(hours: 1)),
        ),
      );

      await startApp(tester);

      expect(blockedText, findsOneWidget);
    });

    testWidgets('the reset is the way out, and the new PIN is free', (
      tester,
    ) async {
      await startApp(tester);
      await useUpTries(tester, AttemptPolicy.maxAttempts);

      await tester.tap(forgotButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reset-confirm')));
      await tester.pumpAndSettle();
      expect(find.text(ru.pinSetupTitle), findsOneWidget);

      await createPin(tester, '654321');
      await tester.tap(find.byKey(const Key('offer-decline')));
      await tester.pumpAndSettle();
      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    testWidgets('the biometrics open the app, and the field is back', (
      tester,
    ) async {
      await biometricsOn();
      lock.keys.signFailsWith = 'USER_CANCELED';
      await startApp(tester);
      await useUpTries(tester, AttemptPolicy.maxAttempts);
      expect(blockedText, findsOneWidget);
      expect(biometricButton, findsOneWidget);

      lock.keys.signFailsWith = null;
      await tester.tap(biometricButton);
      await tester.pumpAndSettle();
      expect(find.text(ru.emptyTitle), findsOneWidget);

      // Locked again, with the prompt closed by the user, to see the screen.
      lock.keys.signFailsWith = 'USER_CANCELED';
      await tester.tap(find.byKey(const Key('lock-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-lock-now')));
      await tester.pumpAndSettle();
      expect(blockedText, findsNothing);
      expect(pinField, findsOneWidget);
    });

    testWidgets('the text speaks English on an English device', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await lock.repository.writeAttempts(
        PinAttempts(
          attempts: AttemptPolicy.maxAttempts,
          lastAttemptAt: lock.clock.now(),
        ),
      );
      final appLock = lock.newCubit();
      getIt.registerSingleton<LockCubit>(appLock);

      await tester.pumpWidget(
        App(
          getIt: getIt,
          router: createRouter(lock: appLock),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.pinBlocked), findsOneWidget);
      expect(en.pinBlocked, contains('blocked'));
      expect(ru.pinBlocked, contains('заблокирован'));
    });
  });

  group('a forgotten PIN', () {
    const newPin = '654321';
    final forgotButton = find.byKey(const Key('forgot-pin-button'));
    final confirmReset = find.byKey(const Key('reset-confirm'));
    final cancelReset = find.byKey(const Key('reset-cancel'));
    const oldAccount = 'GitHub · alex@example.com';

    setUp(() async {
      repository().accounts.add(testAccount());
      await lock.setUpLocked();
    });

    Future<void> askToReset(WidgetTester tester) async {
      await tester.tap(forgotButton);
      await tester.pumpAndSettle();
    }

    testWidgets('the lock screen offers a way out', (tester) async {
      await startApp(tester);

      expect(forgotButton, findsOneWidget);
      expect(find.text(ru.forgotPin), findsOneWidget);
    });

    testWidgets('it asks first, and says what will be lost', (tester) async {
      await startApp(tester);

      await askToReset(tester);

      expect(find.text(ru.resetTitle), findsOneWidget);
      expect(find.text(ru.resetBody), findsOneWidget);
      expect(ru.resetBody, contains('Все аккаунты'));
      expect(ru.resetBody, contains('резервные коды'));
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await startApp(tester);
      await askToReset(tester);

      await tester.tap(cancelReset);
      await tester.pumpAndSettle();

      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(find.text(ru.resetTitle), findsNothing);
      expect(repository().accounts, hasLength(1));
      expect(lock.store.entries, isNotEmpty);
    });

    testWidgets('confirming erases the accounts and asks for a new PIN', (
      tester,
    ) async {
      await startApp(tester);
      await askToReset(tester);

      await tester.tap(confirmReset);
      await tester.pumpAndSettle();

      expect(find.text(ru.pinSetupTitle), findsOneWidget);
      expect(find.text(ru.lockTitle), findsNothing);
      expect(repository().accounts, isEmpty);
      expect(lock.store.entries, isEmpty);
    });

    testWidgets('the list afterwards is empty, not the old one', (
      tester,
    ) async {
      await startApp(tester);
      await askToReset(tester);
      await tester.tap(confirmReset);
      await tester.pumpAndSettle();

      await createPin(tester, newPin);
      await tester.tap(find.byKey(const Key('offer-decline')));
      await tester.pumpAndSettle();

      expect(find.text(ru.emptyTitle), findsOneWidget);
      expect(find.text(oldAccount), findsNothing);
    });

    testWidgets('the old PIN does not open the new app', (tester) async {
      await startApp(tester);
      await askToReset(tester);
      await tester.tap(confirmReset);
      await tester.pumpAndSettle();
      await createPin(tester, newPin);
      await tester.tap(find.byKey(const Key('offer-decline')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lock-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-lock-now')));
      await tester.pumpAndSettle();
      await typePin(tester, testPin);
      expect(find.text(ru.pinWrong), findsOneWidget);

      await typePin(tester, newPin);
      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    testWidgets('it works while the PIN has to wait', (tester) async {
      await startApp(tester);
      for (var i = 0; i < 5; i++) {
        await typePin(tester, '000000');
      }
      expect(isDisabled(tester, unlockButton), isTrue);

      await askToReset(tester);
      await tester.tap(confirmReset);
      await tester.pumpAndSettle();

      expect(find.text(ru.pinSetupTitle), findsOneWidget);
    });

    testWidgets('a failure is reported, and the app stays locked', (
      tester,
    ) async {
      await startApp(tester);
      repository().failRemoving = true;
      await askToReset(tester);

      await tester.tap(confirmReset);
      await tester.pumpAndSettle();

      expect(find.text(ru.lockResetFailed), findsOneWidget);
      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(find.text(ru.pinSetupTitle), findsNothing);
    });

    testWidgets('and it can be tried again', (tester) async {
      await startApp(tester);
      repository().failRemoving = true;
      await askToReset(tester);
      await tester.tap(confirmReset);
      await tester.pumpAndSettle();

      repository().failRemoving = false;
      await askToReset(tester);
      await tester.tap(confirmReset);
      await tester.pumpAndSettle();

      expect(find.text(ru.pinSetupTitle), findsOneWidget);
    });

    testWidgets('the PIN still opens the app after a failed reset', (
      tester,
    ) async {
      await startApp(tester);
      repository().failRemoving = true;
      await askToReset(tester);
      await tester.tap(confirmReset);
      await tester.pumpAndSettle();

      await typePin(tester, testPin);

      expect(find.text(oldAccount), findsOneWidget);
    });

    testWidgets('it speaks English on an English device', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final appLock = lock.newCubit();
      getIt.registerSingleton<LockCubit>(appLock);
      await tester.pumpWidget(
        App(
          getIt: getIt,
          router: createRouter(lock: appLock),
        ),
      );
      await tester.pumpAndSettle();

      await askToReset(tester);

      expect(find.text(en.forgotPin), findsOneWidget);
      expect(find.text(en.resetTitle), findsOneWidget);
      expect(find.text(en.resetBody), findsOneWidget);
      expect(find.text(en.resetConfirm), findsOneWidget);
    });
  });

  group('when the lock can not be read', () {
    const oldAccount = 'GitHub · alex@example.com';
    final damagedReset = find.byKey(const Key('reset-damaged-button'));
    final confirmReset = find.byKey(const Key('reset-confirm'));
    final cancelReset = find.byKey(const Key('reset-cancel'));

    setUp(() async {
      repository().accounts.add(testAccount());
      await lock.setUpLocked();
    });

    group('because the storage failed', () {
      testWidgets('the app stays shut, and a retry can open the lock', (
        tester,
      ) async {
        lock.breakStorage(reads: true);

        await startApp(tester);
        expect(find.text(ru.lockLoadFailedTitle), findsOneWidget);
        expect(find.text(ru.lockDamagedTitle), findsNothing);
        expect(find.text(ru.emptyTitle), findsNothing);
        expect(find.text(ru.pinSetupTitle), findsNothing);

        lock.fixStorage();
        await tester.tap(find.text(ru.retry));
        await tester.pumpAndSettle();

        expect(find.text(ru.lockTitle), findsOneWidget);
      });

      testWidgets('there is no reset: it may work at the next try', (
        tester,
      ) async {
        lock.breakStorage(reads: true);

        await startApp(tester);

        expect(damagedReset, findsNothing);
        expect(find.text(ru.resetApp), findsNothing);
        expect(find.byKey(const Key('forgot-pin-button')), findsNothing);
        expect(repository().accounts, hasLength(1));
      });
    });

    group('because a record is damaged', () {
      setUp(() => lock.store.entries[SecureLockRepository.pinKey] = 'garbage');

      testWidgets('the app stays shut, and does not ask for a new PIN', (
        tester,
      ) async {
        await startApp(tester);

        expect(find.text(ru.lockDamagedTitle), findsOneWidget);
        expect(find.text(ru.lockDamagedBody), findsOneWidget);
        expect(find.text(ru.pinSetupTitle), findsNothing);
        expect(find.text(ru.emptyTitle), findsNothing);
        expect(find.text(ru.lockTitle), findsNothing);
      });

      testWidgets(
        'it says that trying again will not help, and offers the reset',
        (
          tester,
        ) async {
          await startApp(tester);

          expect(ru.lockDamagedBody, contains('повтор не поможет'));
          expect(damagedReset, findsOneWidget);
          expect(find.text(ru.resetApp), findsOneWidget);
        },
      );

      testWidgets('a retry reads the same record and gets the same screen', (
        tester,
      ) async {
        await startApp(tester);

        await tester.tap(find.text(ru.retry));
        await tester.pumpAndSettle();

        expect(find.text(ru.lockDamagedTitle), findsOneWidget);
      });

      testWidgets('the reset asks first, and cancelling changes nothing', (
        tester,
      ) async {
        await startApp(tester);

        await tester.tap(damagedReset);
        await tester.pumpAndSettle();
        expect(find.text(ru.resetTitle), findsOneWidget);
        expect(find.text(ru.resetBody), findsOneWidget);

        await tester.tap(cancelReset);
        await tester.pumpAndSettle();

        expect(find.text(ru.lockDamagedTitle), findsOneWidget);
        expect(repository().accounts, hasLength(1));
        expect(lock.store.entries, isNotEmpty);
      });

      testWidgets('confirming erases everything and asks for a new PIN', (
        tester,
      ) async {
        await startApp(tester);

        await tester.tap(damagedReset);
        await tester.pumpAndSettle();
        await tester.tap(confirmReset);
        await tester.pumpAndSettle();

        expect(find.text(ru.pinSetupTitle), findsOneWidget);
        expect(find.text(ru.lockDamagedTitle), findsNothing);
        expect(repository().accounts, isEmpty);
        expect(lock.store.entries, isEmpty);
      });

      testWidgets('then a new PIN opens an app with no old accounts', (
        tester,
      ) async {
        await startApp(tester);
        await tester.tap(damagedReset);
        await tester.pumpAndSettle();
        await tester.tap(confirmReset);
        await tester.pumpAndSettle();

        await createPin(tester, '654321');
        await tester.tap(find.byKey(const Key('offer-decline')));
        await tester.pumpAndSettle();

        expect(find.text(ru.emptyTitle), findsOneWidget);
        expect(find.text(oldAccount), findsNothing);
      });

      testWidgets(
        'a failure is shown, the record stays, and it can be retried',
        (
          tester,
        ) async {
          await startApp(tester);
          repository().failRemoving = true;
          await tester.tap(damagedReset);
          await tester.pumpAndSettle();

          await tester.tap(confirmReset);
          await tester.pumpAndSettle();

          expect(find.text(ru.lockResetFailed), findsOneWidget);
          expect(find.text(ru.lockDamagedTitle), findsOneWidget);
          expect(find.text(ru.pinSetupTitle), findsNothing);
          expect(repository().accounts, hasLength(1));

          repository().failRemoving = false;
          await tester.tap(damagedReset);
          await tester.pumpAndSettle();
          await tester.tap(confirmReset);
          await tester.pumpAndSettle();

          expect(find.text(ru.pinSetupTitle), findsOneWidget);
        },
      );

      testWidgets('the screen speaks English on an English device', (
        tester,
      ) async {
        tester.platformDispatcher.localesTestValue = [const Locale('en')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        final appLock = lock.newCubit();
        getIt.registerSingleton<LockCubit>(appLock);

        await tester.pumpWidget(
          App(
            getIt: getIt,
            router: createRouter(lock: appLock),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(en.lockDamagedTitle), findsOneWidget);
        expect(find.text(en.lockDamagedBody), findsOneWidget);
        expect(find.text(en.resetApp), findsOneWidget);
      });
    });

    testWidgets('a damaged record of the attempts is the same case', (
      tester,
    ) async {
      lock.store.entries[SecureLockRepository.attemptsKey] = '{';

      await startApp(tester);

      expect(find.text(ru.lockDamagedTitle), findsOneWidget);
      expect(damagedReset, findsOneWidget);
    });

    testWidgets('a damaged record of the biometrics is no case at all', (
      tester,
    ) async {
      lock.store.entries[SecureLockRepository.biometricKey] = 'garbage';

      await startApp(tester);

      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(find.text(ru.lockDamagedTitle), findsNothing);
    });
  });

  group('the biometrics', () {
    setUp(() async => lock.setUpLockedWithBiometrics());

    testWidgets('the prompt comes up by itself, with the texts of the app', (
      tester,
    ) async {
      await startApp(tester);

      final request = lock.keys.signRequests.single;
      expect(request.title, ru.biometricPromptTitle);
      expect(request.subtitle, ru.biometricPromptSubtitle);
      expect(request.cancelText, ru.cancel);
    });

    testWidgets('and the chip opens the list', (tester) async {
      await startApp(tester);

      expect(find.text(ru.emptyTitle), findsOneWidget);
      expect(find.text(ru.lockTitle), findsNothing);
    });

    testWidgets('the texts of the prompt follow the language', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final appLock = lock.newCubit();
      getIt.registerSingleton<LockCubit>(appLock);

      await tester.pumpWidget(
        App(
          getIt: getIt,
          router: createRouter(lock: appLock),
        ),
      );
      await tester.pumpAndSettle();

      final request = lock.keys.signRequests.single;
      expect(request.title, en.biometricPromptTitle);
      expect(request.subtitle, en.biometricPromptSubtitle);
      expect(request.cancelText, en.cancel);
    });

    testWidgets('a closed prompt leaves the PIN and a button to try again', (
      tester,
    ) async {
      lock.keys.signFailsWith = 'USER_CANCELED';
      await startApp(tester);

      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(biometricButton, findsOneWidget);
      expect(find.text(ru.lockBiometricFailed), findsNothing);
      expect(find.text(ru.lockBiometricUnavailable), findsNothing);

      lock.keys.signFailsWith = null;
      await tester.tap(biometricButton);
      await tester.pumpAndSettle();

      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    testWidgets('the PIN works after a closed prompt', (tester) async {
      lock.keys.signFailsWith = 'USER_CANCELED';
      await startApp(tester);

      await typePin(tester, testPin);

      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    testWidgets('a prompt that is not available points to the PIN', (
      tester,
    ) async {
      lock.keys.signFailsWith = 'BIOMETRY_UNAVAILABLE';
      await startApp(tester);

      expect(find.text(ru.lockBiometricUnavailable), findsOneWidget);
    });

    testWidgets('a signature that does not hold does not open the app', (
      tester,
    ) async {
      lock.keys.signWithAnotherKey = true;
      await startApp(tester);

      expect(find.text(ru.lockBiometricFailed), findsOneWidget);
      expect(find.text(ru.emptyTitle), findsNothing);
    });

    testWidgets('they work while the PIN has to wait', (tester) async {
      lock.keys.signFailsWith = 'USER_CANCELED';
      await startApp(tester);
      for (var i = 0; i < 5; i++) {
        await typePin(tester, '000000');
      }
      expect(isDisabled(tester, unlockButton), isTrue);

      lock.keys.signFailsWith = null;
      await tester.tap(biometricButton);
      await tester.pumpAndSettle();

      expect(find.text(ru.emptyTitle), findsOneWidget);
    });
  });

  group('KEY_INVALIDATED', () {
    setUp(() async {
      await lock.setUpLockedWithBiometrics();
      lock.keys.invalidate(alias);
    });

    testWidgets('the PIN is offered, with the reason', (tester) async {
      await startApp(tester);

      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(find.byKey(const Key('renewal-hint')), findsOneWidget);
      expect(find.text(ru.lockBiometricRenewalHint), findsOneWidget);
      expect(biometricButton, findsNothing);
      expect(find.text(ru.emptyTitle), findsNothing);
    });

    testWidgets('after the PIN, the app offers to turn the biometrics on', (
      tester,
    ) async {
      await startApp(tester);

      await typePin(tester, testPin);

      expect(find.text(ru.emptyTitle), findsOneWidget);
      expect(find.text(ru.biometricRenewTitle), findsOneWidget);
      expect(find.text(ru.biometricRenewBody), findsOneWidget);
    });

    testWidgets('accepting makes a new key that works', (tester) async {
      final appLock = await startApp(tester);
      await typePin(tester, testPin);
      final keysBefore = lock.keys.generateCount;

      await tester.tap(find.byKey(const Key('offer-accept')));
      await tester.pumpAndSettle();

      expect(lock.keys.generateCount, keysBefore + 1);
      expect(find.text(ru.biometricRenewTitle), findsNothing);

      appLock.lock();
      await tester.pumpAndSettle();
      // The prompt comes up and the new key signs.
      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    testWidgets('declining does not ask again', (tester) async {
      final appLock = await startApp(tester);
      await typePin(tester, testPin);

      await tester.tap(find.byKey(const Key('offer-decline')));
      await tester.pumpAndSettle();
      appLock.lock();
      await tester.pumpAndSettle();
      await typePin(tester, testPin);

      expect(find.text(ru.biometricRenewTitle), findsNothing);
      expect(find.text(ru.emptyTitle), findsOneWidget);
    });
  });

  group('locking again while the app is in use', () {
    setUp(() async {
      await lock.setUpLocked();
      repository().accounts.add(testAccount());
    });

    Future<void> unlocked(WidgetTester tester) async {
      await startApp(tester);
      await typePin(tester, testPin);
      expect(find.text('GitHub · alex@example.com'), findsOneWidget);
    }

    testWidgets('away for longer than the timeout, the lock is back', (
      tester,
    ) async {
      await unlocked(tester);

      toBackground(tester);
      lock.clock.advance(const Duration(minutes: 5));
      await fromBackground(tester);

      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(find.text('GitHub · alex@example.com'), findsNothing);
    });

    testWidgets('away for a short time, the list is still there', (
      tester,
    ) async {
      await unlocked(tester);

      toBackground(tester);
      lock.clock.advance(const Duration(seconds: 20));
      await fromBackground(tester);

      expect(find.text(ru.lockTitle), findsNothing);
      expect(find.text('GitHub · alex@example.com'), findsOneWidget);
    });

    testWidgets(
      'only inactive, as with a Face ID prompt, does not lock the app',
      (tester) async {
        await unlocked(tester);

        // The app becomes inactive and comes back, and a long time passes in
        // the meantime. It was never in the background.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        lock.clock.advance(const Duration(minutes: 10));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(find.text(ru.lockTitle), findsNothing);
        expect(find.text('GitHub · alex@example.com'), findsOneWidget);
      },
    );

    testWidgets('a Face ID unlock does not lock the app again', (
      tester,
    ) async {
      await biometricsOn();
      lock.keys.signFailsWith = 'USER_CANCELED';
      await startApp(tester);
      lock.keys.signFailsWith = null;

      // The user presses the button: the app goes inactive for the prompt, and
      // comes back after it. A long time may pass under the prompt.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.tap(biometricButton);
      lock.clock.advance(const Duration(minutes: 10));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(ru.lockTitle), findsNothing);
      expect(find.text('GitHub · alex@example.com'), findsOneWidget);
    });

    testWidgets('the lock then asks again, and the PIN opens the list', (
      tester,
    ) async {
      await unlocked(tester);
      toBackground(tester);
      lock.clock.advance(const Duration(minutes: 5));
      await fromBackground(tester);

      await typePin(tester, testPin);

      expect(find.text('GitHub · alex@example.com'), findsOneWidget);
    });

    testWidgets('a dialog that is open is closed when the app locks', (
      tester,
    ) async {
      await unlocked(tester);
      await tester.tap(find.byKey(const Key('menu-id-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-id-1')));
      await tester.pumpAndSettle();
      expect(find.text(ru.deleteTitle), findsOneWidget);

      toBackground(tester);
      lock.clock.advance(const Duration(minutes: 5));
      await fromBackground(tester);

      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(find.text(ru.deleteTitle), findsNothing);
      expect(find.text('GitHub · alex@example.com'), findsNothing);
    });

    testWidgets('any screen leads to the lock, and back to the list', (
      tester,
    ) async {
      await unlocked(tester);
      await tester.tap(find.text(ru.addAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.enterManually));
      await tester.pumpAndSettle();
      expect(find.text(ru.manualTitle), findsOneWidget);

      toBackground(tester);
      lock.clock.advance(const Duration(minutes: 5));
      await fromBackground(tester);
      expect(find.text(ru.lockTitle), findsOneWidget);
      expect(find.text(ru.manualTitle), findsNothing);

      await typePin(tester, testPin);
      expect(find.text(ru.manualTitle), findsNothing);
      expect(find.text('GitHub · alex@example.com'), findsOneWidget);
    });

    testWidgets('the menu locks the app at once', (tester) async {
      await unlocked(tester);

      await tester.tap(find.byKey(const Key('lock-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-lock-now')));
      await tester.pumpAndSettle();

      expect(find.text(ru.lockTitle), findsOneWidget);
    });
  });

  group('the menu and the biometrics', () {
    setUp(() async => lock.setUpLocked());

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('lock-menu')));
      await tester.pumpAndSettle();
    }

    testWidgets('turns them on, and then offers to turn them off', (
      tester,
    ) async {
      await startApp(tester);
      await typePin(tester, testPin);

      await openMenu(tester);
      expect(find.text(ru.menuBiometricsOn), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-biometrics')));
      await tester.pumpAndSettle();
      expect(lock.keys.hasKey(alias), isTrue);

      await openMenu(tester);
      expect(find.text(ru.menuBiometricsOff), findsOneWidget);
      expect(find.text(ru.menuBiometricsOn), findsNothing);
    });

    testWidgets('turns them off and deletes the key', (tester) async {
      await biometricsOn();
      await startApp(tester);
      expect(find.text(ru.emptyTitle), findsOneWidget);

      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-biometrics')));
      await tester.pumpAndSettle();

      expect(lock.keys.hasKey(alias), isFalse);
      await openMenu(tester);
      expect(find.text(ru.menuBiometricsOn), findsOneWidget);
    });

    testWidgets('tells a device that can not do it', (tester) async {
      await startApp(tester);
      await typePin(tester, testPin);
      lock.keys.generateFailsWith = 'BIOMETRY_UNAVAILABLE';

      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-biometrics')));
      await tester.pumpAndSettle();

      expect(find.text(ru.biometricUnavailableOnDevice), findsOneWidget);
      expect(lock.keys.hasKey(alias), isFalse);
    });
  });
}
