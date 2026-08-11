import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';

/// The dashboard quick-link labels.
///
/// **Fitting is no longer this test's job.** The tile lays its label
/// out on a single line inside a `FittedBox(scaleDown)`, so a label
/// that does not fit is shrunk, never broken mid-word. That replaced
/// two failed attempts to pick a label short enough by counting
/// characters — "Misunderstandings" (17) broke, then "Misconceptions"
/// (14) broke, then "Misreadings" (11) broke, while "Bible Trivia"
/// (12) fitted the whole time, because M and s and a are far wider
/// than i and l and t. Character count was never measuring the thing
/// that decides.
///
/// What is still worth pinning is the DATA: a missing locale silently
/// falls back to an English string hard-coded at the call site, which
/// is invisible to everyone except the reader it fails.
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

  test('every quick-link label exists in all three locales', () {
    for (final key in keys) {
      final entry = uiStrings[key];
      expect(entry, isNotNull, reason: '$key is missing from uiStrings');
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        final label = entry![locale];
        expect(label, isNotNull,
            reason: '$key has no $locale — the tile would silently fall '
                'back to the English default hard-coded at the call site');
        expect(label!.trim(), isNotEmpty, reason: '$key.$locale is blank');
      }
    }
  });

  test('no label is long enough to shrink past readability', () {
    // Not a fitting rule — a sanity ceiling. The tile scales a long
    // label down, and past roughly this length the result is too small
    // to read on a phone even though nothing is clipped or broken.
    // "The Only True God" (17) is the longest that currently ships and
    // reads fine, so the bar sits above it rather than under it.
    const absurd = 24;
    for (final key in keys) {
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        final label = uiStrings[key]?[locale];
        if (label == null) continue;
        expect(label.length, lessThanOrEqualTo(absurd),
            reason: '$key.$locale is ${label.length} characters '
                '("$label") and would be scaled down to something too '
                'small to read — give the tile its own shorter key, as '
                'misconceptionsTile does');
      }
    }
  });
}
