/// Whether [a] and [b] hold the same bytes, in a time that does not depend on
/// where they differ.
///
/// `==` on lists stops at the first byte that differs, and the time it took
/// would tell a guesser how many leading bytes of a hash were right. This one
/// always looks at every byte. A difference in length is counted as a
/// difference, without stopping either.
bool constantTimeEquals(List<int> a, List<int> b) {
  var difference = a.length ^ b.length;
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    difference |= x ^ y;
  }
  return difference == 0;
}
