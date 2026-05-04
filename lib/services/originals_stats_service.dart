import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// One row in the Originals stats table — a single Strong's number
/// with its Hebrew/Greek lemma, transliteration, English + Chinese
/// glosses, and aggregate occurrence count.
class OriginalsLemma {
  /// Strong's number in canonical form (`H7225`, `G2316`).
  final String strongs;

  /// True for Hebrew (Old Testament, "H####"), false for Greek
  /// (New Testament, "G####").
  final bool isHebrew;

  /// Original-language word (Hebrew or Greek script).
  final String lemma;

  /// Transliteration (e.g. "ʼâb" for אָב).
  final String translit;

  /// Short English gloss — what the lexicon calls a "summary".
  final String glossEn;

  /// Short Simplified-Chinese gloss.
  final String glossZhHans;

  /// Short Traditional-Chinese gloss.
  final String glossZhHant;

  /// Total occurrence count across the whole Bible.
  final int count;

  /// Per-book occurrence counts (book → count). Keys are the
  /// English canonical book names matching the concordance file.
  final Map<String, int> byBook;

  const OriginalsLemma({
    required this.strongs,
    required this.isHebrew,
    required this.lemma,
    required this.translit,
    required this.glossEn,
    required this.glossZhHans,
    required this.glossZhHant,
    required this.count,
    required this.byBook,
  });

  String glossFor(String locale) {
    if (locale == 'zh-Hant' && glossZhHant.isNotEmpty) return glossZhHant;
    if (locale.startsWith('zh') && glossZhHans.isNotEmpty) return glossZhHans;
    return glossEn;
  }
}

/// Aggregate stats over the original Hebrew + Greek text. Loads
/// `assets/strongs/concordance.json` for occurrence counts +
/// `hebrew.json` / `greek.json` for lexicon glosses; produces a
/// sortable list of [OriginalsLemma] rows.
///
/// Cached at module level — first call parses ~2 MB of JSON, every
/// later call returns the cached list. The Stats page invokes this
/// when the user opens the "Originals" tab so the cost is paid
/// only on demand.
class OriginalsStatsService {
  static List<OriginalsLemma>? _cache;

  /// Reset the cache. Useful for tests; not called from production
  /// code paths.
  static void clearCache() {
    _cache = null;
  }

  /// Load and aggregate. Returns the full list sorted by
  /// descending occurrence count.
  static Future<List<OriginalsLemma>> load() async {
    if (_cache != null) return _cache!;
    final results = <OriginalsLemma>[];
    try {
      final concordanceRaw =
          await rootBundle.loadString('assets/strongs/concordance.json');
      final hebrewRaw =
          await rootBundle.loadString('assets/strongs/hebrew.json');
      final greekRaw =
          await rootBundle.loadString('assets/strongs/greek.json');
      // Yield to event loop between heavy parses so the UI thread
      // gets a frame in. Each parse is ~30-100 ms on a fast
      // device, more on slow ones; spreading them across event-
      // loop ticks keeps the page responsive.
      final concordance =
          json.decode(concordanceRaw) as Map<String, dynamic>;
      await Future<void>.delayed(Duration.zero);
      final hebrew = json.decode(hebrewRaw) as Map<String, dynamic>;
      await Future<void>.delayed(Duration.zero);
      final greek = json.decode(greekRaw) as Map<String, dynamic>;

      for (final entry in concordance.entries) {
        final key = entry.key;
        if (key.startsWith('_')) continue; // skip metadata keys
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        final count = (value['n'] as num?)?.toInt() ?? 0;
        final byBookRaw = (value['b'] as Map<String, dynamic>?) ?? const {};
        final byBook = <String, int>{
          for (final e in byBookRaw.entries)
            e.key: (e.value as num?)?.toInt() ?? 0,
        };
        final isHebrew = key.startsWith('H');
        final lex = (isHebrew ? hebrew[key] : greek[key]) as Map<String, dynamic>?;
        if (lex == null) continue; // unknown Strong's #
        results.add(OriginalsLemma(
          strongs: key,
          isHebrew: isHebrew,
          lemma: (lex['lemma'] ?? '').toString(),
          translit: (lex['translit'] ?? '').toString(),
          glossEn: (lex['gloss'] ?? '').toString(),
          glossZhHans: (lex['glossZh'] ?? '').toString(),
          glossZhHant: (lex['glossZhTw'] ?? '').toString(),
          count: count,
          byBook: byBook,
        ));
      }
      // Sort once: descending occurrence count, ties broken by
      // Strong's number (canonical order).
      results.sort((a, b) {
        final c = b.count.compareTo(a.count);
        if (c != 0) return c;
        return a.strongs.compareTo(b.strongs);
      });
    } catch (_) {
      // Asset missing or malformed — return empty list. UI shows
      // an empty-state instead of crashing.
    }
    _cache = results;
    return results;
  }

  /// Top N most frequent lemmas. Convenience for the default
  /// table view.
  static Future<List<OriginalsLemma>> topN({int n = 200}) async {
    final all = await load();
    return all.take(n).toList();
  }

  /// Filter by language: 'hebrew' / 'greek' / 'all'.
  static Future<List<OriginalsLemma>> filtered({
    String language = 'all',
    int? limit,
  }) async {
    final all = await load();
    Iterable<OriginalsLemma> filtered = all;
    if (language == 'hebrew') {
      filtered = all.where((e) => e.isHebrew);
    } else if (language == 'greek') {
      filtered = all.where((e) => !e.isHebrew);
    }
    final list = filtered.toList();
    if (limit != null && list.length > limit) {
      return list.take(limit).toList();
    }
    return list;
  }
}
