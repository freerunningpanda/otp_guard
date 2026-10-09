import 'package:otp_guard/features/otp/data/key_value_store.dart';

/// A [KeyValueStore] in memory for tests, which can also be made to fail or to
/// be slow.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial])
    : entries = {...?initial};

  /// What is stored. A test may read and change it directly.
  final Map<String, String> entries;

  /// If it returns true for the key, the write throws.
  bool Function(String key)? failWriteWhen;

  /// If true, reading throws.
  bool failRead = false;

  /// Every call waits this long, so that two operations started together
  /// overlap if nothing keeps them in turn.
  Duration delay = Duration.zero;

  /// How many writes succeeded.
  int writeCount = 0;

  @override
  Future<Map<String, String>> readAll() async {
    await Future<void>.delayed(delay);
    if (failRead) throw StateError('read failed');
    return Map.of(entries);
  }

  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(delay);
    if (failWriteWhen?.call(key) ?? false) throw StateError('write failed');
    entries[key] = value;
    writeCount++;
  }

  @override
  Future<void> delete(String key) async {
    await Future<void>.delayed(delay);
    entries.remove(key);
  }
}
