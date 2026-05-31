import 'dart:async' show unawaited;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart'
    show sanitizeForSearch, notePattern, bracePattern, squarePattern;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/original_word.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/widgets/collapsible_english_ref.dart';
import 'package:yswords/widgets/left_accent_card.dart';
import 'package:yswords/services/ai_word_service.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/lxx_service.dart';
import 'package:yswords/services/originals_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/utils/ai_markdown.dart' show parseAiMarkdown;
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/theme_color_helpers.dart';
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

  // Strong's #s for which the user has tapped "+N more" to reveal
  // every concordance ref (rather than the default first-8 preview).
  // Cleared whenever the user switches to a new word entry.
  final Set<String> _refsShowAll = {};

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

  // The Strong's # the user pivoted FROM via Full Study. When that
  // chip is auto-expanded in the new entry, we hide the redundant
  // "Full Study →" link inside it (clicking it would just take them
  // back to where they came from — confusing right after navigation).
  String? _pivotFromNumber;

  // 2026-05-10 (v1.2.30): generation counter for in-flight Strong's /
  // concordance / relations lookups. Bumped at the start of every new
  // word tap (`_onWordTap`), root-entry navigation (`_loadRootEntry`),
  // and clear-root (`_clearRoot`). Each async branch captures the gen
  // at entry and bails out (no setState) if the gen has moved on by
  // the time it tries to land. Without this, tapping word A then word
  // B before A's lookup resolves can leave A's entry/concordance/
  // family rendered under B's selection — same "stale resolution"
  // pattern fixed in v1.2.8 (BYOK Test) but not yet here.
  int _lookupGen = 0;

  // ── AI explanation panel ─────────────────────────────────────────
  // Gemini-powered "explain this word in this verse" feature.
  // Tap-to-load (not auto) so we don't burn API calls every time the
  // user pokes at a chip. Keyed by Strong's # so we don't re-show a
  // stale explanation when the user switches words.
  //
  // The panel keeps a *list* of explanation chunks so follow-up
  // requests (different length / scope) APPEND rather than replace —
  // the user builds up a longer study by tapping multiple directions.
  // Each chunk has a label (e.g. "In this chapter") shown as a small
  // header, and the full transcript can be copied to clipboard.
  final List<_AiChunk> _aiChunks = [];
  String? _aiError;
  bool _aiLoading = false;
  String? _aiForStrongs;

  /// 2026-05-08 (v1.1.10): heuristic — does this AI-failure message
  /// indicate a quota / not-configured failure that BYOK can solve?
  /// Mirrors the helpers in search_page.dart and evidence_page.dart.
  bool _shouldOfferByokForError(String? msg) {
    if (msg == null) return false;
    final lower = msg.toLowerCase();
    const triggers = [
      'quota', 'exhausted', 'rate-limit', 'rate limit',
      'not configured', 'gemini_api_key',
      '配额', '用完', '没有配置',
    ];
    for (final t in triggers) {
      if (lower.contains(t)) return true;
    }
    return false;
  }

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
    final myGen = ++_lookupGen;
    _clearTapRecognizers();
    _pivotFromNumber = null;
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
      _refsShowAll.clear();
      _lxxEquivalents = const [];
      _hebrewSources = const [];
      // Clear any AI explanation from a previous word — keep the panel
      // tightly scoped to the currently-selected lemma.
      _aiChunks.clear();
      _aiError = null;
      _aiLoading = false;
      _aiForStrongs = null;
    });
    // Fire both lookups in parallel — Strong's entry is per-language,
    // concordance is a single shared file that gets warmed by the
    // first lookup of the session.
    final entryFuture = StrongsService.lookup(w.strongs);
    final concordanceFuture = ConcordanceService.lookup(w.strongs);
    final entry = await entryFuture;
    final concordance = await concordanceFuture;
    // v1.2.30: bail if the user has tapped a different word while we
    // were resolving — preserves selection coherence.
    if (!mounted || myGen != _lookupGen) return;
    _clearTapRecognizers();
    setState(() {
      _selectedEntry = entry;
      _selectedConcordance = concordance;
      _loadingEntry = false;
      // All book groups are collapsed by default — user opts in to
      // auto-expand-first via the AppSettings.autoExpandFirstRef flag.
      _expandedConcordanceBook =
          (context.read<AppSettings>().autoExpandFirstRef &&
                  concordance?.refs.isNotEmpty == true)
              ? concordance!.refs.first.englishBook
              : null;
    });
    // Word family + synonyms load in the background — doesn't block the entry card.
    unawaited(_loadRelations(w.strongs, gen: myGen));
  }

  Future<void> _loadRootEntry(String strongsNumber,
      {String? pivotFromNumber}) async {
    final myGen = ++_lookupGen;
    _pivotFromNumber = pivotFromNumber;
    _clearTapRecognizers();
    setState(() {
      _loadingEntry = true;
      _expandedConcordanceBook = null;
      _wordFamily = const [];
      _compareWords = const [];
      _relatedConcordances = const {};
      _expandedRelatedNumber = null;
      _refsShowAll.clear();
      _lxxEquivalents = const [];
      _hebrewSources = const [];
      // Round 56 fix: navigating to a different lemma (via 完整研经
      // or a family/synonym chip) means any AI explanation that was
      // generated for the PREVIOUS lemma is now irrelevant. Clear it
      // so the AI panel starts empty on the new entry — user re-clicks
      // to regenerate. Mirrors the clearing already done in _onWordTap.
      _aiChunks.clear();
      _aiError = null;
      _aiLoading = false;
      _aiForStrongs = null;
    });
    final entryFuture = StrongsService.lookup(strongsNumber);
    final concordanceFuture = ConcordanceService.lookup(strongsNumber);
    final entry = await entryFuture;
    final concordance = await concordanceFuture;
    // v1.2.30: bail if the user navigated to a different entry while
    // we were resolving.
    if (!mounted || myGen != _lookupGen) return;
    _clearTapRecognizers();
    setState(() {
      _rootEntry = entry;
      _rootConcordance = concordance;
      _loadingEntry = false;
      _expandedConcordanceBook = null;
    });
    // pivotFromNumber: when the user reached this entry via a chip in
    // a cross-language section (LXX or Hebrew Sources), auto-expand the
    // chip pointing back to where they came from so the OT context is
    // visible immediately — saves an extra tap.
    unawaited(_loadRelations(strongsNumber,
        pivotFromNumber: pivotFromNumber, gen: myGen));
  }

  void _clearRoot() {
    _clearTapRecognizers();
    _pivotFromNumber = null;
    setState(() {
      _rootEntry = null;
      _rootConcordance = null;
      _wordFamily = const [];
      _compareWords = const [];
      _relatedConcordances = const {};
      _expandedRelatedNumber = null;
      _refsShowAll.clear();
      _lxxEquivalents = const [];
      _hebrewSources = const [];
      // Restore the word-entry's auto-opened first book.
      _expandedConcordanceBook = null;
      // Round 56 fix: same clearing rationale as _loadRootEntry —
      // we're showing a different entry (the original word's vs the
      // root's), so any AI explanation generated for the root entry
      // is no longer the right paragraph to show.
      _aiChunks.clear();
      _aiError = null;
      _aiLoading = false;
      _aiForStrongs = null;
    });
    if (_selectedWord != null) {
      // v1.2.30: bump gen so the new relations chain participates in
      // the staleness check (otherwise a fast tap of clear → tap a
      // different word could see clearRoot's relations land afterwards).
      final myGen = ++_lookupGen;
      unawaited(_loadRelations(_selectedWord!.strongs, gen: myGen));
    }
  }

  /// Asks the AI service to explain the currently-selected original
  /// word as it functions in [scope] (defaulting to the verse). Each
  /// call APPENDS a new labeled chunk to [_aiChunks] so the user can
  /// stack multiple angles (verse → chapter → book → cross-refs) in
  /// one session. Tap-to-load — never auto-fired.
  ///
  /// [length] is one of `default` / `concise` / `longer`.
  /// [scope]  is one of `verse` / `chapter` / `book` / `wholeBible` /
  /// `otherChapters`.
  Future<void> _loadAiExplanation({
    String length = 'default',
    String scope = 'verse',
  }) async {
    // Round 56 fix: the previous version always asked Gemini to
    // explain the *original* tapped word in the verse, even when the
    // user had since navigated to a related root entry via 完整研经
    // or a word-family chip. The on-screen entry no longer matched
    // what AI was being asked to explain. Now the AI tracks whichever
    // lemma is currently displayed: _rootEntry takes precedence, with
    // _selectedEntry as the fallback for the original word view.
    final entry = _rootEntry ?? _selectedEntry;
    if (entry == null) return;
    final v = widget.verses.isNotEmpty ? widget.verses.first : null;
    if (v == null) return;
    final englishBook = toEnglish(v.book) ?? v.book;
    final entryNumber = entry.number;
    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiForStrongs = entryNumber;
    });
    // BYOK (2026-05): if the user has pasted their own Gemini API
    // key in Settings → AI, route the request through that key so
    // their AI Studio quota is consumed instead of the developer's
    // shared one. Passed as a body field; the Netlify function
    // prefers it over the env-var key when present.
    final settings = context.read<AppSettings>();
    final userKey = settings.geminiApiKey;
    final result = await AiWordService.explain(
      strongs: entryNumber,
      lemma: entry.lemma,
      translit: entry.translit,
      gloss: entry.gloss,
      englishBook: englishBook,
      chapter: v.chapter,
      verse: v.verse,
      verseText: sanitizeForSearch(v.text),
      locale: widget.locale,
      length: length,
      scope: scope,
      userApiKey: userKey.isEmpty ? null : userKey,
      // v1.2.26 — Gemini tier from Settings.
      aiModel: settings.aiModel,
    );
    // Race-check: if the user navigated to another entry while we
    // were waiting for Gemini, drop the response on the floor — the
    // displayed entry no longer matches what we asked about.
    final stillCurrent =
        (_rootEntry ?? _selectedEntry)?.number == entryNumber;
    if (!mounted || !stillCurrent) return;
    setState(() {
      _aiLoading = false;
      if (result.unavailable) {
        _aiError = result.unavailableReason;
      } else {
        // 2026-05-11 (v1.2.42): v1.2.37's fellBackToFlash notice
        // path was removed — v1.2.40's switch to
        // gemini-3-flash-preview made Deep work on free tier.
        _aiChunks.add(_AiChunk(
          label: _chunkLabel(length: length, scope: scope, locale: widget.locale),
          text: result.explanation,
        ));
      }
    });
  }

  /// Build the small header shown above each appended explanation —
  /// e.g. "本节经文" / "In this chapter (more detail)". Uses the
  /// existing uiStrings entries so all three locales get the right
  /// label without duplicate logic in the widget tree.
  String _chunkLabel({
    required String length,
    required String scope,
    required String locale,
  }) {
    final scopeKey = switch (scope) {
      'chapter' => 'aiScopeChapter',
      'book' => 'aiScopeBook',
      'wholeBible' => 'aiScopeWholeBible',
      'otherChapters' => 'aiScopeOtherChapters',
      'crossTestament' => 'aiScopeCrossTestament',
      'deepExegesis' => 'aiScopeDeepExegesis',
      _ => 'aiScopeVerse',
    };
    final scopeLabel = uiStrings[scopeKey]?[locale] ?? scope;
    if (length == 'concise') {
      final s = uiStrings['aiLengthConcise']?[locale] ?? 'shorter';
      return '$scopeLabel · $s';
    }
    if (length == 'longer') {
      final s = uiStrings['aiLengthLonger']?[locale] ?? 'more detail';
      return '$scopeLabel · $s';
    }
    return scopeLabel;
  }

  /// Concatenate every appended chunk for clipboard copy. Plain text
  /// — labeled headers separated by blank lines so it pastes well
  /// into Notes / Word / chat.
  String _aiTranscript() {
    final w = _selectedWord;
    final v = widget.verses.isNotEmpty ? widget.verses.first : null;
    if (w == null || v == null || _aiChunks.isEmpty) return '';
    final ref = '${v.book} ${v.chapter}:${v.verseLabel} · ${w.text} (${w.strongs})';
    final buf = StringBuffer()
      ..writeln(ref)
      ..writeln();
    for (final c in _aiChunks) {
      buf.writeln('— ${c.label} —');
      buf.writeln(c.text);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  Future<void> _loadRelations(String number,
      {String? pivotFromNumber, int? gen}) async {
    // v1.2.30: callers (`_onWordTap`, `_loadRootEntry`, `_clearRoot`)
    // pass their generation; if not provided, snapshot the current one
    // (defensive default, though all known callers now pass it).
    final myGen = gen ?? _lookupGen;
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
    if (!mounted || myGen != _lookupGen) return;
    // Prefetch concordances for every related entry in parallel.
    final all = <StrongsEntry>[...family, ...compare, ...lxx, ...hebSrc];
    final entries = <String, ConcordanceResult?>{};
    await Future.wait(all.map((e) async {
      entries[e.number] = await ConcordanceService.lookup(e.number);
    }));
    if (!mounted || myGen != _lookupGen) return;
    // If the user reached this entry by tapping a chip in a related
    // section (Word Family / Synonyms / LXX / Hebrew Sources) on the
    // previous entry, find that "previous" Strong's # in the new
    // entry's related sets and auto-expand it. For an LXX→Greek pivot
    // this surfaces the OT verses (via Hebrew Sources) immediately;
    // for a Hebrew Sources→Hebrew pivot it surfaces the LXX equivalent.
    String? autoExpand;
    if (pivotFromNumber != null) {
      final pivots = {
        for (final e in all) e.number,
      };
      if (pivots.contains(pivotFromNumber)) autoExpand = pivotFromNumber;
    }
    setState(() {
      _wordFamily = family;
      _compareWords = compare;
      _lxxEquivalents = lxx;
      _hebrewSources = hebSrc;
      _relatedConcordances = entries;
      if (autoExpand != null) _expandedRelatedNumber = autoExpand;
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
        // Local Scaffold so snackbars from ScaffoldMessenger.of(ctx)
        // (e.g. the "Copied!" feedback after tapping a copy icon)
        // render INSIDE this modal sheet — without it the snackbar
        // anchors to the root scaffold below the modal and the user
        // never sees the feedback.
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
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
        ),
        );
      },
    );
  }

  Widget _buildVerseBlock(_VerseOriginals vo, ColorScheme scheme) {
    final ref = '${vo.verse.book} ${vo.verse.chapter}:${vo.verse.verse}';
    final isHebrew = (vo.words ?? const []).isNotEmpty &&
        vo.words!.first.strongs.startsWith('H');
    // Round 56 (continued — Aramaic highlight): English book name for
    // [isAramaicWord] lookup. `vo.verse.book` may already be localised
    // depending on the source path, so canonicalise it.
    final englishBook = toEnglish(vo.verse.book) ?? vo.verse.book;
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
            LeftAccentCard(
              // v1.3.x: was Container(BoxDecoration(border:
              // Border(left:...), borderRadius:...)) — non-uniform
              // border + radius throws in Border.paint.
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              background: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              accentColor: scheme.primary,
              accentWidth: 3,
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
                  for (final w in words)
                    _wordChip(
                      w,
                      scheme,
                      englishBook: englishBook,
                      chapter: vo.verse.chapter,
                      verse: vo.verse.verse,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _wordChip(
    OriginalWord w,
    ColorScheme scheme, {
    required String englishBook,
    required int chapter,
    required int verse,
  }) {
    final isSelected = _selectedWord?.strongs == w.strongs &&
        _selectedWord?.text == w.text;
    // Round 56 (continued — Aramaic highlight): tag chips whose word
    // is Aramaic so the reader can see at a glance which embedded
    // tokens are Aramaic vs. surrounding Hebrew/Greek. Teal matches
    // the Aramaic accent on the Bible Languages card.
    final isAramaic = isAramaicWord(
      englishBook: englishBook,
      chapter: chapter,
      verse: verse,
      strongs: w.strongs,
    );
    // Interlinear gloss row — the Strong's entry's primary meaning in
    // the user's locale (English `gloss` or Chinese `glossZh`). Shown
    // beneath the original word so a reader who doesn't know
    // Hebrew/Greek can immediately see what each word means.
    final entry = _glossCache[w.strongs];
    final gloss =
        entry?.localizedGloss(widget.locale) ?? '';
    // Aramaic chips: teal-tinted background + 1.5px teal border, even
    // when not selected. Selected Aramaic chips switch to the primary
    // colour scheme so the selection cue stays unambiguous.
    final Color bgColor;
    final Color borderColor;
    if (isSelected) {
      bgColor = scheme.primaryContainer;
      borderColor = scheme.primary;
    } else if (isAramaic) {
      // Theme-aware teal so the chip stays readable + vivid in dark
      // mode. paletteBg = teal.shade100 (light) / teal.shade900 with
      // alpha (dark); paletteBorder uses a brighter teal in dark
      // mode so the border is still visible.
      bgColor = paletteBg(context, Colors.teal);
      borderColor = paletteBorder(context, Colors.teal);
    } else {
      bgColor = scheme.surfaceContainerHighest.withValues(alpha: 0.5);
      borderColor = Colors.transparent;
    }
    return InkWell(
      onTap: () => _onWordTap(w),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        constraints: const BoxConstraints(minWidth: 56, maxWidth: 140),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Round 56 (continued — Aramaic highlight): tiny teal pill
            // above the lemma reading "亚兰文 / 亞蘭文 / Aramaic" so the
            // distinction is visible without relying on colour alone.
            if (isAramaic) ...[
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: paletteBg(context, Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    uiStrings['aramaicWordBadge']?[widget.locale] ??
                        'Aramaic',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: paletteFg(context, Colors.teal),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ],
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
            // Strong's # badge — small, monospace, dimmed so it doesn't
            // compete with the lemma but is identifiable at a glance.
            // Force LTR Directionality so the number reads left-to-right
            // even when the surrounding chip Wrap is RTL for Hebrew.
            // Hidden when the user has disabled the badge in settings.
            if (context.read<AppSettings>().showStrongsInOriginals) ...[
              const SizedBox(height: 2),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    w.strongs,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: scheme.secondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
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

  /// Tiny helper for the proper-noun gloss block — renders one row
  /// with a small italic label on the left and the gloss text on the
  /// right. Used for both "Etymology / 词源" and "Identification / 此处指"
  /// rows so they have a consistent shape.
  Widget _properNounRow({
    required ColorScheme scheme,
    required String label,
    required String value,
    required bool bold,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13.5,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color:
                  bold ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ),
      ],
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
    // Round 56 (continued — Aramaic highlight, entry card): tag the
    // header row when this Strong's entry is Aramaic. Detection
    // mirrors the chip-side rule: NT entries → curated Greek
    // transliteration set; OT entries → first verse falls inside a
    // known Aramaic section AND the entry is H-numbered. Browsing a
    // root pivoted away from the original verse keeps the badge as
    // long as the displayed number itself is in the Aramaic set
    // (true for the NT transliteration roots; false for plain OT
    // roots, which is the right behaviour — those roots aren't
    // exclusively Aramaic).
    bool entryIsAramaic = _aramaicGreekStrongs.contains(displayNumber);
    if (!entryIsAramaic && !isBrowsingRoot && widget.verses.isNotEmpty) {
      final v = widget.verses.first;
      final eb = toEnglish(v.book) ?? v.book;
      entryIsAramaic = isAramaicWord(
        englishBook: eb,
        chapter: v.chapter,
        verse: v.verse,
        strongs: displayNumber,
      );
    }

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
              if (entryIsAramaic) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: paletteBg(context, Colors.teal),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: paletteBorder(context, Colors.teal),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    uiStrings['aramaicWordBadge']?[locale] ?? 'Aramaic',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: paletteFg(context, Colors.teal),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
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
                // 2026-05-10 (v1.2.31): keep glyph at 18 dp but bump
                // tap target to 48×48 for Material/WCAG a11y. Was
                // `padding: zero, constraints: BoxConstraints()` =
                // ~18 dp tap target (well below 48 dp minimum).
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: uiStrings['distributionTable']?[locale] ??
                    'Distribution Table',
                onPressed: () => _showDistributionTable(context),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                iconSize: 18,
                // v1.2.31: see above — 48 dp minimum tap target.
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
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
            //
            // 2026-05-07: for proper nouns (people, places, deities),
            // the two lexicon sources emphasise different aspects —
            // English Strong's gives the **etymology** (e.g. "Sceva"
            // → Latin "left-handed"), CBOL Chinese gives the **biblical
            // identification** (e.g. "一个祭司长，住在以弗所"). Showing
            // only one made users think the data contradicted itself.
            // Now we render BOTH with role labels so it reads as
            // "etymology + identification" — complementary, not
            // contradictory. Plus a small 👤 badge above so the user
            // knows this is a proper-noun entry.
            if (entry.isProperNoun &&
                entry.complementaryGloss(locale).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      uiStrings['exegesisProperNounBadge']?[locale] ??
                          'Proper noun',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: scheme.onTertiaryContainer,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uiStrings['exegesisProperNounNote']?[locale] ??
                          'Etymology + identification (both correct).',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Primary gloss (locale-preferred). For ZH this is the
              // CBOL identification; for EN this is the Strong's
              // etymology. Render with a subtle label.
              _properNounRow(
                scheme: scheme,
                label: locale.startsWith('zh')
                    ? (uiStrings['exegesisProperNounRoleLabel']?[locale] ??
                        '此处指')
                    : (uiStrings['exegesisProperNounEtymLabel']?['en'] ??
                        'Etymology'),
                value: entry.localizedGloss(locale),
                bold: true,
              ),
              const SizedBox(height: 4),
              // Complementary gloss (the "other" perspective).
              _properNounRow(
                scheme: scheme,
                label: locale.startsWith('zh')
                    ? (uiStrings['exegesisProperNounEtymLabel']?[locale] ??
                        '词源')
                    : (uiStrings['exegesisProperNounRoleLabel']?['en'] ??
                        'Identification'),
                value: entry.complementaryGloss(locale),
                bold: false,
              ),
            ] else if (entry.localizedGloss(locale).isNotEmpty) ...[
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
            // 2026-05-07 follow-up: for proper nouns also render the
            // OTHER language's definition body below, with clear
            // labels — same complementary-perspective philosophy as
            // the gloss block above. Without this the long definition
            // text still looked locale-locked (English etymology
            // paragraph for EN readers, Chinese identification
            // paragraph for ZH readers), making the user feel the
            // data was inconsistent. Now both are shown so the user
            // sees etymology + identification side by side at every
            // level of detail.
            if (entry.isProperNoun &&
                entry.complementaryDefinition(locale).isNotEmpty) ...[
              const SizedBox(height: 10),
              if (entry.localizedDefinition(locale).isNotEmpty)
                Text(
                  entry.localizedDefinition(locale),
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurface,
                    height: 1.45,
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.25),
                    width: 0.6,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.startsWith('zh')
                          ? (uiStrings['exegesisProperNounComplDefEn']
                                  ?[locale] ??
                              '英文 Strong\'s 完整释义')
                          : (uiStrings['exegesisProperNounComplDefZh']
                                  ?[locale] ??
                              'Chinese CBOL definition'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onTertiaryContainer,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.complementaryDefinition(locale),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.85),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (entry.cleanChineseDefinition(locale).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                // v1.3.x: English-only CBOL noise (id header, "AV -"
                // KJV counts) stripped for Chinese; the English moves
                // into the collapsible "英文参考" section below.
                entry.cleanChineseDefinition(locale),
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
                  // Traditional users see the converted attribution
                  // string too — no script-mixing inside the panel.
                  locale == 'zh-Hant'
                      ? '中文釋義來源:CBOL · bible.fhl.net (CC-BY-NC-SA 4.0)'
                      : '中文释义来源:CBOL · bible.fhl.net (CC-BY-NC-SA 4.0)',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            // ── AI explanation (Gemini, opt-in) ───────────────────
            // Renders a button below the lexicon definition; tap to
            // request an 80-180 word explanation of the lemma in the
            // selected verse's specific context. Doesn't auto-fire
            // on word tap so we don't burn API quota on idle browsing.
            const SizedBox(height: 12),
            _buildAiExplainSection(scheme, locale),
            // Derivation / etymology line with tappable Strong's refs.
            // v1.3.x: this is English-only. In a Chinese panel, tuck it
            // behind a collapsed "英文参考" disclosure so the panel reads
            // as Chinese first; show inline for English readers.
            if ((entry.derivation ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              if (locale.startsWith('zh'))
                CollapsibleEnglishRef(
                  title: uiStrings['englishReference']?[locale] ??
                      'English reference',
                  child: _buildDerivationRich(entry.derivation!, scheme),
                )
              else
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
                // Override: when expanding an LXX Greek chip, show the
                // OT verses where the source Hebrew word appears (the
                // verses the LXX renders using this Greek lemma). The
                // verse text is auto-displayed in the user's current
                // Bible version (English / Chinese) via _verseIndex.
                overrideConcordance: concordance,
                overrideHeaderLemma: entry.lemma,
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

  /// AI explanation block. Four logical states:
  ///   - idle: shows the "Explain in this verse with AI" button
  ///   - loading: spinner + "Asking Gemini…" hint
  ///   - error: shows the unavailable message + a Try again button
  ///   - has chunks: renders the appended transcript inside a bounded
  ///     scroll container, with direction chips below to extend the
  ///     answer (length: more concise / more detail; scope: this
  ///     chapter / this book / whole Bible / other chapters) and a
  ///     Copy button to grab the full transcript.
  ///
  /// Always shows a small AI-generated disclaimer below the result so
  /// the reader doesn't mistake a Gemini paragraph for hand-curated
  /// scholarship.
  Widget _buildAiExplainSection(ColorScheme scheme, String locale) {
    // Round 56 fix: gate the AI panel against the currently-displayed
    // entry, not the original tapped word. Otherwise after the user
    // hits 完整研经 / Full study to navigate to a related entry, the
    // panel keeps showing the previous lemma's chunks (because
    // _selectedWord doesn't change with the navigation). The chunks
    // are also cleared in _loadRootEntry / _clearRoot, but this gate
    // is a defensive second line — it hides any stragglers from a
    // race or a future code path that updates state without going
    // through those helpers.
    final entry = _rootEntry ?? _selectedEntry;
    final w = _selectedWord;
    final v = widget.verses.isNotEmpty ? widget.verses.first : null;
    if (entry == null || w == null || v == null) {
      return const SizedBox.shrink();
    }
    final ref = '${v.book} ${v.chapter}:${v.verseLabel}';
    final hasChunks =
        _aiForStrongs == entry.number && _aiChunks.isNotEmpty;
    final hasError =
        _aiForStrongs == entry.number && _aiError != null;

    final initialLabel = _aiLoading
        ? (uiStrings['aiExplainAsking']?[locale] ?? 'Asking Gemini…')
        : (uiStrings['aiExplainButton']?[locale] ??
            'Explain in this verse with AI');

    return Container(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${uiStrings['aiExplainHeader']?[locale] ?? 'AI explanation'} · $ref',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!hasChunks && !hasError)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _aiLoading
                    ? null
                    : () => _loadAiExplanation(),
                icon: _aiLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(initialLabel,
                    style: const TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                ),
              ),
            ),
          if (hasError) ...[
            Text(
              _aiError ?? '',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.error,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            // 2026-05-08 (v1.1.10): Try-again is the primary action;
            // when the failure is quota-related AND the user hasn't
            // already pasted their own Gemini key, also show a
            // deep-link to Settings → YsWords AI so they can keep
            // working without waiting for the shared quota to reset.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _aiLoading
                      ? null
                      : () => _loadAiExplanation(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    uiStrings['aiExplainTryAgain']?[locale] ?? 'Try again',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  ),
                ),
                if (_shouldOfferByokForError(_aiError) &&
                    !context.read<AppSettings>().hasUserGeminiKey)
                  TextButton.icon(
                    onPressed: () {
                      Get.to(
                        () => const SettingsPage(
                            initialSection: SettingsSection.ai),
                        transition: Transition.rightToLeft,
                      );
                    },
                    icon: const Icon(Icons.key_rounded, size: 16),
                    label: Text(
                      uiStrings['aiOpenByokSettings']?[locale] ??
                          'Set up your own Gemini API key',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
          ],
          if (hasChunks) ...[
            // Bounded transcript — long answers scroll inside the
            // panel. Each direction tap APPENDS a new labeled chunk
            // so the user builds up a multi-angle study (verse →
            // chapter → cross-refs) without losing earlier sections.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _aiChunks.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.6),
                              height: 1,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _aiChunks[i].label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        // Round 56 (continued — markdown rendering):
                        // Gemini ignores "no markdown" instructions
                        // and ships **bold** / ***heading*** markers
                        // even when told not to. Parse them into
                        // proper TextSpans (bold/italic) instead of
                        // showing literal asterisks. Stripped:
                        // ##/### heading hashes, --- rules, leading
                        // bullets. User feedback: "the exegesis when
                        // asking gemini questions, it has *** which
                        // indicate the format issue".
                        SelectableText.rich(
                          TextSpan(
                            children: parseAiMarkdown(
                              _aiChunks[i].text,
                              base: TextStyle(
                                fontSize: 14,
                                color: scheme.onSurface,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_aiLoading) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              uiStrings['aiExplainAsking']?[locale] ??
                                  'Asking Gemini…',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    scheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Direction chips — each tap appends a new chunk in the
            // requested direction. The first row tunes the LENGTH of
            // the next response; the second row tunes the SCOPE.
            // Disabled while a request is in-flight so we don't
            // queue duplicates.
            _buildAiDirectionChips(scheme, locale),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    uiStrings['aiExplainDisclaimer']?[locale] ??
                        'AI-generated. Verify with primary sources for '
                        'study or teaching use.',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _aiLoading ? null : _copyAiTranscript,
                  icon: const Icon(Icons.copy_all_outlined, size: 14),
                  label: Text(
                    uiStrings['aiExplainCopy']?[locale] ?? 'Copy',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Two rows of chips below the transcript. Length first (small,
  /// orthogonal tweak) then Scope (the meatier "where is this word
  /// used?" question). Tapping any chip appends a new explanation
  /// chunk via [_loadAiExplanation].
  Widget _buildAiDirectionChips(ColorScheme scheme, String locale) {
    final disabled = _aiLoading;
    Widget chip(String label, VoidCallback onTap, {bool primary = false}) {
      return ActionChip(
        avatar: primary
            ? Icon(Icons.auto_awesome, size: 14, color: scheme.primary)
            : null,
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: disabled ? null : onTap,
        visualDensity: VisualDensity.compact,
        backgroundColor: primary
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        side: BorderSide(
          color: primary
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outlineVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Length row
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: Text(
                uiStrings['aiLengthLabel']?[locale] ?? 'Length',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            chip(
              uiStrings['aiLengthConcise']?[locale] ?? 'More concise',
              () => _loadAiExplanation(length: 'concise'),
            ),
            chip(
              uiStrings['aiLengthLonger']?[locale] ?? 'More detail',
              () => _loadAiExplanation(length: 'longer'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Scope row
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: Text(
                uiStrings['aiScopeLabel']?[locale] ?? 'Scope',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            chip(
              uiStrings['aiScopeChapter']?[locale] ?? 'In this chapter',
              () => _loadAiExplanation(scope: 'chapter'),
              primary: true,
            ),
            chip(
              uiStrings['aiScopeBook']?[locale] ?? 'In this book',
              () => _loadAiExplanation(scope: 'book'),
              primary: true,
            ),
            chip(
              uiStrings['aiScopeOtherChapters']?[locale] ?? 'Other chapters',
              () => _loadAiExplanation(scope: 'otherChapters'),
              primary: true,
            ),
            chip(
              uiStrings['aiScopeWholeBible']?[locale] ?? 'Whole Bible',
              () => _loadAiExplanation(scope: 'wholeBible'),
              primary: true,
            ),
            // Cross-testament chip is direction-aware: for a Greek
            // (NT) word it offers "OT background → here"; for a Hebrew
            // (OT) word it offers "this → NT echoes". The function
            // figures out the direction from the Strong's prefix.
            chip(
              _crossTestamentLabel(locale),
              () => _loadAiExplanation(scope: 'crossTestament'),
              primary: true,
            ),
            // 2026-05-07: BDAG-level deep exegesis. Pairs the new
            // 'deep' length (~500-750 words) with a 'deepExegesis'
            // scope that asks for a structured 5-section analysis:
            // lexical core, usage in this verse, cultural / historical
            // context, canonical pattern, theological weight.
            // Acts as a free-tier substitute for what Logos / Accordance
            // sells via BDAG / HALOT integration.
            chip(
              uiStrings['aiScopeDeepExegesis']?[locale] ?? 'Deep exegesis',
              () => _loadAiExplanation(
                  length: 'deep', scope: 'deepExegesis'),
              primary: true,
            ),
          ],
        ),
      ],
    );
  }

  /// Pick the user-facing label for the cross-testament chip based
  /// on whether the selected Strong's # is Greek (NT, "G…") or
  /// Hebrew (OT, "H…"). Falls back to a neutral label when no word
  /// is selected.
  String _crossTestamentLabel(String locale) {
    final n = _selectedWord?.strongs;
    if (n != null && n.startsWith('G')) {
      return uiStrings['aiScopeCrossTestamentNtToOt']?[locale] ??
          'OT background';
    }
    if (n != null && n.startsWith('H')) {
      return uiStrings['aiScopeCrossTestamentOtToNt']?[locale] ??
          'NT echoes';
    }
    return uiStrings['aiScopeCrossTestament']?[locale] ??
        'Across testaments';
  }

  /// Copy the entire AI transcript to clipboard with a toast.
  Future<void> _copyAiTranscript() async {
    final text = _aiTranscript();
    if (text.isEmpty) return;
    if (!mounted) return;
    await ClipboardHelper.copyWithFeedback(context, text);
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
      String label, List<StrongsEntry> entries, ColorScheme scheme, String locale,
      {ConcordanceResult? overrideConcordance, String? overrideHeaderLemma}) {
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
          _buildExpandedRelatedVerses(expanded, scheme, locale,
              overrideConcordance: overrideConcordance,
              overrideHeaderLemma: overrideHeaderLemma),
        ],
      ],
    );
  }

  Widget _buildExpandedRelatedVerses(
      StrongsEntry e, ColorScheme scheme, String locale,
      {ConcordanceResult? overrideConcordance, String? overrideHeaderLemma}) {
    // For the LXX section we override the concordance so the user sees
    // the Old Testament verses where the source Hebrew word appears
    // (translated as this Greek word in the LXX) — that's the OT
    // context behind the Greek lemma. Verse text is displayed in the
    // current Bible version's locale via _lookupVerseText.
    final cr = overrideConcordance ?? _relatedConcordances[e.number];
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
    final showAll = _refsShowAll.contains(e.number);
    final shown = showAll ? cr.refs : cr.refs.take(8).toList();
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
                  overrideHeaderLemma != null
                      ? '${e.lemma} ← $overrideHeaderLemma · $usedLabel'
                      : '${e.lemma} · $usedLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Hide the "Full Study →" link when this chip is the
              // back-pivot — clicking it would just take the user
              // where they just came from. Otherwise, tapping it
              // navigates into this entry's full word study, with the
              // current entry recorded as the next back-pivot.
              if (e.number != _pivotFromNumber)
                InkWell(
                  onTap: () {
                    final currentNumber = (_rootEntry ?? _selectedEntry)?.number;
                    _loadRootEntry(e.number, pivotFromNumber: currentNumber);
                  },
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
            // Tappable: reveal every remaining ref instead of the
            // first-8 preview. Idempotent — stays expanded until the
            // user switches to a new word.
            InkWell(
              onTap: () => setState(() => _refsShowAll.add(e.number)),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+ $remaining ${uiStrings['moreRefs']?[locale] ?? 'more'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    Icon(Icons.expand_more,
                        size: 14, color: scheme.primary),
                  ],
                ),
              ),
            ),
          ] else if (showAll && cr.refs.length > 8) ...[
            // Once expanded, show a "collapse" affordance so the
            // section can fold back to the compact preview.
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _refsShowAll.remove(e.number)),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      uiStrings['collapse']?[locale] ?? 'Collapse',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    Icon(Icons.expand_less,
                        size: 14, color: scheme.primary),
                  ],
                ),
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
    await ClipboardHelper.copyWithFeedback(ctx, buf.toString().trimRight());
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

    // LXX Greek equivalents (Hebrew → Greek). Their concordance is
    // already cached in _relatedConcordances from _loadRelations.
    for (final lxxEntry in _lxxEquivalents) {
      final lxxConc = _relatedConcordances[lxxEntry.number] ??
          await ConcordanceService.lookup(lxxEntry.number);
      writeEntry('LXX', lxxEntry, lxxConc);
    }

    // Hebrew sources (Greek → Hebrew). Mirror of LXX for NT entries.
    for (final hebEntry in _hebrewSources) {
      final hebConc = _relatedConcordances[hebEntry.number] ??
          await ConcordanceService.lookup(hebEntry.number);
      writeEntry('HebrewSource', hebEntry, hebConc);
    }

    if (!ctx.mounted) return;
    await ClipboardHelper.copyWithFeedback(ctx, buf.toString().trimRight());
  }

  // ── Distribution table ───────────────────────────────────────────

  void _showDistributionTable(BuildContext ctx) {
    final isBrowsingRoot = _rootEntry != null;
    final entry = isBrowsingRoot ? _rootEntry : _selectedEntry;
    // Resolve the Strong's # from any of: root entry → selected entry →
    // raw selected word. We prefer entry when available (typed lemma)
    // but fall back to the original-word's strongs so the table still
    // opens even if the lexicon lookup hasn't completed.
    final number = entry?.number ?? _selectedWord?.strongs;
    if (number == null || number.isEmpty) return;
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
        builder: (_, scrollController) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
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
                strongsNumber: number,
                locale: locale,
                currentVersion: widget.currentVersion,
                scrollController: scrollController,
              ),
            ),
          ],
        ),
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
        .replaceAll(_kOriginalsMultiSpace, ' ')
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

/// One labeled segment in the AI explanation transcript. Multiple
/// chunks accumulate in [_OriginalsSheetState._aiChunks] as the user
/// taps successive direction chips (this verse → this chapter → …).
class _AiChunk {
  final String label;
  final String text;
  const _AiChunk({required this.label, required this.text});
}

// 2026-05-11 (v1.2.38): the inline markdown parser was extracted
// into `lib/utils/ai_markdown.dart::parseAiMarkdown` so other AI
// surfaces (search_page, evidence_page, settings_page tier panel)
// can render `**bold**` / `*italic*` properly instead of showing
// literal asterisks. The remaining hoisted regex below is just
// the multi-space collapse used by `_lookupVerseText` — kept here
// because it's specific to this widget's concordance preview.
final RegExp _kOriginalsMultiSpace = RegExp(r' {2,}');

/// Round 56 (continued — Aramaic highlight): when the user taps into
/// an Aramaic passage from the Bible Tools page, the OriginalsSheet
/// should visually distinguish the Aramaic words. The Strong's lexicon
/// in `assets/strongs/hebrew.json` doesn't carry a separate Aramaic
/// flag (Aramaic entries are mixed into the H#### range), so we
/// detect by reference instead. Two rules:
///
///   1) **OT verses inside known Aramaic sections** — every H-numbered
///      word in Daniel 2:4–7:28, Ezra 4:8–6:18, Ezra 7:12–26,
///      Genesis 31:47, and Jeremiah 10:11 is Aramaic. (Daniel 2:4a is
///      Hebrew but the whole verse switches mid-line; we still flag
///      every word in 2:4 because the chip view is per-word.)
///   2) **NT Aramaic transliterations** — specific Greek Strong's
///      numbers that are actually transliterated Aramaic on the lips
///      of Jesus / the early church (raca, talitha koum, ephphatha,
///      abba, eloi/lema/sabachthani, maranatha).
///
/// Only H-numbered words inside the OT ranges are flagged; G-numbered
/// words there (rare cross-references) are not. NT detection is
/// strictly by Strong's # — surrounding Greek words remain Greek.
bool isAramaicWord({
  required String englishBook,
  required int chapter,
  required int verse,
  required String strongs,
}) {
  // NT rule: known Aramaic transliterations carry a fixed set of
  // Greek Strong's #s regardless of the verse they appear in.
  if (_aramaicGreekStrongs.contains(strongs)) return true;
  // OT rule: chapter/verse falls inside a curated Aramaic section
  // AND the word is H-numbered (Hebrew/Aramaic side of the lexicon).
  if (!strongs.startsWith('H')) return false;
  switch (englishBook) {
    case 'Genesis':
      return chapter == 31 && verse == 47;
    case 'Jeremiah':
      return chapter == 10 && verse == 11;
    case 'Daniel':
      // 2:4b – 7:28. We accept the whole of 2:4 (per-word view).
      if (chapter < 2 || chapter > 7) return false;
      if (chapter == 2) return verse >= 4;
      if (chapter == 7) return verse <= 28;
      return true;
    case 'Ezra':
      if (chapter == 4) return verse >= 8;
      if (chapter == 5) return true;
      if (chapter == 6) return verse <= 18;
      if (chapter == 7) return verse >= 12 && verse <= 26;
      return false;
    default:
      return false;
  }
}

/// Greek Strong's numbers whose underlying word is Aramaic
/// transliterated into Greek script. These appear in the NT
/// embedded inside otherwise-Greek verses.
const Set<String> _aramaicGreekStrongs = {
  'G4469', // ῥακά (raca)
  'G5008', // ταλιθα (talitha)
  'G2891', // κουμι / κουμ (koumi/koum)
  'G2188', // εφφαθα (ephphatha)
  'G5',    // ἀββα (abba)
  'G1682', // ἐλωΐ (eloi)
  'G2982', // λεμα (lema)
  'G4518', // σαβαχθανι (sabachthani)
  'G3134', // μαρὰν ἀθά (maranatha)
};
