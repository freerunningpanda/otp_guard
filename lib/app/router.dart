import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:otp_guard/features/debug/key_demo_page.dart';
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

  /// The page that checks the device key. Debug builds only.
  static const keyDemo = '/debug/keys';
}

/// The routes of the app: the list, the scanner and the manual form.
GoRouter createRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: AppRoutes.accounts,
        builder: (context, state) => AccountsPage(
          onScan: () => unawaited(context.push<void>(AppRoutes.scan)),
          onEnterManually: () =>
              unawaited(context.push<void>(AppRoutes.manual)),
          onOpenKeyDemo: kDebugMode
              ? () => unawaited(context.push<void>(AppRoutes.keyDemo))
              : null,
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
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.keyDemo,
          builder: (context, state) => const KeyDemoPage(),
        ),
    ],
  );
}
