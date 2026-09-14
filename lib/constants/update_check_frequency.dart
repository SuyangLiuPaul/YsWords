/// How often the app asks, on its own, whether a newer build exists.
///
/// 2026-09-14, at the owner's request: the daily check was a fixed
/// `Duration(days: 1)` compiled into `AppSettings.updateCheckDueAt`, and
/// the only control over it was a switch. Daily is still the default and
/// still what the switch turns on — what changes is that a reader who
/// wants to be told sooner, or less often, can say so.
///
/// The gaps are minimums, measured from the last check rather than from a
/// calendar boundary: "daily" means "not again for a day", not "once per
/// midnight". The distinction matters because the timestamp is stamped
/// even when a check FAILS — a device that is offline every morning would
/// otherwise retry on every launch all day.
library;

enum UpdateCheckFrequency {
  /// Every time the app opens. The honest name for "no gap at all": this
  /// is one request per launch, which is what a reader tracking releases
  /// closely actually wants and what nobody else should get by default.
  everyLaunch(Duration.zero, 'everyLaunch'),

  /// The default, and the only one of the four the app shipped with.
  daily(Duration(days: 1), 'daily'),

  weekly(Duration(days: 7), 'weekly'),

  monthly(Duration(days: 30), 'monthly');

  const UpdateCheckFrequency(this.gap, this.prefValue);

  /// The minimum time between two checks.
  final Duration gap;

  /// What goes into SharedPreferences. Written out rather than taken from
  /// `name` or `index`: an index breaks the moment a value is inserted in
  /// the middle, and `name` ties a stored preference to a Dart
  /// identifier that a rename would silently orphan.
  final String prefValue;

  /// The reader's stored choice, or [daily] for anything unrecognised —
  /// a null (never set), a value from a newer build, or a key left over
  /// from a rename. Defaulting to the documented default is the only
  /// answer here that cannot surprise someone.
  static UpdateCheckFrequency fromPref(String? stored) {
    for (final f in values) {
      if (f.prefValue == stored) return f;
    }
    return daily;
  }
}
