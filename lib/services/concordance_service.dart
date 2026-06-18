import 'dart:convert';
import 'package:flutter/services.dart';

/// Result of a concordance lookup for one Strong's number.
///
/// `total` is the absolute occurrence count across the entire Bible
/// (counted by the build pipeline before any cap is applied), so the UI
/// can show "Used 19,859 times" even when the bundled list itself is
/// truncated. `refs` are English-name verse strings like "John 3:16",
/// canonical-order sorted, capped at the pipeline's per-entry limit.
/// `byBook` is the absolute (uncapped) per-book count map keyed by
/// canonical English book name — used by the WordDistribution panel.
class ConcordanceResult {
  final int total;
  final List<ConcordanceRef> refs;
  final Map<String, int> byBook;
  const ConcordanceResult({
    required this.total,
    required this.refs,
    this.byBook = const {},
  });
}

class ConcordanceRef {
  final String englishBook;
  final int chapter;
  final int verse;
  final String label;
  const ConcordanceRef({
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.label,
  });

  static ConcordanceRef? tryParse(String label) {
    final m = RegExp(r'^(.+?)\s+(\d+):(\d+)$').firstMatch(label);
    if (m == null) return null;
    return ConcordanceRef(
      englishBook: m.group(1)!,
      chapter: int.parse(m.group(2)!),
      verse: int.parse(m.group(3)!),
      label: label,
    );
  }
}

/// Lazy loader for `assets/strongs/concordance.json` — the inverted
/// index from Strong's number to the verse references where that
/// number appears. The file is loaded once on first lookup and held in
/// memory. ~3.5 MB; acceptable for a Bible study app where any concord
/// lookup is preceded by a deliberate user action (selecting a verse,
/// opening the originals sheet, tapping a word).
class ConcordanceService {
  static Map<String, dynamic>? _cache;
  static Future<Map<String, dynamic>>? _loading;

  static Future<Map<String, dynamic>> _load() async {
    final raw = await rootBundle.loadString('assets/strongs/concordance.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// 2026-06-18 (v1.3.91): all Strong's numbers in the concordance whose
  /// normalized form starts with [prefix] (e.g. "G25" → G25, G250, G251, …
  /// G2599). Powers the `G25*` prefix wildcard in boolean search. Capped at
  /// [limit] so a very short prefix can't union the whole Bible.
  static Future<List<String>> numbersMatchingPrefix(String prefix,
      {int limit = 300}) async {
    if (prefix.isEmpty) return const [];
    _cache ??= await (_loading ??= _load());
    final out = <String>[];
    for (final key in _cache!.keys) {
      if (key.startsWith(prefix)) {
        out.add(key);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  static Future<ConcordanceResult?> lookup(String strongsNumber) async {
    if (strongsNumber.isEmpty) return null;
    _cache ??= await (_loading ??= _load());
    final entry = _cache![strongsNumber];
    if (entry is! Map) return null;
    final n = entry['n'];
    final r = entry['r'];
    final b = entry['b'];
    if (r is! List) return null;
    final refs = <ConcordanceRef>[];
    for (final raw in r) {
      if (raw is String) {
        final parsed = ConcordanceRef.tryParse(raw);
        if (parsed != null) refs.add(parsed);
      }
    }
    final byBook = <String, int>{};
    if (b is Map) {
      for (final entry in b.entries) {
        final v = entry.value;
        if (v is int) byBook[entry.key.toString()] = v;
      }
    }
    return ConcordanceResult(
      total: n is int ? n : refs.length,
      refs: refs,
      byBook: byBook,
    );
  }
}
