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

  /// Signs [challenge] with the private key under [alias] after the user
  /// confirms with biometrics, and returns the signature.
  ///
  /// The signature is ECDSA over the SHA-256 of [challenge], in DER, the same
  /// on both platforms.
  ///
  /// The texts of the biometric prompt belong to the app, not to the plugin,
  /// so the app can translate them and word them for its scenario: [title] is
  /// the headline, [subtitle] an optional explanation (on iOS it is the reason
  /// the system shows, [title] is used if it is null), and [cancelText] the
  /// label of the cancel button. [title] and [cancelText] must not be empty.
  ///
  /// It is @async because the answer comes after the user answers the
  /// biometric prompt, which can take any time. It stays off @TaskQueue on
  /// purpose: the queue of the other key calls is serial, and a prompt that
  /// waits for a person would block them all. On iOS the implementation moves
  /// the blocking system call to its own background queue.
  @async
  Uint8List sign(
    String alias,
    Uint8List challenge,
    String title,
    String? subtitle,
    String cancelText,
  );
}
