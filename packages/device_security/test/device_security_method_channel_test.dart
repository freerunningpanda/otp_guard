import 'package:device_security/device_security_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelDeviceSecurity();
  final channel = platform.methodChannel;
  MethodCall? receivedCall;

  setUp(() {
    receivedCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          receivedCall = methodCall;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setScreenProtection', () async {
    await platform.setScreenProtection(enabled: true);

    expect(receivedCall?.method, 'setScreenProtection');
    expect(receivedCall?.arguments, <String, dynamic>{'enabled': true});
  });
}
