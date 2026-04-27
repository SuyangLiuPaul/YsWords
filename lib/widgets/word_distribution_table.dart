import 'package:flutter/material.dart';

import 'package:yswords/constants/book_groups.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;

/// Holistic per-book / per-corpus distribution table for a set of
/// Strong's entries (typically the current word + its word family +
/// its synonyms).
///
/// Renders as a horizontally + vertically scrollable grid:
///   Strong's | Lemma | Gloss | Total | Sub-corpus totals | Per-book counts
///
/// Greek vs Hebrew is detected from the first entry's number prefix
/// (G/H), and the column set switches accordingly — NT books for
/// Greek, OT books for Hebrew.
class WordDistributionTable extends StatefulWidget {
  /// Strong's number to centre the table on. The widget loads this
  /// entry, its word family, and its synonyms internally, so the
  /// caller doesn't have to pre-load anything — fixes the stale-state
  /// bug where the table opened before the parent's _loadRelations
  /// had finished and only showed one row.
  final String strongsNumber;
  final String locale;
  final String? currentVersion;
  final ScrollController? scrollController;

  const WordDistributionTable({
    super.key,
    required this.strongsNumber,
    required this.locale,
    this.currentVersion,
    this.scrollController,
  });

  @override
  State<WordDistributionTable> createState() => _WordDistributionTableState();
}

