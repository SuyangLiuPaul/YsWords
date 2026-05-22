import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/widgets/originals_sheet.dart';
import 'package:yswords/widgets/word_distribution_table.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/bible_stats_service.dart';
import 'package:yswords/services/daily_verse_service.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/services/originals_stats_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/theme_color_helpers.dart';
import 'package:yswords/services/concordance_service.dart' show ConcordanceRef;
import 'package:yswords/utils/jump_to_reference.dart' show resolveAndPrepareJump;
import 'package:yswords/utils/reference_parser.dart'
    show BibleReference, parseReference;
import 'package:yswords/utils/version_mapper.dart' show toEnglish, localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Bible Tools page — three tabs (Overview / Lookup / Distribution).
/// Round 56 cleanup: the Vocabulary tab and the Strong's-search
/// section of the Lookup tab were both pulled out. User feedback:
/// "原文查询感觉下面的点任意... 下面的都没有用，上面的选择经文已经
/// 出来的popup窗口那个强多了。包括词汇其实也没有用那个tab，remove
/// those". The two removed surfaces re-implemented search affordances
/// the Distribution-tab's own picker already covers; keeping them
/// just gave users three near-identical search lists.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    // Round 56: stats are now computed from Hebrew/Greek originals
    // via OriginalsStatsService, not from the current Bible version.
    // The old BibleStatsService translation-text counts are dead.

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          title: Text(uiStrings['statistics']?[locale] ?? 'Statistics'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            // 2026-05 dark-mode fix: was explicitly setting labelColor
            // / unselectedLabelColor / indicatorColor to onPrimary —
            // tuned for the light-mode primary-coloured AppBar. In
            // dark mode the AppBar uses primaryContainer (different
            // contrast pair), so onPrimary text was invisible.
            // Removing the override lets the global tabBarTheme in
            // main.dart handle both modes correctly (it sets
            // onPrimary in light + onPrimaryContainer in dark).
            tabs: [
              Tab(
                icon: const Icon(Icons.dashboard_outlined),
                text: uiStrings['statsOverview']?[locale] ?? 'Overview',
              ),
              // Round 56 (continued — Bible Tools rename): the
              // 'Books' tab was per-book originals stats — same data
              // the Overview now exposes via its book filter, so it
              // wasn't earning its slot. Replaced with a Strong's
              // lookup tool that opens the full StrongsEntryPage
              // (entry + word-family + concordance) for any tapped
              // result. User feedback: "书卷这一个tab感觉没有什么用，
              // 但是在经文里面的释经，里面的全部内容可以搬过来".
              Tab(
                icon: const Icon(Icons.search_rounded),
                text:
                    uiStrings['statsLookup']?[locale] ?? 'Lookup',
              ),
              // Round 56 (continued): Word Distribution tab —
              // exposes the WordDistributionTable widget that
              // previously was only reachable via tap-a-verse →
              // originals sheet → tap a word → "show distribution".
              // User feedback: "ALSo there is a table, can you
              // have another tab for that table from exegesis?"
              Tab(
                icon: const Icon(Icons.table_chart_outlined),
                text: uiStrings['statsDistribution']?[locale] ??
                    'Distribution',
              ),
            ],
          ),
          actions: const [
            HomeIconButton(),
          ],
        ),
        // Round 56: every tab now sources from
        // `OriginalsStatsService.aggregate()` per user request:
        // "统计分析、词汇、书卷总揽都需要基于原文". The translation-text
        // word counts (BibleStatsService) are gone — those varied
        // per-version and conflated translator choices with the
        // underlying text. Hebrew + Greek lemma counts give a
        // consistent, version-independent view of "what's actually
        // in the Bible."
        body: TabBarView(
          children: [
            _OriginalsOverviewTab(locale: locale, settings: settings),
            _StrongsLookupTab(locale: locale, settings: settings),
            _WordDistributionTab(locale: locale, settings: settings),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _copyAllStats(BuildContext ctx, BibleStats stats,
      String locale, String version) async {
    final buf = StringBuffer();
    buf.writeln('Bible statistics — $version');
    buf.writeln('Books\t${stats.totalBooks}');
    buf.writeln('Chapters\t${stats.totalChapters}');
    buf.writeln('Verses\t${stats.totalVerses}');
    buf.writeln('Words\t${stats.totalWords}');
    buf.writeln('Reading time (200 wpm)\t${stats.readingTimeMinutes()} min');
    buf.writeln();
    buf.writeln('Book\tChapters\tVerses\tWords\tAvg words/verse\tReading time (min)');
    for (final b in stats.books) {
      final book = toEnglish(b.book) ?? b.book;
      buf.writeln(
          '$book\t${b.chapters}\t${b.verses}\t${b.words}\t${b.avgWordsPerVerse.toStringAsFixed(1)}\t${b.readingTimeMinutes()}');
    }
    await ClipboardHelper.copyWithFeedback(ctx, buf.toString().trimRight());
  }
}

// Round 56: dead — replaced by _OriginalsOverviewTab. Kept for
// reference; safe to remove in a future cleanup pass.
// ignore: unused_element
class _OverviewTab extends StatelessWidget {
  final BibleStats stats;
  final String locale;
  final String version;
  const _OverviewTab(
      {required this.stats, required this.locale, required this.version});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final fs = settings.fontSize;
    final readingMin = stats.readingTimeMinutes();
    final hours = readingMin ~/ 60;
    final mins = readingMin % 60;
    final readingLabel =
        hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 720;
    final maxW = isWide ? 720.0 : double.infinity;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          version.toUpperCase(),
          style: TextStyle(
            fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
            fontSize: (fs - 6).clamp(13.0, 18.0).toDouble(),
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        // Big-number cards: 3-up on iPad/desktop, 2-up on phone.
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.4 : 1.6,
          children: [
            _StatCard(
                label: uiStrings['statsBooks']?[locale] ?? 'Books',
                value: '${stats.totalBooks}',
                icon: Icons.menu_book_outlined),
            _StatCard(
                label: uiStrings['statsChapters']?[locale] ?? 'Chapters',
                value: '${stats.totalChapters}',
                icon: Icons.bookmark_border),
            _StatCard(
                label: uiStrings['statsVerses']?[locale] ?? 'Verses',
                value: '${stats.totalVerses}',
                icon: Icons.format_list_numbered_rtl),
            _StatCard(
                label: uiStrings['statsWords']?[locale] ?? 'Words',
                value: _humanNum(stats.totalWords),
                icon: Icons.spellcheck),
            _StatCard(
                label: uiStrings['statsChars']?[locale] ?? 'Characters',
                value: _humanNum(stats.totalChars),
                icon: Icons.text_format),
            _StatCard(
                label: uiStrings['statsReadingTime']?[locale] ??
                    'Reading time @ 200 wpm',
                value: readingLabel,
                icon: Icons.timer_outlined),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader(
            label: uiStrings['statsLongestShortest']?[locale] ??
                'Longest and shortest books'),
        const SizedBox(height: 8),
        _LongestShortestList(stats: stats, locale: locale, version: version),
      ],
    ),
      ),
    );
  }
}

class _LongestShortestList extends StatelessWidget {
  final BibleStats stats;
  final String locale;
  final String version;
  const _LongestShortestList(
      {required this.stats, required this.locale, required this.version});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final fs = settings.fontSize;
    final byWords = [...stats.books]..sort((a, b) => b.words.compareTo(a.words));
    final longest = byWords.take(5).toList();
    final shortest = byWords.reversed.take(5).toList();
    Widget rowFor(BookStats b, {required bool isLong}) {
      final book =
          localeAwareBookName(toEnglish(b.book) ?? b.book, locale, version);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isLong ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: isLong ? scheme.primary : scheme.tertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(book,
                    style: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: (fs - 4).clamp(13.0, 18.0).toDouble(),
                      fontWeight: FontWeight.w600,
                    ))),
            Text(_humanNum(b.words),
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: (fs - 4).clamp(13.0, 18.0).toDouble(),
                  color: scheme.onSurfaceVariant,
                )),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            uiStrings['statsLongest']?[locale] ?? 'Longest (by word count)',
            style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: (fs - 7).clamp(13.0, 16.0).toDouble(),
                fontWeight: FontWeight.w700,
                color: scheme.primary,
                letterSpacing: 0.4),
          ),
        ),
        ...longest.map((b) => rowFor(b, isLong: true)),
        const SizedBox(height: 12),
        Text(
          uiStrings['statsShortest']?[locale] ?? 'Shortest (by word count)',
          style: TextStyle(
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
              fontSize: (fs - 7).clamp(13.0, 16.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: scheme.tertiary,
              letterSpacing: 0.4),
        ),
        ...shortest.map((b) => rowFor(b, isLong: false)),
      ],
    );
  }
}

class _BooksTab extends StatefulWidget {
  final BibleStats stats;
  final String locale;
  final String currentVersion;
  const _BooksTab(
      {required this.stats,
      required this.locale,
      required this.currentVersion});

