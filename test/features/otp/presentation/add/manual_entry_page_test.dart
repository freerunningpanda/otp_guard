import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/app/strings.dart';
import 'package:otp_guard/features/otp/presentation/add/manual_entry_page.dart';

import '../../../../support/accounts.dart';
import '../../../../support/fake_account_repository.dart';
import '../../../../support/pump_app.dart';

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> fill(
  WidgetTester tester, {
  String issuer = '',
  String name = '',
  String secret = '',
}) async {
  await tester.enterText(field(Strings.issuerLabel), issuer);
  await tester.enterText(field(Strings.nameLabel), name);
  await tester.enterText(field(Strings.secretLabel), secret);
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text(Strings.save));
  await tester.pump();
  await tester.pump();
}

void main() {
  late int finished;
  late TestEnvironment env;

  setUp(() => finished = 0);

  Future<void> open(WidgetTester tester, {TestEnvironment? environment}) async {
    env = environment ?? TestEnvironment();
    await env.pump(tester, ManualEntryPage(onFinished: () => finished++));
    await env.load(tester);
  }

  testWidgets('shows the three fields', (tester) async {
    await open(tester);

    expect(field(Strings.issuerLabel), findsOneWidget);
    expect(field(Strings.nameLabel), findsOneWidget);
    expect(field(Strings.secretLabel), findsOneWidget);
  });

  testWidgets('saves what was typed and closes', (tester) async {
    await open(tester);

    await fill(
      tester,
      issuer: 'GitHub',
      name: 'alex@example.com',
      secret: 'jbsw y3dp ehpk 3pxp',
    );
    await save(tester);

    expect(finished, 1);
    final saved = env.repository.accounts.single;
    expect(saved.issuer, 'GitHub');
    expect(saved.name, 'alex@example.com');
    expect(find.text(Strings.accountAdded), findsOneWidget);
  });

  testWidgets('the issuer is optional', (tester) async {
    await open(tester);

    await fill(tester, name: 'alex', secret: 'JBSWY3DPEHPK3PXP');
    await save(tester);

    expect(env.repository.accounts.single.issuer, isNull);
    expect(finished, 1);
  });

  testWidgets('asks for the name when it is empty', (tester) async {
    await open(tester);

    await fill(tester, secret: 'JBSWY3DPEHPK3PXP');
    await save(tester);

    expect(find.text(Strings.nameRequired), findsOneWidget);
    expect(find.text(Strings.secretRequired), findsNothing);
    expect(env.repository.added, isEmpty);
    expect(finished, 0);
  });

  testWidgets('asks for the secret when it is empty', (tester) async {
    await open(tester);

    await fill(tester, name: 'alex');
    await save(tester);

    expect(find.text(Strings.secretRequired), findsOneWidget);
    expect(find.text(Strings.nameRequired), findsNothing);
    expect(finished, 0);
  });

  testWidgets('says that the secret is not Base32', (tester) async {
    await open(tester);

    await fill(tester, name: 'alex', secret: 'abc1!');
    await save(tester);

    expect(find.text(Strings.secretInvalid), findsOneWidget);
    expect(env.repository.added, isEmpty);
    expect(finished, 0);
  });

  testWidgets('a mistake is gone from the screen once it is fixed', (
    tester,
  ) async {
    await open(tester);
    await fill(tester, name: 'alex', secret: 'abc1!');
    await save(tester);
    expect(find.text(Strings.secretInvalid), findsOneWidget);

    await tester.enterText(field(Strings.secretLabel), 'JBSWY3DPEHPK3PXP');
    await save(tester);

    expect(find.text(Strings.secretInvalid), findsNothing);
    expect(finished, 1);
  });

  testWidgets('says that the account is already added, and closes', (
    tester,
  ) async {
    final environment = TestEnvironment(
      repository: FakeAccountRepository(
        accounts: [
          // The same source as the form below: the secret is JBSWY3DPEHPK3PXP.
          testAccount(
            issuer: null,
            name: 'alex',
            secret: referenceSecretOfHello,
          ),
        ],
      ),
    );
    await open(tester, environment: environment);

    await fill(tester, name: 'alex', secret: 'JBSWY3DPEHPK3PXP');
    await save(tester);

    expect(find.text(Strings.accountDuplicate), findsOneWidget);
    expect(find.text(Strings.accountAdded), findsNothing);
    expect(env.repository.accounts, hasLength(1));
    expect(finished, 1);
  });

  testWidgets('tells the user when the storage fails, and stays', (
    tester,
  ) async {
    await open(
      tester,
      environment: TestEnvironment(
        repository: FakeAccountRepository()..failAdding = true,
      ),
    );

    await fill(tester, name: 'alex', secret: 'JBSWY3DPEHPK3PXP');
    await save(tester);

    expect(find.text(Strings.saveFailed), findsOneWidget);
    expect(finished, 0);
    // What was typed is still there, to try again.
    expect(find.text('alex'), findsOneWidget);
  });
}
