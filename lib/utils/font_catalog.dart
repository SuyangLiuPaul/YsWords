import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';

import 'package:yswords/constants/build_flags.dart';

/// Round 56: central font catalogue for the Settings → Font Family
/// dropdown.
///
/// Why this file exists:
/// Flutter on web (CanvasKit) cannot render CSS-only system fonts
/// — picking "Times New Roman" or "Georgia" used to silently fall
/// back to Roboto because no font asset was loaded for those names.
/// We ship one bundled font (Roboto) plus a
/// curated set of Google Fonts that the `google_fonts` package
/// downloads + registers at runtime. The user's selection still
/// roundtrips as a stable string key in SharedPreferences (e.g.
/// `'EB Garamond'`), and [resolveFontFamily] turns that key into
/// the actual registered family name (e.g. `'EBGaramond_regular'`)
/// that TextStyle's `fontFamily` field needs.
///
/// User-facing behaviour:
/// • Roboto always works (bundled; offline-safe).
/// • Google Fonts work as long as the device has internet on first
///   use; afterwards the package caches them locally.
/// • System-only options (PingFang SC, SimSun, Heiti SC, …) are
///   marked as `isSystemFont: true` and rendered with a CSS-style
///   family name; on Apple/Windows where the font is installed the
///   browser will use it, otherwise they fall back to the engine's
///   default. We keep them so users on those platforms can still
///   pick their preferred local font.

class FontOption {
  /// Stable identifier — what gets persisted in SharedPreferences.
  final String key;

  /// Display label shown in the dropdown row.
  final Map<String, String> label;

  /// True for fonts shipped as bundled assets in pubspec.yaml.
  /// These work offline and on all platforms.
  final bool isBundled;

  /// True for fonts pulled from Google Fonts at runtime.
  /// Require internet on first use.
  final bool isGoogleFont;

  /// Loose category for the optional grouping divider.
  final FontCategory category;

  const FontOption({
    required this.key,
    required this.label,
    this.isBundled = false,
    this.isGoogleFont = false,
    this.category = FontCategory.englishSerif,
  });

  String labelFor(String locale) =>
      label[locale] ?? label['en'] ?? key;
}

enum FontCategory { bundled, englishSerif, englishSans, chinese, system }