  @override
  State<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<_BooksTab> {
  /// 0=book name, 1=chapters, 2=verses, 3=words, 4=avg words/verse,
  /// 5=reading time. Negative = ascending; positive = descending.
  int _sortColumn = 3; // default sort by word count, descending
  bool _ascending = false;

  List<BookStats> get _sortedBooks {
    final list = [...widget.stats.books];
    int cmp(BookStats a, BookStats b) {
      switch (_sortColumn) {
        case 0:
          return a.book.compareTo(b.book);
        case 1:
          return a.chapters.compareTo(b.chapters);
        case 2:
          return a.verses.compareTo(b.verses);
        case 4:
          return a.avgWordsPerVerse.compareTo(b.avgWordsPerVerse);
        case 5:
          return a.readingTimeMinutes().compareTo(b.readingTimeMinutes());
        case 3:
        default:
          return a.words.compareTo(b.words);
      }
    }
    list.sort(cmp);
    if (!_ascending) {
      return list.reversed.toList();
    }
    return list;
  }

  void _setSort(int column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        _ascending = column == 0; // book name default ascending
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final fs = settings.fontSize;
    // Header style for DataColumn labels — bumps from theme default
    // (~14pt) up via user font scale so Windows 1080p users can
    // actually read the column titles.
    final headerStyle = TextStyle(
      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
      fontSize: (fs - 5).clamp(13.0, 17.0).toDouble(),
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    final cellStyle = TextStyle(
      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
      fontSize: (fs - 5).clamp(13.0, 16.0).toDouble(),
      color: scheme.onSurface,
    );
    final l = widget.locale;
    final sortedBooks = _sortedBooks;
    final maxWords = widget.stats.books.fold<int>(
        0, (m, b) => b.words > m ? b.words : m);
    final w = MediaQuery.of(context).size.width;
    // Cap a bit wider than the other tabs (~960 dp vs 720) since
    // the DataTable has 6 columns and benefits from extra room
    // before the user has to horizontally scroll.
    final maxW = w >= 720 ? 960.0 : double.infinity;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumn,
            sortAscending: _ascending,
            columnSpacing: 16,
            columns: [
              DataColumn(
                label: Text(uiStrings['statsBook']?[l] ?? 'Book',
                    style: headerStyle),
                onSort: (i, asc) => _setSort(0),
              ),
              DataColumn(
                label: Text(uiStrings['statsChapters']?[l] ?? 'Chapters',
                    style: headerStyle),
                numeric: true,
                onSort: (i, asc) => _setSort(1),
              ),
              DataColumn(
                label: Text(uiStrings['statsVerses']?[l] ?? 'Verses',
                    style: headerStyle),
                numeric: true,
                onSort: (i, asc) => _setSort(2),
              ),
              DataColumn(
                label: Text(uiStrings['statsWords']?[l] ?? 'Words',
                    style: headerStyle),
                numeric: true,
                onSort: (i, asc) => _setSort(3),
              ),
              DataColumn(
                label: Text(
                    uiStrings['statsAvgWordsVerse']?[l] ?? 'Avg w/v',
                    style: headerStyle),
                numeric: true,
                onSort: (i, asc) => _setSort(4),
              ),
              DataColumn(
                label: Text(uiStrings['statsTime']?[l] ?? 'Time (m)',
                    style: headerStyle),
                numeric: true,
                onSort: (i, asc) => _setSort(5),
              ),
            ],
            rows: [
              for (final b in sortedBooks)
                DataRow(cells: [
                  DataCell(SizedBox(
                    width: 160,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            localeAwareBookName(toEnglish(b.book) ?? b.book,
                                l, widget.currentVersion),
                            overflow: TextOverflow.ellipsis,
                            style: cellStyle.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        // Tiny inline bar chart for word count.
                        Container(
                          width: 40 * (b.words / maxWords).clamp(0.05, 1.0),
                          height: 6,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  )),
                  DataCell(Text('${b.chapters}', style: cellStyle)),
                  DataCell(Text('${b.verses}', style: cellStyle)),
                  DataCell(Text(_humanNum(b.words), style: cellStyle)),
                  DataCell(Text(b.avgWordsPerVerse.toStringAsFixed(1), style: cellStyle)),
                  DataCell(Text('${b.readingTimeMinutes()}', style: cellStyle)),
                ]),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}

class _VocabularyTab extends StatefulWidget {
  final BibleStats stats;
  final String locale;
  final String currentVersion;
  const _VocabularyTab(
      {required this.stats,
      required this.locale,
      required this.currentVersion});

  @override
  State<_VocabularyTab> createState() => _VocabularyTabState();
}

class _VocabularyTabState extends State<_VocabularyTab> {
  /// Whose vocabulary to show. Null = whole canon; otherwise a book.
  String? _filterBook;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final fs = settings.fontSize;
    final l = widget.locale;
    final List<MapEntry<String, int>> top;
    final List<String> hapax;
    final int totalWords;
    if (_filterBook == null) {
      top = widget.stats.topGlobal.take(40).toList();
      hapax = widget.stats.hapaxLegomena.take(40).toList();
      totalWords = widget.stats.totalWords;
    } else {
      final b = widget.stats.books.firstWhere(
        (x) => x.book == _filterBook,
        orElse: () => widget.stats.books.first,
      );
      top = b.topWords(40);
      hapax = b.hapaxInBook().take(40).toList();
      totalWords = b.words;
    }
    final w = MediaQuery.of(context).size.width;
    final maxW = w >= 720 ? 720.0 : double.infinity;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Book filter dropdown.
        Row(
          children: [
            Text(
              uiStrings['statsScope']?[l] ?? 'Scope:',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _filterBook,
                hint: Text(uiStrings['statsAllCanon']?[l] ?? 'Whole Bible'),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                        uiStrings['statsAllCanon']?[l] ?? 'Whole Bible'),
                  ),
                  ...widget.stats.books.map((b) => DropdownMenuItem<String?>(
                        value: b.book,
                        child: Text(localeAwareBookName(
                            toEnglish(b.book) ?? b.book,
                            l,
                            widget.currentVersion)),
                      )),
                ],
                onChanged: (v) => setState(() => _filterBook = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          label: uiStrings['statsTopWords']?[l] ?? 'Top words',
          subtitle: uiStrings['statsTopWordsSub']?[l] ??
              'Frequency of content words (function words filtered).',
        ),
        const SizedBox(height: 8),
        // Bar chart of top words — width is proportional to count.
        for (final e in top)
          _FrequencyBar(
            word: e.key,
            count: e.value,
            ratio: top.isEmpty ? 0 : e.value / top.first.value,
          ),
        const SizedBox(height: 24),
        _SectionHeader(
          label: uiStrings['statsHapax']?[l] ?? 'Hapax legomena',
          subtitle: uiStrings['statsHapaxSub']?[l] ??
              'Words appearing only once in the selected scope.',
        ),
        const SizedBox(height: 8),
        if (hapax.isEmpty)
          Text(
            uiStrings['statsNoHapax']?[l] ?? '— none —',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in hapax)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: (fs - 6).clamp(13.0, 16.0).toDouble(),
                      fontFamily: RegExp(r'[一-鿿]').hasMatch(w)
                          ? settings.fontFamily
                          : 'monospace',
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),
        Text(
          (uiStrings['statsScopeTotal']?[l] ?? 'Total words in scope: {n}')
              .replaceAll('{n}', _humanNum(totalWords)),
          style: TextStyle(
            fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
            fontSize: (fs - 7).clamp(12.0, 15.0).toDouble(),
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final fs = settings.fontSize;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: (fs - 7).clamp(12.0, 15.0).toDouble(),
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final String? subtitle;
  const _SectionHeader({required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final fs = settings.fontSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
            // Was hardcoded 13. On Windows 1080p that's hard to read,
            // and it ignored the user's font-scale setting. Now scales
            // with `settings.fontSize` while keeping clear hierarchy
            // above body text.
            fontSize: (fs - 5).clamp(14.0, 20.0).toDouble(),
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: 0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
              fontSize: (fs - 7).clamp(12.0, 15.0).toDouble(),
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _FrequencyBar extends StatelessWidget {
  final String word;
  final int count;
  final double ratio; // 0..1 relative to the most frequent
  const _FrequencyBar(
      {required this.word, required this.count, required this.ratio});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCjk = RegExp(r'[一-鿿]').hasMatch(word);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                fontFamily: isCjk ? null : 'monospace',
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  scheme.primary.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              _humanNum(count),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _humanNum(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}K';
  }
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

/// Round 56: Overview tab — originals-based summary.
///
/// User: "统计分析、词汇、书卷总揽都需要基于原文". Drops the prior
/// translation-text word counts (which varied per-version) and
/// shows version-independent Hebrew/Greek lemma stats:
///   - Total Hebrew + Greek words (raw occurrences)
///   - Unique Hebrew + Greek lemmas (Strong's #s)
///   - Hapax (lemmas appearing exactly once)
///   - Top 5 Hebrew + 5 Greek lemmas with counts
class _OriginalsOverviewTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _OriginalsOverviewTab(
      {required this.locale, required this.settings});

  @override
  State<_OriginalsOverviewTab> createState() =>
      _OriginalsOverviewTabState();
}

class _OriginalsOverviewTabState extends State<_OriginalsOverviewTab>
    with AutomaticKeepAliveClientMixin {
  // Round 56 (continued — wide-screen + book filter redesign):
  //
  // Two futures load in parallel. `_aggregateFuture` gives the
  // whole-Bible totals + canonical bookStats list. `_lemmasFuture`
  // gives every lemma with its per-book occurrence map (`byBook`),
  // which is what powers the per-book filtered Top-25 lists.
  // Both are cached at the service layer so the second open is
  // instant.
  Future<OriginalsAggregateStats>? _aggregateFuture;
  Future<List<OriginalsLemma>>? _lemmasFuture;
  final ScrollController _scrollCtrl = ScrollController();

  // 'all' = whole-Bible aggregate; otherwise an English book name
  // ('Genesis', 'Romans', …). When set, every stat tile + Top-25
  // list recomputes from `lemma.byBook[bookName]`.
  String _bookFilter = 'all';

  bool _hideStopwords = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _aggregateFuture = OriginalsStatsService.aggregate();
    _lemmasFuture = OriginalsStatsService.load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final settings = widget.settings;
    return FutureBuilder<OriginalsAggregateStats>(
      future: _aggregateFuture,
      builder: (context, aggSnap) {
        return FutureBuilder<List<OriginalsLemma>>(
          future: _lemmasFuture,
          builder: (context, lemmasSnap) {
            if (aggSnap.connectionState != ConnectionState.done ||
                lemmasSnap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final stats = aggSnap.data;
            final allLemmas = lemmasSnap.data;
            if (stats == null || allLemmas == null) {
              return Center(
                child: Text(
                  uiStrings['statsOriginalsEmpty']?[locale] ??
                      'Original-language data not loaded.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              );
            }
            // Compute the view-model. When _bookFilter == 'all' this
            // is the whole-Bible aggregate; otherwise it's a derived
            // slice keyed off lemma.byBook[bookName].
            final view = _buildViewModel(stats, allLemmas);
            return Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: Center(
                  child: ConstrainedBox(
                    // Round 56: cap layout width at 1200 so the
                    // Overview doesn't sprawl edge-to-edge on
                    // 4K monitors. Below 1200 the layout fluidly
                    // fills available width via LayoutBuilder
                    // inside _StatGrid + the side-by-side lemma
                    // row.
                    constraints:
                        const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 16, 16, 24),
                      child: _buildBody(
                        view: view,
                        locale: locale,
                        settings: settings,
                        scheme: scheme,
                        availableBooks: stats.bookStats
                            .map((b) => b.englishBook)
                            .toSet(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody({
    required _OverviewView view,
    required String locale,
    required AppSettings settings,
    required ColorScheme scheme,
    required Set<String> availableBooks,
  }) {
    return LayoutBuilder(
      builder: (ctx, c) {
        // ≥ 900px → render the two Top-25 lemma cards side-by-side
        // (each in a 50% column). Below that, stack vertically.
        // The threshold matches the iPad-portrait breakpoint where
        // a single column starts wasting horizontal space.
        final wide = c.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OverviewFilterBar(
              locale: locale,
              settings: settings,
              scheme: scheme,
              bookFilter: _bookFilter,
              hideStopwords: _hideStopwords,
              availableBooks: availableBooks,
              onBookChanged: (v) =>
                  setState(() => _bookFilter = v),
              onStopwordChanged: (v) =>
                  setState(() => _hideStopwords = v),
            ),
            const SizedBox(height: 16),
            // Round 56 (continued — languages card): user feedback
            // 'those blocks in overview is not helpful. remove them.
            // also apart from Greek and Hebrew but also have other
            // languages right. I remember like Aramaic'. The
            // numeric stat tiles (Hebrew words / Greek words /
            // Hebrew lemmas / Greek lemmas / Hapax / Books covered)
            // mostly duplicated information already visible from the
            // Top-25 cards. Replaced with an educational card listing
            // all three biblical source languages — Hebrew, Aramaic,
            // and Greek — with a one-paragraph background each. The
            // numbers that did add value (Hebrew/Greek totals) now
            // appear inline within the language descriptions when
            // we have them.
            _BibleLanguagesCard(
              view: view,
              locale: locale,
              settings: settings,
              scheme: scheme,
            ),
            const SizedBox(height: 20),
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (view.showHebrew)
                      Expanded(
                        child: _TopLemmasCard(
                          title: _topHebrewTitle(view, locale),
                          lemmas: _applyStopwordFilter(view.topHebrew)
                              .take(25)
                              .toList(),
                          isHebrew: true,
                          scheme: scheme,
                          settings: settings,
                          locale: locale,
                          countContext: view.bookFilter,
                        ),
                      ),
                    if (view.showHebrew && view.showGreek)
                      const SizedBox(width: 12),
                    if (view.showGreek)
                      Expanded(
                        child: _TopLemmasCard(
                          title: _topGreekTitle(view, locale),
                          lemmas: _applyStopwordFilter(view.topGreek)
                              .take(25)
                              .toList(),
                          isHebrew: false,
                          scheme: scheme,
                          settings: settings,
                          locale: locale,
                          countContext: view.bookFilter,
                        ),
                      ),
                  ],
                ),
              )
            else ...[
              if (view.showHebrew)
                _TopLemmasCard(
                  title: _topHebrewTitle(view, locale),
                  lemmas: _applyStopwordFilter(view.topHebrew)
                      .take(25)
                      .toList(),
                  isHebrew: true,
                  scheme: scheme,
                  settings: settings,
                  locale: locale,
                  countContext: view.bookFilter,
                ),
              if (view.showHebrew && view.showGreek)
                const SizedBox(height: 12),
              if (view.showGreek)
                _TopLemmasCard(
                  title: _topGreekTitle(view, locale),
                  lemmas: _applyStopwordFilter(view.topGreek)
                      .take(25)
                      .toList(),
                  isHebrew: false,
                  scheme: scheme,
                  settings: settings,
                  locale: locale,
                  countContext: view.bookFilter,
                ),
            ],
          ],
        );
      },
    );
  }

  String _topHebrewTitle(_OverviewView view, String locale) {
    final base = uiStrings['statsOriginalsTopHebrew']?[locale] ??
        'Top Hebrew (OT)';
    if (view.bookFilter == null) return base;
    return '$base · ${localeAwareBookName(view.bookFilter!, locale)}';
  }

  String _topGreekTitle(_OverviewView view, String locale) {
    final base = uiStrings['statsOriginalsTopGreek']?[locale] ??
        'Top Greek (NT)';
    if (view.bookFilter == null) return base;
    return '$base · ${localeAwareBookName(view.bookFilter!, locale)}';
  }

  // ignore: unused_element
  List<_StatTile> _statTilesFor(
      _OverviewView view, String locale, ColorScheme scheme) {
    final tiles = <_StatTile>[];
    if (view.showHebrew) {
      tiles.add(_StatTile(
        label: uiStrings['statsOriginalsHebrewTotal']?[locale] ??
            'Hebrew words',
        value: _humanNum(view.hebrewWords),
        scheme: scheme,
      ));
      tiles.add(_StatTile(
        label: uiStrings['statsOriginalsHebrewUnique']?[locale] ??
            'Hebrew lemmas',
        value: _humanNum(view.hebrewUnique),
        scheme: scheme,
      ));
    }
    if (view.showGreek) {
      tiles.add(_StatTile(
        label: uiStrings['statsOriginalsGreekTotal']?[locale] ??
            'Greek words',
        value: _humanNum(view.greekWords),
        scheme: scheme,
      ));
      tiles.add(_StatTile(
        label: uiStrings['statsOriginalsGreekUnique']?[locale] ??
            'Greek lemmas',
        value: _humanNum(view.greekUnique),
        scheme: scheme,
      ));
    }
    if (view.bookFilter == null) {
      tiles.add(_StatTile(
        label: uiStrings['statsOriginalsHapax']?[locale] ??
            'Hapax legomena',
        value: '${view.hebrewHapax} + ${view.greekHapax}',
        scheme: scheme,
      ));
      tiles.add(_StatTile(
        label: uiStrings['statsOriginalsBooksCount']?[locale] ??
            'Books covered',
        value: '${view.booksCovered}',
        scheme: scheme,
      ));
    } else {
      // Per-book tile: total words across both languages (only one
      // will be non-zero for any single OT or NT book).
      tiles.add(_StatTile(
        label: uiStrings['statsOriginalsBookTotalWords']?[locale] ??
            'Total words in book',
        value: _humanNum(view.hebrewWords + view.greekWords),
        scheme: scheme,
      ));
      tiles.add(_StatTile(
        label: uiStrings['statsOriginalsBookUniqueLemmas']?[locale] ??
            'Unique lemmas in book',
        value: _humanNum(view.hebrewUnique + view.greekUnique),
        scheme: scheme,
      ));
    }
    return tiles;
  }

  /// Compute the view model for the current filter setting.
  /// When `_bookFilter == 'all'` returns the whole-Bible figures
  /// from [stats]. When set to a specific book, recomputes:
  ///   • word totals: sum of `lemma.byBook[book]` across that
  ///     language's lemmas
  ///   • unique lemmas: how many lemmas appear at least once in
  ///     that book
  ///   • Top lemmas: re-sorted by `byBook[book]` count
  /// `showHebrew` / `showGreek` flip off when the selected book is
  /// pure-OT or pure-NT respectively, so we don't waste rows on
  /// "Greek words: 0" when the user is reading Genesis.
  _OverviewView _buildViewModel(
      OriginalsAggregateStats stats, List<OriginalsLemma> allLemmas) {
    if (_bookFilter == 'all') {
      return _OverviewView(
        bookFilter: null,
        hebrewWords: stats.totalHebrewWords,
        greekWords: stats.totalGreekWords,
        hebrewUnique: stats.uniqueHebrewLemmas,
        greekUnique: stats.uniqueGreekLemmas,
        hebrewHapax: stats.hebrewHapaxCount,
        greekHapax: stats.greekHapaxCount,
        booksCovered: stats.bookStats.length,
        topHebrew: stats.topHebrew,
        topGreek: stats.topGreek,
        showHebrew: true,
        showGreek: true,
      );
    }
    final book = _bookFilter;
    int hebrewWords = 0;
    int greekWords = 0;
    int hebrewUnique = 0;
    int greekUnique = 0;
    final hebrewBookHits = <_BookHit>[];
    final greekBookHits = <_BookHit>[];
    for (final l in allLemmas) {
      final c = l.byBook[book] ?? 0;
      if (c == 0) continue;
      if (l.isHebrew) {
        hebrewWords += c;
        hebrewUnique += 1;
        hebrewBookHits.add(_BookHit(l, c));
      } else {
        greekWords += c;
        greekUnique += 1;
        greekBookHits.add(_BookHit(l, c));
      }
    }
    hebrewBookHits.sort((a, b) => b.count.compareTo(a.count));
    greekBookHits.sort((a, b) => b.count.compareTo(a.count));
    // Build virtual lemmas with the book-specific count overlaid
    // onto a fresh `byBook` so the rendered count column reflects
    // the in-book frequency, not the global one. The original lemma
    // metadata (lemma string, gloss, transliteration) stays
    // untouched.
    final topHebrew = hebrewBookHits
        .map((h) => OriginalsLemma(
              strongs: h.lemma.strongs,
              isHebrew: true,
              lemma: h.lemma.lemma,
              translit: h.lemma.translit,
              glossEn: h.lemma.glossEn,
              glossZhHans: h.lemma.glossZhHans,
              glossZhHant: h.lemma.glossZhHant,
              count: h.count,
              byBook: h.lemma.byBook,
            ))
        .toList();
    final topGreek = greekBookHits
        .map((h) => OriginalsLemma(
              strongs: h.lemma.strongs,
              isHebrew: false,
              lemma: h.lemma.lemma,
              translit: h.lemma.translit,
              glossEn: h.lemma.glossEn,
              glossZhHans: h.lemma.glossZhHans,
              glossZhHant: h.lemma.glossZhHant,
              count: h.count,
              byBook: h.lemma.byBook,
            ))
        .toList();
    return _OverviewView(
      bookFilter: book,
      hebrewWords: hebrewWords,
      greekWords: greekWords,
      hebrewUnique: hebrewUnique,
      greekUnique: greekUnique,
      hebrewHapax: 0,
      greekHapax: 0,
      booksCovered: 1,
      topHebrew: topHebrew,
      topGreek: topGreek,
      // Auto-hide the testament that has no presence in this book.
      showHebrew: hebrewWords > 0,
      showGreek: greekWords > 0,
    );
  }

  /// Apply the [_hideStopwords] toggle: when ON, drops entries
  /// flagged as `isStopword`. When OFF, returns the input list
  /// unchanged.
  List<OriginalsLemma> _applyStopwordFilter(List<OriginalsLemma> input) {
    if (!_hideStopwords) return input;
    return input.where((l) => !l.isStopword).toList();
  }
}

/// Rendered view-model for one Overview frame. The `_buildViewModel`
/// helper produces this from either the whole-Bible aggregate or a
/// per-book derivation. Keeping the rendering pure-from-this-struct
/// keeps `build()` short and makes the wide-screen layout trivial
/// to reason about.
class _OverviewView {
  final String? bookFilter; // null = whole Bible
  final int hebrewWords;
  final int greekWords;
  final int hebrewUnique;
  final int greekUnique;
  final int hebrewHapax;
  final int greekHapax;
  final int booksCovered;
  final List<OriginalsLemma> topHebrew;
  final List<OriginalsLemma> topGreek;
  final bool showHebrew;
  final bool showGreek;

  const _OverviewView({
    required this.bookFilter,
    required this.hebrewWords,
    required this.greekWords,
    required this.hebrewUnique,
    required this.greekUnique,
    required this.hebrewHapax,
    required this.greekHapax,
    required this.booksCovered,
    required this.topHebrew,
    required this.topGreek,
    required this.showHebrew,
    required this.showGreek,
  });
}

class _BookHit {
  final OriginalsLemma lemma;
  final int count;
  const _BookHit(this.lemma, this.count);
}

/// Round 56: filter row at the top of the Overview tab. Holds the
/// book-filter button + active-filter chip + stopword toggle.
/// Same modal-sheet pattern as the songs / trivia pages so users
/// see consistent affordances across the app.
class _OverviewFilterBar extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  final String bookFilter;
  final bool hideStopwords;
  final Set<String> availableBooks;
  final ValueChanged<String> onBookChanged;
  final ValueChanged<bool> onStopwordChanged;

  const _OverviewFilterBar({
    required this.locale,
    required this.settings,
    required this.scheme,
    required this.bookFilter,
    required this.hideStopwords,
    required this.availableBooks,
    required this.onBookChanged,
    required this.onStopwordChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filterLabel =
        uiStrings['sermonFilterByPassage']?[locale] ?? 'Filter';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                bookFilter == 'all'
                    ? (uiStrings['statsOriginalsScopeAll']?[locale] ??
                        'Whole Bible')
                    : (uiStrings['statsOriginalsScopeBook']?[locale] ??
                            'Showing: {book}')
                        .replaceAll('{book}',
                            localeAwareBookName(bookFilter, locale)),
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Hide-stopwords toggle moved inline as a compact chip
            // button — frees vertical space the old card took up.
            FilterChip(
              avatar: Icon(
                hideStopwords
                    ? Icons.filter_alt
                    : Icons.filter_alt_off,
                size: 16,
              ),
              label: Text(
                uiStrings['statsOriginalsHideStopwordsTitle']
                        ?[locale] ??
                    'Hide common particles',
                style: const TextStyle(fontSize: 12),
              ),
              selected: hideStopwords,
              onSelected: onStopwordChanged,
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: () => _openBookSheet(context),
              icon: Icon(
                bookFilter == 'all'
                    ? Icons.filter_list
                    : Icons.filter_list_alt,
                size: 18,
              ),
              label: Text(filterLabel,
                  style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: bookFilter == 'all'
                    ? null
                    : scheme.primaryContainer
                        .withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        if (bookFilter != 'all') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              avatar: Icon(Icons.bookmark,
                  size: 16, color: scheme.primary),
              label: Text(
                  localeAwareBookName(bookFilter, locale)),
              onDeleted: () => onBookChanged('all'),
              backgroundColor:
                  scheme.primaryContainer.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  void _openBookSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return _OverviewBookFilterSheet(
          locale: locale,
          availableBooks: availableBooks,
          initialBook:
              bookFilter == 'all' ? null : bookFilter,
          onApply: (book) {
            onBookChanged(book ?? 'all');
            Navigator.of(sheetCtx).pop();
          },
          onClear: () {
            onBookChanged('all');
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }
}

/// Modal book picker for the Overview filter — copies the layout
/// of `_TriviaBookFilterSheet` so the affordance is the same
/// everywhere.
class _OverviewBookFilterSheet extends StatefulWidget {
  final String locale;
  final Set<String> availableBooks;
  final String? initialBook;
  final void Function(String? book) onApply;
  final VoidCallback onClear;

  const _OverviewBookFilterSheet({
    required this.locale,
    required this.availableBooks,
    required this.initialBook,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_OverviewBookFilterSheet> createState() =>
      _OverviewBookFilterSheetState();
}

class _OverviewBookFilterSheetState
    extends State<_OverviewBookFilterSheet> {
  String? _selectedBook;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initialBook;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  uiStrings['sermonFilterByPassage']?[locale] ??
                      'Filter by passage',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.initialBook != null)
                  TextButton(
                    onPressed: widget.onClear,
                    child: Text(
                        uiStrings['clearFilter']?[locale] ?? 'Clear'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () =>
                      Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final b in standardBookOrder)
                      _OverviewBookChip(
                        book: b,
                        locale: locale,
                        hasData: widget.availableBooks.contains(b),
                        selected: _selectedBook == b,
                        onTap: () => setState(() {
                          _selectedBook =
                              _selectedBook == b ? null : b;
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => widget.onApply(_selectedBook),
              child: Text(
                  uiStrings['apply']?[locale] ?? 'Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewBookChip extends StatelessWidget {
  final String book;
  final String locale;
  final bool hasData;
  final bool selected;
  final VoidCallback onTap;
  const _OverviewBookChip({
    required this.book,
    required this.locale,
    required this.hasData,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final localized = localeAwareBookName(book, locale, '');
    return ChoiceChip(
      label: Text(
        localized,
        style: TextStyle(
          fontSize: 13,
          color: hasData
              ? null
              : Theme.of(context).disabledColor,
        ),
      ),
      selected: selected,
      onSelected: hasData ? (_) => onTap() : null,
    );
  }
}

/// Shared launcher for the OriginalsSheet flow. Both
/// `_StrongsLookupTabState` and `_BibleLanguagesCard` need to open
/// the exegesis sheet for an arbitrary (book, chapter, verse), with
/// cross-version fallback when the verse isn't in the loaded
/// translation. Pulled out as a top-level helper so the language
/// card can call it without going through Lookup-tab state.
class _ExegesisLauncher {
  /// Open OriginalsSheet for one verse. Same path the Lookup tab
  /// uses — handles "verse missing in current version" by routing
  /// through resolveAndPrepareJump so OT books open in CUVS-YHWH
  /// when the user is on an NT-only translation, etc.
  static void study({
    required BuildContext context,
    required String locale,
    required String book,
    required int chapter,
    required int verse,
  }) {
    final mp = context.read<MainProvider>();
    final matches = mp.verses
        .where((v) =>
            v.book == book && v.chapter == chapter && v.verse == verse)
        .toList();
    if (matches.isEmpty) {
      _resolveAndOpen(context,
          locale: locale,
          book: book,
          chapter: chapter,
          verse: verse);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 1100),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => OriginalsSheet(
        verses: matches,
        allVerses: mp.verses,
        locale: locale,
        currentVersion: mp.currentVersion,
        onNavigateRef: (ref) {
          Navigator.of(sheetCtx).maybePop();
          _hopToRef(context, locale, ref);
        },
      ),
    );
  }

  /// Open the 3-step verse picker, then study the picked verse.
  /// Used by the language card's Hebrew / Greek rows, which want a
  /// "any-verse" entry point rather than the curated Aramaic list.
  static Future<void> pickAndStudy({
    required BuildContext context,
    required String locale,
    required AppSettings settings,
  }) async {
    final mp = context.read<MainProvider>();
    final picked = await showModalBottomSheet<_PickedRef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _VersePickerSheet(
        mp: mp,
        locale: locale,
        settings: settings,
      ),
    );
    if (picked == null || !context.mounted) return;
    study(
      context: context,
      locale: locale,
      book: picked.book,
      chapter: picked.chapter,
      verse: picked.verse,
    );
  }

  static Future<void> _resolveAndOpen(BuildContext context,
      {required String locale,
      required String book,
      required int chapter,
      required int verse}) async {
    final mp = context.read<MainProvider>();
    final ref = BibleReference(
      englishBook: toEnglish(book) ?? book,
      chapter: chapter,
      verseStart: verse,
      verseEnd: verse,
    );
    final result = await resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted || !result.ready) return;
    final v = mp.verses.firstWhere(
      (x) =>
          x.chapter == chapter &&
          x.verse == verse &&
          (x.book == book || toEnglish(x.book) == toEnglish(book)),
      orElse: () => mp.verses.isNotEmpty
          ? mp.verses.first
          : Verse(
              book: book,
              chapter: chapter,
              verse: verse,
              verseLabel: '$verse',
              text: '',
            ),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 1100),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => OriginalsSheet(
        verses: [v],
        allVerses: mp.verses,
        locale: locale,
        currentVersion: mp.currentVersion,
        onNavigateRef: (ref) {
          Navigator.of(sheetCtx).maybePop();
          _hopToRef(context, locale, ref);
        },
      ),
    );
  }

  static void _hopToRef(
      BuildContext context, String locale, ConcordanceRef ref) {
    final mp = context.read<MainProvider>();
    final localBook = mp.verses.isEmpty
        ? null
        : mp.verses
            .firstWhere(
              (v) => (toEnglish(v.book) ?? v.book) == ref.englishBook,
              orElse: () => mp.verses.first,
            )
            .book;
    final book = localBook ?? ref.englishBook;
    study(
      context: context,
      locale: locale,
      book: book,
      chapter: ref.chapter,
      verse: ref.verse,
    );
  }
}

/// Round 56 (continued): one entry in the curated Aramaic-passages
/// list. Aramaic biblical content is small enough to enumerate
/// fully; this struct holds the reference + a one-phrase factual
/// note about what's in the passage (NOT the verse text itself —
/// taps open the OriginalsSheet which renders from the user's own
/// bundled Bible). For NT phrases the [transliteration] is the
/// actual Aramaic word as it appears transliterated in Greek text
/// (e.g. 'abba', 'maranatha').
class _AramaicEntry {
  final String englishBook;
  final int chapter;
  /// Starting verse — what we open the OriginalsSheet at.
  final int verse;
  /// Localised i18n key for the reference label shown to the user
  /// (e.g. 'aramRefDanielSection', 'aramRefMarkAbba').
  final String labelKey;
  /// Localised i18n key for the one-line description.
  final String descKey;
  /// For NT phrases, the transliterated Aramaic word/phrase.
  /// Null for OT sections (the whole passage is Aramaic, not a
  /// single embedded word).
  final String? transliteration;
  const _AramaicEntry({
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.labelKey,
    required this.descKey,
    this.transliteration,
  });
}

/// Curated full list of Aramaic biblical passages. References are
/// factual citations; descriptions in [descKey] are short factual
/// notes authored fresh for this app. NT entries also carry the
/// transliterated phrase that's actually Aramaic embedded in
/// Greek text.
const List<_AramaicEntry> _aramaicPassages = [
  // ── OT sections (the entire passage is Aramaic) ───────────────
  _AramaicEntry(
    englishBook: 'Genesis',
    chapter: 31,
    verse: 47,
    labelKey: 'aramRefGenesis',
    descKey: 'aramDescGenesis',
    transliteration: 'יְגַר שָׂהֲדוּתָא',
  ),
  _AramaicEntry(
    englishBook: 'Jeremiah',
    chapter: 10,
    verse: 11,
    labelKey: 'aramRefJeremiah',
    descKey: 'aramDescJeremiah',
  ),
  _AramaicEntry(
    englishBook: 'Daniel',
    chapter: 2,
    verse: 4,
    labelKey: 'aramRefDaniel',
    descKey: 'aramDescDaniel',
  ),
  _AramaicEntry(
    englishBook: 'Ezra',
    chapter: 4,
    verse: 8,
    labelKey: 'aramRefEzraA',
    descKey: 'aramDescEzraA',
  ),
  _AramaicEntry(
    englishBook: 'Ezra',
    chapter: 7,
    verse: 12,
    labelKey: 'aramRefEzraB',
    descKey: 'aramDescEzraB',
  ),
  // ── NT phrases (single Aramaic word/phrase embedded in Greek) ─
  _AramaicEntry(
    englishBook: 'Matthew',
    chapter: 5,
    verse: 22,
    labelKey: 'aramRefRaca',
    descKey: 'aramDescRaca',
    transliteration: 'ῥακά (raqa)',
  ),
  _AramaicEntry(
    englishBook: 'Mark',
    chapter: 5,
    verse: 41,
    labelKey: 'aramRefTalitha',
    descKey: 'aramDescTalitha',
    transliteration: 'ταλιθα κουμ (talitha koum)',
  ),
  _AramaicEntry(
    englishBook: 'Mark',
    chapter: 7,
    verse: 34,
    labelKey: 'aramRefEphphatha',
    descKey: 'aramDescEphphatha',
    transliteration: 'εφφαθα (ephphatha)',
  ),
  _AramaicEntry(
    englishBook: 'Mark',
    chapter: 14,
    verse: 36,
    labelKey: 'aramRefAbba',
    descKey: 'aramDescAbba',
    transliteration: 'ἀββα (abba)',
  ),
  _AramaicEntry(
    englishBook: 'Mark',
    chapter: 15,
    verse: 34,
    labelKey: 'aramRefSabachthani',
    descKey: 'aramDescSabachthani',
    transliteration: 'ελωι ελωι λεμα σαβαχθανι',
  ),
  _AramaicEntry(
    englishBook: '1 Corinthians',
    chapter: 16,
    verse: 22,
    labelKey: 'aramRefMaranatha',
    descKey: 'aramDescMaranatha',
    transliteration: 'μαραν αθα (marana tha)',
  ),
];

/// Round 56 (continued): educational card replacing the old stat-
/// block grid. Lists every source language the Bible was originally
/// written in — Hebrew, Aramaic, Greek — with a one-paragraph
/// background each, the canonical sections each language covers,
/// and (for Hebrew + Greek) the running word totals from the
/// originals stats. Inline stats fold the numeric value the old
/// blocks carried into a more meaningful context.
///
/// Each row is tappable: Hebrew / Greek open the standard verse
/// picker → OriginalsSheet, Aramaic opens a curated list of all
/// Aramaic passages (small enough to enumerate fully). The
/// OriginalsSheet already has Gemini AI explain built in, so all
/// three flows give the user the same exegesis affordance.
class _BibleLanguagesCard extends StatelessWidget {
  final _OverviewView view;
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;

  const _BibleLanguagesCard({
    required this.view,
    required this.locale,
    required this.settings,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final title = uiStrings['languagesCardTitle']?[locale] ??
        'Original languages of the Bible';
    final subtitle = uiStrings['languagesCardSubtitle']?[locale] ??
        'The three source languages and where each appears in the canon.';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate_rounded,
                  color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
              fontSize: 12,
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          Builder(builder: (rowCtx) {
            return _LanguageRow(
              scriptColor: Colors.indigo,
              scriptLabel: 'אבג',
              nameKey: 'languageHebrewName',
              roleKey: 'languageHebrewRole',
              sectionsKey: 'languageHebrewSections',
              backgroundKey: 'languageHebrewBackground',
              wordCount: view.hebrewWords > 0 ? view.hebrewWords : null,
              uniqueLemmas:
                  view.hebrewUnique > 0 ? view.hebrewUnique : null,
              locale: locale,
              settings: settings,
              scheme: scheme,
              // Hebrew → standard verse picker. User picks any OT
              // verse and the OriginalsSheet shows word-by-word
              // breakdown (with Gemini AI explain).
              onTap: () => _ExegesisLauncher.pickAndStudy(
                context: rowCtx,
                locale: locale,
                settings: settings,
              ),
            );
          }),
          const SizedBox(height: 14),
          Builder(builder: (rowCtx) {
            return _LanguageRow(
              // Aramaic shares its consonantal script with Hebrew;
              // the glyphs differ in style only.
              scriptColor: Colors.teal,
              scriptLabel: 'ܐܒܓ',
              nameKey: 'languageAramaicName',
              roleKey: 'languageAramaicRole',
              sectionsKey: 'languageAramaicSections',
              backgroundKey: 'languageAramaicBackground',
              wordCount: null,
              uniqueLemmas: null,
              locale: locale,
              settings: settings,
              scheme: scheme,
              // Aramaic → curated full passage list. Small enough
              // to enumerate fully (5 OT sections + 6 NT phrases).
              onTap: () => _openAramaicSheet(rowCtx, locale, settings),
            );
          }),
          const SizedBox(height: 14),
          Builder(builder: (rowCtx) {
            return _LanguageRow(
              scriptColor: Colors.deepPurple,
              scriptLabel: 'αβγ',
              nameKey: 'languageGreekName',
              roleKey: 'languageGreekRole',
              sectionsKey: 'languageGreekSections',
              backgroundKey: 'languageGreekBackground',
              wordCount: view.greekWords > 0 ? view.greekWords : null,
              uniqueLemmas:
                  view.greekUnique > 0 ? view.greekUnique : null,
              locale: locale,
              settings: settings,
              scheme: scheme,
              // Greek → same standard verse picker as Hebrew.
              onTap: () => _ExegesisLauncher.pickAndStudy(
                context: rowCtx,
                locale: locale,
                settings: settings,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Open the curated Aramaic-passages list. Each entry tap opens
  /// the same OriginalsSheet (with Gemini AI explain) Hebrew/Greek
  /// rows reach via the verse picker.
  void _openAramaicSheet(
      BuildContext context, String locale, AppSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _AramaicPassagesSheet(
        locale: locale,
        settings: settings,
      ),
    );
  }
}

/// Round 56 (continued — Aramaic full list): the 5 OT sections +
/// 6 NT phrases that are written in Aramaic rather than Hebrew or
/// Greek. Two visual sections (OT / NT). Each entry shows:
///   • localised reference (e.g. '但以理 2:4–7:28')
///   • the actual Aramaic / transliterated phrase (where applicable)
///   • a one-line factual description in the user's locale
///   • a 'Study →' affordance that opens the OriginalsSheet for
///     the starting verse — and from there Gemini AI explain is
///     one tap away inside the sheet itself.
///
/// We deliberately don't render the verse text in this sheet —
/// the OriginalsSheet is the single source of truth for that, and
/// reaches it from the user's already-loaded Bible asset.
class _AramaicPassagesSheet extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  const _AramaicPassagesSheet(
      {required this.locale, required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Split into OT (5 entries) and NT (6 entries) for visual
    // grouping; the canonical order matches the order entries are
    // declared in `_aramaicPassages`.
    final otEntries = _aramaicPassages
        .where((e) => _isOtBookForAramaic(e.englishBook))
        .toList();
    final ntEntries = _aramaicPassages
        .where((e) => !_isOtBookForAramaic(e.englishBook))
        .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.translate_rounded,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uiStrings['aramSheetTitle']?[locale] ??
                          'Aramaic in the Bible',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  // Round 56 (continued — Aramaic copy): one-tap export
                  // of the full curated list (OT sections + NT phrases)
                  // as a plain-text outline. Uses copyWithFeedback so
                  // the user gets a "Copied!" snack and the sheet stays
                  // open in case they want to study a passage too.
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: uiStrings['aramCopyTooltip']?[locale] ??
                        'Copy Aramaic passage list',
                    onPressed: () => _copyAramaicList(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                uiStrings['aramSheetSubtitle']?[locale] ??
                    'Tap any entry to open the verse with word-by-word breakdown and Gemini AI explanation.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SheetGroupHeader(
                        text:
                            uiStrings['aramGroupOt']?[locale] ??
                                'Old Testament sections',
                        scheme: scheme,
                      ),
                      const SizedBox(height: 6),
                      for (final e in otEntries) ...[
                        _AramaicEntryTile(
                          entry: e,
                          locale: locale,
                          settings: settings,
                          scheme: scheme,
                          onTap: () {
                            Navigator.of(context).maybePop();
                            _ExegesisLauncher.study(
                              context: context,
                              locale: locale,
                              book: _resolveLocalBook(
                                  context, e.englishBook),
                              chapter: e.chapter,
                              verse: e.verse,
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 8),
                      _SheetGroupHeader(
                        text:
                            uiStrings['aramGroupNt']?[locale] ??
                                'New Testament phrases',
                        scheme: scheme,
                      ),
                      const SizedBox(height: 6),
                      for (final e in ntEntries) ...[
                        _AramaicEntryTile(
                          entry: e,
                          locale: locale,
                          settings: settings,
                          scheme: scheme,
                          onTap: () {
                            Navigator.of(context).maybePop();
                            _ExegesisLauncher.study(
                              context: context,
                              locale: locale,
                              book: _resolveLocalBook(
                                  context, e.englishBook),
                              chapter: e.chapter,
                              verse: e.verse,
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolve canonical English book to the localised name the
  /// MainProvider's verse list uses (e.g. 'Daniel' → '但以理书' for
  /// CUVS). Falls back to the English name when no match.
  String _resolveLocalBook(BuildContext context, String englishBook) {
    final mp = context.read<MainProvider>();
    if (mp.verses.isEmpty) return englishBook;
    return mp.verses
        .firstWhere(
          (v) => (toEnglish(v.book) ?? v.book) == englishBook,
          orElse: () => mp.verses.first,
        )
        .book;
  }

  /// Tiny helper: which entries belong to the OT half vs the NT
  /// half. Avoids a full canonical lookup for the small Aramaic
  /// list — just spot-checks the four OT books that have Aramaic.
  static bool _isOtBookForAramaic(String englishBook) {
    return englishBook == 'Genesis' ||
        englishBook == 'Jeremiah' ||
        englishBook == 'Daniel' ||
        englishBook == 'Ezra';
  }

  /// Round 56 (continued — Aramaic copy): builds a plain-text outline
  /// of the curated 11-passage list and copies it to the clipboard.
  /// Layout — sheet title, subtitle, OT group header with bullets
  /// (ref label — description), then NT group header with bullets
  /// (ref label, optional transliteration in brackets, description).
  ///
  /// All strings are rendered in the user's current locale so the
  /// copied output matches what they see on screen.
  void _copyAramaicList(BuildContext context) {
    final title =
        uiStrings['aramSheetTitle']?[locale] ?? 'Aramaic in the Bible';
    final subtitle = uiStrings['aramSheetSubtitle']?[locale] ?? '';
    final otHeader = uiStrings['aramGroupOt']?[locale] ??
        'Old Testament sections';
    final ntHeader = uiStrings['aramGroupNt']?[locale] ??
        'New Testament phrases';
    final buf = StringBuffer();
    buf.writeln(title);
    if (subtitle.isNotEmpty) buf.writeln(subtitle);
    buf.writeln();

    final otEntries = _aramaicPassages
        .where((e) => _isOtBookForAramaic(e.englishBook))
        .toList();
    final ntEntries = _aramaicPassages
        .where((e) => !_isOtBookForAramaic(e.englishBook))
        .toList();

    void writeGroup(String header, List<_AramaicEntry> entries) {
      buf.writeln(header);
      for (final e in entries) {
        final ref = uiStrings[e.labelKey]?[locale] ?? e.labelKey;
        final desc = uiStrings[e.descKey]?[locale] ?? '';
        final tl = e.transliteration ?? '';
        buf.write('  • ');
        buf.write(ref);
        if (tl.isNotEmpty) {
          buf.write('  [');
          buf.write(tl);
          buf.write(']');
        }
        if (desc.isNotEmpty) {
          buf.write(' — ');
          buf.write(desc);
        }
        buf.writeln();
      }
      buf.writeln();
    }

    writeGroup(otHeader, otEntries);
    writeGroup(ntHeader, ntEntries);

    final text = buf.toString().trimRight();
    ClipboardHelper.copyWithFeedback(
      context,
      text,
      messageOverride: uiStrings['aramCopiedToast']?[locale],
    );
  }
}

class _SheetGroupHeader extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _SheetGroupHeader(
      {required this.text, required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: scheme.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _AramaicEntryTile extends StatelessWidget {
  final _AramaicEntry entry;
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _AramaicEntryTile({
    required this.entry,
    required this.locale,
    required this.settings,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = uiStrings[entry.labelKey]?[locale] ??
        '${entry.englishBook} ${entry.chapter}:${entry.verse}';
    final desc = uiStrings[entry.descKey]?[locale] ?? '';
    final ref =
        '${localeAwareBookName(entry.englishBook, locale)} ${entry.chapter}:${entry.verse}';
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ref,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.primary,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                    if (entry.transliteration != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.transliteration!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          // Theme-aware: shade900 in light, shade200
                          // in dark — keeps the transliteration vivid
                          // against either scheme without the dark-
                          // shade-on-dark-bg invisibility problem.
                          color: paletteFg(context, Colors.teal),
                        ),
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: 12,
                          height: 1.4,
                          color:
                              scheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color:
                      scheme.onSurface.withValues(alpha: 0.45)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row inside _BibleLanguagesCard. Two columns: a script-glyph
/// badge on the left (אבג / ܐܒܓ / αβγ) so the language is visually
/// recognisable before the user reads the text, and the localised
/// name + role + sections + background paragraph on the right.
/// Stats for languages we have counts for fold into the role line.
class _LanguageRow extends StatelessWidget {
  /// MaterialColor (not just Color) so we can access `.shade900`
  /// for the glyph badge text against the lightly-tinted box.
  final MaterialColor scriptColor;
  final String scriptLabel;
  final String nameKey;
  final String roleKey;
  final String sectionsKey;
  final String backgroundKey;
  final int? wordCount;
  final int? uniqueLemmas;
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  /// Round 56: tappable affordance — Hebrew/Greek opens the verse
  /// picker, Aramaic opens the curated passages sheet. Each path
  /// ultimately lands on the OriginalsSheet which has Gemini AI
  /// explain built in.
  final VoidCallback? onTap;

  const _LanguageRow({
    required this.scriptColor,
    required this.scriptLabel,
    required this.nameKey,
    required this.roleKey,
    required this.sectionsKey,
    required this.backgroundKey,
    required this.wordCount,
    required this.uniqueLemmas,
    required this.locale,
    required this.settings,
    required this.scheme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = uiStrings[nameKey]?[locale] ?? '';
    final role = uiStrings[roleKey]?[locale] ?? '';
    final sections = uiStrings[sectionsKey]?[locale] ?? '';
    final background = uiStrings[backgroundKey]?[locale] ?? '';
    final wordsLabel = wordCount != null
        ? (uiStrings['languageWordCount']?[locale] ?? '{n} words')
            .replaceAll('{n}', _humanNum(wordCount!))
        : null;
    final lemmasLabel = uniqueLemmas != null
        ? (uiStrings['languageLemmaCount']?[locale] ?? '{n} lemmas')
            .replaceAll('{n}', _humanNum(uniqueLemmas!))
        : null;
    final body = _buildBody(
        context: context,
        name: name,
        role: role,
        sections: sections,
        background: background,
        wordsLabel: wordsLabel,
        lemmasLabel: lemmasLabel);
    if (onTap == null) return body;
    // Wrap the row in an InkWell so the whole row is a target —
    // taps anywhere on the row trigger the language's flow.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: body,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required String name,
    required String role,
    required String sections,
    required String background,
    required String? wordsLabel,
    required String? lemmasLabel,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            // Theme-aware language-script badge — paletteBg adapts
            // to dark mode so the indigo/teal/deepOrange tile stays
            // visible without being washed out or eye-searing.
            color: paletteBg(context, scriptColor),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            scriptLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: paletteFg(context, scriptColor),
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      role,
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: 11,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (wordsLabel != null || lemmasLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  [wordsLabel, lemmasLabel]
                      .whereType<String>()
                      .join(' · '),
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              if (sections.isNotEmpty) ...[
                Text(
                  sections,
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: 12,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                background,
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: 12,
                  height: 1.5,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _StatGrid extends StatelessWidget {
  final AppSettings settings;
  final ColorScheme scheme;
  final List<_StatTile> tiles;
  const _StatGrid({
    required this.settings,
    required this.scheme,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        // Round 56 (continued — wide-screen redesign): scale the
        // column count with available width so tiles stay roughly
        // 200-240 px wide on every device class, instead of getting
        // stretched into wide rectangles on iPad / desktop.
        //   <  380 → 2 cols  (compact phone)
        //   < 600  → 3       (phone landscape / small tablet)
        //   < 900  → 4       (iPad portrait)
        //   < 1200 → 5       (iPad landscape)
        //   ≥ 1200 → 6       (desktop / 4K capped at 1200 by parent)
        final w = c.maxWidth;
        final int cols = w < 380
            ? 2
            : w < 600
                ? 3
                : w < 900
                    ? 4
                    : w < 1200
                        ? 5
                        : 6;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          childAspectRatio: 1.6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: tiles,
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme scheme;
  const _StatTile({
    required this.label,
    required this.value,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}


class _TopLemmasCard extends StatelessWidget {
  final String title;
  final List<OriginalsLemma> lemmas;
  final bool isHebrew;
  final ColorScheme scheme;
  final AppSettings settings;
  final String locale;
  /// When set, shown as a small caption under the title — e.g.
  /// 'Genesis' so the user knows the count column reflects in-book
  /// frequency, not global. Null = whole-Bible scope.
  final String? countContext;
  const _TopLemmasCard({
    required this.title,
    required this.lemmas,
    required this.isHebrew,
    required this.scheme,
    required this.settings,
    required this.locale,
    this.countContext,
  });

  @override
  Widget build(BuildContext context) {
    // Theme-aware Hebrew (indigo) / Greek (deepPurple) tag colors
    // so the lemma chips stay vivid in dark mode (shade900 background
    // with alpha + shade200 text) instead of shade100 bg + shade900
    // text which becomes near-invisible on the dark scaffold.
    final palette = isHebrew ? Colors.indigo : Colors.deepPurple;
    final tagColor = paletteBg(context, palette);
    final tagFg = paletteFg(context, palette);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < lemmas.length; i++) ...[
            if (i > 0) const Divider(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    lemmas[i].strongs,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tagFg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lemmas[i].lemma,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    lemmas[i].glossFor(locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${lemmas[i].count}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Round 56: Books tab — per-book originals stats.
class _OriginalsBooksTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _OriginalsBooksTab(
      {required this.locale, required this.settings});

  @override
  State<_OriginalsBooksTab> createState() => _OriginalsBooksTabState();
}

class _OriginalsBooksTabState extends State<_OriginalsBooksTab>
    with AutomaticKeepAliveClientMixin {
  Future<OriginalsAggregateStats>? _future;
  String _filter = 'all'; // all / ot / nt
  final ScrollController _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = OriginalsStatsService.aggregate();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final settings = widget.settings;
    return FutureBuilder<OriginalsAggregateStats>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snap.data;
        if (stats == null) {
          return Center(
            child: Text(
              uiStrings['statsOriginalsEmpty']?[locale] ??
                  'Original-language data not loaded.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }
        var rows = stats.bookStats;
        if (_filter == 'ot') {
          rows = rows.where((b) => b.isOt).toList();
        } else if (_filter == 'nt') {
          rows = rows.where((b) => !b.isOt).toList();
        }
        // Round 56 (continued — wide-screen): center the list
        // and cap at 1200 px so it doesn't stretch edge-to-edge
        // on iPad / desktop.
        return Scrollbar(
          controller: _scrollCtrl,
          thumbVisibility: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView.separated(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: rows.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding:
                          const EdgeInsets.fromLTRB(0, 4, 0, 12),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'all',
                            label: Text(
                                uiStrings['statsOriginalsAll']?[locale] ??
                                    'All'),
                          ),
                          ButtonSegment(
                            value: 'ot',
                            label: Text(
                                uiStrings['statsBooksOT']?[locale] ??
                                    'OT'),
                          ),
                          ButtonSegment(
                            value: 'nt',
                            label: Text(
                                uiStrings['statsBooksNT']?[locale] ??
                                    'NT'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (s) =>
                            setState(() => _filter = s.first),
                        multiSelectionEnabled: false,
                        showSelectedIcon: false,
                      ),
                    );
                  }
                  final book = rows[i - 1];
                  return _BookOriginalsRow(
                    book: book,
                    scheme: scheme,
                    settings: settings,
                    locale: locale,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BookOriginalsRow extends StatelessWidget {
  final OriginalsBookStat book;
  final ColorScheme scheme;
  final AppSettings settings;
  final String locale;
  const _BookOriginalsRow({
    required this.book,
    required this.scheme,
    required this.settings,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final localizedName =
        localeAwareBookName(book.englishBook, locale);
    // Theme-aware OT (indigo) / NT (deepPurple) badge so the chip
    // stays vivid in dark mode instead of the shade100 + shade900
    // pair that washes out against the dark scaffold.
    final palette = book.isOt ? Colors.indigo : Colors.deepPurple;
    final tagColor = paletteBg(context, palette);
    final tagFg = paletteFg(context, palette);
    final tagLabel = book.isOt
        ? (uiStrings['statsBooksOT']?[locale] ?? 'OT')
        : (uiStrings['statsBooksNT']?[locale] ?? 'NT');
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                tagLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: tagFg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizedName,
                    style: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: settings.fontSize,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    book.englishBook,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_humanNum(book.totalWords)} ${uiStrings['statsOriginalsWordsShort']?[locale] ?? 'words'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '${book.uniqueLemmas} ${uiStrings['statsOriginalsLemmasShort']?[locale] ?? 'lemmas'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round 56 cleanup: trimmed to just the Passage Study launcher.
/// User feedback: '原文查询感觉下面的点任意... 下面的都没有用，
/// 上面的选择经文已经出来的popup窗口那个强多了'. The previous
/// Strong's-search list duplicated the picker the Distribution
/// tab already exposes. The Lookup tab is now a single card that
/// opens the in-reader OriginalsSheet (word-by-word breakdown,
/// tap-a-word entry, family + synonyms + concordance) for any
/// verse the user picks. All the rich exegesis affordances live
/// inside that sheet.
class _StrongsLookupTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _StrongsLookupTab(
      {required this.locale, required this.settings});

  @override
  State<_StrongsLookupTab> createState() => _StrongsLookupTabState();
}

class _StrongsLookupTabState extends State<_StrongsLookupTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final settings = widget.settings;
    // Round 56 (continued — Lookup tab redesign): the previous
    // single-card centered layout looked sparse on iPad / desktop
    // (one small card floating in a wide empty page). User feedback:
    // "感觉原文查询，middle aligned 感觉看起来不好看". Page is now a
    // top-aligned column of three sections: hero CTA, popular-
    // passages quick picks, exegesis features card. Still capped at
    // 900 px so a 4K monitor doesn't sprawl, but the column is now
    // dense enough that the centered layout feels intentional.
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PassageStudyCard(
                  locale: locale,
                  settings: settings,
                  scheme: scheme,
                  onPickVerse: () => _openVersePicker(context),
                  onContinueReading: () =>
                      _continueReading(context),
                ),
                const SizedBox(height: 16),
                _PopularPassagesCard(
                  locale: locale,
                  settings: settings,
                  scheme: scheme,
                  onTap: (book, chapter, verse) =>
                      _openOriginalsSheetFor(
                    context,
                    book: book,
                    chapter: chapter,
                    verse: verse,
                  ),
                ),
                const SizedBox(height: 16),
                _ExegesisFeaturesCard(
                  locale: locale,
                  settings: settings,
                  scheme: scheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Open the 3-step modal picker (book → chapter → verse). When
  /// the user lands on a verse, dismiss the picker and open the
  /// shared OriginalsSheet — same widget the reader pops when you
  /// tap a verse in the reading pane.
  Future<void> _openVersePicker(BuildContext context) async {
    final mp = context.read<MainProvider>();
    final picked = await showModalBottomSheet<_PickedRef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _VersePickerSheet(
        mp: mp,
        locale: widget.locale,
        settings: widget.settings,
      ),
    );
    if (picked != null && context.mounted) {
      _openOriginalsSheetFor(
        context,
        book: picked.book,
        chapter: picked.chapter,
        verse: picked.verse,
      );
    }
  }

  /// "继续阅读" action: open OriginalsSheet for the verse the user
  /// last read in the main reader. Falls back to chapter:1 verse:1
  /// when the reader hasn't been opened yet this session.
  Future<void> _continueReading(BuildContext context) async {
    final mp = context.read<MainProvider>();
    final book = mp.currentBook;
    final chapter = mp.currentChapter;
    if (book == null || chapter == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          uiStrings['statsLookupNoCurrentReading']?[widget.locale] ??
              'Open a passage in the reader first to continue here.',
        ),
      ));
      return;
    }
    final firstVerse = mp.currentVerse?.verse ?? 1;
    _openOriginalsSheetFor(
      context,
      book: book,
      chapter: chapter,
      verse: firstVerse,
    );
  }

  /// Filter MainProvider.verses down to a single (book, chapter,
  /// verse) and pop the OriginalsSheet. The sheet itself handles the
  /// "no original-language data" empty state, so the affordance
  /// always opens.
  void _openOriginalsSheetFor(
    BuildContext context, {
    required String book,
    required int chapter,
    required int verse,
  }) {
    final mp = context.read<MainProvider>();
    final matches = mp.verses
        .where((v) =>
            v.book == book && v.chapter == chapter && v.verse == verse)
        .toList();
    if (matches.isEmpty) {
      _resolveAndOpen(context,
          book: book, chapter: chapter, verse: verse);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 1100),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => OriginalsSheet(
        verses: matches,
        allVerses: mp.verses,
        locale: widget.locale,
        currentVersion: mp.currentVersion,
        onNavigateRef: (ref) {
          Navigator.of(sheetCtx).maybePop();
          _hopToConcordanceRef(context, ref);
        },
      ),
    );
  }

  /// Re-target the OriginalsSheet at the verse a concordance ref
  /// points to. Filters MainProvider.verses; if the verse isn't in
  /// the current version, falls through to _resolveAndOpen which
  /// handles cross-version fallback.
  void _hopToConcordanceRef(
      BuildContext context, ConcordanceRef ref) {
    final mp = context.read<MainProvider>();
    final localBook = mp.verses.isEmpty
        ? null
        : mp.verses
            .firstWhere(
              (v) => (toEnglish(v.book) ?? v.book) == ref.englishBook,
              orElse: () => mp.verses.first,
            )
            .book;
    final book = localBook ?? ref.englishBook;
    _openOriginalsSheetFor(
      context,
      book: book,
      chapter: ref.chapter,
      verse: ref.verse,
    );
  }

  Future<void> _resolveAndOpen(BuildContext context,
      {required String book,
      required int chapter,
      required int verse}) async {
    final mp = context.read<MainProvider>();
    final ref = BibleReference(
      englishBook: toEnglish(book) ?? book,
      chapter: chapter,
      verseStart: verse,
      verseEnd: verse,
    );
    final result = await resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted || !result.ready) return;
    final v = mp.verses.firstWhere(
      (x) =>
          x.chapter == chapter &&
          x.verse == verse &&
          (x.book == book || toEnglish(x.book) == toEnglish(book)),
      orElse: () => mp.verses.isNotEmpty ? mp.verses.first : Verse(
        book: book,
        chapter: chapter,
        verse: verse,
        verseLabel: '$verse',
        text: '',
      ),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 1100),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => OriginalsSheet(
        verses: [v],
        allVerses: mp.verses,
        locale: widget.locale,
        currentVersion: mp.currentVersion,
        onNavigateRef: (ref) {
          Navigator.of(sheetCtx).maybePop();
          _hopToConcordanceRef(context, ref);
        },
      ),
    );
  }
}

/// Round 56 (continued — exegesis-table tab): wraps the
/// `WordDistributionTable` widget so users can reach it from a
/// dedicated Bible Tools tab instead of having to tap a verse →
/// originals sheet → tap a word → "show distribution".
///
/// The widget itself renders only lexical metadata (Strong's
/// number, lemma, gloss, per-book occurrence counts for the word
/// + its family + synonyms). No verse text or extended
/// commentary is shown by this tab — that's `OriginalsSheet`'s
/// job.
class _WordDistributionTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _WordDistributionTab(
      {required this.locale, required this.settings});

  @override
  State<_WordDistributionTab> createState() =>
      _WordDistributionTabState();
}

class _WordDistributionTabState extends State<_WordDistributionTab>
    with AutomaticKeepAliveClientMixin {
  // Default to H3068 — יהוה, the Tetragrammaton — so the table
  // arrives populated with an interesting OT distribution rather
  // than an empty state.
  String _strongs = 'H3068';
  Future<List<OriginalsLemma>>? _lemmasFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lemmasFuture = OriginalsStatsService.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final settings = widget.settings;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            // Sticky picker header — current focus word + change
            // button. Fits on one line; doesn't scroll with the
            // table body.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiStrings['statsDistributionHint']?[locale] ??
                        'Pick a Strong\'s word to see its distribution across books, plus word-family + synonym comparison.',
                    style: TextStyle(
                      fontSize: (settings.fontSize - 3)
                          .clamp(11.0, 14.0),
                      color: scheme.onSurface.withValues(alpha: 0.65),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CurrentWordBar(
                    strongs: _strongs,
                    locale: locale,
                    settings: settings,
                    scheme: scheme,
                    onChange: () => _openPicker(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: WordDistributionTable(
                // Re-key on every selection so the widget runs
                // its initState (which fires _loadAll) — without
                // this, switching words would leave the previous
                // rows visible until the user manually scrolled.
                key: ValueKey(_strongs),
                strongsNumber: _strongs,
                locale: locale,
                currentVersion: null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final all = await _lemmasFuture;
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return _StrongsPickerSheet(
          allLemmas: all ?? const [],
          locale: widget.locale,
          settings: widget.settings,
          initialQuery: '',
          onPick: (strongs) =>
              Navigator.of(sheetCtx).pop(strongs),
        );
      },
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _strongs = picked);
    }
  }
}

/// Compact header showing which Strong's word the distribution
/// table is currently focused on, plus a "Change word" button
/// that opens the picker sheet.
class _CurrentWordBar extends StatefulWidget {
  final String strongs;
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  final VoidCallback onChange;
  const _CurrentWordBar({
    required this.strongs,
    required this.locale,
    required this.settings,
    required this.scheme,
    required this.onChange,
  });

  @override
  State<_CurrentWordBar> createState() => _CurrentWordBarState();
}

class _CurrentWordBarState extends State<_CurrentWordBar> {
  Future<OriginalsLemma?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _lookup(widget.strongs);
  }

  @override
  void didUpdateWidget(covariant _CurrentWordBar old) {
    super.didUpdateWidget(old);
    if (old.strongs != widget.strongs) {
      _future = _lookup(widget.strongs);
    }
  }

  Future<OriginalsLemma?> _lookup(String s) async {
    final all = await OriginalsStatsService.load();
    for (final l in all) {
      if (l.strongs == s) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isHebrew = widget.strongs.startsWith('H');
    // Same theme-aware pattern as other Hebrew/Greek tag chips —
    // adapts shade100/900 pair to dark mode legible variants.
    final palette = isHebrew ? Colors.indigo : Colors.deepPurple;
    final tagColor = paletteBg(context, palette);
    final tagFg = paletteFg(context, palette);
    return Material(
      color: widget.scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.strongs,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tagFg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FutureBuilder<OriginalsLemma?>(
                future: _future,
                builder: (ctx, snap) {
                  final lemma = snap.data;
                  if (lemma == null) {
                    return Text(
                      widget.strongs,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.scheme.onSurface,
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              lemma.lemma,
                              style: TextStyle(
                                fontFamily: widget.settings.fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: widget.scheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lemma.translit.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                lemma.translit,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: widget.scheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        lemma.glossFor(widget.locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: widget.settings.fontFamily,
                          fontSize: 12,
                          color: widget.scheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: widget.onChange,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(
                uiStrings['statsDistributionPicker']?[widget.locale] ??
                    'Change word',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal-sheet picker that lets the user choose a Strong's word
/// for the distribution table. Same fuzzy-search vocabulary as
/// the Lookup tab; selection returns a Strong's number string
/// via Navigator.pop.
class _StrongsPickerSheet extends StatefulWidget {
  final List<OriginalsLemma> allLemmas;
  final String locale;
  final AppSettings settings;
  final String initialQuery;
  final ValueChanged<String> onPick;

  const _StrongsPickerSheet({
    required this.allLemmas,
    required this.locale,
    required this.settings,
    required this.initialQuery,
    required this.onPick,
  });

  @override
  State<_StrongsPickerSheet> createState() => _StrongsPickerSheetState();
}

class _StrongsPickerSheetState extends State<_StrongsPickerSheet> {
  late String _query;
  String _filter = 'all';
  bool _hideStopwords = true;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final allLabel =
        uiStrings['statsOriginalsAll']?[locale] ?? 'All';
    Iterable<OriginalsLemma> filtered = widget.allLemmas;
    if (_filter == 'hebrew') {
      filtered = filtered.where((e) => e.isHebrew);
    } else if (_filter == 'greek') {
      filtered = filtered.where((e) => !e.isHebrew);
    }
    if (_hideStopwords) {
      filtered = filtered.where((e) => !e.isStopword);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((e) =>
          e.strongs.toLowerCase().contains(q) ||
          e.lemma.contains(_query.trim()) ||
          e.translit.toLowerCase().contains(q) ||
          e.glossEn.toLowerCase().contains(q) ||
          e.glossZhHans.contains(_query.trim()) ||
          e.glossZhHant.contains(_query.trim()));
    }
    final rows = filtered.toList();
    // Cap at 60 visible rows so the sheet doesn't laggy-scroll
    // through 14k entries; the search box is the primary tool.
    final showRows =
        (q.isEmpty && rows.length > 60) ? rows.take(60).toList() : rows;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_horiz,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    uiStrings['statsDistributionPicker']?[locale] ??
                        'Change word',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: uiStrings['statsLookupHint']?[locale] ??
                      'Search by Strong\'s, lemma, transliteration, or gloss',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                            value: 'all', label: Text(allLabel)),
                        ButtonSegment(
                          value: 'hebrew',
                          label: Text(uiStrings['statsOriginalsHebrew']
                                  ?[locale] ??
                              'Hebrew'),
                        ),
                        ButtonSegment(
                          value: 'greek',
                          label: Text(uiStrings['statsOriginalsGreek']
                                  ?[locale] ??
                              'Greek'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) =>
                          setState(() => _filter = s.first),
                      multiSelectionEnabled: false,
                      showSelectedIcon: false,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    avatar: Icon(
                      _hideStopwords
                          ? Icons.filter_alt
                          : Icons.filter_alt_off,
                      size: 16,
                    ),
                    label: Text(
                      uiStrings['statsOriginalsHideStopwordsTitle']
                              ?[locale] ??
                          'Hide common particles',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _hideStopwords,
                    onSelected: (v) =>
                        setState(() => _hideStopwords = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: showRows.isEmpty
                    ? Center(
                        child: Text(
                          uiStrings['statsLookupEmpty']?[locale] ??
                              'No matching entries.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: showRows.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 4),
                        itemBuilder: (_, i) {
                          final e = showRows[i];
                          final palette = e.isHebrew
                              ? Colors.indigo
                              : Colors.deepPurple;
                          final tagColor = paletteBg(context, palette);
                          final tagFg = paletteFg(context, palette);
                          return InkWell(
                            onTap: () => widget.onPick(e.strongs),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tagColor,
                                      borderRadius:
                                          BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      e.strongs,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: tagFg,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${e.lemma}  ·  ${e.glossFor(locale)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily:
                                            widget.settings.fontFamily,
                                        fontSize: 14,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${e.count}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round 56 (continued — exegesis parity): card at the top of the
/// Lookup tab inviting the user to start an exegesis study from
/// a passage rather than from a Strong's number. Mirrors the
/// in-reader experience (tap-a-verse → originals sheet) but
/// reachable directly from Bible Tools without first opening the
/// reader.
class _PassageStudyCard extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  final VoidCallback onPickVerse;
  final VoidCallback onContinueReading;

  const _PassageStudyCard({
    required this.locale,
    required this.settings,
    required this.scheme,
    required this.onPickVerse,
    required this.onContinueReading,
  });

  @override
  Widget build(BuildContext context) {
    final title = uiStrings['statsLookupPassageTitle']?[locale] ??
        'Study a passage';
    final desc = uiStrings['statsLookupPassageDesc']?[locale] ??
        'Pick any verse to see its word-by-word original-language breakdown — same view the reader pops when you tap a verse.';
    final pickLabel =
        uiStrings['statsLookupPickVerse']?[locale] ?? 'Pick a verse';
    final continueLabel =
        uiStrings['statsLookupContinueReading']?[locale] ??
            'Continue from reader';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: scheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded,
                    color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: 12,
                height: 1.45,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onPickVerse,
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: Text(pickLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onContinueReading,
                  icon: const Icon(Icons.history_edu_rounded,
                      size: 18),
                  label: Text(continueLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round 56 (continued — Lookup redesign): the recommended-
/// passages card now sources its entries from
/// [DailyVerseService.recentRefs] instead of a hardcoded eight-
/// passage list. User feedback: 'for recommended verse, in bible
/// study, can you also include daily verse? also yesterday and
/// the day before etc... to replace all current ones'.
///
/// Each chip shows a localised relative-date label (Today /
/// Yesterday / 2 days ago / …) above the canonical reference.
/// Tapping parses the reference via parseReference, resolves the
/// book to the current Bible version's localized name, and pops
/// the same OriginalsSheet the rest of the tab uses.
class _PopularPassagesCard extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  /// (book, chapter, verse) → caller resolves through
  /// MainProvider.verses + opens the sheet.
  final void Function(String book, int chapter, int verse) onTap;

  const _PopularPassagesCard({
    required this.locale,
    required this.settings,
    required this.scheme,
    required this.onTap,
  });

  @override
  State<_PopularPassagesCard> createState() =>
      _PopularPassagesCardState();
}

class _PopularPassagesCardState extends State<_PopularPassagesCard> {
  Future<List<DailyVerseEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _future = DailyVerseService.recentRefs(8);
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.read<MainProvider>();
    final locale = widget.locale;
    final settings = widget.settings;
    final scheme = widget.scheme;
    final title = uiStrings['lookupPopularTitle']?[locale] ??
        'Recent daily verses';
    final desc = uiStrings['lookupPopularDesc']?[locale] ??
        'Each entry is one of the past few days of daily verse — tap to study it.';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.65),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<DailyVerseEntry>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }
              final entries = snap.data ?? const [];
              if (entries.isEmpty) {
                return Text(
                  uiStrings['lookupPopularEmpty']?[locale] ??
                      'No daily verses available yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                );
              }
              return LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth >= 600 ? 4 : 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in entries)
                      SizedBox(
                        width: (c.maxWidth - (cols - 1) * 8) / cols,
                        child: _DailyVerseChip(
                          entry: e,
                          locale: locale,
                          settings: settings,
                          scheme: scheme,
                          onTap: () => _onTap(mp, e.ref),
                        ),
                      ),
                  ],
                );
              });
            },
          ),
        ],
      ),
    );
  }

  /// Parse the daily-verse reference (e.g. 'John 3:16',
  /// 'Psalms 23:1-6', 'Genesis 1') and forward to the parent's
  /// onTap with the localised book name + the start verse. Falls
  /// back gracefully if the reference doesn't parse.
  void _onTap(MainProvider mp, String ref) {
    final parsed = parseReference(ref);
    if (parsed == null) return;
    final localBook = mp.verses.isEmpty
        ? parsed.englishBook
        : mp.verses
            .firstWhere(
              (v) =>
                  (toEnglish(v.book) ?? v.book) == parsed.englishBook,
              orElse: () => mp.verses.first,
            )
            .book;
    widget.onTap(
      localBook,
      parsed.chapter,
      parsed.verseStart ?? 1,
    );
  }
}

/// Single chip in the daily-verse history grid. Top line: relative
/// date label (Today / Yesterday / N days ago, localised). Bottom
/// line: canonical reference re-localised via
/// [localeAwareBookName] so 'John 3:16' shows as '约翰福音 3:16'
/// in zh-Hans, '約翰福音 3:16' in zh-Hant.
class _DailyVerseChip extends StatelessWidget {
  final DailyVerseEntry entry;
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _DailyVerseChip({
    required this.entry,
    required this.locale,
    required this.settings,
    required this.scheme,
    required this.onTap,
  });

  /// Reference re-formatted into the user's locale book naming +
  /// the localized topical theme for the chapter. Preserves verse
  /// range when present (e.g. 'Psalms 23:1-6').
  ({String ref, String theme}) _displayParts() {
    final parsed = parseReference(entry.ref);
    if (parsed == null) {
      return (
        ref: entry.ref,
        theme: uiStrings['verseThemeGeneral']?[locale] ?? '',
      );
    }
    final book = localeAwareBookName(parsed.englishBook, locale);
    final tail = parsed.verseStart == null
        ? '${parsed.chapter}'
        : (parsed.verseEnd != null && parsed.verseEnd! > parsed.verseStart!
            ? '${parsed.chapter}:${parsed.verseStart}-${parsed.verseEnd}'
            : '${parsed.chapter}:${parsed.verseStart}');
    final themeKey = themeKeyFor(parsed.englishBook, parsed.chapter);
    final theme = uiStrings[themeKey]?[locale] ??
        uiStrings['verseThemeGeneral']?[locale] ??
        '';
    return (ref: '$book $tail', theme: theme);
  }

  @override
  Widget build(BuildContext context) {
    // Round 56 (continued — themes): user feedback "no need to
    // mention today yesterday etc. but show the theme of the verse
    // somehow". Top line is now a topical label resolved through
    // themeKeyFor() in daily_verse_service.dart instead of the
    // relative-date label that used to live there.
    final parts = _displayParts();
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                parts.theme,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                parts.ref,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static educational card explaining what the user can do once
/// the OriginalsSheet pops. Adds visual weight to the otherwise
/// sparse Lookup tab and answers the implicit "what is this for"
/// question for first-time visitors.
class _ExegesisFeaturesCard extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  const _ExegesisFeaturesCard({
    required this.locale,
    required this.settings,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final title = uiStrings['lookupFeaturesTitle']?[locale] ??
        'Inside the exegesis sheet';
    final features = <(IconData, String)>[
      (Icons.translate_rounded,
          uiStrings['lookupFeatureWords']?[locale] ??
              'Word-by-word original-language breakdown with transliteration and gloss.'),
      (Icons.touch_app_rounded,
          uiStrings['lookupFeatureTap']?[locale] ??
              'Tap any word for the full Strong\'s entry — meaning, derivation, occurrence count.'),
      (Icons.diversity_3_rounded,
          uiStrings['lookupFeatureFamily']?[locale] ??
              'Word family + synonym comparison — see related lemmas at a glance.'),
      (Icons.format_list_numbered_rounded,
          uiStrings['lookupFeatureConcordance']?[locale] ??
              'Tappable concordance — every verse the word appears in, one tap to navigate.'),
      (Icons.copy_rounded,
          uiStrings['lookupFeatureCopy']?[locale] ??
              'Copy the interlinear table to clipboard for sermon prep or notes.'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < features.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(features[i].$1,
                    size: 18,
                    color:
                        scheme.primary.withValues(alpha: 0.85)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    features[i].$2,
                    style: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: 12,
                      height: 1.45,
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Result of the verse-picker modal — the three coordinates needed
/// to filter MainProvider.verses to a single row before opening
/// OriginalsSheet.
class _PickedRef {
  final String book;
  final int chapter;
  final int verse;
  const _PickedRef(this.book, this.chapter, this.verse);
}

/// Three-step verse picker: book chips → chapter chips → verse
/// chips. Returns the picked (book, chapter, verse) triple via
/// Navigator.pop. Designed to be lightweight — uses
/// MainProvider.books for the structure rather than re-loading.
/// Falls back to the verse list when MainProvider.books is empty
/// (e.g. user opened Bible Tools before the reader loaded).
class _VersePickerSheet extends StatefulWidget {
  final MainProvider mp;
  final String locale;
  final AppSettings settings;
  const _VersePickerSheet({
    required this.mp,
    required this.locale,
    required this.settings,
  });

  @override
  State<_VersePickerSheet> createState() => _VersePickerSheetState();
}

class _VersePickerSheetState extends State<_VersePickerSheet> {
  String? _book; // English book name
  int? _chapter;

  /// Books the loaded version actually has. Built from the verse
  /// list so we never offer a book that has no data.
  late final List<String> _availableEnglishBooks = _computeBooks();

  List<String> _computeBooks() {
    final set = <String>{};
    for (final v in widget.mp.verses) {
      final en = toEnglish(v.book) ?? v.book;
      set.add(en);
    }
    final ordered = standardBookOrder
        .where((b) => set.contains(b))
        .toList();
    return ordered;
  }

  /// Chapters available in the selected book.
  List<int> _chaptersFor(String englishBook) {
    final set = <int>{};
    for (final v in widget.mp.verses) {
      final en = toEnglish(v.book) ?? v.book;
      if (en == englishBook) set.add(v.chapter);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Verses available in the selected book + chapter.
  List<int> _versesFor(String englishBook, int chapter) {
    final set = <int>{};
    for (final v in widget.mp.verses) {
      final en = toEnglish(v.book) ?? v.book;
      if (en == englishBook && v.chapter == chapter) {
        set.add(v.verse);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Localized version of `englishBook` to display in chips,
  /// matching the rest of the app's naming convention.
  String _displayBook(String englishBook) =>
      localeAwareBookName(englishBook, widget.locale);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PickerHeader(
                step: _book == null
                    ? 1
                    : _chapter == null
                        ? 2
                        : 3,
                locale: locale,
                onBack: _book == null
                    ? null
                    : () => setState(() {
                          if (_chapter != null) {
                            _chapter = null;
                          } else {
                            _book = null;
                          }
                        }),
              ),
              const SizedBox(height: 10),
              if (_book == null)
                Expanded(
                  child: _BookGrid(
                    books: _availableEnglishBooks,
                    locale: locale,
                    onPick: (b) => setState(() => _book = b),
                  ),
                )
              else if (_chapter == null)
                Expanded(
                  child: _NumberGrid(
                    label: _displayBook(_book!),
                    numbers: _chaptersFor(_book!),
                    onPick: (c) => setState(() => _chapter = c),
                  ),
                )
              else
                Expanded(
                  child: _NumberGrid(
                    label:
                        '${_displayBook(_book!)} ${_chapter!}',
                    numbers: _versesFor(_book!, _chapter!),
                    onPick: (v) => Navigator.of(context)
                        .pop(_PickedRef(_book!, _chapter!, v)),
                  ),
                ),
              const SizedBox(height: 4),
              if (_availableEnglishBooks.isEmpty)
                Text(
                  uiStrings['statsLookupNoCurrentReading']?[locale] ??
                      'Open a passage in the reader first to continue here.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  final int step; // 1 = book, 2 = chapter, 3 = verse
  final String locale;
  final VoidCallback? onBack;
  const _PickerHeader({
    required this.step,
    required this.locale,
    required this.onBack,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stepText = step == 1
        ? (uiStrings['statsLookupStepBook']?[locale] ?? 'Pick a book')
        : step == 2
            ? (uiStrings['statsLookupStepChapter']?[locale] ??
                'Pick a chapter')
            : (uiStrings['statsLookupStepVerse']?[locale] ??
                'Pick a verse');
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: onBack,
          ),
        Icon(Icons.bookmark_outline,
            size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            stepText,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '$step / 3',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _BookGrid extends StatelessWidget {
  final List<String> books;
  final String locale;
  final ValueChanged<String> onPick;
  const _BookGrid({
    required this.books,
    required this.locale,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final b in books)
            ChoiceChip(
              label: Text(localeAwareBookName(b, locale)),
              selected: false,
              onSelected: (_) => onPick(b),
            ),
        ],
      ),
    );
  }
}

class _NumberGrid extends StatelessWidget {
  final String label;
  final List<int> numbers;
  final ValueChanged<int> onPick;
  const _NumberGrid({
    required this.label,
    required this.numbers,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in numbers)
                  SizedBox(
                    // Round 56 (continued): widened 44 → 56 because
                    // two-digit verses (10, 11, 100, 119:176) were
                    // getting ellipsised to "1.." in the picker.
                    // FittedBox.scaleDown is a safety net for the
                    // longest book Psalms 119 (verse 176).
                    width: 56,
                    child: ChoiceChip(
                      labelPadding: const EdgeInsets.symmetric(
                          horizontal: 2),
                      label: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('$n'),
                        ),
                      ),
                      selected: false,
                      onSelected: (_) => onPick(n),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
