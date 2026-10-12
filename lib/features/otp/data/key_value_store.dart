/// The part of a secure storage that the account repository needs.
///
/// A small interface of its own, so the repository does not depend on a
/// plugin and a test can use a store in memory, even one that fails.
abstract interface class KeyValueStore {
  /// All the entries.
  Future<Map<String, String>> readAll();

  /// The value of [key], or null if there is none. For a part of the app that
  /// needs one entry and should not read the secrets of the others.
  Future<String?> read(String key);

  /// Writes [value] under [key], replacing what was there.
  Future<void> write(String key, String value);

  /// Deletes [key]. Does nothing if there is none.
  Future<void> delete(String key);
}
