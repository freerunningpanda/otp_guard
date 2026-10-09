import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/app/strings.dart';
import 'package:otp_guard/core/security/screen_security.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_state.dart';
import 'package:otp_guard/features/otp/presentation/security/screen_security_cubit.dart';
import 'package:otp_guard/features/otp/presentation/widgets/account_tile.dart';

/// The main screen: the accounts with their codes.
///
/// While it is open, the screen is protected and the events of the plugin are
/// followed: a screenshot gets a notice, and the codes are hidden while the
/// screen is being recorded.
class AccountsPage extends StatelessWidget {
  /// Creates the page. The callbacks do the navigation, so the page does not
  /// depend on a router. [onOpenKeyDemo] is null where the demo is not wanted.
  const AccountsPage({
    required this.onScan,
    required this.onEnterManually,
    this.onOpenKeyDemo,
    super.key,
  });

  /// Opens the scanner.
  final VoidCallback onScan;

  /// Opens the form for typing an account.
  final VoidCallback onEnterManually;

  /// Opens the page that checks the device key, or null.
  final VoidCallback? onOpenKeyDemo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ScreenSecurityCubit(context.read<ScreenSecurity>());
        unawaited(cubit.start());
        return cubit;
      },
      child: _AccountsView(
        onScan: onScan,
        onEnterManually: onEnterManually,
        onOpenKeyDemo: onOpenKeyDemo,
      ),
    );
  }
}

class _AccountsView extends StatelessWidget {
  const _AccountsView({
    required this.onScan,
    required this.onEnterManually,
    required this.onOpenKeyDemo,
  });

  final VoidCallback onScan;
  final VoidCallback onEnterManually;
  final VoidCallback? onOpenKeyDemo;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScreenSecurityCubit, ScreenSecurityState>(
      listenWhen: (previous, current) =>
          current.screenshotCount > previous.screenshotCount,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(Strings.screenshotTaken)),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(Strings.appTitle),
          actions: [
            if (onOpenKeyDemo != null)
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                tooltip: Strings.deviceKeyDemo,
                onPressed: onOpenKeyDemo,
              ),
          ],
        ),
        body: const _AccountsBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddOptions(context),
          icon: const Icon(Icons.add),
          label: const Text(Strings.addAccount),
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text(Strings.scanQr),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onScan();
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                title: const Text(Strings.enterManually),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEnterManually();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountsCubit, AccountsState>(
      builder: (context, state) {
        return switch (state) {
          AccountsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          AccountsFailure() => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(Strings.loadFailed),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      unawaited(context.read<AccountsCubit>().load()),
                  child: const Text(Strings.retry),
                ),
              ],
            ),
          ),
          AccountsLoaded() => _AccountsList(state: state),
        };
      },
    );
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({required this.state});

  final AccountsLoaded state;

  @override
  Widget build(BuildContext context) {
    // Only this value is watched, so the list is rebuilt when recording starts
    // or stops, and not at every screenshot.
    final isRecording = context.select<ScreenSecurityCubit, bool>(
      (cubit) => cubit.state.isRecording,
    );

    return ListView(
      // Room for the button, so it does not cover the last row.
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (state.unreadableIds.isNotEmpty)
          _UnreadableBanner(count: state.unreadableIds.length),
        if (isRecording) const _RecordingBanner(),
        if (state.accounts.isEmpty)
          const _EmptyView()
        else
          for (final account in state.accounts)
            AccountTile(
              key: ValueKey(account.id),
              account: account,
              hideCode: isRecording,
              onDelete: () => unawaited(_confirmDelete(context, account)),
            ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, OtpAccount account) async {
    final cubit = context.read<AccountsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.deleteTitle),
        content: Text(Strings.deleteBody(account.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(Strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await cubit.remove(account.id)) {
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.deleteFailed)),
      );
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            Strings.emptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(Strings.emptyHint, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ListTile(
        leading: Icon(Icons.videocam, color: colors.onErrorContainer),
        title: Text(
          Strings.recordingBanner,
          style: TextStyle(color: colors.onErrorContainer),
        ),
      ),
    );
  }
}

class _UnreadableBanner extends StatelessWidget {
  const _UnreadableBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.tertiaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ListTile(
        leading: Icon(Icons.warning_amber, color: colors.onTertiaryContainer),
        title: Text(
          Strings.unreadableWarning(count),
          style: TextStyle(color: colors.onTertiaryContainer),
        ),
        trailing: TextButton(
          onPressed: () => unawaited(_confirmDelete(context)),
          child: const Text(Strings.deleteUnreadable),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<AccountsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.deleteUnreadableTitle),
        content: const Text(Strings.deleteUnreadableBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(Strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await cubit.removeUnreadable()) {
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.deleteFailed)),
      );
    }
  }
}
