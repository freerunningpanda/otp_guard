import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_state.dart';
import 'package:otp_guard/features/otp/presentation/accounts/add_account_outcome.dart';

import '../../../../support/accounts.dart';
import '../../../../support/fake_account_repository.dart';

const goodLink =
    'otpauth://totp/GitHub:alex@example.com?secret=JBSWY3DPEHPK3PXP';

void main() {
  late FakeAccountRepository repository;
  var counter = 0;

  AccountsCubit build() =>
      AccountsCubit(repository, newId: () => 'new-${++counter}');

  setUp(() {
    repository = FakeAccountRepository();
    counter = 0;
  });

  test('starts in the loading state', () async {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const AccountsLoading());
  });

  group('load', () {
    blocTest<AccountsCubit, AccountsState>(
      'shows the accounts that are stored',
      setUp: () => repository = FakeAccountRepository(
        accounts: [
          testAccount(),
          testAccount(id: 'id-2', name: 'bob'),
        ],
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const AccountsLoading(),
        AccountsLoaded(
          accounts: [
            testAccount(),
            testAccount(id: 'id-2', name: 'bob'),
          ],
        ),
      ],
    );

    blocTest<AccountsCubit, AccountsState>(
      'shows an empty list when nothing is stored',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const AccountsLoading(),
        const AccountsLoaded(accounts: []),
      ],
    );

    blocTest<AccountsCubit, AccountsState>(
      'passes on the ids of the records that could not be read',
      setUp: () => repository = FakeAccountRepository(
        accounts: [testAccount()],
        unreadableIds: ['broken'],
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const AccountsLoading(),
        AccountsLoaded(
          accounts: [testAccount()],
          unreadableIds: const ['broken'],
        ),
      ],
    );

    blocTest<AccountsCubit, AccountsState>(
      'is a failure when the storage can not be read',
      setUp: () => repository.failReading = true,
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const AccountsLoading(), const AccountsFailure()],
    );

    blocTest<AccountsCubit, AccountsState>(
      'works again after a failure',
      build: build,
      act: (cubit) async {
        repository.failReading = true;
        await cubit.load();
        repository.failReading = false;
        await cubit.load();
      },
      expect: () => [
        const AccountsLoading(),
        const AccountsFailure(),
        const AccountsLoading(),
        const AccountsLoaded(accounts: []),
      ],
    );
  });

  group('addFromUri', () {
    test('saves the account of a link and puts it in the list', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();

      final outcome = await cubit.addFromUri(goodLink);

      expect(outcome, isA<AccountSaved>());
      final saved = (outcome as AccountSaved).account;
      expect(saved.id, 'new-1');
      expect(saved.issuer, 'GitHub');
      expect(saved.name, 'alex@example.com');
      expect(repository.added, [saved]);
      expect(cubit.state, AccountsLoaded(accounts: [saved]));
    });

    test('the same link twice is a duplicate, and the list stays', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      final first = await cubit.addFromUri(goodLink) as AccountSaved;
      final stateAfterFirst = cubit.state;
      final states = <AccountsState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      final second = await cubit.addFromUri(goodLink);

      expect(second, AccountDuplicate(first.account));
      expect(cubit.state, stateAfterFirst);
      expect(states, isEmpty);
      expect(repository.accounts, hasLength(1));
    });

    test('a link that is not usable is rejected, nothing is stored', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();

      final outcomes = {
        'hello': const NotAnOtpAuthUri(),
        'otpauth://hotp/a?secret=JBSWY3DPEHPK3PXP': const UnsupportedOtpType(
          'hotp',
        ),
        'otpauth://totp/a': const MissingSecret(),
        'otpauth://totp/a?secret=abc1': const InvalidSecret(),
        'otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&digits=5':
            const InvalidParameter('digits', '5'),
      };
      for (final entry in outcomes.entries) {
        expect(
          await cubit.addFromUri(entry.key),
          AccountRejected(entry.value),
          reason: entry.key,
        );
      }
      expect(repository.added, isEmpty);
      expect(cubit.state, const AccountsLoaded(accounts: []));
    });

    test('a failing storage gives AccountStorageFailed', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      repository.failAdding = true;

      final outcome = await cubit.addFromUri(goodLink);

      expect(outcome, const AccountStorageFailed());
      expect(cubit.state, const AccountsLoaded(accounts: []));
    });

    test(
      'an account that is saved but can not be listed is a failure',
      () async {
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.load();
        repository.failReading = true;

        final outcome = await cubit.addFromUri(goodLink);

        // It is saved, and the screen is told so; the list can not be read now.
        expect(outcome, isA<AccountSaved>());
        expect(cubit.state, const AccountsFailure());
      },
    );
  });

  group('addManual', () {
    test('saves what was typed', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();

      final outcome = await cubit.addManual(
        issuer: 'GitHub',
        name: 'alex',
        secret: 'JBSWY3DPEHPK3PXP',
      );

      expect(outcome, isA<AccountSaved>());
      expect(
        (cubit.state as AccountsLoaded).accounts.single.name,
        'alex',
      );
    });

    test('says which field is wrong', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();

      expect(
        await cubit.addManual(name: '', secret: 'JBSWY3DPEHPK3PXP'),
        const AccountRejected(MissingLabel()),
      );
      expect(
        await cubit.addManual(name: 'alex', secret: ''),
        const AccountRejected(MissingSecret()),
      );
      expect(
        await cubit.addManual(name: 'alex', secret: 'abc1'),
        const AccountRejected(InvalidSecret()),
      );
      expect(repository.added, isEmpty);
    });

    test('the same account typed twice is a duplicate', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.addManual(name: 'alex', secret: 'JBSWY3DPEHPK3PXP');

      final outcome = await cubit.addManual(
        name: 'alex',
        secret: 'jbsw y3dp ehpk 3pxp',
      );

      expect(outcome, isA<AccountDuplicate>());
    });
  });

  group('remove', () {
    blocTest<AccountsCubit, AccountsState>(
      'removes the account and updates the list',
      setUp: () => repository = FakeAccountRepository(
        accounts: [
          testAccount(),
          testAccount(id: 'id-2', name: 'bob'),
        ],
      ),
      build: build,
      seed: () => AccountsLoaded(
        accounts: [
          testAccount(),
          testAccount(id: 'id-2', name: 'bob'),
        ],
      ),
      act: (cubit) async => expect(await cubit.remove('id-1'), isTrue),
      expect: () => [
        AccountsLoaded(
          accounts: [testAccount(id: 'id-2', name: 'bob')],
        ),
      ],
      verify: (_) => expect(repository.removed, ['id-1']),
    );

    blocTest<AccountsCubit, AccountsState>(
      'keeps the list when the storage fails, and says so',
      setUp: () {
        repository = FakeAccountRepository(accounts: [testAccount()])
          ..failRemoving = true;
      },
      build: build,
      seed: () => AccountsLoaded(accounts: [testAccount()]),
      act: (cubit) async => expect(await cubit.remove('id-1'), isFalse),
      expect: () => <AccountsState>[],
    );

    blocTest<AccountsCubit, AccountsState>(
      'removes the records that could not be read',
      setUp: () => repository = FakeAccountRepository(
        accounts: [testAccount()],
        unreadableIds: ['bad-1', 'bad-2'],
      ),
      build: build,
      seed: () => AccountsLoaded(
        accounts: [testAccount()],
        unreadableIds: const ['bad-1', 'bad-2'],
      ),
      act: (cubit) async => expect(await cubit.removeUnreadable(), isTrue),
      expect: () => [
        AccountsLoaded(accounts: [testAccount()]),
      ],
      verify: (_) => expect(repository.removed, ['bad-1', 'bad-2']),
    );
  });
}
