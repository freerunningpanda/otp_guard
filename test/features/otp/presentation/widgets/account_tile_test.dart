import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/presentation/widgets/account_tile.dart';
import 'package:otp_guard/features/otp/presentation/widgets/code_format.dart';

import '../../../../support/accounts.dart';
import '../../../../support/fake_clock.dart';
import '../../../../support/localizations.dart';

String codeShown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('code-id-1'))).data!;

Future<void> pumpTile(
  WidgetTester tester, {
  required FakeClock clock,
  required OtpAccount account,
  bool hideCode = false,
}) {
  return tester.pumpWidget(
    RepositoryProvider<Clock>.value(
      value: clock,
      child: localizedApp(
        home: Scaffold(
          body: AccountTile(
            account: account,
            hideCode: hideCode,
            onDelete: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  // The reference secret gives 755224 for the interval 0 and 287082 for the
  // interval 1, see testAccount.
  testWidgets('the code is the same within an interval, new in the next one', (
    tester,
  ) async {
    final clock = FakeClock.atUnix(0);
    await pumpTile(tester, clock: clock, account: testAccount());
    expect(codeShown(tester), '755 224');

    clock.advance(const Duration(seconds: 29));
    await tester.pump();
    expect(codeShown(tester), '755 224');

    clock.advance(const Duration(seconds: 1));
    await tester.pump();
    expect(codeShown(tester), '287 082');
  });

  testWidgets(
    'another secret gives its own code at once, in the same interval',
    (
      tester,
    ) async {
      final clock = FakeClock.atUnix(10);
      await pumpTile(tester, clock: clock, account: testAccount());
      expect(codeShown(tester), '755 224');

      await pumpTile(
        tester,
        clock: clock,
        account: testAccount(secret: referenceSecretOfHello),
      );

      expect(codeShown(tester), isNot('755 224'));
      expect(codeShown(tester), matches(RegExp(r'^\d{3} \d{3}$')));
    },
  );

  testWidgets('the code is back at once when it stops being hidden', (
    tester,
  ) async {
    final clock = FakeClock.atUnix(10);
    await pumpTile(tester, clock: clock, account: testAccount());
    await pumpTile(
      tester,
      clock: clock,
      account: testAccount(),
      hideCode: true,
    );
    expect(codeShown(tester), hiddenCode);

    await pumpTile(tester, clock: clock, account: testAccount());

    expect(codeShown(tester), '755 224');
  });

  testWidgets('a code that was hidden is not shown after the interval ends', (
    tester,
  ) async {
    final clock = FakeClock.atUnix(10);
    await pumpTile(tester, clock: clock, account: testAccount());
    await pumpTile(
      tester,
      clock: clock,
      account: testAccount(),
      hideCode: true,
    );

    clock.advance(const Duration(seconds: 25));
    await tester.pump();
    await pumpTile(tester, clock: clock, account: testAccount());

    expect(codeShown(tester), '287 082');
  });
}
