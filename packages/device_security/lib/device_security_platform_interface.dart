import 'dart:typed_data';

import 'package:device_security/device_security_method_channel.dart';
import 'package:device_security/security_event.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that implementations of device_security must implement.
abstract class DeviceSecurityPlatform extends PlatformInterface {
  /// Constructs a DeviceSecurityPlatform.
  DeviceSecurityPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceSecurityPlatform _instance = MethodChannelDeviceSecurity();

  /// The default instance of [DeviceSecurityPlatform] to use.
  ///
  /// Defaults to [MethodChannelDeviceSecurity].
  static DeviceSecurityPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DeviceSecurityPlatform] when
  /// they register themselves.
  static set instance(DeviceSecurityPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Sets the screen protection flag on the device.
  Future<void> setScreenProtection({required bool enabled});

  /// The security events the platform reports, such as a screenshot.
  ///
  /// A broadcast stream: the platform starts watching for events when the
  /// first listener subscribes and stops when the last one cancels.
  ///
  /// The stream never announces "no recording": a recording that is not running
  /// at subscription time sends nothing. Until a [ScreenRecordingChanged] with
  /// `isRecording` true arrives, treat the screen as not recorded.
  Stream<SecurityEvent> get securityEvents;

  /// Whether the device is protected by a screen lock.
  Future<bool> isDeviceSecure();

  /// Creates a key pair under [alias] in the secure hardware and returns the
  /// public key as X.509 SubjectPublicKeyInfo in DER, on both platforms.
  ///
  /// The private key never leaves the hardware. Throws a `PlatformException`
  /// with the code `KEY_EXISTS` if the alias is taken, `UNAVAILABLE` if the
  /// device has no secure hardware for the key (no key is kept then), or
  /// `KEY_GENERATION_FAILED`.
  Future<Uint8List> generateKey(String alias);

  /// Whether a key pair exists under [alias].
  Future<bool> hasKey(String alias);

  /// Deletes the key pair under [alias]. Does nothing if there is none.
  Future<void> deleteKey(String alias);

  /// Signs [challenge] with the private key under [alias] after the user
  /// confirms with a fingerprint or a face, and returns the signature.
  ///
  /// The signature is ECDSA over the SHA-256 of [challenge], in DER, the same
  /// on both platforms. The hardware lets the key be used only after the
  /// biometric check, so the check cannot be bypassed from the app.
  ///
  /// Throws a `PlatformException` with the code `KEY_NOT_FOUND` if there is
  /// no such key, `USER_CANCELED` if the user closes the prompt,
  /// `BIOMETRY_UNAVAILABLE` if biometrics are not set up or not usable,
  /// `KEY_INVALIDATED` if the fingerprints or faces changed, so the key no
  /// longer works, or `SIGNING_FAILED`.
  ///
  /// The texts of the biometric prompt are given by the caller: the plugin has
  /// none of its own. [title] and [cancelText] must not be empty, otherwise the
  /// call fails with `INVALID_ARGUMENT`. [subtitle] is optional.
  Future<Uint8List> sign(
    String alias,
    Uint8List challenge, {
    required String title,
    required String cancelText,
    String? subtitle,
  });
}
