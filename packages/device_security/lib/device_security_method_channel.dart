import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_security_platform_interface.dart';

/// An implementation of [DeviceSecurityPlatform] that uses method channels.
class MethodChannelDeviceSecurity extends DeviceSecurityPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('device_security');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
