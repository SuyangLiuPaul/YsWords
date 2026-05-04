import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/bible_stats_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/version_mapper.dart' show toEnglish, localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Statistical analysis of the currently-loaded Bible version —
/// vocabulary frequency, per-book size, hapax legomena, reading
/// time. Computes lazily once per version and renders three tabs:
/// Overview / Books / Vocabulary.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final mainProvider = context.watch<MainProvider>();
    final locale = settings.locale;
    final stats = BibleStatsService.compute(
        mainProvider.currentVersion, mainProvider.verses);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          title: Text(uiStrings['statistics']?[locale] ?? 'Statistics'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            // Round 56 user feedback: "统计分析的几个 tab 的字看不清，
            // 颜色搭配有问题". The default TabBar inherits AppBar
            // foreground colors, but with the new primary AppBar
            // (Round 56 theme update) the unselected-tab colour
            // ended up with low contrast against the primary
            // background. Force explicit high-contrast colors:
            // selected = full onPrimary, unselected = onPrimary at
            // 78% opacity (clearly distinct from selected but still
            // readable).
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context)
                .colorScheme
                .onPrimary
                .withValues(alpha: 0.78),
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            tabs: [
              Tab(
                icon: const Icon(Icons.dashboard_outlined),
                text: uiStrings['statsOverview']?[locale] ?? 'Overview',
              ),
              Tab(
                icon: const Icon(Icons.menu_book_outlined),
                text: uiStrings['statsBooks']?[locale] ?? 'Books',
              ),
              Tab(
                icon: const Icon(Icons.spellcheck),
                text: uiStrings['statsVocabulary']?[locale] ?? 'Vocabulary',
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: uiStrings['copyTable']?[locale] ?? 'Copy table',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => _copyAllStats(context, stats, locale,
                  mainProvider.currentVersion),
            ),
            const HomeIconButton(),
          ],
        ),
        body: TabBarView(
          children: [
            _OverviewTab(stats: stats, locale: locale, version: mainProvider.currentVersion),
            _BooksTab(
                stats: stats,
                locale: locale,
                currentVersion: mainProvider.currentVersion),
            _VocabularyTab(
                stats: stats,
                locale: locale,
                currentVersion: mainProvider.currentVersion),
          ],
        ),
      ),
    );
  }

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
            fontFamily: settings.fontFamily,
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
                      fontFamily: settings.fontFamily,
                      fontSize: (fs - 4).clamp(13.0, 18.0).toDouble(),
                      fontWeight: FontWeight.w600,
                    ))),
            Text(_humanNum(b.words),
                style: TextStyle(
                  fontFamily: settings.fontFamily,
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
                fontFamily: settings.fontFamily,
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
              fontFamily: settings.fontFamily,
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
      fontFamily: settings.fontFamily,
      fontSize: (fs - 5).clamp(13.0, 17.0).toDouble(),
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    final cellStyle = TextStyle(
      fontFamily: settings.fontFamily,
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
            fontFamily: settings.fontFamily,
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
                    fontFamily: settings.fontFamily,
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
            fontFamily: settings.fontFamily,
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
              fontFamily: settings.fontFamily,
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
