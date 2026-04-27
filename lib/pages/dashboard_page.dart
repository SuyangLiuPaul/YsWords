import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/library_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/pages/stats_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/cloud_sync_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_plan_service.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/widgets/google_g_logo.dart';
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

  @override
  void initState() {
    super.initState();
    ProfileService.instance.addListener(_onProfileOrAuthChanged);
    CloudAuthService.instance.addListener(_onProfileOrAuthChanged);
    CloudSyncService.instance.addListener(_onProfileOrAuthChanged);
    _loadPlan();
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop ? const LocalizedBackButton() : null,
        title: Text(uiStrings['home']?[locale] ?? 'Home'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting + profile / sync status
          _GreetingCard(
            greeting: _greeting(locale),
            profileName: profile.name,
            authConfigured: auth.isConfigured,
            isSignedIn: auth.isSignedIn,
            email: auth.currentUser?.email,
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

          // Today's reading
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
                  label: uiStrings['highlight']?[locale] ?? 'Highlights',
                  // Highlights live in a modal sheet inside the
                  // reading pane (no dedicated page yet). Push the
                  // reader; user opens them via the overflow menu.
                  onTap: () => Get.to(
                    () => const HomePage(),
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
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.6,
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
                icon: Icons.menu_book_rounded,
                label: uiStrings['continueReading']?[locale] ??
                    'Continue reading',
                // Push the Bible reader on top of the Dashboard.
                // If a HomePage is already on the stack (because the
                // user came from Bible → Home → Continue), Get.back
                // would pop it directly — but tracking that adds
                // complexity for marginal stack-cleanliness benefit.
                // A duplicate HomePage on the stack is harmless;
                // swipe-back / browser-back lands on the previous
                // one which then lands on Dashboard.
                onTap: () => Get.to(
                  () => const HomePage(),
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
  final CloudSyncStatus syncStatus;
  final String locale;
  final VoidCallback onSignIn;

  const _GreetingCard({
    required this.greeting,
    required this.profileName,
    required this.authConfigured,
    required this.isSignedIn,
    required this.email,
    required this.syncStatus,
    required this.locale,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.30),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profileName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (isSignedIn)
              Row(
                children: [
                  Icon(Icons.cloud_done_outlined,
                      size: 14, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (uiStrings['cloudSignedInAs']?[locale] ??
                              'Cloud-synced as {email}')
                          .replaceAll('{email}', email ?? ''),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              )
            else if (authConfigured) ...[
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
                      horizontal: 14, vertical: 10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoogleGLogo(size: 16),
                    const SizedBox(width: 10),
                    Text(
                      uiStrings['cloudSignInGoogle']?[locale] ??
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
      color: scheme.primaryContainer.withValues(alpha: 0.20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 28, color: scheme.primary),
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
              Icon(Icons.chevron_right, color: scheme.primary),
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
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary, size: 20),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
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
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
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
