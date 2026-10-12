import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:otp_guard/core/security/screen_security.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/lock/presentation/widgets/lock_lifecycle_observer.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';
import 'package:otp_guard/l10n/s.dart';

/// The root of the app: it hands the dependencies down the tree and starts the
/// router.
class App extends StatelessWidget {
  /// Creates the app. [getIt] holds what it is made of, see
  /// `configureDependencies`.
  const App({required this.getIt, required this.router, super.key});

  /// The container with the dependencies.
  final GetIt getIt;

  /// The router with the screens.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<Clock>.value(value: getIt()),
        RepositoryProvider<ScreenSecurity>.value(value: getIt()),
      ],
      // The lock is above everything: the router asks it where to go, and the
      // observer tells it when the app goes to the background and back.
      child: BlocProvider<LockCubit>(
        create: (_) {
          final cubit = getIt<LockCubit>();
          unawaited(cubit.load());
          return cubit;
        },
        child: LockLifecycleObserver(
          // Above the router, so the list, the scanner and the form share one
          // cubit and see the same accounts.
          child: BlocProvider<AccountsCubit>(
            create: (_) {
              final cubit = getIt<AccountsCubit>();
              unawaited(cubit.load());
              return cubit;
            },
            child: MaterialApp.router(
              onGenerateTitle: (context) => S.of(context).appTitle,
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
              ),
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
  }
}
