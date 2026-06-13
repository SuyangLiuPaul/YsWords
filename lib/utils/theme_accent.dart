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
const double kDarkAccentMinLightness = 0.58;

/// Upper bound of the dark-mode accent lightness band. A near-white seed
/// is brought down to this so the accent still carries colour.
const double kDarkAccentMaxLightness = 0.74;

/// Minimum saturation floor — washed-out picker swatches are pushed up to
/// this so the hue is still recognisable in dark mode.
const double kDarkAccentMinSaturation = 0.42;

/// Derive a dark-mode accent that stays faithful to the user's chosen
/// [seed] hue while remaining legible on dark surfaces.
Color darkReadingAccent(Color seed) {
  final hsl = HSLColor.fromColor(seed);
  final s = hsl.saturation < kDarkAccentMinSaturation
      ? kDarkAccentMinSaturation
      : hsl.saturation;
  final l =
      hsl.lightness.clamp(kDarkAccentMinLightness, kDarkAccentMaxLightness);
  return hsl.withSaturation(s).withLightness(l).toColor();
}

/// Pick black or white for text/icons drawn ON [bg], whichever has the
/// higher contrast. Used for the dark scheme's `onPrimary` after the
/// accent override so FilledButton labels etc. stay readable.
Color onAccentColor(Color bg) =>
    bg.computeLuminance() > 0.45 ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
