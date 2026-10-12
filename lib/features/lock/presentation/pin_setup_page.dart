import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/features/lock/domain/pin_policy.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/l10n/s.dart';

/// The screen where the user creates the PIN, the first time the app opens.
/// The router sends every route here until a PIN is set.
class PinSetupPage extends StatefulWidget {
  /// Creates the page.
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  String? _pinError;
  String? _confirmError;
  bool _isSaving = false;

  @override
  void dispose() {
    // The PIN does not outlive the screen in a controller.
    _pin
      ..clear()
      ..dispose();
    _confirm
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final l10n = S.of(context);
    final pin = _pin.text;
    final problem = PinPolicy.check(pin);

    setState(() {
      _pinError = switch (problem) {
        null => null,
        PinProblem.notDigits => l10n.pinDigitsOnly,
        PinProblem.tooShort || PinProblem.tooLong => l10n.pinLengthError(
          PinPolicy.minLength,
          PinPolicy.maxLength,
        ),
      };
      _confirmError = problem == null && pin != _confirm.text
          ? l10n.pinMismatch
          : null;
    });
    if (_pinError != null || _confirmError != null) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await context.read<LockCubit>().setPin(pin);
    // When it worked, the router has moved on and this page is gone.
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result != SetPinResult.done) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.pinSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.pinSetupTitle),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.pinSetupHint, key: const Key('pin-setup-hint')),
            const SizedBox(height: 24),
            _PinField(
              fieldKey: const Key('pin-field'),
              controller: _pin,
              label: l10n.pinLabel,
              error: _pinError,
              enabled: !_isSaving,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            _PinField(
              fieldKey: const Key('pin-confirm-field'),
              controller: _confirm,
              label: l10n.pinConfirmLabel,
              error: _confirmError,
              enabled: !_isSaving,
              onSubmitted: (_) => unawaited(_save()),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('pin-create-button'),
              onPressed: _isSaving ? null : () => unawaited(_save()),
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.pinCreate),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.error,
    required this.enabled,
    this.autofocus = false,
    this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? error;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: true,
      // A PIN is typed once. No suggestions or corrections, which would send
      // what is typed to the keyboard's dictionary.
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.number,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(PinPolicy.maxLength),
      ],
      decoration: InputDecoration(labelText: label, errorText: error),
      onSubmitted: onSubmitted,
    );
  }
}
