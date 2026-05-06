import 'package:flutter/material.dart';

/// Theme-aware color helpers for places where we want to use a
/// **specific palette** (teal for Aramaic, indigo for Hebrew, etc.)
/// rather than the surrounding ColorScheme's primary/secondary slots,
/// but still need to adapt to light vs. dark mode.
///
/// Pattern before this helper:
/// ```dart
/// Container(
///   color: Colors.teal.shade100,        // washed out in dark mode
///   child: Text('...', style: TextStyle(color: Colors.teal.shade900)), // unreadable in dark
/// )
/// ```
///
/// Pattern after:
/// ```dart
/// Container(
///   color: paletteBg(context, Colors.teal),
///   child: Text('...', style: TextStyle(color: paletteFg(context, Colors.teal))),
/// )
/// ```
///
/// In light mode: shade100 bg + shade900 text (high contrast, vivid).
/// In dark mode: shade900 bg with alpha + shade100/200 text (vivid
/// without being eye-searing on a dark surface).

/// Background tint for a colored card / chip / pill.
/// Light: shade100 (pastel). Dark: shade900 with low alpha so the
/// card sits as a tinted surface above the dark scaffold.
Color paletteBg(BuildContext ctx, MaterialColor color) {
  final dark = Theme.of(ctx).brightness == Brightness.dark;
  return dark
      ? color.shade900.withValues(alpha: 0.45)
      : color.shade100;
}

/// Foreground (text / icon) on a [paletteBg] surface.
/// Light: shade900 (deep, readable). Dark: shade200 (vivid, readable).
Color paletteFg(BuildContext ctx, MaterialColor color) {
  final dark = Theme.of(ctx).brightness == Brightness.dark;
  return dark ? color.shade200 : color.shade900;
}

/// Border / accent line — visible in both modes without overpowering
/// the content.
Color paletteBorder(BuildContext ctx, MaterialColor color) {
  final dark = Theme.of(ctx).brightness == Brightness.dark;
  return dark
      ? color.shade400.withValues(alpha: 0.55)
      : color.shade700.withValues(alpha: 0.45);
}

/// Stronger accent color for icons, chips, link-text. Stays vivid
/// in both modes.
Color paletteAccent(BuildContext ctx, MaterialColor color) {
  final dark = Theme.of(ctx).brightness == Brightness.dark;
  // Brighter shade in dark mode so it pops against the dark surface;
  // standard `color` (which is `shade500`) in light mode stays readable.
  return dark ? color.shade300 : color.shade700;
}

/// Status colors — used for the diagnostic page's pass/fail/warn
/// rows. Adapt to dark mode while keeping the semantic meaning.
Color statusOk(BuildContext ctx) =>
    paletteAccent(ctx, Colors.green);
Color statusWarn(BuildContext ctx) =>
    paletteAccent(ctx, Colors.orange);
Color statusBgOk(BuildContext ctx) =>
    paletteBg(ctx, Colors.green);
Color statusBgWarn(BuildContext ctx) =>
    paletteBg(ctx, Colors.orange);
