import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:yswords/constants/section_title_map.dart';

/// Section / paragraph titles bundled at `assets/section_titles.json`.
/// One asset, multiple title-sets (cuv / cuv-tr / english-classic /
/// future cnv), wired via `lib/constants/section_title_map.dart`.
///
/// Lazy-loaded once on first lookup. Single in-memory cache shared
/// across reading-pane calls; deep enough that even tight loops over
/// every verse are O(1) lookups.
class SectionTitleService {
  /// Two-level index: setId → "Book/chapter/verse" → title.
  static Map<String, Map<String, String>>? _cache;
  static Future<void>? _loadFuture;

  /// Trigger the asset load. Idempotent. The reading pane calls this
  /// from `initState` so the first chapter render already has data.
  static Future<void> ensureLoaded() {
    if (_cache != null) return Future.value();
    return _loadFuture ??= _doLoad();
  }

  static Future<void> _doLoad() async {
    try {
      final raw = await rootBundle.loadString('assets/section_titles.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final sets = decoded['sets'] as Map<String, dynamic>?;
      final out = <String, Map<String, String>>{};
      if (sets != null) {
        sets.forEach((setId, books) {
          final flat = <String, String>{};
          if (books is Map<String, dynamic>) {
            books.forEach((book, chapters) {
              if (chapters is Map<String, dynamic>) {
                chapters.forEach((chapter, entries) {
                  if (entries is List) {
                    for (final e in entries) {
                      if (e is Map &&
                          e['verse'] is num &&
                          e['title'] is String) {
                        flat['$book/$chapter/${(e['verse'] as num).toInt()}'] =
                            e['title'] as String;
                      }
                    }
                  }
                });
              }
            });
          }
          out[setId] = flat;
        });
      }
      _cache = out;
    } catch (e, st) {
      debugPrint('SectionTitleService load failed: $e\n$st');
      _cache = const {}; // soft-fail; lookups return null below
    } finally {
      _loadFuture = null;
    }
  }

  /// Returns the section-heading text for the verse at
  /// (`englishBook`, `chapter`, `verse`) under [version], or null if
  /// no heading is configured for that exact verse.
  ///
  /// Looks up the version's primary title set; on miss, consults the
  /// fallback set (CNV → CUV).
  static String? titleAt({
    required String version,
    required String englishBook,
    required int chapter,
    required int verse,
  }) {
    final cache = _cache;
    if (cache == null) return null;
    final primarySet = sectionTitleSetFor(version);
    if (primarySet.isEmpty) return null;
    final key = '$englishBook/$chapter/$verse';
    final hit = cache[primarySet]?[key];
    if (hit != null) return hit;
    final fallbackSet = sectionTitleFallbackFor(primarySet);
    if (fallbackSet == null) return null;
    return cache[fallbackSet]?[key];
  }

  /// Test-only — clears the cache so a hot-restart picks up edits to
  /// the asset.
  @visibleForTesting
  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
