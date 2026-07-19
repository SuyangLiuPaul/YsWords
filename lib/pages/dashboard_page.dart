import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/utils/short_book_name.dart' show shortBookName;
import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/dashboard_section.dart';
import 'package:yswords/models/sermon.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/pages/evidence_detail_page.dart';
import 'package:yswords/pages/evidence_page.dart';
import 'package:yswords/pages/bible_timeline_page.dart';
import 'package:yswords/pages/bible_trivia_page.dart';
import 'package:yswords/pages/family_tree_page.dart';
import 'package:yswords/pages/sermon_detail_page.dart';
import 'package:yswords/pages/sermons_page.dart';
import 'package:yswords/widgets/liquid_glass.dart';
import 'package:yswords/pages/highlights_page.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/library_page.dart';
import 'package:yswords/pages/feedback_page.dart';
import 'package:yswords/pages/search_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/pages/stats_page.dart';
import 'package:yswords/services/bible_evidence_service.dart';
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/realtime_db_sync_service.dart';
import 'package:yswords/services/daily_verse_fallback.dart';
import 'package:yswords/services/daily_verse_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/passage_localizer.dart' show localizePassage;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/widgets/left_accent_card.dart';
import 'package:yswords/widgets/onboarding_dialog.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Personal "home" / dashboard. Shows the signed-in user's reading
/// state at a glance:
///   • Greeting with profile name + sync-status badge
///   • Today's reading from the active plan (or pick-a-plan CTA)
///   • Counts for bookmarks / notes / highlights
///   • Recent bookmarks (last 5)
///   • Quick-link tiles to Library / Statistics / Settings
///
/// Reachable from the floating-header overflow menu's "Home" entry.
/// Doesn't replace the bible-reading surface — it's an opt-in
/// landing page for users who want a personal overview.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Verse? _dailyVerse;
  /// Set when [_dailyVerse] was resolved from a fallback bundle
  /// (e.g. user is on LJK1, today's verse is OT, we pulled it from
  /// CUVS-YHWH). Holds the friendly label of the source version so
  /// the UI can show a "via {version}" note. null when the verse
  /// came from the user's own selected version as normal.
  String? _dailyVerseFromVersionLabel;
  /// Cached canonical English ref ("John 3:16") loaded once from the
  /// asset. Kept separate from [_dailyVerse] so a Bible-version
  /// switch can re-resolve the verse text without re-fetching the
  /// reference list.
  String? _dailyVerseRef;
  /// Today's spotlight from the Biblical Evidence Archive (one of
  /// 225, deterministic by day-of-year so all devices see the same
  /// item). Loaded lazily so the dashboard renders before the
  /// 1.5 MB asset finishes parsing.
  BibleEvidence? _dailyEvidence;

  /// The sermon the user was most recently reading (persisted in
  /// SharedPreferences as `sermons_last_read`). null when the user
  /// has never opened a sermon. Drives the "Resume sermon" hero just
  /// below the Bible "Continue reading" CTA.
  Sermon? _resumeSermon;

  /// Best-known scroll progress for [_resumeSermon] in the user's UI
  /// locale (0.0–1.0). Computed from the per-sermon
  /// `sermonScroll:<id>:<lang>` + `:max` keys written by
  /// `sermon_detail_page.dart`. Null when no offset has been saved
  /// for that sermon (just opened, never scrolled, or the body is
  /// shorter than the 24 px threshold the detail page bypasses).
  double? _resumeProgress;

  @override
  void initState() {
    super.initState();
    ProfileService.instance.addListener(_onProfileOrAuthChanged);
    CloudAuthService.instance.addListener(_onProfileOrAuthChanged);
    RealtimeDbSyncService.instance.addListener(_onProfileOrAuthChanged);
    _loadDailyVerse();
    _loadDailyEvidence();
    _loadResumeSermon();
    _maybeShowOnboarding();
  }

  Future<void> _loadDailyEvidence() async {
    final list = await BibleEvidenceService.all();
    if (!mounted) return;
    setState(() {
      _dailyEvidence = BibleEvidenceService.todayEvidence(list);
    });
  }

  /// Resolve the user's last-read sermon (if any) for the "Resume
  /// sermon" hero. We read [`sermons_last_read`] from
  /// SharedPreferences (written by `sermons_page.dart::_openSermon`),
  /// look up that id in the bundled index, and compute scroll
  /// progress from the per-sermon
  /// `sermonScroll:<id>:<lang>` / `:max` keys written by
  /// `sermon_detail_page.dart`.
  ///
  /// All three reads happen in parallel via SharedPreferences's
  /// in-memory cache (the singleton is initialised by `main.dart` /
  /// `AppSettings`), so this is sub-millisecond and safe to call on
  /// every dashboard mount + locale change.
  Future<void> _loadResumeSermon() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('sermons_last_read');
    if (lastId == null || lastId.isEmpty) {
      if (!mounted) return;
      if (_resumeSermon != null) {
        setState(() {
          _resumeSermon = null;
          _resumeProgress = null;
        });
      }
      return;
    }
    Sermon? hit;
    try {
      final all = await SermonService.instance.loadIndex();
      // Use a manual loop instead of firstWhere with `orElse` so we
      // can return null cleanly when the saved id no longer matches
      // any sermon (e.g. corpus re-ingestion dropped that id).
      for (final s in all) {
        if (s.id == lastId) {
          hit = s;
          break;
        }
      }
    } catch (_) {
      hit = null;
    }
    if (!mounted) return;
    if (hit == null) {
      setState(() {
        _resumeSermon = null;
        _resumeProgress = null;
      });
      return;
    }
    // Pick the language code that the sermon detail page most likely
    // wrote against, falling back so a user who reads in 简 but
    // briefly toggled to 繁 still sees a non-zero meter.
    final settings = context.read<AppSettings>();
    final preferred = settings.locale == 'zh-Hant'
        ? 'zh-TW'
        : settings.locale.startsWith('zh')
            ? 'zh-CN'
            : 'en';
    final candidates = <String>{preferred, 'en', 'zh-CN', 'zh-TW'};
    double? progress;
    for (final lang in candidates) {
      final key = 'sermonScroll:${hit.id}:$lang';
      final px = prefs.getDouble(key);
      final max = prefs.getDouble('$key:max');
      if (px != null && max != null && max > 0) {
        progress = (px / max).clamp(0.0, 1.0);
        break;
      }
    }
    setState(() {
      _resumeSermon = hit;
      _resumeProgress = progress;
    });
  }

  /// Open the saved sermon and refresh the resume state when the
  /// user returns. Mirrors `sermons_page._openSermon` so the same
  /// session-progress invariants apply (id is already saved; the
  /// detail page will write a fresh offset on dispose).
  Future<void> _openResumeSermon(Sermon s) async {
    await Get.to(
      () => SermonDetailPage(sermon: s),
      transition: Transition.rightToLeft,
    );
    if (!mounted) return;
    // Pull the new scroll offset (the detail page wrote it on
    // dispose) so the meter on the dashboard immediately reflects
    // what the user just did.
    await _loadResumeSermon();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always re-resolve. Cheap (early-bails when verses are empty,
    // setStates only when the resolved Verse actually differs from
    // the cached one). Handles every flavour of MainProvider
    // notify: setVersion (currentVersion changed, verses still old),
    // setVerses (verses replaced after fetch), and benign
    // notifyListeners from highlight/note saves.
    _resolveDailyVerse();
  }

  /// Show the 4-slide onboarding tour the first time the dashboard
  /// mounts on a given device. Flagged in SharedPreferences so the
  /// dialog never re-appears (until we bump the version key).
  Future<void> _maybeShowOnboarding() async {
    final seen = await OnboardingDialog.hasSeen();
    if (seen || !mounted) return;
    // Wait one frame so the dashboard scaffold is fully built before
    // we try to push a Dialog over it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const OnboardingDialog(),
      );
    });
  }

  /// Load today's curated reference once (asset is small, cached
  /// in service after first call), then resolve via
  /// [_resolveDailyVerse]. Called from initState; the version-change
  /// listener takes care of re-resolving when the user switches.
  Future<void> _loadDailyVerse() async {
    final ref = await DailyVerseService.todayRef();
    if (!mounted || ref == null) return;
    setState(() => _dailyVerseRef = ref);
    _resolveDailyVerse();
  }

  /// Resolve [_dailyVerseRef] against the currently-loaded Bible
  /// version. Re-run whenever the user switches version (or the
  /// initial verse list finishes loading) so the verse text always
  /// matches what they're reading.
  ///
  /// IMPORTANT: this gets called from [didChangeDependencies], which
  /// fires twice on a version switch — once for `setVersion` (verses
  /// still old) and again for the post-fetch `setVerses` (verses
  /// new). The first fire would resolve against stale data and
  /// potentially set _dailyVerse to null; we guard with
  /// `mp.verses.isEmpty` AND only blank out _dailyVerse when we
  /// confirm there really is no match for the *current* version
  /// (i.e. mp.verses is non-empty). Otherwise we leave the previous
  /// value alone until the verses actually arrive.
  void _resolveDailyVerse() {
    final ref = _dailyVerseRef;
    if (ref == null) return;
    final parsed = parseReference(ref);
    if (parsed == null) return;
    final mp = context.read<MainProvider>();
    if (mp.verses.isEmpty) return;
    final localBook =
        translateBookName(parsed.englishBook, mp.currentVersion);
    final targetVerse = parsed.verseStart ?? 1;
    Verse? match;
    for (final v in mp.verses) {
      if (v.book == localBook &&
          v.chapter == parsed.chapter &&
          v.verse == targetVerse) {
        match = v;
        break;
      }
    }
    if (!mounted) return;
    if (match != null) {
      if (match.book != _dailyVerse?.book ||
          match.text != _dailyVerse?.text) {
        setState(() {
          _dailyVerse = match;
          _dailyVerseFromVersionLabel = null;
        });
      }
      return;
    }
    // Primary lookup missed — usually because the user is reading on
    // an NT-only edition (LJK1 / LJK2) and today's verse is OT.
    // Pull from the same-language full-canon fallback (CUVS-YHWH /
    // CUVS-YHWH-TR) and label the card so the user knows the text
    // came from a different version than what they're reading.
    DailyVerseFallback.resolve(
      englishBook: parsed.englishBook,
      chapter: parsed.chapter,
      verseNumber: targetVerse,
      currentVersion: mp.currentVersion,
    ).then((result) {
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _dailyVerse = null;
          _dailyVerseFromVersionLabel = null;
        });
        return;
      }
      setState(() {
        _dailyVerse = result.verse;
        _dailyVerseFromVersionLabel =
            DailyVerseFallback.fallbackVersionLabel(mp.currentVersion);
      });
    });
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_onProfileOrAuthChanged);
    CloudAuthService.instance.removeListener(_onProfileOrAuthChanged);
    RealtimeDbSyncService.instance.removeListener(_onProfileOrAuthChanged);
    super.dispose();
  }

  void _onProfileOrAuthChanged() {
    if (!mounted) return;
    // 2026-05-25 (v1.3.44): re-run the resume-sermon resolver so
    // that when RealtimeDbSyncService delivers a new `lastRead`
    // blob (which now carries `sermonId` and mirrors it to the
    // unscoped `sermons_last_read` key), the dashboard's
    // "继续讲道" card actually updates on the receiving device.
    // Previously this listener just did setState — the card's
    // `_resumeSermon` field is cached in state and never refreshed
    // mid-session, so the card stayed null/stale.
    // ignore: unawaited_futures
    _loadResumeSermon();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final mainProvider = context.watch<MainProvider>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;

    // After Round 36 the Dashboard is *always* the navigator root
    // (the floating-header "Home" entry pops to first instead of
    // pushing a duplicate). Hard-disable the back arrow here so a
    // weirdly-stacked navigator never sneaks one in.
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    // Cap reading width on iPad / desktop so the dashboard doesn't
    // become a row of stretched, half-empty cards. Same constraint
    // pattern used in Settings keeps the app's wide-screen feel
    // consistent.
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);
    final isWide = MediaQuery.of(context).size.width >= 720;
    // Round 36: every header/label scales with settings.fontSize.
    // Caps prevent very-large reader settings (24-40 pt) from
    // making chrome tower over the cards.
    final headerSize =
        (settings.fontSize - 1).clamp(12.0, 22.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: null,
        title: Text(uiStrings['home']?[locale] ?? 'Home'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: RefreshIndicator(
            onRefresh: _pullToRefresh,
            child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── DASHBOARD SECTIONS (customizable order + visibility) ──
          // The user controls both the render order and which blocks
          // are visible via Settings → "Dashboard layout" (round 55).
          // We walk `settings.dashboardSectionOrder` and emit each
          // section that is both explicitly enabled AND has content
          // to show. Spacing is inserted between non-null blocks.
          ..._buildOrderedSections(
            order: settings.dashboardSectionOrder,
            settings: settings,
            mainProvider: mainProvider,
            scheme: scheme,
            locale: locale,
            isWide: isWide,
            headerSize: headerSize,
          ),
        ],
      ),
        ),
        ),
      ),
    );
  }

  /// Walk the user's [DashboardSection] order, build each visible
  /// section, and intersperse spacing. Sections with no content
  /// (e.g. resumeSermon when no sermon was opened, dailyVerse before
  /// first paint, recentBookmarks when bookmarks are empty) emit
  /// `null` and are skipped — the spacing is only inserted between
  /// adjacent non-null blocks so a hidden section doesn't leave a
  /// dead gap.
  List<Widget> _buildOrderedSections({
    required List<DashboardSection> order,
    required AppSettings settings,
    required MainProvider mainProvider,
    required ColorScheme scheme,
    required String locale,
    required bool isWide,
    required double headerSize,
  }) {
    final widgets = <Widget>[];
    var first = true;
    for (final section in order) {
      if (!settings.isDashboardSectionVisible(section)) continue;
      final w = _buildSection(
        section: section,
        settings: settings,
        mainProvider: mainProvider,
        scheme: scheme,
        locale: locale,
        isWide: isWide,
        headerSize: headerSize,
      );
      if (w == null) continue;
      if (!first) {
        widgets.add(const SizedBox(height: 20));
      }
      first = false;
      widgets.add(w);
    }
    return widgets;
  }

  /// Build one [DashboardSection] block. Returns null when the
  /// section has no content to show (so the caller can skip the
  /// inter-section spacing).
  Widget? _buildSection({
    required DashboardSection section,
    required AppSettings settings,
    required MainProvider mainProvider,
    required ColorScheme scheme,
    required String locale,
    required bool isWide,
    required double headerSize,
  }) {
    switch (section) {
      case DashboardSection.readBible:
        return _ContinueReadingHero(
          book: mainProvider.currentBook,
          chapter: mainProvider.currentChapter,
          currentVersion: mainProvider.currentVersion,
          locale: locale,
          settings: settings,
          onTap: () => Get.to(
            () => const HomePage(),
            transition: Transition.rightToLeft,
          ),
        );

      case DashboardSection.resumeSermon:
        if (_resumeSermon == null) return null;
        return _ResumeSermonHero(
          sermon: _resumeSermon!,
          progress: _resumeProgress,
          locale: locale,
          settings: settings,
          onTap: () => _openResumeSermon(_resumeSermon!),
        );

      case DashboardSection.dailyVerse:
        if (_dailyVerse == null) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              uiStrings['dailyVerse']?[locale] ?? 'Verse of the Day',
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: headerSize,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _DailyVerseCard(
              verse: _dailyVerse!,
              fontFamily: settings.fontFamily,
              fontSize: settings.fontSize,
              locale: locale,
              fromVersionLabel: _dailyVerseFromVersionLabel,
              onTap: () {
                jumper.prepareJumpToVerse(_dailyVerse!, mainProvider);
                Get.to(
                  () => const HomePage(),
                  transition: Transition.rightToLeft,
                );
              },
            ),
          ],
        );

      case DashboardSection.counts:
        return Row(
          children: [
            Expanded(
              child: _CountTile(
                icon: Icons.bookmark_outline_rounded,
                count: mainProvider.bookmarks.length,
                label: uiStrings['tabBookmarks']?[locale] ?? 'Bookmarks',
                onTap: () => Get.to(
                  () => const LibraryPage(),
                  transition: Transition.rightToLeft,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CountTile(
                icon: Icons.sticky_note_2_outlined,
                count: mainProvider.verseNotes.length,
                label: uiStrings['tabNotes']?[locale] ?? 'Notes',
                onTap: () => Get.to(
                  () => const LibraryPage(),
                  transition: Transition.rightToLeft,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CountTile(
                icon: Icons.format_color_fill,
                count: mainProvider.highlights.length,
                label: uiStrings['highlights']?[locale] ?? 'Highlights',
                onTap: () => Get.to(
                  () => const HighlightsPage(),
                  transition: Transition.rightToLeft,
                ),
              ),
            ),
          ],
        );

      case DashboardSection.recentBookmarks:
        if (mainProvider.bookmarks.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              uiStrings['homeRecentBookmarks']?[locale] ?? 'Recent bookmarks',
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: headerSize,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            for (final v in _recentBookmarks(mainProvider).take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bookmark_rounded,
                    size: 20, color: scheme.primary),
                title: Text(
                  '${v.book} ${v.chapter}:${v.verseLabel}',
                  style: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: settings.fontSize,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  sanitizeForSearch(v.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  jumper.prepareJumpToVerse(v, mainProvider);
                  Get.to(
                    () => const HomePage(),
                    transition: Transition.rightToLeft,
                  );
                },
              ),
          ],
        );

      case DashboardSection.todayEvidence:
        if (_dailyEvidence == null) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              uiStrings['todayEvidence']?[locale] ?? "Today's Evidence",
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: headerSize,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _DashboardEvidenceCard(
              evidence: _dailyEvidence!,
              locale: locale,
              onTap: () => Get.to(
                () => EvidenceDetailPage(evidence: _dailyEvidence!),
                transition: Transition.rightToLeft,
              ),
            ),
          ],
        );

      case DashboardSection.quickLinks:
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 3 : 2,
          childAspectRatio: isWide ? 3.2 : 2.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            // 2026-05-07 (v11): Search tile in the quick-links grid.
            // The user wanted a one-tap entry to the search function
            // from the dashboard, in the same row as Settings /
            // Library / etc. Placed first so it sits in the most
            // discoverable slot for a frequently-used feature.
            _LinkTile(
              icon: Icons.search_rounded,
              label: uiStrings['search']?[locale] ?? 'Search',
              onTap: () => Get.to(
                () => const SearchPage(),
                transition: Transition.rightToLeft,
              ),
            ),
            _LinkTile(
              icon: Icons.collections_bookmark_outlined,
              label: uiStrings['library']?[locale] ?? 'Library',
              onTap: () => Get.to(
                () => const LibraryPage(),
                transition: Transition.rightToLeft,
              ),
            ),
            _LinkTile(
              icon: Icons.insights_outlined,
              label: uiStrings['statistics']?[locale] ?? 'Statistics',
              onTap: () => Get.to(
                () => const StatsPage(),
                transition: Transition.rightToLeft,
              ),
            ),
            if (settings.isDashboardSectionVisible(
                DashboardSection.todayEvidence))
              _LinkTile(
                icon: Icons.museum_outlined,
                label: uiStrings['bibleEvidence']?[locale] ?? 'Bible Evidence',
                onTap: () => Get.to(
                  () => const EvidencePage(),
                  transition: Transition.rightToLeft,
                ),
              ),
            _LinkTile(
              icon: Icons.menu_book_outlined,
              label: uiStrings['sermons']?[locale] ?? 'Sermons',
              onTap: () => Get.to(
                () => const SermonsPage(),
                transition: Transition.rightToLeft,
              ),
            ),
            _LinkTile(
              icon: Icons.account_tree_outlined,
              label: uiStrings['familyTree']?[locale] ?? 'Family Tree',
              onTap: () => Get.to(
                () => const FamilyTreePage(),
                transition: Transition.rightToLeft,
              ),
            ),
            _LinkTile(
              icon: Icons.timeline_rounded,
              label: uiStrings['bibleTimeline']?[locale] ?? 'Bible Timeline',
              onTap: () => Get.to(
                () => const BibleTimelinePage(),
                transition: Transition.rightToLeft,
              ),
            ),
            _LinkTile(
              icon: Icons.auto_awesome_rounded,
              label: uiStrings['bibleTrivia']?[locale] ?? 'Bible Trivia',
              onTap: () => Get.to(
                () => const BibleTriviaPage(),
                transition: Transition.rightToLeft,
              ),
            ),
            // 2026-05-07 (v12): feedback tile -- mailto-driven form
            // page that lands directly in the developer's inbox via
            // the user's mail client.
            _LinkTile(
              icon: Icons.feedback_outlined,
              label: uiStrings['feedback']?[locale] ?? 'Feedback',
              onTap: () => Get.to(
                () => const FeedbackPage(),
                transition: Transition.rightToLeft,
              ),
            ),
            _LinkTile(
              icon: Icons.settings_outlined,
              label: uiStrings['settings']?[locale] ?? 'Settings',
              onTap: () => Get.to(
                () => const SettingsPage(),
                transition: Transition.rightToLeft,
              ),
            ),
          ],
        );
    }
  }

  /// Pull-to-refresh: re-pull every dynamic dashboard tile from its
  /// remote source. Returns when all done so the spinner can collapse.
  /// Cheap when network is up, graceful when down.
  Future<void> _pullToRefresh() async {
    await Future.wait<void>([
      _loadDailyEvidence(),
      _loadDailyVerse(),
    ]);
  }

  /// Most-recently-bookmarked verses, newest first.
  /// `_bookmarks` is a `LinkedHashSet` (constructed by `List.toSet()`
  /// in MainProvider._loadBookmarks), so iteration preserves
  /// insertion order — i.e. the order they were added across
  /// sessions. Reversed gives newest-first, which is the natural
  /// "Recent bookmarks" sort.
  List<Verse> _recentBookmarks(MainProvider mp) {
    final byId = {for (final v in mp.verses) v.id: v};
    return mp.bookmarks
        .map((id) => byId[id])
        .whereType<Verse>()
        .toList()
        .reversed
        .toList();
  }
}

