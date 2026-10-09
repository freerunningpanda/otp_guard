/// The source of the current time and of the beat that redraws the codes.
///
/// A widget never calls `DateTime.now()` itself. It asks a [Clock], so a test
/// can give it a clock that it winds by hand and check the code at the very
/// second the period ends.
abstract interface class Clock {
  /// The current time.
  DateTime now();

  /// A tick at the start of every second, with the time of that moment.
  ///
  /// A broadcast stream: any number of rows can listen, and the clock keeps
  /// one timer for all of them, which runs only while somebody listens.
  Stream<DateTime> get ticks;
}
