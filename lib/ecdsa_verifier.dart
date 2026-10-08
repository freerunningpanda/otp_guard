import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

// The start of an X.509 SubjectPublicKeyInfo in DER for a P-256 key, the
// format that DeviceSecurity.generateKey returns on both platforms. The 65
// bytes of the key follow it: 91 bytes in all.
const _p256PublicKeyHeader = <int>[
  0x30, 0x59, // SEQUENCE, 89 bytes follow
  0x30, 0x13, // SEQUENCE: the algorithm
  0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, // ecPublicKey
  0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, // P-256
  0x03, 0x42, 0x00, // BIT STRING, 66 bytes: 0 unused bits, then the key
];

/// Checks an ECDSA P-256 signature over the SHA-256 of [message].
///
/// [publicKey] is what `DeviceSecurity.generateKey` returned, X.509
/// SubjectPublicKeyInfo in DER. [signature] is what `DeviceSecurity.sign`
/// returned, ECDSA in DER. This is what a server does with the same bytes, so
/// a `true` here shows that the key format, the signature format and the
/// algorithm all match at once.
///
/// Returns `false` for a signature that is wrong or malformed. Throws a
/// [FormatException] if [publicKey] is not in the documented format, because
/// that is a broken contract, not a bad signature.
bool verifyP256Signature({
  required Uint8List publicKey,
  required Uint8List message,
  required Uint8List signature,
}) {
  final domain = ECDomainParameters('prime256v1');
  final point = domain.curve.decodePoint(_pointOf(publicKey));
  if (point == null) {
    throw const FormatException('The public key is not a point of P-256');
  }
  final signatureValues = _parseDerSignature(signature);
  if (signatureValues == null) return false;

  final verifier = ECDSASigner(SHA256Digest())
    ..init(false, PublicKeyParameter<ECPublicKey>(ECPublicKey(point, domain)));
  return verifier.verifySignature(
    message,
    ECSignature(signatureValues.$1, signatureValues.$2),
  );
}

// The 65 bytes of the key (0x04, X, Y) behind the fixed header.
Uint8List _pointOf(Uint8List publicKey) {
  const headerLength = 26;
  final hasHeader =
      publicKey.length == headerLength + 65 &&
      List.generate(
        headerLength,
        (i) => publicKey[i] == _p256PublicKeyHeader[i],
      ).every((same) => same);
  if (!hasHeader) {
    throw const FormatException(
      'The public key is not an X.509 DER key of 91 bytes for P-256',
    );
  }
  return Uint8List.sublistView(publicKey, headerLength);
}

// A DER signature is SEQUENCE { INTEGER r, INTEGER s }.
(BigInt, BigInt)? _parseDerSignature(Uint8List signature) {
  try {
    final sequence = ASN1Parser(signature).nextObject();
    if (sequence is! ASN1Sequence) return null;
    final elements = sequence.elements;
    if (elements == null || elements.length != 2) return null;
    final r = elements[0];
    final s = elements[1];
    if (r is! ASN1Integer || s is! ASN1Integer) return null;
    final rValue = r.integer;
    final sValue = s.integer;
    if (rValue == null || sValue == null) return null;
    return (rValue, sValue);
  } on Object {
    return null;
  }
}
