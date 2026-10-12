import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:otp_guard/features/lock/domain/constant_time.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';
import 'package:pointycastle/export.dart';

/// Runs [task] somewhere it will not block the screen, and gives its result.
typedef Compute = Future<R> Function<R>(R Function() task);

Future<R> _inIsolate<R>(R Function() task) => Isolate.run(task);

/// PBKDF2 with HMAC-SHA-256 (RFC 8018): [length] bytes made from [password]
/// and [salt] in [iterations] rounds.
Uint8List pbkdf2HmacSha256({
  required List<int> password,
  required Uint8List salt,
  required int iterations,
  required int length,
}) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, length));
  return derivator.process(Uint8List.fromList(password));
}

/// Makes the stored form of a PIN and checks a typed PIN against it.
///
/// The PIN itself is never stored. The function is slow on purpose: a guesser
/// who got the stored hash has to pay its price for every guess. The price is
/// paid on the user's side too, a fraction of a second, so the work runs in an
/// isolate and the screen keeps moving.
class PinHasher {
  /// Creates the hasher.
  ///
  /// [iterations] is the strength of new credentials. [random] makes the salts
  /// and the compute function runs the work; a test passes its own of each.
  PinHasher({
    this.iterations = defaultIterations,
    Random? random,
    this._compute = _inIsolate,
  }) : _random = random ?? Random.secure();

  /// The number of rounds for new credentials. On a recent phone it takes
  /// about a second; a credential with fewer is made stronger the next time
  /// its PIN is typed right.
  static const defaultIterations = 300000;

  /// The length of a salt in bytes.
  static const saltLength = 16;

  /// The length of a hash in bytes.
  static const hashLength = 32;

  /// The algorithm of new credentials.
  static const PinHashAlgorithm algorithm = PinHashAlgorithm.pbkdf2HmacSha256;

  /// The number of rounds for new credentials.
  final int iterations;

  final Random _random;
  final Compute _compute;

  /// The credential for [pin], with a new random salt.
  Future<PinCredential> create(String pin) async {
    final salt = Uint8List.fromList(
      List.generate(saltLength, (_) => _random.nextInt(256)),
    );
    final hash = await _derive(pin, salt, iterations);
    return PinCredential(
      algorithm: algorithm,
      iterations: iterations,
      salt: salt,
      hash: hash,
    );
  }

  /// Whether [pin] is the PIN that [credential] was made from.
  ///
  /// It uses the parameters stored in the credential, not the current ones,
  /// and compares the hashes in constant time.
  Future<bool> verify(String pin, PinCredential credential) async {
    final hash = await _derive(pin, credential.salt, credential.iterations);
    return constantTimeEquals(hash, credential.hash);
  }

  /// Whether [credential] is weaker than what new credentials get, so it
  /// should be made again while the PIN is at hand.
  bool needsUpgrade(PinCredential credential) {
    return credential.algorithm != algorithm ||
        credential.iterations < iterations;
  }

  Future<Uint8List> _derive(String pin, Uint8List salt, int iterations) {
    return _compute(_task(pin, salt, iterations));
  }

  // Static, so the task can not take the hasher with it into the isolate: only
  // the PIN, the salt and the number, which can be sent.
  static Uint8List Function() _task(
    String pin,
    Uint8List salt,
    int iterations,
  ) {
    return () => pbkdf2HmacSha256(
      password: utf8.encode(pin),
      salt: salt,
      iterations: iterations,
      length: hashLength,
    );
  }
}