// Removed: _navigateToReference. Replaced inline above with
// `jumper.resolveAndPrepareJump` so the OT-fallback (CUVS-YHWH on
// NT-only versions like LJK1/LJK2) is consistent across every
// cross-link surface — see `lib/utils/jump_to_reference.dart`.

class _CountTile extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;
  const _CountTile({
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // v1.2.31: see comment near line 1072 — select-based subscribe.
    context.select<AppSettings, (double, String)>(
        (s) => (s.fontSize, s.fontFamily));
    final settings = context.read<AppSettings>();
    final fs = settings.fontSize;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: scheme.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize:
                            (fs + 6).clamp(20.0, 32.0).toDouble(),
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize:
                        (fs - 4).clamp(11.0, 14.0).toDouble(),
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Verse-of-the-day card. Italic body text + reference, tappable to
/// jump straight into the reader at that verse. Visual style is
/// intentionally lighter than the other cards — meant to feel like
/// a quote, not a CTA.
class _DailyVerseCard extends StatelessWidget {
  final Verse verse;
  final String fontFamily;
  /// User's reading font size — daily verse text uses it directly so
  /// the verse renders at the same scale as their Bible reading.
  final double fontSize;
  /// Non-null when the verse text came from a fallback Bible bundle
  /// because the user's selected version doesn't carry that book
  /// (e.g. on LJK1/LJK2 + an OT verse). Drives a small "via {label}"
  /// note under the citation so the user knows the text isn't from
  /// their primary reading version.
  final String? fromVersionLabel;
  final String locale;
  final VoidCallback onTap;
  const _DailyVerseCard({
    required this.verse,
    required this.fontFamily,
    required this.fontSize,
    required this.locale,
    required this.onTap,
    this.fromVersionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = sanitizeForSearch(verse.text);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      // v1.3.x: was Ink(BoxDecoration(borderRadius: 12, border:
      // Border(left: primary w3, top/right/bottom: outlineVariant))).
      // A non-uniform border combined with a borderRadius throws
      // "A borderRadius can only be given on borders with uniform
      // colors" in Border.paint — the reported InkDecoration crash on
      // this daily-verse card. LeftAccentCard draws the left stripe as
      // a clipped child and the 3 grey sides as a uniform outline.
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: LeftAccentCard(
          borderRadius: BorderRadius.circular(12),
          accentColor: scheme.primary,
          accentWidth: 3,
          outlineColor: scheme.outlineVariant.withValues(alpha: 0.6),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '— ${verse.book} ${verse.chapter}:${verse.verseLabel}',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize:
                                  (fontSize - 3).clamp(11.0, 18.0).toDouble(),
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                          if (fromVersionLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                (uiStrings['dailyVerseFromFallback']
                                            ?[locale] ??
                                        'Shown from {version}')
                                    .replaceAll('{version}', fromVersionLabel!),
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: (fontSize - 5)
                                      .clamp(10.0, 14.0)
                                      .toDouble(),
                                  color: scheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward,
                        size: 16, color: scheme.outline),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // v1.2.31: see comment near line 1072 — select-based subscribe.
    context.select<AppSettings, (double, String)>(
        (s) => (s.fontSize, s.fontFamily));
    final settings = context.read<AppSettings>();
    final fs = settings.fontSize;
    // 2026-05-08 (v1.1.0 — Liquid Glass): replaced Material+Ink+InkWell
    // with the LiquidGlassButton primitive. Hover / press states use
    // the primary tint blending into the glass material rather than a
    // hard-edged ripple; the surface itself catches the implicit
    // "ambient light" via specular highlight + hairline border. Inner
    // controls (icon, label, chevron) keep their geometry — only the
    // container material changed.
    return LiquidGlassButton(
      onTap: onTap,
      borderRadius: 18, // concentric to outer-card radius (24)
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      semanticLabel: label,
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: (fs - 2).clamp(12.0, 18.0).toDouble(),
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                height: 1.15,
              ),
            ),
          ),
          Icon(Icons.chevron_right,
              size: 16, color: scheme.outline),
        ],
      ),
    );
  }
}

