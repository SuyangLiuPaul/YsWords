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

  /// "Featured" — the church's own media: 獨一真神 and Songs.
  ///
  /// 2026-08-11, at the user's request, and added as a SECTION rather
  /// than hard-coded above Today's Evidence. The dashboard has had
  /// reorder + per-section visibility since Round 55, so writing the
  /// order into the widget tree would have taken that control away for
  /// exactly the block the user cares most about. Default on, and it
  /// sits above todayEvidence in [defaultDashboardOrder].
  featured,

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
  DashboardSection.featured,
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
  DashboardSection.featured: true,
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
///     stored list is missing, placed **where [defaultDashboardOrder]
///     puts it relative to the sections the user already has** — not
///     appended to the end
///
/// That last point changed on 2026-08-11 and it matters. Appending was
/// the old behaviour, and it meant a new section's default position
/// only ever applied to fresh installs: anyone already using the app
/// got it dumped at the bottom, under the quick links. Shipping
/// `featured` "above Today's Evidence" would then have been true of
/// nobody who had ever opened the app before. A new section now lands
/// immediately before the first section that follows it in the default
/// order and that the user actually has — and falls back to the end
/// only when there is no such anchor.
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
    if (seen.contains(s)) continue;
    seen.add(s);

    // Where does the default order say this belongs? Insert it before
    // the nearest section that follows it there and is already placed.
    final defaultIdx = defaultDashboardOrder.indexOf(s);
    var at = out.length;
    for (var i = defaultIdx + 1; i < defaultDashboardOrder.length; i++) {
      final anchor = out.indexOf(defaultDashboardOrder[i]);
      if (anchor >= 0) {
        at = anchor;
        break;
      }
    }
    out.insert(at, s);
  }
  return out;
}

/// Sections the dashboard drops when they have nothing to show — even
/// though their Settings switch is ON.
///
/// 2026-08-25, reported by the user: "设置里面的主页布局的位置和主页真实
/// 位置是不一样的，这个不是应该一致吗". They were right, and it is not a
/// reordering bug — Settings and the dashboard read the SAME
/// `dashboardSectionOrder`. The mismatch is that
/// `dashboard_page.dart::_buildSection` returns null for a section with
/// no content, so on a fresh install Settings lists eight rows, all
/// switched on, and the home page renders six. Nothing on the Settings
/// row said why, so a switch that is on and a block that is absent read
/// as a bug in the ordering.
///
/// Deliberately only these two. `dailyVerse` and `todayEvidence` also
/// return null while their data loads, but that is a transient state
/// measured in milliseconds, not a durable "you have none of these" —
/// captioning them would tell the user something that stops being true
/// before they finish reading it.
extension DashboardSectionAutoHide on DashboardSection {
  bool get hidesWhenEmpty =>
      this == DashboardSection.resumeSermon ||
      this == DashboardSection.recentBookmarks;

  /// uiStrings key explaining why this section is not on screen right
  /// now. Only meaningful when [hidesWhenEmpty] and the data is empty.
  String get emptyReasonKey => 'dashboardSection_${name}_emptyReason';
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
      case DashboardSection.featured:
        return 'Featured';
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
      case DashboardSection.featured:
        return "The church's own media — the video teaching and the songs "
            'directory.';
      case DashboardSection.todayEvidence:
        return 'One archaeology / manuscript / science entry per day.';
      case DashboardSection.quickLinks:
        return 'Tiles linking to Library, Statistics, Sermons, etc.';
    }
  }
}
