import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:otp_guard/app/cubit_listenable.dart';
import 'package:otp_guard/features/debug/key_demo_page.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/lock/presentation/lock_page.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';
import 'package:otp_guard/features/lock/presentation/pin_setup_page.dart';
import 'package:otp_guard/features/lock/presentation/widgets/biometric_offer_listener.dart';
import 'package:otp_guard/features/lock/presentation/widgets/lock_menu_button.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_page.dart';
import 'package:otp_guard/features/otp/presentation/add/manual_entry_page.dart';
import 'package:otp_guard/features/otp/presentation/add/scanner_page.dart';

/// The paths of the screens.
abstract final class AppRoutes {
  /// The list of accounts.
  static const accounts = '/';

  /// The QR scanner.
  static const scan = '/scan';

  /// The form for typing an account.
  static const manual = '/manual';

  /// The lock screen: a PIN, a fingerprint or a face opens the app.
  static const lock = '/lock';

  /// Where the first PIN is created.
  static const pinSetup = '/lock/setup';

  /// The page that checks the device key. Debug builds only.
  static const keyDemo = '/debug/keys';
}

/// Where the router must send a visitor of [location], given the state of the
/// lock, or null if the visitor may stay.
///
/// While the app is locked, or its lock is not read yet, every path leads to
/// the lock screen. While no PIN is set, every path leads to the creation of
/// one. Once the app is open, the screens of the lock lead on to the list.
String? lockRedirect(AppLockState state, String location) {
  return switch (state) {
    LockLoading() ||
    LockLoadFailed() ||
    Locked() => location == AppRoutes.lock ? null : AppRoutes.lock,
    PinNotSet() => location == AppRoutes.pinSetup ? null : AppRoutes.pinSetup,
    Unlocked() =>
      location == AppRoutes.lock || location == AppRoutes.pinSetup
          ? AppRoutes.accounts
          : null,
  };
}

/// The routes of the app: the list, the scanner, the manual form and the
/// screens of the lock.
///
/// Every route goes through the lock: the router checks its redirect again at
/// each change of [lock], so an app that locks sends whatever screen is open to
/// the lock screen.
GoRouter createRouter({required LockCubit lock}) {
  return GoRouter(
    refreshListenable: CubitListenable(lock),
    redirect: (context, state) =>
        lockRedirect(lock.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.accounts,
        builder: (context, state) => BiometricOfferListener(
          child: AccountsPage(
            onScan: () => unawaited(context.push<void>(AppRoutes.scan)),
            onEnterManually: () =>
                unawaited(context.push<void>(AppRoutes.manual)),
            onOpenKeyDemo: kDebugMode
                ? () => unawaited(context.push<void>(AppRoutes.keyDemo))
                : null,
            actions: const [LockMenuButton()],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => ScannerPage(
          onFinished: () => context.pop(),
          // The scanner is replaced, not covered: after the form the user
          // goes back to the list, not to a camera.
          onEnterManually: () => context.pushReplacement(AppRoutes.manual),
        ),
      ),
      GoRoute(
        path: AppRoutes.manual,
        builder: (context, state) =>
            ManualEntryPage(onFinished: () => context.pop()),
      ),
      GoRoute(
        path: AppRoutes.lock,
        builder: (context, state) {
          // The accounts in memory are the erased ones after a reset.
          final accounts = context.read<AccountsCubit>();
          return LockPage(onAppReset: () => unawaited(accounts.load()));
        },
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        builder: (context, state) => const PinSetupPage(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.keyDemo,
          builder: (context, state) => const KeyDemoPage(),
        ),
    ],
  );
}
