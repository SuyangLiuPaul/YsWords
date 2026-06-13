// 2026-06-13 (v1.3.68): dark-mode accent derivation, extracted from
// main.dart so it is a pure, unit-tested function.
//
// Why this exists: Material-3's `ColorScheme.fromSeed(... dark ...)`
// maps `primary` to a pale, low-chroma tone-80 of the seed. Since verse
// numbers, note/bookmark glyphs, and section headers all read
// `colorScheme.primary` (see lib/utils/build_verse_content_spans.dart),
// dark mode looked washed-out and generic, NOT the hue the user picked
// (user report: "dark mode 没有根据 theme color"). [darkReadingAccent]
// keeps the chosen hue, floors the chroma so muted swatches still read,
// and clamps lightness into a dark-legible band — applied only to the
// dark scheme's `primary` override so light mode is untouched and the
// dark AppBar (which uses `primaryContainer`) stays non-garish.

import 'package:flutter/widgets.dart';

/// Lower bound of the dark-mode accent lightness band. A very dark seed
/// (e.g. navy) is lifted to at least this so it does not vanish on the
/// near-black dark surface.
///
/// 2026-06-13 (v1.3.69): raised from 0.58 → 0.74. The dark `primary`
/// isn't only used for THIN accents (verse numbers) — it also fills
/// whole surfaces like the dashboard "读经/Read Bible" hero card
/// (`Material(color: scheme.primary)`). A mid-lightness saturated tone
/// reads as harsh/刺眼 across a large fill in dark mode (user report).
/// A LIGHT pastel — Material-3's own dark-primary treatment — stays
/// soft as a big fill AND legible as thin text, while still carrying
/// the chosen hue.
const double kDarkAccentMinLightness = 0.74;

/// Upper bound of the dark-mode accent lightness band. A near-white seed
/// is brought down to this so the accent still carries colour.
const double kDarkAccentMaxLightness = 0.82;

/// Minimum saturation floor — washed-out picker swatches are pushed up to
/// this so the hue is still recognisable in dark mode.
const double kDarkAccentMinSaturation = 0.32;

/// Maximum saturation — caps vivid seeds so the light pastel doesn't read
/// as neon/刺眼 when it fills a whole card. (2026-06-13 v1.3.69.)
const double kDarkAccentMaxSaturation = 0.55;

/// Derive a dark-mode accent that stays faithful to the user's chosen
/// [seed] hue while remaining legible on dark surfaces — soft enough to
/// fill a whole card without harshness, saturated enough to read as the
/// user's colour.
Color darkReadingAccent(Color seed) {
  final hsl = HSLColor.fromColor(seed);
  final s = hsl.saturation
      .clamp(kDarkAccentMinSaturation, kDarkAccentMaxSaturation);
  final l =
      hsl.lightness.clamp(kDarkAccentMinLightness, kDarkAccentMaxLightness);
  return hsl.withSaturation(s).withLightness(l).toColor();
}

/// Pick black or white for text/icons drawn ON [bg], whichever has the
/// higher WCAG contrast. Used for the dark scheme's `onPrimary` (and the
/// "读经" hero card text, which is `onPrimary` on a `primary`-filled
/// card).
///
/// Threshold is 0.179, NOT the common-but-wrong 0.5: maximising the WCAG
/// contrast ratio, dark text wins for any background with relative
/// luminance above ≈0.179 (e.g. a light indigo pastel at luminance ~0.30
/// reads far better with dark text — ~7:1 — than white — ~3:1). The 0.45
/// value used in v1.3.68 mis-picked white text on light blue pastels.
Color onAccentColor(Color bg) =>
    bg.computeLuminance() > 0.179 ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
