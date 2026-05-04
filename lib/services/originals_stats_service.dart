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

  /// True when this lemma is a "stopword" — a high-frequency
  /// grammatical particle (the, and, of, who, that, in, …) rather
  /// than a content word. Round 56 user feedback: "最频繁使用应该
  /// 也有一个 toggle, 把这些没有意义的字 filter out". The Stats UI
  /// exposes a switch that hides these so meaningful theological
  /// words rise to the top.
  ///
  /// We list specific Strong's numbers (not heuristics on the gloss
  /// string) so the filter is deterministic and easy to audit.
  /// Proper nouns and verbs of saying/seeing/doing are deliberately
  /// LEFT IN — they're high-frequency but semantically meaningful.
  bool get isStopword => _stopwordStrongs.contains(strongs);
}

/// Strong's numbers for grammatical particles / structural markers
/// that dominate raw frequency tables but carry no theological
/// content on their own. Filtering these surfaces verbs, nouns, and
/// proper names that the user actually wants to study.
const Set<String> _stopwordStrongs = {
  // ── Hebrew (OT) ────────────────────────────────────────────────
  'H834',  // ʾăšer — relative pronoun (which/who/that)
  'H853',  // ʾēṯ    — direct-object marker (untranslated)
  'H3588', // kî     — conjunction (because/that/when)
  'H3605', // kōl    — pronoun (all/every/whole)
  'H1961', // hāyâ   — copula (to be / it came to pass)
  'H1909', // hēn    — particle (behold / lo)
  'H6213', // ʿāśâ   — borderline; common verb of doing
  'H559',  // ʾāmar  — borderline; "said" in narrative
  // ── Greek (NT) ─────────────────────────────────────────────────
  'G2532', // kaí        — conjunction (and)
  'G3588', // ho         — definite article (the)
  'G1161', // dé         — conjunction (but / and / now)
  'G1722', // en         — preposition (in)
  'G1519', // eis        — preposition (into)
  'G1537', // ek         — preposition (out of)
  'G1909', // epi        — preposition (upon / on)
  'G2596', // katá       — preposition (according to / down)
  'G3326', // metá       — preposition (with / after)
  'G4314', // prós       — preposition (to / toward)
  'G575',  // apó        — preposition (from)
  'G846',  // autós      — pronoun (he / she / it / same)
  'G3739', // hós        — relative pronoun (who / which / that)
  'G3754', // hóti       — conjunction (that / because)
  'G1063', // gár        — conjunction (for)
  'G3756', // ou         — negation (not)
  'G3361', // mḗ         — negation (not)
  'G5613', // hōs        — adverb (as / like)
  'G1510', // eimí       — copula (to be)
  'G3956', // pás        — pronoun (all / every)
  'G3303', // mén        — particle (indeed / on the one hand)
  'G3779', // hoútōs     — adverb (so / thus)
  'G2192', // échō       — borderline; "to have"
};

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

  /// Aggregate stats over the entire Bible's original text.
  /// Used by the Overview / Books / Vocabulary tabs of the Stats
  /// page (Round 56 — user request: "统计分析、词汇、书卷总揽都需要
  /// 基于原文").
  static OriginalsAggregateStats? _aggregateCache;
  static Future<OriginalsAggregateStats> aggregate() async {
    if (_aggregateCache != null) return _aggregateCache!;
    final all = await load();

    int totalHebrew = 0;
    int totalGreek = 0;
    int uniqueHebrew = 0;
    int uniqueGreek = 0;
    final hebrewHapax = <OriginalsLemma>[];
    final greekHapax = <OriginalsLemma>[];

    // Per-book aggregate: total words + unique lemmas + top N
    final perBookTotals = <String, int>{};
    final perBookUnique = <String, Set<String>>{};
    final perBookTop = <String, List<MapEntry<String, int>>>{};

    for (final lemma in all) {
      if (lemma.isHebrew) {
        totalHebrew += lemma.count;
        uniqueHebrew++;
        if (lemma.count == 1) hebrewHapax.add(lemma);
      } else {
        totalGreek += lemma.count;
        uniqueGreek++;
        if (lemma.count == 1) greekHapax.add(lemma);
      }
      for (final entry in lemma.byBook.entries) {
        perBookTotals[entry.key] =
            (perBookTotals[entry.key] ?? 0) + entry.value;
        perBookUnique
            .putIfAbsent(entry.key, () => <String>{})
            .add(lemma.strongs);
      }
    }

    // Build per-book top-5 lemma lists. We need to walk all again
    // tracking each book's top contributors.
    final perBookSorted = <String, List<OriginalsLemma>>{};
    for (final lemma in all) {
      for (final book in lemma.byBook.keys) {
        perBookSorted.putIfAbsent(book, () => <OriginalsLemma>[]).add(lemma);
      }
    }
    perBookSorted.forEach((book, lemmas) {
      lemmas.sort(
          (a, b) => (b.byBook[book] ?? 0).compareTo(a.byBook[book] ?? 0));
      perBookTop[book] = lemmas
          .take(5)
          .map((l) => MapEntry(l.strongs, l.byBook[book] ?? 0))
          .toList();
    });

    // First 100 Hebrew + 100 Greek for the Vocabulary tab default.
    final topHebrew =
        all.where((l) => l.isHebrew).take(100).toList();
    final topGreek =
        all.where((l) => !l.isHebrew).take(100).toList();

    final bookStats = <OriginalsBookStat>[];
    perBookTotals.forEach((book, total) {
      final unique = perBookUnique[book]?.length ?? 0;
      final isOt = _otBooks.contains(book);
      bookStats.add(OriginalsBookStat(
        englishBook: book,
        isOt: isOt,
        totalWords: total,
        uniqueLemmas: unique,
        topInBook: perBookTop[book] ?? const [],
      ));
    });
    // Canonical order
    bookStats.sort((a, b) {
      final ai = _canonicalIndex(a.englishBook);
      final bi = _canonicalIndex(b.englishBook);
      return ai.compareTo(bi);
    });

    _aggregateCache = OriginalsAggregateStats(
      totalHebrewWords: totalHebrew,
      totalGreekWords: totalGreek,
      uniqueHebrewLemmas: uniqueHebrew,
      uniqueGreekLemmas: uniqueGreek,
      hebrewHapaxCount: hebrewHapax.length,
      greekHapaxCount: greekHapax.length,
      topHebrew: topHebrew,
      topGreek: topGreek,
      bookStats: bookStats,
    );
    return _aggregateCache!;
  }

  static int _canonicalIndex(String book) {
    final i = _canonicalOrder.indexOf(book);
    return i < 0 ? 999 : i;
  }
}

