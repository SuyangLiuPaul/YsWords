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
const disabledVersions = {'nasb', 'niv'};

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
