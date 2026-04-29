// Day-part greeting helper. Pure function so it can be unit-tested
// without spinning up a widget tree.
//
// Pre-fix bug: the dashboard used `hour < 12` for "morning", which
// meant opening the app at 00:00 greeted you with "Good morning".
// Real-world morning starts around 5am, so that boundary moves.

/// Buckets the day into four parts. UI translates via uiStrings.
enum DayPart { morning, afternoon, evening, night }

/// Returns the day-part for the given hour (0-23).
///   05:00 – 11:59  morning
///   12:00 – 17:59  afternoon
///   18:00 – 21:59  evening
///   22:00 – 04:59  night
DayPart dayPartForHour(int hour) {
  if (hour >= 5 && hour < 12) return DayPart.morning;
  if (hour >= 12 && hour < 18) return DayPart.afternoon;
  if (hour >= 18 && hour < 22) return DayPart.evening;
  return DayPart.night;
}

/// Convenience for the dashboard: returns the localized greeting
/// string for [now], defaulting to the system clock.
String greetingFor({DateTime? now, required String locale}) {
  final h = (now ?? DateTime.now()).hour;
  final part = dayPartForHour(h);
  final isZh = locale.startsWith('zh');
  switch (part) {
    case DayPart.morning:
      return isZh ? '早安' : 'Good morning';
    case DayPart.afternoon:
      return isZh ? '午安' : 'Good afternoon';
    case DayPart.evening:
      return isZh ? '晚安' : 'Good evening';
    case DayPart.night:
      return isZh ? '夜安' : 'Good night';
  }
}
