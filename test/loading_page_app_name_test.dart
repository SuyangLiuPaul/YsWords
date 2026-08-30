// The splash shows ONE app name — the reader's own — not both stacked.
// User, 2026-08-30: "根据用户语言而定，中文汉字都是雅伟之言，否则都是
// Yahweh words".
//
// Two things are pinned, and the second is the one that would rot
// silently:
//
//   1. The name is resolved per locale, in BOTH splash paths (there are
//      two, and only fixing one is the obvious way to half-fix this).
//   2. A zh-Hant reader gets the TRADITIONAL 雅偉之言. Before this change
//      the splash hardcoded the simplified 雅伟之言 for every Chinese
//      reader, so the first screen of the app showed a Traditional user
//      the wrong script. Nothing failed; it just looked slightly wrong to
//      the people least likely to report it.
//
// The source is read directly rather than pumped as a widget: the splash
// sits behind the whole boot path (SharedPreferences, the database, the
// asset bundle), and the regression being guarded is a hardcoded literal
// — which is exactly the kind of thing that comes back during a tidy-up.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';

void main() {
  final src = File('lib/pages/loading_page.dart').readAsStringSync();

  // Comments deliberately name both Chinese forms to explain the fix, so
  // they must never count as rendered literals.
  final code = src
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('appName string table', () {
    test('carries a distinct name for all three locales', () {
      expect(uiStrings['appName']?['zh-Hans'], '雅伟之言');
      expect(uiStrings['appName']?['zh-Hant'], '雅偉之言');
      expect(uiStrings['appName']?['en'], "Yahweh's Words");
    });

    test('Simplified and Traditional are NOT the same string', () {
      // The exact defect this change fixes: one literal doing duty for
      // both scripts. 伟 vs 偉 is the whole difference, and it is easy to
      // "tidy" away as an apparent duplicate.
      final hans = uiStrings['appName']!['zh-Hans']!;
      final hant = uiStrings['appName']!['zh-Hant']!;
      expect(hans, isNot(equals(hant)),
          reason: 'zh-Hans and zh-Hant app names collapsed into one form');
      expect(hans.contains('伟'), isTrue, reason: 'zh-Hans lost 伟');
      expect(hant.contains('偉'), isTrue, reason: 'zh-Hant lost 偉');
    });
  });

  group('loading_page.dart', () {
    test('resolves the name per locale in BOTH splash paths', () {
      final uses = RegExp(r"uiStrings\['appName'\]\?\[settings\.locale\]")
          .allMatches(code)
          .length;
      expect(uses, 2,
          reason: 'both splash paths must resolve the name per locale; '
              'found $uses of the expected 2');
    });

    test('renders no hardcoded Chinese app name', () {
      expect(code.contains('雅伟之言'), isFalse,
          reason: 'simplified app name is hardcoded again — Traditional '
              'readers would be shown the wrong script');
      expect(code.contains('雅偉之言'), isFalse,
          reason: 'traditional app name is hardcoded again — Simplified '
              'readers would be shown the wrong script');
    });

    test('the two names are not stacked as separate Texts again', () {
      // The English literal survives only as a `?? ` fallback. A bare
      // Text('Yahweh\'s Words') means the second name came back.
      final bare =
          RegExp(r"Text\(\s*'Yahweh\\'s Words'").allMatches(code).length;
      expect(bare, 0,
          reason: 'a bare English-name Text is back; the splash is showing '
              'both names again');
    });
  });
}
