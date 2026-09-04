import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';

/// 2026-06-22: guards for the language-grouped version picker.
/// The picker groups the ~14 editions under English / 繁體 / 简体 tabs,
/// so the `language` metadata and the grouping helpers must stay
/// consistent with the catalog.
void main() {
  const validLanguages = {'en', 'zh-Hant', 'zh-Hans'};

  // 2026-08-09: the 梁家铿 rows shipped with no narrowLabel, so the
  // top-bar pill cut them to "梁家…" on a phone — and BOTH rows cut to
  // the SAME string, destroying the 简/繁 distinction that is the only
  // thing telling them apart. The 雅伟版 rows had carried a narrowLabel
  // since v1.3.160 for the same reason; nothing enforced that the next
  // Chinese edition would.
  group('narrow-screen labels stay narrow, and stay distinct', () {
    // Four CJK characters overflow the pill at 390 px; three is the
    // longest that survives, which is what 雅伟版 already uses.
    const maxNarrowChars = 3;

    test('every Chinese edition has a narrow label that actually fits', () {
      for (final v in availableVersions.where((v) => v.language != 'en')) {
        final narrow = narrowBibleVersionLabel(v.value);
        // runes, not `length`: every one of these labels is CJK, where
        // `String.length` counts UTF-16 units rather than characters.
        expect(narrow.runes.length, lessThanOrEqualTo(maxNarrowChars),
            reason: '${v.value} narrows to "$narrow" — too long for the '
                'pill, so it will render truncated with an ellipsis');
      }
    });

    test('no two editions narrow to the same label', () {
      final seen = <String, String>{};
      for (final v in availableVersions.where((v) => v.language != 'en')) {
        final narrow = narrowBibleVersionLabel(v.value);
        expect(seen.containsKey(narrow), isFalse,
            reason: '${v.value} and ${seen[narrow]} both narrow to '
                '"$narrow" — the reader cannot tell them apart');
        seen[narrow] = v.value;
      }
    });

    test('梁家铿 narrows to 梁简 / 梁繁, not 梁家…', () {
      expect(narrowBibleVersionLabel('biblexg-v2'), '梁简');
      expect(narrowBibleVersionLabel('biblexg-v2-tr'), '梁繁');
      // The wide labels are deliberately unchanged — they are correct
      // when there is room for them.
      expect(shortBibleVersionLabel('biblexg-v2'), '梁家铿(简)');
      expect(shortBibleVersionLabel('biblexg-v2-tr'), '梁家鏗(繁)');
    });
  });

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
    // 2026-09-04: 'nasb' left this list because it is now in
    // `disabledVersions` and offered on no platform. The catalogue entry
    // still exists — see test/nasb_hidden_test.dart, which pins both
    // halves of that (hidden from the picker, still resolvable so an old
    // stored preference lands on the KJV rather than on nothing).
    expect(versionsForLanguage('en').map((v) => v.value),
        containsAll(<String>['kjv', 'leb']));
    expect(versionsForLanguage('en').map((v) => v.value),
        isNot(contains('nasb')));
    expect(versionsForLanguage('zh-Hans').map((v) => v.value),
        containsAll(<String>['cuvs-yhwh', 'biblexg-v2']));
    expect(versionsForLanguage('zh-Hant').map((v) => v.value),
        containsAll(<String>['cuvs-yhwh-tr', 'biblexg-v2-tr']));
  });

  test('bibleVersionLanguage resolves known codes + falls back safely', () {
    expect(bibleVersionLanguage('nasb'), 'en');
    expect(bibleVersionLanguage('cuvs-yhwh'), 'zh-Hans');
    expect(bibleVersionLanguage('cuvs-yhwh-tr'), 'zh-Hant');
    // Unknown code falls back to the primary audience, never throws.
    expect(bibleVersionLanguage('does-not-exist'), 'zh-Hans');
  });

  test('no zh-Hant label contains a Simplified character', () {
    // Three of them did, for months, in the one place a reader would
    // actually look: 和合本雅伟版(繁體), 梁家铿(繁), 梁家铿譯本(繁體) — the
    // 繁體 marker spelled out in full, with the name in front of it left
    // Simplified. Each row's own shortLabel or About-page equivalent was
    // already correct, so nothing looked broken; the rows just quietly
    // disagreed with themselves. Fixed 2026-08-31, when the prerendered
    // /read/ pages were about to print them on 1,256 crawlable
    // Traditional page titles per edition.
    //
    // The pair table is explicit rather than derived: this app ships no
    // general simp→trad converter (that lives in the Python asset
    // scripts), and this guard only has to cover the vocabulary edition
    // names are built from. Add a pair when a new edition needs one.
    const simplifiedToTraditional = {
      '伟': '偉', // 雅伟版
      '铿': '鏗', // 梁家铿
      '译': '譯', // 译本
      '简': '簡', // 简体
      '体': '體', // 繁体
      '华': '華',
      '书': '書',
      '汉': '漢',
      '标': '標', // 新标点
      '点': '點',
    };

    for (final v in bibleVersions.where((v) => v.language == 'zh-Hant')) {
      final labels = <String, String>{
        'shortLabel': v.shortLabel,
        'menuLabel': v.menuLabel,
        if (v.narrowLabel != null) 'narrowLabel': v.narrowLabel!,
      };
      labels.forEach((field, text) {
        for (final entry in simplifiedToTraditional.entries) {
          expect(text.contains(entry.key), isFalse,
              reason: '${v.value}.$field is "$text" — "${entry.key}" is '
                  'Simplified inside a Traditional label; '
                  'use "${entry.value}"');
        }
      });
    }
  });

  test('the locale-default versions exist in the catalog', () {
    // Mirrors MainProvider.restoreState fresh-install defaults:
    //   en → nasb, zh-Hant → cuvs-yhwh-tr, zh-Hans → cuvs-yhwh.
    final codes = bibleVersions.map((v) => v.value).toSet();
    expect(codes, containsAll(<String>['nasb', 'cuvs-yhwh-tr', 'cuvs-yhwh']));
  });
}
