import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/app/otp_auth_failure_message.dart';
import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';
import 'package:otp_guard/features/otp/presentation/accounts/add_account_outcome.dart';
import 'package:otp_guard/l10n/s.dart';

/// A form for adding an account by typing: the service, the account name and
/// the secret in Base32.
class ManualEntryPage extends StatefulWidget {
  /// Creates the page. [onFinished] is called when the account is added or
  /// already there.
  const ManualEntryPage({required this.onFinished, super.key});

  /// Closes the page after an account is added.
  final VoidCallback onFinished;

  @override
  State<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends State<ManualEntryPage> {
  final _issuer = TextEditingController();
  final _name = TextEditingController();
  final _secret = TextEditingController();

  String? _nameError;
  String? _secretError;
  bool _isSaving = false;

  @override
  void dispose() {
    _issuer.dispose();
    _name.dispose();
    // The secret does not outlive the form in a controller.
    _secret
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _nameError = null;
      _secretError = null;
    });

    final outcome = await context.read<AccountsCubit>().addManual(
      issuer: _issuer.text,
      name: _name.text,
      secret: _secret.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    final messenger = ScaffoldMessenger.of(context);
    switch (outcome) {
      case AccountSaved():
        messenger.showSnackBar(
          SnackBar(content: Text(S.of(context).accountAdded)),
        );
        widget.onFinished();
      case AccountDuplicate():
        messenger.showSnackBar(
          SnackBar(content: Text(S.of(context).accountDuplicate)),
        );
        widget.onFinished();
      case AccountRejected(:final failure):
        _showFieldError(failure, messenger);
      case AccountStorageFailed():
        messenger.showSnackBar(
          SnackBar(content: Text(S.of(context).saveFailed)),
        );
    }
  }

  // Puts the message next to the field that is wrong.
  void _showFieldError(
    OtpAuthFailure failure,
    ScaffoldMessengerState messenger,
  ) {
    final l10n = S.of(context);
    setState(() {
      switch (failure) {
        case MissingLabel():
          _nameError = l10n.nameRequired;
        case MissingSecret():
          _secretError = l10n.secretRequired;
        case InvalidSecret():
          _secretError = l10n.secretInvalid;
        case NotAnOtpAuthUri() || UnsupportedOtpType() || InvalidParameter():
          // These come only from a link, never from the form. A text is
          // shown all the same, instead of nothing.
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.forFailure(failure))),
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.manualTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _issuer,
            decoration: InputDecoration(labelText: l10n.issuerLabel),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
              errorText: _nameError,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secret,
            decoration: InputDecoration(
              labelText: l10n.secretLabel,
              errorText: _secretError,
            ),
            // The secret is typed once. No suggestions or corrections, which
            // would send what is typed to the keyboard's dictionary.
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => unawaited(_save()),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : () => unawaited(_save()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
