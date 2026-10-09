import 'dart:typed_data';

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// Decodes a Base32 string (RFC 4648) into bytes.
///
/// The secret of a one-time code comes in this encoding, in a QR code or typed
/// by hand. The case does not matter. Spaces and line breaks are ignored, as
/// services print secrets in groups, and so are `=` signs at the end.
///
/// Throws a [FormatException] for a character outside `A-Z` and `2-7`, for a
/// `=` that is not at the end, and for a length that cannot be a whole number
/// of bytes. The message never contains the input: the input is a secret, and
/// an exception message ends up in logs.
Uint8List decodeBase32(String input) {
  final text = input.replaceAll(RegExp(r'\s'), '').toUpperCase();
  var end = text.length;
  while (end > 0 && text[end - 1] == '=') {
    end--;
  }

  // 5 bits per character. After the last whole byte there may be 0 to 4 spare
  // bits, which is the padding of the last group; 1, 3 and 6 characters in a
  // group of 8 would leave 5, 15 or 30 bits and can not be a part of a byte.
  if (const {1, 3, 6}.contains(end % 8)) {
    throw const FormatException('Invalid Base32 length');
  }

  final bytes = <int>[];
  var buffer = 0;
  var bits = 0;
  for (var i = 0; i < end; i++) {
    final value = _alphabet.indexOf(text[i]);
    if (value < 0) {
      throw FormatException('Invalid Base32 character at position $i');
    }
    buffer = (buffer << 5) | value;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.add((buffer >> bits) & 0xFF);
      // Keep only the bits that are not used yet, so the buffer stays small.
      buffer &= (1 << bits) - 1;
    }
  }
  return Uint8List.fromList(bytes);
}
