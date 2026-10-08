import 'dart:typed_data';

import 'package:device_security/device_security.dart';
import 'package:device_security/device_security_method_channel.dart';
import 'package:device_security/device_security_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceSecurityPlatform
    with MockPlatformInterfaceMixin
    implements DeviceSecurityPlatform {
  bool? receivedEnabled;
  Stream<SecurityEvent> events = const Stream.empty();
  bool deviceSecure = false;
  final keys = <String, Uint8List>{};

  @override
  Future<void> setScreenProtection({required bool enabled}) async {
    receivedEnabled = enabled;
  }

  @override
  Stream<SecurityEvent> get securityEvents => events;

  @override
  Future<bool> isDeviceSecure() async => deviceSecure;

  @override
  Future<Uint8List> generateKey(String alias) async =>
      keys[alias] = Uint8List.fromList([1, 2, 3]);

  @override
  Future<bool> hasKey(String alias) async => keys.containsKey(alias);

  @override
  Future<void> deleteKey(String alias) async {
    keys.remove(alias);
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

  test('securityEvents forwards the platform stream', () async {
    final deviceSecurityPlugin = DeviceSecurity();
    final fakePlatform = MockDeviceSecurityPlatform();
    final event = ScreenshotTaken(timestamp: DateTime.utc(2026));
    fakePlatform.events = Stream.value(event);
    DeviceSecurityPlatform.instance = fakePlatform;

    expect(deviceSecurityPlugin.securityEvents, emits(event));
  });

  group('device key', () {
    late DeviceSecurity deviceSecurityPlugin;
    late MockDeviceSecurityPlatform fakePlatform;

    setUp(() {
      deviceSecurityPlugin = DeviceSecurity();
      fakePlatform = MockDeviceSecurityPlatform();
      DeviceSecurityPlatform.instance = fakePlatform;
    });

    test('isDeviceSecure forwards the platform answer', () async {
      fakePlatform.deviceSecure = true;

      expect(await deviceSecurityPlugin.isDeviceSecure(), isTrue);
    });

    test('generateKey, hasKey and deleteKey forward to the platform', () async {
      expect(await deviceSecurityPlugin.hasKey('login'), isFalse);

      final publicKey = await deviceSecurityPlugin.generateKey('login');

      expect(publicKey, Uint8List.fromList([1, 2, 3]));
      expect(await deviceSecurityPlugin.hasKey('login'), isTrue);

      await deviceSecurityPlugin.deleteKey('login');

      expect(await deviceSecurityPlugin.hasKey('login'), isFalse);
    });
  });
}
