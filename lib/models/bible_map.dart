import 'package:flutter/foundation.dart';

/// Per-illustration rights record — who owns the picture, under what
/// licence, where it came from, and whether this app altered it.
///
/// 2026-09-06. Why this is a field on the data and not a line on the
/// About page: 40 of the 1192 entries in `assets/maps_index.json` are
/// Sweet Publishing / Jim Padgett illustrations that carry a LIVE
/// copyleft obligation, and the app was meeting none of it — the
/// generator that fetched them recorded no licence at all, and About
/// carried one generic sentence for all 1192. A sentence on a page can
/// be true today and silently wrong after the next import; a required
/// field on the entry cannot.
///
/// **Everything here was read off the Wikimedia Commons file pages on
/// 2026-09-06** (API `extmetadata` plus the raw wikitext of the file
/// pages) — not inferred, not remembered. All 40 are uniform:
/// `{{Bible Illustrations (Sweet Publishing)-license}}`, which expands
/// to `{{cc-by-sa-3.0|Distant Shores Media/Sweet Publishing}}`, with
/// `Author={{Creator:Jim Padgett}}` and `Date=1984`.
///
/// Absence of a rights block is NOT a claim of public domain. The other
/// 1152 entries (Doré, Schnorr, Tissot, Rembrandt) are believed public
/// domain by age but their file pages were not individually checked, so
/// they carry no rights block rather than an unverified assertion —
/// `test/illustration_rights_test.dart` holds them on a frozen
/// allowlist so a NEW entry cannot join them by accident.
@immutable
class MapRights {
  /// Title of the work as the source names it. CC BY-SA 3.0 §4(c) asks
  /// for the title, so it is stored even though the app shows its own.
  final String title;

  /// The human who made it. Distinct from [holder]: Commons splits
  /// `Artist` (Jim Padgett) from `Attribution` (Distant Shores
  /// Media/Sweet Publishing) and the licence wants both named.
  final String author;

  /// The party the licensor asks to be credited.
  final String holder;

  /// The URI the licensor specifies for the credit. Stored because
  /// CC BY-SA 3.0 §4(c) names it; **not rendered as a link** — it did
  /// not respond from this machine on 2026-09-06, and this machine has
  /// known egress restrictions (PROJECT_STATE trap 7), so "dead" is not
  /// established. A link that may be dead is worse in an attribution
  /// than no link; [sourceUrl] and [licenseUrl] both answered 200.
  final String holderUrl;

  final String year;

  /// The rights holder's own credit sentence, verbatim.
  final String credit;

  /// Short licence name, e.g. 'CC BY-SA 3.0'.
  final String license;

  /// The deed's own title, e.g. 'Attribution-ShareAlike 3.0 Unported'.
  final String licenseFullName;

  /// Link to the licence deed. Required by the licence itself.
  final String licenseUrl;

  /// True when the licence makes credit a condition, not a courtesy.
  final bool attributionRequired;

  /// True when derivatives must carry the same licence.
  final bool shareAlike;

  /// The source the work was taken from — the file page, not the image
  /// bytes, so a reader can reach the licence statement itself.
  final String sourceUrl;

  /// Localised statement of whether this app changed the work.
  /// CC BY-SA 3.0 requires indicating if changes were made, and the
  /// honest answer here has two clauses rather than a yes or a no: the
  /// bytes this app redistributes are SHA-256 identical to the Commons
  /// originals (checked, 40 of 40, 2026-09-06), while the thumbnail
  /// call sites draw them `BoxFit.cover` at 220 px and 88x88, which
  /// visibly crops an 831x610 frame. Saying "not modified" is true of
  /// the file and false to the eye; saying "modified" misdescribes what
  /// is distributed. So both clauses are stated.
  final Map<String, String> modification;

  /// When and how these values were established.
  final String verified;

  const MapRights({
    required this.title,
    required this.author,
    required this.holder,
    required this.holderUrl,
    required this.year,
    required this.credit,
    required this.license,
    required this.licenseFullName,
    required this.licenseUrl,
    required this.attributionRequired,
    required this.shareAlike,
    required this.sourceUrl,
    required this.modification,
    required this.verified,
  });

  static MapRights? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    String s(String k) => json[k] as String? ?? '';
    return MapRights(
      title: s('title'),
      author: s('author'),
      holder: s('holder'),
      holderUrl: s('holderUrl'),
      year: s('year'),
      credit: s('credit'),
      license: s('license'),
      licenseFullName: s('licenseFullName'),
      licenseUrl: s('licenseUrl'),
      attributionRequired: json['attributionRequired'] == true,
      shareAlike: json['shareAlike'] == true,
      sourceUrl: s('sourceUrl'),
      modification: (json['modification'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String? ?? '')),
      verified: s('verified'),
    );
  }

  String localizedModification(String locale) =>
      modification[locale] ?? modification['en'] ?? '';

  /// The one-line credit this app owes: author, holder, licence.
  /// Deliberately not localised — names and licence identifiers are
  /// not translated.
  String get creditLine => '$author / $holder · $license';

  /// Two entries that owe the same credit collapse to one row on the
  /// About page. Keyed on everything a reader would see.
  String get attributionKey =>
      '$author|$holder|$license|$licenseUrl|${modification['en']}';
}

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

  /// Rights record for this illustration, or null when none has been
  /// established. **Null is not a public-domain claim** — see
  /// [MapRights].
  final MapRights? rights;

  const BibleMap({
    required this.id,
    required this.title,
    required this.description,
    required this.books,
    required this.file,
    this.kind = 'map',
    this.source = 'asset',
    this.rights,
  });

  /// True when this entry carries a licence whose credit is a
  /// condition of use rather than a courtesy.
  bool get requiresAttribution => rights?.attributionRequired ?? false;

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
      rights: MapRights.fromJson(json['rights'] as Map<String, dynamic>?),
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
