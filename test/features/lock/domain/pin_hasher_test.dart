import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';
import 'package:otp_guard/features/lock/domain/pin_hasher.dart';

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List ascii(String text) => Uint8List.fromList(utf8.encode(text));

// Runs the work at once, in this isolate: a test needs neither the time of a
// new isolate nor the real number of rounds.
Future<R> inPlace<R>(R Function() task) async => task();

PinHasher fastHasher({int iterations = 4, Random? random}) =>
    PinHasher(iterations: iterations, random: random, compute: inPlace);

void main() {
  group('pbkdf2HmacSha256', () {
    // The values of PBKDF2-HMAC-SHA256 for the password "password" and the
    // salt "salt", from the published test vectors (RFC 7914 and others).
    final vectors = {
      1: '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      2: 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      4096: 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
    };

    for (final MapEntry(key: iterations, value: expected) in vectors.entries) {
      test('$iterations iterations match the reference', () {
        final key = pbkdf2HmacSha256(
          password: ascii('password'),
          salt: ascii('salt'),
          iterations: iterations,
          length: 32,
        );

        expect(hex(key), expected);
      });
    }
  });

  group('PinHasher', () {
    test('the right PIN is accepted', () async {
      final hasher = fastHasher();
      final credential = await hasher.create('123456');

      expect(await hasher.verify('123456', credential), isTrue);
    });

    test('a wrong PIN is refused', () async {
      final hasher = fastHasher();
      final credential = await hasher.create('123456');

      expect(await hasher.verify('123457', credential), isFalse);
      expect(await hasher.verify('12345', credential), isFalse);
      expect(await hasher.verify('1234560', credential), isFalse);
      expect(await hasher.verify('', credential), isFalse);
    });

    test('the same PIN gets a different salt and a different hash', () async {
      final hasher = fastHasher(random: Random(7));

      final first = await hasher.create('123456');
      final second = await hasher.create('123456');

      expect(first.salt, isNot(second.salt));
      expect(first.hash, isNot(second.hash));
      expect(await hasher.verify('123456', first), isTrue);
      expect(await hasher.verify('123456', second), isTrue);
    });

    test('a hash is not good for another salt', () async {
      final hasher = fastHasher(random: Random(7));
      final first = await hasher.create('123456');
      final second = await hasher.create('123456');
      final mixed = PinCredential(
        algorithm: first.algorithm,
        iterations: first.iterations,
        salt: second.salt,
        hash: first.hash,
      );

      expect(await hasher.verify('123456', mixed), isFalse);
    });

    test('the credential keeps its parameters next to the hash', () async {
      final credential = await fastHasher(iterations: 25).create('123456');

      expect(credential.algorithm, PinHashAlgorithm.pbkdf2HmacSha256);
      expect(credential.iterations, 25);
      expect(credential.salt, hasLength(PinHasher.saltLength));
      expect(credential.hash, hasLength(PinHasher.hashLength));
    });

    test('the credential does not show the hash in logs', () async {
      final credential = await fastHasher().create('123456');

      expect(credential.toString(), isNot(contains(hex(credential.hash))));
      expect(credential.toString(), isNot(contains('123456')));
    });

    test('a PIN is checked with the parameters it was made with', () async {
      final old = await fastHasher(iterations: 3).create('123456');

      // A hasher that is set to more rounds still reads the old credential.
      expect(await fastHasher(iterations: 50).verify('123456', old), isTrue);
      expect(await fastHasher(iterations: 50).verify('654321', old), isFalse);
    });

    test('more rounds give another hash', () async {
      final random = Random(1);
      final weak = await fastHasher(iterations: 3, random: random).create('1');
      final salted = PinCredential(
        algorithm: weak.algorithm,
        iterations: 30,
        salt: weak.salt,
        hash: weak.hash,
      );

      expect(await fastHasher().verify('1', salted), isFalse);
    });

    test('a weaker credential is to be made again', () async {
      final hasher = fastHasher(iterations: 20);
      final weak = await fastHasher(iterations: 10).create('123456');
      final same = await fastHasher(iterations: 20).create('123456');
      final stronger = await fastHasher(iterations: 40).create('123456');

      expect(hasher.needsUpgrade(weak), isTrue);
      expect(hasher.needsUpgrade(same), isFalse);
      expect(hasher.needsUpgrade(stronger), isFalse);
    });

    test('the work goes through the compute function', () async {
      var runs = 0;
      Future<R> counting<R>(R Function() task) async {
        runs++;
        return task();
      }

      final hasher = PinHasher(iterations: 3, compute: counting);
      final credential = await hasher.create('123456');
      await hasher.verify('123456', credential);

      expect(runs, 2);
    });

    test('the default compute runs in a real isolate', () async {
      // The task is sent to another isolate. It must not take along anything
      // that can not be sent, such as the hasher with its Random; this fails
      // at once if it does.
      final hasher = PinHasher(iterations: 5);

      final credential = await hasher.create('123456');

      expect(await hasher.verify('123456', credential), isTrue);
      expect(await hasher.verify('000000', credential), isFalse);
    });

    test('a new credential is as strong as the setting says', () async {
      expect(PinHasher().iterations, PinHasher.defaultIterations);
      expect(PinHasher.defaultIterations, greaterThanOrEqualTo(100000));
    });
  });
}
