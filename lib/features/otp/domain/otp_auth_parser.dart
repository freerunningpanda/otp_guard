import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:otp_guard/features/otp/domain/account_id.dart';
import 'package:otp_guard/features/otp/domain/base32.dart';
import 'package:otp_guard/features/otp/domain/otp_account.dart';
import 'package:otp_guard/features/otp/domain/otp_algorithm.dart';

/// The result of reading an `otpauth://` link: an account, or the reason why
/// the link is not usable.
///
/// A sealed class, so the interface can `switch` over it and the compiler
/// checks that every reason has a message.
@immutable
sealed class OtpAuthParseResult {
  const OtpAuthParseResult();
}

/// The link was read, here is the account.
final class OtpAuthParsed extends OtpAuthParseResult {
  /// Creates the result.
  const OtpAuthParsed(this.account);

  /// The account made from the link.
  final OtpAccount account;

  @override
  bool operator ==(Object other) =>
      other is OtpAuthParsed && other.account == account;

  @override
  int get hashCode => account.hashCode;

  @override
  String toString() => 'OtpAuthParsed($account)';
}

/// The link can not be used. No failure holds the secret, so they are safe to
/// show and to log.
sealed class OtpAuthFailure extends OtpAuthParseResult {
  const OtpAuthFailure();
}

/// The text is not an `otpauth://` link at all: another scheme, plain text,
/// or a link that can not be read.
final class NotAnOtpAuthUri extends OtpAuthFailure {
  /// Creates the failure.
  const NotAnOtpAuthUri();

  @override
  bool operator ==(Object other) => other is NotAnOtpAuthUri;

  @override
  int get hashCode => (NotAnOtpAuthUri).hashCode;

  @override
  String toString() => 'NotAnOtpAuthUri()';
}

/// The link is for a kind of code that is not supported, such as `hotp`.
final class UnsupportedOtpType extends OtpAuthFailure {
  /// Creates the failure for [type].
  const UnsupportedOtpType(this.type);

  /// The type in the link, such as `hotp`.
  final String type;

  @override
  bool operator ==(Object other) =>
      other is UnsupportedOtpType && other.type == type;

  @override
  int get hashCode => Object.hash(UnsupportedOtpType, type);

  @override
  String toString() => 'UnsupportedOtpType($type)';
}

/// The link has no account name: no label, or nothing after the issuer.
final class MissingLabel extends OtpAuthFailure {
  /// Creates the failure.
  const MissingLabel();

  @override
  bool operator ==(Object other) => other is MissingLabel;

  @override
  int get hashCode => (MissingLabel).hashCode;

  @override
  String toString() => 'MissingLabel()';
}

/// The link has no `secret` parameter, or it is empty.
final class MissingSecret extends OtpAuthFailure {
  /// Creates the failure.
  const MissingSecret();

  @override
  bool operator ==(Object other) => other is MissingSecret;

  @override
  int get hashCode => (MissingSecret).hashCode;

  @override
  String toString() => 'MissingSecret()';
}

/// The `secret` parameter is not valid Base32. It carries nothing from the
/// secret, not even a position.
final class InvalidSecret extends OtpAuthFailure {
  /// Creates the failure.
  const InvalidSecret();

  @override
  bool operator ==(Object other) => other is InvalidSecret;

  @override
  int get hashCode => (InvalidSecret).hashCode;

  @override
  String toString() => 'InvalidSecret()';
}

/// A parameter other than the secret has a value that is not allowed:
/// `algorithm`, `digits` or `period`.
final class InvalidParameter extends OtpAuthFailure {
  /// Creates the failure for the parameter [name] with the [value].
  const InvalidParameter(this.name, this.value);

  /// The name of the parameter, such as `digits`.
  final String name;

  /// The value that was given. These parameters are not secret.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is InvalidParameter && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(InvalidParameter, name, value);

  @override
  String toString() => 'InvalidParameter($name: $value)';
}

/// Reads an `otpauth://totp/...` link, such as the one in a QR code.
///
/// ```text
/// otpauth://totp/GitHub:alex@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub
/// ```
///
/// The label (`GitHub:alex@example.com`) is the issuer and the account name;
/// the issuer in the label is optional. If the `issuer` parameter is also
/// there, the parameter wins. `secret` is required and is Base32. `algorithm`
/// (`SHA1`, `SHA256`, `SHA512`), `digits` (6 to 8) and `period` (seconds) are
/// optional and default to `SHA1`, 6 and 30. Only `totp` is supported.
///
/// Percent-encoding in the label and the parameters (`%20`, `%3A`, `%40`) is
/// decoded.
///
/// Nothing is thrown for a bad link: the reason is returned as an
/// [OtpAuthFailure]. [newId] makes the identifier of the new account; the
/// default is a random one.
OtpAuthParseResult parseOtpAuthUri(String input, {String Function()? newId}) {
  try {
    return OtpAuthParsed(_parse(input, newId ?? generateAccountId));
  } on _Reject catch (reject) {
    return reject.failure;
  }
}

