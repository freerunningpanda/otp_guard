import 'dart:async';
import 'dart:math';

import 'package:device_security/device_security.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otp_guard/ecdsa_verifier.dart';

/// A page for checking the device key on a real device: it creates a key,
/// signs random bytes and verifies the signature in Dart. Reached from the
/// menu of the accounts page, in debug builds only.
class KeyDemoPage extends StatefulWidget {
  /// Creates the page.
  const KeyDemoPage({super.key});

  @override
  State<KeyDemoPage> createState() => _KeyDemoPageState();
}

class _KeyDemoPageState extends State<KeyDemoPage> {
  // A demo of the device key API: runs a scenario at start and shows what
  // each call returned. The "Run key checks" button runs it again.
  String _keyLog = 'running...';

  // True while one of the checks runs. Both checks use keys under fixed aliases
  // and delete them first, so a second run started on top of the first would
  // delete the key under it and mix the two logs. The buttons are disabled
  // meanwhile.
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check(_runKeyChecks));
  }

  // Runs one check at a time and always releases the lock, even if the check
  // throws.
  Future<void> _check(Future<void> Function() check) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      await check();
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _runKeyChecks() async {
    final security = DeviceSecurity();
    const alias = 'temp_check_key';
    final log = StringBuffer();

    Future<void> step(String name, Future<Object?> Function() body) async {
      String line;
      try {
        line = 'OK   $name -> ${await body()}';
      } on PlatformException catch (e) {
        line = 'ERR  $name -> ${e.code}: ${e.message}';
      }
      log.writeln(line);
      debugPrint('KEYCHECK $line');
    }

    await step('isDeviceSecure', security.isDeviceSecure);
    await step('deleteKey (clean start)', () => security.deleteKey(alias));
    await step('hasKey, expect false', () => security.hasKey(alias));
    await step('generateKey #1, UNAVAILABLE on an emulator', () async {
      final key = await security.generateKey(alias);
      final head = key
          .take(4)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return '${key.length} bytes, starts $head';
    });
    await step(
      'hasKey, true only if the key was made',
      () => security.hasKey(alias),
    );
    await step(
      'generateKey #2, KEY_EXISTS on a device',
      () => security.generateKey(alias),
    );
    await step('deleteKey', () => security.deleteKey(alias));
    await step('hasKey, expect false', () => security.hasKey(alias));
    await step('deleteKey again, expect OK', () => security.deleteKey(alias));

    if (mounted) setState(() => _keyLog = log.toString());
  }

  // A demo of signing: creates a key, signs random bytes (the biometric prompt
  // appears), checks the signature in Dart with the public key that generateKey
  // returned, and deletes the key. A valid signature shows that the key format,
  // the signature format and the algorithm all match, as a server needs them.
  // It needs a device with secure hardware and enrolled biometrics.
  String _signLog = 'press "Sign and verify"';

  Future<void> _runSignCheck() async {
    final security = DeviceSecurity();
    const alias = 'temp_sign_key';
    final log = StringBuffer();

    void line(String text) {
      log.writeln(text);
      debugPrint('SIGNCHECK $text');
    }

    Future<T?> step<T>(
      String name,
      Future<T> Function() body, {
      String Function(T value)? show,
    }) async {
      try {
        final value = await body();
        line('OK   $name${show == null ? '' : ' -> ${show(value)}'}');
        return value;
      } on PlatformException catch (e) {
        line('ERR  $name -> ${e.code}: ${e.message}');
        return null;
      }
    }

    setState(() => _signLog = 'running...');
    // A key made before keys required biometrics would not ask for them.
    await step('deleteKey (clean start)', () => security.deleteKey(alias));
    final publicKey = await step(
      'generateKey',
      () => security.generateKey(alias),
      show: (key) => '${key.length} bytes',
    );
    if (publicKey != null) {
      final random = Random.secure();
      final challenge = Uint8List.fromList(
        List.generate(32, (_) => random.nextInt(256)),
      );
      final signature = await step(
        'sign (confirm with biometrics)',
        () => security.sign(
          alias,
          challenge,
          title: 'Confirm sign-in',
          subtitle: 'Sign the challenge from the server',
          cancelText: 'Cancel',
        ),
        show: (value) => '${value.length} bytes',
      );
      if (signature != null) {
        try {
          final valid = verifyP256Signature(
            publicKey: publicKey,
            message: challenge,
            signature: signature,
          );
          line('${valid ? 'OK  ' : 'ERR '} the signature verifies: $valid');
        } on FormatException catch (e) {
          line('ERR  the signature check -> ${e.message}');
        }
      }
      await step('deleteKey', () => security.deleteKey(alias));
    }

    if (mounted) setState(() => _signLog = log.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Device key demo'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: .center,
            children: [
              // Runs the key scenario again and shows its result.
              ElevatedButton(
                onPressed: _isChecking
                    ? null
                    : () => unawaited(_check(_runKeyChecks)),
                child: const Text('Run key checks'),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _keyLog,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
              // Signs with the key and checks the signature in Dart.
              ElevatedButton(
                onPressed: _isChecking
                    ? null
                    : () => unawaited(_check(_runSignCheck)),
                child: const Text('Sign and verify'),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _signLog,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
