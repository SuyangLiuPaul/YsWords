import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';

/// A dashboard tile must never break a word in half.
///
/// 2026-08-11, from the phone: the misconceptions tile read
/// "Misunderstandi / ngs". Giving the grid intrinsic-height rows fixed
/// the clipping, but a single word wider than the tile is still split
/// mid-word — the ugliest way to wrap, and it happens in one language
/// at a time, so it is invisible to anyone not reading that one.
///
/// **Why a character count and not a real measurement.** `flutter
/// test` renders with a fixed-width test font where every glyph is a
/// square of the font size, roughly twice the width of the real one.
/// Laying text out here and asserting on the result measures the test
/// font, not the app — a first version of this test "failed" on
/// Search, Library and Sermons, all of which fit on one line on the
/// actual device. So this guards the property that actually causes the
/// break: a single unbreakable word that is too long.
///
/// The threshold is calibrated against what ships and renders
/// correctly today — "Timeline" (8), "Evidence" (8), "Settings" (8) —
/// and against the one that did not: "Misunderstandings" (17).
void main() {
  /// Labels used in the dashboard quick-link grids.
  const keys = [
    'search',
    'library',
    'sermons',
    'settings',
    'statistics',
    'bibleEvidence',
    'familyTree',
    'bibleTimeline',
    'bibleTrivia',
    'songsPageTitle',
    'oneGodTitle',
    'misconceptionsTile',
    'feedback',
  ];

  /// Calibrated against the DEPLOYED build at 375pt, not estimated —
  /// the first version of this test guessed 14 and "Misconceptions"
  /// still broke on the device. "Bible Trivia" (12 characters
  /// including the space) sits on one line; 14 does not fit.
  ///
  /// CJK is not at risk: it breaks between any two characters and has
  /// no unbreakable "word".
  const maxWordLength = 12;

  test('every quick-link key exists in all three locales', () {
    for (final key in keys) {
      final entry = uiStrings[key];
      expect(entry, isNotNull, reason: '$key is missing from uiStrings');
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        expect(entry![locale], isNotNull,
            reason: '$key has no $locale — the tile would fall back to '
                'its English hard-coded default');
      }
    }
  });

  test('no quick-link label contains a word too long for a tile', () {
    final problems = <String>[];
    for (final key in keys) {
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        final label = uiStrings[key]?[locale];
        if (label == null) continue;
        for (final word in label.split(RegExp(r'\s+'))) {
          // Latin runs only. CJK has no unbreakable words.
          if (!RegExp(r'^[A-Za-z][A-Za-z\-]*$').hasMatch(word)) continue;
          if (word.length > maxWordLength) {
            problems.add('$key.$locale: "$word" is ${word.length} '
                'characters — it will be split mid-word');
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
