import 'package:equatable/equatable.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';

/// The state of the list of accounts.
///
/// The codes are not in it. A code changes every 30 seconds and the countdown
/// every second, and a state that held them would change every second and
/// rebuild the whole list. The state holds the accounts, which change only when
/// the user adds or removes one, and each row works out its own code from the
/// clock.
sealed class AccountsState extends Equatable {
  const AccountsState();

  @override
  List<Object?> get props => const [];
}

/// The accounts are being read.
final class AccountsLoading extends AccountsState {
  /// Creates the state.
  const AccountsLoading();
}

/// The accounts are read.
final class AccountsLoaded extends AccountsState {
  /// Creates the state.
  const AccountsLoaded({
    required this.accounts,
    this.unreadableIds = const [],
  });

  /// The accounts, in the order to show them.
  final List<OtpAccount> accounts;

  /// The ids of the records that could not be read.
  final List<String> unreadableIds;

  @override
  List<Object?> get props => [accounts, unreadableIds];
}

/// The storage could not be read.
final class AccountsFailure extends AccountsState {
  /// Creates the state.
  const AccountsFailure();
}
