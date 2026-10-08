import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/ecdsa_verifier.dart';

// The vectors were made by implementations other than the code under test, in
// the formats the plugin returns: the public key as X.509 DER (what
// generateKey returns) and the signature as ECDSA in DER (what sign returns).
// CryptoKit stands for iOS, whose SecKeyCreateSignature gives the same X9.62
// DER, and the JDK's SHA256withECDSA stands for Android.
Uint8List hex(String text) => Uint8List.fromList([
  for (var i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
]);

class _Vector {
  const _Vector(this.name, this.publicKey, this.message, this.signature);
  final String name;
  final String publicKey;
  final String message;
  final String signature;
}

const _vectors = [
  _Vector(
    'CryptoKit (Apple)',
    '3059301306072a8648ce3d020106082a8648ce3d0301070342000460c51981ae'
        '650cf958ee0f3229c28a5ef554d5d99ac5877ccf93315e7ac86edd0d8af00a5b'
        '70121375c1aea2149ed0b06e6f18c044d730dacf1def203a4a191c',
    '6368616c6c656e67652d66726f6d2d63727970746f6b6974',
    '30460221009558534dff8222c52eb94761cdfda1ecdc81fc18d836f3257f2fb5'
        '54ca2954e2022100ec257049ee7a020c3ab9a9ea47cf05a402c38662ad4bf300'
        '4739e354d1cdad60',
  ),
  _Vector(
    'JDK SHA256withECDSA',
    '3059301306072a8648ce3d020106082a8648ce3d03010703420004d7c8f02b47'
        '4fbf46cd38f0b142f37eab760f06d7b9d8ccf349e00fdfe99438e0f8ff19244b'
        'a85b74289f5ab12762aee087e47dbbd529ce681e1e9649411103aa',
    '6368616c6c656e67652d66726f6d2d6a617661',
    '304502207be0437ac33e04367849c69627ba73e72571bfbdcfd6bfeb432a8cd1'
        'ecf71a1d022100ea164446ae4ab841ad2589e60d1c0430c0ca315307bc026b82'
        'e3ed27ff9becf9',
  ),
];

void main() {
  for (final vector in _vectors) {
    group('verifyP256Signature with a vector from ${vector.name}', () {
      final publicKey = hex(vector.publicKey);
      final message = hex(vector.message);
      final signature = hex(vector.signature);

      test('accepts the genuine signature', () {
        expect(
          verifyP256Signature(
            publicKey: publicKey,
            message: message,
            signature: signature,
          ),
          isTrue,
        );
      });

      test('rejects a changed message', () {
        final changed = Uint8List.fromList(message)..[0] ^= 1;

        expect(
          verifyP256Signature(
            publicKey: publicKey,
            message: changed,
            signature: signature,
          ),
          isFalse,
        );
      });

      test('rejects a changed signature', () {
        final changed = Uint8List.fromList(signature)..[10] ^= 1;

        expect(
          verifyP256Signature(
            publicKey: publicKey,
            message: message,
            signature: changed,
          ),
          isFalse,
        );
      });

      test('rejects a signature that is not DER', () {
        expect(
          verifyP256Signature(
            publicKey: publicKey,
            message: message,
            signature: Uint8List.fromList([1, 2, 3]),
          ),
          isFalse,
        );
      });
    });
  }

  test('a signature does not verify under another key', () {
    final other = hex(_vectors[1].publicKey);

    expect(
      verifyP256Signature(
        publicKey: other,
        message: hex(_vectors[0].message),
        signature: hex(_vectors[0].signature),
      ),
      isFalse,
    );
  });

  test('a public key in another format is a FormatException', () {
    // The raw 65-byte point, the format iOS gives before the plugin wraps it.
    final raw = hex(_vectors[0].publicKey).sublist(26);

    expect(
      () => verifyP256Signature(
        publicKey: raw,
        message: hex(_vectors[0].message),
        signature: hex(_vectors[0].signature),
      ),
      throwsFormatException,
    );
  });
}
