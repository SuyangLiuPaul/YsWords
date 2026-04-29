// Pure-Dart Sydney time helpers. We can't depend on `package:timezone`
// or `package:intl` here without bloating the web build, but we DO
// need Sydney-correct timestamps for the daily-news "last updated"
// label — and Sydney swings between AEST (+10) and AEDT (+11) twice
// a year, so a hardcoded +10 lies for half the year.
//
// Pre-fix bug: `_formatLastUpdated` did `toUtc().add(Duration(hours: 10))`,
// which displayed times one hour BEHIND reality during AEDT
// (October's first Sunday 03:00 through April's first Sunday 03:00).

/// Australian Eastern Time offset for [moment] in minutes from UTC.
///   AEST  +600 (10h)  — most of the year
///   AEDT  +660 (11h)  — first Sunday of October through first Sunday of April
///
/// Both transitions happen at Sydney local 02:00 / 03:00, which in UTC
/// is the prior Saturday at 16:00 UTC. We compute that instant and
/// branch on whether [moment] is before or after.
int sydneyOffsetMinutes(DateTime moment) {
  final utc = moment.toUtc();
  final year = utc.year;
  final dstStart = _sydneyDstTransitionUtc(year, DateTime.october);
  final dstEnd = _sydneyDstTransitionUtc(year, DateTime.april);

  // Southern hemisphere DST wraps the calendar year:
  //   Jan 1 .. dstEnd          → AEDT
  //   dstEnd .. dstStart       → AEST
  //   dstStart .. Dec 31       → AEDT
  final inAedt = utc.isBefore(dstEnd) || !utc.isBefore(dstStart);
  return inAedt ? 660 : 600;
}

/// Convert a UTC DateTime to Sydney wall-clock as a "local-as-UTC"
/// DateTime. The returned DateTime has [isUtc] = true but its fields
/// reflect Sydney local time — Dart has no first-class arbitrary TZ.
DateTime toSydney(DateTime moment) {
  final utc = moment.toUtc();
  final offsetMin = sydneyOffsetMinutes(utc);
  return utc.add(Duration(minutes: offsetMin));
}

/// "AEST" or "AEDT" matching [moment]. Useful for honest labelling so
/// a Northern-hemisphere reader understands the offset.
String sydneyTzLabel(DateTime moment) {
  return sydneyOffsetMinutes(moment) == 660 ? 'AEDT' : 'AEST';
}

/// Format moment as `YYYY-MM-DD HH:MM` in Sydney local time.
String formatSydneyStamp(DateTime moment) {
  final s = toSydney(moment);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${s.year}-${two(s.month)}-${two(s.day)} '
      '${two(s.hour)}:${two(s.minute)}';
}

/// Format moment in the VIEWER's local timezone, falling back to
/// Melbourne (which shares Sydney's AEST/AEDT) if the device can't
/// resolve a local zone.
///
/// On every platform Dart supports, `toLocal()` returns the device's
/// configured timezone — on web that's the browser's resolved IANA
/// zone, on native it's the OS setting. The Melbourne fallback only
/// kicks in for the (rare) case where the device clock is broken
/// or the user has no system locale.
({String stamp, String tzLabel}) formatViewerLocalStamp(DateTime moment) {
  try {
    final local = moment.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
    final tz = local.timeZoneName;
    // On web, Dart returns short codes like "AEST" / "PDT" — use as-is.
    // On macOS / Linux it sometimes returns long names like "Australian
    // Eastern Standard Time"; truncate to the first letters of each
    // word so we don't blow out the masthead width.
    final tzLabel = tz.contains(' ')
        ? tz.split(' ').map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase()
        : tz;
    return (stamp: stamp, tzLabel: tzLabel);
  } catch (_) {
    // Fall back to Melbourne (same TZ as Sydney since the user lives
    // in Australia). Safer than throwing; the user still sees a
    // reasonable timestamp.
    return (stamp: formatSydneyStamp(moment), tzLabel: 'Melbourne');
  }
}

/// UTC instant of the Sydney DST transition in [month] of [year]:
///   - October: AEST → AEDT at local 02:00 first Sunday
///   - April:   AEDT → AEST at local 03:00 first Sunday
///
/// Both transitions land at Saturday 16:00 UTC because:
///   02:00 AEST = 16:00 UTC the day before
///   03:00 AEDT = 16:00 UTC the day before
DateTime _sydneyDstTransitionUtc(int year, int month) {
  // Find first Sunday of [month] at 00:00 UTC.
  var d = DateTime.utc(year, month, 1);
  final daysUntilSunday = (DateTime.sunday - d.weekday) % 7;
  d = d.add(Duration(days: daysUntilSunday));
  // Step back to Saturday 16:00 UTC — the actual transition instant.
  return d.subtract(const Duration(hours: 8));
}
