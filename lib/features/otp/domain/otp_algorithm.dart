import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// The hash function behind the HMAC of a one-time code.
///
/// SHA-1 is the default of RFC 4226 and the one almost every service uses.
/// RFC 6238 also allows SHA-256 and SHA-512.
enum OtpAlgorithm {
  sha1,
  sha256,
  sha512;

  /// The HMAC of [message] with [key] under this hash function.
  Uint8List hmac(Uint8List key, Uint8List message) {
    final hash = switch (this) {
      OtpAlgorithm.sha1 => crypto.sha1,
      OtpAlgorithm.sha256 => crypto.sha256,
      OtpAlgorithm.sha512 => crypto.sha512,
    };
    return Uint8List.fromList(crypto.Hmac(hash, key).convert(message).bytes);
  }
}
