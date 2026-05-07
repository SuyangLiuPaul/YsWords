import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/ai_bible_search_service.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/pages/strongs_entry_page.dart';
import 'package:yswords/services/recent_searches_service.dart';
import 'package:yswords/utils/format_searched_text.dart';
import 'package:yswords/utils/jump_to_reference.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart'
    show localeAwareBookName, toEnglish, translateBookName;
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:flutter/services.dart';

/// Pattern for Strong's-number queries: optional whitespace, "G" or "H",
/// optional whitespace, digits. Matches user-typed forms like "G2316",
/// "g 2316", "h7200", with case insensitivity.
final _strongsQueryPattern = RegExp(r'^\s*([GHgh])\s*(\d{1,5})\s*$');

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // Controllers and list for managing search functionality
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textEditingController = TextEditingController();
  final List<Verse> _results = [];

  bool searchPerformed = false;
  bool searchAll = true;
  Map<String, int> bookCounts = {};
  String? filterBook;
  /// Recent searches for the active profile. Loaded once on init,
  /// updated whenever the user submits a non-trivial query.
  List<String> _recents = const [];

  // When the user typed a Strong's-number pattern (e.g. "G2316"), these
  // hold the lookup result; in this mode the regular text-search path
  // is bypassed and the UI renders concordance refs instead of verses.
  String? _strongsKey;
  StrongsEntry? _strongsEntry;
  ConcordanceResult? _strongsResult;

  // 2026-05-07: YsWords AI Bible search state. The user can hit
  // "Search with YsWords AI" when keyword search returns no results,
  // or use it for fuzzy / thematic queries (e.g. "the love chapter",
  // "雅各信仰", "Sermon on the Mount"). Gemini returns up to 10
  // references; we resolve them against the user's currently-loaded
  // Bible version and display the verses in the same shape regular
  // keyword results take. Always tagged "for reference only" since
  // LLM-generated references can be wrong.
  bool _aiBusy = false;
  String? _aiNotice; // YsWords-AI status / "no matches" — small inline note.
  bool _lastResultsFromAi = false; // toggles header above _results.

  /// 2026-05-07 (post-fix): when a regular text search returns 0 or
  /// few results AND the query also looks like it might be a Greek/
  /// Hebrew lemma (e.g. "agape", "shalom"), we show a "Did you mean
  /// lexicon entry: …" suggestion above the empty state. Replaces the
  /// previous behavior of silently auto-redirecting to the lexicon
  /// for any short Latin token, which made common English Bible words
  /// like "love", "faith", "father" hijack themselves to the wrong
  /// view.
  StrongsEntry? _lemmaSuggestion;

  /// 2026-05-07 (post-fix): how many verses the last `search()` call
  /// actually scanned. Surfaced in the no-results state so users can
  /// see whether the page found nothing because the Bible isn't
  /// loaded (0 scanned), the active filter excluded everything, or
  /// the query genuinely doesn't appear in any verse.
  int _lastScanCount = 0;

  /// 2026-05-07 (post-fix v4): simplified verse-load state. Earlier
  /// versions tried a Future latch to coordinate post-frame and
  /// search() callers, but the user kept seeing "scanned 0 verses"
  /// — meaning the latch resolved before verses were truly populated
  /// (or `mp.verses` was being read on a different context or race
  /// path). Drop the latch entirely; just load synchronously inside
  /// search() when needed. Adds an `_loadAttempts` counter so the
  /// no-results banner can surface diagnostic info when something
  /// unexpected (zero verses despite a successful load) happens.
  bool _isLoadingVerses = false;
  String? _versesLoadError;
  int _loadAttempts = 0;
  int _lastVersesLength = -1; // -1 = never checked
  String _lastLoadedVersion = '';

  /// On-demand verse load. Used by search(), the recent-search row
  /// tap path, and the AI search path. Returns true iff
  /// `mp.verses.isNotEmpty` after the call.
  Future<bool> _ensureVersesLoaded() async {
    final mp = Provider.of<MainProvider>(context, listen: false);
    if (mp.verses.isNotEmpty) {
      _lastVersesLength = mp.verses.length;
      _lastLoadedVersion = mp.currentVersion;
      return true;
    }
    if (_isLoadingVerses) {
      // Another load is in flight. Poll until it completes (max
      // 10s, 100ms tick) instead of bailing — bailing is what made
      // search look broken in v2.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (_isLoadingVerses && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      _lastVersesLength = mp.verses.length;
      _lastLoadedVersion = mp.currentVersion;
      return mp.verses.isNotEmpty;
    }
    _loadAttempts += 1;
    if (mounted) {
      setState(() {
        _isLoadingVerses = true;
        _versesLoadError = null;
      });
    }
    try {
      await FetchVerses.execute(mainProvider: mp);
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _isLoadingVerses = false;
        _versesLoadError = e.toString();
      });
      return false;
    }
    if (!mounted) return false;
    _lastVersesLength = mp.verses.length;
    _lastLoadedVersion = mp.currentVersion;
    setState(() {
      _isLoadingVerses = false;
    });
    return mp.verses.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadRecents();
    // 2026-05-07 (post-fix): defensive — always start with whole-Bible
    // scope. If the user previously chose "Search current book" from
    // the filter dropdown, the choice persisted on the State instance
    // until X was pressed. That made fresh searches return 0 hits
    // when the previously-selected book didn't contain the new query
    // — silently and unintuitively. Now every fresh entry to the
    // search page resets to "search the entire Bible" + no book
    // filter; the filter dropdown is still available for explicit
    // narrowing within the session.
    searchAll = true;
    filterBook = null;
    // 2026-05-07 (post-fix v2): kick off a verse load if the bootstrap
    // didn't run (or hasn't finished). Search is useless against an
    // empty corpus — the user would otherwise see "no results · 0
    // scanned" forever and assume the search itself is broken.
    // Deferred to post-frame so the build runs before we call
    // Provider.of inside the helper.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mp = Provider.of<MainProvider>(context, listen: false);
      if (mp.verses.isEmpty) {
        // ignore: unawaited_futures
        _ensureVersesLoaded();
      }
    });
  }

  Future<void> _loadRecents() async {
    final list = await RecentSearchesService.list();
    if (!mounted) return;
    setState(() => _recents = list);
  }

  /// 2026-05-07 (post-fix): single source-of-truth reset. Called by
  /// the X clear button, the start of `search()`, and the start of
  /// `_askAi()` so we don't leak old state from one search mode into
  /// the next. Previously each entry-point cleared its own subset and
  /// e.g. the X button left `_lastResultsFromAi`, `_strongsKey` and
  /// `_aiNotice` intact, which made the next search look broken.
  ///
  /// `keepResultsList=true` lets `search()` keep showing the previous
  /// results during the brief async window before new results land —
  /// avoids a "no results" flash between the old list and the new one.
  void _resetSearchState({bool keepResultsList = false}) {
    if (!keepResultsList) {
      _results.clear();
      bookCounts.clear();
    }
    _strongsKey = null;
    _strongsEntry = null;
    _strongsResult = null;
    _lastResultsFromAi = false;
    _aiNotice = null;
    _lemmaSuggestion = null;
    searchPerformed = false;
  }

  /// Run an AI-powered Bible reference lookup for the current query.
  /// Resolves the LLM's references against `MainProvider.verses`
  /// (the user's currently-loaded Bible version) so the displayed
  /// verses use whatever translation they're reading. The `book`
  /// field on AI refs is canonical English, mapped to the user's
  /// version's book name via `toEnglish` reverse-comparison.
  /// 2026-05-07: redesigned empty / pre-search state. Three sub-cases:
  /// 1. Search performed + no results → centered "no results" + AI
  ///    button (unchanged).
  /// 2. No search yet, but user has recent queries → **top-aligned**
  ///    list of recent rows (history icon + query + per-item × +
  ///    "Clear all" footer). The previous design centered the chips
  ///    in the middle of the screen which felt awkward and didn't
  ///    look like a familiar "history" UI.
  /// 3. No search yet, no recents → centered search icon + hint
  ///    (true empty state).
  Widget _buildEmptyState(BuildContext context, AppSettings settings) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;

    // Case 1 — search performed, no results.
    if (searchPerformed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: settings.fontSize * 2.4,
                color: scheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                uiStrings['noResults']?[locale] ?? 'No results found',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.outline,
                    )
                    .copyWith(fontSize: settings.fontSize),
                textAlign: TextAlign.center,
              ),
              // 2026-05-07 (post-fix): show the active search scope so
              // the user can tell at a glance whether the 0-results
              // came from a stuck filter (a previous "Search Current
              // Book" choice) versus a genuinely-missing query. With
              // the initState reset, the default scope is now always
              // "entire Bible" — but if the user explicitly narrowed
              // mid-session, this banner makes that visible.
              const SizedBox(height: 8),
              _ScopeBanner(
                searchAll: searchAll,
                filterBook: filterBook,
                versesScanned: _lastScanCount,
                onWiden: (filterBook != null || !searchAll)
                    ? () async {
                        setState(() {
                          searchAll = true;
                          filterBook = null;
                        });
                        await search();
                      }
                    : null,
                locale: locale,
              ),
              // 2026-05-07 (post-fix v4): when scan-count is zero,
              // surface a diagnostic line + force-reload button. The
              // user reported repeated "scanned 0 verses" results
              // even after the auto-load fix; this gives a manual
              // path to recover (and tells us, via the version
              // string, whether the corpus loaded under an unexpected
              // version key). The banner auto-hides as soon as
              // there's a successful scan.
              if (_lastScanCount == 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bible: $_lastLoadedVersion · '
                        'verses=$_lastVersesLength · '
                        'attempts=$_loadAttempts',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: Text(
                          uiStrings['retry']?[locale] ?? 'Retry',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          // Force a fresh load by clearing verses
                          // first, then re-running search. Avoids
                          // the early-return inside
                          // _ensureVersesLoaded that returns true
                          // immediately when mp.verses.isNotEmpty.
                          final mp = Provider.of<MainProvider>(
                              context,
                              listen: false);
                          mp.setVerses(<Verse>[]);
                          await search();
                        },
                      ),
                    ],
                  ),
                ),
              ],
              // 2026-05-07 (post-fix): "Did you mean lexicon entry…"
              // suggestion. Surfaces when text search returned 0 but
              // the query weakly matched a Greek/Hebrew lemma. Replaces
              // the old behavior of silently auto-redirecting to that
              // lexicon entry, which hijacked common English words.
              if (_lemmaSuggestion != null) ...[
                const SizedBox(height: 16),
                _LemmaSuggestionCard(
                  entry: _lemmaSuggestion!,
                  locale: locale,
                  onTap: () async {
                    final num = _lemmaSuggestion!.number;
                    setState(() {
                      _resetSearchState();
                      _strongsKey = num;
                      _strongsEntry = _lemmaSuggestion;
                    });
                    final conc = await ConcordanceService.lookup(num);
                    if (!mounted) return;
                    setState(() {
                      _strongsResult = conc;
                      searchPerformed = true;
                    });
                  },
                ),
              ],
              if (_textEditingController.text.trim().length >= 2) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _aiBusy ? null : _askAi,
                  icon: _aiBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.4))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    _aiBusy
                        ? (uiStrings['aiSearching']?[locale] ??
                            'YsWords AI searching…')
                        : (uiStrings['askAiForVerses']?[locale] ??
                            'Search with YsWords AI (reference only)'),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  uiStrings['aiReferenceOnly']?[locale] ??
                      'AI results are for reference — verify before use.',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_aiNotice != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _aiNotice!,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    }

    // Case 2 — no search yet, has recent queries → top-aligned list.
    if (_recents.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        physics: const BouncingScrollPhysics(),
        children: [
          // Section header — left-aligned, subtle, mirrors the
          // "Recent" / "History" header pattern from Google Search,
          // browser address bars, etc.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  uiStrings['recentSearches']?[locale] ?? 'Recent',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          // List of recent queries — each row: query text + per-item
          // delete button. Tapping the row re-runs that query.
          for (final q in _recents)
            _RecentSearchRow(
              query: q,
              onTap: () async {
                _textEditingController.text = q;
                _textEditingController.selection =
                    TextSelection.fromPosition(
                  TextPosition(offset: q.length),
                );
                await RecentSearchesService.add(q);
                await _loadRecents();
                await search();
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0.0);
                }
              },
              onDelete: () async {
                await RecentSearchesService.remove(q);
                await _loadRecents();
              },
            ),
          // Footer — "Clear all" link, dim and only there if user
          // really wants to nuke everything.
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await RecentSearchesService.clear();
                await _loadRecents();
              },
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: Text(
                uiStrings['clearAllRecent']?[locale] ??
                    uiStrings['clear']?[locale] ??
                    'Clear all',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    // Case 3 — true empty state (no search, no recents). Adds a
    // brief tip line to surface the most common advanced-search
    // formats (full help is one tap away in the AppBar).
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: settings.fontSize * 2.4,
              color: scheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              uiStrings['searchHint']?[locale] ??
                  'Type a word or phrase to search',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.outline,
                  )
                  .copyWith(fontSize: settings.fontSize),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              uiStrings['searchHintQuickList']?[locale] ??
                  'Tip: try "John 3:16", "G2316", or a Greek/Hebrew word.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.help_outline_rounded, size: 14),
              label: Text(
                uiStrings['searchHelpTooltip']?[locale] ?? 'Search tips',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _showSearchHelp(context, settings),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askAi() async {
    final query = _textEditingController.text.trim();
    if (query.length < 2) return;
    final settings = Provider.of<AppSettings>(context, listen: false);
    final mp = Provider.of<MainProvider>(context, listen: false);
    setState(() {
      _aiBusy = true;
      _aiNotice = null;
    });
    final result = await AiBibleSearchService.ask(
      query: query,
      locale: settings.locale,
      userApiKey: settings.geminiApiKey.isEmpty ? null : settings.geminiApiKey,
    );
    if (!mounted) return;
    if (result.unavailable) {
      setState(() {
        _aiBusy = false;
        _aiNotice = result.unavailableReason;
      });
      return;
    }
    if (result.refs.isEmpty) {
      setState(() {
        _aiBusy = false;
        _aiNotice = uiStrings['aiBibleSearchNoMatches']?[settings.locale] ??
            'YsWords AI didn\'t find any matching passages for that '
                'query (reference only).';
      });
      return;
    }
    // Resolve refs to actual Verse objects from the user's loaded
    // Bible version. The AI returns canonical English book names —
    // we walk the user's verses and reverse-map book name to English
    // via toEnglish() to find matches that work for any localized
    // version (CUV, CNV, NASB, etc.).
    final resolved = <Verse>[];
    final missing = <AiBibleRef>[];
    final byBookChapter = <String, List<Verse>>{};
    for (final v in mp.verses) {
      final eb = toEnglish(v.book) ?? v.book;
      final key = '$eb|${v.chapter}';
      (byBookChapter[key] ??= []).add(v);
    }
    // 2026-05-07 (post-fix v3): apply book filter to YsWords AI
    // results too. The user expected the filter scope to apply to
    // every search mode (text / Strong's / AI). Pre-compute the
    // active scope here so refs from other books are dropped before
    // resolution, with their count surfaced in _aiNotice so the user
    // knows the AI suggested more.
    final scopeEnglishBook = filterBook != null
        ? (toEnglish(filterBook!) ?? filterBook!)
        : (!searchAll && mp.currentBook != null
            ? (toEnglish(mp.currentBook!) ?? mp.currentBook!)
            : null);
    int outOfScope = 0;
    for (final ref in result.refs) {
      // Filter scope: book mismatch → count and skip.
      if (scopeEnglishBook != null && ref.book != scopeEnglishBook) {
        outOfScope += 1;
        continue;
      }
      final key = '${ref.book}|${ref.chapter}';
      final candidates = byBookChapter[key];
      if (candidates == null) {
        missing.add(ref);
        continue;
      }
      bool found = false;
      for (final v in candidates) {
        if (v.verse < ref.verseStart || v.verse > ref.verseEnd) continue;
        if (!resolved.contains(v)) resolved.add(v);
        found = true;
      }
      if (!found) missing.add(ref);
    }
    setState(() {
      _aiBusy = false;
      _resetSearchState();
      _results.addAll(resolved);
      for (final v in resolved) {
        bookCounts[v.book] = (bookCounts[v.book] ?? 0) + 1;
      }
      _lastResultsFromAi = true;
      // Compose an inline note that combines: out-of-scope (filter)
      // + missing-from-version drops, when present.
      final notes = <String>[];
      if (outOfScope > 0) {
        notes.add((uiStrings['aiBibleSearchOutOfScope']?[settings.locale] ??
                'YsWords AI also suggested {n} passages outside your '
                    'current filter scope.')
            .replaceAll('{n}', outOfScope.toString()));
      }
      if (missing.isNotEmpty) {
        notes.add(
            (uiStrings['aiBibleSearchSomeMissing']?[settings.locale] ??
                    'YsWords AI also suggested {n} passages not in your '
                        'current Bible version (reference only).')
                .replaceAll('{n}', missing.length.toString()));
      }
      _aiNotice = notes.isEmpty ? null : notes.join('\n');
      searchPerformed = true;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  /// 2026-05-07 (post-fix): localized help dialog that documents
  /// every search syntax the page supports. Until now, the
  /// page accepted Strong's numbers, Bible references, lemmas, and
  /// transliterations silently — users had no way to discover those
  /// features unless they happened to type the right thing. This
  /// dialog is reachable from the AppBar `?` icon and from the
  /// no-recents empty state.
  ///
  /// Wording adapts to locale (zh-Hans / zh-Hant / en) like the rest
  /// of the app.
  void _showSearchHelp(BuildContext context, AppSettings settings) {
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            uiStrings['searchHelpTitle']?[locale] ?? 'How to search',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          contentPadding:
              const EdgeInsets.fromLTRB(24, 12, 24, 0),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchHelpSection(
                  title: uiStrings['searchHelpBasicTitle']?[locale] ??
                      'Basic',
                  rows: [
                    _SearchHelpRow(
                      icon: Icons.text_fields_rounded,
                      label: uiStrings['searchHelpBasicWord']?[locale] ??
                          'Type a word or phrase to find every verse '
                              'containing it.',
                    ),
                    _SearchHelpRow(
                      icon: Icons.menu_book_rounded,
                      label: uiStrings['searchHelpBasicRef']?[locale] ??
                          'Type a reference like "John 3:16", "约 3:16", '
                              'or "Rom 12:1-2" to jump directly.',
                    ),
                    _SearchHelpRow(
                      icon: Icons.history_rounded,
                      label: uiStrings['searchHelpBasicRecent']?[locale] ??
                          'Tap any recent search above to repeat it. '
                              'Tap × to remove a single entry.',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SearchHelpSection(
                  title: uiStrings['searchHelpAdvancedTitle']?[locale] ??
                      'Advanced',
                  rows: [
                    _SearchHelpRow(
                      icon: Icons.tag_rounded,
                      label: uiStrings['searchHelpAdvStrongs']?[locale] ??
                          'Strong\'s number: type "G2316" / "H7200" '
                              'to open the lexicon and concordance.',
                    ),
                    _SearchHelpRow(
                      icon: Icons.translate_rounded,
                      label: uiStrings['searchHelpAdvLemma']?[locale] ??
                          'Greek / Hebrew word: type ἀγάπη or אהבה. '
                              'Match → opens the lexicon entry.',
                    ),
                    _SearchHelpRow(
                      icon: Icons.spellcheck_rounded,
                      label: uiStrings['searchHelpAdvTranslit']?[locale] ??
                          'Transliteration: type "agape", "shalom", '
                              '"logos". Exact matches open the lexicon; '
                              'partial matches show as a "Did you mean…" '
                              'card alongside text results.',
                    ),
                    _SearchHelpRow(
                      icon: Icons.auto_awesome,
                      label: uiStrings['searchHelpAdvAi']?[locale] ??
                          'YsWords AI search: when keyword search '
                              'returns nothing, tap "Search with YsWords '
                              'AI" for fuzzy / thematic queries (e.g. '
                              '"the love chapter"). Results are for '
                              'reference only — verify before use.',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          uiStrings['searchHelpFooter']?[locale] ??
                              'Search scans the Bible version you have '
                                  'loaded — change versions in Settings if '
                                  'matches feel off.',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(uiStrings['ok']?[locale] ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  // Method to perform the search
  Future<void> search() async {
    final query = _textEditingController.text.trim();
    if (query.isEmpty) {
      // 2026-05-07 (post-fix): empty query is NOT a "search" — it just
      // returns the user to the empty state (recents + tips). The old
      // code set searchPerformed=true here, which made the page show
      // "No results" with an empty bar — confusing.
      setState(() {
        _resetSearchState();
      });
      return;
    }

    // 2026-05-07 (post-fix v2): self-heal when the corpus is empty.
    // Deep-link refreshes that land directly on the SearchPage can
    // race ahead of the bootstrap loader — on those paths the user
    // would otherwise type a query, get 0 results, and conclude that
    // search itself is broken. Auto-load if needed; bail to "no
    // results" only after a successful load that genuinely returned
    // nothing.
    final loaded = await _ensureVersesLoaded();
    if (!mounted) return;
    if (!loaded) {
      // The loading state widget is shown by the build method; just
      // exit so we don't render the empty/no-results path on top.
      return;
    }

    // Strong's-number search path. When the input matches "G2316" /
    // "H7200" / etc., bypass the text scan and load the bundled
    // concordance — every verse where that Strong's word appears.
    final strongsMatch = _strongsQueryPattern.firstMatch(query);
    if (strongsMatch != null) {
      final prefix = strongsMatch.group(1)!.toUpperCase();
      final digits = strongsMatch.group(2)!;
      final num = '$prefix$digits';
      setState(() {
        _resetSearchState();
        _strongsKey = num;
      });
      final entry = await StrongsService.lookup(num);
      final conc = await ConcordanceService.lookup(num);
      if (!mounted) return;
      setState(() {
        _strongsEntry = entry;
        _strongsResult = conc;
        searchPerformed = true;
      });
      return;
    }

    // 2026-05-07 (post-fix): lemma redirect policy.
    //
    // OLD behavior (buggy): any Latin token of length 3-25 was sent
    // through `searchByLemma`, and ANY match (including weak
    // contains-matches) auto-redirected to the lexicon. So typing
    // "love" / "father" / "faith" could silently land on a Greek
    // lexicon entry instead of doing the text search the user wanted.
    //
    // NEW behavior:
    //   - Greek/Hebrew script in input → still always lemma search
    //     (the verses don't contain those characters, text search
    //     would always return 0).
    //   - Latin token → only auto-redirect on EXACT match (lemma
    //     normalised == query OR translit normalised == query, i.e.
    //     score 0/1 from searchByLemma). Weaker matches are kept
    //     aside and surfaced as a "Did you mean lexicon entry…"
    //     suggestion above the regular text-search results.
    final hasGreek = RegExp(r'[Ͱ-Ͽἀ-῿]').hasMatch(query);
    final hasHebrew = RegExp(r'[֐-׿יִ-ﭏ]').hasMatch(query);
    final isLatinToken = RegExp(r'^[a-zA-ZÀ-ɏḀ-ỿ]+$').hasMatch(query) &&
        query.length >= 3 &&
        query.length <= 25;

    StrongsEntry? lemmaSuggestion;
    if (hasGreek || hasHebrew || isLatinToken) {
      final matches = await StrongsService.searchByLemma(query, limit: 4);
      if (!mounted) return;
      if (matches.isEmpty) {
        // No lemma match. Greek/Hebrew script → bail with empty
        // results (text search is guaranteed empty against
        // translations). Latin token → fall through to text search.
        if (hasGreek || hasHebrew) {
          setState(() {
            _resetSearchState();
            searchPerformed = true;
          });
          return;
        }
      } else {
        final best = matches.first;
        // Exact-match decision: derive normalised forms inline since
        // StrongsService._normaliseForLemma is private.
        final qNorm = _normaliseLemmaInline(query);
        final lemmaNorm = _normaliseLemmaInline(best.lemma);
        final translitNorm = _normaliseLemmaInline(best.translit);
        final isExact = qNorm == lemmaNorm || qNorm == translitNorm;
        // Greek/Hebrew script → always redirect (verses don't contain
        // those characters, text search would always be empty). Latin
        // tokens → only redirect on exact lemma/translit match;
        // weaker matches are surfaced as a "Did you mean…" chip.
        final shouldRedirect =
            (hasGreek || hasHebrew) || (isLatinToken && isExact);
        if (shouldRedirect) {
          final num = best.number;
          setState(() {
            _resetSearchState();
            _strongsKey = num;
            _strongsEntry = best;
          });
          final conc = await ConcordanceService.lookup(num);
          if (!mounted) return;
          setState(() {
            _strongsResult = conc;
            searchPerformed = true;
          });
          return;
        }
        lemmaSuggestion = best;
      }
    }
    // Guard before any context lookup — searchByLemma above is async
    // and the user may have left this page during the await.
    if (!mounted) return;

    setState(() {
      _resetSearchState();
      _lemmaSuggestion = lemmaSuggestion;
    });

    final mainProvider = Provider.of<MainProvider>(context, listen: false);
    final verses = mainProvider.verses;
    final source = filterBook != null
        ? verses.where((v) => v.book == filterBook)
        : searchAll
            ? verses
            : verses.where((v) => v.book == mainProvider.currentBook);

    // 2026-05-07 (post-fix): count what was actually scanned so the
    // no-results banner can distinguish "Bible not loaded" from
    // "filter excluded the match" from "query genuinely absent".
    final sourceList = source.toList();
    _lastScanCount = sourceList.length;
    final queryNorm =
        _textEditingController.text.trim().replaceAll(' ', '').toLowerCase();
    for (var verse in sourceList) {
      final sanitized = sanitizeForSearch(verse.text);
      final textNorm = sanitized.replaceAll(' ', '').toLowerCase();
      if (textNorm.contains(queryNorm)) {
        if (!_results.contains(verse)) {
          _results.add(verse);
          bookCounts[verse.book] = (bookCounts[verse.book] ?? 0) + 1;
        }
      }
    }

    final bookOrder = {
      for (var i = 0; i < mainProvider.books.length; i++)
        mainProvider.books[i].title: i
    };

    _results.sort((a, b) {
      final orderA = bookOrder[a.book] ?? 9999;
      final orderB = bookOrder[b.book] ?? 9999;
      if (orderA != orderB) return orderA.compareTo(orderB);
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verse.compareTo(b.verse);
    });

    final sortedEntries = bookCounts.entries.toList()
      ..sort((a, b) {
        final orderA = bookOrder[a.key] ?? 9999;
        final orderB = bookOrder[b.key] ?? 9999;
        return orderA.compareTo(orderB);
      });
    bookCounts = {for (var e in sortedEntries) e.key: e.value};

    setState(() {
      searchPerformed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) {
          Get.back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          // Search input field in the app bar.
          // 2026-05-07: text + hint colors derived from the AppBar's
          // foregroundColor (not the page surface), so the input is
          // readable on the saturated AppBar background instead of
          // inheriting the global form-input colors which were tuned
          // for white surfaces.
          title: TextField(
            autofocus: true,
            controller: _textEditingController,
            style: TextStyle(
              fontSize: settings.fontSize,
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
            cursorColor: Theme.of(context).appBarTheme.foregroundColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: uiStrings['search']?[settings.locale] ?? 'Search',
              hintStyle: TextStyle(
                color: (Theme.of(context).appBarTheme.foregroundColor ??
                        Theme.of(context).colorScheme.onSurface)
                    .withValues(alpha: 0.65),
              ),
            ),
            inputFormatters: [
              // Allow alphanumerics + Chinese chars + space + the
              // colon / dash / dot punctuation needed to type Bible
              // references like "John 3:16" or "约 3:16-18".
              FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9a-zA-Z\u4E00-\u9FFF\u00C0-\u024F\u0370-\u03FF\u1F00-\u1FFF\u0590-\u05FF :\-\.：。‐–—]')),
            ],
            onChanged: (text) {
              // 2026-05-07 (post-fix v3): user feedback — filter must
              // persist across edits. Previously, deleting all chars
              // silently reset filterBook=null + searchAll=true; the
              // user expected their book filter to stick. setState is
              // still needed for the X-button visibility update.
              setState(() {});
            },
            onSubmitted: (s) async {
              final trimmed = s.trim();
              if (trimmed.isEmpty) {
                // Empty submit = abandon the query but keep the
                // user's filter selection so the next typed query
                // honours it.
                await search();
                return;
              }
              // Strong's-shaped query ("G25", "H430", "Strong G1234")
              // jumps straight to the lexicon entry — common idiom in
              // study-tool searches. Done before reference parsing
              // because "H1" could otherwise match a malformed ref.
              final strongs = parseStrongsNumber(trimmed);
              if (strongs != null) {
                Get.to(() => StrongsEntryPage(number: strongs),
                    transition: Transition.rightToLeft);
                return;
              }
              // Then try parsing as a Bible reference. If it
              // resolves to a real verse in the current version,
              // navigate straight there instead of doing full-text
              // search — that's almost always what the user wants
              // when they typed something that looks like a reference.
              final ref = parseReference(trimmed);
              if (ref != null) {
                final mainProv =
                    Provider.of<MainProvider>(context, listen: false);
                if (_navigateToReference(ref, mainProv)) return;
              }
              // Record the query in the recent-searches list AFTER
              // we've established that the user submitted a real
              // text-search (not a Strong's # or a parseable
              // reference, which navigate away). Fire-and-forget
              // is fine — list is only read on next page open.
              await RecentSearchesService.add(trimmed);
              await _loadRecents();
              await search();
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0.0);
              }
            },
            textInputAction: TextInputAction.search,
          ),
          actions: [
            // 2026-05-07 (post-fix): help icon. Opens a localized
            // dialog explaining basic + advanced search syntax —
            // direct text, Bible refs, Strong's #s, Greek/Hebrew
            // lemmas, transliterations, and YsWords AI fallback.
            // Replaces the implicit-only learning curve where
            // advanced features were undiscoverable.
            IconButton(
              tooltip: uiStrings['searchHelpTooltip']?[settings.locale] ??
                  'Search tips',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showSearchHelp(context, settings),
            ),
            PopupMenuButton<Object>(
              tooltip: uiStrings['showMenu']?[settings.locale] ?? 'Show menu',
              icon: const Icon(Icons.filter_list),
              onSelected: (value) async {
                // 2026-05-07 (post-fix v3): replay the LAST search
                // mode (text / Strong's / YsWords AI) with the new
                // filter, instead of always defaulting to text
                // search. Without this, a user who got AI results
                // and changed the filter saw their AI results
                // replaced with a (probably empty) text search.
                final wasAi = _lastResultsFromAi;
                final hadStrongs = _strongsKey != null;
                setState(() {
                  _results.clear();
                  bookCounts.clear();
                  if (value is bool) {
                    searchAll = value;
                    filterBook = null;
                  } else if (value is String) {
                    filterBook = value;
                    searchAll = false;
                  }
                });
                if (wasAi) {
                  // Re-run YsWords AI in the new scope. The
                  // post-resolve filter inside _askAi() drops refs
                  // outside the active filterBook / searchAll, with
                  // a notice line so the user can see how many were
                  // dropped.
                  await _askAi();
                } else if (hadStrongs) {
                  // Strong's mode: just rebuild — _buildStrongsRefList
                  // re-applies the filter at render time. No need to
                  // re-fetch the concordance.
                  setState(() {});
                } else {
                  await search();
                }
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0.0);
                }
              },
              itemBuilder: (_) {
                // base scope items
                final items = <PopupMenuEntry<Object>>[
                  PopupMenuItem<bool>(
                      value: false,
                      child: Text(
                          uiStrings['searchCurrentBook']?[settings.locale] ??
                              'Search Current Book',
                          style: TextStyle(fontSize: settings.fontSize))),
                  PopupMenuItem<bool>(
                      value: true,
                      child: Text(
                          uiStrings['searchEntireBible']?[settings.locale] ??
                              'Search Entire Bible',
                          style: TextStyle(fontSize: settings.fontSize))),
                ];
                // divider
                items.add(const PopupMenuDivider());
                // use bookCounts for per-book counts
                bookCounts.forEach((book, count) {
                  items.add(
                    PopupMenuItem<String>(
                      value: book,
                      child: Text('$book ($count)',
                          style: TextStyle(fontSize: settings.fontSize)),
                    ),
                  );
                });
                return items;
              },
            ),
            // Clear search button when there's input. Uses the
            // central state reset so leftover AI / Strong's / lemma
            // suggestion state doesn't bleed into the next search.
            if (_textEditingController.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  setState(() {
                    _textEditingController.clear();
                    FocusScope.of(context).unfocus(); // 关闭键盘
                    _resetSearchState();
                    searchAll = true; // ✅ 恢复为整本搜索
                    filterBook = null; // ✅ 清除书卷筛选
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
            const HomeIconButton(),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveBreakpoints.isTabletOrWider(
                      MediaQuery.of(context).size.width)
                  ? 720
                  : double.infinity,
            ),
            child: Column(
          children: [
            // 2026-05-07 (post-fix v2): "Bible loading…" / load-failed
            // banner. Replaces the silent "0 results · scanned 0"
            // state when the user opens search before the corpus is
            // ready. _ensureVersesLoaded() drives the flag.
            if (_isLoadingVerses)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2.4),
                      const SizedBox(height: 14),
                      Text(
                        uiStrings['searchLoadingBible']?[settings.locale] ??
                            'Loading the Bible…',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_versesLoadError != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 32,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 10),
                        Text(
                          uiStrings['searchLoadBibleFailed']
                                  ?[settings.locale] ??
                              'Could not load the Bible.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => _ensureVersesLoaded(),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(uiStrings['retry']?[settings.locale] ??
                              'Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_strongsKey != null) ...[
              _buildStrongsHeader(context, settings),
              Expanded(
                child: _buildStrongsRefList(context, settings),
              ),
            ] else ...[
            if (_results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    if (bookCounts.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text(
                              uiStrings['bibleBooks']?[settings.locale] ??
                                  'Bible Books',
                              style: TextStyle(fontSize: settings.fontSize),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: bookCounts.entries
                                    .map((e) => Text('${e.key} (${e.value})',
                                        style: TextStyle(
                                            fontSize: settings.fontSize)))
                                    .toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                    uiStrings['ok']?[settings.locale] ?? 'OK',
                                    style:
                                        TextStyle(fontSize: settings.fontSize)),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  child: Text(
                    _lastResultsFromAi
                        // AI-results header: cleaner / more inviting
                        // than the per-book breakdown for keyword
                        // matches. Users opt into AI search precisely
                        // when keyword exact-match wasn't useful, so
                        // a thematic / conceptual phrasing fits better.
                        ? (uiStrings['aiBibleSearchHeader']
                                    ?[settings.locale] ??
                                'YsWords AI found {count} passages for '
                                    '"{query}" (reference only)')
                            .replaceAll('{count}', _results.length.toString())
                            .replaceAll(
                                '{query}', _textEditingController.text.trim())
                        : '${(uiStrings['searchResultCount']?[settings.locale] ?? 'Total {count} matches, grouped by book:').replaceAll('{count}', _results.length.toString())} ${bookCounts.entries.take(3).map((e) => '${e.key}(${e.value})').join(settings.locale == 'en' ? ', ' : '，')}${bookCounts.length > 3 ? '...' : ''}${bookCounts.length > 3 ? '\n${uiStrings['viewMoreBooksHint']?[settings.locale] ?? ''}' : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: settings.fontSize,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _results.isEmpty
                  ? _buildEmptyState(context, settings)
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final verse = _results[index];
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Theme.of(context).hoverColor),
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              // pendingJump handshake — see
                              // lib/utils/jump_to_reference.dart for
                              // the rationale. Replaces the previous
                              // Future.delayed(300ms) which often
                              // missed cold-start and slow-device
                              // builds, leaving the user at the top
                              // of the chapter.
                              final mainProv = Provider.of<MainProvider>(
                                  context,
                                  listen: false);
                              prepareJumpToVerse(verse, mainProv);
                              Get.back();
                            },
                            // Sanitize verse text: remove <note:…> and {...}, leave […]
                            title: Builder(
                              builder: (context) {
                                final sanitized = sanitizeForSearch(verse.text);
                                return formatSearchText(
                                  input: sanitized,
                                  text: _textEditingController.text.trim(),
                                  context: context,
                                );
                              },
                            ),
                            subtitle: Text(
                              '${verse.book} ${verse.chapter}:${verse.verseLabel}',
                              style:
                                  TextStyle(fontSize: settings.fontSize * 0.85),
                            ),
                          ),
                        );
                      },
                    ),
            )
            ],
          ],
            ),
          ),
        ),
        ),
    );
  }

  /// Header for Strong's-search mode: the Strong's number badge,
  /// lemma, and a short result summary. Replaces the bookCounts
  /// summary row used by text search.
  Widget _buildStrongsHeader(BuildContext context, AppSettings settings) {
    final scheme = Theme.of(context).colorScheme;
    final entry = _strongsEntry;
    final result = _strongsResult;
    final num = _strongsKey ?? '';
    if (!searchPerformed && entry == null && result == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final total = result?.total ?? 0;
    final shown = result?.refs.length ?? 0;
    final usedTemplate = uiStrings['concordanceUsed']?[settings.locale] ??
        'Used {count} times';
    final usedLabel = usedTemplate.replaceAll('{count}', total.toString());
    final showingFirst = (total > 0 && shown < total)
        ? (uiStrings['concordanceShowingFirst']?[settings.locale] ??
                'showing first {shown} of {total}')
            .replaceAll('{shown}', shown.toString())
            .replaceAll('{total}', total.toString())
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    num,
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
                    entry?.lemma ?? num,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (entry != null &&
                entry.localizedGloss(settings.locale).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.localizedGloss(settings.locale),
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              usedLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
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
          ],
        ),
      ),
    );
  }

  /// Tappable list of all concordance references for the queried
  /// Strong's number. Each row navigates to that verse — same flow as
  /// regular search results.
  Widget _buildStrongsRefList(BuildContext context, AppSettings settings) {
    final result = _strongsResult;
    if (result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            uiStrings['noResults']?[settings.locale] ?? 'No results found',
            style: TextStyle(
              fontSize: settings.fontSize,
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    // 2026-05-07 (post-fix v3): apply book filter to Strong's
    // concordance results too. The filter dropdown ("Search current
    // book" / "Search entire Bible") used to silently apply only to
    // the text-search path; for Strong's lookups it had no effect,
    // which surprised users — typing G2316 while filtered to a book
    // would show every occurrence in the whole Bible. Now: when
    // searchAll is false (or filterBook is set) we keep only refs
    // whose canonical English book matches the current scope.
    final mainProv = Provider.of<MainProvider>(context, listen: false);
    final scopeEnglishBook = filterBook != null
        ? (toEnglish(filterBook!) ?? filterBook!)
        : (!searchAll && mainProv.currentBook != null
            ? (toEnglish(mainProv.currentBook!) ?? mainProv.currentBook!)
            : null);
    final List<ConcordanceRef> refs = scopeEnglishBook != null
        ? result.refs.where((r) => r.englishBook == scopeEnglishBook).toList()
        : result.refs;
    if (refs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiStrings['noResults']?[settings.locale] ?? 'No results found',
                style: TextStyle(
                  fontSize: settings.fontSize,
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (scopeEnglishBook != null) ...[
                const SizedBox(height: 8),
                _ScopeBanner(
                  searchAll: searchAll,
                  filterBook: filterBook,
                  versesScanned: result.refs.length,
                  onWiden: (filterBook != null || !searchAll)
                      ? () {
                          setState(() {
                            searchAll = true;
                            filterBook = null;
                          });
                        }
                      : null,
                  locale: settings.locale,
                ),
              ],
            ],
          ),
        ),
      );
    }
    // Build a version-independent index for verse text lookup.
    final verseIndex = <String, String>{
      for (final v in mainProv.verses)
        '${(toEnglish(v.book) ?? v.book)}-${v.chapter}-${v.verse}': v.text,
    };
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: refs.length,
      itemBuilder: (context, index) {
        final ref = refs[index];
        // Display label follows UI locale; navigation lookup (in
        // _navigateToRef) still uses translateBookName so it matches
        // the version's actual verse data.
        final displayBook = localeAwareBookName(
            ref.englishBook, settings.locale, mainProv.currentVersion);
        final preview = verseIndex['${ref.englishBook}-${ref.chapter}-${ref.verse}']
            ?.replaceAll('\n', ' ')
            .replaceAll(notePattern, '')
            .replaceAllMapped(bracePattern, (m) => m.group(1) ?? '')
            .replaceAllMapped(squarePattern, (m) => m.group(1) ?? '')
            .replaceAll(RegExp(r' {2,}'), ' ')
            .trim();
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).hoverColor),
            ),
          ),
          child: ListTile(
            onTap: () => _navigateToRef(ref, mainProv),
            title: Text(
              '$displayBook ${ref.chapter}:${ref.verse}',
              style: TextStyle(fontSize: settings.fontSize),
            ),
            subtitle: preview != null
                ? Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: settings.fontSize - 2),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _navigateToRef(ConcordanceRef ref, MainProvider mainProv) {
    final localBook =
        translateBookName(ref.englishBook, mainProv.currentVersion);
    final match = mainProv.verses.where(
      (v) => v.book == localBook &&
          v.chapter == ref.chapter &&
          v.verse == ref.verse,
    );
    if (match.isEmpty) return;
    final verse = match.first;
    prepareJumpToVerse(verse, mainProv);
    Get.back();
  }

  /// Navigate to a free-form parsed [BibleReference]. Returns true
  /// if the reference resolved to an actual verse in the current
  /// Bible version and the navigation was triggered; false if it
  /// didn't (caller should fall back to full-text search).
  ///
  /// Re-uses the same post-jump highlight + scroll dance as the
  /// concordance-ref handler.
  bool _navigateToReference(BibleReference ref, MainProvider mainProv) {
    final localBook =
        translateBookName(ref.englishBook, mainProv.currentVersion);
    // Find candidate verses in the requested book + chapter.
    final chapterMatches = mainProv.verses
        .where((v) => v.book == localBook && v.chapter == ref.chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    if (chapterMatches.isEmpty) return false;
    // Pick the verse to highlight: explicit verseStart, else the
    // first verse of the chapter.
    final targetVerse = ref.verseStart ?? chapterMatches.first.verse;
    final hit = chapterMatches.firstWhere(
      (v) => v.verse == targetVerse,
      orElse: () => chapterMatches.first,
    );

    prepareJumpToVerse(hit, mainProv);
    Get.back();
    return true;
  }

  /// 2026-05-07 (post-fix): in-page mirror of
  /// `StrongsService._normaliseForLemma` (which is private). Used to
  /// decide whether a lemma-search hit is an exact match — only
  /// exact matches auto-redirect Latin-token queries to the lexicon
  /// view; weaker matches are surfaced as a "Did you mean…" chip.
  static String _normaliseLemmaInline(String s) {
    final lower = s.toLowerCase().trim();
    final out = StringBuffer();
    for (final r in lower.runes) {
      if (r >= 0x0300 && r <= 0x036F) continue;
      if (r >= 0x0591 && r <= 0x05BD) continue;
      if (r == 0x05BF) continue;
      if (r >= 0x05C1 && r <= 0x05C7) continue;
      if (r >= 0x1AB0 && r <= 0x1AFF) continue;
      out.writeCharCode(r);
    }
    return out.toString();
  }
}

