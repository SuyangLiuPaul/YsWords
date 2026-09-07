import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/ui_strings.dart';

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
  final versionsSrc =
      File('lib/constants/bible_versions.dart').readAsStringSync();
  final list = versionsSrc.substring(
    versionsSrc.indexOf('const bibleVersions ='),
    versionsSrc.indexOf('\n];', versionsSrc.indexOf('const bibleVersions =')),
  );
  final versionCount = RegExp(r"value:\s*'([^']+)'")
      .allMatches(list.replaceAll(RegExp(r'//[^\n]*'), ''))
      .length;

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
}
