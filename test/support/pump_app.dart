import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/core/security/screen_security.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';

import 'fake_account_repository.dart';
import 'fake_clock.dart';
import 'fake_screen_security.dart';
import 'localizations.dart';

/// What a page under test is given, and what a test can look at afterwards.
class TestEnvironment {
  TestEnvironment({
    FakeAccountRepository? repository,
    FakeClock? clock,
    FakeScreenSecurity? security,
  }) : repository = repository ?? FakeAccountRepository(),
       clock = clock ?? FakeClock.atUnix(0),
       security = security ?? FakeScreenSecurity() {
    cubit = AccountsCubit(this.repository, newId: () => 'new-${++_ids}');
  }

  final FakeAccountRepository repository;
  final FakeClock clock;
  final FakeScreenSecurity security;
  late final AccountsCubit cubit;
  var _ids = 0;

  /// Puts [page] in an app that has what the pages ask for: the clock, the
  /// screen security and the cubit of the accounts.
  Future<void> pump(WidgetTester tester, Widget page) async {
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<Clock>.value(value: clock),
          RepositoryProvider<ScreenSecurity>.value(value: security),
        ],
        child: BlocProvider<AccountsCubit>.value(
          value: cubit,
          child: localizedApp(home: page),
        ),
      ),
    );
  }

  /// Reads the accounts and lets the screen show them.
  Future<void> load(WidgetTester tester) async {
    await cubit.load();
    await tester.pump();
  }
}
