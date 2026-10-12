import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// How a PIN is turned into the hash that is stored.
enum PinHashAlgorithm {
  /// PBKDF2 with HMAC-SHA-256: slow on purpose, with a random salt.
  pbkdf2HmacSha256('pbkdf2-hmac-sha256');

  const PinHashAlgorithm(this.id);

  /// The name in the stored record. It never changes for an algorithm, or old
  /// records could not be read.
  final String id;

  /// The algorithm with the name [id], or null.
  static PinHashAlgorithm? fromId(String id) {
    for (final algorithm in values) {
      if (algorithm.id == id) return algorithm;
    }
    return null;
  }
}

/// What is stored in place of a PIN: the hash, and everything needed to
/// compute it again from a typed PIN.
///
/// The salt, the number of iterations and the algorithm are kept with the hash
/// on purpose. A PIN is checked with the parameters it was hashed with, so the
/// parameters can be made stronger later and the old records still work.
class PinCredential extends Equatable {
  /// Creates the credential.
  const PinCredential({
    required this.algorithm,
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  /// How [hash] was made.
  final PinHashAlgorithm algorithm;

  /// How many rounds of the function were run.
  final int iterations;

  /// The random bytes mixed into the PIN. Different for every credential, so
  /// two people with the same PIN have different hashes and a table of hashes
  /// of common PINs is useless.
  final Uint8List salt;

  /// The derived key.
  final Uint8List hash;

  @override
  List<Object?> get props => [algorithm, iterations, salt, hash];

  // The hash is not for logs.
  @override
  String toString() {
    return 'PinCredential(${algorithm.id}, iterations: $iterations)';
  }
}
