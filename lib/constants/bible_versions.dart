class BibleVersionInfo {
  final String value;
  final String shortLabel;
  final String menuLabel;

  const BibleVersionInfo({
    required this.value,
    required this.shortLabel,
    required this.menuLabel,
  });
}

const bibleVersions = <BibleVersionInfo>[
  BibleVersionInfo(
    value: 'kjv',
    shortLabel: 'KJV',
    menuLabel: 'King James Version',
  ),
  BibleVersionInfo(
    value: 'leb',
    shortLabel: 'LEB',
    menuLabel: 'Lexham English Bible',
  ),
  BibleVersionInfo(
    value: 'nasb',
    shortLabel: 'NASB',
    menuLabel: 'New American Standard Bible 2020',
  ),
  BibleVersionInfo(
    value: 'niv',
    shortLabel: 'NIV',
    menuLabel: 'New International Version 2011',
  ),
  BibleVersionInfo(
    value: 'cuvs-yhwh',
    shortLabel: 'CUVS(简)',
    menuLabel: '和合本雅伟版(简体)',
  ),
  BibleVersionInfo(
    value: 'cuvs-yhwh-tr',
    shortLabel: 'CUVS(繁)',
    menuLabel: '和合本雅伟版(繁體)',
  ),
  BibleVersionInfo(
    value: 'biblexg',
    shortLabel: 'LJK1(简)',
    menuLabel: '梁家铿译本 第一版(简体)',
  ),
  BibleVersionInfo(
    value: 'biblexg-tr',
    shortLabel: 'LJK1(繁)',
    menuLabel: '梁家铿譯本 第一版(繁體)',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2',
    shortLabel: 'LJK2(简)',
    menuLabel: '梁家铿译本 第二版(简体)',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2-tr',
    shortLabel: 'LJK2(繁)',
    menuLabel: '梁家铿譯本 第二版(繁體)',
  ),
  BibleVersionInfo(
    value: 'cuv',
    shortLabel: '和合本(简)',
    menuLabel: '和合本(简体)',
  ),
  BibleVersionInfo(
    value: 'cuv-tr',
    shortLabel: '和合本(繁)',
    menuLabel: '和合本(繁體)',
  ),
  BibleVersionInfo(
    value: 'cnv',
    shortLabel: '新译本(简)',
    menuLabel: '新译本(简体)',
  ),
  BibleVersionInfo(
    value: 'cnv-tr',
    shortLabel: '新译本(繁)',
    menuLabel: '新译本(繁體)',
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
