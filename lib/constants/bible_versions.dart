class BibleVersionInfo {
  final String value;
  final String shortLabel;
  final String menuLabel;

  /// 2026-08-02 (v1.3.160): fallback label for the top-bar version
  /// pill on narrow screens (< 390 px, same breakpoint the book/
  /// chapter title already uses). Only set for editions whose
  /// [shortLabel] is long enough to visibly truncate inside the pill
  /// at that width (currently just 和合本雅伟版) — everything else
  /// falls back to [shortLabel] itself via [narrowChipLabel].
  final String? narrowLabel;

  /// 2026-06-22: which language family this edition belongs to, so the
  /// version picker can group the ~14 editions under English / 繁體 /
  /// 简体 tabs instead of one long flat list. Values match the app
  /// locale codes: `en`, `zh-Hant`, `zh-Hans`.
  final String language;

  /// Round 56 user feedback: "和合本新译本should mention which year
  /// version". Year / edition info shown in the version-picker
  /// secondary line so the reader knows which published edition the
  /// asset corresponds to (1919 vs 1989 CUV; 1992 vs 2011 CNV; etc.).
  /// Empty string when not applicable / unknown.
  final String editionYear;

  const BibleVersionInfo({
    required this.value,
    required this.shortLabel,
    required this.menuLabel,
    required this.language,
    this.editionYear = '',
    this.narrowLabel,
  });
}

const bibleVersions = <BibleVersionInfo>[
  BibleVersionInfo(
    value: 'kjv',
    shortLabel: 'KJV',
    menuLabel: 'King James Version',
    language: 'en',
    editionYear: '1611 / 1769 revision',
  ),
  BibleVersionInfo(
    value: 'leb',
    shortLabel: 'LEB',
    menuLabel: 'Lexham English Bible',
    language: 'en',
    editionYear: '2012',
  ),
  BibleVersionInfo(
    value: 'nasb',
    shortLabel: 'NASB',
    menuLabel: 'New American Standard Bible',
    language: 'en',
    editionYear: '2020 update',
  ),
  // NIV (New International Version) was previously listed here.
  // Removed in 2026-05 — Biblica / Zondervan retain commercial
  // copyright on the full text and we cannot redistribute the bundled
  // JSON without an explicit publisher licence. Users seeking NIV
  // should follow Bible Gateway / YouVersion. The asset file
  // `assets/niv.json` was also removed in the same change.
  BibleVersionInfo(
    value: 'cuvs-yhwh',
    // 2026-08-02 (v1.3.157): was 'CUVS(简)' — user asked for Chinese
    // versions to show Chinese labels instead of the Latin
    // abbreviation, for both the Simplified and Traditional edition
    // ("中文应该用中文的，繁体也是两个版本").
    // 2026-08-02 (v1.3.159): dropped the "(简)" suffix — user pointed
    // out the simplified/traditional characters themselves already
    // make that obvious ("看字就知道") — and switched to the fuller
    // "和合本雅伟版" name instead of the shortened "雅伟版".
    shortLabel: '和合本雅伟版',
    menuLabel: '和合本雅伟版(简体)',
    language: 'zh-Hans',
    editionYear: '基于和合本 1919 / 现代标点 1989',
    // 2026-08-02 (v1.3.160): "和合本雅伟版" truncates inside the top-bar
    // pill on narrow phones — falls back to the shorter "雅伟版" there.
    narrowLabel: '雅伟版',
  ),
  BibleVersionInfo(
    value: 'cuvs-yhwh-tr',
    shortLabel: '和合本雅偉版',
    menuLabel: '和合本雅伟版(繁體)',
    language: 'zh-Hant',
    editionYear: '基於和合本 1919 / 現代標點 1989',
    narrowLabel: '雅偉版',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2',
    shortLabel: '梁家铿(简)',
    menuLabel: '梁家铿译本(简体)',
    language: 'zh-Hans',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2-tr',
    shortLabel: '梁家铿(繁)',
    menuLabel: '梁家铿譯本(繁體)',
    language: 'zh-Hant',
  ),
];

/// Versions hidden from the picker (currently none — CUV, CNV, and
/// LJK1 were removed outright in 2026-08 rather than hidden; see
/// git history for the rationale). Kept as a mechanism in case a
/// future edition needs to be superseded without breaking old
/// shared links.
const disabledVersions = <String>{};

/// Versions shown in the picker (excludes disabled ones).
List<BibleVersionInfo> get availableVersions =>
    bibleVersions.where((v) => !disabledVersions.contains(v.value)).toList();

/// The order languages appear in the version picker's language selector.
/// English first, then Traditional, then Simplified — matches the way
/// the user phrased it ("英语繁体简体"). Only languages that actually have
/// at least one available version are kept (defensive against a future
/// all-disabled language).
List<String> get bibleLanguageOrder {
  const order = ['en', 'zh-Hant', 'zh-Hans'];
  final present = availableVersions.map((v) => v.language).toSet();
  return order.where(present.contains).toList();
}

/// The available versions belonging to [language] (`en` / `zh-Hant` /
/// `zh-Hans`), in catalog order.
List<BibleVersionInfo> versionsForLanguage(String language) =>
    availableVersions.where((v) => v.language == language).toList();

/// The language family (`en` / `zh-Hant` / `zh-Hans`) of a version code.
/// Falls back to `zh-Hans` for an unknown code (the app's primary
/// audience) so the picker never lands on an empty tab.
String bibleVersionLanguage(String value) {
  for (final v in bibleVersions) {
    if (v.value == value) return v.language;
  }
  return 'zh-Hans';
}

String shortBibleVersionLabel(String version) {
  return bibleVersions
      .firstWhere(
        (item) => item.value == version,
        orElse: () => BibleVersionInfo(
          value: version,
          shortLabel: version,
          menuLabel: version,
          language: 'zh-Hans',
        ),
      )
      .shortLabel;
}

/// 2026-08-02 (v1.3.160): narrow-screen variant of
/// [shortBibleVersionLabel] — mirrors the book/chapter title's own
/// `screenW < 390` short-name fallback, so the version pill in the
/// reading-pane header never truncates on a phone-width screen. Falls
/// back to [shortBibleVersionLabel] itself for every edition that
/// doesn't define a [BibleVersionInfo.narrowLabel].
String narrowBibleVersionLabel(String version) {
  final info = bibleVersions.firstWhere(
    (item) => item.value == version,
    orElse: () => BibleVersionInfo(
      value: version,
      shortLabel: version,
      menuLabel: version,
      language: 'zh-Hans',
    ),
  );
  return info.narrowLabel ?? info.shortLabel;
}

/// Some bundled versions only ship one Testament — most notably the
/// LJK2 (梁家铿译本) editions are NT-only because the translator's OT
/// work isn't published yet. When the daily-verse lookup hits a book
/// that doesn't exist in those bundles, we fall back to a
/// same-language full-canon bundle instead of showing an empty
/// daily-verse card.
///
/// Returns the version code to fall back to, or null when [version]
/// already has full OT+NT coverage.
String? bibleVersionFullCanonFallback(String version) {
  switch (version) {
    case 'biblexg-v2':    // LJK2 (Simplified Chinese, NT only)
      return 'cuvs-yhwh';      // 和合本雅伟版 (Simplified, full canon)
    case 'biblexg-v2-tr': // LJK2 (Traditional Chinese, NT only)
      return 'cuvs-yhwh-tr';   // 和合本雅伟版 (Traditional, full canon)
  }
  return null;
}
