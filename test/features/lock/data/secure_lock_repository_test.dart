import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/lock/data/secure_lock_repository.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';

import '../../../support/in_memory_key_value_store.dart';

final credential = PinCredential(
  algorithm: PinHashAlgorithm.pbkdf2HmacSha256,
  iterations: 1000,
  salt: Uint8List.fromList(List.generate(16, (i) => i)),
  hash: Uint8List.fromList(List.generate(32, (i) => i + 100)),
);

void main() {
  late InMemoryKeyValueStore store;
  late SecureLockRepository repository;

  setUp(() {
    store = InMemoryKeyValueStore();
    repository = SecureLockRepository(store);
  });

  test('a new repository has no PIN, no attempts and no biometrics', () async {
    expect(await repository.readPin(), isNull);
    expect(await repository.readAttempts(), PinAttempts.none);
    expect(await repository.readBiometric(), BiometricSetting.off);
  });

  group('the PIN', () {
    test('is written and read', () async {
      await repository.writePin(credential);

      expect(await repository.readPin(), credential);
    });

    test('is replaced by a new one', () async {
      final other = PinCredential(
        algorithm: credential.algorithm,
        iterations: 2000,
        salt: credential.salt,
        hash: credential.hash,
      );
      await repository.writePin(credential);
      await repository.writePin(other);

      expect(await repository.readPin(), other);
    });

    test('is still there for a new repository on the same storage', () async {
      await repository.writePin(credential);

      expect(await SecureLockRepository(store).readPin(), credential);
    });

    test('a damaged record is a FormatException', () async {
      store.entries[SecureLockRepository.pinKey] = 'garbage';

      await expectLater(repository.readPin(), throwsFormatException);
    });
  });

  group('the attempts', () {
    final attempts = PinAttempts(
      attempts: 6,
      lastAttemptAt: DateTime.utc(2026, 10, 12, 8, 30),
      lockedUntil: DateTime.utc(2026, 10, 12, 8, 31),
    );

    test('are written and read', () async {
      await repository.writeAttempts(attempts);

      expect(await repository.readAttempts(), attempts);
    });

    test('are still there after the app is restarted', () async {
      await repository.writeAttempts(attempts);

      // A new repository stands for a new run of the app on the same storage.
      expect(await SecureLockRepository(store).readAttempts(), attempts);
    });

    test('are cleared by writing none, and leave no record', () async {
      await repository.writeAttempts(attempts);
      await repository.writeAttempts(PinAttempts.none);

      expect(await repository.readAttempts(), PinAttempts.none);
      expect(
        store.entries.containsKey(SecureLockRepository.attemptsKey),
        isFalse,
      );
    });

    test('a damaged record is a FormatException', () async {
      store.entries[SecureLockRepository.attemptsKey] = '{"v":1';

      await expectLater(repository.readAttempts(), throwsFormatException);
    });
  });

  group('the biometric setting', () {
    final enabled = BiometricSetting.enabled(
      Uint8List.fromList(List.generate(91, (i) => i)),
    );

    test('is written and read', () async {
      await repository.writeBiometric(enabled);
      expect(await repository.readBiometric(), enabled);

      await repository.writeBiometric(BiometricSetting.needsRenewal);
      expect(await repository.readBiometric(), BiometricSetting.needsRenewal);
    });

    test('is turned off by writing off, and leaves no record', () async {
      await repository.writeBiometric(enabled);
      await repository.writeBiometric(BiometricSetting.off);

      expect(await repository.readBiometric(), BiometricSetting.off);
      expect(
        store.entries.containsKey(SecureLockRepository.biometricKey),
        isFalse,
      );
    });
  });

  group('erase', () {
    final enabled = BiometricSetting.enabled(
      Uint8List.fromList(List.generate(91, (i) => i)),
    );

    Future<void> fillEverything() async {
      await repository.writePin(credential);
      await repository.writeAttempts(
        PinAttempts(attempts: 5, lockedUntil: DateTime.utc(2030)),
      );
      await repository.writeBiometric(enabled);
    }

    test('removes the PIN, the attempts and the biometric setting', () async {
      await fillEverything();

      await repository.erase();

      expect(await repository.readPin(), isNull);
      expect(await repository.readAttempts(), PinAttempts.none);
      expect(await repository.readBiometric(), BiometricSetting.off);
      expect(store.entries, isEmpty);
    });

    test('does nothing when there is nothing', () async {
      await expectLater(repository.erase(), completes);
    });

    test('leaves the entries of other parts of the app', () async {
      await fillEverything();
      store.entries['otp.account.id-1'] = 'an account';

      await repository.erase();

      expect(store.entries, {'otp.account.id-1': 'an account'});
    });

    test('the PIN goes last: if the biometric entry fails, it stays', () async {
      await fillEverything();
      store.breakDeleting(SecureLockRepository.biometricKey);

      await expectLater(repository.erase(), throwsA(isA<Exception>()));

      expect(await repository.readPin(), credential);
    });

    test('the PIN goes last: if the attempts entry fails, it stays', () async {
      await fillEverything();
      store.breakDeleting(SecureLockRepository.attemptsKey);

      await expectLater(repository.erase(), throwsA(isA<Exception>()));

      expect(await repository.readPin(), credential);
    });

    test('and it can be erased again after a failure', () async {
      await fillEverything();
      store.breakDeleting(SecureLockRepository.attemptsKey);
      await expectLater(repository.erase(), throwsA(isA<Exception>()));

      store.failWriteWhen = null;
      await repository.erase();

      expect(store.entries, isEmpty);
    });
  });

  group('beside the accounts', () {
    test('it reads one entry and never all of them', () async {
      await repository.writePin(credential);
      await repository.readPin();
      await repository.readAttempts();
      await repository.readBiometric();

      expect(store.readAllCount, 0);
    });

    test('its keys do not look like the keys of an account', () {
      for (final key in [
        SecureLockRepository.pinKey,
        SecureLockRepository.attemptsKey,
        SecureLockRepository.biometricKey,
      ]) {
        expect(key, startsWith('otp.lock.'));
        expect(key, isNot(startsWith('otp.account.')));
      }
    });
  });

  group('a failing storage', () {
    test('a failed read throws, and the next one can succeed', () async {
      await repository.writePin(credential);
      store.failRead = true;
      await expectLater(repository.readPin(), throwsStateError);

      store.failRead = false;

      expect(await repository.readPin(), credential);
    });

    test('a failed write throws and keeps what was there', () async {
      await repository.writePin(credential);
      store.failWriteWhen = (key) => true;
      final other = PinCredential(
        algorithm: credential.algorithm,
        iterations: 5,
        salt: credential.salt,
        hash: credential.hash,
      );

      await expectLater(repository.writePin(other), throwsStateError);

      store.failWriteWhen = null;
      expect(await repository.readPin(), credential);
    });
  });
}
