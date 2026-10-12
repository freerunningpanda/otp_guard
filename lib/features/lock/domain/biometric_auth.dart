import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:otp_guard/core/security/device_keys.dart';
import 'package:otp_guard/ecdsa_verifier.dart';

/// The texts of the system prompt for a fingerprint or a face. They belong to
/// the app, not to the plugin, so the app words and translates them.
class BiometricPromptTexts extends Equatable {
  /// Creates the texts. [title] and [cancelText] must not be empty.
  const BiometricPromptTexts({
    required this.title,
    required this.cancelText,
    this.subtitle,
  });

  /// The headline of the prompt.
  final String title;

  /// The label of the cancel button.
  final String cancelText;

  /// An explanation under the headline, or null.
  final String? subtitle;

  @override
  List<Object?> get props => [title, cancelText, subtitle];
}

/// What came of setting up the biometric sign-in.
sealed class BiometricEnrollment {
  const BiometricEnrollment();
}

/// The key is made. [publicKey] is what the signatures are checked with.
final class BiometricEnrolled extends BiometricEnrollment {
  /// Creates the result.
  const BiometricEnrolled(this.publicKey);

  /// X.509 DER, as `generateKey` returned it.
  final Uint8List publicKey;
}

/// The device can not do it: no secure hardware for the key, or no
/// fingerprints or faces are set up.
final class BiometricEnrollUnavailable extends BiometricEnrollment {
  /// Creates the result.
  const BiometricEnrollUnavailable();
}

/// It failed for another reason.
final class BiometricEnrollFailed extends BiometricEnrollment {
  /// Creates the result.
  const BiometricEnrollFailed();
}

/// What came of one try to sign in with a fingerprint or a face.
sealed class BiometricAttempt {
  const BiometricAttempt();
}

/// The hardware signed the challenge, and the signature is right: the user
/// confirmed with a fingerprint or a face.
final class BiometricVerified extends BiometricAttempt {
  /// Creates the result.
  const BiometricVerified();
}

/// The user closed the prompt.
final class BiometricCanceled extends BiometricAttempt {
  /// Creates the result.
  const BiometricCanceled();
}

/// The key does not work any more: the fingerprints or faces of the device
/// changed (`KEY_INVALIDATED`), or the key is gone or unusable. The user has to
/// set the biometrics up again.
final class BiometricKeyInvalidated extends BiometricAttempt {
  /// Creates the result.
  const BiometricKeyInvalidated();
}

/// Biometrics are not available right now: not set up, or locked out by the
/// system after too many wrong tries.
final class BiometricUnavailable extends BiometricAttempt {
  /// Creates the result.
  const BiometricUnavailable();
}

/// The hardware returned a signature, and it does not match the challenge and
/// the stored public key. Something is wrong, and it is not taken as a yes.
final class BiometricSignatureInvalid extends BiometricAttempt {
  /// Creates the result.
  const BiometricSignatureInvalid();
}

/// It failed for another reason.
final class BiometricFailed extends BiometricAttempt {
  /// Creates the result.
  const BiometricFailed();
}

/// Signs in with a fingerprint or a face through a key in the secure hardware.
///
/// This is not a yes or a no from the system, as `local_auth` gives, which
/// anything that can change the answer can fake. The app makes a random
/// challenge, the chip signs it only after the biometric check, and the app
/// checks the signature with the public key it kept at set-up. A "yes" cannot
/// be produced without the private key, and the private key never leaves the
/// chip.
class BiometricAuth {
  /// Creates it on the [DeviceKeys]. A test gives its own [random].
  BiometricAuth(this._keys, {Random? random, this.alias = defaultAlias})
    : _random = random ?? Random.secure();

  /// The alias of the key of the lock.
  static const defaultAlias = 'com.freerunningpanda.otp_guard.unlock';

  /// The length of a challenge in bytes.
  static const challengeLength = 32;

  /// The alias the key is made under.
  final String alias;

  final DeviceKeys _keys;
  final Random _random;

  /// Makes the key and returns its public part.
  ///
  /// A key left from an earlier run is deleted first. The plugin refuses to
  /// replace one, and after `KEY_INVALIDATED` there is always one.
  Future<BiometricEnrollment> enroll() async {
    try {
      await _keys.deleteKey(alias);
      final publicKey = await _keys.generateKey(alias);
      if (!_isUsable(publicKey)) {
        await remove();
        return const BiometricEnrollFailed();
      }
      return BiometricEnrolled(publicKey);
    } on PlatformException catch (e) {
      return switch (e.code) {
        'UNAVAILABLE' ||
        'BIOMETRY_UNAVAILABLE' => const BiometricEnrollUnavailable(),
        _ => const BiometricEnrollFailed(),
      };
    } on MissingPluginException {
      return const BiometricEnrollUnavailable();
    }
  }

  /// Asks for a fingerprint or a face and checks the proof.
  ///
  /// The challenge is new every time, so an old signature is no good.
  Future<BiometricAttempt> authenticate({
    required Uint8List publicKey,
    required BiometricPromptTexts texts,
  }) async {
    final challenge = Uint8List.fromList(
      List.generate(challengeLength, (_) => _random.nextInt(256)),
    );
    final Uint8List signature;
    try {
      signature = await _keys.sign(
        alias,
        challenge,
        title: texts.title,
        subtitle: texts.subtitle,
        cancelText: texts.cancelText,
      );
    } on PlatformException catch (e) {
      return switch (e.code) {
        'USER_CANCELED' => const BiometricCanceled(),
        'KEY_INVALIDATED' || 'KEY_NOT_FOUND' => const BiometricKeyInvalidated(),
        'BIOMETRY_UNAVAILABLE' || 'UNAVAILABLE' => const BiometricUnavailable(),
        _ => const BiometricFailed(),
      };
    } on MissingPluginException {
      return const BiometricUnavailable();
    }

    try {
      final isValid = verifyP256Signature(
        publicKey: publicKey,
        message: challenge,
        signature: signature,
      );
      return isValid
          ? const BiometricVerified()
          : const BiometricSignatureInvalid();
    } on FormatException {
      // The stored key is not a P-256 key. It can never verify anything, so
      // the biometrics have to be set up again.
      return const BiometricKeyInvalidated();
    }
  }

  /// Deletes the key. A failure is ignored: the key is of no use without the
  /// public key that the lock forgets at the same time.
  Future<void> remove() async {
    try {
      await _keys.deleteKey(alias);
    } on PlatformException {
      // Nothing to do about it.
    } on MissingPluginException {
      // No plugin, no key.
    }
  }

  // A key that is not P-256 in X.509 DER would be accepted here and never
  // verify, and the user would find out only at the first sign-in.
  bool _isUsable(Uint8List publicKey) {
    try {
      verifyP256Signature(
        publicKey: publicKey,
        message: Uint8List(1),
        signature: Uint8List(0),
      );
      return true;
    } on FormatException {
      return false;
    }
  }
}
