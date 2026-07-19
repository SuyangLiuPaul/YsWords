import 'package:yswords/constants/ui_strings.dart';

/// One reorderable / toggleable block on the dashboard.
///
/// The dashboard renders sections in the order persisted in
/// `AppSettings.dashboardSectionOrder` (driven by Settings →
/// "Dashboard layout"). Each section also has an independent
/// visibility flag on `AppSettings`. Sections may also have an
/// **implicit** hide condition (e.g. `resumeSermon` hides when no
/// sermon has been opened yet, `recentBookmarks` hides when there
/// are no bookmarks) — those are layered on top of the user's
/// explicit show/hide preference.
///
/// Adding a new section:
///   1. Add a value here
///   2. Append it to [defaultDashboardOrder]
///   3. Add a `show<Section>` flag + getter + setter on `AppSettings`
///   4. Add a builder for it in `dashboard_page.dart::_buildSections`
///   5. Add a label/description in [DashboardSectionLabel] extension
///   6. Add a default-on/off entry to [defaultVisibility]
enum DashboardSection {
  /// "Read Bible" hero. Primary CTA. Default on.
  readBible,

  /// "Resume sermon" hero — last-read sermon + progress. Default on
  /// (auto-hidden when no sermon has been opened).
  resumeSermon,

  /// Verse of the Day card. Default on (auto-hidden until the verse
  /// resolves on first paint).
  dailyVerse,

  // 2026-05-21 (v1.2.69): todayReading removed along with reading
  // plan feature.

  /// Three-column counts row: bookmarks / notes / highlights. Default
  /// on.
  counts,

  /// "Recent bookmarks" list (last 5). Default on (auto-hidden when
  /// the user has no bookmarks).
  recentBookmarks,

  /// "Today's Evidence" — one of 225 Bible-evidence entries rotating
  /// by day-of-year. Default on.
  todayEvidence,

  /// Quick-link tiles grid (Library / Statistics / Bible Evidence /
  /// Sermons / Family Tree / Bible Timeline / Settings). Default on.
  quickLinks,
}

/// Canonical default order. Used as the seed for new installs and
/// the "Reset to default" button. Also used to backfill any
/// sections the user's persisted list is missing (e.g. when we ship
/// a new section in a later release).
const List<DashboardSection> defaultDashboardOrder = <DashboardSection>[
  DashboardSection.readBible,
  DashboardSection.resumeSermon,
  DashboardSection.dailyVerse,
  DashboardSection.counts,
  DashboardSection.recentBookmarks,
  DashboardSection.todayEvidence,
  DashboardSection.quickLinks,
];

/// Default visibility for each section on a fresh install. Mirrors
/// the historic dashboard behavior — every block on, the user can
/// then turn things off in Settings.
const Map<DashboardSection, bool> defaultVisibility =
    <DashboardSection, bool>{
  DashboardSection.readBible: true,
  DashboardSection.resumeSermon: true,
  DashboardSection.dailyVerse: true,
  DashboardSection.counts: true,
  DashboardSection.recentBookmarks: true,
  DashboardSection.todayEvidence: true,
  DashboardSection.quickLinks: true,
};

/// Parse a persisted enum-name back into a [DashboardSection]. Returns
/// null when the name no longer corresponds to any known section
/// (e.g. user upgraded across a rename — we drop the unknown entry
/// and the default-merge logic fills it back in).
DashboardSection? parseDashboardSection(String name) {
  for (final s in DashboardSection.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// Take a stored list of enum-name strings and produce a clean
/// [DashboardSection] list:
///   • drop any unknown / duplicate names
///   • append any sections from [defaultDashboardOrder] that the
///     stored list is missing (so a new section we ship later shows
///     up at the bottom of the user's existing layout instead of
///     being silently invisible)
///
/// Always returns a complete list containing every enum value
/// exactly once.
List<DashboardSection> normalizeDashboardOrder(List<String> stored) {
  final seen = <DashboardSection>{};
  final out = <DashboardSection>[];
  for (final name in stored) {
    final s = parseDashboardSection(name);
    if (s == null || seen.contains(s)) continue;
    seen.add(s);
    out.add(s);
  }
  for (final s in defaultDashboardOrder) {
    if (!seen.contains(s)) {
      seen.add(s);
      out.add(s);
    }
  }
  return out;
}

extension DashboardSectionLabel on DashboardSection {
  /// Short human-readable name shown in the Settings reorder list and
  /// the "Reset to default" confirmation. Locale-aware via
  /// [uiStrings] — falls back to English when no entry is registered.
  String label(String locale) {
    final key = 'dashboardSection_${name}_label';
    return uiStrings[key]?[locale] ?? _enFallbackLabel;
  }

  /// One-line explanation shown beneath [label] in the Settings list.
  /// Helps the user understand what each block actually contains
  /// before they hide / reorder it.
  String description(String locale) {
    final key = 'dashboardSection_${name}_description';
    return uiStrings[key]?[locale] ?? _enFallbackDescription;
  }

  String get _enFallbackLabel {
    switch (this) {
      case DashboardSection.readBible:
        return 'Read Bible';
      case DashboardSection.resumeSermon:
        return 'Resume Sermon';
      case DashboardSection.dailyVerse:
        return 'Verse of the Day';
      case DashboardSection.counts:
        return 'Bookmarks / Notes / Highlights';
      case DashboardSection.recentBookmarks:
        return 'Recent Bookmarks';
      case DashboardSection.todayEvidence:
        return "Today's Evidence";
      case DashboardSection.quickLinks:
        return 'Quick Links';
    }
  }

  String get _enFallbackDescription {
    switch (this) {
      case DashboardSection.readBible:
        return 'Primary CTA — jump back to your last reading position.';
      case DashboardSection.resumeSermon:
        return 'Pick up where you left off in the last sermon you opened.';
      case DashboardSection.dailyVerse:
        return 'One curated verse per day, the same on every device.';
      case DashboardSection.counts:
        return 'Counts of bookmarks, notes, and highlights.';
      case DashboardSection.recentBookmarks:
        return 'Your five most recently bookmarked verses.';
      case DashboardSection.todayEvidence:
        return 'One archaeology / manuscript / science entry per day.';
      case DashboardSection.quickLinks:
        return 'Tiles linking to Library, Statistics, Sermons, etc.';
    }
  }
}
