/// What is wrong with a PIN that is about to be set.
enum PinProblem {
  /// Fewer digits than [PinPolicy.minLength].
  tooShort,

  /// More digits than [PinPolicy.maxLength].
  tooLong,

  /// Something other than the digits 0 to 9.
  notDigits,
}

/// The rules for a new PIN.
abstract final class PinPolicy {
  /// The fewest digits.
  static const minLength = 6;

  /// The most digits.
  static const maxLength = 12;

  static final _digits = RegExp(r'^[0-9]*$');

  /// What is wrong with [pin], or null if it is fine.
  static PinProblem? check(String pin) {
    if (!_digits.hasMatch(pin)) return PinProblem.notDigits;
    if (pin.length < minLength) return PinProblem.tooShort;
    if (pin.length > maxLength) return PinProblem.tooLong;
    return null;
  }
}
