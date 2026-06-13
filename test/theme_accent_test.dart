// 2026-06-13 (v1.3.68): verifies the dark-mode accent derivation that
// makes reading accents (verse numbers, note glyphs, section headers)
// track the user's chosen theme colour in dark mode.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/theme_accent.dart';

void main() {
  group('darkReadingAccent', () {
    test('clamps lightness into the dark-legible band', () {
      // Very dark seed (navy) must be lifted so it does not vanish on
      // a near-black surface.
      // Tolerance accounts for the 8-bit colour round-trip
      // (HSL→Color→HSL nudges lightness by up to ~1/255).
      const tol = 0.01;
      final navy = darkReadingAccent(const Color(0xFF000033));
      final navyL = HSLColor.fromColor(navy).lightness;
      expect(navyL, greaterThanOrEqualTo(kDarkAccentMinLightness - tol));
      expect(navyL, lessThanOrEqualTo(kDarkAccentMaxLightness + tol));

      // Near-white seed must be brought down so the accent still carries
      // colour.
      final pale = darkReadingAccent(const Color(0xFFEFEFFF));
      final paleL = HSLColor.fromColor(pale).lightness;
      expect(paleL, lessThanOrEqualTo(kDarkAccentMaxLightness + tol));
      expect(paleL, greaterThanOrEqualTo(kDarkAccentMinLightness - tol));
    });

    test('preserves the chosen hue', () {
      // A vivid teal seed: hue should survive the lightness/saturation
      // adjustment (so the user still recognises "their" colour).
      const seed = Color(0xFF00897B); // teal
      final seedHue = HSLColor.fromColor(seed).hue;
      final accent = darkReadingAccent(seed);
      final accentHue = HSLColor.fromColor(accent).hue;
      expect((accentHue - seedHue).abs(), lessThan(2.0));
    });

    test('floors saturation so muted swatches still read', () {
      // A washed-out swatch (low saturation) should be pushed up to the
      // floor so the hue is recognisable in dark mode.
      const muted = Color(0xFF8A8E96); // low-chroma slate
      final s = HSLColor.fromColor(darkReadingAccent(muted)).saturation;
      expect(s, greaterThanOrEqualTo(kDarkAccentMinSaturation - 1e-6));
    });

    test('caps saturation so vivid seeds are not neon as a big fill', () {
      // A fully-saturated seed must be brought DOWN to the cap so the
      // light pastel filling a whole card (e.g. the dashboard hero) is
      // soft rather than harsh/刺眼.
      const vivid = Color(0xFFFF1744); // near-pure red
      final s = HSLColor.fromColor(darkReadingAccent(vivid)).saturation;
      expect(s, lessThanOrEqualTo(kDarkAccentMaxSaturation + 1e-6));
    });

    test('result is light enough that onAccentColor picks dark text', () {
      // The dark accent is a LIGHT pastel, so a card filled with it
      // (Material(color: primary)) should get dark text/icons — the
      // natural Material-3 dark-mode filled-surface look.
      for (final seed in const [
        Color(0xFF00897B), // teal
        Color(0xFF3F51B5), // indigo
        Color(0xFFFF1744), // red
        Color(0xFF000033), // navy
      ]) {
        final accent = darkReadingAccent(seed);
        expect(onAccentColor(accent), const Color(0xFF1A1A1A),
            reason: 'accent for $seed should be light enough for dark text');
      }
    });

    test('leaves an already-vivid mid-tone hue recognisable + legible', () {
      const orange = Color(0xFFFB8C00);
      final accent = darkReadingAccent(orange);
      final hsl = HSLColor.fromColor(accent);
      expect(hsl.lightness, greaterThanOrEqualTo(kDarkAccentMinLightness - 0.01));
      expect(hsl.lightness, lessThanOrEqualTo(kDarkAccentMaxLightness + 0.01));
      expect((hsl.hue - HSLColor.fromColor(orange).hue).abs(), lessThan(2.0));
    });
  });

  group('onAccentColor', () {
    test('returns light text on a dark accent', () {
      final on = onAccentColor(const Color(0xFF1B3A6B)); // dark blue
      expect(on, const Color(0xFFFFFFFF));
    });

    test('returns dark text on a light accent', () {
      final on = onAccentColor(const Color(0xFFFFE082)); // light amber
      expect(on, const Color(0xFF1A1A1A));
    });
  });
}
