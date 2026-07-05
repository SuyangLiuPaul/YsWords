import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/constants/spiritual_giant_categories.dart';
import 'package:yswords/models/spiritual_giant.dart';

/// Loads and caches the 属灵伟人小传 / Spiritual Giants corpus from
/// `assets/spiritual_giants.json`.
///
/// The whole corpus (35 figures × 3 languages of short biographies) is
/// a single bundled JSON, parsed once on first visit to the list page
/// and cached for the process lifetime. No per-figure lazy loading is
/// needed because each biography is only ~110 words.
class SpiritualGiantService {
  SpiritualGiantService._();
  static final SpiritualGiantService instance = SpiritualGiantService._();

  List<SpiritualGiant>? _index;

  /// Parse the bundled JSON on first call; O(1) thereafter.
  Future<List<SpiritualGiant>> loadIndex() async {
    if (_index != null) return _index!;
    final raw = await rootBundle.loadString('assets/spiritual_giants.json');
    final decoded = json.decode(raw);
    // Accept either a bare array or an object with a `figures` array so
    // the file can carry top-level metadata later without breaking.
    final list = decoded is Map<String, dynamic>
        ? (decoded['figures'] as List<dynamic>? ?? const [])
        : decoded as List<dynamic>;
    _index = list
        .whereType<Map<String, dynamic>>()
        .map(SpiritualGiant.fromJson)
        .toList();
    return _index!;
  }

  /// One figure by id, or null when absent (used by deep links / the
  /// dashboard "continue reading" hero if we add one later).
  Future<SpiritualGiant?> byId(String id) async {
    final all = await loadIndex();
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Group the index by category, ordered by [giantCategoryOrder].
  /// Categories with no figures are omitted; any figure whose category
  /// is unknown lands in a trailing group under its raw id so nothing
  /// is silently dropped.
  Future<Map<String, List<SpiritualGiant>>> loadByCategory() async {
    final all = await loadIndex();
    final byCat = <String, List<SpiritualGiant>>{};
    for (final g in all) {
      byCat.putIfAbsent(g.category, () => <SpiritualGiant>[]).add(g);
    }
    final ordered = <String, List<SpiritualGiant>>{};
    for (final cat in giantCategoryOrder) {
      final list = byCat.remove(cat);
      if (list != null && list.isNotEmpty) ordered[cat] = list;
    }
    // Any leftover (unknown) categories, in first-seen order.
    for (final entry in byCat.entries) {
      if (entry.value.isNotEmpty) ordered[entry.key] = entry.value;
    }
    return ordered;
  }
}
