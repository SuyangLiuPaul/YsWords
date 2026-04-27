import 'dart:async' show unawaited;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:yswords/constants/text_patterns.dart'
    show sanitizeForSearch, notePattern, bracePattern, squarePattern;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/original_word.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/lxx_service.dart';
import 'package:yswords/services/originals_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/utils/version_mapper.dart'
    show localeAwareBookName, toEnglish;
import 'package:yswords/widgets/word_distribution.dart';
import 'package:yswords/widgets/word_distribution_table.dart';

/// Bottom sheet that shows the original Hebrew/Greek text for one or
/// more selected verses, with each word as a tappable chip linked to
/// its Strong's lexicon entry.
///
/// Pure data — no AI, no network. The sheet falls back to a friendly
/// "no original-language data for this verse yet" message when bundled
/// coverage is missing for the verse, so the affordance always opens.
///
/// `onNavigateRef` is invoked when the user taps a concordance entry
/// (e.g. "John 3:16"). The host widget is responsible for closing the
/// sheet, switching to that book/chapter, and scrolling to the verse —
/// the sheet stays presentation-only.
class OriginalsSheet extends StatefulWidget {
  final List<Verse> verses;
  final List<Verse> allVerses;
  final String locale;
  final String? currentVersion;
  final void Function(ConcordanceRef ref)? onNavigateRef;

  const OriginalsSheet({
    super.key,
    required this.verses,
    this.allVerses = const [],
    required this.locale,
    this.currentVersion,
    this.onNavigateRef,
  });

  @override
  State<OriginalsSheet> createState() => _OriginalsSheetState();
}

class _OriginalsSheetState extends State<OriginalsSheet> {
  late Future<List<_VerseOriginals>> _future;
  OriginalWord? _selectedWord;
  StrongsEntry? _selectedEntry;
  ConcordanceResult? _selectedConcordance;
  // When non-null, the user is browsing a root entry instead of the
  // word entry. Back button reverts to the word entry.
  StrongsEntry? _rootEntry;
  ConcordanceResult? _rootConcordance;
  bool _loadingEntry = false;
  // TapGestureRecognizers for inline derivation links — disposed on change.
  final _tapRecognizers = <TapGestureRecognizer>[];

  // Strong's-entry cache for the interlinear gloss line rendered below
  // each word chip. Populated once in [_loadAll] and reused by every
  // chip so we don't re-fetch the same lemma over and over.
  final Map<String, StrongsEntry?> _glossCache = {};

  // Which book group is currently expanded in the concordance section.
  // Null = all collapsed. Reset whenever the user switches to a new
  // word entry or root entry.
  String? _expandedConcordanceBook;

  // Loaded interlinear data — set once _loadAll completes so the
  // "copy table" button can build the TSV without re-awaiting the future.
  List<_VerseOriginals>? _verseOriginals;

  // "englishBook-chapter-verse" → cleaned verse text for concordance preview.
  late final Map<String, String> _verseIndex;

  // Word family (siblings + children) and synonyms (compare refs) for the
  // currently displayed entry. Populated asynchronously after each word tap.
  List<StrongsEntry> _wordFamily = const [];
  List<StrongsEntry> _compareWords = const [];

  // Pre-fetched concordances for every related entry (family + synonym),
  // so tapping a chip can immediately show inline verse refs without
  // a per-tap network round trip. Populated by _loadRelations.
  Map<String, ConcordanceResult?> _relatedConcordances = {};

  // Strong's # of the word-family / synonym chip currently expanded
  // inline (showing its verse refs below the Wrap). Null = all collapsed.
  String? _expandedRelatedNumber;

  // LXX Greek equivalents for the current Hebrew entry (empty for
  // Greek entries). Tapping a chip navigates into that Greek entry,
  // which then loads its own family / synonyms / verses — letting
  // the user pivot from Hebrew to Greek word study seamlessly.
  List<StrongsEntry> _lxxEquivalents = const [];

