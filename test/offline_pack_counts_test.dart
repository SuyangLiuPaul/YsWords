import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/constants/bible_versions.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';

/// Guards the two counts the offline-pack settings screen states about
/// itself — `offlinePackSermons` and `offlinePackBibles`.
///
/// Neither had a test before this one. `seo_meta_test.dart`'s
/// "the version count the copy advertises" group already guards
/// `offlinePackBibles`'s English "7 versions", but its `anyCount` regex
/// requires the number to come BEFORE `版本`/`译本` (`7 个版本`) and so
/// never matches this string's actual order, `版本（共 7 个）` — number
/// after the noun. It has silently checked nothing for this string since
/// it was written. This test extracts every digit run instead of relying
/// on word order, so it can't miss a count regardless of how the
/// sentence is phrased.
void main() {
  // 2026-09-14: counted off the editions the picker offers, NOT off the
  // catalog in `bible_versions.dart`. The catalog has 14 rows, 5 of them
  // in `disabledVersions`; scraping `value:` counted all 14 and so
  // measured neither the pack nor the picker. It agreed with the copy
  // only while the catalog happened to hold as many rows as the pack held
  // files, which stopped being true when the 梁家鏗譯本 v3 rows joined and
  // the v2 pair was hidden rather than removed.
  //
  // Those are now one number by construction: `_bibleUrls` in the service
  // derives from `availableVersions` (see the doc comment there — it
  // records the 404 and the two unopenable editions that a hand-kept list
  // had drifted into).
  final versionCount = availableVersions.length;
  final sermons =
      json.decode(File('assets/sermons/index.json').readAsStringSync())
          as List;
  final sermonTotal = sermons.length;
  final sermonTrilingual =
      sermons.where((s) => (s as Map)['hasEn'] == true).length;

  List<int> numbersIn(String s) => RegExp(r'\d+')
      .allMatches(s)
      .map((m) => int.parse(m.group(0)!))
      .toList();

  test('offlinePackSermons states the real sermon counts in every locale',
      () {
    // The copy states two real counts (total, trilingual) plus a
    // literal "×3" for the language count — not a third derived
    // count. "289 篇 ×3 语" reads "289 sermons, in 3 languages",
    // not "289 vs some other count of 3".
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      final body = uiStrings['offlinePackSermons']![locale]!;
      expect(
        numbersIn(body),
        [sermonTotal, sermonTrilingual, 3],
        reason: 'offlinePackSermons/$locale',
      );
    }
  });

  test('offlinePackBibles states the real version count in every locale',
      () {
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      final body = uiStrings['offlinePackBibles']![locale]!;
      expect(
        numbersIn(body),
        [versionCount],
        reason: 'offlinePackBibles/$locale',
      );
    }
  });

  test('every edition the pack derives is really a declared asset', () {
    // `_bibleUrls` builds `assets/<value>.json` from each available
    // edition's code. That holds for all nine today and is a CONVENTION,
    // not a guarantee: an edition whose asset is named anything else
    // would make the pack request a path Flutter never bundled, and the
    // symptom — one more failed fetch inside a 9-file download, on web
    // only — is exactly the kind nobody notices. This is the check that
    // moved the risk out of a reader's browser and into `flutter test`.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final v in availableVersions) {
      expect(pubspec, contains('- assets/${v.value}.json'),
          reason: '${v.value} is offered in the picker, so the offline '
              'pack will fetch assets/${v.value}.json — which pubspec.yaml '
              'does not declare. Either the asset is named differently '
              '(then _bibleUrls needs a real mapping, not the convention) '
              'or the edition ships no text at all.');
    }
  });
}
