// 2026-09-08: the reader's own reading, reported back to them.
//
// Deliberately NOT a tab on `stats_page.dart`. That page is Bible Tools:
// Hebrew and Greek lemma counts, Strong's lookup, word distribution —
// facts about the text. This page's subject is the person holding the
// phone, and the two only look alike because both contain numbers.
//
// WHAT IS ON IT, AND WHAT IS KEPT OFF IT
//
// On: chapters opened, books touched, how much of the canon that covers,
// the same split for Old and New Testament, per-book coverage, and a
// recent list. All of it derives from one local store —
// `ReadingHistoryService` — and every figure is a count of things the
// app genuinely observed.
//
// Off: any streak. No 打卡, no "days in a row", no "longest run", no
// badge, and no relabelled version of one. The owner excluded it from
// this project, and the argument holds on its own: a streak counter
// turns a missed Tuesday into a loss, which is a strange thing to do to
// someone's Bible reading.
//
// THE PERIOD LINE IS NOT DECORATION
//
// The header states the date recording began, because "12% of the canon"
// with no period attached will be read as a lifetime figure, and this
// feature is days old. A reader who has been in this app for two years
// would otherwise see a number that says they have barely read it. The
// line is the difference between a true statement and a false one.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/canon_chapters.dart' show canonLastChapter;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/services/reading_history_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/app_nav.dart' show pushPage;
import 'package:yswords/utils/jump_to_reference.dart'
    show resolveAndPrepareJump, showJumpResultSnackBar;
import 'package:yswords/utils/reference_parser.dart' show BibleReference;
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Matthew is the 40th book in `standardBookOrder`, so the first 39 are
/// the Old Testament. Derived from the shared order rather than a second
/// hand-typed list, which would be one more thing to keep in step.
const int _kOldTestamentBooks = 39;

/// 1,189 — the canon's chapter count, summed from the table the Bible
/// assets are checked against rather than typed in as a constant that
/// could drift away from them.
int get _canonChapterTotal =>
    canonLastChapter.values.fold(0, (a, b) => a + b);

class ReadingStatsPage extends StatefulWidget {
  const ReadingStatsPage({super.key});

  @override
  State<ReadingStatsPage> createState() => _ReadingStatsPageState();
}

