import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/data/flutter_secure_key_value_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterSecureKeyValueStore', () {
    late FlutterSecureKeyValueStore store;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({'existing': 'value'});
      store = FlutterSecureKeyValueStore();
    });

    test('reads all entries', () async {
      expect(await store.readAll(), {'existing': 'value'});
    });

    test('reads one entry, and null for what is not there', () async {
      expect(await store.read('existing'), 'value');
      expect(await store.read('missing'), isNull);
    });

    test('writes, replaces and deletes an entry', () async {
      await store.write('key', 'one');
      expect(await store.readAll(), {'existing': 'value', 'key': 'one'});

      await store.write('key', 'two');
      expect((await store.readAll())['key'], 'two');

      await store.delete('key');
      expect(await store.readAll(), {'existing': 'value'});
    });

    test('deleting what is not there is not an error', () async {
      await store.delete('missing');

      expect(await store.readAll(), {'existing': 'value'});
    });
  });

  group('the settings of the default storage', () {
    const storage = FlutterSecureKeyValueStore.defaultStorage;

    test('iOS: readable only while unlocked, and never off this device', () {
      final options = storage.iOptions.toMap();

      expect(options['accessibility'], 'unlocked_this_device');
      expect(options['synchronizable'], 'false');
    });

    test('Android: an error never erases the accounts', () {
      expect(storage.aOptions.toMap()['resetOnError'], 'false');
    });
  });
}
