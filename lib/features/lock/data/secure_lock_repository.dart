import 'package:otp_guard/features/lock/data/lock_json.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/lock_repository.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';
import 'package:otp_guard/features/otp/data/key_value_store.dart';

/// Keeps the state of the lock in a secure [KeyValueStore], the same one that
/// holds the accounts, under keys of its own.
///
/// It reads one entry at a time and never everything: the secrets of the
/// accounts are in the same store, and the lock has no business with them.
class SecureLockRepository implements LockRepository {
  /// Creates the repository on a `store`.
  SecureLockRepository(this._store);

  /// The entry with the hash of the PIN.
  static const pinKey = 'otp.lock.pin';

  /// The entry with the attempts at the PIN.
  static const attemptsKey = 'otp.lock.attempts';

  /// The entry with the biometric setting.
  static const biometricKey = 'otp.lock.biometric';

  final KeyValueStore _store;

  @override
  Future<PinCredential?> readPin() async {
    final record = await _store.read(pinKey);
    return record == null ? null : decodePinCredential(record);
  }

  @override
  Future<void> writePin(PinCredential credential) {
    return _store.write(pinKey, encodePinCredential(credential));
  }

  @override
  Future<PinAttempts> readAttempts() async {
    final record = await _store.read(attemptsKey);
    return record == null ? PinAttempts.none : decodeAttempts(record);
  }

  @override
  Future<void> writeAttempts(PinAttempts attempts) {
    if (attempts == PinAttempts.none) return _store.delete(attemptsKey);
    return _store.write(attemptsKey, encodeAttempts(attempts));
  }

  @override
  Future<BiometricSetting> readBiometric() async {
    final record = await _store.read(biometricKey);
    return record == null
        ? BiometricSetting.off
        : decodeBiometricSetting(record);
  }

  @override
  Future<void> writeBiometric(BiometricSetting setting) {
    if (setting == BiometricSetting.off) return _store.delete(biometricKey);
    return _store.write(biometricKey, encodeBiometricSetting(setting));
  }

  @override
  Future<void> erase() async {
    await _store.delete(biometricKey);
    await _store.delete(attemptsKey);
    // The PIN goes last. The app asks for a new PIN only when none is stored,
    // and until then the old one still guards the way in.
    await _store.delete(pinKey);
  }
}
