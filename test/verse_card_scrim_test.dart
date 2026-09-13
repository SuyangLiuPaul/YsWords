import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/widgets/verse_card.dart';

/// 2026-09-13: the photo card's veil answers to the photograph.
///
/// A fixed 0.32 veil read over a dark photograph and measured 2.2:1 for
/// white type over a bright one. The veil is now the least that reaches
/// 4.5:1 against the photograph's mean luminance, floored where the
/// design was tuned and capped before the picture disappears.
void main() {
  double contrast(double l1, double l2) {
    final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('a dark photograph keeps exactly the veil it had', () {
    expect(photoScrimAlpha(0.05, dark: true), 0.32);
    expect(photoScrimAlpha(0.15, dark: true), 0.32);
  });

  test('a bright photograph gets a heavier veil, and the type reads', () {
    final a = photoScrimAlpha(0.9, dark: true);
    expect(a, greaterThan(0.32));
    expect(a, lessThanOrEqualTo(0.85));
    final ground = 0.9 * (1 - a);
    expect(contrast(1.0, ground), greaterThanOrEqualTo(4.5),
        reason: 'white type over the veiled photograph');
  });

  test('the light veil has the mirror rule, and the floor already meets it',
      () {
    // A white veil brightens a ground fast: even a black photograph
    // under 0.32 of white sits at L≈0.32, which near-black type reads
    // at 6.7:1. So the light side never leaves the floor — the rule is
    // kept for symmetry and pinned so that stays true.
    for (final l in [0.0, 0.02, 0.5, 0.9]) {
      final a = photoScrimAlpha(l, dark: false);
      expect(a, 0.32, reason: 'luminance $l');
      final ground = l + a * (1 - l);
      expect(contrast(0.007, ground), greaterThanOrEqualTo(4.5),
          reason: 'near-black type over the veiled photograph at $l');
    }
  });

  test('the dark veil tops out at 0.817 for pure white — under the cap', () {
    // 1 − 0.183/1.0: the heaviest veil any photograph can ask for. The
    // 0.85 cap exists as a guard, not a value anything reaches.
    expect(photoScrimAlpha(1.0, dark: true), closeTo(0.817, 0.001));
    expect(photoScrimAlpha(1.0, dark: true), lessThanOrEqualTo(0.85));
  });

  test('null keeps the floor', () {
    expect(photoScrimAlpha(null, dark: true), 0.32);
    expect(photoScrimAlpha(null, dark: false), 0.32);
  });

  test('the palette carries it into the scrim colour', () {
    final dark = ColorScheme.fromSeed(
        seedColor: Colors.blue, brightness: Brightness.dark);
    final calm = VerseCardPalette.of(VerseCardStyle.photo, dark,
        photoLuminance: 0.1);
    final bright = VerseCardPalette.of(VerseCardStyle.photo, dark,
        photoLuminance: 0.9);
    expect(calm.scrim!.a, closeTo(0.32, 0.001));
    expect(bright.scrim!.a, greaterThan(calm.scrim!.a));
    expect(VerseCardPalette.of(VerseCardStyle.photo, dark).scrim!.a,
        closeTo(0.32, 0.001),
        reason: 'no measurement, the fixed veil');
  });
}
