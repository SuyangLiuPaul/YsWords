// 2026-09-09: both Greek editions are hidden from the picker, on the
// owner's word — 「words 其实希腊语可以 hidden 的」.
//
// `wh` (Westcott-Hort NT, 1881) and `lxx` (the Septuagint) are the only
// two `el` rows in the catalogue, so hiding them removes the fourth
// language tab entirely. That is the point: this is the app people READ
// in, and 雅伟之剑 is the app they check the original in. A picker opened
// to switch between 和合本 and the BSB should not also be offering a
// Greek New Testament.
//
// Hiding a whole LANGUAGE is a different shape from hiding the NASB, and
// `nasb_hidden_test.dart` carries the reason it has to be pinned at all:
// the 2026-09-02 web strip shipped a boot crash because two code paths
// set the version WITHOUT going through the picker. Neither can name
// Greek — no locale defaults to `el` — but a STORED preference can, and
// that path has no same-language edition left to fall back to. This file
// pins where it lands instead.
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';

void main() {
  test('neither Greek edition is offered in any language list', () {
    expect(disabledVersions, containsAll(<String>['wh', 'lxx']));
    final offered = availableVersions.map((v) => v.value);
    expect(offered, isNot(contains('wh')));
    expect(offered, isNot(contains('lxx')));
    expect(versionsForLanguage('el'), isEmpty);
  });

  test('the Greek language pill is gone from the picker', () {
    expect(bibleLanguageOrder, isNot(contains('el')),
        reason: 'both el rows are disabled, so the fourth tab has nothing '
            'behind it — bibleLanguageOrder filters to languages that '
            'actually have an available version, and this is that branch '
            'earning its keep');
    expect(bibleLanguageOrder, ['en', 'zh-Hant', 'zh-Hans'],
        reason: 'the three reading tabs, in the order the owner asked for '
            '— 英语繁体简体');
  });

  test('a reader stored on Greek lands on a real edition, not on nothing',
      () {
    // The path the NASB strip crashed on: a stored preference is applied
    // without going through the picker. `resolvableVersionFrom` normally
    // coerces to the nearest edition of the SAME language, and for the
    // first time there is no same-language edition to reach — so the
    // final `available.first` fallback is what catches this reader.
    for (final stored in <String>['wh', 'lxx']) {
      final landed = resolvableVersionFrom(stored, availableVersions);
      expect(availableVersions.map((v) => v.value), contains(landed),
          reason: '$stored must resolve to something the picker can show');
      expect(landed, isNot(stored));
    }
  });

  test('hidden, NOT removed — both entries and both assets stay', () {
    // Same rule as the NASB: the catalogue keeps the entry so an old
    // shared link or a stored preference naming `wh` still resolves to
    // something describable. Deleting the entries and the assets is the
    // NIV treatment, a separate decision, and the owner's to make.
    final all = bibleVersions.map((v) => v.value);
    expect(all, containsAll(<String>['wh', 'lxx']));
    expect(bibleVersionLanguage('wh'), 'el');
    expect(bibleVersionLanguage('lxx'), 'el');
  });
}
