import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';
import 'package:otp_guard/l10n/s.dart';

/// The texts for the reasons a link can not be used.
extension OtpAuthFailureMessage on S {
  /// A message for each reason a link can not be used. The `switch` is
  /// exhaustive: a new kind of failure does not compile until it has a text.
  String forFailure(OtpAuthFailure failure) {
    return switch (failure) {
      NotAnOtpAuthUri() => failureNotAnOtpAuthUri,
      UnsupportedOtpType(:final type) when type == 'hotp' => failureHotp,
      UnsupportedOtpType(:final type) => failureUnsupportedType(type),
      MissingLabel() => failureMissingLabel,
      MissingSecret() => failureMissingSecret,
      InvalidSecret() => failureInvalidSecret,
      InvalidParameter(name: 'algorithm', :final value) =>
        failureInvalidAlgorithm(value),
      InvalidParameter(name: 'digits', :final value) => failureInvalidDigits(
        value,
      ),
      InvalidParameter(name: 'period', :final value) => failureInvalidPeriod(
        value,
      ),
      InvalidParameter(:final name, :final value) => failureInvalidParameter(
        name,
        value,
      ),
    };
  }
}
