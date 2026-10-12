import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';
import 'package:otp_guard/l10n/s.dart';

/// Asks the user about the biometric sign-in when the lock offers it: right
/// after the first PIN is set, and after the fingerprints or faces of the
/// device changed and the old key stopped working.
///
/// It is put around the screen that opens after the lock, so the question is
/// asked on top of the app and not on top of the lock screen.
class BiometricOfferListener extends StatefulWidget {
  /// Creates the listener around [child].
  const BiometricOfferListener({required this.child, super.key});

  /// The screen the question is asked over.
  final Widget child;

  @override
  State<BiometricOfferListener> createState() => _BiometricOfferListenerState();
}

class _BiometricOfferListenerState extends State<BiometricOfferListener> {
  bool _isAsking = false;

  @override
  void initState() {
    super.initState();
    // The offer may have been made before this screen was built: the PIN is
    // set, the state changes, and only then the router opens the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askIfOffered(context.read<LockCubit>().state);
    });
  }

  void _askIfOffered(AppLockState state) {
    if (_isAsking || state is! Unlocked) return;
    if (state.offer == BiometricOffer.none) return;
    unawaited(_ask(state.offer));
  }

  Future<void> _ask(BiometricOffer offer) async {
    _isAsking = true;
    final cubit = context.read<LockCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = S.of(context);
    final isRenewal = offer == BiometricOffer.renewal;

    final wantsIt = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isRenewal ? l10n.biometricRenewTitle : l10n.biometricOfferTitle,
        ),
        content: Text(
          isRenewal ? l10n.biometricRenewBody : l10n.biometricOfferBody,
        ),
        actions: [
          TextButton(
            key: const Key('offer-decline'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.biometricNotNow),
          ),
          TextButton(
            key: const Key('offer-accept'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.biometricEnable),
          ),
        ],
      ),
    );

    if (wantsIt ?? false) {
      final result = await cubit.enableBiometrics();
      final message = switch (result) {
        EnableBiometricsResult.enabled => null,
        EnableBiometricsResult.unavailable => l10n.biometricUnavailableOnDevice,
        EnableBiometricsResult.failed => l10n.biometricEnableFailed,
      };
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } else {
      await cubit.declineBiometricOffer();
    }
    _isAsking = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LockCubit, AppLockState>(
      listenWhen: (previous, current) => current is Unlocked,
      listener: (context, state) => _askIfOffered(state),
      child: widget.child,
    );
  }
}
