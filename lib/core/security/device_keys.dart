import 'dart:typed_data';

import 'package:device_security/device_security.dart';

/// What the app needs from the key in the secure hardware: to make it, to
/// delete it and to sign with it.
///
/// A small interface of its own, so the lock does not call the plugin, which
/// has no implementation in a test. The failures are the `PlatformException`
/// of the plugin, with the codes in its documentation.
abstract interface class DeviceKeys {
  /// Makes a key pair under [alias] and returns the public key, X.509 DER.
  Future<Uint8List> generateKey(String alias);

  /// Deletes the key under [alias]. Does nothing if there is none.
  Future<void> deleteKey(String alias);

  /// Signs [challenge] with the key under [alias] after the user confirms with
  /// a fingerprint or a face. The signature is ECDSA over the SHA-256 of the
  /// challenge, in DER.
  Future<Uint8List> sign(
    String alias,
    Uint8List challenge, {
    required String title,
    required String cancelText,
    String? subtitle,
  });
}

/// The [DeviceKeys] of the device, on the `device_security` plugin.
class DeviceSecurityKeys implements DeviceKeys {
  /// Creates it on the plugin entry point.
  DeviceSecurityKeys(this._device);

  final DeviceSecurity _device;

  @override
  Future<Uint8List> generateKey(String alias) => _device.generateKey(alias);

  @override
  Future<void> deleteKey(String alias) => _device.deleteKey(alias);

  @override
  Future<Uint8List> sign(
    String alias,
    Uint8List challenge, {
    required String title,
    required String cancelText,
    String? subtitle,
  }) {
    return _device.sign(
      alias,
      challenge,
      title: title,
      subtitle: subtitle,
      cancelText: cancelText,
    );
  }
}
