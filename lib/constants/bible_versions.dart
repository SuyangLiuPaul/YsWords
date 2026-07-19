class BibleVersionInfo {
  final String value;
  final String shortLabel;
  final String menuLabel;

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
    shortLabel: 'CUVS(简)',
    menuLabel: '和合本雅伟版(简体)',
    language: 'zh-Hans',
    editionYear: '基于和合本 1919 / 现代标点 1989',
  ),
  BibleVersionInfo(
    value: 'cuvs-yhwh-tr',
    shortLabel: 'CUVS(繁)',
    menuLabel: '和合本雅伟版(繁體)',
    language: 'zh-Hant',
    editionYear: '基於和合本 1919 / 現代標點 1989',
  ),
  BibleVersionInfo(
    value: 'biblexg',
    shortLabel: 'LJK1(简)',
    menuLabel: '梁家铿译本 第一版(简体)',
    language: 'zh-Hans',
    editionYear: '第一版',
  ),
  BibleVersionInfo(
    value: 'biblexg-tr',
    shortLabel: 'LJK1(繁)',
    menuLabel: '梁家铿譯本 第一版(繁體)',
    language: 'zh-Hant',
    editionYear: '第一版',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2',
    shortLabel: 'LJK(简)',
    menuLabel: '梁家铿译本(简体)',
    language: 'zh-Hans',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2-tr',
    shortLabel: 'LJK(繁)',
    menuLabel: '梁家铿譯本(繁體)',
    language: 'zh-Hant',
  ),
  BibleVersionInfo(
    value: 'cuv',
    shortLabel: '和合本(简)',
    menuLabel: '和合本(简体)',
    language: 'zh-Hans',
    editionYear: '1919 / 现代标点 1989',
  ),
  BibleVersionInfo(
    value: 'cuv-tr',
    shortLabel: '和合本(繁)',
    menuLabel: '和合本(繁體)',
    language: 'zh-Hant',
    editionYear: '1919 / 現代標點 1989',
  ),
  BibleVersionInfo(
    value: 'cnv',
    shortLabel: '新译本·雅伟',
    menuLabel: '新译本（简体·雅伟版）',
    language: 'zh-Hans',
    editionYear: '基于新译本 1992 / 三版 2011',
  ),
  BibleVersionInfo(
    value: 'cnv-tr',
    // 2026-05-10 (v1.2.33): 雅威 → 雅偉. Project canonical
    // simp→trad pairing is 雅伟 → 雅偉; historical mistake using
    // 雅威 (might) instead of 雅偉 (great). User reported
    // "很多地方寫雅威但是需要雅偉".
    shortLabel: '新譯本·雅偉',
    menuLabel: '新譯本（繁體·雅偉版）',
    language: 'zh-Hant',
    editionYear: '基於新譯本 1992 / 三版 2011',
  ),
];

/// Versions hidden from the picker. `biblexg`/`biblexg-tr` (LJK1, the
/// first edition of 梁家铿译本) are superseded by the v2 edition and
/// kept only as a fallback source; `cuv`/`cuv-tr`/`cnv`/`cnv-tr` are
/// hidden in favour of `cuvs-yhwh`/`cuvs-yhwh-tr`. All remain in
/// [bibleVersions] (not deleted) so label lookups, the
/// full-canon-fallback chain, and shared-link version codes for
/// existing readers keep working.
const disabledVersions = <String>{
  'cuv', 'cuv-tr',
  'cnv', 'cnv-tr',
  'biblexg', 'biblexg-tr',
};

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

/// Some bundled versions only ship one Testament — most notably the
/// LJK1 / LJK2 (梁家铿译本) editions are NT-only because the
/// translator's OT work isn't published yet.  When the daily-verse
/// lookup hits a book that doesn't exist in those bundles (e.g. an
/// OT reference for a user reading on LJK1), we fall back to a
/// same-language full-canon bundle instead of showing an empty
/// daily-verse card.
///
/// Returns the version code to fall back to, or null when [version]
/// already has full OT+NT coverage.
String? bibleVersionFullCanonFallback(String version) {
  switch (version) {
    case 'biblexg':       // LJK1 (Simplified Chinese, NT only)
    case 'biblexg-v2':    // LJK2 (Simplified Chinese, NT only)
      return 'cuvs-yhwh';      // 和合本雅伟版 (Simplified, full canon)
    case 'biblexg-tr':    // LJK1 (Traditional Chinese, NT only)
    case 'biblexg-v2-tr': // LJK2 (Traditional Chinese, NT only)
      return 'cuvs-yhwh-tr';   // 和合本雅伟版 (Traditional, full canon)
  }
  return null;
}
