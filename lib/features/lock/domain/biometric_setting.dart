import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Whether the user signs in with a fingerprint or a face.
enum BiometricStatus {
  /// Not set up, or turned off.
  off,

  /// On: a key in the secure hardware signs the challenges.
  on,

  /// It was on, and the key stopped working: the fingerprints or faces of the
  /// device changed (`KEY_INVALIDATED`), or the key is gone. The PIN is the
  /// way in until the user turns it on again.
  needsRenewal,
}

/// The stored side of the biometric sign-in: the status, and the public key
/// that the signatures are checked with.
class BiometricSetting extends Equatable {
  const BiometricSetting._(this.status, this.publicKey);

  /// On, with the public key that `generateKey` returned.
  factory BiometricSetting.enabled(Uint8List publicKey) {
    return BiometricSetting._(BiometricStatus.on, publicKey);
  }

  /// Not set up.
  static const off = BiometricSetting._(BiometricStatus.off, null);

  /// Was on, and has to be set up again.
  static const needsRenewal = BiometricSetting._(
    BiometricStatus.needsRenewal,
    null,
  );

  /// Whether it is on, off or has to be renewed.
  final BiometricStatus status;

  /// The public key, X.509 DER. Set when the status is [BiometricStatus.on].
  final Uint8List? publicKey;

  @override
  List<Object?> get props => [status, publicKey];
}
