import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/drive_sync_service.dart';
import 'package:yswords/services/profile_service.dart';

/// One reading entry within a [ReadingPlan]. `readings` is a list of
/// reference strings ("Genesis 1", "Psalms 23", "Matthew 5") that the
/// reference parser can resolve. Each chip in the UI represents one
/// reading.
class ReadingPlanDay {
  final int day;
  final List<String> readings;
  const ReadingPlanDay({required this.day, required this.readings});
}

/// A single reading plan (One-Year, Chronological, M'Cheyne, …).
/// Plans are bundled in `assets/reading_plans.json` and loaded lazily.
class ReadingPlan {
  final String id;
  final Map<String, String> name;
  final Map<String, String> description;
  final int days;
  final List<ReadingPlanDay> schedule;

  const ReadingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.days,
    required this.schedule,
  });

  /// Localized name lookup, with safe English fallback.
  String localizedName(String locale) =>
      name[locale] ?? name['en'] ?? id;

  /// Localized description lookup, with safe English fallback.
  String localizedDescription(String locale) =>
      description[locale] ?? description['en'] ?? '';

  /// Returns the day-of-plan entry for [day] (1-indexed). Returns null
  /// if the day is out of range — caller should guard.
  ReadingPlanDay? dayOf(int day) {
    if (day < 1 || day > schedule.length) return null;
    return schedule[day - 1];
  }
}

/// Centralised loader + progress tracker for reading plans. Plans
/// themselves are immutable bundled data; progress (active plan,
/// start date, completed days) lives in SharedPreferences.
class ReadingPlanService {
  static List<ReadingPlan>? _cache;
  static Future<void>? _loading;

  // Base key names. The actual SharedPreferences keys are namespaced
  // by the active profile via `ProfileService.scopedKey()` so each
  // signed-in user keeps their own plan + progress.
  static const _kActiveId = 'plan.activeId';
  static const _kStartDateMs = 'plan.startMs';
  static const _kModeUseDate = 'plan.useDate';
  static const _kCompletedPrefix = 'plan.completed.';

  static String _k(String base) => ProfileService.instance.scopedKey(base);

  /// Load all bundled plans (once per process).
  static Future<List<ReadingPlan>> all() async {
    if (_cache != null) return _cache!;
    _loading ??= _load();
    await _loading;
    return _cache ?? const [];
  }

  static Future<void> _load() async {
    final raw =
        await rootBundle.loadString('assets/reading_plans.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['plans'] as List;
    final out = <ReadingPlan>[];
    for (final p in list) {
      final m = p as Map<String, dynamic>;
      final schedule = (m['schedule'] as List).map((d) {
        final dm = d as Map<String, dynamic>;
        return ReadingPlanDay(
          day: dm['day'] as int,
          readings: (dm['readings'] as List).cast<String>(),
        );
      }).toList();
      out.add(ReadingPlan(
        id: m['id'] as String,
        name: Map<String, String>.from(m['name'] as Map),
        description: Map<String, String>.from(m['description'] as Map),
        days: m['days'] as int,
        schedule: schedule,
      ));
    }
    _cache = out;
  }

  /// Find a plan by its [id]. Returns null if unknown.
  static Future<ReadingPlan?> byId(String? id) async {
    if (id == null || id.isEmpty) return null;
    final plans = await all();
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ── Active-plan settings ───────────────────────────────────────────

  /// Currently selected plan id, or null if the user hasn't picked one.
  static Future<String?> activeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_k(_kActiveId));
  }

  static Future<void> setActiveId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_k(_kActiveId));
    } else {
      await prefs.setString(_k(_kActiveId), id);
    }
    DriveSyncService.instance.requestUpload();
  }

  /// Start date for the active plan. Used together with `useDate=true`
  /// to compute today's day-of-plan. If null, defaults to today the
  /// first time the user opens a plan.
  static Future<DateTime?> startDate() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_k(_kStartDateMs));
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setStartDate(DateTime? d) async {
    final prefs = await SharedPreferences.getInstance();
    if (d == null) {
      await prefs.remove(_k(_kStartDateMs));
    } else {
      // Store as midnight UTC of the chosen calendar day so day-rollover
      // doesn't depend on the user's exact start time.
      final midnight = DateTime.utc(d.year, d.month, d.day);
      await prefs.setInt(_k(_kStartDateMs), midnight.millisecondsSinceEpoch);
    }
    DriveSyncService.instance.requestUpload();
  }

  /// Whether to compute today's day from the calendar date (true) or
  /// from the day-of-year (false). Day-of-year is convenient for
  /// canonical/chronological plans — they restart Jan 1 each year.
  static Future<bool> useDateMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_k(_kModeUseDate)) ?? true;
  }

  static Future<void> setUseDateMode(bool useDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_kModeUseDate), useDate);
    DriveSyncService.instance.requestUpload();
  }

  /// Compute today's 1-indexed day-of-plan for [plan], based on the
  /// current settings. Always clamped to `[1, plan.days]`.
  static Future<int> todayOfPlan(ReadingPlan plan, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final useDate = await useDateMode();
    if (!useDate) {
      // Day-of-year, 1..365/366. Clamp to plan.days.
      final start = DateTime(n.year, 1, 1);
      final diff = n.difference(start).inDays + 1;
      return diff.clamp(1, plan.days);
    }
    var start = await startDate();
    start ??= DateTime(n.year, n.month, n.day);
    final today = DateTime(n.year, n.month, n.day);
    final s = DateTime(start.year, start.month, start.day);
    final diff = today.difference(s).inDays + 1;
    if (diff < 1) return 1;
    if (diff > plan.days) {
      // Wrap around so multi-year readers get day 1 again.
      return ((diff - 1) % plan.days) + 1;
    }
    return diff;
  }

  // ── Completion progress ────────────────────────────────────────────

  /// Returns the set of completed day numbers for [planId].
  static Future<Set<int>> completedDays(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_k('$_kCompletedPrefix$planId'));
    if (list == null) return <int>{};
    return list
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toSet();
  }

  static Future<void> setDayCompleted(
      String planId, int day, bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _k('$_kCompletedPrefix$planId');
    final cur = (prefs.getStringList(key) ?? <String>[]).toSet();
    if (completed) {
      cur.add(day.toString());
    } else {
      cur.remove(day.toString());
    }
    await prefs.setStringList(key, cur.toList());
    DriveSyncService.instance.requestUpload();
  }

  /// Wipe all completion tracking for [planId]. Used by Settings →
  /// Reset Progress.
  static Future<void> resetProgress(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k('$_kCompletedPrefix$planId'));
    DriveSyncService.instance.requestUpload();
  }
}