/// 2026-05-07: single recent-search row in the redesigned empty
/// state. Mirrors the look of a Material list tile but tighter
/// (1 line, smaller padding) so a dozen entries fit without scrolling.
/// Tapping the body re-runs the query; tapping the × icon removes
/// just that entry from the history.
class _RecentSearchRow extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentSearchRow({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: (settings.fontSize - 1).clamp(13.0, 17.0),
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Per-item delete. Small + subtle so it doesn't compete
            // with the row's primary tap target.
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2026-05-07 (post-fix): scope banner shown in the no-results state
/// so users can see at a glance whether the empty result came from a
/// stuck filter (book scoped to one volume) versus a genuinely
/// missing query. Includes verse-count for the scanned scope and an
/// optional "Search entire Bible" widen button when the active scope
/// is narrower than the whole canon.
class _ScopeBanner extends StatelessWidget {
  final bool searchAll;
  final String? filterBook;
  final int versesScanned;
  final VoidCallback? onWiden;
  final String locale;
  const _ScopeBanner({
    required this.searchAll,
    required this.filterBook,
    required this.versesScanned,
    required this.onWiden,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWhole = filterBook == null && searchAll;
    final scopeLabel = filterBook != null
        ? filterBook!
        : (searchAll
            ? (uiStrings['searchScopeWhole']?[locale] ?? 'Entire Bible')
            : (uiStrings['searchScopeCurrentBook']?[locale] ??
                'Current book'));
    final scanLabel =
        (uiStrings['searchScopeScanned']?[locale] ?? 'Scanned {n} verses')
            .replaceAll('{n}', versesScanned.toString());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 12,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '$scopeLabel · $scanLabel',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!isWhole && onWiden != null) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onWiden,
            icon: const Icon(Icons.unfold_more_rounded, size: 14),
            label: Text(
              uiStrings['searchScopeWiden']?[locale] ??
                  'Search entire Bible instead',
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}

/// 2026-05-07 (post-fix): "Did you mean lexicon entry…" suggestion
/// shown above the no-results empty state. Surfaces when the user's
/// query weakly matched a Greek/Hebrew lemma — tapping opens that
/// entry in the inline Strong's view. Replaces the previous behavior
/// of silently hijacking common English words to the lexicon.
class _LemmaSuggestionCard extends StatelessWidget {
  final StrongsEntry entry;
  final String locale;
  final VoidCallback onTap;
  const _LemmaSuggestionCard({
    required this.entry,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gloss = entry.localizedGloss(locale);
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiStrings['searchLemmaSuggestionTitle']?[locale] ??
                    'Did you mean this lexicon entry?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.number,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      entry.lemma,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (gloss.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  gloss,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
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
}

/// 2026-05-07 (post-fix): one block in the search-help dialog ("Basic"
/// or "Advanced"). Holds the section header + a column of icon-rows.
class _SearchHelpSection extends StatelessWidget {
  final String title;
  final List<_SearchHelpRow> rows;
  const _SearchHelpSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        ...rows,
      ],
    );
  }
}

/// 2026-05-07 (post-fix): one row in the search-help dialog. Icon +
/// description. Used by both the Basic and Advanced sections.
class _SearchHelpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SearchHelpRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
