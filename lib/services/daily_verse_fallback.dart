import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;

/// Looks up a single daily-verse reference against a *fallback* Bible
/// bundle (e.g. CUVS-YHWH) when the user's currently-selected version
/// doesn't carry the requested book.
///
/// Why this exists: LJK1 / LJK2 (梁家铿译本) ship NT only — 27 books,
/// 7,900 verses. The daily-verse rotation is full-canon
/// (3,650 references, 43% OT). When a user on LJK1 sees today's verse
/// pointing to Genesis or Psalms, the dashboard's primary lookup
/// returns null → empty verse card. This service provides the OT
/// text from a same-language full-canon bundle (CUVS-YHWH for
/// Simplified, CUVS-YHWH-TR for Traditional) so the card stays
/// populated while the rest of the app keeps the user's chosen
/// reading version.
///
/// Caches each loaded fallback bundle in memory after first read so
/// the OT-day lookup doesn't reparse a 4 MB JSON every dashboard
/// render. Cache lives for the process lifetime; bundles are static
/// Flutter assets so this is fine.
class DailyVerseFallback {
  static final Map<String, List<Verse>> _bundleCache = {};

  /// Result wrapper carrying both the resolved Verse and the version
  /// it actually came from — so the UI can show a small "displayed
  /// via 和合本雅伟版" note when the fallback fired.
  static Future<({Verse verse, String fromVersion})?> resolve({
    required String englishBook,
    required int chapter,
    required int verseNumber,
    required String currentVersion,
  }) async {
    final fallbackVersion =
        bibleVersionFullCanonFallback(currentVersion);
    if (fallbackVersion == null) return null;
    final bundle = await _loadBundle(fallbackVersion);
    if (bundle.isEmpty) return null;
    final localBook = translateBookName(englishBook, fallbackVersion);
    for (final v in bundle) {
      if (v.book == localBook &&
          v.chapter == chapter &&
          v.verse == verseNumber) {
        return (verse: v, fromVersion: fallbackVersion);
      }
    }
    return null;
  }

  /// Friendly label for the fallback version, suitable for showing
  /// on the daily-verse card ("via 和合本雅伟版(简体)").
  static String? fallbackVersionLabel(String currentVersion) {
    final fallback = bibleVersionFullCanonFallback(currentVersion);
    if (fallback == null) return null;
    final info = bibleVersions.firstWhere(
      (v) => v.value == fallback,
      orElse: () => BibleVersionInfo(
        value: fallback,
        shortLabel: fallback,
        menuLabel: fallback,
        language: 'zh-Hans',
      ),
    );
    return info.menuLabel;
  }

  /// Pre-warm the fallback bundle for [currentVersion] so the next
  /// resolve() call is instant. Optional — resolve() will load on
  /// demand anyway. Call from app startup if you want to mask the
  /// 200–500 ms first-load cost.
  static Future<void> warmUp(String currentVersion) async {
    final fallback = bibleVersionFullCanonFallback(currentVersion);
    if (fallback == null) return;
    await _loadBundle(fallback);
  }

  static Future<List<Verse>> _loadBundle(String version) async {
    final cached = _bundleCache[version];
    if (cached != null) return cached;
    try {
      final raw =
          await rootBundle.loadString('assets/$version.json');
      final decoded = json.decode(raw);
      final list = _flatten(decoded);
      final verses = list
          .whereType<Map<String, dynamic>>()
          .map(Verse.fromJson)
          .toList();
      _bundleCache[version] = verses;
      return verses;
    } catch (_) {
      _bundleCache[version] = const [];
      return const [];
    }
  }

  /// Bundle JSON appears in two shapes — flat list, or
  /// `{ "passages": [ ... ] }`. Normalize.
  static List<dynamic> _flatten(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final passages = decoded['passages'];
      if (passages is List) return passages;
      // Last-ditch: take the first List value we find.
      for (final v in decoded.values) {
        if (v is List) return v;
      }
    }
    return const [];
  }
}
