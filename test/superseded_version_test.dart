// 2026-09-14: what happens to a reader who had chosen the 梁家鏗譯本 when
// that fetch is replaced by a newer one.
//
// Every edition hidden before this one was WITHDRAWN — the NASB on a
// licensing question, the two Greek texts on the owner's word. For a
// withdrawal, `resolvableVersionFrom`'s language fallback is right: land
// the reader on another edition in the same language and let them choose
// again.
//
// A REPLACEMENT is a different case and the fallback gets it wrong. The
// September re-fetch of the 梁家鏗譯本 is the same translation by the same
// translator; `biblexg-v2` is hidden and `biblexg-v3` is offered. Without
// a successor table the reader who had chosen it reopens the app in
// 和合本雅伟版 — a completely different translation, silently, with no
// message and nothing to undo. Not a crash, not visible in any test that
// only asks "did we land somewhere real", and exactly the sort of thing
// the reader would blame on themselves.
//
// So the mechanism is `_kSupersededBy`, consulted before the language
// fallback, and this file is what says it is wired up. The fallback
// itself is still the right answer for a withdrawal — `nasb_hidden_test`
// and `greek_hidden_test` pin that, and nothing here should weaken it.
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/constants/bible_versions.dart';

void main() {
  test('a stored 梁家鏗 v2 preference lands on v3, not on another translation',
      () {
    expect(resolvableVersionFrom('biblexg-v2', availableVersions),
        'biblexg-v3');
    expect(resolvableVersionFrom('biblexg-v2-tr', availableVersions),
        'biblexg-v3-tr');
    // Through the other door too — the one the app calls on boot.
    expect(resolvableVersion('biblexg-v2'), 'biblexg-v3');
    expect(resolvableVersion('biblexg-v2-tr'), 'biblexg-v3-tr');
  });

  test('the successor keeps the reader in their own script', () {
    // The failure this guards is subtler than landing on the wrong
    // translation: mapping the Traditional row to the Simplified
    // successor would keep the translation and silently convert the
    // script, which for this app's readers is the visible half.
    expect(bibleVersionLanguage(
            resolvableVersionFrom('biblexg-v2', availableVersions)),
        bibleVersionLanguage('biblexg-v2'));
    expect(bibleVersionLanguage(
            resolvableVersionFrom('biblexg-v2-tr', availableVersions)),
        bibleVersionLanguage('biblexg-v2-tr'));
  });

  test('both halves of "hidden, not removed" hold for the v2 pair', () {
    // Hidden from the picker…
    for (final v in ['biblexg-v2', 'biblexg-v2-tr']) {
      expect(disabledVersions, contains(v));
      expect(availableVersions.map((x) => x.value), isNot(contains(v)));
      // …and still in the catalogue, because a stored preference and an
      // old shared link both have to resolve to something with a name.
      expect(bibleVersions.map((x) => x.value), contains(v));
      expect(shortBibleVersionLabel(v), isNotEmpty);
    }
  });

  test('the successor is itself offered — a chain to a hidden row is worse '
      'than no chain', () {
    // The table names codes, and nothing stops someone hiding the
    // successor later. If that happens the mapping must not hand the
    // reader an edition the picker will not open; this is the assertion
    // that turns that into a test failure rather than a blank pane.
    for (final code in ['biblexg-v2', 'biblexg-v2-tr']) {
      final landed = resolvableVersionFrom(code, availableVersions);
      expect(availableVersions.map((v) => v.value), contains(landed),
          reason: '$code resolves to $landed, which is not on offer');
      expect(disabledVersions, isNot(contains(landed)));
    }
  });

  test('a withdrawal still falls back by language, not to a successor', () {
    // The guard against over-applying the new mechanism. `nasb` has no
    // successor and must keep landing on the KJV.
    expect(resolvableVersionFrom('nasb', availableVersions), 'kjv');
  });
}
