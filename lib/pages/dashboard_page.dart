import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/highlights_page.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/library_page.dart';
import 'package:yswords/pages/profile_edit_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/pages/stats_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/cloud_sync_service.dart';
import 'package:yswords/services/daily_verse_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_plan_service.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/widgets/google_g_logo.dart';
import 'package:yswords/widgets/onboarding_dialog.dart';
import 'package:yswords/widgets/localized_back_button.dart';

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
  ReadingPlan? _plan;
  int _planDay = 1;
  Set<int> _planDone = const {};
  Verse? _dailyVerse;
  /// Cached canonical English ref ("John 3:16") loaded once from the
  /// asset. Kept separate from [_dailyVerse] so a Bible-version
  /// switch can re-resolve the verse text without re-fetching the
  /// reference list.
  String? _dailyVerseRef;
  /// Snapshot of MainProvider.currentVersion at the time we last
  /// resolved the daily verse — lets `didChangeDependencies` decide
  /// whether to redo the resolve.
  String? _resolvedForVersion;

  @override
  void initState() {
    super.initState();
    ProfileService.instance.addListener(_onProfileOrAuthChanged);
    CloudAuthService.instance.addListener(_onProfileOrAuthChanged);
    CloudSyncService.instance.addListener(_onProfileOrAuthChanged);
    _loadPlan();
    _loadDailyVerse();
    _maybeShowOnboarding();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Daily-verse resolution depends on MainProvider.currentVersion
    // (the verse text comes from whichever Bible the user has
    // loaded) and on mp.verses (which is replaced when version
    // switches). didChangeDependencies fires when any watched
    // provider changes — so a version switch reliably triggers a
    // re-resolve here without us needing a manual listener.
    final mp = context.read<MainProvider>();
    if (_dailyVerseRef != null &&
        _resolvedForVersion != mp.currentVersion) {
      _resolveDailyVerse();
    }
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
  void _resolveDailyVerse() {
    final ref = _dailyVerseRef;
    if (ref == null) return;
    final parsed = parseReference(ref);
    if (parsed == null) return;
    final mp = context.read<MainProvider>();
    final localBook =
        translateBookName(parsed.englishBook, mp.currentVersion);
    final targetVerse = parsed.verseStart ?? 1;
    final matches = mp.verses.where((v) =>
        v.book == localBook &&
        v.chapter == parsed.chapter &&
        v.verse == targetVerse);
    if (!mounted) return;
    setState(() {
      _dailyVerse = matches.isEmpty ? null : matches.first;
      _resolvedForVersion = mp.currentVersion;
    });
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_onProfileOrAuthChanged);
    CloudAuthService.instance.removeListener(_onProfileOrAuthChanged);
    CloudSyncService.instance.removeListener(_onProfileOrAuthChanged);
    super.dispose();
  }

  void _onProfileOrAuthChanged() {
    if (!mounted) return;
    setState(() {});
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final id = await ReadingPlanService.activeId();
    if (id == null) {
      if (!mounted) return;
      setState(() => _plan = null);
      return;
    }
    final plan = await ReadingPlanService.byId(id);
    if (plan == null) return;
    final day = await ReadingPlanService.todayOfPlan(plan);
    final done = await ReadingPlanService.completedDays(plan.id);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _planDay = day;
      _planDone = done;
    });
  }

  String _greeting(String locale) {
    final hour = DateTime.now().hour;
    if (locale.startsWith('zh')) {
      if (hour < 12) return '早安';
      if (hour < 18) return '午安';
      return '晚安';
    }
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final mainProvider = context.watch<MainProvider>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final profile = ProfileService.instance.current;
    final auth = CloudAuthService.instance;

    // The Dashboard is shown both as the app root AND as a pushed
    // page from the floating-header "Home" entry. As root there's
    // nothing to pop back to, so the back arrow would be confusing
    // — `Navigator.canPop` keeps it conditional automatically.
    final canPop = Navigator.of(context).canPop();
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    // Cap reading width on iPad / desktop so the dashboard doesn't
    // become a row of stretched, half-empty cards. Same constraint
    // pattern used in Settings keeps the app's wide-screen feel
    // consistent.
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop ? const LocalizedBackButton() : null,
        title: Text(uiStrings['home']?[locale] ?? 'Home'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting + profile / sync status
          _GreetingCard(
            greeting: _greeting(locale),
            profileName: profile.name,
            authConfigured: auth.isConfigured,
            isSignedIn: auth.isSignedIn,
            email: auth.currentUser?.email,
            photoUrl: auth.currentUser?.photoURL,
            avatarColor: profile.avatarColorArgb,
            syncStatus: CloudSyncService.instance.status,
            locale: locale,
            onSignIn: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await CloudAuthService.instance
                  .signInWithGoogleAndAdoptProfile();
              if (!mounted) return;
              if (!result.isOk) {
                messenger.showSnackBar(SnackBar(
                  content: Text(result.errorMessage ?? 'Sign-in failed.'),
                  duration: const Duration(seconds: 3),
                ));
              }
            },
          ),
          const SizedBox(height: 16),

          // Daily verse — one curated verse per day, deterministic
          // by day-of-year so two devices on the same calendar day
          // show the same one. Hidden until the verse text resolves.
          if (_dailyVerse != null) ...[
            Text(
              uiStrings['dailyVerse']?[locale] ?? 'Verse of the Day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _DailyVerseCard(
              verse: _dailyVerse!,
              fontFamily: settings.fontFamily,
              onTap: () {
                final v = _dailyVerse!;
                mainProvider.setCurrentChapter(
                    book: v.book, chapter: v.chapter);
                mainProvider.updateCurrentVerse(verse: v);
                Get.to(
                  () => const HomePage(),
                  transition: Transition.rightToLeft,
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // Today's reading (from active reading plan)
          Text(
            uiStrings['todayReading']?[locale] ?? "Today's Reading",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          if (_plan != null)
            _DashboardPlanCard(
              plan: _plan!,
              day: _planDay,
              isDone: _planDone.contains(_planDay),
              currentVersion: mainProvider.currentVersion,
              locale: locale,
              onJump: (canonical) {
                final ref = parseReference(canonical);
                if (ref == null) return;
                // Mutate provider first so the reader picks up the
                // new chapter on its first build; then push the
                // reader on top of the dashboard.
                _navigateToReference(mainProvider, ref);
                Get.to(
                  () => const HomePage(),
                  transition: Transition.rightToLeft,
                );
              },
              onToggleDone: () async {
                if (_plan == null) return;
                await ReadingPlanService.setDayCompleted(
                  _plan!.id,
                  _planDay,
                  !_planDone.contains(_planDay),
                );
                _loadPlan();
              },
            )
          else
            _PickPlanCard(
              locale: locale,
              onTap: () => Get.to(
                () => const SettingsPage(),
                transition: Transition.rightToLeft,
              ),
            ),
          const SizedBox(height: 24),

          // Counts row — bookmarks / notes / highlights
          Row(
            children: [
              Expanded(
                child: _CountTile(
                  icon: Icons.bookmark_outline_rounded,
                  count: mainProvider.bookmarks.length,
                  label:
                      uiStrings['tabBookmarks']?[locale] ?? 'Bookmarks',
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
          ),
          const SizedBox(height: 24),

          // Recent bookmarks (last 5)
          if (mainProvider.bookmarks.isNotEmpty) ...[
            Text(
              uiStrings['homeRecentBookmarks']?[locale] ??
                  'Recent bookmarks',
              style: TextStyle(
                fontSize: 14,
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
                      fontFamily: settings.fontFamily,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  sanitizeForSearch(v.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  // Mutate provider first; push reader on top.
                  mainProvider.setCurrentChapter(
                      book: v.book, chapter: v.chapter);
                  mainProvider.updateCurrentVerse(verse: v);
                  Get.to(
                    () => const HomePage(),
                    transition: Transition.rightToLeft,
                  );
                },
              ),
            const SizedBox(height: 16),
          ],

          // Quick-link tiles
          // "Continue reading" gets its own full-width primary
          // button — it's the highest-intent action on this page,
          // hiding it among 4 link tiles makes it less prominent
          // than it should be.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Get.to(
                () => const HomePage(),
                transition: Transition.rightToLeft,
              ),
              icon: const Icon(Icons.menu_book_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  uiStrings['continueReading']?[locale] ??
                      'Continue reading',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // 3-up on iPad/desktop so the tiles feel balanced;
            // 2-up on phones where 3 columns would be cramped.
            crossAxisCount: isWide ? 3 : 2,
            childAspectRatio: isWide ? 3.2 : 2.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
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
              _LinkTile(
                icon: Icons.settings_outlined,
                label: uiStrings['settings']?[locale] ?? 'Settings',
                onTap: () => Get.to(
                  () => const SettingsPage(),
                  transition: Transition.rightToLeft,
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
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

void _navigateToReference(MainProvider mp, BibleReference ref) {
  final localBook = translateBookName(ref.englishBook, mp.currentVersion);
  final matches = mp.verses
      .where((v) => v.book == localBook && v.chapter == ref.chapter)
      .toList()
    ..sort((a, b) => a.verse.compareTo(b.verse));
  if (matches.isEmpty) return;
  final targetVerse = ref.verseStart ?? matches.first.verse;
  final hit = matches.firstWhere(
    (v) => v.verse == targetVerse,
    orElse: () => matches.first,
  );
  mp.setCurrentChapter(book: hit.book, chapter: hit.chapter);
  mp.updateCurrentVerse(verse: hit);
  Future.delayed(const Duration(milliseconds: 300), () {
    final relIdx = matches.indexWhere((v) => v.verse == hit.verse);
    if (relIdx < 0) return;
    mp.jumpToIndex(index: relIdx);
    mp.setHighlightIndex(relIdx);
    Future.delayed(const Duration(milliseconds: 800), () {
      mp.clearHighlightIndex();
    });
  });
}

class _GreetingCard extends StatelessWidget {
  final String greeting;
  final String profileName;
  final bool authConfigured;
  final bool isSignedIn;
  final String? email;
  /// Google profile photo URL when signed in. Falls through to
  /// initial-on-color when null or fails to load.
  final String? photoUrl;
  /// Custom avatar color picked in Profile setup. Used when there's
  /// no [photoUrl]; falls through to scheme.primary when null.
  final int? avatarColor;
  final CloudSyncStatus syncStatus;
  final String locale;
  final VoidCallback onSignIn;

  const _GreetingCard({
    required this.greeting,
    required this.profileName,
    required this.authConfigured,
    required this.isSignedIn,
    required this.email,
    required this.photoUrl,
    required this.avatarColor,
    required this.syncStatus,
    required this.locale,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = profileName.isEmpty
        ? '?'
        : profileName.characters.first.toUpperCase();
    final tileColor = avatarColor != null ? Color(avatarColor!) : scheme.primary;
    // Compact horizontal layout: avatar on the left, greeting + name
    // stacked in the middle, sign-in button (or sync chip) on the
    // right. Keeps the card to ~80 dp tall on phones and avoids the
    // tall empty box that wide-screen layouts produced before.
    // Tap-to-edit on the avatar opens the Profile editor (rename,
    // pick avatar color). Most discoverable affordance — users
    // already mentally associate "tap the avatar" with profile
    // settings from every social app they use.
    final avatar = (photoUrl != null && photoUrl!.isNotEmpty)
                ? CircleAvatar(
                    radius: 24,
                    backgroundColor: tileColor,
                    foregroundColor: scheme.onPrimary,
                    backgroundImage: NetworkImage(photoUrl!),
                    onBackgroundImageError: (_, __) {},
                    child: ClipOval(
                      child: Image.network(
                        photoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          initial,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 24,
                    backgroundColor: tileColor,
                    foregroundColor: scheme.onPrimary,
                    child: Text(
                      initial,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Get.to(
                () => const ProfileEditPage(),
                transition: Transition.rightToLeft,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  avatar,
                  // Small edit-pencil chip in the bottom-right
                  // corner makes the affordance unmistakable.
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: scheme.outline, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.edit,
                          size: 10, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    profileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (isSignedIn && email != null)
                    Row(
                      children: [
                        Icon(Icons.cloud_done_outlined,
                            size: 12, color: scheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isSignedIn && authConfigured)
              OutlinedButton(
                onPressed: onSignIn,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F1F1F),
                  side: const BorderSide(
                      color: Color(0xFFDADCE0), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoogleGLogo(size: 16),
                    const SizedBox(width: 8),
                    Text(
                      uiStrings['welcomeSignInGoogle']?[locale] ??
                          'Sign in with Google',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPlanCard extends StatelessWidget {
  final ReadingPlan plan;
  final int day;
  final bool isDone;
  final String currentVersion;
  final String locale;
  final void Function(String canonical) onJump;
  final VoidCallback onToggleDone;

  const _DashboardPlanCard({
    required this.plan,
    required this.day,
    required this.isDone,
    required this.currentVersion,
    required this.locale,
    required this.onJump,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = plan.dayOf(day);
    if (entry == null) return const SizedBox.shrink();
    final dayLabel = (uiStrings['planDayLabel']?[locale] ??
            'Day {day} of {total}')
        .replaceAll('{day}', day.toString())
        .replaceAll('{total}', plan.days.toString());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.localizedName(locale),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleDone,
                  icon: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color:
                        isDone ? scheme.primary : scheme.outline,
                  ),
                  tooltip: isDone
                      ? (uiStrings['planMarkUndone']?[locale] ??
                          'Mark as unread')
                      : (uiStrings['planMarkDone']?[locale] ??
                          'Mark as done'),
                ),
              ],
            ),
            Text(
              dayLabel,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final r in entry.readings)
                  _ChipBtn(
                    label: _localizeRef(r, currentVersion),
                    onTap: () => onJump(r),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _localizeRef(String canonical, String version) {
    final ref = parseReference(canonical);
    if (ref == null) return canonical;
    final localBook = translateBookName(ref.englishBook, version);
    return '$localBook ${ref.chapter}';
  }
}

class _PickPlanCard extends StatelessWidget {
  final String locale;
  final VoidCallback onTap;
  const _PickPlanCard({required this.locale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      // Use a thin tinted border instead of a translucent fill —
      // looked muddy when the user's primary color was low-contrast
      // (e.g. mid-blue on grey scaffold).
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: scheme.primary.withValues(alpha: 0.25),
        ),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 22, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uiStrings['planHomeHint']?[locale] ??
                          'Choose a reading plan to see today\'s passages here.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      uiStrings['planHomeHintSub']?[locale] ??
                          'Tap to open Settings.',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

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
                        fontSize: 22,
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
                    fontSize: 11,
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
  final VoidCallback onTap;
  const _DailyVerseCard({
    required this.verse,
    required this.fontFamily,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = sanitizeForSearch(verse.text);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: scheme.primary, width: 3),
            top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6)),
            right: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6)),
            bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 15,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '— ${verse.book} ${verse.chapter}:${verse.verseLabel}',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChipBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
