import 'package:meta/meta.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';

/// Where the accounts are kept.
///
/// The implementation keeps them in secure storage. The interface is all the
/// rest of the app knows, so it can be replaced in a test.
abstract interface class AccountRepository {
  /// Reads all accounts, sorted by issuer, then by name.
  ///
  /// A record that can not be read does not stop the others: its id is in
  /// [StoredAccounts.unreadableIds], and the app can tell the user.
  Future<StoredAccounts> getAccounts();

  /// Adds [account], unless the same source is already there.
  ///
  /// Scanning the same QR code twice finds the account that exists and adds
  /// nothing, see [AccountAlreadyExists].
  Future<AddAccountResult> add(OtpAccount account);

  /// Removes the account with [id], also one that can not be read. Does
  /// nothing if there is none.
  Future<void> remove(String id);
}

/// The accounts that were read, and the ids of the records that could not be.
@immutable
class StoredAccounts {
  /// Creates the value. The lists are copied and can not be changed.
  StoredAccounts({
    required List<OtpAccount> accounts,
    List<String> unreadableIds = const [],
  }) : accounts = List.unmodifiable(accounts),
       unreadableIds = List.unmodifiable(unreadableIds);

  /// The accounts that were read, sorted by issuer, then by name.
  final List<OtpAccount> accounts;

  /// The ids of the records that were damaged or of an unknown version. They
  /// are kept in the storage: a newer version of the app may read them.
  final List<String> unreadableIds;

  @override
  bool operator ==(Object other) {
    return other is StoredAccounts &&
        _sameItems(accounts, other.accounts) &&
        _sameItems(unreadableIds, other.unreadableIds);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(accounts), Object.hashAll(unreadableIds));

  @override
  String toString() {
    return 'StoredAccounts(${accounts.length} accounts, '
        '${unreadableIds.length} unreadable)';
  }
}

/// The outcome of adding an account.
@immutable
sealed class AddAccountResult {
  const AddAccountResult();
}

/// The account was added.
final class AccountAdded extends AddAccountResult {
  /// Creates the result.
  const AccountAdded(this.account);

  /// The account that was stored.
  final OtpAccount account;

  @override
  bool operator ==(Object other) =>
      other is AccountAdded && other.account == account;

  @override
  int get hashCode => Object.hash(AccountAdded, account);

  @override
  String toString() => 'AccountAdded($account)';
}

/// The same source is already stored, under the label and with the secret and
/// the settings of the account that was offered, so nothing was added.
final class AccountAlreadyExists extends AddAccountResult {
  /// Creates the result.
  const AccountAlreadyExists(this.existing);

  /// The account that is already stored. Its id is the one to use.
  final OtpAccount existing;

  @override
  bool operator ==(Object other) =>
      other is AccountAlreadyExists && other.existing == existing;

  @override
  int get hashCode => Object.hash(AccountAlreadyExists, existing);

  @override
  String toString() => 'AccountAlreadyExists($existing)';
}

bool _sameItems<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
