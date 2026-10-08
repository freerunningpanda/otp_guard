import 'package:device_security/device_security_platform_interface.dart';
import 'package:device_security/security_event.dart';
import 'package:device_security/src/device_key_api.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [DeviceSecurityPlatform] that uses method channels.
class MethodChannelDeviceSecurity extends DeviceSecurityPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'com.freerunningpanda.device_security/methods',
  );

  /// The event channel used to receive security events from the native
  /// platform.
  @visibleForTesting
  final eventChannel = const EventChannel(
    'com.freerunningpanda.device_security/events',
  );

  // The generated client of the key API. Calls go through Pigeon channels, not
  // through methodChannel.
  final _keyApi = DeviceKeyApi();

  // Built once: every call to receiveBroadcastStream() would create a new
  // stream, and the native side would then see one more listener each time.
  @override
  late final Stream<SecurityEvent> securityEvents = eventChannel
      .receiveBroadcastStream()
      .map(_parseEvent)
      .where((event) => event != null)
      .cast<SecurityEvent>();

  @override
  Future<void> setScreenProtection({required bool enabled}) async {
    await methodChannel.invokeMethod<void>(
      'setScreenProtection',
      <String, dynamic>{'enabled': enabled},
    );
  }

  @override
  Future<bool> isDeviceSecure() => _keyApi.isDeviceSecure();

  @override
  Future<Uint8List> generateKey(String alias) => _keyApi.generateKey(alias);

  @override
  Future<bool> hasKey(String alias) => _keyApi.hasKey(alias);

  @override
  Future<void> deleteKey(String alias) => _keyApi.deleteKey(alias);

  // Returns null for an event type this version does not know, which the
  // stream above drops.
  SecurityEvent? _parseEvent(Object? event) {
    if (event is! Map<Object?, Object?>) {
      throw FormatException('Event must be a map', event);
    }
    return SecurityEvent.fromMap(event);
  }
}
