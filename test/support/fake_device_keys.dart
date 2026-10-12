import 'dart:math';

import 'package:flutter/services.dart';
import 'package:otp_guard/core/security/device_keys.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

// The start of an X.509 SubjectPublicKeyInfo for a P-256 key, the format that
// the plugin returns on both platforms.
const _spkiHeader = <int>[
  0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, //
  0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
  0x42, 0x00,
];

/// A real P-256 key pair, to sign with in a test and to hand out the public
/// part in the format of the plugin.
class FakeKeyPair {
  FakeKeyPair._(this._private, this.publicKey);

  factory FakeKeyPair.generate() {
    final random = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List.generate(32, (_) => Random.secure().nextInt(256)),
          ),
        ),
      );
    final domain = ECDomainParameters('prime256v1');
    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(ECKeyGeneratorParameters(domain), random),
      );
    final pair = generator.generateKeyPair();
    final public = pair.publicKey;
    return FakeKeyPair._(
      pair.privateKey,
      Uint8List.fromList([..._spkiHeader, ...public.Q!.getEncoded(false)]),
    );
  }

  final ECPrivateKey _private;

  /// X.509 DER, 91 bytes.
  final Uint8List publicKey;

  /// ECDSA over the SHA-256 of [message], in DER.
  Uint8List sign(Uint8List message) {
    final random = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List.generate(32, (_) => Random.secure().nextInt(256)),
          ),
        ),
      );
    final signer = ECDSASigner(SHA256Digest())
      ..init(
        true,
        ParametersWithRandom(
          PrivateKeyParameter<ECPrivateKey>(_private),
          random,
        ),
      );
    final signature = signer.generateSignature(message) as ECSignature;
    return ASN1Sequence(
      elements: [ASN1Integer(signature.r), ASN1Integer(signature.s)],
    ).encode();
  }
}

/// What the biometric prompt was given.
class SignRequest {
  SignRequest(
    this.alias,
    this.challenge,
    this.title,
    this.cancelText,
    this.subtitle,
  );

  final String alias;
  final Uint8List challenge;
  final String title;
  final String cancelText;
  final String? subtitle;
}

/// The [DeviceKeys] of a test: real keys in memory, signing like the chip
/// does, and a way to make each call fail like the plugin does.
class FakeDeviceKeys implements DeviceKeys {
  final _keys = <String, FakeKeyPair>{};
  final _invalidated = <String>{};

  /// Every call to `sign`, in order.
  final signRequests = <SignRequest>[];

  /// How many keys were made.
  int generateCount = 0;

  /// The code `generateKey` fails with, or null.
  String? generateFailsWith;

  /// The code `sign` fails with, or null. A test sets `KEY_INVALIDATED`,
  /// `USER_CANCELED` and the others of the plugin.
  String? signFailsWith;

  /// If true, the plugin is missing: every call throws
  /// `MissingPluginException`.
  bool pluginMissing = false;

  /// If true, `sign` returns the signature of a key that is not the stored
  /// one, as something that fakes the chip would.
  bool signWithAnotherKey = false;

  /// If set, `sign` returns these bytes instead of a signature.
  Uint8List? signReturns;

  /// If set, `sign` waits for it, as a prompt that is still on the screen.
  Future<void>? signWaitsFor;

  /// If set, `generateKey` returns these bytes in place of a public key.
  Uint8List? publicKeyOverride;

  /// Whether a key exists under [alias].
  bool hasKey(String alias) => _keys.containsKey(alias);

  /// The key pair under [alias], for a test that wants to sign itself.
  FakeKeyPair? keyOf(String alias) => _keys[alias];

  /// Makes the key under [alias] stop working, as a changed set of
  /// fingerprints does. A new key under the alias works again.
  void invalidate(String alias) => _invalidated.add(alias);

  @override
  Future<Uint8List> generateKey(String alias) async {
    _checkPlugin();
    final code = generateFailsWith;
    if (code != null) throw PlatformException(code: code);
    if (_keys.containsKey(alias)) throw PlatformException(code: 'KEY_EXISTS');
    generateCount++;
    _invalidated.remove(alias);
    final pair = FakeKeyPair.generate();
    _keys[alias] = pair;
    return publicKeyOverride ?? pair.publicKey;
  }

  @override
  Future<void> deleteKey(String alias) async {
    _checkPlugin();
    _keys.remove(alias);
    _invalidated.remove(alias);
  }

  @override
  Future<Uint8List> sign(
    String alias,
    Uint8List challenge, {
    required String title,
    required String cancelText,
    String? subtitle,
  }) async {
    _checkPlugin();
    signRequests.add(
      SignRequest(alias, challenge, title, cancelText, subtitle),
    );
    await signWaitsFor;
    final code = signFailsWith;
    if (code != null) throw PlatformException(code: code);
    final pair = _keys[alias];
    if (pair == null) throw PlatformException(code: 'KEY_NOT_FOUND');
    if (_invalidated.contains(alias)) {
      throw PlatformException(code: 'KEY_INVALIDATED');
    }
    final returns = signReturns;
    if (returns != null) return returns;
    if (signWithAnotherKey) return FakeKeyPair.generate().sign(challenge);
    return pair.sign(challenge);
  }

  void _checkPlugin() {
    if (pluginMissing) throw MissingPluginException();
  }
}
