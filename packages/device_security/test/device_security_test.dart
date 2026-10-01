import 'package:flutter_test/flutter_test.dart';
import 'package:device_security/device_security.dart';
import 'package:device_security/device_security_platform_interface.dart';
import 'package:device_security/device_security_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceSecurityPlatform
    with MockPlatformInterfaceMixin
    implements DeviceSecurityPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DeviceSecurityPlatform initialPlatform = DeviceSecurityPlatform.instance;

  test('$MethodChannelDeviceSecurity is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDeviceSecurity>());
  });

  test('getPlatformVersion', () async {
    DeviceSecurity deviceSecurityPlugin = DeviceSecurity();
    MockDeviceSecurityPlatform fakePlatform = MockDeviceSecurityPlatform();
    DeviceSecurityPlatform.instance = fakePlatform;

    expect(await deviceSecurityPlugin.getPlatformVersion(), '42');
  });
}
