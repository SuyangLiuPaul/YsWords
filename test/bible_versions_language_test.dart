import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';

/// 2026-06-22: guards for the language-grouped version picker.
/// The picker groups the ~14 editions under English / 繁體 / 简体 tabs,
/// so the `language` metadata and the grouping helpers must stay
/// consistent with the catalog.
void main() {
  const validLanguages = {'en', 'zh-Hant', 'zh-Hans'};

  test('every available version declares a valid language', () {
    for (final v in availableVersions) {
      expect(validLanguages.contains(v.language), isTrue,
          reason: '${v.value} has invalid language "${v.language}"');
    }
  });

  test('language matches the naming convention', () {
    const english = {'kjv', 'leb', 'nasb'};
    for (final v in bibleVersions) {
      if (english.contains(v.value)) {
        expect(v.language, 'en', reason: '${v.value} should be English');
      } else if (v.value.endsWith('-tr')) {
        expect(v.language, 'zh-Hant',
            reason: '${v.value} should be Traditional');
      } else {
        expect(v.language, 'zh-Hans',
            reason: '${v.value} should be Simplified');
      }
    }
  });

  test('bibleLanguageOrder lists every language that has versions', () {
    expect(bibleLanguageOrder, ['en', 'zh-Hant', 'zh-Hans']);
    for (final lang in bibleLanguageOrder) {
      expect(versionsForLanguage(lang), isNotEmpty);
    }
  });

  test('every available version belongs to exactly one language group', () {
    final grouped = <String>[];
    for (final lang in bibleLanguageOrder) {
      grouped.addAll(versionsForLanguage(lang).map((v) => v.value));
    }
    expect(grouped.toSet(), availableVersions.map((v) => v.value).toSet());
    // No duplicates across groups.
    expect(grouped.length, grouped.toSet().length);
  });

  test('versionsForLanguage returns the expected editions', () {
    expect(versionsForLanguage('en').map((v) => v.value),
        containsAll(<String>['kjv', 'leb', 'nasb']));
    expect(versionsForLanguage('zh-Hans').map((v) => v.value),
        containsAll(<String>['cuvs-yhwh', 'biblexg-v2']));
    expect(versionsForLanguage('zh-Hant').map((v) => v.value),
        containsAll(<String>['cuvs-yhwh-tr', 'biblexg-v2-tr']));
  });

  test('cuv/cnv/biblexg(v1) are hidden from the picker but stay resolvable',
      () {
    const hidden = <String>[
      'cuv', 'cuv-tr',
      'cnv', 'cnv-tr',
      'biblexg', 'biblexg-tr',
    ];
    final availableCodes = availableVersions.map((v) => v.value).toSet();
    final allCodes = bibleVersions.map((v) => v.value).toSet();
    for (final code in hidden) {
      expect(availableCodes.contains(code), isFalse,
          reason: '$code should be hidden from the picker');
      expect(allCodes.contains(code), isTrue,
          reason: '$code should still resolve (labels/fallback/shared links)');
    }
  });

  test('bibleVersionLanguage resolves known codes + falls back safely', () {
    expect(bibleVersionLanguage('nasb'), 'en');
    expect(bibleVersionLanguage('cuvs-yhwh'), 'zh-Hans');
    expect(bibleVersionLanguage('cuvs-yhwh-tr'), 'zh-Hant');
    // Unknown code falls back to the primary audience, never throws.
    expect(bibleVersionLanguage('does-not-exist'), 'zh-Hans');
  });

  test('the locale-default versions exist in the catalog', () {
    // Mirrors MainProvider.restoreState fresh-install defaults:
    //   en → nasb, zh-Hant → cuvs-yhwh-tr, zh-Hans → cuvs-yhwh.
    final codes = bibleVersions.map((v) => v.value).toSet();
    expect(codes, containsAll(<String>['nasb', 'cuvs-yhwh-tr', 'cuvs-yhwh']));
  });
}
