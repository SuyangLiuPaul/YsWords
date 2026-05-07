import 'package:flutter/material.dart';

import 'package:yswords/models/app_settings.dart';

/// Bundled-style "presets" that the user can apply with one tap.
/// Each preset bundles a coordinated set of visual settings —
/// fontFamily, fontSize, lineSpacing, menuScale, paragraphMode, and
/// (since v1.1.1) the [CardMaterial] used by tiles / chips / framing
/// cards — so the app's overall feel changes without the user having
/// to tune every field individually.
///
/// Round 56 user request: "now can change theme color, also should
/// have format style of the app, now is plain or something, and
/// all other style of the app which can be applied all inside
/// the app."
///
/// 2026-05-08 (v1.1.1) user follow-up: "感觉还不如之前的，把 glass
/// 改成 setting 里的可选样式，并且多加几个". v1.1.0 had made
/// Liquid Glass the global default; v1.1.1 reverts to Classic by
/// default and exposes Liquid Glass as one of several pickable
/// materials in Settings → Style preset.
///
/// Adding a new preset:
///   1. Add an enum value
///   2. Add a definition in [presetDefinitions]
///   3. Add localized labels via uiStrings (`stylePreset_<name>_label`,
///      `stylePreset_<name>_description`)
enum AppStylePreset {
  /// 2026-05-08 (v1.1.2): the new top-of-list preset. Picks up
  /// **whatever the user's OS reports**: native UI font (San
  /// Francisco / Segoe UI / Roboto / Cantarell etc. via the CSS
  /// font stack), system theme mode, system locale. Material is
  /// `classic` so it works on every device including ones where
  /// reduced-transparency is preferred. This is what users land
  /// on when they pick "Reset settings" or first install.
  systemDefault,

  /// Sans-serif Roboto, paragraph mode on, normal density.
  /// Recreates the look users had before the v1.1.0 design pass.
  classic,

  /// System sans-serif font, slightly compact, paragraph mode on.
  /// Closer to a modern reading app like a Kindle.
  modern,

  /// Serif Garamond/Times, generous line-spacing, paragraph mode
  /// on. Calls to mind a printed Bible or hymnal.
  reverent,

  /// Smaller fonts, lower menu scale, verse-by-verse mode.
  /// Maximum density for reference-heavy use.
  compact,

  /// Larger font, slightly increased line spacing, paragraph
  /// mode on, menu scale unchanged. For users who want easy
  /// reading without compromising on chrome.
  reader,

  /// 2026-05-08 (v1.1.1): Apple WWDC25 Liquid Glass material on
  /// dashboard tiles / search chips / framing cards. Bundled with
  /// Apple-style typography (SF Pro family inferred via the
  /// system font fallback chain). Was the global default in
  /// v1.1.0; demoted to "one of several" in v1.1.1.
  liquidGlass,

  /// 2026-05-08 (v1.1.1): warm sepia paper aesthetic. Flat tiles
  /// with hairline borders, generous spacing, serif body. Evokes
  /// reading a printed book; pairs well with the Reverent font
  /// settings and a warm-grey primary colour.
  paper,

  /// 2026-05-08 (v1.1.1): high-contrast tech aesthetic. Sharp
  /// drop-shadows, dense info layout, mono-friendly typography.
  /// Designed to look great in dark mode but also viable on light.
  carbon,
}

/// What card / tile / chip material to use across the app's framing
/// surfaces. Independent from the typography settings inside a
/// preset — different presets can share the same material if the
/// vibe calls for it.
enum CardMaterial {
  /// Material 3 — primary-tinted Card with InkWell ripple. The
  /// look the app shipped with from v0.9 → v1.0.1.
  classic,

  /// Apple WWDC25 frosted glass with specular highlights,
  /// hairline border, soft shadow. See `lib/widgets/liquid_glass.dart`.
  liquidGlass,

  /// Warm flat surface with a hairline outline. No shadow, no
  /// elevation — the whole UI feels like a single sheet of paper.
  paper,

  /// Dark or near-black surface with a sharp drop-shadow. Borders
  /// are visible but thin; the look reads "developer / power tool".
  carbon,
}

/// Concrete settings bundle for one preset.
class AppStylePresetDef {
  final String fontFamily;
  final double fontSize;
  final double lineSpacing;
  final double menuScale;
  final bool paragraphMode;
  final CardMaterial cardMaterial;
  const AppStylePresetDef({
    required this.fontFamily,
    required this.fontSize,
    required this.lineSpacing,
    required this.menuScale,
    required this.paragraphMode,
    required this.cardMaterial,
  });
}

