import 'dart:convert';
import 'package:flutter/services.dart';

/// Result of a concordance lookup for one Strong's number.
///
/// `total` is the absolute occurrence count across the entire Bible
/// (counted by the build pipeline before any cap is applied), so the UI
/// can show "Used 19,859 times" even when the bundled list itself is
/// truncated. `refs` are English-name verse strings like "John 3:16",
/// canonical-order sorted, capped at the pipeline's per-entry limit.
class ConcordanceResult {
  final int total;
  final List<ConcordanceRef> refs;
  const ConcordanceResult({required this.total, required this.refs});
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

  static Future<ConcordanceResult?> lookup(String strongsNumber) async {
    if (strongsNumber.isEmpty) return null;
    _cache ??= await (_loading ??= _load());
    final entry = _cache![strongsNumber];
    if (entry is! Map) return null;
    final n = entry['n'];
    final r = entry['r'];
    if (r is! List) return null;
    final refs = <ConcordanceRef>[];
    for (final raw in r) {
      if (raw is String) {
        final parsed = ConcordanceRef.tryParse(raw);
        if (parsed != null) refs.add(parsed);
      }
    }
    return ConcordanceResult(
      total: n is int ? n : refs.length,
      refs: refs,
    );
  }
}