class _DashboardEvidenceCard extends StatelessWidget {
  final BibleEvidence evidence;
  final String locale;
  final VoidCallback onTap;
  const _DashboardEvidenceCard({
    required this.evidence,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // v1.2.31: see comment near line 1072 — select-based subscribe.
    context.select<AppSettings, (double, String)>(
        (s) => (s.fontSize, s.fontFamily));
    final settings = context.read<AppSettings>();
    final fs = settings.fontSize;
    final imgUrl =
        evidence.images.isNotEmpty ? evidence.images.first : null;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Thumbnail.
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: imgUrl != null
                        ? Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            // 2026-05-07: <img> tag for evidence
                            // thumbs — same CORS reason as news.
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.prefer,
                            // 2026-05-08 (v1.0.1 perf): cap decode
                            // size — these are 64×64 thumbnails;
                            // the source images can be 1500×1000+.
                            cacheWidth: 128,
                            cacheHeight: 128,
                            errorBuilder: (_, __, ___) =>
                                _ThumbIcon(icon: evidence.icon),
                          )
                        : _ThumbIcon(icon: evidence.icon),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              evidence.localizedTitle(locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                fontSize:
                                    (fs - 1).clamp(13.0, 18.0).toDouble(),
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        evidence.localizedSummary(locale),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: (fs - 3).clamp(11.0, 15.0).toDouble(),
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 12, color: scheme.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              evidence.scriptureReference,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                fontSize:
                                    (fs - 4).clamp(11.0, 14.0).toDouble(),
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbIcon extends StatelessWidget {
  final String icon;
  const _ThumbIcon({required this.icon});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      alignment: Alignment.center,
      child: Text(icon, style: const TextStyle(fontSize: 28)),
    );
  }
}

/// Primary "Continue reading" hero card. Shipped as the top-most
/// action on the dashboard because YsWords is first and foremost a
/// Bible reading app — the user's most likely next move when they
/// open Home is "open the Bible". Showing the current book / chapter /
/// version under the CTA gives a clear "resume" affordance instead
/// of feeling like a generic button.
class _ContinueReadingHero extends StatelessWidget {
  /// Localised book name for the current version (e.g. '創世記' on
  /// CUV, 'Genesis' on KJV). May be null on cold start before
  /// MainProvider has hydrated.
  final String? book;
  final int? chapter;
  final String? currentVersion;
  final String locale;
  final AppSettings settings;
  final VoidCallback onTap;