  // Reverse LXX: Hebrew Strong's that the LXX renders using the
  // current Greek entry. Empty for Hebrew entries. Lets a NT reader
  // surface OT roots — e.g. for κύριος (G2962) shows יהוה (H3068),
  // אֲדֹנָי (H136), etc.
  List<StrongsEntry> _hebrewSources = const [];

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _verseIndex = {
      for (final v in widget.allVerses)
        '${(toEnglish(v.book) ?? v.book)}-${v.chapter}-${v.verse}': v.text,
    };
  }

  @override
  void dispose() {
    _clearTapRecognizers();
    super.dispose();
  }

  void _clearTapRecognizers() {
    for (final r in _tapRecognizers) {
      r.dispose();
    }
    _tapRecognizers.clear();
  }

  Future<List<_VerseOriginals>> _loadAll() async {
    final results = <_VerseOriginals>[];
    for (final v in widget.verses) {
      final english = toEnglish(v.book) ?? v.book;
      final words = await OriginalsService.forVerse(english, v.chapter, v.verse);
      results.add(_VerseOriginals(verse: v, words: words));
    }
    // Prefetch Strong's entries for every unique number across all
    // verses so the interlinear gloss row under each chip can render
    // synchronously when the chip first builds. Lookups are async but
    // hit a cached lexicon after the first call, so wrapping them in
    // `Future.wait` parallelises the dictionary scans.
    final uniqueNums = <String>{};
    for (final r in results) {
      for (final w in r.words ?? const <OriginalWord>[]) {
        uniqueNums.add(w.strongs);
      }
    }
    await Future.wait(uniqueNums.map((n) async {
      if (_glossCache.containsKey(n)) return;
      _glossCache[n] = await StrongsService.lookup(n);
    }));
    if (mounted) setState(() => _verseOriginals = results);
    return results;
  }

  Future<void> _onWordTap(OriginalWord w) async {
    _clearTapRecognizers();
    setState(() {
      _selectedWord = w;
      _selectedEntry = null;
      _selectedConcordance = null;
      _rootEntry = null;
      _rootConcordance = null;
      _loadingEntry = true;
      _expandedConcordanceBook = null;
      _wordFamily = const [];
      _compareWords = const [];
      _relatedConcordances = const {};
      _expandedRelatedNumber = null;
      _lxxEquivalents = const [];
      _hebrewSources = const [];
    });
    // Fire both lookups in parallel — Strong's entry is per-language,
    // concordance is a single shared file that gets warmed by the
    // first lookup of the session.
    final entryFuture = StrongsService.lookup(w.strongs);
    final concordanceFuture = ConcordanceService.lookup(w.strongs);
    final entry = await entryFuture;
    final concordance = await concordanceFuture;
    if (!mounted) return;
    _clearTapRecognizers();
    setState(() {
      _selectedEntry = entry;
      _selectedConcordance = concordance;
      _loadingEntry = false;
      // Auto-open the first book group so the user sees refs immediately.
      _expandedConcordanceBook =
          concordance?.refs.isNotEmpty == true ? concordance!.refs.first.englishBook : null;
    });
    // Word family + synonyms load in the background — doesn't block the entry card.
    unawaited(_loadRelations(w.strongs));
  }

  Future<void> _loadRootEntry(String strongsNumber) async {
    _clearTapRecognizers();
    setState(() {
      _loadingEntry = true;
      _expandedConcordanceBook = null;
      _wordFamily = const [];
      _compareWords = const [];
      _relatedConcordances = const {};
      _expandedRelatedNumber = null;
      _lxxEquivalents = const [];
      _hebrewSources = const [];
    });
    final entryFuture = StrongsService.lookup(strongsNumber);
    final concordanceFuture = ConcordanceService.lookup(strongsNumber);
    final entry = await entryFuture;
    final concordance = await concordanceFuture;
    if (!mounted) return;
    _clearTapRecognizers();
    setState(() {
      _rootEntry = entry;
      _rootConcordance = concordance;
      _loadingEntry = false;
      _expandedConcordanceBook =
          concordance?.refs.isNotEmpty == true ? concordance!.refs.first.englishBook : null;
    });
    unawaited(_loadRelations(strongsNumber));
  }

  void _clearRoot() {
    _clearTapRecognizers();
    setState(() {
      _rootEntry = null;
      _rootConcordance = null;
      _wordFamily = const [];
      _compareWords = const [];
      _relatedConcordances = const {};
      _expandedRelatedNumber = null;
      _lxxEquivalents = const [];
      _hebrewSources = const [];
      // Restore the word-entry's auto-opened first book.
      _expandedConcordanceBook = _selectedConcordance?.refs.isNotEmpty == true
          ? _selectedConcordance!.refs.first.englishBook
          : null;
    });
    if (_selectedWord != null) {
      unawaited(_loadRelations(_selectedWord!.strongs));
    }
  }

  Future<void> _loadRelations(String number) async {
    final family = await StrongsService.wordFamily(number);
    final compare = await StrongsService.compareWords(number);
    // Hebrew entries get LXX Greek equivalents (forward).
    // Greek entries get Hebrew sources (reverse LXX).
    final lxx = number.startsWith('H')
        ? await LxxService.greekEntriesFor(number)
        : const <StrongsEntry>[];
    final hebSrc = number.startsWith('G')
        ? await LxxService.hebrewSourceEntriesFor(number)
        : const <StrongsEntry>[];
    if (!mounted) return;
    // Prefetch concordances for every related entry in parallel.
    final all = <StrongsEntry>[...family, ...compare, ...lxx, ...hebSrc];
    final entries = <String, ConcordanceResult?>{};
    await Future.wait(all.map((e) async {
      entries[e.number] = await ConcordanceService.lookup(e.number);
    }));
    if (!mounted) return;
    setState(() {
      _wordFamily = family;
      _compareWords = compare;
      _lxxEquivalents = lxx;
      _hebrewSources = hebSrc;
      _relatedConcordances = entries;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final title = uiStrings['originalText']?[locale] ?? 'Original Text';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_stories, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          uiStrings['interlinearHint']?[locale] ??
                              'Original · Strong\'s gloss',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_verseOriginals != null)
                    IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      iconSize: 20,
                      tooltip: uiStrings['copyTable']?[locale] ?? 'Copy word table',
                      onPressed: () => _copyInterlinearTable(context),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<_VerseOriginals>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snap.data ?? const [];
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      for (final vo in data) _buildVerseBlock(vo, scheme),
                      if (_selectedWord != null) ...[
                        const SizedBox(height: 16),
                        _buildEntryCard(context, scheme, locale),
                      ] else ...[
                        const SizedBox(height: 16),
                        _buildHint(scheme, locale),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVerseBlock(_VerseOriginals vo, ColorScheme scheme) {
    final ref = '${vo.verse.book} ${vo.verse.chapter}:${vo.verse.verse}';
    final isHebrew = (vo.words ?? const []).isNotEmpty &&
        vo.words!.first.strongs.startsWith('H');
    final words = vo.words;
    // Verse text from the user's current Bible version, with `{...}`
    // emphasis braces and `<note:...>` markers stripped so the panel
    // reads cleanly. We keep `[...]` (e.g. KJV italicized supplied
    // words) since that's part of the published text.
    final verseText = sanitizeForSearch(vo.verse.text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          if (verseText.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Show the verse as it appears in the user's current
            // version above the original-language line so the reader
            // can compare their translation to the Hebrew/Greek and
            // the per-word glosses below.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: scheme.primary, width: 3),
                ),
              ),
              child: Text(
                verseText,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (words == null || words.isEmpty)
            Text(
              uiStrings['originalNotAvailable']?[widget.locale] ??
                  'Original-language data not available for this verse yet.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Directionality(
              textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                alignment: isHebrew ? WrapAlignment.end : WrapAlignment.start,
                children: [
                  for (final w in words) _wordChip(w, scheme),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _wordChip(OriginalWord w, ColorScheme scheme) {
    final isSelected = _selectedWord?.strongs == w.strongs &&
        _selectedWord?.text == w.text;
    // Interlinear gloss row — the Strong's entry's primary meaning in
    // the user's locale (English `gloss` or Chinese `glossZh`). Shown
    // beneath the original word so a reader who doesn't know
    // Hebrew/Greek can immediately see what each word means.
    final entry = _glossCache[w.strongs];
    final gloss =
        entry?.localizedGloss(widget.locale) ?? '';
    return InkWell(
      onTap: () => _onWordTap(w),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        constraints: const BoxConstraints(minWidth: 56, maxWidth: 140),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              w.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            if (w.translit != null && w.translit!.isNotEmpty)
              Text(
                w.translit!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (gloss.isNotEmpty) ...[
              const SizedBox(height: 2),
              // Gloss is locale-script (LTR/Chinese), even when the
              // surrounding chip Wrap is RTL for Hebrew. Force LTR so
              // multi-word glosses don't render right-to-left inside
              // the Hebrew Directionality scope.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  gloss,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: scheme.primary.withValues(alpha: 0.85),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, ColorScheme scheme, String locale) {
    final w = _selectedWord!;
    if (_loadingEntry) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // When the user has tapped a root link, show that entry instead.
    final isBrowsingRoot = _rootEntry != null;
    final entry = isBrowsingRoot ? _rootEntry : _selectedEntry;
    final concordance = isBrowsingRoot ? _rootConcordance : _selectedConcordance;
    // The displayed number: root number when browsing, otherwise the word's.
    final displayNumber = entry?.number ?? w.strongs;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isBrowsingRoot) ...[
                InkWell(
                  onTap: _clearRoot,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back,
                        size: 18, color: scheme.primary),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry?.lemma ?? w.text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.table_chart_outlined),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: uiStrings['distributionTable']?[locale] ??
                    'Distribution Table',
                onPressed: () => _showDistributionTable(context),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: uiStrings['copyWordStudy']?[locale] ?? 'Copy word study',
                onPressed: () => _copyWordEntry(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (entry != null) ...[
            if (entry.translit.isNotEmpty || entry.pronunciation.isNotEmpty)
              Text(
                [
                  if (entry.translit.isNotEmpty) entry.translit,
                  if (entry.pronunciation.isNotEmpty) '/${entry.pronunciation}/',
                ].join('  '),
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            // Headline gloss and full definition follow the user's
            // current locale: Chinese for zh-Hans / zh-Hant when CBOL
            // has data, English fallback otherwise.
            if (entry.localizedGloss(locale).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.localizedGloss(locale),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
            if (entry.partOfSpeech != null &&
                entry.partOfSpeech!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.partOfSpeech!,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ],
            if (entry.localizedDefinition(locale).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                entry.localizedDefinition(locale),
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
              if (locale.startsWith('zh') &&
                  (entry.definitionZh ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  // CC-BY-NC-SA 4.0 attribution required by the source.
                  '中文释义来源：CBOL · bible.fhl.net (CC-BY-NC-SA 4.0)',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            // Derivation / etymology line with tappable Strong's refs.
            if ((entry.derivation ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDerivationRich(entry.derivation!, scheme),
            ],
            if (_wordFamily.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRelatedSection(
                uiStrings['wordFamily']?[locale] ?? 'Word Family',
                _wordFamily, scheme, locale,
              ),
            ],
            if (_compareWords.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRelatedSection(
                uiStrings['synonyms']?[locale] ?? 'Synonyms',
                _compareWords, scheme, locale,
              ),
            ],
            if (_lxxEquivalents.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRelatedSection(
                uiStrings['lxxEquivalents']?[locale] ?? 'LXX Equivalents',
                _lxxEquivalents, scheme, locale,
              ),
            ],
            if (_hebrewSources.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRelatedSection(
                uiStrings['hebrewSources']?[locale] ?? 'Hebrew Sources',
                _hebrewSources, scheme, locale,
              ),
            ],
          ] else
            Text(
              uiStrings['strongsNotFound']?[locale] ??
                  'Lexicon entry not found for $displayNumber.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (concordance != null && concordance.byBook.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
                height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            WordDistribution(
              byBook: concordance.byBook,
              locale: locale,
              currentVersion: widget.currentVersion,
            ),
          ],
          if (concordance != null && concordance.refs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
                height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            _buildConcordance(scheme, locale, concordance),
          ],
        ],
      ),
    );
  }

  /// Renders [text] with any Strong's refs ([GH]\d+) as tappable blue links.
  /// Recognizers are tracked in [_tapRecognizers] and disposed on state change.
  Widget _buildDerivationRich(String text, ColorScheme scheme) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'([GH]\d+)');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final num = m.group(1)!;
      final rec = TapGestureRecognizer()
        ..onTap = () => _loadRootEntry(num);
      _tapRecognizers.add(rec);
      spans.add(TextSpan(
        text: num,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: scheme.primary.withValues(alpha: 0.6),
        ),
        recognizer: rec,
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
          height: 1.45,
        ),
        children: spans,
      ),
    );
  }

  // ── Word family + synonyms ──────────────────────────────────────────────────

  Widget _buildRelatedSection(
      String label, List<StrongsEntry> entries, ColorScheme scheme, String locale) {
    // Find which entry (if any) in this section is expanded — only
    // expand inline within the section that owns the chip, so a tap
    // on a Word-Family chip doesn't dangle verses inside the Synonyms
    // section.
    StrongsEntry? expanded;
    if (_expandedRelatedNumber != null) {
      for (final e in entries) {
        if (e.number == _expandedRelatedNumber) {
          expanded = e;
          break;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final e in entries) _relatedChip(e, scheme, locale)],
        ),
        if (expanded != null) ...[
          const SizedBox(height: 8),
          _buildExpandedRelatedVerses(expanded, scheme, locale),
        ],
      ],
    );
  }

  Widget _buildExpandedRelatedVerses(
      StrongsEntry e, ColorScheme scheme, String locale) {
    final cr = _relatedConcordances[e.number];
    if (cr == null) {
      // Concordance still loading or genuinely unavailable.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
        ),
      );
    }
    if (cr.refs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          uiStrings['concordanceNoResults']?[locale] ??
              'No verse references for this entry.',
          style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic),
        ),
      );
    }
    final shown = cr.refs.take(8).toList();
    final remaining = cr.refs.length - shown.length;
    final usedTemplate =
        uiStrings['concordanceUsed']?[locale] ?? 'Used {count} times';
    final usedLabel = usedTemplate.replaceAll('{count}', cr.total.toString());
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  e.number,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${e.lemma} · $usedLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Open the full word study for this entry.
              InkWell(
                onTap: () => _loadRootEntry(e.number),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        uiStrings['fullStudy']?[locale] ?? 'Full study',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded,
                          size: 12, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < shown.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: scheme.outlineVariant.withValues(alpha: 0.3)),
            _refRow(shown[i], scheme),
          ],
          if (remaining > 0) ...[
            const SizedBox(height: 4),
            Text(
              '+ $remaining ${uiStrings['moreRefs']?[locale] ?? 'more'}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _relatedChip(StrongsEntry e, ColorScheme scheme, String locale) {
    // Material ancestor guarantees InkWell.onTap fires on Flutter web.
    // Tap behavior: toggle inline verse-list expansion. To open the
    // full word study, the user uses the "Full study →" affordance
    // inside the expanded section.
    final isExpanded = _expandedRelatedNumber == e.number;
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: () => setState(() {
        _expandedRelatedNumber = isExpanded ? null : e.number;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        constraints: const BoxConstraints(maxWidth: 200),
        decoration: BoxDecoration(
          color: isExpanded
              ? scheme.primaryContainer
              : scheme.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isExpanded ? scheme.primary : scheme.outlineVariant,
            width: isExpanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e.number,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: scheme.secondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    e.lemma,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              e.localizedGloss(locale),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Copy helpers ────────────────────────────────────────────────────────────

  Future<void> _copyInterlinearTable(BuildContext ctx) async {
    final data = _verseOriginals;
    if (data == null) return;
    final locale = widget.locale;
    final buf = StringBuffer();
    buf.writeln("Verse\tWord\tStrong's\tLemma\tTransliteration\tPronunciation\tGloss");
    for (final vo in data) {
      final en = toEnglish(vo.verse.book) ?? vo.verse.book;
      final verseRef =
          '${localeAwareBookName(en, locale, widget.currentVersion)} '
          '${vo.verse.chapter}:${vo.verse.verse}';
      for (final w in vo.words ?? const <OriginalWord>[]) {
        final entry = _glossCache[w.strongs];
        buf.writeln([
          verseRef,
          w.text,
          w.strongs,
          entry?.lemma ?? '',
          entry?.translit ?? w.translit ?? '',
          entry?.pronunciation ?? '',
          entry?.localizedGloss(locale) ?? '',
        ].map((s) => s.replaceAll('\t', ' ')).join('\t'));
      }
    }
    await Clipboard.setData(ClipboardData(text: buf.toString().trimRight()));
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(uiStrings['copied']?[locale] ?? 'Copied!'),
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _copyWordEntry(BuildContext ctx) async {
    final isBrowsingRoot = _rootEntry != null;
    final entry = isBrowsingRoot ? _rootEntry : _selectedEntry;
    final concordance = isBrowsingRoot ? _rootConcordance : _selectedConcordance;
    final w = _selectedWord;
    if (entry == null && w == null) return;
    final locale = widget.locale;
    final buf = StringBuffer();

    // Single flat TSV so the whole family + synonyms paste cleanly into
    // Sheets/Excel as one table. Each row is tagged with a Section.
    buf.writeln(
        "Section\tStrong's\tLemma\tTranslit\tGloss\tDefinition\tReference\tVerse Text");

    void writeEntry(String section, StrongsEntry e, ConcordanceResult? cr) {
      final base = [
        section,
        e.number,
        e.lemma,
        e.translit,
        e.localizedGloss(locale),
        e.localizedDefinition(locale),
      ].map((s) => s.replaceAll('\t', ' ').replaceAll('\n', ' ')).toList();
      if (cr != null && cr.refs.isNotEmpty) {
        for (final r in cr.refs) {
          final label =
              '${localeAwareBookName(r.englishBook, locale, widget.currentVersion)} '
              '${r.chapter}:${r.verse}';
          final verseText =
              (_lookupVerseText(r) ?? '').replaceAll('\t', ' ').replaceAll('\n', ' ');
          buf.writeln([...base, label, verseText].join('\t'));
        }
      } else {
        buf.writeln([...base, '', ''].join('\t'));
      }
    }

    if (entry != null) {
      writeEntry('Main', entry, concordance);
    } else if (w != null) {
      buf.writeln([
        'Main',
        w.strongs,
        w.text,
        w.translit ?? '',
        '',
        '',
        '',
        '',
      ].join('\t'));
    }

    // Word family — fetch concordance per entry; cached after first lookup.
    for (final famEntry in _wordFamily) {
      final famConc = await ConcordanceService.lookup(famEntry.number);
      writeEntry('Family', famEntry, famConc);
    }

    // Synonyms / compare references.
    for (final synEntry in _compareWords) {
      final synConc = await ConcordanceService.lookup(synEntry.number);
      writeEntry('Synonym', synEntry, synConc);
    }

    await Clipboard.setData(ClipboardData(text: buf.toString().trimRight()));
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(uiStrings['copied']?[locale] ?? 'Copied!'),
      duration: const Duration(seconds: 1),
    ));
  }

  // ── Distribution table ───────────────────────────────────────────

  void _showDistributionTable(BuildContext ctx) {
    final isBrowsingRoot = _rootEntry != null;
    final entry = isBrowsingRoot ? _rootEntry : _selectedEntry;
    if (entry == null) return;
    final locale = widget.locale;
    final scheme = Theme.of(ctx).colorScheme;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      // Wider sheet on desktop/iPad — Material's default ~640dp cap
      // squeezes the table on wide screens.
      constraints: const BoxConstraints(maxWidth: 1400),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined,
                      color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uiStrings['distributionTable']?[locale] ??
                          'Distribution Table',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    onPressed: () => Navigator.of(sheetCtx).maybePop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: WordDistributionTable(
                strongsNumber: entry.number,
                locale: locale,
                currentVersion: widget.currentVersion,
                scrollController: scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConcordance(
      ColorScheme scheme, String locale, ConcordanceResult cr) {
    final usedTemplate =
        uiStrings['concordanceUsed']?[locale] ?? 'Used {count} times';
    final usedLabel = usedTemplate.replaceAll('{count}', cr.total.toString());
    final shown = cr.refs.length;
    final showingFirst = shown < cr.total
        ? (uiStrings['concordanceShowingFirst']?[locale] ??
                'showing first {shown} of {total}')
            .replaceAll('{shown}', shown.toString())
            .replaceAll('{total}', cr.total.toString())
        : null;

    // Group refs by book, preserving canonical order of first appearance.
    final grouped = <String, List<ConcordanceRef>>{};
    for (final r in cr.refs) {
      grouped.putIfAbsent(r.englishBook, () => []).add(r);
    }
    final books = grouped.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                usedLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        if (showingFirst != null) ...[
          const SizedBox(height: 2),
          Text(
            showingFirst,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < books.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    thickness: 0.5,
                    color: scheme.outlineVariant.withValues(alpha: 0.3)),
              _buildBookGroup(
                books[i],
                grouped[books[i]]!,
                cr.byBook[books[i]] ?? grouped[books[i]]!.length,
                scheme,
                locale,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBookGroup(
    String englishBook,
    List<ConcordanceRef> refs,
    int totalCount,
    ColorScheme scheme,
    String locale,
  ) {
    final localBook =
        localeAwareBookName(englishBook, locale, widget.currentVersion);
    final isExpanded = _expandedConcordanceBook == englishBook;
    final countTemplate =
        uiStrings['concordanceBookCount']?[locale] ?? '{count} occurrences';
    final countLabel =
        countTemplate.replaceAll('{count}', totalCount.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book header — tappable to expand/collapse
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() {
              _expandedConcordanceBook = isExpanded ? null : englishBook;
            }),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.arrow_right_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localBook,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          countLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expandable ref list
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < refs.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        thickness: 0.5,
                        color: scheme.outlineVariant.withValues(alpha: 0.4)),
                  _refRow(refs[i], scheme),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _localizedRefLabel(ConcordanceRef r) {
    final localBook = localeAwareBookName(
        r.englishBook, widget.locale, widget.currentVersion);
    return '$localBook ${r.chapter}:${r.verse}';
  }

  String? _lookupVerseText(ConcordanceRef r) {
    final raw = _verseIndex['${r.englishBook}-${r.chapter}-${r.verse}'];
    if (raw == null) return null;
    return raw
        .replaceAll('\n', ' ')
        .replaceAll(notePattern, '')
        .replaceAllMapped(bracePattern, (m) => m.group(1) ?? '')
        .replaceAllMapped(squarePattern, (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }

  Widget _refRow(ConcordanceRef r, ColorScheme scheme) {
    final canNavigate = widget.onNavigateRef != null;
    final label = _localizedRefLabel(r);
    final preview = _lookupVerseText(r);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canNavigate ? () => widget.onNavigateRef!(r) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      canNavigate ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              if (preview != null) ...[
                const SizedBox(height: 3),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHint(ColorScheme scheme, String locale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined,
              color: scheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              uiStrings['originalHint']?[locale] ??
                  'Tap a word to see its Strong\'s entry.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseOriginals {
  final Verse verse;
  final List<OriginalWord>? words;
  _VerseOriginals({required this.verse, required this.words});
}
