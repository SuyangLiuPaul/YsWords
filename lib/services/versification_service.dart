/// The Hebrew and Greek editions do not number verses the way English
/// and Chinese Bibles do, and until this existed the app assumed they
/// did.
///
/// `assets/originals/` and `assets/strongs/concordance.json` are both
/// numbered the way their source editions number themselves. So the
/// Originals sheet on 詩篇 3:1 fetched `psalms 3:1` and got מִזְמוֹר
/// לְדָוִד — the superscription, which the Hebrew counts as verse 1 and
/// the CUV prints inside verse 1 without a number — while the reader was
/// looking at 「雅伟啊，我的敌人何其加增」. It named a Hebrew word the
/// verse on screen did not contain, and did it in 1,626 verses.
///
/// `assets/originals_versification.json` maps a reading reference to the
/// original reference(s) that carry its text. It was *measured*, not
/// transcribed from a table: `tools/build_versification_map.py` aligns
/// each book's two verse sequences by Strong's-number overlap, so the
/// evidence for every entry is the text itself. It independently
/// reproduces the familiar differences — Genesis 31:55 = Hebrew 32:1,
/// Joel 2:28 = Hebrew 3:1, Malachi 4:1 = Hebrew 3:19 — which is the
/// reason to trust the ones nobody has memorised.
///
/// A reading verse can map to SEVERAL original verses, and that is not a
/// rounding error: 詩篇 51:1 carries the whole two-line superscription
/// as well as the first line of the psalm, which the Hebrew numbers
/// 51:1, 51:2 and 51:3. Returning one of the three would silently drop
/// scripture, so the range is returned whole.
///
/// `assets/originals_versification_merged.json` answers a second and
/// separate question: the CUV translators sometimes fold two numbered
/// verses into one and print the vacated number as 「见上节」. 民数记
/// 1:21 is such a verse, and the census total it should hold is at the
/// end of 1:20 — so the sheet on 1:20 showed half that verse's Hebrew.
/// That is a property of the TRANSLATION, not of the Hebrew, which is
/// why it is a per-version overlay rather than part of the map above:
/// the KJV, NASB and LEB all print 1:21 as a verse of their own, and
/// widening the shared map would show their readers a Hebrew clause
/// their verse 20 does not contain.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

class VersificationService {
  /// book slug → reading "c:v" → original "c:v" references.
  static Map<String, Map<String, List<String>>>? _map;
  static Future<Map<String, Map<String, List<String>>>>? _loading;

  /// book slug → original "c:v" → reading "c:v".
  static Map<String, Map<String, String>>? _inverse;

  /// version → book slug → reading "c:v" → original refs, for the
  /// verses that version merges into one.
  static Map<String, Map<String, Map<String, List<String>>>>? _merged;
  static Future<Map<String, Map<String, Map<String, List<String>>>>>?
      _mergedLoading;

  static String slug(String englishBook) =>
      englishBook.toLowerCase().replaceAll(' ', '_').replaceAll("'", '');

  static Future<Map<String, Map<String, List<String>>>> _load() async {
    try {
      final raw = await rootBundle
          .loadString('assets/originals_versification.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return {
        for (final book in decoded.entries)
          book.key: {
            for (final ref in (book.value as Map<String, dynamic>).entries)
              ref.key: (ref.value as List).cast<String>(),
          },
      };
    } catch (_) {
      // Without the map every reference stands for itself, which is
      // right for the 29 books out of 66 that never differ anyway.
      return const {};
    }
  }

  static Future<Map<String, Map<String, Map<String, List<String>>>>>
      _loadMerged() async {
    try {
      final raw = await rootBundle
          .loadString('assets/originals_versification_merged.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return {
        for (final version in decoded.entries)
          version.key: {
            for (final book in (version.value as Map<String, dynamic>).entries)
              book.key: {
                for (final ref in (book.value as Map<String, dynamic>).entries)
                  ref.key: (ref.value as List).cast<String>(),
              },
          },
      };
    } catch (_) {
      return const {};
    }
  }

  static Future<void> ensureLoaded() async {
    _map ??= await (_loading ??= _load());
    _merged ??= await (_mergedLoading ??= _loadMerged());
  }

  /// The original-language references carrying the text of this reading
  /// verse. Always at least one, and the verse's own reference when the
  /// two editions agree.
  /// [version] is the version being read. Without it a verse that this
  /// translation merges with the next one answers with half its own
  /// original text.
  static Future<List<String>> originalRefs(
    String englishBook,
    int chapter,
    int verse, {
    String? version,
  }) async {
    await ensureLoaded();
    final self = '$chapter:$verse';
    final book = slug(englishBook);
    final merged =
        _merged?[version?.toLowerCase() ?? '']?[book]?[self];
    return merged ?? _map?[book]?[self] ?? [self];
  }

  /// The reading reference for an original-language one — the direction
  /// the concordance needs, since its references are the Hebrew's and
  /// Greek's own. "Joel 4:9" is a verse this app has no page for; it is
  /// Joel 3:9 here.
  static Future<String> readingRef(
    String englishBook,
    String originalRef,
  ) async {
    await ensureLoaded();
    final inverse = _inverse ??= _buildInverse();
    return inverse[slug(englishBook)]?[originalRef] ?? originalRef;
  }

  static Map<String, Map<String, String>> _buildInverse() {
    final out = <String, Map<String, String>>{};
    for (final book in (_map ?? const {}).entries) {
      final table = <String, String>{};
      for (final entry in book.value.entries) {
        for (final original in entry.value) {
          // Two reading verses can share one original verse — the Greek
          // of Romans 16:23 is split across 16:23 and 16:24 here. The
          // earlier reading verse wins, so the reference still lands on
          // text that contains the word.
          table.putIfAbsent(original, () => entry.key);
        }
      }
      out[book.key] = table;
    }
    return out;
  }

  @visibleForTesting
  static void resetForTest() {
    _map = null;
    _loading = null;
    _inverse = null;
  }
}