/// 2026-05-22 (v1.2.71): comprehensive CJK font fallback chain. When a
/// TextStyle sets `fontFamily: settings.fontFamily` it should also set
/// `fontFamilyFallback: kCjkFontFallback` so rare Chinese characters
/// (e.g. `赒` U+8D52 in Acts 10:2, `䍁` U+4341, `𨱔` U+28C54) render
/// even if the primary font's subset doesn't include them.
///
/// 2026-05-24 (v1.3.31): The first entry `NotoSansSC-YsWords` is a
/// BUNDLED font subset (assets/fonts/NotoSansSC-YsWords.otf) covering
/// every CJK character used anywhere in the app. It's the only entry
/// in this list that Flutter web's CanvasKit renderer can actually
/// see — the rest are CSS names that only work on native iOS / macOS /
/// Android (where the OS fonts are accessible) or when the browser's
/// HTML renderer is active. CanvasKit needs fonts loaded into its
/// Skia font registry, and `fonts:` declarations in `pubspec.yaml`
/// are the standard way to register a font. Without this first entry
/// the user would see "X" tofu glyphs for rare characters on the web
/// build even though the chain has 20+ candidates.
///
/// Order rationale:
///   • Bundled → `NotoSansSC-YsWords` (registered via pubspec, web-safe)
///   • Apple system → PingFang SC / Heiti SC — complete CJK on macOS/iOS
///   • Apple legacy → STSong / STFangsong
///   • Windows → Microsoft YaHei
///   • Google web → Noto Sans SC / Noto Serif SC — also complete
///   • Generic CSS → sans-serif (browser picks)
const List<String> kCjkFontFallback = [
  // 2026-06-16: Latin UI faces FIRST so Latin glyphs render in a clean
  // sans-serif on native desktop (Windows → Segoe UI; bundled Roboto
  // elsewhere) instead of falling through to a CJK serif (SimSun 宋体)
  // when the `-apple-system` token can't be resolved by the native
  // Skia engine. Per-glyph fallback means CJK characters skip these
  // (no Latin-only font has the glyph) and still resolve via the CJK
  // families below. Web/CanvasKit skips the unresolvable system names
  // and uses bundled Roboto for Latin, then NotoSansSC-YsWords for CJK
  // — so this is safe on web too.
  'Segoe UI',
  'Roboto',
  'SF Pro Text',
  'Helvetica Neue',
  'Arial',
  // FIRST CJK: the bundled subset — the only CJK fallback that CanvasKit
  // can resolve on Flutter web. See `pubspec.yaml` for the bundle
  // declaration + the build script `tools/build_cjk_font_subset.sh`.
  'NotoSansSC-YsWords',
  // After: native-platform / browser-CSS fallbacks. These work on
  // iOS / macOS / Android where Flutter can access OS-installed fonts,
  // and on the HTML renderer (not CanvasKit) where the browser
  // honours CSS font names. Kept as defence-in-depth.
  'PingFang SC',
  'PingFang TC',
  'Heiti SC',
  'Heiti TC',
  'STSong',
  'STFangsong',
  'STHeiti',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  '微软雅黑',
  'Source Han Sans SC',
  'Source Han Sans TC',
  '思源黑体',
  'Noto Sans SC',
  'Noto Sans TC',
  'Noto Sans CJK SC',
  'Noto Sans CJK TC',
  'Noto Serif SC',
  'Noto Serif TC',
  'SimSun',
  '宋体',
  'sans-serif',
];