class _ReadingStatsPageState extends State<ReadingStatsPage> {
  ReadingHistorySnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // `load()` flushes first, so the chapter the reader was in when they
    // opened this page counts towards the figures on it.
    final snap = await ReadingHistoryService.instance.load();
    if (!mounted) return;
    setState(() => _snapshot = snap);
  }

  Future<void> _confirmClear(String locale) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(uiStrings['readingStatsClear']?[locale] ??
            'Clear reading record'),
        content: Text(uiStrings['readingStatsClearBody']?[locale] ??
            'This deletes everything this device has recorded about your '
                'reading. It cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(uiStrings['readingStatsClear']?[locale] ?? 'Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ReadingHistoryService.instance.clear();
    if (!mounted) return;
    setState(() => _snapshot = ReadingHistorySnapshot.empty);
    messenger.showSnackBar(SnackBar(
      content: Text(
          uiStrings['readingStatsCleared']?[locale] ?? 'Reading record cleared.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final snap = _snapshot;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
            uiStrings['readingStats']?[locale] ?? 'Reading statistics'),
        actions: [
          if (snap != null && !snap.isEmpty)
            IconButton(
              tooltip: uiStrings['readingStatsClear']?[locale] ??
                  'Clear reading record',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmClear(locale),
            ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: snap == null
          ? const Center(child: CircularProgressIndicator())
          : snap.isEmpty
              ? _EmptyState(locale: locale, settings: settings)
              : _Report(snapshot: snap, locale: locale, settings: settings),
    );
  }
}

/// Shown before anything has been recorded. Says what will be collected
/// and where it goes, rather than a bare "no data" — this is the first
/// time the reader learns the app keeps a reading log at all.
class _EmptyState extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  const _EmptyState({required this.locale, required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              uiStrings['readingStatsEmpty']?[locale] ??
                  'Nothing recorded yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              uiStrings['readingStatsEmptyBody']?[locale] ??
                  'Chapters you spend time in are noted on this device '
                      'only, and never sent anywhere. Open a chapter and '
                      'stay a moment, then come back.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (settings.fontSize - 2).clamp(12.0, 16.0),
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  final ReadingHistorySnapshot snapshot;
  final String locale;
  final AppSettings settings;
  const _Report(
      {required this.snapshot, required this.locale, required this.settings});

  /// Chapters opened in the books at [from]..[to] of `standardBookOrder`,
  /// paired with the canon total for that same span.
  (int opened, int total) _span(int from, int to) {
    var opened = 0;
    var total = 0;
    for (var i = from; i < to && i < standardBookOrder.length; i++) {
      final book = standardBookOrder[i];
      total += canonLastChapter[book] ?? 0;
      opened += snapshot.coverage[book]?.length ?? 0;
    }
    return (opened, total);
  }

  /// Open a logged chapter in the reader.
  ///
  /// Routed through `resolveAndPrepareJump` rather than
  /// `setCurrentChapter` directly, because the log stores canonical
  /// English book names while the reader's current version may be an
  /// NT-only edition that has no Genesis to jump to — the helper
  /// switches to the full-canon companion and says so, which a raw
  /// chapter set would not.
  static Future<void> _openChapter(
      BuildContext context, String englishBook, int chapter) async {
    final mp = context.read<MainProvider>();
    final result = await resolveAndPrepareJump(
      reference: BibleReference(englishBook: englishBook, chapter: chapter),
      mp: mp,
    );
    if (!context.mounted) return;
    final ok = await showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    // Explicit routeName — see main.dart's duplicate-HomePage note.
    pushPage(const HomePage(), routeName: '/HomePage');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chapters = snapshot.chaptersOpened;
    final canonTotal = _canonChapterTotal;
    final (otOpened, otTotal) = _span(0, _kOldTestamentBooks);
    final (ntOpened, ntTotal) =
        _span(_kOldTestamentBooks, standardBookOrder.length);

    final booksWithReading = [
      for (final book in standardBookOrder)
        if ((snapshot.coverage[book]?.length ?? 0) > 0) book,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _PeriodLine(
            since: snapshot.since, locale: locale, settings: settings),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Figure(
                icon: Icons.menu_book_outlined,
                label: uiStrings['readingStatsChapters']?[locale] ??
                    'Chapters opened',
                value: '$chapters',
                settings: settings,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Figure(
                icon: Icons.library_books_outlined,
                label:
                    uiStrings['readingStatsBooks']?[locale] ?? 'Books opened',
                value: '${snapshot.booksTouched} / 66',
                settings: settings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionLabel(
          text: uiStrings['readingStatsCoverage']?[locale] ?? 'Canon coverage',
          settings: settings,
        ),
        const SizedBox(height: 8),
        _CoverageBar(
          label: uiStrings['readingStatsWholeBible']?[locale] ?? 'Whole Bible',
          opened: chapters,
          total: canonTotal,
          settings: settings,
        ),
        _CoverageBar(
          label: uiStrings['oldTestament']?[locale] ?? 'Old Testament',
          opened: otOpened,
          total: otTotal,
          settings: settings,
        ),
        _CoverageBar(
          label: uiStrings['newTestament']?[locale] ?? 'New Testament',
          opened: ntOpened,
          total: ntTotal,
          settings: settings,
        ),
        const SizedBox(height: 20),
        _SectionLabel(
          text: uiStrings['readingStatsByBook']?[locale] ?? 'By book',
          settings: settings,
        ),
        const SizedBox(height: 8),
        // Only books with something in them. A 66-row list of mostly
        // zeroes reads as a scorecard of everything not done, which is
        // the same shame mechanic the streak was excluded for.
        for (final book in booksWithReading)
          _BookRow(
            book: book,
            opened: snapshot.coverage[book]!.length,
            total: canonLastChapter[book] ?? 0,
            locale: locale,
            settings: settings,
          ),
        const SizedBox(height: 20),
        _SectionLabel(
          text: uiStrings['readingStatsRecent']?[locale] ?? 'Recently read',
          settings: settings,
        ),
        const SizedBox(height: 4),
        for (final e in snapshot.recent.take(30))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.chevron_right,
                size: 18, color: scheme.onSurfaceVariant),
            title: Text(
              '${localeAwareBookName(e.book, locale)} ${e.chapter}',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (settings.fontSize - 1).clamp(13.0, 17.0),
              ),
            ),
            subtitle: Text(
              _relativeTime(e.at, locale),
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (settings.fontSize - 5).clamp(11.0, 13.0),
                color: scheme.onSurfaceVariant,
              ),
            ),
            onTap: () => _openChapter(context, e.book, e.chapter),
          ),
      ],
    );
  }
}

