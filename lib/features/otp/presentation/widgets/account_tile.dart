import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/app/strings.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/domain/totp.dart';
import 'package:otp_guard/features/otp/presentation/widgets/code_format.dart';

/// One row of the list: the code of an account and the time it has left.
///
/// The row works out its own code and countdown from the [Clock], once a
/// second. They are not in the state of the list, so only this row is redrawn
/// every second, and not the whole list.
class AccountTile extends StatefulWidget {
  /// Creates the row. While [hideCode] is true, the code is not shown.
  const AccountTile({
    required this.account,
    required this.hideCode,
    required this.onDelete,
    super.key,
  });

  /// The account of this row.
  final OtpAccount account;

  /// Whether to show dots instead of the code, for example while the screen is
  /// being recorded.
  final bool hideCode;

  /// Called when the user asks to delete the account.
  final VoidCallback onDelete;

  @override
  State<AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<AccountTile> {
  // Made once per account, not once per second: it copies the secret.
  late Totp _totp = widget.account.toTotp();

  @override
  void didUpdateWidget(AccountTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      _totp = widget.account.toTotp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clock = context.read<Clock>();
    return StreamBuilder<DateTime>(
      stream: clock.ticks,
      initialData: clock.now(),
      builder: (context, snapshot) {
        final now = snapshot.requireData;
        final remaining = _totp.remaining(now);
        final fraction = remaining.inMilliseconds / (_totp.period * 1000);
        final secondsLeft = (remaining.inMilliseconds / 1000).ceil();
        final account = widget.account;
        final colors = Theme.of(context).colorScheme;
        // The last seconds are in the color of a warning: the code is about to
        // change, and a code typed now may come too late.
        final almostOver = secondsLeft <= 5;

        return ListTile(
          leading: SizedBox.square(
            dimension: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  key: Key('progress-${account.id}'),
                  value: fraction,
                  strokeWidth: 3,
                  color: almostOver ? colors.error : colors.primary,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
                Text(
                  '$secondsLeft',
                  key: Key('seconds-${account.id}'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          title: Text(
            widget.hideCode
                ? Strings.hiddenCode
                : formatCode(_totp.codeAt(now)),
            key: Key('code-${account.id}'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 2,
            ),
          ),
          subtitle: Text(
            account.issuer == null
                ? account.name
                : '${account.issuer} · ${account.name}',
          ),
          trailing: PopupMenuButton<void>(
            key: Key('menu-${account.id}'),
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                key: Key('delete-${account.id}'),
                onTap: widget.onDelete,
                child: const Text(Strings.delete),
              ),
            ],
          ),
        );
      },
    );
  }
}
