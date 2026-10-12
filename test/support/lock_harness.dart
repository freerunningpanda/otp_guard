import 'dart:math';

import 'package:otp_guard/features/lock/data/secure_lock_repository.dart';
import 'package:otp_guard/features/lock/domain/biometric_auth.dart';
import 'package:otp_guard/features/lock/domain/pin_hasher.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';

import 'fake_account_repository.dart';
import 'fake_clock.dart';
import 'fake_device_keys.dart';
import 'in_memory_key_value_store.dart';

/// The PIN that the tests set and type.
const testPin = '123456';

/// The texts that the tests give to the biometric prompt.
const testPromptTexts = BiometricPromptTexts(
  title: 'Confirm',
  subtitle: 'The app is locked',
  cancelText: 'Cancel',
);

// Runs the work at once, in this isolate: a test needs neither a new isolate
// nor the real number of rounds.
Future<R> inPlace<R>(R Function() task) async => task();

/// Everything a lock is made of, with the fakes in reach of a test.
///
/// [newCubit] makes another cubit on the same storage, the clock and the keys:
/// a new run of the app on the same phone.
class LockHarness {
  LockHarness({
    int iterations = 4,
    this.lockTimeout = LockCubit.defaultLockTimeout,
    FakeClock? clock,
    FakeAccountRepository? accounts,
  }) : clock = clock ?? FakeClock.atUnix(1000000),
       accounts = accounts ?? FakeAccountRepository(),
       store = InMemoryKeyValueStore(),
       keys = FakeDeviceKeys(),
       hasher = PinHasher(
         iterations: iterations,
         random: Random(1),
         compute: inPlace,
       ) {
    repository = SecureLockRepository(store);
    cubit = newCubit();
  }

  final Duration lockTimeout;
  final FakeClock clock;

  /// The accounts, which a reset erases.
  final FakeAccountRepository accounts;
  final InMemoryKeyValueStore store;
  final FakeDeviceKeys keys;
  final PinHasher hasher;
  late final SecureLockRepository repository;
  late LockCubit cubit;

  /// A new cubit on the same storage, clock and keys. The old one is closed.
  LockCubit newCubit({PinHasher? hasher, Duration? lockTimeout}) {
    return LockCubit(
      repository: SecureLockRepository(store),
      accounts: accounts,
      hasher: hasher ?? this.hasher,
      biometrics: BiometricAuth(keys, random: Random(2)),
      clock: clock,
      lockTimeout: lockTimeout ?? this.lockTimeout,
    );
  }

  /// A new run of the app: the cubit is closed and another one made, and it
  /// loads.
  Future<LockCubit> restart({PinHasher? hasher}) async {
    await cubit.close();
    cubit = newCubit(hasher: hasher);
    await cubit.load();
    return cubit;
  }

  /// Loads, sets [testPin] and leaves the app unlocked, the offer declined.
  Future<LockCubit> setUpUnlocked() async {
    await cubit.load();
    await cubit.setPin(testPin);
    await cubit.declineBiometricOffer();
    return cubit;
  }

  /// Sets the PIN, turns the biometrics on and locks the app.
  Future<LockCubit> setUpLockedWithBiometrics() async {
    await setUpUnlocked();
    await cubit.enableBiometrics();
    cubit.lock();
    return cubit;
  }

  /// Sets the PIN and locks the app.
  Future<LockCubit> setUpLocked() async {
    await setUpUnlocked();
    cubit.lock();
    return cubit;
  }

  /// Makes the storage fail like a real one, with an [Exception]: every read
  /// if [reads] is true, and every write of a key for which [writes] says so.
  void breakStorage({bool reads = false, bool Function(String key)? writes}) {
    store.fail = () => throw const FakeStorageException();
    store.failRead = reads;
    store.failWriteWhen = writes;
  }

  /// The storage works again.
  void fixStorage() {
    store.failRead = false;
    store.failWriteWhen = null;
  }

  Locked get locked => cubit.state as Locked;

  Unlocked get unlocked => cubit.state as Unlocked;

  Future<void> dispose() => cubit.close();
}
