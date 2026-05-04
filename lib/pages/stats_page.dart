import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/bible_stats_service.dart';
import 'package:yswords/services/originals_stats_service.dart';
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          title: Text(uiStrings['statistics']?[locale] ?? 'Statistics'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
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
              Tab(
                icon: const Icon(Icons.translate_rounded),
                text: uiStrings['statsOriginals']?[locale] ?? 'Originals',
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
            _OriginalsTab(locale: locale, settings: settings),
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

/// Round 56: Hebrew + Greek originals frequency tab. User feedback:
/// "for 统计分析 should not use the chinese or english. should have
/// hebrew and greek and then view the result and with related
/// chinese or english translation next to it."
///
/// Loads pre-computed `assets/strongs/concordance.json` (Strong's #
/// → total occurrence count + per-book breakdown) and joins with
/// `hebrew.json` / `greek.json` lexicons to render lemma + transliter
/// + locale-aware gloss alongside each frequency. Filterable by
/// language (All / Hebrew / Greek). Cap at 200 by default — users
/// can tap "Show all" to see the full ~14k Strong's corpus.
class _OriginalsTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _OriginalsTab({required this.locale, required this.settings});

  @override
  State<_OriginalsTab> createState() => _OriginalsTabState();
}

class _OriginalsTabState extends State<_OriginalsTab>
    with AutomaticKeepAliveClientMixin {
  String _filter = 'all'; // 'all' | 'hebrew' | 'greek'
  bool _showAll = false;
  Future<List<OriginalsLemma>>? _future;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = OriginalsStatsService.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final settings = widget.settings;
    return FutureBuilder<List<OriginalsLemma>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? const <OriginalsLemma>[];
        if (all.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                uiStrings['statsOriginalsEmpty']?[locale] ??
                    'Original-language data not loaded.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          );
        }
        Iterable<OriginalsLemma> filtered = all;
        if (_filter == 'hebrew') {
          filtered = all.where((e) => e.isHebrew);
        } else if (_filter == 'greek') {
          filtered = all.where((e) => !e.isHebrew);
        }
        if (_query.trim().isNotEmpty) {
          final q = _query.trim().toLowerCase();
          filtered = filtered.where((e) =>
              e.strongs.toLowerCase().contains(q) ||
              e.lemma.contains(_query.trim()) ||
              e.translit.toLowerCase().contains(q) ||
              e.glossEn.toLowerCase().contains(q) ||
              e.glossZhHans.contains(_query.trim()) ||
              e.glossZhHant.contains(_query.trim()));
        }
        var rows = filtered.toList();
        final total = rows.length;
        if (!_showAll && _query.isEmpty && rows.length > 200) {
          rows = rows.take(200).toList();
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: rows.length + 2, // header + rows + footer
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) {
            if (i == 0) {
              return _buildHeader(scheme, locale, settings, total);
            }
            if (i == rows.length + 1) {
              return _buildFooter(scheme, locale, total, rows.length);
            }
            return _OriginalsRow(
              entry: rows[i - 1],
              locale: locale,
              settings: settings,
              scheme: scheme,
              rank: i,
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme scheme, String locale,
      AppSettings settings, int total) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uiStrings['statsOriginalsHint']?[locale] ??
                'Frequency of every Strong\'s number in the original Hebrew (OT) and Greek (NT) text. Tap a row to see book breakdown.',
            style: TextStyle(
              fontSize: (settings.fontSize - 3).clamp(11.0, 14.0),
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: uiStrings['statsOriginalsSearchHint']
                            ?[locale] ??
                        'Search by Strong\'s, lemma, or gloss…',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'all',
                label: Text(uiStrings['statsOriginalsAll']?[locale] ?? 'All'),
              ),
              ButtonSegment(
                value: 'hebrew',
                label: Text(uiStrings['statsOriginalsHebrew']?[locale] ??
                    'Hebrew'),
              ),
              ButtonSegment(
                value: 'greek',
                label: Text(
                    uiStrings['statsOriginalsGreek']?[locale] ?? 'Greek'),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
            multiSelectionEnabled: false,
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
      ColorScheme scheme, String locale, int total, int shown) {
    if (_query.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            (uiStrings['statsOriginalsMatchCount']?[locale] ??
                    '{shown} matches')
                .replaceAll('{shown}', '$shown'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    if (_showAll || total <= 200) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            (uiStrings['statsOriginalsTotal']?[locale] ??
                    '{total} unique Strong\'s numbers')
                .replaceAll('{total}', '$total'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TextButton.icon(
          icon: const Icon(Icons.expand_more_rounded),
          label: Text(
            (uiStrings['statsOriginalsShowAll']?[locale] ??
                    'Show all {total} entries')
                .replaceAll('{total}', '$total'),
          ),
          onPressed: () => setState(() => _showAll = true),
        ),
      ),
    );
  }
}

class _OriginalsRow extends StatelessWidget {
  final OriginalsLemma entry;
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  final int rank;

  const _OriginalsRow({
    required this.entry,
    required this.locale,
    required this.settings,
    required this.scheme,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final isHebrew = entry.isHebrew;
    final tagColor = isHebrew
        ? Colors.indigo.shade100
        : Colors.deepPurple.shade100;
    final tagFg = isHebrew
        ? Colors.indigo.shade900
        : Colors.deepPurple.shade900;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showBookBreakdown(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Rank badge
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  // Strong's # tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.strongs,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tagFg,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Lemma + transliteration
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.lemma,
                          style: TextStyle(
                            fontSize: (settings.fontSize + 2)
                                .clamp(16.0, 22.0)
                                .toDouble(),
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                            // Force LTR even for Hebrew RTL text so
                            // the lemma + count line stays in a
                            // predictable order; native rendering
                            // still draws Hebrew right-to-left
                            // within the run.
                            height: 1.3,
                          ),
                        ),
                        if (entry.translit.isNotEmpty)
                          Text(
                            entry.translit,
                            style: TextStyle(
                              fontSize:
                                  (settings.fontSize - 4).clamp(11.0, 14.0),
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Count
                  Text(
                    '${entry.count}',
                    style: TextStyle(
                      fontSize: (settings.fontSize)
                          .clamp(14.0, 18.0)
                          .toDouble(),
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (entry.glossFor(locale).isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    entry.glossFor(locale),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize:
                          (settings.fontSize - 2).clamp(12.0, 16.0),
                      color: scheme.onSurface.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBookBreakdown(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final entries = entry.byBook.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    '${entry.lemma}  ·  ${entry.strongs}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (entry.translit.isNotEmpty)
                    Text(
                      entry.translit,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    entry.glossFor(locale),
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${uiStrings['statsOriginalsByBook']?[locale] ?? 'By book'} (${entry.count})',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in entries)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${localeAwareBookName(toEnglish(e.key) ?? e.key, locale)} · ${e.value}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onPrimaryContainer,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
