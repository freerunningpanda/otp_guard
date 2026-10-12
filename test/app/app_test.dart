import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:otp_guard/app/app.dart';
import 'package:otp_guard/app/injection.dart';
import 'package:otp_guard/app/router.dart';
import 'package:otp_guard/core/security/device_keys.dart';
import 'package:otp_guard/core/security/screen_security.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/core/time/system_clock.dart';
import 'package:otp_guard/features/lock/data/secure_lock_repository.dart';
import 'package:otp_guard/features/lock/domain/biometric_auth.dart';
import 'package:otp_guard/features/lock/domain/lock_repository.dart';
import 'package:otp_guard/features/lock/domain/pin_hasher.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/otp/data/key_value_store.dart';
import 'package:otp_guard/features/otp/domain/account_repository.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';

import '../support/fake_account_repository.dart';
import '../support/fake_clock.dart';
import '../support/fake_screen_security.dart';
import '../support/localizations.dart';
import '../support/lock_harness.dart';

void main() {
  group('the app, with the screens joined by the router', () {
    late GetIt getIt;
    late FakeAccountRepository repository;
    late LockHarness lock;

    setUp(() {
      repository = FakeAccountRepository();
      lock = LockHarness();
      var ids = 0;
      getIt = GetIt.asNewInstance()
        ..registerSingleton<Clock>(FakeClock.atUnix(59))
        ..registerSingleton<ScreenSecurity>(FakeScreenSecurity())
        ..registerSingleton<LockCubit>(lock.cubit)
        ..registerFactory<AccountsCubit>(
          () => AccountsCubit(repository, newId: () => 'new-${++ids}'),
        );
    });

    // The app closes the lock with its tree.
    tearDown(() => getIt.reset());

    // [language] is the language of the device, which the app follows.
    Future<void> openApp(
      WidgetTester tester, {
      Locale language = const Locale('ru'),
    }) async {
      tester.platformDispatcher.localesTestValue = [language];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      // These tests are about the screens, not the lock: it is open.
      await lock.setUpUnlocked();
      await tester.pumpWidget(
        App(
          getIt: getIt,
          router: createRouter(lock: lock.cubit),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('starts on the list, which is empty', (tester) async {
      await openApp(tester);

      expect(find.text(ru.appTitle), findsOneWidget);
      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    group('the language', () {
      testWidgets('follows the device: Russian', (tester) async {
        await openApp(tester);

        expect(find.text(ru.emptyTitle), findsOneWidget);
        expect(find.text(en.emptyTitle), findsNothing);
      });

      testWidgets('follows the device: English', (tester) async {
        await openApp(tester, language: const Locale('en'));

        expect(find.text(en.emptyTitle), findsOneWidget);
        expect(find.text(ru.emptyTitle), findsNothing);
      });

      testWidgets(
        'is English when the app has not the language of the device',
        (
          tester,
        ) async {
          await openApp(tester, language: const Locale('de'));

          expect(find.text(en.emptyTitle), findsOneWidget);
        },
      );

      testWidgets('is the title of the app in the language', (tester) async {
        await openApp(tester, language: const Locale('en'));

        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        final context = tester.element(find.byType(Scaffold));

        expect(app.onGenerateTitle!(context), en.appTitle);
      });
    });

    testWidgets('adds an account by typing and shows it in the list', (
      tester,
    ) async {
      await openApp(tester);

      await tester.tap(find.text(ru.addAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.enterManually));
      await tester.pumpAndSettle();
      expect(find.text(ru.manualTitle), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, ru.issuerLabel),
        'GitHub',
      );
      await tester.enterText(
        find.widgetWithText(TextField, ru.nameLabel),
        'alex',
      );
      await tester.enterText(
        find.widgetWithText(TextField, ru.secretLabel),
        'JBSWY3DPEHPK3PXP',
      );
      await tester.tap(find.text(ru.save));
      await tester.pumpAndSettle();

      // Back on the list, with the new row and the notice.
      expect(find.text(ru.manualTitle), findsNothing);
      expect(find.text('GitHub · alex'), findsOneWidget);
      expect(find.byKey(const Key('code-new-1')), findsOneWidget);
      expect(find.text(ru.accountAdded), findsOneWidget);
      expect(find.text(ru.emptyTitle), findsNothing);
    });

    testWidgets('the account added on one screen is on the others', (
      tester,
    ) async {
      // One cubit above the router: the form adds, the list shows.
      await openApp(tester);
      await tester.tap(find.text(ru.addAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.enterManually));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, ru.nameLabel),
        'alex',
      );
      await tester.enterText(
        find.widgetWithText(TextField, ru.secretLabel),
        'JBSWY3DPEHPK3PXP',
      );
      await tester.tap(find.text(ru.save));
      await tester.pumpAndSettle();

      expect(repository.accounts, hasLength(1));
      expect(find.text('alex'), findsOneWidget);
    });

    testWidgets('opens the page that checks the device key in a debug build', (
      tester,
    ) async {
      await openApp(tester);

      await tester.tap(find.byTooltip(ru.deviceKeyDemo));
      await tester.pumpAndSettle();

      expect(find.text('Device key demo'), findsOneWidget);
    });
  });

  group('configureDependencies', () {
    late GetIt getIt;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      getIt = GetIt.asNewInstance();
      configureDependencies(getIt);
    });

    tearDown(() => getIt.reset());

    test('registers everything the app asks for', () {
      expect(getIt<Clock>(), isA<SystemClock>());
      expect(getIt<KeyValueStore>(), isNotNull);
      expect(getIt<AccountRepository>(), isNotNull);
      expect(getIt<ScreenSecurity>(), isA<DeviceScreenSecurity>());
      expect(getIt<DeviceKeys>(), isA<DeviceSecurityKeys>());
      expect(getIt<LockRepository>(), isA<SecureLockRepository>());
      expect(getIt<PinHasher>().iterations, PinHasher.defaultIterations);
      expect(getIt<BiometricAuth>(), isNotNull);
    });

    test('gives the same instance of a service every time', () {
      expect(getIt<Clock>(), same(getIt<Clock>()));
      expect(getIt<AccountRepository>(), same(getIt<AccountRepository>()));
      expect(getIt<ScreenSecurity>(), same(getIt<ScreenSecurity>()));
    });

    test('gives one lock to the whole app', () {
      expect(getIt<LockCubit>(), same(getIt<LockCubit>()));
    });

    test('gives a new cubit every time, on the one repository', () async {
      final first = getIt<AccountsCubit>();
      final second = getIt<AccountsCubit>();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(first, isNot(same(second)));
      // Both read the same storage, which is empty.
      await first.load();
      await second.load();
      expect(first.state, second.state);
    });
  });
}
