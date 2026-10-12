/// What is shown in place of a code that must not be seen. Dots, not text, so
/// it needs no translation.
const hiddenCode = '••• •••';

/// A code in two groups, as it is easier to read and to type: `123456` as
/// `123 456`, `12345678` as `1234 5678`, and `1234567` as `123 4567`.
String formatCode(String code) {
  final split = code.length ~/ 2;
  return '${code.substring(0, split)} ${code.substring(split)}';
}
