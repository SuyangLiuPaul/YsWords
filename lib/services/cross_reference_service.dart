import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:yswords/utils/reference_parser.dart';

/// Cross-reference lookup. For any verse `(englishBook, chapter,
/// verse)`, returns related verses that explain, fulfil, parallel,
/// or contrast its theme — the "Treasury of Scripture Knowledge"
/// equivalent. Initial dataset is curated; expansion is data-only.
class CrossReferenceService {
  static Map<String, List<BibleReference>>? _cache;
  static Future<void>? _loading;

  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    final raw =
        await rootBundle.loadString('assets/cross_references.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, List<BibleReference>>{};
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) continue; // skip _meta
      final list = entry.value as List;
      final refs = <BibleReference>[];
      for (final s in list) {
        final parsed = parseReference(s as String);
        if (parsed != null) refs.add(parsed);
      }
      out[_keyFromString(entry.key)] = refs;
    }
    _cache = out;
  }

  /// Returns the cross-references for a given verse, or empty list
  /// if the verse isn't in the curated dataset.
  ///
  /// [englishBook] must be the canonical English book name (e.g.
  /// "John", "1 Corinthians"). [verse] is the verse number; for
  /// queries that span a verse range you can pass the first verse —
  /// the lookup matches the entry's start verse.
  static Future<List<BibleReference>> forVerse(
      String englishBook, int chapter, int verse) async {
    if (englishBook.isEmpty || chapter <= 0 || verse <= 0) return const [];
    await _ensureLoaded();
    final key = _key(englishBook, chapter, verse);
    return _cache?[key] ?? const [];
  }

  /// Heuristic for chapter-level queries:
  ///   1. Try the exact verse key first. With the OpenBible TSK
  ///      dataset this is the common case — every verse in the Bible
  ///      has its own entry (29k+ source verses).
  ///   2. If the exact key is missing, find ALL nearby verses in the
  ///      same chapter and merge their refs (deduped by canonical
  ///      reference key). Sort by closeness to the requested verse so
  ///      the most relevant nearby refs appear first.
  ///   3. Cap the merged result at 12 refs to keep the sheet readable.
  ///
  /// Pre-round-50: only returned the first nearby key's refs, so a
  /// chapter with 8 verses each having one ref would surface only
  /// the first verse's refs — confusing.
  static Future<List<BibleReference>> forVerseOrNearby(
      String englishBook, int chapter, int verse) async {
    await _ensureLoaded();
    final cache = _cache;
    if (cache == null) return const [];

    final exact = cache[_key(englishBook, chapter, verse)] ?? const [];
    if (exact.isNotEmpty) return exact;

    // Walk all keys in the same book+chapter; sort by distance from
    // the requested verse so refs closest to the user's tap appear
    // first.
    final prefix = '$englishBook $chapter:';
    final neighbours = <int, List<BibleReference>>{};
    for (final entry in cache.entries) {
      final k = entry.key;
      if (!k.startsWith(prefix)) continue;
      final v = int.tryParse(k.substring(prefix.length));
      if (v == null) continue;
      neighbours[v] = entry.value;
    }
    if (neighbours.isEmpty) return const [];

    final sortedVerses = neighbours.keys.toList()
      ..sort((a, b) =>
          (a - verse).abs().compareTo((b - verse).abs()));
    final merged = <String, BibleReference>{};
    for (final v in sortedVerses) {
      for (final ref in neighbours[v]!) {
        final key =
            '${ref.englishBook} ${ref.chapter}:${ref.verseStart ?? 1}';
        merged.putIfAbsent(key, () => ref);
        if (merged.length >= 12) break;
      }
      if (merged.length >= 12) break;
    }
    return merged.values.toList();
  }

  /// Total number of curated source verses currently in the dataset.
  /// Useful for surfacing coverage in the UI.
  static Future<int> sourceCount() async {
    await _ensureLoaded();
    return _cache?.length ?? 0;
  }

  static String _key(String book, int ch, int v) => '$book $ch:$v';

  /// Normalize a raw JSON key like "John 3:16" into the same shape
  /// used by [_key]. Some keys in the source file may include verse
  /// ranges ("Matthew 5:3-12") — we collapse to the start verse.
  static String _keyFromString(String raw) {
    final m = RegExp(r'^(.+?)\s+(\d+):(\d+)').firstMatch(raw.trim());
    if (m == null) return raw.trim();
    return '${m.group(1)} ${m.group(2)}:${m.group(3)}';
  }
}
