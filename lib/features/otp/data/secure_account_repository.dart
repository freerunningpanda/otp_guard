import 'package:otp_guard/features/otp/data/account_json.dart';
import 'package:otp_guard/features/otp/data/key_value_store.dart';
import 'package:otp_guard/features/otp/domain/account_repository.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';

/// Keeps the accounts in a secure [KeyValueStore], one entry for each.
///
/// One entry per account, not one list in a single entry. A failed write
/// touches one account only, a damaged record loses one account and not all of
/// them, and there is no list to read, change and write back.
class SecureAccountRepository implements AccountRepository {
  /// Creates the repository on a `store`.
  SecureAccountRepository(this._store);

  /// The start of every key this repository writes. The entries of other
  /// parts of the app, if they share the store, are left alone.
  static const keyPrefix = 'otp.account.';

  final KeyValueStore _store;

  // The operations run one after another. "Look for a duplicate, then write" is
  // two steps, and two scans of the same QR code at once would both pass the
  // look and both write.
  Future<void> _last = Future<void>.value();

  Future<T> _inTurn<T>(Future<T> Function() action) {
    final result = _last.then((_) => action());
    // The next operation waits for this one, whether it succeeds or fails.
    _last = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<StoredAccounts> getAccounts() => _inTurn(_read);

  @override
  Future<AddAccountResult> add(OtpAccount account) {
    return _inTurn(() async {
      final stored = await _read();

      for (final existing in stored.accounts) {
        if (existing.isSameSourceAs(account)) {
          return AccountAlreadyExists(existing);
        }
      }
      // An id comes from a random generator, so this means a bug, and writing
      // would replace another account.
      if (stored.accounts.any((a) => a.id == account.id) ||
          stored.unreadableIds.contains(account.id)) {
        throw StateError('An account with this id is already stored');
      }

      await _store.write(_keyOf(account.id), encodeAccount(account));
      return AccountAdded(account);
    });
  }

  @override
  Future<void> remove(String id) => _inTurn(() => _store.delete(_keyOf(id)));

  @override
  Future<void> removeAll() {
    return _inTurn(() async {
      final entries = await _store.readAll();
      // Everything under the prefix, readable or not. The entries of other
      // parts of the app are left alone.
      for (final key in entries.keys.where((k) => k.startsWith(keyPrefix))) {
        await _store.delete(key);
      }
    });
  }

  Future<StoredAccounts> _read() async {
    final entries = await _store.readAll();
    final accounts = <OtpAccount>[];
    final unreadableIds = <String>[];

    for (final entry in entries.entries) {
      if (!entry.key.startsWith(keyPrefix)) continue;
      final id = entry.key.substring(keyPrefix.length);
      try {
        accounts.add(decodeAccount(entry.value, expectedId: id));
      } on FormatException {
        // Left in the storage on purpose, and reported.
        unreadableIds.add(id);
      }
    }

    accounts.sort(_byIssuerThenName);
    unreadableIds.sort();
    return StoredAccounts(accounts: accounts, unreadableIds: unreadableIds);
  }

  String _keyOf(String id) => '$keyPrefix$id';
}

// Case does not matter, and an account without an issuer comes first. The id
// is the last resort, so the order never depends on how the storage lists.
int _byIssuerThenName(OtpAccount a, OtpAccount b) {
  final byIssuer = (a.issuer ?? '').toLowerCase().compareTo(
    (b.issuer ?? '').toLowerCase(),
  );
  if (byIssuer != 0) return byIssuer;
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (byName != 0) return byName;
  return a.id.compareTo(b.id);
}
