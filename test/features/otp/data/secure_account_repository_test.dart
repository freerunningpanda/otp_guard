import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/data/account_json.dart';
import 'package:otp_guard/features/otp/data/secure_account_repository.dart';
import 'package:otp_guard/features/otp/domain/account_repository.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';

import '../../../support/in_memory_key_value_store.dart';

const String prefix = SecureAccountRepository.keyPrefix;

OtpAccount account({
  String id = 'id-1',
  String? issuer = 'GitHub',
  String name = 'alex@example.com',
  List<int> secret = const [1, 2, 3, 4, 5],
}) {
  return OtpAccount(
    id: id,
    issuer: issuer,
    name: name,
    secret: Uint8List.fromList(secret),
  );
}

void main() {
  late InMemoryKeyValueStore store;
  late SecureAccountRepository repository;

  setUp(() {
    store = InMemoryKeyValueStore();
    repository = SecureAccountRepository(store);
  });

  group('add and getAccounts', () {
    test('an empty storage has no accounts', () async {
      final stored = await repository.getAccounts();

      expect(stored.accounts, isEmpty);
      expect(stored.unreadableIds, isEmpty);
    });

    test('an added account is returned', () async {
      final result = await repository.add(account());

      expect(result, AccountAdded(account()));
      expect((await repository.getAccounts()).accounts, [account()]);
    });

    test('the secret comes back byte for byte', () async {
      final secret = List.generate(256, (i) => i);
      await repository.add(account(secret: secret));

      final stored = (await repository.getAccounts()).accounts.single;

      expect(stored.secret, secret);
    });

    test('an account is one entry of the storage, named by its id', () async {
      await repository.add(account(id: 'a'));
      await repository.add(account(id: 'b', name: 'bob'));

      expect(store.entries.keys, unorderedEquals(['${prefix}a', '${prefix}b']));
      expect(
        decodeAccount(store.entries['${prefix}a']!, expectedId: 'a'),
        account(id: 'a'),
      );
    });

    test('accounts are sorted by issuer, then name, in any case', () async {
      await repository.add(account(id: '1', name: 'bob'));
      await repository.add(account(id: '2', issuer: 'github', name: 'Alice'));
      await repository.add(account(id: '3', issuer: null, name: 'carol'));
      await repository.add(account(id: '4', issuer: 'Apple', name: 'zed'));

      final ids = (await repository.getAccounts()).accounts.map((a) => a.id);

      // No issuer first; "github" and "GitHub" are the same issuer.
      expect(ids, ['3', '4', '2', '1']);
    });

    test('the list that is returned can not be changed', () async {
      await repository.add(account());

      final stored = await repository.getAccounts();

      expect(stored.accounts.clear, throwsUnsupportedError);
      expect(() => stored.unreadableIds.add('x'), throwsUnsupportedError);
    });
  });

  group('remove', () {
    test('removes that account and leaves the others', () async {
      await repository.add(account(id: 'a'));
      await repository.add(account(id: 'b', name: 'bob'));

      await repository.remove('a');

      final stored = await repository.getAccounts();
      expect(stored.accounts.map((a) => a.id), ['b']);
      expect(store.entries.keys, ['${prefix}b']);
    });

    test('an account that is not there is not an error', () async {
      await repository.add(account());

      await repository.remove('missing');

      expect((await repository.getAccounts()).accounts, [account()]);
    });

    test('a removed account can be added again', () async {
      await repository.add(account());
      await repository.remove('id-1');

      final result = await repository.add(account(id: 'id-2'));

      expect(result, isA<AccountAdded>());
    });
  });

  group('removeAll', () {
    test('removes every account', () async {
      await repository.add(account());
      await repository.add(account(id: 'id-2', name: 'bob'));

      await repository.removeAll();

      expect((await repository.getAccounts()).accounts, isEmpty);
      expect(store.entries, isEmpty);
    });

    test('does nothing when there are none', () async {
      await expectLater(repository.removeAll(), completes);
      expect(store.entries, isEmpty);
    });

    test('removes a record that can not be read, too', () async {
      await repository.add(account());
      store.entries['${prefix}broken'] = 'not a record';

      await repository.removeAll();

      expect(store.entries, isEmpty);
      expect((await repository.getAccounts()).unreadableIds, isEmpty);
    });

    test('leaves the entries of other parts of the app', () async {
      await repository.add(account());
      store.entries['otp.lock.pin'] = 'the PIN record';
      store.entries['something.else'] = 'value';

      await repository.removeAll();

      expect(store.entries, {
        'otp.lock.pin': 'the PIN record',
        'something.else': 'value',
      });
    });

    test('accounts can be added again afterwards', () async {
      await repository.add(account());
      await repository.removeAll();

      final result = await repository.add(account());

      expect(result, isA<AccountAdded>());
    });

    test('waits for an account that is being added', () async {
      store.delay = const Duration(milliseconds: 5);

      final adding = repository.add(account());
      final removing = repository.removeAll();
      await Future.wait([adding, removing]);

      expect((await repository.getAccounts()).accounts, isEmpty);
    });

    test('a storage that fails throws, and what is left stays', () async {
      await repository.add(account());
      await repository.add(account(id: 'id-2', name: 'bob'));
      store.failWriteWhen = (key) => key == '${prefix}id-2';

      await expectLater(repository.removeAll(), throwsStateError);

      store.failWriteWhen = null;
      expect((await repository.getAccounts()).accounts, hasLength(1));

      await repository.removeAll();
      expect(store.entries, isEmpty);
    });
  });

  group('the same QR code twice', () {
    test('the second scan finds the first account and adds nothing', () async {
      const uri =
          'otpauth://totp/GitHub:alex@example.com?secret=JBSWY3DPEHPK3PXP';
      // Two scans make two accounts with different ids and the same source.
      final first = (parseOtpAuthUri(uri) as OtpAuthParsed).account;
      final second = (parseOtpAuthUri(uri) as OtpAuthParsed).account;
      expect(first.id, isNot(second.id));

      final added = await repository.add(first);
      final repeated = await repository.add(second);

      expect(added, AccountAdded(first));
      expect(repeated, AccountAlreadyExists(first));
      expect((await repository.getAccounts()).accounts, [first]);
      expect(store.writeCount, 1);
    });

    test('the same label with another secret is another account', () async {
      await repository.add(account(id: 'a', secret: [1, 2, 3]));

      final result = await repository.add(account(id: 'b', secret: [4, 5, 6]));

      expect(result, isA<AccountAdded>());
      expect((await repository.getAccounts()).accounts, hasLength(2));
    });

    test('the same secret under another name is another account', () async {
      await repository.add(account(id: 'a', name: 'alex'));

      final result = await repository.add(account(id: 'b', name: 'bob'));

      expect(result, isA<AccountAdded>());
    });

    test('two scans at the same moment add one account, not two', () async {
      // Each call waits, so without a queue both would see an empty storage.
      store.delay = const Duration(milliseconds: 5);

      final results = await Future.wait([
        repository.add(account(id: 'a')),
        repository.add(account(id: 'b')),
      ]);

      expect(results.whereType<AccountAdded>(), hasLength(1));
      expect(results.whereType<AccountAlreadyExists>(), hasLength(1));
      expect(store.entries, hasLength(1));
    });
  });

  group('add refuses', () {
    test(
      'an id that is taken by another account, and keeps the first',
      () async {
        await repository.add(account(id: 'same'));

        await expectLater(
          repository.add(account(id: 'same', name: 'bob')),
          throwsStateError,
        );

        expect((await repository.getAccounts()).accounts, [
          account(id: 'same'),
        ]);
      },
    );

    test('an id that is taken by a record that can not be read', () async {
      store.entries['${prefix}same'] = 'damaged';

      await expectLater(
        repository.add(account(id: 'same')),
        throwsStateError,
      );

      expect(store.entries['${prefix}same'], 'damaged');
    });
  });

  group('a record that can not be read', () {
    final healthy = account(id: 'good');
    final records = <String, String>{
      'is not JSON': 'garbage',
      'is empty': '',
      'is of an unknown version': jsonEncode({
        ...jsonDecode(encodeAccount(account(id: 'bad')))
            as Map<String, Object?>,
        'v': 99,
      }),
      'is under another id': encodeAccount(account(id: 'other')),
      'has a secret that is not Base64': jsonEncode({
        ...jsonDecode(encodeAccount(account(id: 'bad')))
            as Map<String, Object?>,
        'secret': '***',
      }),
    };
    for (final entry in records.entries) {
      test('${entry.key} does not stop the others', () async {
        await repository.add(healthy);
        store.entries['${prefix}bad'] = entry.value;

        final stored = await repository.getAccounts();

        expect(stored.accounts, [healthy]);
        expect(stored.unreadableIds, ['bad']);
      });
    }

    test('stays in the storage, for a later version to read', () async {
      store.entries['${prefix}bad'] = 'garbage';

      await repository.getAccounts();

      expect(store.entries['${prefix}bad'], 'garbage');
    });

    test('can be removed by its id', () async {
      await repository.add(healthy);
      store.entries['${prefix}bad'] = 'garbage';

      await repository.remove('bad');

      final stored = await repository.getAccounts();
      expect(stored.accounts, [healthy]);
      expect(stored.unreadableIds, isEmpty);
    });

    test('is reported again on every read', () async {
      store.entries['${prefix}bad'] = 'garbage';

      expect((await repository.getAccounts()).unreadableIds, ['bad']);
      expect((await repository.getAccounts()).unreadableIds, ['bad']);
    });
  });

  test('entries of other parts of the app are left alone', () async {
    store.entries['something.else'] = 'value';
    await repository.add(account());

    final stored = await repository.getAccounts();

    expect(stored.accounts, [account()]);
    expect(stored.unreadableIds, isEmpty);
    expect(store.entries['something.else'], 'value');
  });

  group('a failing storage', () {
    test(
      'a failed write throws, and the other accounts are untouched',
      () async {
        await repository.add(account(id: 'a'));
        store.failWriteWhen = (key) => key == '${prefix}b';

        await expectLater(
          repository.add(account(id: 'b', name: 'bob')),
          throwsStateError,
        );

        expect(store.entries.keys, ['${prefix}a']);
        expect((await repository.getAccounts()).accounts, [account(id: 'a')]);
      },
    );

    test('the repository works again after a failure', () async {
      store.failWriteWhen = (key) => true;
      await expectLater(repository.add(account()), throwsStateError);

      store.failWriteWhen = null;
      final result = await repository.add(account());

      expect(result, isA<AccountAdded>());
    });

    test('a failed read throws, and the next read can succeed', () async {
      await repository.add(account());
      store.failRead = true;
      await expectLater(repository.getAccounts(), throwsStateError);

      store.failRead = false;

      expect((await repository.getAccounts()).accounts, [account()]);
    });
  });

  test('no entry of the storage holds the secret in the clear', () async {
    final secret = utf8.encode('SUPERSECRETSUPERSECRET');
    await repository.add(account(secret: secret));

    for (final entry in store.entries.entries) {
      expect(entry.key, isNot(contains('SUPERSECRET')));
      expect(entry.value, isNot(contains('SUPERSECRET')));
    }
  });
}
