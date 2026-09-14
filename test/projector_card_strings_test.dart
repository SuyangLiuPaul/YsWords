// Every label the projector card asks for exists in all three locales.
//
// 2026-09-15, from a phone screenshot with four rows circled:
// 「这里语言没有跟app语言一起变」. 「对齐」「经文排法」「显示节号」「经文出处」
// were printed in English in the middle of a Chinese card.
//
// The translations existed. They live in `projectionStrings`, because
// the wall needs them, and the card asked `uiStrings` for them under
// `projector*` names that were never added to anything. The lookup
// answers a missing key with the caller's English fallback — which is
// what a fallback is for, and is also why nothing complained.
//
// So this test reads the KEYS OUT OF THE SOURCE rather than being given
// a list. A future row that invents another name fails here on the day
// it is written, instead of on a reader's phone.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/projection_strings.dart';
import 'package:yswords/constants/ui_strings.dart';

/// The three the app ships. A key present in one and missing in another
/// is the same defect, one locale further along.
const _locales = ['zh-Hans', 'zh-Hant', 'en'];

void main() {
  test('the projector card names no string the app cannot translate', () {
    final source = File('lib/pages/settings_page.dart').readAsStringSync();
    final start = source.indexOf('class _ProjectorCard');
    expect(start, greaterThan(0),
        reason: 'the card was renamed — point this test at the new name '
            'rather than deleting it');
    final card = source.substring(start);

    // `t('key', 'fallback')` and the `row('key', 'fallback', …)` that
    // wraps it. Both spellings, because the card uses both and a rule
    // that only sees one of them is a rule that passes while the screen
    // is half English.
    final keys = <String>{
      for (final m in RegExp(r"\bt\(\s*'([A-Za-z0-9_]+)'").allMatches(card))
        m.group(1)!,
      for (final m
          in RegExp(r"\brow\(\s*\n?\s*'([A-Za-z0-9_]+)'").allMatches(card))
        m.group(1)!,
    };
    expect(keys.length, greaterThan(8),
        reason: 'the scrape found ${keys.length} keys, which is fewer '
            'than the card visibly has — the patterns stopped matching '
            'and this test is now asserting nothing');

    final missing = <String>[];
    for (final key in keys) {
      final table = uiStrings[key] ?? projectionStrings[key];
      if (table == null) {
        missing.add('$key — in no table at all');
        continue;
      }
      for (final locale in _locales) {
        if ((table[locale] ?? '').isEmpty) missing.add('$key — no $locale');
      }
    }
    expect(missing, isEmpty,
        reason: 'these rows will print English to a Chinese reader:\n'
            '${missing.join("\n")}');
  });

  test('the four rows from the report resolve, and to Chinese', () {
    // Named explicitly as well as scraped: the scrape proves the rule,
    // and this proves the rule was applied to the rows that were
    // actually reported.
    for (final key in [
      'projectionAlign',
      'projectionFlow',
      'projectionNumbers',
      'projectionReferencePlace',
    ]) {
      final zh = projectionStrings[key]?['zh-Hans'];
      expect(zh, isNotNull, reason: '$key lost its Simplified label');
      expect(RegExp(r'[一-鿿]').hasMatch(zh!), isTrue,
          reason: '$key resolves to "$zh", which is not Chinese');
    }
  });
}
