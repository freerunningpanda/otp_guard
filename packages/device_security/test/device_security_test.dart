import 'package:device_security/device_security.dart';
import 'package:device_security/device_security_method_channel.dart';
import 'package:device_security/device_security_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceSecurityPlatform
    with MockPlatformInterfaceMixin
    implements DeviceSecurityPlatform {
  bool? receivedEnabled;

  @override
  Future<void> setScreenProtection({required bool enabled}) async {
    receivedEnabled = enabled;
  }
}

void main() {
  final initialPlatform = DeviceSecurityPlatform.instance;

  test('$MethodChannelDeviceSecurity is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDeviceSecurity>());
  });

  test('setScreenProtection', () async {
    final deviceSecurityPlugin = DeviceSecurity();
    final fakePlatform = MockDeviceSecurityPlatform();
    DeviceSecurityPlatform.instance = fakePlatform;

    await deviceSecurityPlugin.setScreenProtection(enabled: true);

    expect(fakePlatform.receivedEnabled, true);
  });

  test('setScreenProtection', () async {
    final deviceSecurityPlugin = DeviceSecurity();
    final fakePlatform = MockDeviceSecurityPlatform();
    DeviceSecurityPlatform.instance = fakePlatform;

    await deviceSecurityPlugin.setScreenProtection(enabled: false);

    expect(fakePlatform.receivedEnabled, false);
  });
}