/// 39 OT books (Hebrew). Used to flag book entries in the
/// aggregate stats.
const _otBooks = <String>{
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
  '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
  'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
  'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
  'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
  'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
  'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
};

const List<String> _canonicalOrder = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
  '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
  'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
  'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
  'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
  'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
  'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
  'Matthew', 'Mark', 'Luke', 'John', 'Acts',
  'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
  'Ephesians', 'Philippians', 'Colossians',
  '1 Thessalonians', '2 Thessalonians',
  '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
  'Hebrews', 'James', '1 Peter', '2 Peter',
  '1 John', '2 John', '3 John', 'Jude', 'Revelation',
];

/// Per-book originals statistic.
class OriginalsBookStat {
  final String englishBook;
  final bool isOt;
  final int totalWords;
  final int uniqueLemmas;

  /// Top 5 Strong's #s by occurrence in this book — value is the
  /// count for that book only, not global.
  final List<MapEntry<String, int>> topInBook;

  const OriginalsBookStat({
    required this.englishBook,
    required this.isOt,
    required this.totalWords,
    required this.uniqueLemmas,
    required this.topInBook,
  });
}

/// Aggregate stats over the entire Bible's original text.
class OriginalsAggregateStats {
  final int totalHebrewWords;
  final int totalGreekWords;
  final int uniqueHebrewLemmas;
  final int uniqueGreekLemmas;
  final int hebrewHapaxCount;
  final int greekHapaxCount;

  /// Top 100 most-frequent Hebrew lemmas (descending).
  final List<OriginalsLemma> topHebrew;

  /// Top 100 most-frequent Greek lemmas (descending).
  final List<OriginalsLemma> topGreek;

  /// Per-book originals statistics, in canonical Bible order.
  final List<OriginalsBookStat> bookStats;

  const OriginalsAggregateStats({
    required this.totalHebrewWords,
    required this.totalGreekWords,
    required this.uniqueHebrewLemmas,
    required this.uniqueGreekLemmas,
    required this.hebrewHapaxCount,
    required this.greekHapaxCount,
    required this.topHebrew,
    required this.topGreek,
    required this.bookStats,
  });

  int get totalWords => totalHebrewWords + totalGreekWords;
  int get uniqueLemmas => uniqueHebrewLemmas + uniqueGreekLemmas;
  int get totalHapax => hebrewHapaxCount + greekHapaxCount;
}
