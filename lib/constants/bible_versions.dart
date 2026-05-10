class BibleVersionInfo {
  final String value;
  final String shortLabel;
  final String menuLabel;
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
    this.editionYear = '',
  });
}

const bibleVersions = <BibleVersionInfo>[
  BibleVersionInfo(
    value: 'kjv',
    shortLabel: 'KJV',
    menuLabel: 'King James Version',
    editionYear: '1611 / 1769 revision',
  ),
  BibleVersionInfo(
    value: 'leb',
    shortLabel: 'LEB',
    menuLabel: 'Lexham English Bible',
    editionYear: '2012',
  ),
  BibleVersionInfo(
    value: 'nasb',
    shortLabel: 'NASB',
    menuLabel: 'New American Standard Bible',
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
    editionYear: '基于和合本 1919 / 现代标点 1989',
  ),
  BibleVersionInfo(
    value: 'cuvs-yhwh-tr',
    shortLabel: 'CUVS(繁)',
    menuLabel: '和合本雅伟版(繁體)',
    editionYear: '基於和合本 1919 / 現代標點 1989',
  ),
  BibleVersionInfo(
    value: 'biblexg',
    shortLabel: 'LJK1(简)',
    menuLabel: '梁家铿译本 第一版(简体)',
    editionYear: '第一版',
  ),
  BibleVersionInfo(
    value: 'biblexg-tr',
    shortLabel: 'LJK1(繁)',
    menuLabel: '梁家铿譯本 第一版(繁體)',
    editionYear: '第一版',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2',
    shortLabel: 'LJK2(简)',
    menuLabel: '梁家铿译本 第二版(简体)',
    editionYear: '第二版',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2-tr',
    shortLabel: 'LJK2(繁)',
    menuLabel: '梁家铿譯本 第二版(繁體)',
    editionYear: '第二版',
  ),
  BibleVersionInfo(
    value: 'cuv',
    shortLabel: '和合本(简)',
    menuLabel: '和合本(简体)',
    editionYear: '1919 / 现代标点 1989',
  ),
  BibleVersionInfo(
    value: 'cuv-tr',
    shortLabel: '和合本(繁)',
    menuLabel: '和合本(繁體)',
    editionYear: '1919 / 現代標點 1989',
  ),
  BibleVersionInfo(
    value: 'cnv',
    shortLabel: '新译本·雅伟',
    menuLabel: '新译本（简体·雅伟版）',
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
    editionYear: '基於新譯本 1992 / 三版 2011',
  ),
];

/// Versions that have placeholder data only — hidden from the picker.
const disabledVersions = <String>{};

/// Versions shown in the picker (excludes disabled ones).
List<BibleVersionInfo> get availableVersions =>
    bibleVersions.where((v) => !disabledVersions.contains(v.value)).toList();

String shortBibleVersionLabel(String version) {
  return bibleVersions
      .firstWhere(
        (item) => item.value == version,
        orElse: () => BibleVersionInfo(
          value: version,
          shortLabel: version,
          menuLabel: version,
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
