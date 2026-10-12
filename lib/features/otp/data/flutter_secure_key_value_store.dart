import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp_guard/features/otp/data/key_value_store.dart';

/// A [KeyValueStore] on the Keychain of iOS and the encrypted storage of
/// Android, through flutter_secure_storage.
class FlutterSecureKeyValueStore implements KeyValueStore {
  /// Creates the store. A [storage] can be given for a test.
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? defaultStorage;

  /// The storage with the settings chosen for secrets that the user opens in
  /// the app:
  ///
  /// - iOS: `unlocked_this_device`. An entry can be read only while the device
  ///   is unlocked, and it never leaves this device (no backup, no iCloud).
  ///   There is no background work here, so `first_unlock`, which lets
  ///   background services read it, is not needed.
  /// - Android: `resetOnError` is off. The library default is on, and it would
  ///   erase ALL entries on a failed decryption, for example after a restore
  ///   onto another phone. A read error must not cost the user their accounts.
  static const defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    aOptions: AndroidOptions(resetOnError: false),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
