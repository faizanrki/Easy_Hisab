/// Source of the current time. Inject it so tests can control "now".
///
/// All stored timestamps are UTC milliseconds since epoch.
abstract interface class Clock {
  DateTime nowUtc();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

final class FixedClock implements Clock {
  FixedClock(DateTime time) : _time = time.toUtc();
  DateTime _time;

  void advance(Duration d) => _time = _time.add(d);

  @override
  DateTime nowUtc() => _time;
}
