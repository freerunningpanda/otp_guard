import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/features/lock/data/lock_json.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/domain/pin_attempts.dart';
import 'package:otp_guard/features/lock/domain/pin_credential.dart';

final credential = PinCredential(
  algorithm: PinHashAlgorithm.pbkdf2HmacSha256,
  iterations: 300000,
  salt: Uint8List.fromList(List.generate(16, (i) => i)),
  hash: Uint8List.fromList(List.generate(32, (i) => 255 - i)),
);

Map<String, Object?> pinJson() =>
    jsonDecode(encodePinCredential(credential)) as Map<String, Object?>;

Matcher get formatError => throwsFormatException;

void main() {
  group('the PIN record', () {
    test('comes back as it went', () {
      expect(decodePinCredential(encodePinCredential(credential)), credential);
    });

    test('keeps the parameters beside the hash, and the version', () {
      final json = pinJson();

      expect(json['v'], 1);
      expect(json['alg'], 'pbkdf2-hmac-sha256');
      expect(json['iter'], 300000);
      expect(json['salt'], base64Encode(credential.salt));
      expect(json['hash'], base64Encode(credential.hash));
    });

    test('has no field for a PIN', () {
      expect(
        pinJson().keys,
        unorderedEquals(['v', 'alg', 'iter', 'salt', 'hash']),
      );
    });

    final damaged = <String, String Function()>{
      'not JSON': () => 'nonsense',
      'not an object': () => '[1, 2]',
      'another version': () => jsonEncode({...pinJson(), 'v': 2}),
      'no version': () => jsonEncode({...pinJson()}..remove('v')),
      'an unknown algorithm': () => jsonEncode({...pinJson(), 'alg': 'md5'}),
      'no algorithm': () => jsonEncode({...pinJson()}..remove('alg')),
      'zero rounds': () => jsonEncode({...pinJson(), 'iter': 0}),
      'negative rounds': () => jsonEncode({...pinJson(), 'iter': -5}),
      'absurd rounds': () => jsonEncode({...pinJson(), 'iter': 1 << 40}),
      'rounds as text': () => jsonEncode({...pinJson(), 'iter': '300000'}),
      'no salt': () => jsonEncode({...pinJson()}..remove('salt')),
      'an empty salt': () => jsonEncode({...pinJson(), 'salt': ''}),
      'a salt that is not Base64': () =>
          jsonEncode({...pinJson(), 'salt': '!!!'}),
      'no hash': () => jsonEncode({...pinJson()}..remove('hash')),
      'a hash that is not text': () => jsonEncode({...pinJson(), 'hash': 5}),
    };

    for (final MapEntry(key: name, value: record) in damaged.entries) {
      test('refuses a record with $name', () {
        expect(() => decodePinCredential(record()), formatError);
      });
    }

    test('an error message says nothing of the hash', () {
      final record = jsonEncode({...pinJson(), 'iter': 0});

      expect(
        () => decodePinCredential(record),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              isNot(contains(base64Encode(credential.hash))),
              isNot(contains(base64Encode(credential.salt))),
            ),
          ),
        ),
      );
    });
  });

  group('the attempts record', () {
    test('comes back as it went', () {
      final attempts = PinAttempts(
        attempts: 6,
        lastAttemptAt: DateTime.utc(2026, 10, 12, 8, 30, 15, 250),
        lockedUntil: DateTime.utc(2026, 10, 12, 8, 31, 15, 250),
      );

      expect(decodeAttempts(encodeAttempts(attempts)), attempts);
    });

    test('keeps a record without a wait', () {
      final attempts = PinAttempts(
        attempts: 2,
        lastAttemptAt: DateTime.utc(2026),
      );

      expect(decodeAttempts(encodeAttempts(attempts)), attempts);
    });

    test('the time is read as UTC', () {
      final attempts = decodeAttempts(
        encodeAttempts(
          PinAttempts(attempts: 5, lockedUntil: DateTime.utc(2026)),
        ),
      );

      expect(attempts.lockedUntil!.isUtc, isTrue);
    });

    for (final record in [
      'nonsense',
      '{"v":1}',
      '{"v":1,"attempts":-1}',
      '{"v":1,"attempts":"3"}',
      '{"v":1,"attempts":3,"until":"soon"}',
      '{"v":2,"attempts":3}',
    ]) {
      test('refuses $record', () {
        expect(() => decodeAttempts(record), formatError);
      });
    }
  });

  group('the biometric record', () {
    final publicKey = Uint8List.fromList(List.generate(91, (i) => i));

    test('an enabled setting comes back with its key', () {
      final setting = BiometricSetting.enabled(publicKey);

      expect(decodeBiometricSetting(encodeBiometricSetting(setting)), setting);
    });

    test('a setting that needs renewal comes back without a key', () {
      final decoded = decodeBiometricSetting(
        encodeBiometricSetting(BiometricSetting.needsRenewal),
      );

      expect(decoded, BiometricSetting.needsRenewal);
      expect(decoded.publicKey, isNull);
    });

    for (final record in [
      'nonsense',
      '{"v":1}',
      '{"v":1,"status":"off"}',
      '{"v":1,"status":"on"}',
      '{"v":1,"status":"on","publicKey":""}',
      '{"v":1,"status":"on","publicKey":"%%%"}',
      '{"v":3,"status":"needsRenewal"}',
    ]) {
      test('refuses $record', () {
        expect(() => decodeBiometricSetting(record), formatError);
      });
    }
  });
}
