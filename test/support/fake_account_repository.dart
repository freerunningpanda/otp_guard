import 'package:otp_guard/features/otp/domain/account_repository.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';

/// The storage failed. An [Exception], like the failures of a real storage.
class FakeStorageException implements Exception {
  const FakeStorageException();
}

/// An [AccountRepository] in memory that a test can fill, ask what was done to
/// it, and make fail.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    List<OtpAccount> accounts = const [],
    this.unreadableIds = const [],
  }) : accounts = [...accounts];

  /// The accounts that are stored.
  final List<OtpAccount> accounts;

  /// The ids that are reported as unreadable.
  List<String> unreadableIds;

  /// If true, reading throws.
  bool failReading = false;

  /// If true, adding throws.
  bool failAdding = false;

  /// If true, removing throws.
  bool failRemoving = false;

  /// The accounts that `add` was called with.
  final added = <OtpAccount>[];

  /// The ids that `remove` was called with.
  final removed = <String>[];

  @override
  Future<StoredAccounts> getAccounts() async {
    if (failReading) throw const FakeStorageException();
    return StoredAccounts(accounts: accounts, unreadableIds: unreadableIds);
  }

  @override
  Future<AddAccountResult> add(OtpAccount account) async {
    added.add(account);
    if (failAdding) throw const FakeStorageException();
    for (final existing in accounts) {
      if (existing.isSameSourceAs(account)) {
        return AccountAlreadyExists(existing);
      }
    }
    accounts.add(account);
    return AccountAdded(account);
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    if (failRemoving) throw const FakeStorageException();
    accounts.removeWhere((account) => account.id == id);
    unreadableIds = [
      for (final unreadable in unreadableIds)
        if (unreadable != id) unreadable,
    ];
  }
}
