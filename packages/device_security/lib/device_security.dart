import 'package:device_security/device_security_platform_interface.dart';
import 'package:device_security/security_event.dart';

export 'package:device_security/security_event.dart';

/// The entry point of the plugin: screen protection and security events.
class DeviceSecurity {
  /// Turns screen protection on or off.
  ///
  /// On Android this sets `FLAG_SECURE` on the activity window. On iOS it
  /// blurs the window while the app is inactive, so the task switcher shows no
  /// content.
  Future<void> setScreenProtection({required bool enabled}) =>
      DeviceSecurityPlatform.instance.setScreenProtection(
        enabled: enabled,
      );

  /// The security events the platform reports, such as a screenshot.
  ///
  /// A broadcast stream: the platform starts watching for events when the
  /// first listener subscribes and stops when the last one cancels.
  Stream<SecurityEvent> get securityEvents =>
      DeviceSecurityPlatform.instance.securityEvents;
}
