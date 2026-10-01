import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_security_method_channel.dart';

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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
