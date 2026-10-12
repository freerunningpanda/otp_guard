import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_page.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_state.dart';
import 'package:otp_guard/features/otp/presentation/widgets/code_format.dart';

import '../../../../support/accounts.dart';
import '../../../../support/fake_account_repository.dart';
import '../../../../support/fake_clock.dart';
import '../../../../support/localizations.dart';
import '../../../../support/pump_app.dart';

DateTime atMs(int milliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

AccountsPage page({VoidCallback? onScan, VoidCallback? onManual}) {
  return AccountsPage(
    onScan: onScan ?? () {},
    onEnterManually: onManual ?? () {},
  );
}

String textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

// A snack bar stays for 4 seconds and then plays its exit animation, which only
// moves from frame to frame. One long pump would jump over it.
Future<void> letSnackBarGo(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
}

CircularProgressIndicator progressOf(WidgetTester tester, String id) =>
    tester.widget<CircularProgressIndicator>(find.byKey(Key('progress-$id')));

void main() {
  group('the states of the list', () {
    testWidgets('shows a spinner until the accounts are read', (tester) async {
      final env = TestEnvironment();
      await env.pump(tester, page());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(ru.emptyTitle), findsNothing);
    });

    testWidgets('shows the empty state when there are no accounts', (
      tester,
    ) async {
      final env = TestEnvironment();
      await env.pump(tester, page());
      await env.load(tester);

      expect(find.text(ru.emptyTitle), findsOneWidget);
      expect(find.text(ru.emptyHint), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows an error with a retry when the storage fails', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()])
          ..failReading = true,
      );
      await env.pump(tester, page());
      await env.load(tester);

      expect(find.text(ru.loadFailed), findsOneWidget);
      expect(find.byKey(const Key('code-id-1')), findsNothing);

      env.repository.failReading = false;
      await tester.tap(find.text(ru.retry));
      await tester.pump();
      await tester.pump();

      expect(find.text(ru.loadFailed), findsNothing);
      expect(find.byKey(const Key('code-id-1')), findsOneWidget);
    });

    testWidgets('warns about the records that could not be read', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(
          accounts: [testAccount()],
          unreadableIds: ['a', 'b'],
        ),
      );
      await env.pump(tester, page());
      await env.load(tester);

      expect(find.text(ru.unreadableWarning(2)), findsOneWidget);
      // The accounts that can be read are still there.
      expect(find.byKey(const Key('code-id-1')), findsOneWidget);
    });

    testWidgets('the warning is gone when nothing is unreadable', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
      );
      await env.pump(tester, page());
      await env.load(tester);

      expect(find.textContaining('Не удалось прочитать'), findsNothing);
    });
  });

  group('a row', () {
    testWidgets('shows the issuer, the name and the code in two groups', (
      tester,
    ) async {
      // RFC 4226 and 6238: time 59 is the interval 1, and its 6-digit code is
      // 287082.
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock.atUnix(59),
      );
      await env.pump(tester, page());
      await env.load(tester);

      expect(textOf(tester, const Key('code-id-1')), '287 082');
      expect(find.text('GitHub · alex@example.com'), findsOneWidget);
    });

    testWidgets('an account without an issuer shows the name only', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(
          accounts: [testAccount(issuer: null)],
        ),
      );
      await env.pump(tester, page());
      await env.load(tester);

      expect(find.text('alex@example.com'), findsOneWidget);
    });

    testWidgets('shows each account with its own code', (tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(
          accounts: [
            testAccount(),
            testAccount(id: 'id-2', name: 'bob', digits: 8),
          ],
        ),
        clock: FakeClock.atUnix(59),
      );
      await env.pump(tester, page());
      await env.load(tester);

      expect(textOf(tester, const Key('code-id-1')), '287 082');
      // The same time and secret with 8 digits: 94287082, RFC 6238.
      expect(textOf(tester, const Key('code-id-2')), '9428 7082');
    });

    testWidgets('the code changes exactly at the end of the period', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock(atMs(29999)),
      );
      await env.pump(tester, page());
      await env.load(tester);
      expect(textOf(tester, const Key('code-id-1')), '755 224');

      env.clock.advance(const Duration(milliseconds: 1));
      await tester.pump();

      expect(textOf(tester, const Key('code-id-1')), '287 082');
    });

    testWidgets('the code stays the same within the period', (tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock.atUnix(30),
      );
      await env.pump(tester, page());
      await env.load(tester);
      final first = textOf(tester, const Key('code-id-1'));

      for (var i = 0; i < 29; i++) {
        env.clock.advance(const Duration(seconds: 1));
        await tester.pump();
      }

      expect(textOf(tester, const Key('code-id-1')), first);
    });

    testWidgets('the indicator runs down as the time passes', (tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock.atUnix(0),
      );
      await env.pump(tester, page());
      await env.load(tester);

      expect(progressOf(tester, 'id-1').value, 1.0);
      expect(textOf(tester, const Key('seconds-id-1')), '30');

      env.clock.advance(const Duration(seconds: 10));
      await tester.pump();
      expect(progressOf(tester, 'id-1').value, closeTo(20 / 30, 1e-9));
      expect(textOf(tester, const Key('seconds-id-1')), '20');

      env.clock.advance(const Duration(seconds: 19));
      await tester.pump();
      expect(progressOf(tester, 'id-1').value, closeTo(1 / 30, 1e-9));
      expect(textOf(tester, const Key('seconds-id-1')), '1');
    });

    testWidgets('the indicator is full again when a new period begins', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock(atMs(29000)),
      );
      await env.pump(tester, page());
      await env.load(tester);
      expect(progressOf(tester, 'id-1').value, closeTo(1 / 30, 1e-9));

      env.clock.advance(const Duration(seconds: 1));
      await tester.pump();

      expect(progressOf(tester, 'id-1').value, 1.0);
      expect(textOf(tester, const Key('seconds-id-1')), '30');
    });

    testWidgets('the indicator follows the period of the account', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(
          accounts: [testAccount(period: 60)],
        ),
        clock: FakeClock.atUnix(30),
      );
      await env.pump(tester, page());
      await env.load(tester);

      expect(progressOf(tester, 'id-1').value, closeTo(0.5, 1e-9));
      expect(textOf(tester, const Key('seconds-id-1')), '30');
    });

    testWidgets('the last seconds are drawn as a warning', (tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock.atUnix(0),
      );
      await env.pump(tester, page());
      await env.load(tester);
      final colors = Theme.of(
        tester.element(find.byType(AccountsPage)),
      ).colorScheme;
      expect(progressOf(tester, 'id-1').color, colors.primary);

      env.clock.advance(const Duration(seconds: 25));
      await tester.pump();

      expect(progressOf(tester, 'id-1').color, colors.error);
    });

    testWidgets('a second passing does not change the state of the list', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
      );
      await env.pump(tester, page());
      await env.load(tester);
      final states = <AccountsState>[];
      final subscription = env.cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      for (var i = 0; i < 40; i++) {
        env.clock.advance(const Duration(seconds: 1));
        await tester.pump();
      }

      // The codes change, the state of the list does not: no rebuild.
      expect(states, isEmpty);
    });

    testWidgets('stops listening to the clock when the page goes away', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
      );
      await env.pump(tester, page());
      await env.load(tester);
      expect(env.clock.hasListeners, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(env.clock.hasListeners, isFalse);
    });
  });

  group('screen security', () {
    testWidgets('protects the screen while the page is open', (tester) async {
      final env = TestEnvironment();
      await env.pump(tester, page());
      await tester.pump();

      expect(env.security.protectionCalls, [true]);

      await tester.pumpWidget(const SizedBox());
      // Closing the cubit waits for the subscription to cancel, which takes a
      // turn of the real event loop, not of the fake one of the test.
      await tester.runAsync(pumpEventQueue);

      expect(env.security.protectionCalls, [true, false]);
      expect(env.security.hasListeners, isFalse);
    });

    group('when the protection can not be turned on', () {
      testWidgets('warns that nothing blocks a screenshot', (tester) async {
        final env = TestEnvironment(
          repository: FakeAccountRepository(accounts: [testAccount()]),
          clock: FakeClock.atUnix(59),
        );
        env.security.failSettingProtection = true;
        await env.pump(tester, page());
        await env.load(tester);
        await tester.pump();

        expect(find.text(ru.protectionFailedBanner), findsOneWidget);
      });

      testWidgets('still shows the codes', (tester) async {
        final env = TestEnvironment(
          repository: FakeAccountRepository(accounts: [testAccount()]),
          clock: FakeClock.atUnix(59),
        );
        env.security.failSettingProtection = true;
        await env.pump(tester, page());
        await env.load(tester);
        await tester.pump();

        expect(textOf(tester, const Key('code-id-1')), '287 082');
      });

      testWidgets('warns in the empty list too', (tester) async {
        final env = TestEnvironment();
        env.security.failSettingProtection = true;
        await env.pump(tester, page());
        await env.load(tester);
        await tester.pump();

        expect(find.text(ru.protectionFailedBanner), findsOneWidget);
        expect(find.text(ru.emptyTitle), findsOneWidget);
      });

      testWidgets('still hides the codes while the screen is recorded', (
        tester,
      ) async {
        final env = TestEnvironment(
          repository: FakeAccountRepository(accounts: [testAccount()]),
          clock: FakeClock.atUnix(59),
        );
        env.security.failSettingProtection = true;
        await env.pump(tester, page());
        await env.load(tester);
        await tester.pump();

        env.security.recording(isRecording: true);
        await tester.pump();
        await tester.pump();

        expect(textOf(tester, const Key('code-id-1')), hiddenCode);
        expect(find.text(ru.protectionFailedBanner), findsOneWidget);
        expect(find.text(ru.recordingBanner), findsOneWidget);
      });
    });

    group('when the protection is on', () {
      testWidgets('says nothing', (tester) async {
        final env = TestEnvironment(
          repository: FakeAccountRepository(accounts: [testAccount()]),
        );
        await env.pump(tester, page());
        await env.load(tester);
        await tester.pump();

        expect(find.text(ru.protectionFailedBanner), findsNothing);
      });

      testWidgets('says nothing while the platform has not answered', (
        tester,
      ) async {
        final env = TestEnvironment(
          repository: FakeAccountRepository(accounts: [testAccount()]),
        );
        final answer = Completer<void>();
        env.security.protectionAnswer = answer.future;
        await env.pump(tester, page());
        await env.load(tester);
        await tester.pump();

        expect(find.text(ru.protectionFailedBanner), findsNothing);

        answer.complete();
        await tester.pump();
        await tester.pump();
        expect(find.text(ru.protectionFailedBanner), findsNothing);
      });
    });

    testWidgets('hides the codes while the screen is recorded', (tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(
          accounts: [
            testAccount(),
            testAccount(id: 'id-2', name: 'bob'),
          ],
        ),
        clock: FakeClock.atUnix(59),
      );
      await env.pump(tester, page());
      await env.load(tester);
      expect(textOf(tester, const Key('code-id-1')), '287 082');
      expect(find.text(ru.recordingBanner), findsNothing);

      env.security.recording(isRecording: true);
      await tester.pump();
      await tester.pump();

      expect(textOf(tester, const Key('code-id-1')), hiddenCode);
      expect(textOf(tester, const Key('code-id-2')), hiddenCode);
      expect(find.textContaining('287'), findsNothing);
      expect(find.text(ru.recordingBanner), findsOneWidget);
    });

    testWidgets('keeps the codes hidden while the clock ticks', (tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock.atUnix(59),
      );
      await env.pump(tester, page());
      await env.load(tester);
      env.security.recording(isRecording: true);
      await tester.pump();

      env.clock.advance(const Duration(seconds: 1));
      await tester.pump();

      expect(textOf(tester, const Key('code-id-1')), hiddenCode);
      // The countdown goes on: only the code is hidden.
      expect(textOf(tester, const Key('seconds-id-1')), '30');
    });

    testWidgets('shows the codes again when the recording ends', (
      tester,
    ) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock.atUnix(59),
      );
      await env.pump(tester, page());
      await env.load(tester);
      env.security.recording(isRecording: true);
      await tester.pump();
      await tester.pump();

      env.security.recording(isRecording: false);
      await tester.pump();
      await tester.pump();

      expect(textOf(tester, const Key('code-id-1')), '287 082');
      expect(find.text(ru.recordingBanner), findsNothing);
    });

    testWidgets('hides the codes if the recording began before the page', (
      tester,
    ) async {
      // The plugin reports a recording that is already running as the first
      // event after the subscription.
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock.atUnix(59),
      );
      await env.pump(tester, page());
      env.security.recording(isRecording: true);
      await env.load(tester);
      await tester.pump();

      expect(textOf(tester, const Key('code-id-1')), hiddenCode);
    });

    testWidgets('tells about a screenshot, each time', (tester) async {
      final env = TestEnvironment();
      await env.pump(tester, page());
      await env.load(tester);

      env.security.screenshot();
      await tester.pump();
      await tester.pump();
      expect(find.text(ru.screenshotTaken), findsOneWidget);

      await letSnackBarGo(tester);
      expect(find.text(ru.screenshotTaken), findsNothing);

      env.security.screenshot();
      await tester.pump();
      await tester.pump();
      expect(find.text(ru.screenshotTaken), findsOneWidget);
    });

    testWidgets('a screenshot does not hide the codes', (tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
        clock: FakeClock.atUnix(59),
      );
      await env.pump(tester, page());
      await env.load(tester);

      env.security.screenshot();
      await tester.pump();

      expect(textOf(tester, const Key('code-id-1')), '287 082');
    });
  });

  group('deleting', () {
    Future<TestEnvironment> openWithOneAccount(WidgetTester tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(accounts: [testAccount()]),
      );
      await env.pump(tester, page());
      await env.load(tester);
      return env;
    }

    Future<void> chooseDelete(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('menu-id-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-id-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, and names the account', (tester) async {
      final env = await openWithOneAccount(tester);

      await chooseDelete(tester);

      expect(find.text(ru.deleteTitle), findsOneWidget);
      expect(find.text(ru.deleteBody('alex@example.com')), findsOneWidget);
      expect(env.repository.removed, isEmpty);
    });

    testWidgets('removes the account when confirmed', (tester) async {
      final env = await openWithOneAccount(tester);

      await chooseDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, ru.delete));
      await tester.pumpAndSettle();

      expect(env.repository.removed, ['id-1']);
      expect(find.byKey(const Key('code-id-1')), findsNothing);
      expect(find.text(ru.emptyTitle), findsOneWidget);
    });

    testWidgets('keeps the account when cancelled', (tester) async {
      final env = await openWithOneAccount(tester);

      await chooseDelete(tester);
      await tester.tap(find.text(ru.cancel));
      await tester.pumpAndSettle();

      expect(env.repository.removed, isEmpty);
      expect(find.byKey(const Key('code-id-1')), findsOneWidget);
    });

    testWidgets('tells the user when the storage fails', (tester) async {
      final env = await openWithOneAccount(tester);
      env.repository.failRemoving = true;

      await chooseDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, ru.delete));
      await tester.pumpAndSettle();

      expect(find.text(ru.deleteFailed), findsOneWidget);
      expect(find.byKey(const Key('code-id-1')), findsOneWidget);
    });

    testWidgets('removes the records that could not be read', (tester) async {
      final env = TestEnvironment(
        repository: FakeAccountRepository(
          accounts: [testAccount()],
          unreadableIds: ['a', 'b'],
        ),
      );
      await env.pump(tester, page());
      await env.load(tester);

      await tester.tap(find.text(ru.deleteUnreadable));
      await tester.pumpAndSettle();
      expect(find.text(ru.deleteUnreadableTitle), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, ru.delete),
        ),
      );
      await tester.pumpAndSettle();

      expect(env.repository.removed, ['a', 'b']);
      expect(find.text(ru.unreadableWarning(2)), findsNothing);
      expect(find.byKey(const Key('code-id-1')), findsOneWidget);
    });
  });

  group('adding', () {
    testWidgets('offers to scan or to type', (tester) async {
      final env = TestEnvironment();
      await env.pump(tester, page());
      await env.load(tester);

      await tester.tap(find.text(ru.addAccount));
      await tester.pumpAndSettle();

      expect(find.text(ru.scanQr), findsOneWidget);
      expect(find.text(ru.enterManually), findsOneWidget);
    });

    testWidgets('opens the scanner', (tester) async {
      var scanned = 0;
      final env = TestEnvironment();
      await env.pump(tester, page(onScan: () => scanned++));
      await env.load(tester);

      await tester.tap(find.text(ru.addAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.scanQr));
      await tester.pumpAndSettle();

      expect(scanned, 1);
      expect(find.text(ru.scanQr), findsNothing);
    });

    testWidgets('opens the form for typing', (tester) async {
      var typed = 0;
      final env = TestEnvironment();
      await env.pump(tester, page(onManual: () => typed++));
      await env.load(tester);

      await tester.tap(find.text(ru.addAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.enterManually));
      await tester.pumpAndSettle();

      expect(typed, 1);
    });
  });
}
