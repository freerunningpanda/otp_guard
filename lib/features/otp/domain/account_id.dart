import 'dart:math';

/// A new random identifier for an account: 128 random bits as 32 hex digits.
///
/// The identifier names the account in the storage, so it must not come from
/// the secret or from anything else about the account. [random] is a parameter
/// so that a test can make the identifiers predictable; the default is a
/// cryptographically secure generator.
String generateAccountId([Random? random]) {
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(source.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
