import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:yswords/models/song.dart';

/// Loads and caches the songs directory from `assets/songs.json`.
///
/// Single in-memory cache — first call parses the file, every later
/// call returns the cached list. The Songs page invokes this on open
/// so the ~570 KB parse is only paid when the user actually navigates
/// there, not at boot.
class SongService {
  static List<Song>? _cache;
  static Map<String, dynamic>? _metaCache;

  static Future<List<Song>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/songs.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    _metaCache = (data['_meta'] as Map?)?.cast<String, dynamic>();
    final list = (data['songs'] as List)
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = list;
    return list;
  }

  /// Catalogue metadata (`generatedAt`, per-source counts, the
  /// attribution block). Null until [load] has run.
  static Map<String, dynamic>? get meta => _metaCache;

  /// Distinct theme tags, most-used first. Drives the theme chip row.
  static List<String> distinctThemes(List<Song> songs) {
    final counts = <String, int>{};
    for (final s in songs) {
      for (final t in s.themes) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final list = counts.keys.toList();
    list.sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return list;
  }

  /// Distinct sources in a fixed order — fydt, cahaya, cdc — rather
  /// than by frequency, so the chip row doesn't reshuffle as the
  /// catalogue grows.
  static List<String> distinctSources(List<Song> songs) {
    const order = ['fydt', 'cahaya', 'cdc'];
    final present = songs.map((s) => s.source).toSet();
    return [
      ...order.where(present.contains),
      ...present.where((s) => !order.contains(s)).toList()..sort(),
    ];
  }

  /// Distinct languages, in a fixed order for the same reason.
  static List<String> distinctLanguages(List<Song> songs) {
    const order = ['zh', 'en', 'id'];
    final present = songs.map((s) => s.language).toSet();
    return [
      ...order.where(present.contains),
      ...present.where((s) => !order.contains(s)).toList()..sort(),
    ];
  }

  /// Count per source, for the header summary line.
  static Map<String, int> countBySource(List<Song> songs) {
    final counts = <String, int>{};
    for (final s in songs) {
      counts[s.source] = (counts[s.source] ?? 0) + 1;
    }
    return counts;
  }

  /// Visible for testing — drops the cache so a test can load a
  /// different fixture.
  static void resetCacheForTest() {
    _cache = null;
    _metaCache = null;
  }
}