const List<FontOption> _catalog = [
  // ── System default (preferred default since v1.1.2) ──────────────
  // Routes through the OS's native UI font via the CSS font-stack
  // chain configured in main.dart's `fontFamilyFallback`. Apple
  // devices render in San Francisco, Windows in Segoe UI, Android
  // in Roboto, Linux in Cantarell / Noto Sans, etc. — every user
  // sees their own system's typography out of the box, no setting
  // change needed.
  //
  // The `key` field is treated as a special token by
  // `resolveFontFamily` below: when it equals `'system'` we return
  // an empty string so Flutter falls all the way through the
  // `fontFamilyFallback` list configured in `main.dart` (which
  // starts with `-apple-system`, then `BlinkMacSystemFont`, then
  // OS-specific candidates, then bundled Roboto as a last resort).
  FontOption(
    key: 'system',
    label: {
      'en': 'System default',
      'zh-Hans': '系统默认',
      'zh-Hant': '系統預設',
    },
    isBundled: true,
    category: FontCategory.bundled,
  ),
  // ── Bundled (works everywhere, offline) ──────────────────────────
  FontOption(
    key: 'Roboto',
    label: {
      'en': 'Roboto',
      'zh-Hans': 'Roboto',
      'zh-Hant': 'Roboto',
    },
    isBundled: true,
    category: FontCategory.bundled,
  ),
  // Microsoft YaHei was previously a bundled option here. Removed in
  // 2026-05 because it is a proprietary Microsoft font and the
  // licence forbids redistribution. Chinese readers should pick
  // Noto Sans SC / Noto Serif SC instead (SIL OFL, freely
  // distributable). The migration in [migrateLegacyFontKey] below
  // routes any saved 'Microsoft YaHei' selection to Noto Sans SC so
  // existing users don't see a blank font setting on next launch.

  // ── Google Fonts (English serif) ─────────────────────────────────
  FontOption(
    key: 'EB Garamond',
    label: {
      'en': 'EB Garamond (serif / classic)',
      'zh-Hans': 'EB Garamond（衬线 / 经典）',
      'zh-Hant': 'EB Garamond（襯線 / 經典）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSerif,
  ),
  FontOption(
    key: 'Lora',
    label: {
      'en': 'Lora (serif / readable)',
      'zh-Hans': 'Lora（衬线 / 易读）',
      'zh-Hant': 'Lora（襯線 / 易讀）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSerif,
  ),
  FontOption(
    key: 'Merriweather',
    label: {
      'en': 'Merriweather (serif / book)',
      'zh-Hans': 'Merriweather（衬线 / 书本）',
      'zh-Hant': 'Merriweather（襯線 / 書本）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSerif,
  ),
  FontOption(
    key: 'Crimson Pro',
    label: {
      'en': 'Crimson Pro (serif / elegant)',
      'zh-Hans': 'Crimson Pro（衬线 / 优雅）',
      'zh-Hant': 'Crimson Pro（襯線 / 優雅）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSerif,
  ),
  FontOption(
    key: 'Playfair Display',
    label: {
      'en': 'Playfair Display (serif / display)',
      'zh-Hans': 'Playfair Display（衬线 / 展示）',
      'zh-Hant': 'Playfair Display（襯線 / 展示）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSerif,
  ),

  // ── Google Fonts (English sans-serif) ────────────────────────────
  FontOption(
    key: 'Open Sans',
    label: {
      'en': 'Open Sans (sans-serif / friendly)',
      'zh-Hans': 'Open Sans（无衬线 / 友好）',
      'zh-Hant': 'Open Sans（無襯線 / 友好）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSans,
  ),
  FontOption(
    key: 'Inter',
    label: {
      'en': 'Inter (sans-serif / modern)',
      'zh-Hans': 'Inter（无衬线 / 现代）',
      'zh-Hant': 'Inter（無襯線 / 現代）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSans,
  ),
  FontOption(
    key: 'Lato',
    label: {
      'en': 'Lato (sans-serif / neutral)',
      'zh-Hans': 'Lato（无衬线 / 中性）',
      'zh-Hant': 'Lato（無襯線 / 中性）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSans,
  ),
  FontOption(
    key: 'Nunito',
    label: {
      'en': 'Nunito (sans-serif / soft)',
      'zh-Hans': 'Nunito（无衬线 / 柔和）',
      'zh-Hant': 'Nunito（無襯線 / 柔和）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSans,
  ),
  FontOption(
    key: 'Montserrat',
    label: {
      'en': 'Montserrat (sans-serif / geometric)',
      'zh-Hans': 'Montserrat（无衬线 / 几何）',
      'zh-Hant': 'Montserrat（無襯線 / 幾何）',
    },
    isGoogleFont: true,
    category: FontCategory.englishSans,
  ),

  // ── Google Fonts (Chinese / CJK) ─────────────────────────────────
  FontOption(
    key: 'Noto Serif SC',
    label: {
      'en': 'Noto Serif SC (Chinese serif)',
      'zh-Hans': '思源宋体（中文衬线）',
      'zh-Hant': '思源宋體（中文襯線）',
    },
    isGoogleFont: true,
    category: FontCategory.chinese,
  ),
  FontOption(
    key: 'Noto Sans SC',
    label: {
      'en': 'Noto Sans SC (Chinese sans-serif)',
      'zh-Hans': '思源黑体（中文黑体）',
      'zh-Hant': '思源黑體（中文黑體）',
    },
    isGoogleFont: true,
    category: FontCategory.chinese,
  ),
  FontOption(
    key: 'ZCOOL XiaoWei',
    label: {
      'en': 'ZCOOL XiaoWei (Chinese stylish)',
      'zh-Hans': '站酷小薇（中文）',
      'zh-Hant': '站酷小薇（中文）',
    },
    isGoogleFont: true,
    category: FontCategory.chinese,
  ),
  FontOption(
    key: 'Ma Shan Zheng',
    label: {
      'en': 'Ma Shan Zheng (Chinese brush)',
      'zh-Hans': '马善政楷书（中文毛笔）',
      'zh-Hant': '馬善政楷書（中文毛筆）',
    },
    isGoogleFont: true,
    category: FontCategory.chinese,
  ),

  // ── System fonts (best-effort fallback) ──────────────────────────
  // Kept for users on platforms that ship them locally; if the
  // engine can't find them it falls back to the theme default.
  FontOption(
    key: 'PingFang SC',
    label: {
      'en': 'PingFang SC (Apple devices)',
      'zh-Hans': '苹方（Apple 设备）',
      'zh-Hant': '蘋方（Apple 設備）',
    },
    category: FontCategory.system,
  ),
  FontOption(
    key: 'SimSun',
    label: {
      'en': 'SimSun (Windows classic)',
      'zh-Hans': '宋体（Windows 经典）',
      'zh-Hant': '宋體（Windows 經典）',
    },
    category: FontCategory.system,
  ),
];

/// Public list ordered for the dropdown.
///
/// 2026-05-09 (v1.2.0 — China mode): Google Fonts options are
/// hidden from the picker when [kChinaMode] is true.
/// `fonts.googleapis.com` / `fonts.gstatic.com` are blocked by
/// the Great Firewall, so picking one would silently fail. The
/// "System default" + bundled Roboto + system-installed Chinese
/// fonts cover every realistic case for users in mainland China.
List<FontOption> availableFontOptions() {
  if (!kChinaMode) return List.unmodifiable(_catalog);
  return List.unmodifiable(
    _catalog.where((opt) => !opt.isGoogleFont),
  );
}

/// Whether [key] points at a real entry in the catalogue.
/// Used by [AppSettings.loadSettings] to migrate users whose stored
/// `fontFamily` came from the legacy catalogue (Times New Roman,
/// Garamond, system-ui, …) — those keys would crash the dropdown
/// because no item matches the assigned `value:`.
bool isValidFontKey(String key) {
  for (final f in _catalog) {
    if (f.key == key) return true;
  }
  return false;
}

/// Migrate a legacy / unknown selection key to the closest catalogue
/// entry. Used at startup to repair settings stored before the
/// Round 56 font-catalogue refresh. Falls back to Roboto when nothing
/// reasonable matches.
String migrateLegacyFontKey(String stored) {
  // 2026-05-09 (v1.2.0 — China mode): in the China build, any
  // Google-Fonts key the user previously picked on the
  // international build is unreachable (`fonts.googleapis.com` is
  // blocked). Migrate those to `'system'` so the OS-native font
  // stack handles rendering instead of silently failing.
  if (kChinaMode) {
    final opt = _catalog.firstWhere(
      (o) => o.key == stored,
      orElse: () => const FontOption(
          key: '__missing__', label: {}, category: FontCategory.bundled),
    );
    if (opt.isGoogleFont) return 'system';
  }
  if (isValidFontKey(stored)) return stored;
  // Map known legacy keys to their nearest current equivalent.
  const migrations = {
    // Old serif options → closest Google Font serif.
    'Times New Roman': 'EB Garamond',
    'Garamond': 'EB Garamond',
    'Georgia': 'Lora',
    'Palatino': 'Merriweather',
    // Old sans-serif options.
    'Arial': 'Open Sans',
    'Helvetica': 'Inter',
    'Verdana': 'Lato',
    'system-ui': 'Inter',
    // Chinese options that were dropped.
    'Source Han Sans CN': 'Noto Sans SC',
    'Heiti SC': 'Noto Sans SC',
    'KaiTi': 'Noto Serif SC',
    // Microsoft YaHei removed in 2026-05 (proprietary font, licence
    // forbids redistribution). Existing users get Noto Sans SC, the
    // closest Chinese sans-serif equivalent.
    'Microsoft YaHei': 'Noto Sans SC',
  };
  final mapped = migrations[stored];
  if (mapped != null && isValidFontKey(mapped)) return mapped;
  return 'Roboto';
}

/// Look up the catalogue entry for a stored key. Falls back to the
/// first entry (Roboto) if the key isn't recognized — defensive
/// against schema drift if a Google Font option is later removed
/// from the catalogue.
FontOption fontOptionFor(String key) {
  for (final f in _catalog) {
    if (f.key == key) return f;
  }
  return _catalog.first;
}

/// Resolve a stored selection key to the actual font family name
/// that TextStyle's `fontFamily` parameter expects.
///
/// • For bundled fonts ([FontOption.isBundled]) the key matches the
///   pubspec `family:` declaration, so we return it as-is.
/// • For Google Fonts we ask the package to register the font and
///   return the family name it assigned (this is a synchronous call
///   that kicks off an async download in the background; the
///   TextStyle remains valid even before the bytes arrive — the
///   font just appears once they do).
/// • For system fonts we return the key directly; the engine /
///   browser will pick it up if installed locally.
String resolveFontFamily(String key) {
  // 2026-05-08 (v1.1.2): the special `'system'` key resolves to the
  // first entry of the OS-native CSS font-stack chain. The full
  // chain lives in `main.dart`'s `fontFamilyFallback` argument; on
  // any platform where the leading family is missing, Flutter walks
  // the list until it finds one. The Apple-first ordering means
  // macOS / iOS get San Francisco, Windows gets Segoe UI, Android
  // gets Roboto, Linux gets Cantarell / Noto Sans — without any
  // app-side detection logic.
  // On Flutter web a browser resolves the CSS pseudo-token `-apple-system`
  // to the OS UI font. The native (Windows/macOS/Linux) Skia engine matches
  // real installed family names only and silently drops `-apple-system`, so
  // returning it there makes Latin text fall through to a CJK serif. Return
  // an empty family on native so Flutter walks `fontFamilyFallback` cleanly
  // (which leads with Segoe UI / bundled Roboto). Use `kIsWeb` to stay web-safe.
  if (key == 'system') return kIsWeb ? '-apple-system' : '';
  final option = fontOptionFor(key);
  if (option.isGoogleFont) {
    try {
      final ts = GoogleFonts.getFont(option.key);
      return ts.fontFamily ?? option.key;
    } catch (e) {
      // 2026-05-09 (v1.2.2): previously swallowed silently, which
      // hid intermittent fonts.googleapis.com 403 / network blips
      // from anyone watching DevTools. The CSS fallback (returning
      // option.key) is still the right user-facing behaviour, but
      // log it so production monitoring can catch repeated
      // failures.
      debugPrint('[font_catalog] GoogleFonts.getFont(${option.key}) failed: $e');
      return option.key;
    }
  }
  return option.key;
}

/// Build a TextStyle that previews [key] in its own font, so the
/// dropdown row physically looks like the font it advertises. The
/// caller passes a base style (size/color) and we layer the family
/// on top.
TextStyle previewTextStyle(String key, TextStyle base) {
  if (key == 'system') {
    // System default → preview in the leading CSS font-stack token
    // so the row demonstrates the look the user will get. On native the
    // token is unresolvable, so fall through to fontFamilyFallback (empty
    // family) rather than hard-missing onto a CJK serif. Web-safe via kIsWeb.
    return base.copyWith(fontFamily: kIsWeb ? '-apple-system' : '');
  }
  final option = fontOptionFor(key);
  if (option.isGoogleFont) {
    try {
      return GoogleFonts.getFont(option.key, textStyle: base);
    } catch (e) {
      debugPrint('[font_catalog] previewTextStyle(${option.key}) failed: $e');
      return base.copyWith(fontFamily: option.key);
    }
  }
  return base.copyWith(fontFamily: option.key);
}
