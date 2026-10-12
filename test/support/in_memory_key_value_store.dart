import 'package:otp_guard/features/otp/data/key_value_store.dart';

import 'fake_account_repository.dart';

/// A [KeyValueStore] in memory for tests, which can also be made to fail or to
/// be slow.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial])
    : entries = {...?initial};

  /// What is stored. A test may read and change it directly.
  final Map<String, String> entries;

  /// If it returns true for the key, a write or a delete of it throws.
  bool Function(String key)? failWriteWhen;

  /// If true, reading throws.
  bool failRead = false;

  /// What a failing call does: it throws. A [StateError] unless a test sets
  /// something else, for example an [Exception] like the failures of a real
  /// storage.
  Never Function() fail = _throwStateError;

  static Never _throwStateError() => throw StateError('storage failed');

  /// Every call waits this long, so that two operations started together
  /// overlap if nothing keeps them in turn.
  Duration delay = Duration.zero;

  /// Makes every write and delete of [key] throw an [Exception], like a
  /// storage that fails for one entry.
  void breakDeleting(String key) {
    fail = () => throw const FakeStorageException();
    failWriteWhen = (candidate) => candidate == key;
  }

  /// How many writes succeeded.
  int writeCount = 0;

  /// How many times everything was read. A part of the app that needs one
  /// entry must not do this.
  int readAllCount = 0;

  // No timer when there is no delay: a widget test cannot wait for one.
  Future<void> _wait() async {
    if (delay != Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<Map<String, String>> readAll() async {
    await _wait();
    readAllCount++;
    if (failRead) fail();
    return Map.of(entries);
  }

  @override
  Future<String?> read(String key) async {
    await _wait();
    if (failRead) fail();
    return entries[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await _wait();
    if (failWriteWhen?.call(key) ?? false) fail();
    entries[key] = value;
    writeCount++;
  }

  @override
  Future<void> delete(String key) async {
    await _wait();
    if (failWriteWhen?.call(key) ?? false) fail();
    entries.remove(key);
  }
}
