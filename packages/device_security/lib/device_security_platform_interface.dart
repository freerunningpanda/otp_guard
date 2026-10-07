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
  Stream<SecurityEvent> get securityEvents;
}