class _WordDistributionTableState extends State<WordDistributionTable> {
  late Future<List<_Row>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<List<_Row>> _loadAll() async {
    final mainEntry = await StrongsService.lookup(widget.strongsNumber);
    if (mainEntry == null) return const [];

    // Fetch family + synonyms.
    final family =
        await StrongsService.wordFamily(widget.strongsNumber);
    final compare =
        await StrongsService.compareWords(widget.strongsNumber);

    // Cross-language: Hebrew → LXX Greek; Greek → Hebrew sources.
    // Note: only same-language entries are added as ROWS in the table
    // since the column set is fixed to one canon (NT or OT). The cross-
    // language entries appear in the exegesis panel itself.
    // The rows here stay strictly within the current word's canon.

    // Dedupe by Strong's # while preserving order:
    // main → family → synonyms.
    final seen = <String>{mainEntry.number};
    final entries = <StrongsEntry>[mainEntry];
    for (final e in family) {
      if (seen.add(e.number)) entries.add(e);
    }
    for (final e in compare) {
      if (seen.add(e.number)) entries.add(e);
    }

    // Fetch concordance for every row in parallel — sequential await
    // was making large families slow.
    final rows = await Future.wait(entries.map((e) async {
      final concordance = await ConcordanceService.lookup(e.number);
      return _Row(entry: e, concordance: concordance);
    }));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    return FutureBuilder<List<_Row>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        // Surface load errors so the user sees something concrete
        // instead of an empty sheet.
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: scheme.error, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load: ${snap.error}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final rows = snap.data ?? const <_Row>[];
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                uiStrings['noData']?[locale] ?? 'No data.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          );
        }
        final isGreek = rows.first.entry.number.startsWith('G');
        return _buildScrollable(rows, isGreek, scheme, locale);
      },
    );
  }

  Widget _buildScrollable(
      List<_Row> rows, bool isGreek, ColorScheme scheme, String locale) {
    final books = isGreek ? canonicalNtBooks : canonicalOtBooks;
    final groups = isGreek ? _ntGroups(locale) : _otGroups(locale);
    final headerCells = _headerCells(groups, books, scheme, locale);

    // Two-axis scrolling: vertical rows, horizontal columns.
    return SingleChildScrollView(
      controller: widget.scrollController,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(headerCells, scheme, isHeader: true),
            for (int i = 0; i < rows.length; i++)
              _row(_dataCells(rows[i], groups, books, scheme, locale),
                  scheme,
                  isHeader: false,
                  zebra: i.isOdd),
          ],
        ),
      ),
    );
  }

  // ── Header / data builders ────────────────────────────────────────

  List<_Cell> _headerCells(List<_Group> groups, List<String> books,
      ColorScheme scheme, String locale) {
    final cells = <_Cell>[
      _Cell(text: 'Strong\'s', width: 64, align: TextAlign.left),
      _Cell(
          text: uiStrings['lemma']?[locale] ?? 'Word',
          width: 96,
          align: TextAlign.left),
      _Cell(
          text: uiStrings['gloss']?[locale] ?? 'Gloss',
          width: 140,
          align: TextAlign.left),
      _Cell(
          text: uiStrings['colTotal']?[locale] ?? 'Total',
          width: 52,
          align: TextAlign.center),
    ];
    for (final g in groups) {
      cells.add(_Cell(text: g.label, width: 64, align: TextAlign.center));
    }
    for (final book in books) {
      cells.add(_Cell(
        text: _shortBook(book),
        width: 38,
        align: TextAlign.center,
        tooltip: localeAwareBookName(book, locale, widget.currentVersion),
      ));
    }
    return cells;
  }

  List<_Cell> _dataCells(_Row row, List<_Group> groups, List<String> books,
      ColorScheme scheme, String locale) {
    final entry = row.entry;
    final byBook = row.concordance?.byBook ?? const <String, int>{};
    final total = row.concordance?.total ?? 0;
    final cells = <_Cell>[
      _Cell(text: entry.number, width: 64, align: TextAlign.left, mono: true),
      _Cell(text: entry.lemma, width: 96, align: TextAlign.left, bold: true),
      _Cell(
          text: entry.localizedGloss(locale),
          width: 140,
          align: TextAlign.left,
          maxLines: 2),
      _Cell(
          text: total > 0 ? '$total' : '·',
          width: 52,
          align: TextAlign.center,
          bold: true),
    ];
    for (final g in groups) {
      final sum = g.books.fold<int>(0, (a, b) => a + (byBook[b] ?? 0));
      cells.add(_Cell(
          text: sum > 0 ? '$sum' : '·',
          width: 64,
          align: TextAlign.center,
          dim: sum == 0));
    }
    for (final book in books) {
      final count = byBook[book] ?? 0;
      cells.add(_Cell(
          text: count > 0 ? '$count' : '·',
          width: 38,
          align: TextAlign.center,
          dim: count == 0));
    }
    return cells;
  }

  // ── Row + cell rendering ─────────────────────────────────────────

  Widget _row(List<_Cell> cells, ColorScheme scheme,
      {required bool isHeader, bool zebra = false}) {
    final bg = isHeader
        ? scheme.surfaceContainerHigh
        : (zebra
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : Colors.transparent);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final c in cells) _cellWidget(c, scheme, isHeader)],
      ),
    );
  }

  Widget _cellWidget(_Cell c, ColorScheme scheme, bool isHeader) {
    final color = c.dim
        ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
        : (isHeader ? scheme.onSurfaceVariant : scheme.onSurface);
    final style = TextStyle(
      fontSize: isHeader ? 11 : 12,
      fontWeight: isHeader || c.bold ? FontWeight.w700 : FontWeight.w400,
      fontFamily: c.mono ? 'monospace' : null,
      color: color,
      height: 1.2,
    );
    final cell = Container(
      width: c.width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: c.align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        c.text,
        textAlign: c.align,
        maxLines: c.maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
    if (c.tooltip != null) {
      return Tooltip(message: c.tooltip!, child: cell);
    }
    return cell;
  }

  // ── Group definitions ────────────────────────────────────────────

  List<_Group> _ntGroups(String locale) => [
        _Group(
            label: uiStrings['colGospelsActs']?[locale] ?? 'G&A',
            books: ntGospelsActs),
        _Group(
            label: uiStrings['colPauline']?[locale] ?? 'Paul',
            books: ntPauline),
        _Group(
            label: uiStrings['colJohannine']?[locale] ?? 'John',
            books: ntJohannine),
        _Group(
            label: uiStrings['colOtherApostolic']?[locale] ?? 'Other',
            books: ntOtherApostolic),
      ];

  List<_Group> _otGroups(String locale) => [
        _Group(
            label: uiStrings['colPentateuch']?[locale] ?? 'Torah',
            books: otPentateuch),
        _Group(
            label: uiStrings['colHistory']?[locale] ?? 'Hist.',
            books: otHistory),
        _Group(
            label: uiStrings['colWisdom']?[locale] ?? 'Wisd.',
            books: otWisdom),
        _Group(
            label: uiStrings['colMajorProphets']?[locale] ?? 'Maj.Pr.',
            books: otMajorProphets),
        _Group(
            label: uiStrings['colMinorProphets']?[locale] ?? 'Min.Pr.',
            books: otMinorProphets),
      ];

  /// 3-letter abbreviation for the column header — keeps cells narrow
  /// while remaining recognizable. Falls back to the first 3 chars.
  String _shortBook(String englishBook) {
    const abbr = <String, String>{
      'Genesis': 'Gen', 'Exodus': 'Exo', 'Leviticus': 'Lev',
      'Numbers': 'Num', 'Deuteronomy': 'Deu', 'Joshua': 'Jos',
      'Judges': 'Jdg', 'Ruth': 'Rut', '1 Samuel': '1Sa',
      '2 Samuel': '2Sa', '1 Kings': '1Ki', '2 Kings': '2Ki',
      '1 Chronicles': '1Ch', '2 Chronicles': '2Ch', 'Ezra': 'Ezr',
      'Nehemiah': 'Neh', 'Esther': 'Est', 'Job': 'Job',
      'Psalms': 'Psa', 'Proverbs': 'Pro', 'Ecclesiastes': 'Ecc',
      'Song of Solomon': 'Sng', 'Isaiah': 'Isa', 'Jeremiah': 'Jer',
      'Lamentations': 'Lam', 'Ezekiel': 'Eze', 'Daniel': 'Dan',
      'Hosea': 'Hos', 'Joel': 'Joe', 'Amos': 'Amo', 'Obadiah': 'Oba',
      'Jonah': 'Jon', 'Micah': 'Mic', 'Nahum': 'Nah', 'Habakkuk': 'Hab',
      'Zephaniah': 'Zep', 'Haggai': 'Hag', 'Zechariah': 'Zec',
      'Malachi': 'Mal',
      'Matthew': 'Mat', 'Mark': 'Mar', 'Luke': 'Luk', 'John': 'Joh',
      'Acts': 'Act', 'Romans': 'Rom', '1 Corinthians': '1Co',
      '2 Corinthians': '2Co', 'Galatians': 'Gal', 'Ephesians': 'Eph',
      'Philippians': 'Phi', 'Colossians': 'Col',
      '1 Thessalonians': '1Th', '2 Thessalonians': '2Th',
      '1 Timothy': '1Ti', '2 Timothy': '2Ti', 'Titus': 'Tit',
      'Philemon': 'Phm', 'Hebrews': 'Heb', 'James': 'Jas',
      '1 Peter': '1Pe', '2 Peter': '2Pe', '1 John': '1Jn',
      '2 John': '2Jn', '3 John': '3Jn', 'Jude': 'Jud',
      'Revelation': 'Rev',
    };
    return abbr[englishBook] ??
        (englishBook.length >= 3 ? englishBook.substring(0, 3) : englishBook);
  }
}

class _Row {
  final StrongsEntry entry;
  final ConcordanceResult? concordance;
  _Row({required this.entry, required this.concordance});
}

class _Group {
  final String label;
  final List<String> books;
  _Group({required this.label, required this.books});
}

class _Cell {
  final String text;
  final double width;
  final TextAlign align;
  final bool bold;
  final bool mono;
  final bool dim;
  final int maxLines;
  final String? tooltip;
  _Cell({
    required this.text,
    required this.width,
    required this.align,
    this.bold = false,
    this.mono = false,
    this.dim = false,
    this.maxLines = 1,
    this.tooltip,
  });
}
