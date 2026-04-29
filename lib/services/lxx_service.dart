import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:yswords/models/strongs.dart';
import 'package:yswords/services/strongs_service.dart';

/// Lookup of Septuagint (LXX) Greek equivalents for Hebrew Strong's
/// numbers. Backed by `assets/strongs/lxx_hebrew_to_greek.json`, a
/// curated mapping of the most theologically high-value Hebrew terms
/// to their canonical Greek translations as used in the LXX.
///
/// The mapping is many-to-many in principle but stored as
/// Hebrew# → ordered list of Greek# (most-frequent translation first).
/// Calling code can then feed each Greek # back into [StrongsService]
/// and the existing word-family / synonyms machinery to enable cross-
/// language word study (e.g. חֶסֶד H2617 → ἔλεος G1656 → χάρις G5485).
class LxxService {
  static Map<String, List<String>>? _cache;
  static Future<void>? _loading;

  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    final raw = await rootBundle.loadString(
        'assets/strongs/lxx_hebrew_to_greek.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, List<String>>{};
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) continue; // skip _meta
      final list = (entry.value as List).cast<String>();
      out[entry.key] = list;
    }
    _cache = out;
  }

  /// Returns the Greek Strong's #s that the LXX uses to translate the
  /// given Hebrew [number]. Empty list if no mapping is curated for
  /// that entry (does not throw).
  static Future<List<String>> greekFor(String number) async {
    if (number.isEmpty || !number.startsWith('H')) return const [];
    await _ensureLoaded();
    return _cache?[number] ?? const [];
  }

  /// Convenience: returns the resolved Greek [StrongsEntry]s in the
  /// same order as [greekFor]. Skips numbers the lexicon doesn't know.
  static Future<List<StrongsEntry>> greekEntriesFor(String number) async {
    final nums = await greekFor(number);
    if (nums.isEmpty) return const [];
    final entries = <StrongsEntry>[];
    for (final n in nums) {
      final e = await StrongsService.lookup(n);
      if (e != null) entries.add(e);
    }
    return entries;
  }

  /// Reverse lookup: returns Hebrew Strong's #s that the LXX renders
  /// using the given Greek [number]. Useful for NT word study —
  /// e.g. given G2962 (κύριος), surface H3068 (יהוה) and H136 (אֲדֹנָי)
  /// so the reader sees the Hebrew background of the Greek term.
  static Future<List<String>> hebrewSourcesFor(String number) async {
    if (number.isEmpty || !number.startsWith('G')) return const [];
    await _ensureLoaded();
    final cache = _cache;
    if (cache == null) return const [];
    final out = <String>[];
    cache.forEach((hebNum, greekList) {
      if (greekList.contains(number)) out.add(hebNum);
    });
    // Sort by Hebrew Strong's # for stable order.
    out.sort((a, b) {
      final na = int.tryParse(a.substring(1)) ?? 0;
      final nb = int.tryParse(b.substring(1)) ?? 0;
      return na.compareTo(nb);
    });
    return out;
  }

  /// Convenience: resolved Hebrew [StrongsEntry]s for the reverse lookup.
  static Future<List<StrongsEntry>> hebrewSourceEntriesFor(
      String number) async {
    final nums = await hebrewSourcesFor(number);
    if (nums.isEmpty) return const [];
    final entries = <StrongsEntry>[];
    for (final n in nums) {
      final e = await StrongsService.lookup(n);
      if (e != null) entries.add(e);
    }
    return entries;
  }
}
