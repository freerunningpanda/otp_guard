import 'package:device_security/device_security.dart';

/// What the app needs from the native screen protection: to turn it on and off,
/// and to hear about screenshots and screen recording.
///
/// A small interface of its own, so the widgets and the cubits do not call the
/// plugin, which has no implementation in a test.
abstract interface class ScreenSecurity {
  /// Turns the protection of the screen on or off.
  Future<void> setProtection({required bool enabled});

  /// A screenshot, or a screen recording that starts or stops.
  Stream<SecurityEvent> get events;
}

/// The [ScreenSecurity] of the device, on the `device_security` plugin.
class DeviceScreenSecurity implements ScreenSecurity {
  /// Creates it on the plugin entry point.
  DeviceScreenSecurity(this._device);

  final DeviceSecurity _device;

  @override
  Future<void> setProtection({required bool enabled}) {
    return _device.setScreenProtection(enabled: enabled);
  }

  @override
  Stream<SecurityEvent> get events => _device.securityEvents;
}
