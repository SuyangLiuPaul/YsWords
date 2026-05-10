import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:yswords/constants/book_groups.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/lxx_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
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

  // Separate horizontal scroll controller — the vertical one comes
  // from the parent DraggableScrollableSheet via widget.scrollController.
  late final ScrollController _horizontalController;

  // Zoom factor — multiplies all cell widths and font sizes so the
  // user can read the table at a comfortable size. Persisted only
  // for the lifetime of this widget instance.
  double _zoom = 1.0;
  static const double _minZoom = 0.7;
  static const double _maxZoom = 2.0;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<List<_Row>> _loadAll() async {
    final mainEntry = await StrongsService.lookup(widget.strongsNumber);
    if (mainEntry == null) return const [];

    // Fetch family + synonyms (same-canon rows).
    final family =
        await StrongsService.wordFamily(widget.strongsNumber);
    final compare =
        await StrongsService.compareWords(widget.strongsNumber);

    // Round 56 (continued — cross-testament): user feedback "after
    // switching the word, can you also have related hebrew or greek
    // also display as well... so we can see across all bibles from
    // different languages". Hebrew word → LXX Greek translations;
    // Greek word → Hebrew sources the LXX renders this way. Adding
    // these as rows means the table becomes a cross-canon view —
    // _buildScrollable detects both-canons-present and widens the
    // column set to all 66 books accordingly.
    final List<StrongsEntry> crossTestament;
    if (mainEntry.number.startsWith('H')) {
      crossTestament =
          await LxxService.greekEntriesFor(mainEntry.number);
    } else if (mainEntry.number.startsWith('G')) {
      crossTestament =
          await LxxService.hebrewSourceEntriesFor(mainEntry.number);
    } else {
      crossTestament = const [];
    }

    // Dedupe by Strong's # while preserving order:
    // main → family → synonyms → cross-testament.
    final seen = <String>{mainEntry.number};
    final entries = <StrongsEntry>[mainEntry];
    for (final e in family) {
      if (seen.add(e.number)) entries.add(e);
    }
    for (final e in compare) {
      if (seen.add(e.number)) entries.add(e);
    }
    for (final e in crossTestament) {
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
                    '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}: ${snap.error}',
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
        // Round 56 (continued — cross-testament): the column set
        // depends on which canons the row list spans. Same-canon
        // (only Hebrew or only Greek rows) → single canon columns,
        // matching the historical layout. Both canons present (the
        // user's word has LXX equivalents or Hebrew sources) → all
        // 66 books across both testaments.
        final hasOt = rows.any((r) => r.entry.number.startsWith('H'));
        final hasNt = rows.any((r) => r.entry.number.startsWith('G'));
        final bothCanons = hasOt && hasNt;
        return _buildScrollable(rows, hasNt, bothCanons, scheme, locale);
      },
    );
  }

  Widget _buildScrollable(
      List<_Row> rows, bool isGreek, bool bothCanons,
      ColorScheme scheme, String locale) {
    final books = bothCanons
        ? <String>[...canonicalOtBooks, ...canonicalNtBooks]
        : (isGreek ? canonicalNtBooks : canonicalOtBooks);
    final groups = bothCanons
        ? <_Group>[..._otGroups(locale), ..._ntGroups(locale)]
        : (isGreek ? _ntGroups(locale) : _otGroups(locale));
    final headerCells = _headerCells(groups, books, scheme, locale);

    // Apply zoom: scale every column width proportionally so the
    // entire table grows / shrinks together. Font sizes also scale
    // (handled inside _cellWidget via the zoom field).
    // Book columns widened from 38 → 46 so 4-digit counts (e.g. 7259
    // for very common words) fit at natural font size; FittedBox
    // (in _cellWidget) is the safety net for the rare wider case.
    final fixedWidth = (64.0 + 96.0 + 140.0 + 60.0) * _zoom;
    final groupWidth = groups.length * 70.0 * _zoom;
    final bookWidth = books.length * 46.0 * _zoom;
    final totalWidth = fixedWidth + groupWidth + bookWidth;

    // Enable mouse-drag scrolling on web: by default Flutter only
    // accepts touch + trackpad as scroll-by-drag inputs, so a desktop
    // user can't grab the table and drag it like a mobile user can.
    // Adding PointerDeviceKind.mouse lets click-and-drag work on web.
    final dragScrollBehaviour = ScrollConfiguration.of(context).copyWith(
      dragDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      },
      // Don't show the platform's overscroll glow; we have our own
      // visible Scrollbars for both axes.
      scrollbars: false,
    );

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // Zoom controls + copy button + summary footer share the
          // same axis so they stay visible while the user scrolls the
          // table.
          _buildZoomBar(scheme, locale, rows, books, groups),
          // Two-axis scroll: outer vertical (sheet's controller),
          // inner horizontal (its own controller + visible scrollbar).
          Expanded(
            child: Scrollbar(
              controller: widget.scrollController,
              thumbVisibility: true,
              child: ScrollConfiguration(
                behavior: dragScrollBehaviour,
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    notificationPredicate: (n) => n.depth == 1,
                    child: ScrollConfiguration(
                      behavior: dragScrollBehaviour,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: totalWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _row(headerCells, scheme, isHeader: true),
                              for (int i = 0; i < rows.length; i++)
                                _row(
                                    _dataCells(rows[i], groups, books, scheme,
                                        locale),
                                    scheme,
                                    isHeader: false,
                                    zebra: i.isOdd),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildSummary(rows, books, isGreek, bothCanons, scheme, locale),
        ],
      ),
    );
  }

  // ── Zoom controls ─────────────────────────────────────────────────

  Widget _buildZoomBar(ColorScheme scheme, String locale, List<_Row> rows,
      List<String> books, List<_Group> groups) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.zoom_out_map_rounded,
              size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '${(_zoom * 100).round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          // Copy table → TSV → clipboard. Same flat-table format the
          // user can paste straight into Sheets/Excel.
          IconButton(
            tooltip: uiStrings['copyTable']?[locale] ?? 'Copy table',
            icon: const Icon(Icons.copy_outlined),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () => _copyTable(rows, books, groups, locale),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: uiStrings['zoomOut']?[locale] ?? 'Zoom out',
            icon: const Icon(Icons.remove_circle_outline),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: _zoom <= _minZoom
                ? null
                : () => setState(() {
                      _zoom = (_zoom - 0.1).clamp(_minZoom, _maxZoom);
                    }),
          ),
          IconButton(
            tooltip: uiStrings['zoomReset']?[locale] ?? 'Reset zoom',
            icon: const Icon(Icons.refresh),
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            onPressed: _zoom == 1.0
                ? null
                : () => setState(() => _zoom = 1.0),
          ),
          IconButton(
            tooltip: uiStrings['zoomIn']?[locale] ?? 'Zoom in',
            icon: const Icon(Icons.add_circle_outline),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: _zoom >= _maxZoom
                ? null
                : () => setState(() {
                      _zoom = (_zoom + 0.1).clamp(_minZoom, _maxZoom);
                    }),
          ),
        ],
      ),
    );
  }

  // ── Copy table to clipboard as TSV ────────────────────────────────

  Future<void> _copyTable(List<_Row> rows, List<String> books,
      List<_Group> groups, String locale) async {
    final buf = StringBuffer();

    // Header row: Strong's, Lemma, Gloss, Total, sub-corpus totals,
    // then per-book counts. Book names are localized.
    final headers = <String>[
      uiStrings['colStrongs']?[locale] ?? "Strong's",
      uiStrings['lemma']?[locale] ?? 'Word',
      uiStrings['gloss']?[locale] ?? 'Gloss',
      uiStrings['colTotal']?[locale] ?? 'Total',
    ];
    for (final g in groups) {
      headers.add(g.label);
    }
    for (final book in books) {
      headers.add(localeAwareBookName(book, locale, widget.currentVersion));
    }
    buf.writeln(_tsvRow(headers));

    // Data rows.
    for (final r in rows) {
      final byBook = r.concordance?.byBook ?? const <String, int>{};
      final total = r.concordance?.total ?? 0;
      final cells = <String>[
        r.entry.number,
        r.entry.lemma,
        r.entry.localizedGloss(locale),
        '$total',
      ];
      for (final g in groups) {
        final sum = g.books.fold<int>(0, (a, b) => a + (byBook[b] ?? 0));
        cells.add('$sum');
      }
      for (final book in books) {
        cells.add('${byBook[book] ?? 0}');
      }
      buf.writeln(_tsvRow(cells));
    }

    if (!mounted) return;
    await ClipboardHelper.copyWithFeedback(
        context, buf.toString().trimRight());
  }

  String _tsvRow(List<String> cells) =>
      cells.map((s) => s.replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t');

  // ── Summary footer ────────────────────────────────────────────────

  Widget _buildSummary(List<_Row> rows, List<String> books, bool isGreek,
      bool bothCanons, ColorScheme scheme, String locale) {
    // Aggregate stats across every row.
    final totalOccurrences =
        rows.fold<int>(0, (a, r) => a + (r.concordance?.total ?? 0));
    // Find the book with the most combined occurrences across all rows.
    final perBook = <String, int>{};
    for (final r in rows) {
      final byBook = r.concordance?.byBook ?? const <String, int>{};
      byBook.forEach((b, n) {
        perBook[b] = (perBook[b] ?? 0) + n;
      });
    }
    String? topBook;
    int topCount = 0;
    perBook.forEach((b, n) {
      if (n > topCount) {
        topBook = b;
        topCount = n;
      }
    });
    final wordCount = rows.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            uiStrings['summary']?[locale] ?? 'Summary',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _statChip(
                  uiStrings['statWords']?[locale] ?? 'Words',
                  '$wordCount',
                  scheme),
              _statChip(
                  uiStrings['statTotal']?[locale] ?? 'Total occurrences',
                  '$totalOccurrences',
                  scheme),
              _statChip(
                  uiStrings['statTopBook']?[locale] ?? 'Most frequent book',
                  topBook == null
                      ? '—'
                      : '${localeAwareBookName(topBook!, locale, widget.currentVersion)} ($topCount)',
                  scheme),
              _statChip(
                  uiStrings['statCanon']?[locale] ?? 'Canon',
                  bothCanons
                      ? (uiStrings['bothTestaments']?[locale] ??
                          'Both Testaments')
                      : (isGreek
                          ? (uiStrings['newTestament']?[locale] ??
                              'Greek Bible')
                          : (uiStrings['oldTestament']?[locale] ??
                              'Hebrew Bible')),
                  scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, ColorScheme scheme) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ── Header / data builders ────────────────────────────────────────

  List<_Cell> _headerCells(List<_Group> groups, List<String> books,
      ColorScheme scheme, String locale) {
    final cells = <_Cell>[
      _Cell(
          text: uiStrings['colStrongs']?[locale] ?? "Strong's",
          width: 64,
          align: TextAlign.left),
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
          width: 60,
          align: TextAlign.center),
    ];
    for (final g in groups) {
      cells.add(_Cell(text: g.label, width: 70, align: TextAlign.center));
    }
    for (final book in books) {
      cells.add(_Cell(
        text: _shortBook(book, locale),
        width: 46,
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
          width: 60,
          align: TextAlign.center,
          bold: true),
    ];
    for (final g in groups) {
      final sum = g.books.fold<int>(0, (a, b) => a + (byBook[b] ?? 0));
      cells.add(_Cell(
          text: sum > 0 ? '$sum' : '·',
          width: 70,
          align: TextAlign.center,
          dim: sum == 0));
    }
    for (final book in books) {
      final count = byBook[book] ?? 0;
      cells.add(_Cell(
          text: count > 0 ? '$count' : '·',
          width: 46,
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
        // Default crossAxisAlignment (center) — each cell sizes to its
        // text content. CrossAxisAlignment.stretch was causing render
        // issues on web because cells had no intrinsic vertical bound.
        children: [for (final c in cells) _cellWidget(c, scheme, isHeader)],
      ),
    );
  }

  Widget _cellWidget(_Cell c, ColorScheme scheme, bool isHeader) {
    final color = c.dim
        ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
        : (isHeader ? scheme.onSurfaceVariant : scheme.onSurface);
    // Scale font size and column width by the current zoom factor so
    // every cell grows / shrinks together when the user taps +/−.
    final style = TextStyle(
      fontSize: (isHeader ? 11 : 12) * _zoom,
      fontWeight: isHeader || c.bold ? FontWeight.w700 : FontWeight.w400,
      fontFamily: c.mono ? 'monospace' : null,
      color: color,
      height: 1.2,
    );
    // Numeric cells (centered) must NEVER show "..." for digits — that
    // would corrupt counts like "27" → "..." which is meaningless.
    // Use FittedBox(scaleDown) so the number scales down to fit its
    // cell instead of truncating. Identity cells (left-aligned) keep
    // ellipsis for graceful long-text handling.
    final isNumeric = c.align == TextAlign.center;
    final textWidget = Text(
      c.text,
      textAlign: c.align,
      maxLines: c.maxLines,
      overflow: isNumeric ? TextOverflow.visible : TextOverflow.ellipsis,
      softWrap: !isNumeric && c.maxLines > 1,
      style: style,
    );
    final cell = Container(
      width: c.width * _zoom,
      padding: EdgeInsets.symmetric(horizontal: 6 * _zoom, vertical: 6 * _zoom),
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
      child: isNumeric
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: textWidget,
            )
          : textWidget,
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

  /// Locale-aware book-name abbreviation for the column header —
  /// keeps cells narrow while remaining recognizable. Round 56 fix:
  /// previously English-only ("Mat" / "Mar" / "Luk" / "Joh"…), so
  /// Chinese readers saw English codes mixed into an otherwise-
  /// localised table. Now returns the standard 1-character (or 2-3
  /// character for paired books like 撒上 / 撒下) abbreviations used
  /// in Chinese Bible typesetting when locale starts with 'zh',
  /// falling back to English 3-letter for any other locale.
  String _shortBook(String englishBook, String locale) {
    if (locale.startsWith('zh')) {
      final hant = locale == 'zh-Hant';
      final m = hant ? _shortBooksHant : _shortBooksHans;
      final v = m[englishBook];
      if (v != null) return v;
      // Fallback: take the last 1 char of the localized full name.
      // localeAwareBookName returns the locale's book name; using its
      // last character keeps the abbreviation visually consistent
      // with the rest of the page even for unknown books.
      final full = localeAwareBookName(englishBook, locale, '');
      return full.isEmpty ? englishBook : full.characters.last;
    }
    final v = _shortBooksEn[englishBook];
    return v ??
        (englishBook.length >= 3 ? englishBook.substring(0, 3) : englishBook);
  }
}

const Map<String, String> _shortBooksEn = {
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

/// Standard 1-character Chinese (Simplified) abbreviations used by
/// every major Chinese Bible typesetting tradition (CUV / CNV /
/// RCUV). Numbered books (1 Samuel, 1 Corinthians, 1 John, …) use
/// 2-character forms (撒上 / 林前 / 约一) to disambiguate.
const Map<String, String> _shortBooksHans = {
  'Genesis': '创', 'Exodus': '出', 'Leviticus': '利', 'Numbers': '民',
  'Deuteronomy': '申', 'Joshua': '书', 'Judges': '士', 'Ruth': '得',
  '1 Samuel': '撒上', '2 Samuel': '撒下',
  '1 Kings': '王上', '2 Kings': '王下',
  '1 Chronicles': '代上', '2 Chronicles': '代下',
  'Ezra': '拉', 'Nehemiah': '尼', 'Esther': '斯', 'Job': '伯',
  'Psalms': '诗', 'Proverbs': '箴', 'Ecclesiastes': '传',
  'Song of Solomon': '歌', 'Isaiah': '赛', 'Jeremiah': '耶',
  'Lamentations': '哀', 'Ezekiel': '结', 'Daniel': '但',
  'Hosea': '何', 'Joel': '珥', 'Amos': '摩', 'Obadiah': '俄',
  'Jonah': '拿', 'Micah': '弥', 'Nahum': '鸿', 'Habakkuk': '哈',
  'Zephaniah': '番', 'Haggai': '该', 'Zechariah': '亚', 'Malachi': '玛',
  'Matthew': '太', 'Mark': '可', 'Luke': '路', 'John': '约', 'Acts': '徒',
  'Romans': '罗',
  '1 Corinthians': '林前', '2 Corinthians': '林后',
  'Galatians': '加', 'Ephesians': '弗', 'Philippians': '腓',
  'Colossians': '西',
  '1 Thessalonians': '帖前', '2 Thessalonians': '帖后',
  '1 Timothy': '提前', '2 Timothy': '提后',
  'Titus': '多', 'Philemon': '门', 'Hebrews': '来', 'James': '雅',
  '1 Peter': '彼前', '2 Peter': '彼后',
  '1 John': '约一', '2 John': '约二', '3 John': '约三',
  'Jude': '犹', 'Revelation': '启',
};

/// Traditional-Chinese variants. Most abbreviations are stable
/// across Hans/Hant; only a handful need glyph swaps (书→書,
/// 传→傳, 鸿→鴻, 玛→瑪, 启→啟, 历→歷, 罗→羅, 约→約, 历→歷, 弥→彌,
/// 该→該, 亚→亞, 帖→帖 same). We only override the ones that
/// actually differ.
const Map<String, String> _shortBooksHant = {
  'Genesis': '創', 'Exodus': '出', 'Leviticus': '利', 'Numbers': '民',
  'Deuteronomy': '申', 'Joshua': '書', 'Judges': '士', 'Ruth': '得',
  '1 Samuel': '撒上', '2 Samuel': '撒下',
  '1 Kings': '王上', '2 Kings': '王下',
  '1 Chronicles': '代上', '2 Chronicles': '代下',
  'Ezra': '拉', 'Nehemiah': '尼', 'Esther': '斯', 'Job': '伯',
  'Psalms': '詩', 'Proverbs': '箴', 'Ecclesiastes': '傳',
  'Song of Solomon': '歌', 'Isaiah': '賽', 'Jeremiah': '耶',
  'Lamentations': '哀', 'Ezekiel': '結', 'Daniel': '但',
  'Hosea': '何', 'Joel': '珥', 'Amos': '摩', 'Obadiah': '俄',
  'Jonah': '拿', 'Micah': '彌', 'Nahum': '鴻', 'Habakkuk': '哈',
  'Zephaniah': '番', 'Haggai': '該', 'Zechariah': '亞', 'Malachi': '瑪',
  'Matthew': '太', 'Mark': '可', 'Luke': '路', 'John': '約', 'Acts': '徒',
  'Romans': '羅',
  '1 Corinthians': '林前', '2 Corinthians': '林後',
  'Galatians': '加', 'Ephesians': '弗', 'Philippians': '腓',
  'Colossians': '西',
  '1 Thessalonians': '帖前', '2 Thessalonians': '帖後',
  '1 Timothy': '提前', '2 Timothy': '提後',
  'Titus': '多', 'Philemon': '門', 'Hebrews': '來', 'James': '雅',
  '1 Peter': '彼前', '2 Peter': '彼後',
  '1 John': '約一', '2 John': '約二', '3 John': '約三',
  'Jude': '猶', 'Revelation': '啟',
};

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
