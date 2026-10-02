import 'package:device_security/device_security_platform_interface.dart';

class DeviceSecurity {
  Future<void> setScreenProtection({required bool enabled}) {
    return DeviceSecurityPlatform.instance.setScreenProtection(
      enabled: enabled,
    );
  }
}