/// Builds an account from what a person typed instead of a link: the [issuer]
/// (optional), the account [name] and the [secret] in Base32.
///
/// It gives the same results as [parseOtpAuthUri] for the same mistakes, so the
/// two ways of adding an account are checked by one set of rules: an empty
/// [name] is [MissingLabel], an empty [secret] is [MissingSecret], and a
/// [secret] that is not Base32 is [InvalidSecret]. The algorithm, the digits
/// and the period are the defaults of the authenticators: SHA-1, 6 and 30.
OtpAuthParseResult buildOtpAccount({
  required String name,
  required String secret,
  String? issuer,
  String Function()? newId,
}) {
  try {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw const _Reject(MissingLabel());
    final trimmedIssuer = issuer?.trim();
    return OtpAuthParsed(
      OtpAccount(
        id: (newId ?? generateAccountId)(),
        issuer: (trimmedIssuer == null || trimmedIssuer.isEmpty)
            ? null
            : trimmedIssuer,
        name: trimmedName,
        secret: _readSecret(secret),
      ),
    );
  } on _Reject catch (reject) {
    return reject.failure;
  }
}

// Carries a failure out of the helpers below to parseOtpAuthUri, which turns it
// back into a result. It never leaves this file.
class _Reject implements Exception {
  const _Reject(this.failure);

  final OtpAuthFailure failure;
}

OtpAccount _parse(String input, String Function() newId) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || uri.scheme != 'otpauth' || uri.host.isEmpty) {
    throw const _Reject(NotAnOtpAuthUri());
  }

  // Decoding can throw on a broken percent sequence such as %zz.
  final String label;
  final Map<String, String> parameters;
  try {
    label = uri.pathSegments.join('/').trim();
    parameters = uri.queryParameters;
  } on FormatException {
    throw const _Reject(NotAnOtpAuthUri());
  }

  if (uri.host != 'totp') throw _Reject(UnsupportedOtpType(uri.host));

  final (issuerInLabel, name) = _splitLabel(label);
  if (name.isEmpty) throw const _Reject(MissingLabel());

  final secret = _readSecret(parameters['secret']);
  final algorithm = _readAlgorithm(parameters['algorithm']);
  final digits = _readNumber('digits', parameters['digits'], 6, 6, 8);
  final period = _readNumber('period', parameters['period'], 30, 1, null);

  // The parameter wins over the label when both name an issuer.
  final issuerParameter = parameters['issuer']?.trim();
  final issuer = (issuerParameter != null && issuerParameter.isNotEmpty)
      ? issuerParameter
      : issuerInLabel;

  return OtpAccount(
    id: newId(),
    issuer: issuer,
    name: name,
    secret: secret,
    algorithm: algorithm,
    digits: digits,
    period: period,
  );
}

// The label is "Issuer:account" or just "account". The colon splits at the
// first one, and spaces around the parts are dropped ("Issuer: account").
(String?, String) _splitLabel(String label) {
  final colon = label.indexOf(':');
  if (colon < 0) return (null, label);
  final issuer = label.substring(0, colon).trim();
  final name = label.substring(colon + 1).trim();
  return (issuer.isEmpty ? null : issuer, name);
}

// The secret as bytes. Nothing of the text goes into a failure.
Uint8List _readSecret(String? text) {
  if (text == null || text.trim().isEmpty) {
    throw const _Reject(MissingSecret());
  }
  try {
    final bytes = decodeBase32(text);
    if (bytes.isEmpty) throw const _Reject(InvalidSecret());
    return bytes;
  } on FormatException {
    throw const _Reject(InvalidSecret());
  }
}

OtpAlgorithm _readAlgorithm(String? text) {
  if (text == null) return OtpAlgorithm.sha1;
  return switch (text.trim().toUpperCase()) {
    'SHA1' => OtpAlgorithm.sha1,
    'SHA256' => OtpAlgorithm.sha256,
    'SHA512' => OtpAlgorithm.sha512,
    _ => throw _Reject(InvalidParameter('algorithm', text)),
  };
}

// A whole number from [min] to [max] (no upper limit if null), or [fallback]
// if the parameter is absent. A parameter that is there but empty or not a
// number is a failure, not a fallback.
int _readNumber(String name, String? text, int fallback, int min, int? max) {
  if (text == null) return fallback;
  final value = int.tryParse(text.trim());
  if (value == null || value < min || (max != null && value > max)) {
    throw _Reject(InvalidParameter(name, text));
  }
  return value;
}
