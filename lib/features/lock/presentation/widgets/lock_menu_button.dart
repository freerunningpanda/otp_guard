import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';
import 'package:otp_guard/l10n/s.dart';

enum _LockAction { lockNow, enableBiometrics, disableBiometrics }

/// The menu of the lock in the bar of the main screen: lock now, and turn the
/// biometric sign-in on or off.
class LockMenuButton extends StatelessWidget {
  /// Creates the button.
  const LockMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return BlocBuilder<LockCubit, AppLockState>(
      builder: (context, state) {
        if (state is! Unlocked) return const SizedBox.shrink();
        final isOn = state.biometric == BiometricStatus.on;
        return PopupMenuButton<_LockAction>(
          key: const Key('lock-menu'),
          onSelected: (action) => unawaited(_onSelected(context, action)),
          itemBuilder: (context) => [
            PopupMenuItem(
              key: const Key('menu-lock-now'),
              value: _LockAction.lockNow,
              child: Text(l10n.menuLockNow),
            ),
            PopupMenuItem(
              key: const Key('menu-biometrics'),
              value: isOn
                  ? _LockAction.disableBiometrics
                  : _LockAction.enableBiometrics,
              child: Text(
                isOn ? l10n.menuBiometricsOff : l10n.menuBiometricsOn,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onSelected(BuildContext context, _LockAction action) async {
    final cubit = context.read<LockCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = S.of(context);

    switch (action) {
      case _LockAction.lockNow:
        cubit.lock();
      case _LockAction.enableBiometrics:
        final message = switch (await cubit.enableBiometrics()) {
          EnableBiometricsResult.enabled => null,
          EnableBiometricsResult.unavailable =>
            l10n.biometricUnavailableOnDevice,
          EnableBiometricsResult.failed => l10n.biometricEnableFailed,
        };
        if (message != null) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      case _LockAction.disableBiometrics:
        if (!await cubit.disableBiometrics()) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.biometricDisableFailed)),
          );
        }
    }
  }
}
