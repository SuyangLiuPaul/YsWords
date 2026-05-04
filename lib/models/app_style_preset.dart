import 'package:flutter/material.dart';

import 'package:yswords/models/app_settings.dart';

/// Bundled-style "presets" that the user can apply with one tap.
/// Each preset bundles a coordinated set of visual settings —
/// fontFamily, fontSize, lineSpacing, menuScale, paragraphMode —
/// so the app's overall feel changes without the user having to
/// tune every field individually.
///
/// Round 56 user request: "now can change theme color, also should
/// have format style of the app, now is plain or something, and
/// all other style of the app which can be applied all inside
/// the app."
///
/// Adding a new preset:
///   1. Add an enum value
///   2. Add a definition in [presetDefinitions]
///   3. Add localized labels via uiStrings (`appStylePreset_<name>_label`,
///      `appStylePreset_<name>_description`)
enum AppStylePreset {
  /// Sans-serif Roboto, paragraph mode on, normal density.
  /// The original / default look.
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
}

/// Concrete settings bundle for one preset.
class AppStylePresetDef {
  final String fontFamily;
  final double fontSize;
  final double lineSpacing;
  final double menuScale;
  final bool paragraphMode;
  const AppStylePresetDef({
    required this.fontFamily,
    required this.fontSize,
    required this.lineSpacing,
    required this.menuScale,
    required this.paragraphMode,
  });
}

const Map<AppStylePreset, AppStylePresetDef> presetDefinitions = {
  AppStylePreset.classic: AppStylePresetDef(
    fontFamily: 'Roboto',
    fontSize: 20.0,
    lineSpacing: 1.5,
    menuScale: 1.0,
    paragraphMode: true,
  ),
  AppStylePreset.modern: AppStylePresetDef(
    fontFamily: 'system-ui',
    fontSize: 19.0,
    lineSpacing: 1.45,
    menuScale: 0.95,
    paragraphMode: true,
  ),
  AppStylePreset.reverent: AppStylePresetDef(
    fontFamily: 'Garamond',
    fontSize: 21.0,
    lineSpacing: 1.7,
    menuScale: 1.0,
    paragraphMode: true,
  ),
  AppStylePreset.compact: AppStylePresetDef(
    fontFamily: 'Roboto',
    fontSize: 16.0,
    lineSpacing: 1.3,
    menuScale: 0.85,
    paragraphMode: false,
  ),
  AppStylePreset.reader: AppStylePresetDef(
    fontFamily: 'Georgia',
    fontSize: 22.0,
    lineSpacing: 1.6,
    menuScale: 1.0,
    paragraphMode: true,
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
  }

  IconData get icon {
    switch (this) {
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
    if (s.fontFamily == d.fontFamily &&
        (s.fontSize - d.fontSize).abs() < 0.01 &&
        (s.lineSpacing - d.lineSpacing).abs() < 0.01 &&
        (s.menuScale - d.menuScale).abs() < 0.01 &&
        s.paragraphMode == d.paragraphMode) {
      return entry.key;
    }
  }
  return null;
}
