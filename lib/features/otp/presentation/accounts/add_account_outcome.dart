import 'package:equatable/equatable.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';

/// What came of an attempt to add an account, for the screen to tell the user.
sealed class AddAccountOutcome extends Equatable {
  const AddAccountOutcome();

  @override
  List<Object?> get props => const [];
}

/// The account is saved.
final class AccountSaved extends AddAccountOutcome {
  /// Creates the outcome.
  const AccountSaved(this.account);

  /// The account that was saved.
  final OtpAccount account;

  @override
  List<Object?> get props => [account];
}

/// The same account is already there, so nothing was added.
final class AccountDuplicate extends AddAccountOutcome {
  /// Creates the outcome.
  const AccountDuplicate(this.existing);

  /// The account that is already there.
  final OtpAccount existing;

  @override
  List<Object?> get props => [existing];
}

/// The link or the typed values are not usable. The failure says why.
final class AccountRejected extends AddAccountOutcome {
  /// Creates the outcome.
  const AccountRejected(this.failure);

  /// Why the input was refused.
  final OtpAuthFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// The storage failed, and it is not known whether the account was saved.
final class AccountStorageFailed extends AddAccountOutcome {
  /// Creates the outcome.
  const AccountStorageFailed();
}
