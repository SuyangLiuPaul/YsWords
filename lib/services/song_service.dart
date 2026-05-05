import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:yswords/models/song.dart';

/// Loads and caches the songs directory from `assets/songs.json`.
///
/// Single in-memory cache — first call parses the file, every later
/// call returns the cached list. The Songs page invokes this on open
/// so the cost is only paid when the user actually navigates there.
class SongService {
  static List<Song>? _cache;

  static Future<List<Song>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/songs.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = (data['songs'] as List)
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = list;
    return list;
  }

  /// Distinct theme tags across the corpus, sorted by descending
  /// frequency (most-used theme first). Drives the filter chip row.
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
}
