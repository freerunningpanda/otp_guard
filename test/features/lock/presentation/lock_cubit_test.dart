import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/lock/data/lock_json.dart';
import 'package:otp_guard/features/lock/data/secure_lock_repository.dart';
import 'package:otp_guard/features/lock/domain/biometric_auth.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';
import 'package:otp_guard/features/lock/domain/pin_hasher.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';

import '../../../support/accounts.dart';
import '../../../support/lock_harness.dart';

const wrongPin = '000000';

// A PIN record that reads well, for a test that damages another entry.
String encodeGoodPin() {
  return encodePinCredential(
    PinCredential(
      algorithm: PinHashAlgorithm.pbkdf2HmacSha256,
      iterations: 4,
      salt: Uint8List.fromList(List.filled(16, 1)),
      hash: Uint8List.fromList(List.filled(32, 2)),
    ),
  );
}

const String alias = BiometricAuth.defaultAlias;

// The states a cubit goes through while [action] runs.
Future<List<AppLockState>> statesDuring(
  LockCubit cubit,
  Future<void> Function() action,
) async {
  final states = <AppLockState>[];
  final subscription = cubit.stream.listen(states.add);
  await action();
  await pumpEventQueue();
  await subscription.cancel();
  return states;
}

void main() {
  late LockHarness h;

  setUp(() => h = LockHarness());

  tearDown(() => h.dispose());

  Future<void> wrongPins(int count) async {
    for (var i = 0; i < count; i++) {
      await h.cubit.unlockWithPin(wrongPin);
    }
  }

  group('load', () {
    test('starts loading', () {
      expect(h.cubit.state, const LockLoading());
    });

    test('asks for a PIN when none is set', () async {
      await h.cubit.load();

      expect(h.cubit.state, const PinNotSet());
    });

    test('is locked when a PIN is set', () async {
      await h.setUpLocked();

      final cubit = await h.restart();

      expect(cubit.state, const Locked());
    });

    test('knows that biometrics are on', () async {
      await h.setUpLockedWithBiometrics();

      final cubit = await h.restart();

      expect(h.locked.biometric, BiometricStatus.on);
      expect(cubit.state, isA<Locked>());
    });

    test('knows that biometrics have to be set up again', () async {
      await h.repository.writeBiometric(BiometricSetting.needsRenewal);
      await h.setUpLocked();
      await h.repository.writeBiometric(BiometricSetting.needsRenewal);

      await h.restart();

      expect(h.locked.biometric, BiometricStatus.needsRenewal);
    });

    test('does nothing the second time', () async {
      await h.cubit.load();

      final states = await statesDuring(h.cubit, h.cubit.load);

      expect(states, isEmpty);
      expect(h.cubit.state, const PinNotSet());
    });

    test('does not forget it is unlocked when called again', () async {
      await h.setUpUnlocked();

      await h.cubit.load();

      expect(h.cubit.state, isA<Unlocked>());
    });

    group('stays shut when the lock can not be read', () {
      test('a storage that fails', () async {
        h.breakStorage(reads: true);

        await h.cubit.load();

        expect(h.cubit.state, const LockLoadFailed());
      });

      test('a storage that fails is not a damaged record', () async {
        h.breakStorage(reads: true);

        await h.cubit.load();

        expect(h.cubit.state, const LockLoadFailed());
        expect((h.cubit.state as LockLoadFailed).isDamaged, isFalse);
      });

      test('a PIN record that is damaged is not "no PIN"', () async {
        await h.setUpLocked();
        h.store.entries[SecureLockRepository.pinKey] = 'garbage';

        await h.restart();

        expect(h.cubit.state, const LockLoadFailed(isDamaged: true));
        expect(h.cubit.state, isNot(isA<PinNotSet>()));
      });

      test('a record of the attempts that is damaged', () async {
        await h.setUpLocked();
        h.store.entries[SecureLockRepository.attemptsKey] = '{';

        await h.restart();

        expect(h.cubit.state, const LockLoadFailed(isDamaged: true));
      });

      test('a record of another version is damaged to this one', () async {
        await h.setUpLocked();
        h.store.entries[SecureLockRepository.pinKey] = '{"v":99}';

        await h.restart();

        expect(h.cubit.state, const LockLoadFailed(isDamaged: true));
      });

      test('an empty record is damaged', () async {
        await h.setUpLocked();
        h.store.entries[SecureLockRepository.pinKey] = '';

        await h.restart();

        expect(h.cubit.state, const LockLoadFailed(isDamaged: true));
      });

      test('a damaged record stays damaged when tried again', () async {
        await h.setUpLocked();
        h.store.entries[SecureLockRepository.pinKey] = 'garbage';
        await h.restart();

        await h.cubit.load();

        expect(h.cubit.state, const LockLoadFailed(isDamaged: true));
      });

      test('and tries again when asked', () async {
        await h.setUpLocked();
        h.breakStorage(reads: true);
        await h.restart();
        expect(h.cubit.state, const LockLoadFailed());

        h.fixStorage();
        final states = await statesDuring(h.cubit, h.cubit.load);

        expect(states, [const LockLoading(), const Locked()]);
      });
    });

    test('a damaged biometric record only costs the biometrics', () async {
      await h.setUpLockedWithBiometrics();
      h.store.entries[SecureLockRepository.biometricKey] = 'garbage';

      await h.restart();

      expect(h.cubit.state, const Locked());
    });

    test('shows a wait that was stored', () async {
      await h.setUpLocked();
      await wrongPins(5);

      await h.restart();

      expect(
        h.locked.retryAt,
        h.clock.now().add(const Duration(seconds: 30)),
      );
    });
  });

  group('setPin', () {
    setUp(() async => h.cubit.load());

    test('opens the app and offers the biometrics', () async {
      final result = await h.cubit.setPin(testPin);

      expect(result, SetPinResult.done);
      expect(h.cubit.state, const Unlocked(offer: BiometricOffer.setup));
    });

    test('keeps the hash, and not the PIN', () async {
      await h.cubit.setPin(testPin);

      final credential = await h.repository.readPin();
      expect(credential, isNotNull);
      expect(await h.hasher.verify(testPin, credential!), isTrue);
      expect(await h.hasher.verify(wrongPin, credential), isFalse);
      expect(h.store.entries.values.join(), isNot(contains(testPin)));
    });

    test('the PIN is asked for after a restart', () async {
      await h.cubit.setPin(testPin);

      await h.restart();

      expect(h.cubit.state, const Locked());
    });

    test('refuses a PIN that does not fit the rules', () async {
      for (final pin in ['', '12345', '1234567890123', '12345a', 'abcdef']) {
        expect(await h.cubit.setPin(pin), SetPinResult.invalid, reason: pin);
      }

      expect(h.cubit.state, const PinNotSet());
      expect(h.store.entries, isEmpty);
    });

    test('is refused when the lock does not wait for a PIN', () async {
      await h.cubit.setPin(testPin);
      h.cubit.lock();

      expect(await h.cubit.setPin('654321'), SetPinResult.invalid);
      expect(h.cubit.state, isA<Locked>());
    });

    test('reports a storage that fails, and can be tried again', () async {
      h.breakStorage(writes: (key) => true);

      expect(await h.cubit.setPin(testPin), SetPinResult.failed);
      expect(h.cubit.state, const PinNotSet());

      h.fixStorage();
      expect(await h.cubit.setPin(testPin), SetPinResult.done);
    });

    test('a PIN twice at once is set once', () async {
      final both = await Future.wait([
        h.cubit.setPin(testPin),
        h.cubit.setPin(testPin),
      ]);

      expect(both, [SetPinResult.done, SetPinResult.invalid]);
    });

    test('starts clean: no old attempts, no old biometrics', () async {
      await h.repository.writeAttempts(
        PinAttempts(
          attempts: 7,
          lockedUntil: h.clock.now().add(const Duration(hours: 1)),
        ),
      );
      await h.repository.writeBiometric(
        BiometricSetting.enabled(Uint8List.fromList([1, 2, 3])),
      );

      await h.cubit.setPin(testPin);

      expect(await h.repository.readAttempts(), PinAttempts.none);
      expect(await h.repository.readBiometric(), BiometricSetting.off);
    });
  });

  group('unlockWithPin', () {
    setUp(() async => h.setUpLocked());

    test('the right PIN opens the app', () async {
      await h.cubit.unlockWithPin(testPin);

      expect(h.cubit.state, const Unlocked());
    });

    test('a wrong PIN does not', () async {
      await h.cubit.unlockWithPin(wrongPin);

      expect(h.cubit.state, const Locked(problem: UnlockProblem.wrongPin));
    });

    test('is busy while it works, and then it is not', () async {
      final states = await statesDuring(
        h.cubit,
        () => h.cubit.unlockWithPin(wrongPin),
      );

      expect(states, [
        const Locked(isBusy: true),
        const Locked(problem: UnlockProblem.wrongPin),
      ]);
    });

    test('a second try while one works is ignored', () async {
      var runs = 0;
      final gate = Completer<void>();
      Future<R> slow<R>(R Function() task) async {
        runs++;
        await gate.future;
        return task();
      }

      await h.restart(
        hasher: PinHasher(iterations: 4, random: Random(1), compute: slow),
      );
      final first = h.cubit.unlockWithPin(testPin);
      await pumpEventQueue();
      await h.cubit.unlockWithPin(wrongPin);
      gate.complete();
      await first;

      expect(runs, 1);
      expect(h.cubit.state, isA<Unlocked>());
    });

    test('does nothing when the app is not locked', () async {
      await h.cubit.unlockWithPin(testPin);

      final states = await statesDuring(
        h.cubit,
        () => h.cubit.unlockWithPin(wrongPin),
      );

      expect(states, isEmpty);
      expect(h.cubit.state, isA<Unlocked>());
    });

    test('a right PIN clears the wrong ones', () async {
      await wrongPins(3);
      await h.cubit.unlockWithPin(testPin);
      h.cubit.lock();

      await wrongPins(4);

      // Seven wrong in all, but the first three were cleared: no wait yet.
      expect(h.locked.retryAt, isNull);
      expect((await h.repository.readAttempts()).attempts, 4);
    });

    group('the attempts', () {
      test('the first few wrong PINs cost no wait', () async {
        await wrongPins(AttemptPolicy.freeAttempts);

        expect(h.locked.retryAt, isNull);
        expect(h.locked.problem, UnlockProblem.wrongPin);
      });

      test('then a wait begins, and grows', () async {
        await wrongPins(5);
        expect(
          h.locked.retryAt,
          h.clock.now().add(const Duration(seconds: 30)),
        );

        h.clock.advance(const Duration(seconds: 30));
        await h.cubit.unlockWithPin(wrongPin);
        expect(h.locked.retryAt, h.clock.now().add(const Duration(minutes: 1)));

        h.clock.advance(const Duration(minutes: 1));
        await h.cubit.unlockWithPin(wrongPin);
        expect(h.locked.retryAt, h.clock.now().add(const Duration(minutes: 5)));

        h.clock.advance(const Duration(minutes: 5));
        await h.cubit.unlockWithPin(wrongPin);
        expect(
          h.locked.retryAt,
          h.clock.now().add(const Duration(minutes: 15)),
        );

        h.clock.advance(const Duration(minutes: 15));
        await h.cubit.unlockWithPin(wrongPin);
        expect(h.locked.retryAt, h.clock.now().add(const Duration(hours: 1)));
      });

      test('while the wait is on, even the right PIN is not tried', () async {
        await wrongPins(5);

        h.clock.advance(const Duration(seconds: 29));
        await h.cubit.unlockWithPin(testPin);

        expect(h.cubit.state, isA<Locked>());
        expect(h.locked.problem, isNull);
        expect(h.locked.retryAt, h.clock.now().add(const Duration(seconds: 1)));
      });

      test('a try during the wait is not counted', () async {
        await wrongPins(5);
        await h.cubit.unlockWithPin(wrongPin);
        await h.cubit.unlockWithPin(wrongPin);

        expect((await h.repository.readAttempts()).attempts, 5);
      });

      test('when the wait is over the right PIN opens the app', () async {
        await wrongPins(5);

        h.clock.advance(const Duration(seconds: 30));
        await h.cubit.unlockWithPin(testPin);

        expect(h.cubit.state, isA<Unlocked>());
        expect(await h.repository.readAttempts(), PinAttempts.none);
      });

      test('a wrong PIN after the wait starts a longer one', () async {
        await wrongPins(5);
        h.clock.advance(const Duration(seconds: 30));

        await h.cubit.unlockWithPin(wrongPin);

        expect(h.locked.problem, UnlockProblem.wrongPin);
        expect(h.locked.retryAt, h.clock.now().add(const Duration(minutes: 1)));
      });

      test('the wait survives a restart of the app', () async {
        await wrongPins(5);

        await h.restart();
        expect(
          h.locked.retryAt,
          h.clock.now().add(const Duration(seconds: 30)),
        );

        await h.cubit.unlockWithPin(testPin);
        expect(h.cubit.state, isA<Locked>(), reason: 'still waiting');

        h.clock.advance(const Duration(seconds: 31));
        await h.cubit.unlockWithPin(testPin);
        expect(h.cubit.state, isA<Unlocked>());
      });

      test('the count survives a restart of the app', () async {
        await wrongPins(3);
        await h.restart();

        await wrongPins(2);

        // Five in all, across the restart.
        expect(
          h.locked.retryAt,
          h.clock.now().add(const Duration(seconds: 30)),
        );
      });

      test('the wait is counted again if the clock is turned back', () async {
        await wrongPins(5);

        h.clock.advance(const Duration(hours: -2));
        await h.restart();
        await h.cubit.unlockWithPin(testPin);

        expect(h.cubit.state, isA<Locked>());
        expect(
          h.locked.retryAt,
          h.clock.now().add(const Duration(seconds: 30)),
        );

        h.clock.advance(const Duration(seconds: 29));
        await h.cubit.unlockWithPin(testPin);
        expect(h.cubit.state, isA<Locked>());
      });

      test('a try is counted before it is checked', () async {
        // Four wrong tries are on record. The fifth is being worked on when
        // the app is killed.
        await wrongPins(4);
        final gate = Completer<void>();
        Future<R> stuck<R>(R Function() task) async {
          await gate.future;
          return task();
        }

        await h.restart(
          hasher: PinHasher(iterations: 4, random: Random(1), compute: stuck),
        );
        unawaited(h.cubit.unlockWithPin(wrongPin));
        await pumpEventQueue();

        // The app dies here: the hash was never finished. What is stored is
        // what the next run sees.
        final next = h.newCubit();
        await next.load();
        addTearDown(next.close);

        expect((await h.repository.readAttempts()).attempts, 5);
        expect(
          (next.state as Locked).retryAt,
          h.clock.now().add(const Duration(seconds: 30)),
        );
        gate.complete();
      });

      test('a try that can not be written down is not let in', () async {
        var runs = 0;
        Future<R> counting<R>(R Function() task) async {
          runs++;
          return task();
        }

        await h.restart(
          hasher: PinHasher(
            iterations: 4,
            random: Random(1),
            compute: counting,
          ),
        );
        h.breakStorage(
          writes: (key) => key == SecureLockRepository.attemptsKey,
        );

        await h.cubit.unlockWithPin(testPin);

        expect(
          h.cubit.state,
          const Locked(problem: UnlockProblem.storageFailed),
        );
        expect(runs, 0, reason: 'the PIN was not even checked');
      });

      test('closing the cubit while the hash works is harmless', () async {
        final gate = Completer<void>();
        Future<R> slow<R>(R Function() task) async {
          await gate.future;
          return task();
        }

        await h.restart(
          hasher: PinHasher(iterations: 4, random: Random(1), compute: slow),
        );
        final unlocking = h.cubit.unlockWithPin(testPin);
        await pumpEventQueue();

        await h.cubit.close();
        gate.complete();

        await expectLater(unlocking, completes);
      });
    });

    group('the strength of the hash', () {
      test('a weaker hash is made stronger by a right PIN', () async {
        final weakHasher = PinHasher(
          iterations: 2,
          random: Random(5),
          compute: inPlace,
        );
        await h.repository.writePin(await weakHasher.create(testPin));
        await h.restart();

        await h.cubit.unlockWithPin(testPin);

        final stored = await h.repository.readPin();
        expect(stored!.iterations, h.hasher.iterations);
        expect(await h.hasher.verify(testPin, stored), isTrue);
      });

      test('and the new hash opens the app at the next start', () async {
        final weakHasher = PinHasher(
          iterations: 2,
          random: Random(5),
          compute: inPlace,
        );
        await h.repository.writePin(await weakHasher.create(testPin));
        await h.restart();
        await h.cubit.unlockWithPin(testPin);

        await h.restart();
        await h.cubit.unlockWithPin(testPin);

        expect(h.cubit.state, isA<Unlocked>());
      });

      test('a wrong PIN leaves the hash as it was', () async {
        final weakHasher = PinHasher(
          iterations: 2,
          random: Random(5),
          compute: inPlace,
        );
        final weak = await weakHasher.create(testPin);
        await h.repository.writePin(weak);
        await h.restart();

        await h.cubit.unlockWithPin(wrongPin);

        expect(await h.repository.readPin(), weak);
      });

      test('a hash that is strong enough is left alone', () async {
        final before = await h.repository.readPin();

        await h.cubit.unlockWithPin(testPin);

        expect(await h.repository.readPin(), before);
      });

      test('a failed upgrade does not keep the user out', () async {
        final weakHasher = PinHasher(
          iterations: 2,
          random: Random(5),
          compute: inPlace,
        );
        await h.repository.writePin(await weakHasher.create(testPin));
        await h.restart();
        h.breakStorage(writes: (key) => key == SecureLockRepository.pinKey);

        await h.cubit.unlockWithPin(testPin);

        expect(h.cubit.state, isA<Unlocked>());
      });
    });
  });

  group('resetApp', () {
    const newPin = '654321';

    setUp(() async {
      h.accounts.accounts.addAll([
        testAccount(),
        testAccount(id: 'id-2', name: 'bob'),
      ]);
      h.accounts.unreadableIds = ['broken'];
      await h.setUpLocked();
    });

    test('erases every account', () async {
      final done = await h.cubit.resetApp();

      expect(done, isTrue);
      expect(h.accounts.accounts, isEmpty);
      expect(h.accounts.unreadableIds, isEmpty);
      expect(h.accounts.removeAllCount, 1);
    });

    test('asks for a new PIN', () async {
      await h.cubit.resetApp();

      expect(h.cubit.state, const PinNotSet());
    });

    test(
      'goes through a busy state, and never through "no PIN" early',
      () async {
        final states = await statesDuring(h.cubit, h.cubit.resetApp);

        expect(states, [const Locked(isBusy: true), const PinNotSet()]);
      },
    );

    test('forgets the PIN, the attempts and the biometrics', () async {
      await h.cubit.resetApp();

      expect(await h.repository.readPin(), isNull);
      expect(await h.repository.readAttempts(), PinAttempts.none);
      expect(await h.repository.readBiometric(), BiometricSetting.off);
      expect(h.store.entries, isEmpty);
    });

    test('the next start asks for a PIN, too', () async {
      await h.cubit.resetApp();

      await h.restart();

      expect(h.cubit.state, const PinNotSet());
    });

    test('deletes the key in the hardware', () async {
      await h.cubit.unlockWithPin(testPin);
      await h.cubit.enableBiometrics();
      h.cubit.lock();
      expect(h.keys.hasKey(alias), isTrue);

      await h.cubit.resetApp();

      expect(h.keys.hasKey(alias), isFalse);
    });

    test('the old PIN does not open the new app', () async {
      await h.cubit.resetApp();
      await h.cubit.setPin(newPin);
      h.cubit.lock();

      await h.cubit.unlockWithPin(testPin);
      expect(h.cubit.state, isA<Locked>());
      expect(h.locked.problem, UnlockProblem.wrongPin);

      await h.cubit.unlockWithPin(newPin);
      expect(h.cubit.state, isA<Unlocked>());
    });

    test('a new PIN starts clean: no wait, no biometrics', () async {
      for (var i = 0; i < 6; i++) {
        await h.cubit.unlockWithPin(wrongPin);
      }
      expect(h.locked.retryAt, isNotNull);

      await h.cubit.resetApp();
      await h.cubit.setPin(newPin);
      h.cubit.lock();

      expect(h.cubit.state, const Locked());
    });

    test('works during a wait, which is the point of it', () async {
      for (var i = 0; i < 5; i++) {
        await h.cubit.unlockWithPin(wrongPin);
      }
      expect(h.locked.retryAt, isNotNull);

      expect(await h.cubit.resetApp(), isTrue);
      expect(h.cubit.state, const PinNotSet());
    });

    test('after it the app can be set up as new, with the offer', () async {
      await h.cubit.resetApp();

      expect(await h.cubit.setPin(newPin), SetPinResult.done);
      expect(h.cubit.state, const Unlocked(offer: BiometricOffer.setup));
    });

    group('is allowed only where the user is stuck', () {
      test('not while the app is open', () async {
        await h.cubit.unlockWithPin(testPin);

        expect(await h.cubit.resetApp(), isFalse);
        expect(h.accounts.accounts, hasLength(2));
        expect(h.cubit.state, isA<Unlocked>());
      });

      test('not while no PIN is set', () async {
        await h.cubit.resetApp();
        h.accounts.accounts.add(testAccount());

        expect(await h.cubit.resetApp(), isFalse);
        expect(h.accounts.accounts, hasLength(1));
      });

      test('not while the lock is loading', () async {
        final fresh = h.newCubit();
        addTearDown(fresh.close);

        expect(await fresh.resetApp(), isFalse);
        expect(h.accounts.accounts, hasLength(2));
      });

      test('not twice at once', () async {
        final both = await Future.wait([
          h.cubit.resetApp(),
          h.cubit.resetApp(),
        ]);

        expect(both, [true, false]);
        expect(h.accounts.removeAllCount, 1);
      });

      test('not while a PIN is being checked', () async {
        final gate = Completer<void>();
        Future<R> slow<R>(R Function() task) async {
          await gate.future;
          return task();
        }

        await h.restart(
          hasher: PinHasher(iterations: 4, random: Random(1), compute: slow),
        );
        final unlocking = h.cubit.unlockWithPin(testPin);
        await pumpEventQueue();

        expect(await h.cubit.resetApp(), isFalse);
        gate.complete();
        await unlocking;
      });
    });

    group('when it fails, the app stays locked', () {
      test('the accounts can not be erased', () async {
        h.accounts.failRemoving = true;

        final done = await h.cubit.resetApp();

        expect(done, isFalse);
        expect(
          h.cubit.state,
          const Locked(problem: UnlockProblem.resetFailed),
        );
      });

      test('and then the PIN is still stored, and still works', () async {
        h.accounts.failRemoving = true;
        await h.cubit.resetApp();

        expect(await h.repository.readPin(), isNotNull);
        await h.cubit.unlockWithPin(testPin);
        expect(h.cubit.state, isA<Unlocked>());
      });

      test('and a restart still asks for the PIN, not for a new one', () async {
        h.accounts.failRemoving = true;
        await h.cubit.resetApp();

        await h.restart();

        expect(h.cubit.state, isA<Locked>());
        expect(h.cubit.state, isNot(isA<PinNotSet>()));
      });

      test('it never asks for a new PIN while an account is left', () async {
        h.accounts.failRemoving = true;

        final states = await statesDuring(h.cubit, h.cubit.resetApp);

        expect(states, isNot(contains(isA<PinNotSet>())));
        expect(h.accounts.accounts, isNotEmpty);
      });

      test('the lock can not be erased, after the accounts were', () async {
        h.store.breakDeleting(SecureLockRepository.attemptsKey);

        final done = await h.cubit.resetApp();

        expect(done, isFalse);
        expect(
          h.cubit.state,
          const Locked(problem: UnlockProblem.resetFailed),
        );
        expect(h.accounts.accounts, isEmpty);
        expect(await h.repository.readPin(), isNotNull);
      });

      test('and it can be tried again', () async {
        h.accounts.failRemoving = true;
        await h.cubit.resetApp();
        expect(h.locked.problem, UnlockProblem.resetFailed);

        h.accounts.failRemoving = false;
        final done = await h.cubit.resetApp();

        expect(done, isTrue);
        expect(h.cubit.state, const PinNotSet());
        expect(h.accounts.accounts, isEmpty);
      });

      test('the wait that was on is still on', () async {
        for (var i = 0; i < 5; i++) {
          await h.cubit.unlockWithPin(wrongPin);
        }
        h.accounts.failRemoving = true;

        await h.cubit.resetApp();

        expect(h.locked.retryAt, isNotNull);
        expect(h.locked.problem, UnlockProblem.resetFailed);
      });
    });

    group('from a lock whose record is damaged', () {
      setUp(() async {
        h.store.entries[SecureLockRepository.pinKey] = 'garbage';
        await h.restart();
        expect(h.cubit.state, const LockLoadFailed(isDamaged: true));
      });

      test('is the way out of a dead end', () async {
        final done = await h.cubit.resetApp();

        expect(done, isTrue);
        expect(h.cubit.state, const PinNotSet());
        expect(h.accounts.accounts, isEmpty);
        expect(h.accounts.unreadableIds, isEmpty);
        expect(h.store.entries, isEmpty);
      });

      test('goes through a busy state, not through "no PIN" early', () async {
        final states = await statesDuring(h.cubit, h.cubit.resetApp);

        expect(states, [const LockLoading(), const PinNotSet()]);
      });

      test('a new PIN can be set after it, and opens the app', () async {
        await h.cubit.resetApp();

        expect(await h.cubit.setPin(newPin), SetPinResult.done);
        h.cubit.lock();
        await h.cubit.unlockWithPin(newPin);

        expect(h.cubit.state, isA<Unlocked>());
      });

      test('the next start reads the new state without a complaint', () async {
        await h.cubit.resetApp();
        await h.cubit.setPin(newPin);

        await h.restart();

        expect(h.cubit.state, const Locked());
      });

      test('a failure leaves it damaged, says so, and the accounts', () async {
        h.accounts.failRemoving = true;

        final done = await h.cubit.resetApp();

        expect(done, isFalse);
        expect(
          h.cubit.state,
          const LockLoadFailed(isDamaged: true, resetFailed: true),
        );
        expect(h.accounts.accounts, hasLength(2));
      });

      test('it never asks for a new PIN while an account is left', () async {
        h.accounts.failRemoving = true;

        final states = await statesDuring(h.cubit, h.cubit.resetApp);

        expect(states, isNot(contains(isA<PinNotSet>())));
      });

      test('and it can be tried again', () async {
        h.accounts.failRemoving = true;
        await h.cubit.resetApp();

        h.accounts.failRemoving = false;
        final done = await h.cubit.resetApp();

        expect(done, isTrue);
        expect(h.cubit.state, const PinNotSet());
      });

      test('the lock cannot be erased after the accounts were', () async {
        h.store.breakDeleting(SecureLockRepository.attemptsKey);

        final done = await h.cubit.resetApp();

        expect(done, isFalse);
        expect(h.cubit.state, isA<LockLoadFailed>());
        expect(h.accounts.accounts, isEmpty);
        expect(h.store.entries, contains(SecureLockRepository.pinKey));
      });

      test('a damaged record of the attempts is cleared, too', () async {
        h.store.entries[SecureLockRepository.pinKey] = encodeGoodPin();
        h.store.entries[SecureLockRepository.attemptsKey] = '{';
        await h.restart();
        expect(h.cubit.state, const LockLoadFailed(isDamaged: true));

        await h.cubit.resetApp();

        expect(h.store.entries, isEmpty);
        expect(h.cubit.state, const PinNotSet());
      });
    });

    group('from a lock whose storage failed', () {
      setUp(() async {
        h.breakStorage(reads: true);
        await h.restart();
        expect(h.cubit.state, const LockLoadFailed());
      });

      test('is refused: the storage may work at the next try', () async {
        final done = await h.cubit.resetApp();

        expect(done, isFalse);
        expect(h.cubit.state, const LockLoadFailed());
        expect(h.accounts.accounts, hasLength(2));
        expect(h.accounts.removeAllCount, 0);
        expect(h.store.entries, isNotEmpty);
      });

      test('and the next try gets the lock back, with the accounts', () async {
        await h.cubit.resetApp();

        h.fixStorage();
        await h.cubit.load();

        expect(h.cubit.state, const Locked());
        expect(h.accounts.accounts, hasLength(2));
      });
    });
  });

  group('unlockWithBiometrics', () {
    test('a signature of the chip opens the app', () async {
      await h.setUpLockedWithBiometrics();

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.cubit.state, const Unlocked(biometric: BiometricStatus.on));
    });

    test('the prompt gets the texts it is given', () async {
      await h.setUpLockedWithBiometrics();

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      final request = h.keys.signRequests.single;
      expect(request.title, testPromptTexts.title);
      expect(request.subtitle, testPromptTexts.subtitle);
      expect(request.cancelText, testPromptTexts.cancelText);
    });

    test('is busy while the prompt is on the screen', () async {
      await h.setUpLockedWithBiometrics();
      final gate = Completer<void>();
      h.keys.signWaitsFor = gate.future;

      final unlocking = h.cubit.unlockWithBiometrics(testPromptTexts);
      await pumpEventQueue();
      expect(h.locked.isBusy, isTrue);

      // The PIN is not tried under the prompt.
      await h.cubit.unlockWithPin(testPin);
      expect(h.cubit.state, isA<Locked>());

      gate.complete();
      await unlocking;
      expect(h.cubit.state, isA<Unlocked>());
    });

    test('does nothing when the biometrics are off', () async {
      await h.setUpLocked();

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.keys.signRequests, isEmpty);
      expect(h.cubit.state, const Locked());
    });

    test('does nothing when the app is open', () async {
      await h.setUpLockedWithBiometrics();
      await h.cubit.unlockWithPin(testPin);

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.keys.signRequests, isEmpty);
    });

    test('a closed prompt leaves the app locked, with no complaint', () async {
      await h.setUpLockedWithBiometrics();
      h.keys.signFailsWith = 'USER_CANCELED';

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.cubit.state, const Locked(biometric: BiometricStatus.on));
    });

    test('after a closed prompt the biometrics can be tried again', () async {
      await h.setUpLockedWithBiometrics();
      h.keys.signFailsWith = 'USER_CANCELED';
      await h.cubit.unlockWithBiometrics(testPromptTexts);

      h.keys.signFailsWith = null;
      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.cubit.state, isA<Unlocked>());
    });

    test('after a closed prompt the PIN opens the app', () async {
      await h.setUpLockedWithBiometrics();
      h.keys.signFailsWith = 'USER_CANCELED';
      await h.cubit.unlockWithBiometrics(testPromptTexts);

      await h.cubit.unlockWithPin(testPin);

      expect(h.cubit.state, isA<Unlocked>());
    });

    test('biometrics that are not available point to the PIN', () async {
      await h.setUpLockedWithBiometrics();
      h.keys.signFailsWith = 'BIOMETRY_UNAVAILABLE';

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(
        h.cubit.state,
        const Locked(
          biometric: BiometricStatus.on,
          problem: UnlockProblem.biometricUnavailable,
        ),
      );
    });

    test('a failure of the plugin points to the PIN', () async {
      await h.setUpLockedWithBiometrics();
      h.keys.signFailsWith = 'SIGNING_FAILED';

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.locked.problem, UnlockProblem.biometricFailed);
    });

    test('a signature that does not hold is not a yes', () async {
      await h.setUpLockedWithBiometrics();
      h.keys.signWithAnotherKey = true;

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.cubit.state, isA<Locked>());
      expect(h.locked.problem, UnlockProblem.biometricFailed);
    });

    test('bytes that are no signature are not a yes', () async {
      await h.setUpLockedWithBiometrics();
      h.keys.signReturns = Uint8List.fromList([1]);

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.cubit.state, isA<Locked>());
    });

    test('a success clears the wrong PINs and counts as none', () async {
      await h.setUpLockedWithBiometrics();
      await wrongPins(3);

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(await h.repository.readAttempts(), PinAttempts.none);
    });

    test('the biometrics work while the PIN has to wait', () async {
      await h.setUpLockedWithBiometrics();
      await wrongPins(5);
      expect(h.locked.retryAt, isNotNull);

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.cubit.state, isA<Unlocked>());
    });

    test('a wrong biometric try is not a wrong PIN', () async {
      await h.setUpLockedWithBiometrics();
      h.keys.signFailsWith = 'SIGNING_FAILED';
      for (var i = 0; i < 10; i++) {
        await h.cubit.unlockWithBiometrics(testPromptTexts);
      }

      expect(await h.repository.readAttempts(), PinAttempts.none);
      expect(h.locked.retryAt, isNull);
    });
  });

  group('KEY_INVALIDATED', () {
    late LockHarness locked;

    Future<void> fingerprintsChanged() async {
      await h.setUpLockedWithBiometrics();
      h.keys.invalidate(alias);
      await h.cubit.unlockWithBiometrics(testPromptTexts);
    }

    test('moves to the PIN, and says why', () async {
      await fingerprintsChanged();

      expect(
        h.cubit.state,
        const Locked(biometric: BiometricStatus.needsRenewal),
      );
    });

    test('is remembered, so the next start goes straight to the PIN', () async {
      await fingerprintsChanged();
      final prompts = h.keys.signRequests.length;

      await h.restart();
      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.locked.biometric, BiometricStatus.needsRenewal);
      expect(h.keys.signRequests.length, prompts, reason: 'no prompt');
    });

    test('the PIN opens the app, and offers the biometrics again', () async {
      await fingerprintsChanged();

      await h.cubit.unlockWithPin(testPin);

      expect(
        h.cubit.state,
        const Unlocked(
          biometric: BiometricStatus.needsRenewal,
          offer: BiometricOffer.renewal,
        ),
      );
    });

    test('accepting the offer sets the biometrics up with a new key', () async {
      await fingerprintsChanged();
      await h.cubit.unlockWithPin(testPin);
      final keysBefore = h.keys.generateCount;

      final result = await h.cubit.enableBiometrics();

      expect(result, EnableBiometricsResult.enabled);
      expect(h.keys.generateCount, keysBefore + 1);
      expect(h.cubit.state, const Unlocked(biometric: BiometricStatus.on));

      h.cubit.lock();
      await h.cubit.unlockWithBiometrics(testPromptTexts);
      expect(h.cubit.state, isA<Unlocked>());
    });

    test('the new setting is kept for the next start', () async {
      await fingerprintsChanged();
      await h.cubit.unlockWithPin(testPin);
      await h.cubit.enableBiometrics();

      await h.restart();

      expect(h.locked.biometric, BiometricStatus.on);
    });

    test('declining the offer turns the biometrics off for good', () async {
      await fingerprintsChanged();
      await h.cubit.unlockWithPin(testPin);

      await h.cubit.declineBiometricOffer();

      expect(h.cubit.state, const Unlocked());
      expect(await h.repository.readBiometric(), BiometricSetting.off);
      expect(h.keys.hasKey(alias), isFalse);

      h.cubit.lock();
      await h.cubit.unlockWithPin(testPin);
      expect(h.cubit.state, const Unlocked(), reason: 'no offer again');
    });

    test('a key that is gone is the same case', () async {
      await h.setUpLockedWithBiometrics();
      await h.keys.deleteKey(alias);

      await h.cubit.unlockWithBiometrics(testPromptTexts);

      expect(h.locked.biometric, BiometricStatus.needsRenewal);
    });

    test('a device that can not do it any more keeps the PIN', () async {
      await fingerprintsChanged();
      await h.cubit.unlockWithPin(testPin);
      h.keys.generateFailsWith = 'BIOMETRY_UNAVAILABLE';

      final result = await h.cubit.enableBiometrics();

      expect(result, EnableBiometricsResult.unavailable);
      expect(h.cubit.state, const Unlocked());
      expect(await h.repository.readBiometric(), BiometricSetting.off);
    });

    test('the PIN works as before', () async {
      locked = h;
      await fingerprintsChanged();

      await locked.cubit.unlockWithPin(wrongPin);
      expect(locked.locked.problem, UnlockProblem.wrongPin);
      await locked.cubit.unlockWithPin(testPin);

      expect(locked.cubit.state, isA<Unlocked>());
    });
  });

  group('enableBiometrics', () {
    setUp(() async => h.cubit.load());

    test('after the PIN is set, the offer is taken', () async {
      await h.cubit.setPin(testPin);

      final result = await h.cubit.enableBiometrics();

      expect(result, EnableBiometricsResult.enabled);
      expect(h.cubit.state, const Unlocked(biometric: BiometricStatus.on));
      final stored = await h.repository.readBiometric();
      expect(stored.status, BiometricStatus.on);
      expect(stored.publicKey, h.keys.keyOf(alias)!.publicKey);
    });

    test(
      'the key is in the hardware, and the app keeps only the public part',
      () async {
        await h.cubit.setPin(testPin);
        await h.cubit.enableBiometrics();

        expect(h.keys.hasKey(alias), isTrue);
        // The hash of the PIN and the public key. No private key is in the app.
        expect(
          h.store.entries.keys,
          unorderedEquals([
            SecureLockRepository.pinKey,
            SecureLockRepository.biometricKey,
          ]),
        );
      },
    );

    test('a device without secure hardware or enrolled biometrics', () async {
      await h.cubit.setPin(testPin);
      h.keys.generateFailsWith = 'UNAVAILABLE';

      final result = await h.cubit.enableBiometrics();

      expect(result, EnableBiometricsResult.unavailable);
      expect(h.cubit.state, const Unlocked());
      expect(await h.repository.readBiometric(), BiometricSetting.off);
      expect(h.keys.hasKey(alias), isFalse);
    });

    test('another failure of the plugin', () async {
      await h.cubit.setPin(testPin);
      h.keys.generateFailsWith = 'KEY_GENERATION_FAILED';

      expect(await h.cubit.enableBiometrics(), EnableBiometricsResult.failed);
      expect(h.cubit.state, const Unlocked());
    });

    test('a storage that fails leaves no key behind', () async {
      await h.cubit.setPin(testPin);
      h.breakStorage(writes: (key) => key == SecureLockRepository.biometricKey);

      final result = await h.cubit.enableBiometrics();

      expect(result, EnableBiometricsResult.failed);
      expect(h.keys.hasKey(alias), isFalse);
      expect(h.cubit.state, const Unlocked());
    });

    test('is refused while the app is locked', () async {
      await h.cubit.setPin(testPin);
      h.cubit.lock();

      expect(await h.cubit.enableBiometrics(), EnableBiometricsResult.failed);
      expect(h.keys.generateCount, 0);
    });
  });

  group('declineBiometricOffer and disableBiometrics', () {
    test('declining the first offer leaves the biometrics off', () async {
      await h.cubit.load();
      await h.cubit.setPin(testPin);

      await h.cubit.declineBiometricOffer();

      expect(h.cubit.state, const Unlocked());
      expect(h.keys.generateCount, 0);
    });

    test('turning the biometrics off deletes the key', () async {
      await h.setUpLockedWithBiometrics();
      await h.cubit.unlockWithBiometrics(testPromptTexts);

      final isOff = await h.cubit.disableBiometrics();

      expect(isOff, isTrue);
      expect(h.cubit.state, const Unlocked());
      expect(h.keys.hasKey(alias), isFalse);
      expect(await h.repository.readBiometric(), BiometricSetting.off);
    });

    test('turned off, they are off after a restart', () async {
      await h.setUpLockedWithBiometrics();
      await h.cubit.unlockWithBiometrics(testPromptTexts);
      await h.cubit.disableBiometrics();

      await h.restart();

      expect(h.cubit.state, const Locked());
    });

    test('a storage that fails keeps them on', () async {
      await h.setUpLockedWithBiometrics();
      await h.cubit.unlockWithBiometrics(testPromptTexts);
      h.breakStorage(writes: (key) => true);

      expect(await h.cubit.disableBiometrics(), isFalse);
      expect(h.unlocked.biometric, BiometricStatus.on);
      expect(h.keys.hasKey(alias), isTrue, reason: 'the key is still there');
    });

    test('is refused while the app is locked', () async {
      await h.setUpLockedWithBiometrics();

      expect(await h.cubit.disableBiometrics(), isFalse);
      expect(h.locked.biometric, BiometricStatus.on);
    });
  });

  group('lock', () {
    test('locks the app that is open', () async {
      await h.setUpUnlocked();

      h.cubit.lock();

      expect(h.cubit.state, const Locked());
    });

    test('keeps the wait that is on', () async {
      await h.setUpLocked();
      await wrongPins(5);
      h.clock.advance(const Duration(seconds: 30));
      await h.cubit.unlockWithPin(testPin);
      await wrongPins(0);

      h.cubit.lock();
      expect(h.locked.retryAt, isNull, reason: 'the right PIN cleared it');
    });

    test('does nothing when the app is not open', () async {
      await h.cubit.load();

      h.cubit.lock();

      expect(h.cubit.state, const PinNotSet());
    });
  });

  group('the app in the background', () {
    const timeout = LockCubit.defaultLockTimeout;

    setUp(() async {
      h = LockHarness();
      await h.setUpUnlocked();
    });

    test('away for as long as the timeout, it locks', () async {
      h.cubit.appHidden();
      h.clock.advance(timeout);
      h.cubit.appShown();

      expect(h.cubit.state, isA<Locked>());
    });

    test('away for longer, it locks', () async {
      h.cubit.appHidden();
      h.clock.advance(const Duration(hours: 3));
      h.cubit.appShown();

      expect(h.cubit.state, isA<Locked>());
    });

    test('away for less, it stays open', () async {
      h.cubit.appHidden();
      h.clock.advance(timeout - const Duration(milliseconds: 1));
      h.cubit.appShown();

      expect(h.cubit.state, isA<Unlocked>());
    });

    test('is not locked by being shown when it was never hidden', () async {
      // What an inactive app that was asked for a fingerprint or a face does:
      // it comes back without ever having been in the background.
      h.clock.advance(const Duration(hours: 3));
      h.cubit.appShown();

      expect(h.cubit.state, isA<Unlocked>());
    });

    test('the first hide counts, not the later ones', () async {
      h.cubit.appHidden();
      h.clock.advance(const Duration(seconds: 40));
      h.cubit.appHidden();
      h.clock.advance(const Duration(seconds: 40));
      h.cubit.appShown();

      expect(h.cubit.state, isA<Locked>());
    });

    test('every time away is measured from its own start', () async {
      h.cubit.appHidden();
      h.clock.advance(const Duration(seconds: 10));
      h.cubit.appShown();
      expect(h.cubit.state, isA<Unlocked>());

      h.clock.advance(const Duration(minutes: 30));
      h.cubit.appShown();
      expect(h.cubit.state, isA<Unlocked>(), reason: 'no new hide');

      h.cubit.appHidden();
      h.clock.advance(timeout);
      h.cubit.appShown();
      expect(h.cubit.state, isA<Locked>());
    });

    test('a time away while locked does not lock the next unlock', () async {
      h.cubit.lock();
      h.cubit.appHidden();
      h.clock.advance(const Duration(hours: 1));
      h.cubit.appShown();

      await h.cubit.unlockWithPin(testPin);
      h.cubit.appShown();

      expect(h.cubit.state, isA<Unlocked>());
    });

    test(
      'coming back after a fingerprint prompt does not lock again',
      () async {
        await h.cubit.enableBiometrics();
        h.cubit.lock();
        final gate = Completer<void>();
        h.keys.signWaitsFor = gate.future;

        final unlocking = h.cubit.unlockWithBiometrics(testPromptTexts);
        await pumpEventQueue();
        // The system may report the app away while its prompt is on the screen.
        h.cubit.appHidden();
        h.clock.advance(const Duration(hours: 1));
        gate.complete();
        await unlocking;
        h.cubit.appShown();

        expect(h.cubit.state, isA<Unlocked>());
      },
    );

    test('keeps the time away across other calls', () async {
      h.cubit.appHidden();
      h.clock.advance(timeout);
      await h.cubit.declineBiometricOffer();
      h.cubit.appShown();

      expect(h.cubit.state, isA<Locked>());
    });

    test('a timeout of zero locks at every return', () async {
      final strict = LockHarness(lockTimeout: Duration.zero);
      addTearDown(strict.dispose);
      await strict.setUpUnlocked();

      strict.cubit.appHidden();
      strict.cubit.appShown();

      expect(strict.cubit.state, isA<Locked>());
    });

    test('a one minute timeout is the default', () {
      expect(LockCubit.defaultLockTimeout, const Duration(minutes: 1));
    });
  });
}
