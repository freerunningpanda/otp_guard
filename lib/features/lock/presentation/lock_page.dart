import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/features/lock/domain/biometric_auth.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/pin_policy.dart';
import 'package:otp_guard/features/lock/presentation/format_wait.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';
import 'package:otp_guard/l10n/s.dart';

/// The texts of the system prompt for a fingerprint or a face, in the
/// language of the app.
BiometricPromptTexts biometricPromptTexts(S l10n) {
  return BiometricPromptTexts(
    title: l10n.biometricPromptTitle,
    subtitle: l10n.biometricPromptSubtitle,
    cancelText: l10n.cancel,
  );
}

/// The screen that stands between the user and the app while it is locked.
///
/// It asks for the PIN, and for a fingerprint or a face if they are on. The
/// router sends every route here while the lock is closed, and the back button
/// does not leave it.
class LockPage extends StatelessWidget {
  /// Creates the page. [onAppReset] is called after the user reset the app, so
  /// the screens that hold the erased accounts can forget them.
  const LockPage({this.onAppReset, super.key});

  /// Called after the app was reset, or null.
  final VoidCallback? onAppReset;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<LockCubit, AppLockState>(
            builder: (context, state) {
              return switch (state) {
                Locked() => _PinEntry(state: state, onAppReset: onAppReset),
                LockLoadFailed() => _LoadFailedView(
                  state: state,
                  onAppReset: onAppReset,
                ),
                // The first moments, and the moment before the router moves
                // on: nothing of the app is shown.
                LockLoading() ||
                PinNotSet() ||
                Unlocked() => const Center(child: CircularProgressIndicator()),
              };
            },
          ),
        ),
      ),
    );
  }
}

// Asks whether to erase everything, and does it. The only way out for a user
// who forgot the PIN, and for a lock whose record is damaged.
Future<void> _confirmReset(
  BuildContext context,
  VoidCallback? onAppReset,
) async {
  final lock = context.read<LockCubit>();
  final l10n = S.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.resetTitle),
      content: Text(l10n.resetBody),
      actions: [
        TextButton(
          key: const Key('reset-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('reset-confirm'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.resetConfirm),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    if (await lock.resetApp()) onAppReset?.call();
  }
}

class _LoadFailedView extends StatelessWidget {
  const _LoadFailedView({required this.state, required this.onAppReset});

  final LockLoadFailed state;
  final VoidCallback? onAppReset;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              state.isDamaged
                  ? l10n.lockDamagedTitle
                  : l10n.lockLoadFailedTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              state.isDamaged ? l10n.lockDamagedBody : l10n.lockLoadFailedBody,
              textAlign: TextAlign.center,
            ),
            if (state.resetFailed) ...[
              const SizedBox(height: 8),
              Text(
                l10n.lockResetFailed,
                key: const Key('reset-failed'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => unawaited(context.read<LockCubit>().load()),
              child: Text(l10n.retry),
            ),
            // Only for a record that stays damaged: trying again does not
            // help there. A storage that failed may work at the next try, and
            // a reset would cost the accounts for nothing.
            if (state.isDamaged) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('reset-damaged-button'),
                onPressed: () => unawaited(_confirmReset(context, onAppReset)),
                child: Text(l10n.resetApp),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinEntry extends StatefulWidget {
  const _PinEntry({required this.state, required this.onAppReset});

  final Locked state;
  final VoidCallback? onAppReset;

  @override
  State<_PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<_PinEntry> {
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The prompt for a fingerprint or a face comes up by itself, once for each
    // time the screen is shown. After a cancel the button asks again.
    if (widget.state.biometric == BiometricStatus.on) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askBiometrics();
      });
    }
  }

  @override
  void dispose() {
    // The PIN does not outlive the screen in a controller.
    _pin
      ..clear()
      ..dispose();
    super.dispose();
  }

  void _askBiometrics() {
    final texts = biometricPromptTexts(S.of(context));
    unawaited(context.read<LockCubit>().unlockWithBiometrics(texts));
  }

  void _submit() {
    final pin = _pin.text;
    if (pin.isEmpty) return;
    _pin.clear();
    unawaited(context.read<LockCubit>().unlockWithPin(pin));
  }

  String? _errorText(S l10n, Locked state, Duration wait) {
    if (wait > Duration.zero) return l10n.pinWait(formatWait(wait));
    return switch (state.problem) {
      null => null,
      UnlockProblem.wrongPin => l10n.pinWrong,
      UnlockProblem.biometricUnavailable => l10n.lockBiometricUnavailable,
      UnlockProblem.biometricFailed => l10n.lockBiometricFailed,
      UnlockProblem.storageFailed => l10n.lockStorageFailed,
      UnlockProblem.resetFailed => l10n.lockResetFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final state = widget.state;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.lockTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (state.biometric == BiometricStatus.needsRenewal) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.lockBiometricRenewalHint,
                  key: const Key('renewal-hint'),
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              _Countdown(
                retryAt: state.retryAt,
                builder: (context, wait) {
                  final canSubmit = !state.isBusy && wait == Duration.zero;
                  return Column(
                    children: [
                      TextField(
                        key: const Key('pin-field'),
                        controller: _pin,
                        enabled: canSubmit,
                        autofocus: true,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            PinPolicy.maxLength,
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.pinLabel,
                          errorText: _errorText(l10n, state, wait),
                          errorMaxLines: 3,
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('unlock-button'),
                        onPressed: canSubmit ? _submit : null,
                        child: state.isBusy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.unlock),
                      ),
                    ],
                  );
                },
              ),
              if (state.biometric == BiometricStatus.on) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('biometric-button'),
                  onPressed: state.isBusy ? null : _askBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.unlockWithBiometrics),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                key: const Key('forgot-pin-button'),
                onPressed: state.isBusy
                    ? null
                    : () => unawaited(
                        _confirmReset(context, widget.onAppReset),
                      ),
                child: Text(l10n.forgotPin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Redraws every second while there is a wait to show, and not at all when
// there is none.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.retryAt, required this.builder});

  final DateTime? retryAt;
  final Widget Function(BuildContext context, Duration remaining) builder;

  @override
  Widget build(BuildContext context) {
    final until = retryAt;
    if (until == null) return builder(context, Duration.zero);
    final clock = context.read<Clock>();
    return StreamBuilder<DateTime>(
      stream: clock.ticks,
      initialData: clock.now(),
      builder: (context, snapshot) {
        final left = until.difference(snapshot.requireData);
        return builder(context, left.isNegative ? Duration.zero : left);
      },
    );
  }
}
