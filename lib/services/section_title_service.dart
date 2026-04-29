import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:yswords/constants/section_title_map.dart';

/// One row from `assets/section_titles.json` — title + optional
/// `context` (a short paragraph of historical / theological
/// background rendered under the heading in the reading pane).
class SectionHeading {
  final String title;
  final String? context;
  const SectionHeading({required this.title, this.context});
}

/// Section / paragraph titles bundled at `assets/section_titles.json`.
/// One asset, multiple title-sets (cuv / cuv-tr / english-classic /
/// future cnv), wired via `lib/constants/section_title_map.dart`.
///
/// Lazy-loaded once on first lookup. Single in-memory cache shared
/// across reading-pane calls; deep enough that even tight loops over
/// every verse are O(1) lookups.
class SectionTitleService {
  /// Two-level index: setId → "Book/chapter/verse" → SectionHeading.
  static Map<String, Map<String, SectionHeading>>? _cache;
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
      final out = <String, Map<String, SectionHeading>>{};
      if (sets != null) {
        sets.forEach((setId, books) {
          final flat = <String, SectionHeading>{};
          if (books is Map<String, dynamic>) {
            books.forEach((book, chapters) {
              if (chapters is Map<String, dynamic>) {
                chapters.forEach((chapter, entries) {
                  if (entries is List) {
                    for (final e in entries) {
                      if (e is Map &&
                          e['verse'] is num &&
                          e['title'] is String) {
                        final ctx = e['context'];
                        flat['$book/$chapter/${(e['verse'] as num).toInt()}'] =
                            SectionHeading(
                          title: e['title'] as String,
                          context: ctx is String && ctx.isNotEmpty
                              ? ctx
                              : null,
                        );
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

  /// Returns the section heading for the verse at
  /// (`englishBook`, `chapter`, `verse`) under [version], or null if
  /// no heading is configured for that exact verse.
  ///
  /// Looks up the version's primary title set; on miss, consults the
  /// fallback set (CNV → CUV).
  static SectionHeading? headingAt({
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

  /// Convenience for callers that only want the title text.
  static String? titleAt({
    required String version,
    required String englishBook,
    required int chapter,
    required int verse,
  }) =>
      headingAt(
        version: version,
        englishBook: englishBook,
        chapter: chapter,
        verse: verse,
      )?.title;

  /// Test-only — clears the cache so a hot-restart picks up edits to
  /// the asset.
  @visibleForTesting
  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
