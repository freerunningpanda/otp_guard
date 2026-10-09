import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:otp_guard/app/app.dart';
import 'package:otp_guard/app/injection.dart';
import 'package:otp_guard/app/router.dart';
import 'package:otp_guard/app/strings.dart';
import 'package:otp_guard/core/security/screen_security.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/core/time/system_clock.dart';
import 'package:otp_guard/features/otp/data/key_value_store.dart';
import 'package:otp_guard/features/otp/domain/account_repository.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';

import '../support/fake_account_repository.dart';
import '../support/fake_clock.dart';
import '../support/fake_screen_security.dart';

void main() {
  group('the app, with the screens joined by the router', () {
    late GetIt getIt;
    late FakeAccountRepository repository;

    setUp(() {
      repository = FakeAccountRepository();
      var ids = 0;
      getIt = GetIt.asNewInstance()
        ..registerSingleton<Clock>(FakeClock.atUnix(59))
        ..registerSingleton<ScreenSecurity>(FakeScreenSecurity())
        ..registerFactory<AccountsCubit>(
          () => AccountsCubit(repository, newId: () => 'new-${++ids}'),
        );
    });

    tearDown(() => getIt.reset());

    Future<void> openApp(WidgetTester tester) async {
      await tester.pumpWidget(App(getIt: getIt, router: createRouter()));
      await tester.pumpAndSettle();
    }

    testWidgets('starts on the list, which is empty', (tester) async {
      await openApp(tester);

      expect(find.text(Strings.appTitle), findsOneWidget);
      expect(find.text(Strings.emptyTitle), findsOneWidget);
    });

    testWidgets('adds an account by typing and shows it in the list', (
      tester,
    ) async {
      await openApp(tester);

      await tester.tap(find.text(Strings.addAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.enterManually));
      await tester.pumpAndSettle();
      expect(find.text(Strings.manualTitle), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, Strings.issuerLabel),
        'GitHub',
      );
      await tester.enterText(
        find.widgetWithText(TextField, Strings.nameLabel),
        'alex',
      );
      await tester.enterText(
        find.widgetWithText(TextField, Strings.secretLabel),
        'JBSWY3DPEHPK3PXP',
      );
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();

      // Back on the list, with the new row and the notice.
      expect(find.text(Strings.manualTitle), findsNothing);
      expect(find.text('GitHub · alex'), findsOneWidget);
      expect(find.byKey(const Key('code-new-1')), findsOneWidget);
      expect(find.text(Strings.accountAdded), findsOneWidget);
      expect(find.text(Strings.emptyTitle), findsNothing);
    });

    testWidgets('the account added on one screen is on the others', (
      tester,
    ) async {
      // One cubit above the router: the form adds, the list shows.
      await openApp(tester);
      await tester.tap(find.text(Strings.addAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.enterManually));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, Strings.nameLabel),
        'alex',
      );
      await tester.enterText(
        find.widgetWithText(TextField, Strings.secretLabel),
        'JBSWY3DPEHPK3PXP',
      );
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();

      expect(repository.accounts, hasLength(1));
      expect(find.text('alex'), findsOneWidget);
    });

    testWidgets('opens the page that checks the device key in a debug build', (
      tester,
    ) async {
      await openApp(tester);

      await tester.tap(find.byTooltip(Strings.deviceKeyDemo));
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
    });

    test('gives the same instance of a service every time', () {
      expect(getIt<Clock>(), same(getIt<Clock>()));
      expect(getIt<AccountRepository>(), same(getIt<AccountRepository>()));
      expect(getIt<ScreenSecurity>(), same(getIt<ScreenSecurity>()));
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
