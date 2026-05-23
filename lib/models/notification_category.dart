// 2026-05-24 (v1.3.0): per-category notification preferences.
// User asked "in notifications can have setting for what to push like
// daily verse or news or bible evidence and what time to push and more".
// One row per category in Settings → each row has its own enable
// toggle + time-of-day + weekday mask. Stored as JSON in
// SharedPreferences via AppSettings.
//
// "Category" maps to one of NotificationCategoryIds — kept as strings
// (not enum) so persistence is stable across version bumps and
// new categories don't crash existing installs.

import 'package:flutter/foundation.dart';

class NotificationCategoryIds {
  NotificationCategoryIds._();

  /// Morning verse from assets/daily_verses.json (dayOfYear-indexed).
  static const String dailyVerse = 'daily_verse';

  /// Archaeological / historical evidence entry from
  /// assets/bible_evidence.json.
  static const String bibleEvidence = 'bible_evidence';

  /// Sermon of the day from assets/sermons/index.json.
  static const String sermonOfDay = 'sermon_of_day';

  /// Daily news headline fetched from yswords-data CDN.
  /// (Phase 2 — needs network at fire time; v1.3.0 omits)
  static const String newsDigest = 'news_digest';

  /// Bedtime verse — from user bookmarks or daily_verses fallback.
  /// (Phase 2 — needs user bookmark integration; v1.3.0 omits)
  static const String memoryVerse = 'memory_verse';

  /// All category IDs in display order. Phase-1 ships the first 3.
  static const List<String> all = [
    dailyVerse,
    bibleEvidence,
    sermonOfDay,
    newsDigest,
    memoryVerse,
  ];

  /// Which categories ship in v1.3.0. Phase-2 will widen this list.
  static const List<String> phase1 = [
    dailyVerse,
    bibleEvidence,
    sermonOfDay,
  ];
}

@immutable
class NotificationCategoryPrefs {
  /// Whether this category fires at all.
  final bool enabled;

  /// Local fire time (0-23 hour, 0-59 minute). The scheduler converts
  /// to tz.TZDateTime at reschedule time.
  final int hour;
  final int minute;

  /// Days of the week this category fires on. ISO weekday: Mon=1
  /// .. Sun=7. Empty set → fire every day. Default is every day.
  final Set<int> weekdays;

  const NotificationCategoryPrefs({
    required this.enabled,
    required this.hour,
    required this.minute,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
  });

  /// Defaults shipped in v1.3.0. Distinct per-category default times
  /// so the user gets a reasonable "wake up to verse, read evidence
  /// over lunch, end day with sermon" rhythm out of the box; they
  /// can re-arrange to taste.
  factory NotificationCategoryPrefs.defaultFor(String categoryId) {
    switch (categoryId) {
      case NotificationCategoryIds.dailyVerse:
        return const NotificationCategoryPrefs(
            enabled: false, hour: 7, minute: 0);
      case NotificationCategoryIds.bibleEvidence:
        return const NotificationCategoryPrefs(
            enabled: false, hour: 12, minute: 0);
      case NotificationCategoryIds.sermonOfDay:
        return const NotificationCategoryPrefs(
            enabled: false, hour: 19, minute: 0);
      case NotificationCategoryIds.newsDigest:
        return const NotificationCategoryPrefs(
            enabled: false, hour: 20, minute: 0);
      case NotificationCategoryIds.memoryVerse:
        return const NotificationCategoryPrefs(
            enabled: false, hour: 22, minute: 0);
      default:
        return const NotificationCategoryPrefs(
            enabled: false, hour: 9, minute: 0);
    }
  }

  NotificationCategoryPrefs copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    Set<int>? weekdays,
  }) =>
      NotificationCategoryPrefs(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        weekdays: weekdays ?? this.weekdays,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays.toList()..sort(),
      };

  factory NotificationCategoryPrefs.fromJson(Map<String, dynamic> j) {
    final wd = (j['weekdays'] as List?)?.cast<int>().toSet();
    return NotificationCategoryPrefs(
      enabled: j['enabled'] as bool? ?? false,
      hour: (j['hour'] as int?)?.clamp(0, 23) ?? 9,
      minute: (j['minute'] as int?)?.clamp(0, 59) ?? 0,
      weekdays: wd != null && wd.isNotEmpty
          ? wd
          : const {1, 2, 3, 4, 5, 6, 7},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationCategoryPrefs &&
        other.enabled == enabled &&
        other.hour == hour &&
        other.minute == minute &&
        other.weekdays.length == weekdays.length &&
        other.weekdays.containsAll(weekdays);
  }

  @override
  int get hashCode =>
      Object.hash(enabled, hour, minute, weekdays.length);
}
