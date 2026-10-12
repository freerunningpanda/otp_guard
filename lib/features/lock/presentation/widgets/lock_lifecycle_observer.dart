import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';

/// Tells the lock when the app goes to the background and comes back.
///
/// Only a real trip to the background counts (`hidden` and `show`), not the app
/// becoming inactive. The prompt for a fingerprint or a face, a call or the
/// notification shade make it inactive for a moment, and locking on that would
/// lock the app again right after the fingerprint opened it.
///
/// Nothing is closed by hand when the app locks. The router sends the open
/// screen to the lock screen, and a dialog or a menu that is open over it goes
/// with it, because the navigator removes what was pushed over a screen when it
/// removes the screen.
class LockLifecycleObserver extends StatefulWidget {
  /// Creates the observer around [child]. It needs a `LockCubit` above it.
  const LockLifecycleObserver({required this.child, super.key});

  /// The app.
  final Widget child;

  @override
  State<LockLifecycleObserver> createState() => _LockLifecycleObserverState();
}

class _LockLifecycleObserverState extends State<LockLifecycleObserver> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => context.read<LockCubit>().appHidden(),
      onShow: () => context.read<LockCubit>().appShown(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
