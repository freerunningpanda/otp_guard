import 'dart:typed_data';

import 'package:device_security/device_security_platform_interface.dart';
import 'package:device_security/security_event.dart';

export 'package:device_security/security_event.dart';

/// The entry point of the plugin: screen protection, security events and the
/// device key.
class DeviceSecurity {
  /// Turns screen protection on or off.
  ///
  /// On Android this sets `FLAG_SECURE` on the activity window. On iOS it
  /// blurs the windows while the app is inactive or the screen is captured, so
  /// the task switcher and a recording show no content.
  Future<void> setScreenProtection({required bool enabled}) =>
      DeviceSecurityPlatform.instance.setScreenProtection(
        enabled: enabled,
      );

  /// The security events the platform reports, such as a screenshot.
  ///
  /// A broadcast stream: the platform starts watching for events when the
  /// first listener subscribes and stops when the last one cancels.
  ///
  /// The stream never announces "no recording": a recording that is not running
  /// at subscription time sends nothing. Until a [ScreenRecordingChanged] with
  /// `isRecording` true arrives, treat the screen as not recorded.
  Stream<SecurityEvent> get securityEvents =>
      DeviceSecurityPlatform.instance.securityEvents;

  /// Whether the device is protected by a screen lock.
  Future<bool> isDeviceSecure() =>
      DeviceSecurityPlatform.instance.isDeviceSecure();

  /// Creates a key pair under [alias] in the secure hardware (Android
  /// Keystore, iOS Secure Enclave) and returns the public key as X.509
  /// SubjectPublicKeyInfo in DER, the same format on both platforms.
  ///
  /// The private key never leaves the hardware. Throws a `PlatformException`
  /// with the code `KEY_EXISTS` if the alias is taken, `UNAVAILABLE` if the
  /// device has no secure hardware for the key (the iOS simulator, most
  /// Android emulators; no key is kept then), or `KEY_GENERATION_FAILED`.
  Future<Uint8List> generateKey(String alias) =>
      DeviceSecurityPlatform.instance.generateKey(alias);

  /// Whether a key pair exists under [alias].
  Future<bool> hasKey(String alias) =>
      DeviceSecurityPlatform.instance.hasKey(alias);

  /// Deletes the key pair under [alias]. Does nothing if there is none.
  Future<void> deleteKey(String alias) =>
      DeviceSecurityPlatform.instance.deleteKey(alias);
}