/// "Records since 8 September 2026" — the sentence that stops every
/// percentage on this page from being read as a lifetime figure.
class _PeriodLine extends StatelessWidget {
  final DateTime? since;
  final String locale;
  final AppSettings settings;
  const _PeriodLine(
      {required this.since, required this.locale, required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = since;
    final text = d == null
        ? (uiStrings['readingStatsEmpty']?[locale] ?? 'Nothing recorded yet.')
        : (uiStrings['readingStatsSince']?[locale] ??
                'Covers reading recorded on this device since {date}. '
                    'Anything you read before then is not counted.')
            .replaceAll('{date}', _isoDate(d));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_toggle_off,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (settings.fontSize - 4).clamp(11.0, 14.0),
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppSettings settings;
  const _Figure(
      {required this.icon,
      required this.label,
      required this.value,
      required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: (settings.fontSize - 7).clamp(11.0, 15.0),
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppSettings settings;
  const _SectionLabel({required this.text, required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontFamily: settings.fontFamily,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: (settings.fontSize - 2).clamp(13.0, 17.0),
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
    );
  }
}

class _CoverageBar extends StatelessWidget {
  final String label;
  final int opened;
  final int total;
  final AppSettings settings;
  const _CoverageBar(
      {required this.label,
      required this.opened,
      required this.total,
      required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : (opened / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: (settings.fontSize - 3).clamp(12.0, 15.0),
                  ),
                ),
              ),
              Text(
                // The raw counts sit beside the percentage on purpose: a
                // bare "3%" hides whether that is 3 chapters or 300.
                '$opened / $total  ·  ${(fraction * 100).toStringAsFixed(fraction > 0 && fraction < 0.01 ? 1 : 0)}%',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: (settings.fontSize - 5).clamp(11.0, 13.0),
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final String book;
  final int opened;
  final int total;
  final String locale;
  final AppSettings settings;
  const _BookRow(
      {required this.book,
      required this.opened,
      required this.total,
      required this.locale,
      required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = total > 0 && opened >= total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              localeAwareBookName(book, locale),
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (settings.fontSize - 3).clamp(12.0, 15.0),
                fontWeight: complete ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '$opened / $total',
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: (settings.fontSize - 5).clamp(11.0, 13.0),
              color: complete ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Coarse "how long ago", to the day. Deliberately not minute-accurate:
/// the exact second a chapter was opened is neither interesting nor
/// something the dwell-gated record can claim precisely.
String _relativeTime(DateTime at, String locale) {
  final days = DateTime.now().difference(at).inDays;
  final zh = locale.startsWith('zh');
  if (days <= 0) {
    return zh ? '今天' : 'Today';
  }
  if (days == 1) {
    return zh ? '昨天' : 'Yesterday';
  }
  if (days < 30) {
    return zh ? '$days 天前' : '$days days ago';
  }
  return _isoDate(at);
}
