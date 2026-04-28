import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:yswords/models/bible_evidence.dart';

/// Lazy loader + index for the Biblical Evidence Archive
/// (`assets/bible_evidence.json`, ~1.5 MB, 209 entries).
///
/// First call parses the JSON once and caches; subsequent calls
/// return the cached list. Filter/search helpers operate on the
/// cached data so the UI's filter chips stay snappy.
class BibleEvidenceService {
  static List<BibleEvidence>? _cache;
  static Future<List<BibleEvidence>>? _loading;

  static Future<List<BibleEvidence>> all() async {
    if (_cache != null) return _cache!;
    _loading ??= _load();
    return await _loading!;
  }

  static Future<List<BibleEvidence>> _load() async {
    final raw =
        await rootBundle.loadString('assets/bible_evidence.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['evidences'] as List)
        .map((e) => BibleEvidence.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = list;
    return list;
  }

  /// Free-text search across title / summary / location / scripture
  /// reference / Bible books in the supplied [locale]. Case-
  /// insensitive substring match.
  static List<BibleEvidence> search(
      List<BibleEvidence> source, String query, String locale) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((e) {
      final hay = [
        e.localizedTitle(locale),
        e.localizedSummary(locale),
        e.location,
        e.scriptureReference,
        e.bibleBooks.join(' '),
        e.category,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  /// Return entries whose [scriptureReference] is in [book] (case-
  /// sensitive English book name) — used to surface "Evidence for
  /// this chapter" inside the reader.
  static List<BibleEvidence> forBook(
      List<BibleEvidence> source, String englishBook) {
    return source
        .where((e) =>
            e.scriptureReference.toLowerCase().startsWith(
                englishBook.toLowerCase()) ||
            e.bibleBooks.contains(englishBook))
        .toList();
  }

  /// Picks today's "Daily Evidence" deterministically by day-of-year,
  /// like the daily-verse rotation. Two devices on the same calendar
  /// day see the same one.
  static BibleEvidence? todayEvidence(
      List<BibleEvidence> source, {DateTime? now}) {
    if (source.isEmpty) return null;
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, 1, 1);
    final dayOfYear = n.difference(start).inDays;
    return source[dayOfYear % source.length];
  }
}
