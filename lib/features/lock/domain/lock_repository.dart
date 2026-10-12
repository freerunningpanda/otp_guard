import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';

/// Keeps what the lock must remember between runs of the app: the hash of the
/// PIN, the attempts at it, and the biometric setting.
///
/// A read throws a [FormatException] for a record that is damaged, and any
/// other exception if the storage failed. The lock does not open on either.
abstract interface class LockRepository {
  /// The stored PIN, or null if none is set.
  Future<PinCredential?> readPin();

  /// Stores [credential] in place of the PIN that was there.
  Future<void> writePin(PinCredential credential);

  /// The attempts at the PIN, [PinAttempts.none] if there are none.
  Future<PinAttempts> readAttempts();

  /// Stores [attempts]. [PinAttempts.none] clears the record.
  Future<void> writeAttempts(PinAttempts attempts);

  /// The biometric setting, [BiometricSetting.off] if there is none.
  Future<BiometricSetting> readBiometric();

  /// Stores [setting]. [BiometricSetting.off] clears the record.
  Future<void> writeBiometric(BiometricSetting setting);

  /// Deletes everything the lock remembers: the biometric setting and the
  /// attempts first, and the PIN last. If it fails half-way, the PIN is still
  /// there, and the app stays locked instead of asking for a new PIN.
  Future<void> erase();
}
