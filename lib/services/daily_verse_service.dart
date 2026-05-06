import 'dart:convert';
import 'package:flutter/services.dart';

/// Loads a small curated list of well-known reference strings and
/// returns one per calendar day. Two devices on the same day see the
/// same verse — selection is `dayOfYear % count`, deterministic and
/// timezone-independent (we use the local calendar day, not UTC,
/// because users think of "today's verse" in their own timezone).
class DailyVerseService {
  static List<String>? _cache;
  static Future<List<String>>? _loading;

  static Future<List<String>> _load() async {
    final raw =
        await rootBundle.loadString('assets/daily_verses.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['verses'] as List).cast<String>();
    return list;
  }

  /// Returns the canonical English reference (e.g. "John 3:16") for
  /// today, or null if the asset failed to load. Caller is
  /// responsible for parsing + resolving via reference_parser.
  static Future<String?> todayRef({DateTime? now}) async {
    _cache ??= await (_loading ??= _load());
    final list = _cache;
    if (list == null || list.isEmpty) return null;
    final n = now ?? DateTime.now();
    // Day-of-year, 1..366. Using a stable rotation means visiting
    // the dashboard several times in one day shows the same verse.
    final start = DateTime(n.year, 1, 1);
    final dayOfYear = n.difference(start).inDays;
    return list[dayOfYear % list.length];
  }

  /// Round 56 (continued — Lookup recommended verses): returns the
  /// last [n] days' worth of daily-verse references, newest first.
  /// Each entry is `(date, ref)` so the caller can label chips with
  /// "Today / Yesterday / 2 days ago" without recomputing the
  /// rotation. Year boundaries are handled by the same modular
  /// arithmetic [todayRef] uses, so the rotation doesn't reset on
  /// Jan 1.
  ///
  /// Returns an empty list if the asset failed to load. Always at
  /// most [n] entries; fewer when n exceeds the dataset (would
  /// otherwise repeat).
  static Future<List<DailyVerseEntry>> recentRefs(int n,
      {DateTime? now}) async {
    _cache ??= await (_loading ??= _load());
    final list = _cache;
    if (list == null || list.isEmpty) return const [];
    final base = now ?? DateTime.now();
    final cap = n.clamp(1, list.length);
    final out = <DailyVerseEntry>[];
    for (int back = 0; back < cap; back++) {
      final day = DateTime(base.year, base.month, base.day)
          .subtract(Duration(days: back));
      final start = DateTime(day.year, 1, 1);
      final dayOfYear = day.difference(start).inDays;
      out.add(DailyVerseEntry(date: day, ref: list[dayOfYear % list.length]));
    }
    return out;
  }
}

/// One entry in the daily-verse history surfaced by
/// [DailyVerseService.recentRefs]. Date is the local-calendar day
/// the rotation pegged the reference to (today, today-1, …); ref
/// is the canonical English reference.
class DailyVerseEntry {
  final DateTime date;
  final String ref;
  const DailyVerseEntry({required this.date, required this.ref});
}
