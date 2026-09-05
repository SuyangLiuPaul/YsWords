import 'package:flutter/foundation.dart';

@immutable
class BibleMap {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  /// Chapter coverage per English book name, held as a LIST of
  /// inclusive `[start, end]` ranges — `{'John': [[1, 1], [14, 14]]}`
  /// means John 1 and John 14 and nothing in between.
  ///
  /// 2026-09-05: widened from a single `[start, end]` pair. The old
  /// shape could only express one solid span, so
  /// `tools/integrate_all_tissot.py` collapsed the DISCRETE chapter
  /// lists in `tissot_catalog.json` (Saint Philip → John [1, 14]) with
  /// min/max and the illustration then surfaced on all 12 chapters in
  /// between. [fromJson] accepts both on-disk forms; see there.
  final Map<String, List<List<int>>> books;
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

  /// Normalise one book's on-disk chapter value into a list of
  /// inclusive `[start, end]` ranges.
  ///
  /// Two forms are accepted, told apart by whether the FIRST element is
  /// itself a list — a flat list can never begin with a list, so the
  /// two shapes are unambiguous and no version flag is needed:
  ///
  ///   * FLAT (legacy, 1934 of the 1940 values on disk) —
  ///     `[4, 16]` → `[[4, 16]]`, the solid span 4…16, exactly what it
  ///     has always meant. `[6]` → `[[6, 6]]`, preserving the
  ///     single-element reading. A longer flat list keeps the historic
  ///     first-two-elements behaviour rather than silently changing
  ///     meaning (none exist on disk).
  ///   * NESTED (new) — `[[1, 1], [14, 14]]` → itself: a set of
  ///     disjoint spans, for discrete chapters with gaps.
  static List<List<int>> _parseRanges(List<dynamic> raw) {
    if (raw.isEmpty) return const <List<int>>[];
    if (raw.first is List) {
      final out = <List<int>>[];
      for (final r in raw) {
        if (r is! List) continue;
        final ints = r.whereType<num>().map((n) => n.toInt()).toList();
        if (ints.isEmpty) continue;
        out.add(ints.length == 1
            ? <int>[ints[0], ints[0]]
            : <int>[ints[0], ints[1]]);
      }
      return out;
    }
    final ints = raw.whereType<num>().map((n) => n.toInt()).toList();
    if (ints.isEmpty) return const <List<int>>[];
    if (ints.length == 1) {
      return <List<int>>[
        <int>[ints[0], ints[0]]
      ];
    }
    return <List<int>>[
      <int>[ints[0], ints[1]]
    ];
  }

  factory BibleMap.fromJson(Map<String, dynamic> json) {
    final rawBooks = json['books'] as Map<String, dynamic>? ?? {};
    final books = <String, List<List<int>>>{};
    for (final entry in rawBooks.entries) {
      final value = entry.value;
      if (value is! List) continue;
      books[entry.key] = _parseRanges(value);
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

  /// True when [chapter] of [englishBook] falls inside ANY of the
  /// book's ranges. A single `[start, end]` range behaves exactly as it
  /// did before the 2026-09-05 widening, so the 1934 flat entries match
  /// identically; a multi-range value no longer matches the gaps.
  bool matchesBookChapter(String englishBook, int chapter) {
    final ranges = books[englishBook];
    if (ranges == null || ranges.isEmpty) return false;
    for (final range in ranges) {
      if (range.isEmpty) continue;
      // A 1-element range means that single chapter. [fromJson] never
      // produces one, but BibleMap is const-constructible directly, so
      // the old `range.length == 1` reading is kept rather than let
      // `[6]` silently start matching nothing.
      if (range.length == 1) {
        if (chapter == range[0]) return true;
        continue;
      }
      if (chapter >= range[0] && chapter <= range[1]) return true;
    }
    return false;
  }

  String localizedTitle(String locale) =>
      title[locale] ?? title['en'] ?? id;

  String localizedDescription(String locale) =>
      description[locale] ?? description['en'] ?? '';
}
