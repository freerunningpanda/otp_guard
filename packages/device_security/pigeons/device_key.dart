import 'package:pigeon/pigeon.dart';

// The description of the key API. The Dart, Kotlin and Swift code under the
// paths below is generated from it with
// `dart run pigeon --input pigeons/device_key.dart`. Do not edit it by hand.
//
// The paths are single string literals on purpose: Pigeon does not read
// adjacent literals ('a' 'b') in the options.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/device_key_api.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/freerunningpanda/device_security/DeviceKeyApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.freerunningpanda.device_security',
    ),
    swiftOut:
        'ios/device_security/Sources/device_security/DeviceKeyApi.g.swift',
  ),
)
@HostApi()
abstract class DeviceKeyApi {
  // Pigeon runs the host methods on the main thread of the platform by
  // default. The key operations talk to the Keystore or the Secure Enclave and
  // can take from tens to hundreds of milliseconds, which would freeze the
  // interface. @TaskQueue moves them to a background thread. The
  // implementations keep no state, so this is safe. isDeviceSecure is quick
  // and stays on the main thread.

  /// Whether the device is protected by a screen lock.
  bool isDeviceSecure();

  /// Creates a key pair under [alias] and returns the public key.
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  Uint8List generateKey(String alias);

  /// Whether a key pair exists under [alias].
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  bool hasKey(String alias);

  /// Deletes the key pair under [alias], if there is one.
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void deleteKey(String alias);
}
