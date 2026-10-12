import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/ecdsa_verifier.dart';
import 'package:otp_guard/features/lock/domain/biometric_auth.dart';

import '../../../support/fake_device_keys.dart';

const texts = BiometricPromptTexts(
  title: 'Confirm',
  subtitle: 'Locked',
  cancelText: 'Cancel',
);

void main() {
  late FakeDeviceKeys keys;
  late BiometricAuth auth;

  setUp(() {
    keys = FakeDeviceKeys();
    auth = BiometricAuth(keys, random: Random(3));
  });

  Future<Uint8List> enrolled() async {
    final result = await auth.enroll();
    return (result as BiometricEnrolled).publicKey;
  }

  group('enroll', () {
    test('makes a key under the alias and returns its public part', () async {
      final result = await auth.enroll();

      expect(result, isA<BiometricEnrolled>());
      expect(keys.hasKey(auth.alias), isTrue);
      expect(
        (result as BiometricEnrolled).publicKey,
        keys.keyOf(auth.alias)!.publicKey,
      );
      expect(result.publicKey, hasLength(91));
    });

    test('replaces a key left by an earlier run', () async {
      final first = await enrolled();
      final second = await enrolled();

      expect(second, isNot(first));
      expect(keys.generateCount, 2);
      expect(keys.hasKey(auth.alias), isTrue);
    });

    test(
      'UNAVAILABLE and BIOMETRY_UNAVAILABLE mean the device can not',
      () async {
        for (final code in ['UNAVAILABLE', 'BIOMETRY_UNAVAILABLE']) {
          keys.generateFailsWith = code;

          expect(
            await auth.enroll(),
            isA<BiometricEnrollUnavailable>(),
            reason: code,
          );
        }
      },
    );

    test('any other failure of the plugin is a failure', () async {
      for (final code in ['KEY_GENERATION_FAILED', 'KEY_STORE_FAILED', 'X']) {
        keys.generateFailsWith = code;

        expect(await auth.enroll(), isA<BiometricEnrollFailed>(), reason: code);
      }
    });

    test('a missing plugin means the device can not', () async {
      keys.pluginMissing = true;

      expect(await auth.enroll(), isA<BiometricEnrollUnavailable>());
    });

    test('a public key that is not P-256 in X.509 is not accepted', () async {
      keys.publicKeyOverride = Uint8List.fromList(List.filled(65, 4));

      expect(await auth.enroll(), isA<BiometricEnrollFailed>());
      expect(keys.hasKey(auth.alias), isFalse, reason: 'the key is not kept');
    });
  });

  group('authenticate', () {
    late Uint8List publicKey;

    setUp(() async {
      publicKey = await enrolled();
    });

    Future<BiometricAttempt> authenticate() {
      return auth.authenticate(publicKey: publicKey, texts: texts);
    }

    test('a signature of the chip over the challenge is a yes', () async {
      expect(await authenticate(), isA<BiometricVerified>());
    });

    test('the chip signs a challenge that the app made', () async {
      await authenticate();

      final request = keys.signRequests.single;
      expect(request.alias, auth.alias);
      expect(request.challenge, hasLength(BiometricAuth.challengeLength));
      expect(request.challenge.any((b) => b != 0), isTrue);
    });

    test('every try has a new challenge', () async {
      await authenticate();
      await authenticate();
      await authenticate();

      final challenges = keys.signRequests.map((r) => r.challenge.join(','));
      expect(challenges.toSet(), hasLength(3));
    });

    test('the prompt gets the texts of the app', () async {
      await authenticate();

      final request = keys.signRequests.single;
      expect(request.title, 'Confirm');
      expect(request.subtitle, 'Locked');
      expect(request.cancelText, 'Cancel');
    });

    test('a signature of another key is not a yes', () async {
      keys.signWithAnotherKey = true;

      expect(await authenticate(), isA<BiometricSignatureInvalid>());
    });

    test('a signature over another challenge is not a yes', () async {
      final other = keys.keyOf(auth.alias)!.sign(Uint8List(32));
      keys.signReturns = other;

      expect(await authenticate(), isA<BiometricSignatureInvalid>());
    });

    test('bytes that are no signature are not a yes', () async {
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList(List.filled(70, 1)),
        Uint8List.fromList([0x30, 0x00]),
      ]) {
        keys.signReturns = bytes;

        expect(await authenticate(), isA<BiometricSignatureInvalid>());
      }
    });

    test('the answer of a system that only says yes is not enough', () async {
      // What local_auth would give: a yes with nothing the app can check.
      keys.signReturns = Uint8List.fromList([1]);

      expect(await authenticate(), isNot(isA<BiometricVerified>()));
    });

    test(
      'the signature is checked with the stored key, not the live one',
      () async {
        // The chip signs with its key; the app has another public key stored.
        final stranger = FakeKeyPair.generate();

        final result = await auth.authenticate(
          publicKey: stranger.publicKey,
          texts: texts,
        );

        expect(result, isA<BiometricSignatureInvalid>());
      },
    );

    test('USER_CANCELED is a cancel', () async {
      keys.signFailsWith = 'USER_CANCELED';

      expect(await authenticate(), isA<BiometricCanceled>());
    });

    test('KEY_INVALIDATED needs the biometrics set up again', () async {
      keys.signFailsWith = 'KEY_INVALIDATED';

      expect(await authenticate(), isA<BiometricKeyInvalidated>());
    });

    test('a key that is gone needs the biometrics set up again', () async {
      keys.signFailsWith = 'KEY_NOT_FOUND';

      expect(await authenticate(), isA<BiometricKeyInvalidated>());
    });

    test('a missing key is KEY_NOT_FOUND from the plugin itself', () async {
      await auth.remove();

      expect(await authenticate(), isA<BiometricKeyInvalidated>());
    });

    test('BIOMETRY_UNAVAILABLE and UNAVAILABLE are unavailable', () async {
      for (final code in ['BIOMETRY_UNAVAILABLE', 'UNAVAILABLE']) {
        keys.signFailsWith = code;

        expect(await authenticate(), isA<BiometricUnavailable>(), reason: code);
      }
    });

    test('the other codes of the plugin are failures', () async {
      for (final code in [
        'SIGNING_FAILED',
        'NO_ACTIVITY',
        'ACTIVITY_NOT_SUPPORTED',
        'SIGNING_IN_PROGRESS',
        'INVALID_ARGUMENT',
        'SOMETHING_NEW',
      ]) {
        keys.signFailsWith = code;

        expect(await authenticate(), isA<BiometricFailed>(), reason: code);
      }
    });

    test('a missing plugin is unavailable', () async {
      keys.pluginMissing = true;

      expect(await authenticate(), isA<BiometricUnavailable>());
    });

    test(
      'a stored key that is not a P-256 key needs setting up again',
      () async {
        final result = await auth.authenticate(
          publicKey: Uint8List.fromList(List.filled(10, 1)),
          texts: texts,
        );

        expect(result, isA<BiometricKeyInvalidated>());
      },
    );

    test(
      'the signature of the chip checks out for anyone who has the key',
      () async {
        await authenticate();

        final request = keys.signRequests.single;
        final signature = keys.keyOf(auth.alias)!.sign(request.challenge);

        expect(
          verifyP256Signature(
            publicKey: publicKey,
            message: request.challenge,
            signature: signature,
          ),
          isTrue,
        );
      },
    );
  });

  group('remove', () {
    test('deletes the key', () async {
      await enrolled();

      await auth.remove();

      expect(keys.hasKey(auth.alias), isFalse);
    });

    test('does not fail when there is no key or no plugin', () async {
      await expectLater(auth.remove(), completes);

      keys.pluginMissing = true;
      await expectLater(auth.remove(), completes);
    });
  });
}
