import 'package:flutter/foundation.dart';

@immutable
class BibleMap {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final Map<String, List<int>> books;
  final String file;
  /// Illustration category: 'map' (default, geographic), 'scene'
  /// (narrative painting / event), 'parable' (parable illustration),
  /// 'prophecy' (apocalyptic / vision imagery), 'genealogy'.
  /// Renamed user-facing label is "Illustrations" — see ui_strings.dart.
  final String kind;

  /// 2026-05-23 (v1.2.83): asset source for the illustration file.
  /// 'asset' (default) — bundled in `assets/maps/<file>`. Used by the
  /// 55 original Bible-history maps that have always shipped with
  /// the app.
  /// 'cdn'             — hosted at the yswords-data Netlify CDN at
  /// `https://yswords-data.netlify.app/images/illustrations/<file>`.
  /// Used by the 1041 Tissot / Schnorr / etc. paintings that were
  /// previously broken (the json's `file` field was holding the
  /// upstream Wikimedia URL, so `Image.asset('assets/maps/<url>')`
  /// silently failed in every thumbnail strip).
  /// 'legacy_url'      — file is literally the upstream URL. Kept
  /// for entries whose CDN mirror failed during the migration; the
  /// full-screen viewer still works via Image.network, but the
  /// thumbnail strip's _MapThumb falls back to the broken-image icon.
  final String source;

  const BibleMap({
    required this.id,
    required this.title,
    required this.description,
    required this.books,
    required this.file,
    this.kind = 'map',
    this.source = 'asset',
  });

  factory BibleMap.fromJson(Map<String, dynamic> json) {
    final rawBooks = json['books'] as Map<String, dynamic>? ?? {};
    final books = <String, List<int>>{};
    for (final entry in rawBooks.entries) {
      final list = (entry.value as List).cast<int>();
      books[entry.key] = list;
    }

    // 2026-05-23 (v1.2.83): auto-detect legacy entries that haven't
    // been migrated yet — their `file` is still a URL. Treat as
    // 'legacy_url' so the widget can fall back to Image.network.
    final file = json['file'] as String? ?? '';
    final declaredSource = json['source'] as String?;
    final inferredSource = declaredSource ??
        (RegExp(r'^https?://', caseSensitive: false).hasMatch(file)
            ? 'legacy_url'
            : 'asset');

    return BibleMap(
      id: json['id'] as String? ?? '',
      title: (json['title'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String? ?? '')),
      description: (json['description'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String? ?? '')),
      books: books,
      file: file,
      kind: json['kind'] as String? ?? 'map',
      source: inferredSource,
    );
  }

  /// Returns true when the file is reachable from app code:
  ///   - asset → always (bundled)
  ///   - cdn   → over the network (yswords-data Netlify)
  ///   - legacy_url → over the network (Wikimedia, flaky)
  bool get hasImage => file.isNotEmpty;

  /// Fully-qualified image URL for the network-hosted variants.
  /// Asset variants return an empty string (caller should use
  /// `Image.asset(assetPath)` instead).
  String get imageUrl {
    if (source == 'cdn') {
      return 'https://yswords-data.netlify.app/images/illustrations/$file';
    }
    if (source == 'legacy_url') return file;
    return '';
  }

  /// Bundled asset path. Only valid when source == 'asset'.
  String get assetPath => 'assets/maps/$file';

  bool matchesBookChapter(String englishBook, int chapter) {
    final range = books[englishBook];
    if (range == null || range.isEmpty) return false;
    if (range.length == 1) return chapter == range[0];
    return chapter >= range[0] && chapter <= range[1];
  }

  String localizedTitle(String locale) =>
      title[locale] ?? title['en'] ?? id;

  String localizedDescription(String locale) =>
      description[locale] ?? description['en'] ?? '';
}
