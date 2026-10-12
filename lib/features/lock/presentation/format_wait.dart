/// A wait as minutes and seconds, `0:30` or `5:00`, and with hours from an
/// hour on, `1:00:00`. A part of a second counts as a whole one, so the
/// countdown never shows zero while there is still time to wait.
String formatWait(Duration wait) {
  final totalSeconds = wait.isNegative
      ? 0
      : (wait.inMilliseconds / 1000).ceil();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  return '$minutes:$ss';
}