const Map<AppStylePreset, AppStylePresetDef> presetDefinitions = {
  // 2026-05-08 (v1.1.2): "System default" maps to the special
  // 'system' font key (resolves through the CSS native font stack
  // chain in main.dart), classic material, and the same nominal
  // density as classic. The end result on each platform: macOS /
  // iOS users render in San Francisco; Windows in Segoe UI;
  // Android in Roboto; Linux in Cantarell / Noto Sans — all with
  // the familiar Material 3 cards.
  AppStylePreset.systemDefault: AppStylePresetDef(
    fontFamily: 'system',
    fontSize: 20.0,
    lineSpacing: 1.5,
    menuScale: 1.0,
    paragraphMode: true,
    cardMaterial: CardMaterial.classic,
  ),
  AppStylePreset.classic: AppStylePresetDef(
    fontFamily: 'Roboto',
    fontSize: 20.0,
    lineSpacing: 1.5,
    menuScale: 1.0,
    paragraphMode: true,
    cardMaterial: CardMaterial.classic,
  ),
  // Round 56 (continued): preset font keys must come from the new
  // [availableFontOptions] catalogue in lib/utils/font_catalog.dart.
  // The previous keys (`system-ui`, `Garamond`, `Georgia`) were
  // CSS-only system fonts that CanvasKit can't load — picking
  // those presets silently rendered everything in Roboto.
  AppStylePreset.modern: AppStylePresetDef(
    fontFamily: 'Inter',
    fontSize: 19.0,
    lineSpacing: 1.45,
    menuScale: 0.95,
    paragraphMode: true,
    cardMaterial: CardMaterial.classic,
  ),
  AppStylePreset.reverent: AppStylePresetDef(
    fontFamily: 'EB Garamond',
    fontSize: 21.0,
    lineSpacing: 1.7,
    menuScale: 1.0,
    paragraphMode: true,
    cardMaterial: CardMaterial.paper,
  ),
  AppStylePreset.compact: AppStylePresetDef(
    fontFamily: 'Roboto',
    fontSize: 16.0,
    lineSpacing: 1.3,
    menuScale: 0.85,
    paragraphMode: false,
    cardMaterial: CardMaterial.classic,
  ),
  AppStylePreset.reader: AppStylePresetDef(
    fontFamily: 'Merriweather',
    fontSize: 22.0,
    lineSpacing: 1.6,
    menuScale: 1.0,
    paragraphMode: true,
    cardMaterial: CardMaterial.paper,
  ),
  AppStylePreset.liquidGlass: AppStylePresetDef(
    // SF system fonts can't be loaded by CanvasKit, but the user's
    // OS picks them up via the fontFamilyFallback chain configured
    // in main.dart. Use Inter as the explicit fallback so non-Apple
    // devices still get a clean modern sans.
    fontFamily: 'Inter',
    fontSize: 20.0,
    lineSpacing: 1.5,
    menuScale: 1.0,
    paragraphMode: true,
    cardMaterial: CardMaterial.liquidGlass,
  ),
  AppStylePreset.paper: AppStylePresetDef(
    fontFamily: 'EB Garamond',
    fontSize: 20.0,
    lineSpacing: 1.55,
    menuScale: 1.0,
    paragraphMode: true,
    cardMaterial: CardMaterial.paper,
  ),
  AppStylePreset.carbon: AppStylePresetDef(
    fontFamily: 'Inter',
    fontSize: 19.0,
    lineSpacing: 1.4,
    menuScale: 0.95,
    paragraphMode: true,
    cardMaterial: CardMaterial.carbon,
  ),
};

extension AppStylePresetExt on AppStylePreset {
  /// Apply this preset to [settings] in one shot. Skips
  /// `setX` calls that would be no-ops (those notify
  /// listeners only when the value actually changes anyway).
  Future<void> apply(AppSettings settings) async {
    final def = presetDefinitions[this];
    if (def == null) return;
    await settings.setFontFamily(def.fontFamily);
    await settings.setFontSize(def.fontSize);
    await settings.setLineSpacing(def.lineSpacing);
    await settings.setMenuScale(def.menuScale);
    await settings.setParagraphMode(def.paragraphMode);
    await settings.setCardMaterial(def.cardMaterial);
  }

  IconData get icon {
    switch (this) {
      case AppStylePreset.systemDefault:
        return Icons.devices_rounded;
      case AppStylePreset.classic:
        return Icons.menu_book_rounded;
      case AppStylePreset.modern:
        return Icons.tablet_mac_rounded;
      case AppStylePreset.reverent:
        return Icons.auto_stories_rounded;
      case AppStylePreset.compact:
        return Icons.density_small_rounded;
      case AppStylePreset.reader:
        return Icons.chrome_reader_mode_rounded;
      case AppStylePreset.liquidGlass:
        return Icons.blur_on_rounded;
      case AppStylePreset.paper:
        return Icons.note_alt_outlined;
      case AppStylePreset.carbon:
        return Icons.dark_mode_outlined;
    }
  }
}

/// Detect which preset, if any, the current settings most closely
/// match. Returns null when the user's settings don't line up
/// exactly with any preset (custom configuration). Used by the
/// Settings UI to show a check on the active preset card.
AppStylePreset? detectActivePreset(AppSettings s) {
  for (final entry in presetDefinitions.entries) {
    final d = entry.value;
    // Round 56 fix: compare against `fontSelection` (the catalogue
    // key, e.g. 'EB Garamond') NOT `fontFamily` (the resolved
    // Google-Fonts-registered family, e.g. 'EBGaramond_regular').
    // After the Google Fonts integration these two diverged, so
    // tapping Modern / Reverent / Reader correctly applied the
    // settings but the active-preset check always returned null,
    // leaving the card looking unselected. User feedback: "why
    // clicked modern or jingqian not showing selected".
    if (s.fontSelection == d.fontFamily &&
        (s.fontSize - d.fontSize).abs() < 0.01 &&
        (s.lineSpacing - d.lineSpacing).abs() < 0.01 &&
        (s.menuScale - d.menuScale).abs() < 0.01 &&
        s.paragraphMode == d.paragraphMode &&
        s.cardMaterial == d.cardMaterial) {
      return entry.key;
    }
  }
  return null;
}