  const _ContinueReadingHero({
    required this.book,
    required this.chapter,
    required this.currentVersion,
    required this.locale,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPosition = book != null && chapter != null;
    final fs = settings.fontSize;

    final ctaTitle = hasPosition
        ? (uiStrings['continueReading']?[locale] ?? 'Continue reading')
        : (uiStrings['startReading']?[locale] ?? 'Start reading');

    // Position line reads e.g. "Genesis 1 · 和合本雅伟版(简体)".
    // We resolve the version code to its menuLabel (full localised
    // name) instead of dumping the raw value like "cuvs-yhwh" —
    // user feedback on round 49: "cuv-yhwh this doesn't look good".
    //
    // 2026-05-07 user follow-up: at < 390 px the long form
    // "创世纪 1 · 和合本雅伟版(简体)" overflows and gets ellipsized.
    // Below the threshold we fold both the book (帖前 / 创 / 1Th)
    // and version (CUVS(简)) to their short labels, which still
    // identify the location unambiguously.
    final screenW = MediaQuery.of(context).size.width;
    final useShort = screenW < 390;
    String? versionLabel;
    if (currentVersion != null && currentVersion!.isNotEmpty) {
      final info = bibleVersions.firstWhere(
        (v) => v.value == currentVersion,
        orElse: () => BibleVersionInfo(
          value: currentVersion!,
          shortLabel: currentVersion!,
          menuLabel: currentVersion!,
          language: 'zh-Hans',
        ),
      );
      versionLabel = useShort ? info.shortLabel : info.menuLabel;
    }
    final displayBook =
        (book != null && useShort) ? shortBookName(book!, locale) : book;
    final positionLine = hasPosition
        ? '$displayBook $chapter${versionLabel != null ? "  ·  $versionLabel" : ""}'
        : (uiStrings['continueReadingHint']?[locale] ??
            'Open the Bible from the beginning.');

    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: scheme.onPrimary,
                  size: (fs + 8).clamp(20.0, 32.0).toDouble(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctaTitle,
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: (fs + 3).clamp(16.0, 24.0).toDouble(),
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      positionLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: (fs - 2).clamp(11.0, 16.0).toDouble(),
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: scheme.onPrimary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Companion to [_ContinueReadingHero] — same shape and density, but
/// for the user's last-read sermon. Renders only when a sermon id is
/// persisted and still resolvable; the dashboard hides this card
/// otherwise (so first-time users don't see an empty placeholder).
///
/// Visual hierarchy: the Bible CTA on top is primary-coloured (the
/// app's main job), this card sits just under it in
/// `surfaceContainerHigh` so it doesn't compete — but with a primary-
/// tinted icon + thin progress bar so it still reads as
/// "you can pick up where you left off".
class _ResumeSermonHero extends StatelessWidget {
  final Sermon sermon;
  final double? progress;
  final String locale;
  final AppSettings settings;
  final VoidCallback onTap;

  const _ResumeSermonHero({
    required this.sermon,
    required this.progress,
    required this.locale,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fs = settings.fontSize;
    final ctaTitle = uiStrings['resumeSermon']?[locale] ?? 'Resume sermon';

    // Subtitle: localized passage (matches the sermons-list / detail
    // page) + percent read when we have a meter.
    final passage = sermon.passage.trim().isEmpty
        ? null
        : localizePassage(sermon.passage.trim(), locale);
    final percent =
        progress == null ? null : '${(progress!.clamp(0.0, 1.0) * 100).round()}%';
    final subtitleParts = <String>[
      sermon.localizedTitle(locale),
      if (passage != null) passage,
      if (percent != null) percent,
    ];
    final subtitle = subtitleParts.join('  ·  ');

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.headset_mic_rounded,
                      color: scheme.primary,
                      size: (fs + 6).clamp(18.0, 26.0).toDouble(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ctaTitle,
                          style: TextStyle(
                            fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                            fontSize: (fs + 1).clamp(14.0, 20.0).toDouble(),
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                            fontSize: (fs - 2).clamp(11.0, 15.0).toDouble(),
                            color: scheme.onSurface.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    size: 20,
                  ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
