
import 'device_security_platform_interface.dart';

class DeviceSecurity {
  Future<String?> getPlatformVersion() {
    return DeviceSecurityPlatform.instance.getPlatformVersion();
  }
}
