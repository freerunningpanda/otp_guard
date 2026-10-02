import 'package:device_security/device_security_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [DeviceSecurityPlatform] that uses method channels.
class MethodChannelDeviceSecurity extends DeviceSecurityPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'com.freerunningpanda.device_security/methods',
  );

  @override
  Future<void> setScreenProtection({required bool enabled}) async {
    await methodChannel.invokeMethod<void>(
      'setScreenProtection',
      <String, dynamic>{'enabled': enabled},
    );
  }
}
