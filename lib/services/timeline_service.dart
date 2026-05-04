import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/models/timeline_event.dart';

/// Loads the curated `assets/bible_timeline.json` dataset and
/// caches it for the process lifetime.
class TimelineService {
  TimelineService._();
  static final TimelineService instance = TimelineService._();

  List<TimelineEvent>? _cache;

  /// Loads & sorts events chronologically (oldest first).
  Future<List<TimelineEvent>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/bible_timeline.json');
    final j = json.decode(raw) as Map<String, dynamic>;
    final entries = (j['events'] as List?) ?? const [];
    final list = entries
        .whereType<Map<String, dynamic>>()
        .map(TimelineEvent.fromJson)
        .toList();
    list.sort((a, b) => a.year.compareTo(b.year));
    _cache = list;
    return list;
  }

  List<TimelineEvent> allOrEmpty() => _cache ?? const [];
}
