import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/ai_bible_search_service.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/utils/strongs_boolean_search.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/pages/strongs_entry_page.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/services/recent_searches_service.dart';
import 'package:yswords/utils/clipboard_helper.dart' show ClipboardHelper;
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
import 'package:yswords/utils/ai_markdown.dart' show parseAiMarkdown;
import 'package:yswords/utils/relative_time.dart' show relativeTime;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

// 2026-05-10 (v1.2.31): hoisted regex — used inside the AI-results
// `itemBuilder` for every visible row during scroll, plus the
// "Copy all" loop. Constructing it per-call burned RegExp.compile
// time; one cached instance is reused.
final RegExp _kMultiSpaceRe = RegExp(r' {2,}');

// 2026-05-08 (v1.1.7): the `_SearchMode` enum + `_lastMode` field
// were removed. They drove the active-chip highlight on the
// `_SearchModeStrip` widget; that strip is gone (text search runs
// live, AI search is reachable as a fallback button inside the
// empty state). The `_lastResultsFromAi` boolean already covers
// the only remaining consumer — the result header copy that
// branches "YsWords AI found N passages …" vs the per-book
// breakdown.

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
  /// 2026-05-07 (v9): debounced live-search timer. Each onChanged
  /// keystroke resets the filter to default scope (entire Bible,
  /// text mode) and reschedules a fresh search 250 ms after the
  /// last keystroke -- the user gets results that update as they
  /// type without hammering the for-loop on every character.
  Timer? _liveSearchDebounce;

  bool searchPerformed = false;
  bool searchAll = true;
  Map<String, int> bookCounts = {};
  String? filterBook;
  /// Recent searches for the active profile. Loaded once on init,
  /// updated whenever the user submits a non-trivial query.
  ///
  /// 2026-05-24 (v1.2.91): now a list of (query, createdAt) tuples
  /// instead of raw strings so the UI can render "5 分钟前 /
  /// 5 minutes ago" next to each row. Ordering still comes from
  /// the underlying SharedPreferences StringList (most-recent-first
  /// by insert-at-front); timestamps are display + sync aid only.
  List<RecentSearchEntry> _recents = const [];

  // When the user typed a Strong's-number pattern (e.g. "G2316"), these
  // hold the lookup result; in this mode the regular text-search path
  // is bypassed and the UI renders concordance refs instead of verses.
  String? _strongsKey;
  StrongsEntry? _strongsEntry;
  ConcordanceResult? _strongsResult;

  // 2026-06-18 (v1.3.91): boolean Strong's search — "G25 AND G26",
  // "G25 OR G26", adjacent-implies-AND, and the "G25*" prefix wildcard.
  // When [_booleanQuery] is set the UI renders the combined occurrence
  // refs (set intersection / union) instead of single-Strong's results.
  StrongsBooleanQuery? _booleanQuery;
  List<ConcordanceRef>? _booleanRefs;
  bool _booleanLoading = false;

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

  // 2026-05-10 (v1.2.31): cached verse-index map for the AI-refs
  // ListView.builder. Previously rebuilt fresh inside `build()` on
  // every rebuild (theme toggle, font size change, ANY notifyListeners
  // on settings or main provider) — ~30 k entries. Now built once
  // per (currentVersion, verses identity) pair and reused. The
  // `identical(...)` guard catches version cache swaps that don't
  // change `currentVersion` (e.g. profile switch).
  String? _cachedVerseIndexVersion;
  List<Verse>? _cachedVerseIndexVerses;
  Map<String, String>? _cachedVerseIndex;

  Map<String, String> _getVerseIndex(MainProvider mp) {
    if (identical(_cachedVerseIndexVerses, mp.verses) &&
        _cachedVerseIndexVersion == mp.currentVersion &&
        _cachedVerseIndex != null) {
      return _cachedVerseIndex!;
    }
    _cachedVerseIndexVerses = mp.verses;
    _cachedVerseIndexVersion = mp.currentVersion;
    _cachedVerseIndex = <String, String>{
      for (final v in mp.verses)
        '${(toEnglish(v.book) ?? v.book)}-${v.chapter}-${v.verse}': v.text,
    };
    return _cachedVerseIndex!;
  }

  // 2026-05-08 (v1.1.5): keep the FULL list of refs the AI returned —
  // including those that don't resolve to a verse in the user's
  // currently-loaded Bible version. Previously these went to a silent
  // `missing` local + a tiny notice; users couldn't tell whether AI
  // actually returned anything. Now we always render them as
  // reference-only cards so the user sees the AI's full suggestion
  // list regardless of whether the local corpus has matching text.
  List<AiBibleRef> _aiRefs = const [];
  // Subset of `_aiRefs` whose verses are NOT in the user's loaded
  // version (so the result-list rendering knows to display them as
  // "reference only" rather than as full Verse rows).
  Set<String> _aiUnresolvedRefDisplays = const {};

  /// 2026-05-07 (post-fix): when a regular text search returns 0 or
  /// few results AND the query also looks like it might be a Greek/
  /// Hebrew lemma (e.g. "agape", "shalom"), we show a "Did you mean
  /// lexicon entry: …" suggestion above the empty state. Replaces the
  /// previous behavior of silently auto-redirecting to the lexicon
  /// for any short Latin token, which made common English Bible words
  /// like "love", "faith", "father" hijack themselves to the wrong
  /// view.
  /// 2026-05-07 (v8): no longer set anywhere after Word Study
  /// removal, but the field stays for backwards compat with the
  /// `_resetSearchState()` clear and a possible future re-introduction.
  // ignore: unused_field
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
  // 2026-05-07 (v5 diagnostic): captured AT THE FOR LOOP so we can
  // see whether the corpus was actually present at search time, not
  // just at load-check time.
  int _lastVersesAtSearch = -1;
  bool _lastSearchAll = true;
  String? _lastFilterBook;
  String? _lastCurrentBook;

  /// 2026-05-07 (v6): which mode produced the currently-displayed
  /// results. Drives the highlight on the mode-chip strip.

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
      // 2026-06-12 (v1.3.66): `&& mounted` so the poll STOPS the moment
      // the user leaves the search page. Without it the loop kept
      // scheduling uncancellable Future.delayed ticks for up to 10s
      // after dispose — wasted work on a dead widget (and a pending
      // timer the framework flags).
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (_isLoadingVerses &&
          mounted &&
          DateTime.now().isBefore(deadline)) {
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
    final list = await RecentSearchesService.listWithTimestamps();
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
    _booleanQuery = null;
    _booleanRefs = null;
    _booleanLoading = false;
    _lastResultsFromAi = false;
    _aiNotice = null;
    // 2026-05-08 (v1.1.5): clear the cached AI refs / unresolved set
    // so a new mode (text search / Strong's) doesn't render stale AI
    // suggestion cards.
    _aiRefs = const [];
    _aiUnresolvedRefDisplays = const {};
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
  /// 2026-05-08 (v1.1.10): heuristic — does this `_aiNotice` text
  /// indicate a quota / not-configured failure that BYOK can solve?
  /// Used to gate the "Set up your own Gemini key" deep-link button.
  /// We match on a few keyword fragments rather than HTTP code so
  /// localised messages also trigger correctly.
  bool _shouldOfferByokForNotice(String? notice) {
    if (notice == null) return false;
    final lower = notice.toLowerCase();
    const triggers = [
      'quota',
      'exhausted',
      'rate-limit',
      'rate limit',
      'not configured',
      'gemini_api_key',
      '配额',
      '用完',
      '没有配置',
    ];
    for (final t in triggers) {
      if (lower.contains(t)) return true;
    }
    return false;
  }

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
                        'v=$_lastLoadedVersion · load=$_lastVersesLength · '
                        'src=$_lastVersesAtSearch · all=$_lastSearchAll · '
                        'filter=${_lastFilterBook ?? "-"} · '
                        'cur=${_lastCurrentBook ?? "-"} · '
                        'tries=$_loadAttempts',
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
                    // v1.2.38: shared markdown parser so the
                    // notice text honours Gemini's `**bold**` etc.
                    child: Text.rich(
                      TextSpan(
                        children: parseAiMarkdown(
                          _aiNotice!,
                          base: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 2026-05-08 (v1.1.10): when the AI notice indicates
                  // a quota / not-configured failure AND the user
                  // hasn't already set up their own Gemini key,
                  // surface a one-tap deep-link to Settings → YsWords
                  // AI so they can paste their own AI Studio key.
                  if (_shouldOfferByokForNotice(_aiNotice) &&
                      !settings.hasUserGeminiKey) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.key_rounded, size: 16),
                      label: Text(
                        uiStrings['aiOpenByokSettings']?[locale] ??
                            'Set up your own Gemini API key',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        Get.to(
                          () => const SettingsPage(
                              initialSection: SettingsSection.ai),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                  ],
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
          // List of recent queries — each row: query text + created
          // timestamp + per-item delete button. Tapping the row
          // re-runs that query.
          for (final entry in _recents)
            _RecentSearchRow(
              query: entry.query,
              createdAt: entry.createdAt,
              locale: locale,
              onTap: () async {
                _textEditingController.text = entry.query;
                _textEditingController.selection =
                    TextSelection.fromPosition(
                  TextPosition(offset: entry.query.length),
                );
                await RecentSearchesService.add(entry.query);
                await _loadRecents();
                await search();
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0.0);
                }
              },
              onDelete: () async {
                await RecentSearchesService.remove(entry.query);
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
    // 2026-05-07 (v6): refresh diagnostic so banner is not stuck on
    // src=-1 from a previous text search.
    _lastVersesAtSearch = mp.verses.length;
    _lastSearchAll = searchAll;
    _lastFilterBook = filterBook;
    _lastCurrentBook = mp.currentBook;
    _lastLoadedVersion = mp.currentVersion;
    _lastVersesLength = mp.verses.length;
    setState(() {
      _aiBusy = true;
      _aiNotice = null;
    });
    // 2026-05-08 (v1.1.6): wrap the entire post-busy flow in
    // try/finally so `_aiBusy` ALWAYS resets, regardless of how
    // the function exits — including uncaught exceptions inside
    // the resolve loop, the AiBibleSearchService throwing
    // unexpectedly, etc. The previous version relied on every
    // setState branch to reset the busy flag; one missed branch
    // and the chip stays greyed forever. User reported exactly
    // this: "after AI search returns no verses, deleting a char
    // makes the AI chip un-clickable". Defensive try/finally is
    // the safety net.
    try {
    final result = await AiBibleSearchService.ask(
      query: query,
      locale: settings.locale,
      userApiKey: settings.geminiApiKey.isEmpty ? null : settings.geminiApiKey,
      aiModel: settings.aiModel,
    );
    if (!mounted) return;
    // 2026-05-08 (v1.1.5): every early-return path now also flips
    // `searchPerformed = true` and resets stale state, so the empty
    // state widget actually renders with the AI notice attached.
    // The previous version left `searchPerformed = false` on the
    // unavailable / empty-refs branches, which made `_aiNotice`
    // invisible (it's only rendered inside `_buildEmptyState`, which
    // only renders when `searchPerformed == true`). Symptom: user
    // taps AI, gets no feedback, assumes the chip is broken.
    if (result.unavailable) {
      setState(() {
        _aiBusy = false;
        _resetSearchState();
        _lastResultsFromAi = true;
        _aiNotice = result.unavailableReason;
        searchPerformed = true;
      });
      return;
    }
    if (result.refs.isEmpty) {
      setState(() {
        _aiBusy = false;
        _resetSearchState();
        _lastResultsFromAi = true;
        _aiNotice = uiStrings['aiBibleSearchNoMatches']?[settings.locale] ??
            'YsWords AI didn\'t find any matching passages for that '
                'query (reference only).';
        searchPerformed = true;
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
    // 2026-05-08 (v1.1.5): keep ALL the refs the AI returned, not
    // just the ones that resolve to a Verse in the local corpus.
    // The result-list renderer can use this to show reference-only
    // cards so the user always sees the AI's full suggestion list,
    // regardless of whether their loaded version has the verses.
    final keptRefs = <AiBibleRef>[];
    for (final ref in result.refs) {
      // Drop refs that fall outside the user's filter scope (we
      // already counted them as `outOfScope` above).
      if (scopeEnglishBook != null && ref.book != scopeEnglishBook) {
        continue;
      }
      keptRefs.add(ref);
    }
    final missingDisplaySet = <String>{
      for (final r in missing) r.display,
    };
    setState(() {
      _aiBusy = false;
      _resetSearchState();
      _results.addAll(resolved);
      for (final v in resolved) {
        bookCounts[v.book] = (bookCounts[v.book] ?? 0) + 1;
      }
      _lastResultsFromAi = true;
      _aiRefs = keptRefs;
      _aiUnresolvedRefDisplays = missingDisplaySet;
      // Compose an inline note that combines: out-of-scope (filter)
      // + missing-from-version drops, when present.
      // 2026-05-11 (v1.2.42): the v1.2.37 `fellBackToFlash` branch
      // was removed — v1.2.40's switch to gemini-3-flash-preview
      // made Deep work on free tier without silent downgrade.
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
    } finally {
      // 2026-05-08 (v1.1.6): unconditional safety net — if anything
      // above threw an uncaught exception (HTTP failure that
      // bypassed the service's own catch, JSON parse error,
      // resolve-loop crash …), the chip would otherwise stay
      // greyed forever. Reset busy if it's still true here.
      if (mounted && _aiBusy) {
        setState(() => _aiBusy = false);
      }
    }
  }

  @override
  void dispose() {
    // 2026-05-07 (v9): cancel any in-flight debounce so a fired
    // search() doesn't try to setState after the State is gone.
    _liveSearchDebounce?.cancel();
    // 2026-05-11 (v1.2.42): same for the settle-debounced recents
    // commit timer — fire-and-forget RecentSearchesService.add
    // would otherwise race a now-disposed `_loadRecents` setState.
    _recentsCommitTimer?.cancel();
    _scrollController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  /// 2026-05-07 (v10): bulk-copy every search result as plain text.
  /// Format: each verse on its own line as
  /// "Book Chapter:Verse  text"
  /// Heads with a "Search: 'query' · N matches" line so the user has
  /// the search context when pasting elsewhere. Strips inline
  /// annotations ({…}, [...], <note:...>) via sanitizeForSearch so
  /// the pasted text is clean readable Scripture.
  Future<void> _copyAllResults(
      BuildContext context, AppSettings settings) async {
    if (_results.isEmpty) return;
    final query = _textEditingController.text.trim();
    final header =
        (uiStrings['copyAllResultsHeader']?[settings.locale] ??
                'Search: "{query}" · {n} matches')
            .replaceAll('{query}', query)
            .replaceAll('{n}', _results.length.toString());
    final lines = <String>[header, ''];
    for (final v in _results) {
      final clean = sanitizeForSearch(v.text)
          .replaceAll('\n', ' ')
          .replaceAll(_kMultiSpaceRe, ' ')
          .trim();
      lines.add('${v.book} ${v.chapter}:${v.verseLabel}  $clean');
    }
    final blob = lines.join('\n');
    await ClipboardHelper.copyWithFeedback(
      context,
      blob,
      messageOverride: (uiStrings['copyAllResultsToast']?[settings.locale] ??
              'Copied {n} matches')
          .replaceAll('{n}', _results.length.toString()),
    );
  }

  /// 2026-06-18 (v1.3.94): copy ONE result row — long-press any search
  /// result (text / AI / Strong's / boolean) to copy "Book ch:verse  text".
  /// Consistent across every search mode; reference-only when no verse text.
  Future<void> _copyVerseLine(
      BuildContext context, String reference, String? text) async {
    final clean = (text == null || text.isEmpty)
        ? ''
        : sanitizeForSearch(text)
            .replaceAll('\n', ' ')
            .replaceAll(_kMultiSpaceRe, ' ')
            .trim();
    await ClipboardHelper.copyWithFeedback(
      context,
      clean.isEmpty ? reference : '$reference  $clean',
    );
  }

  /// 2026-06-18 (v1.3.94): "copy all" for the Strong's-concordance and
  /// boolean result lists — same format + toast as the text-search copy-all,
  /// so every search mode offers a consistent copy-everything action.
  Future<void> _copyAllRefList(BuildContext context, AppSettings settings,
      String header, List<ConcordanceRef> refs) async {
    if (refs.isEmpty) return;
    final mainProv = Provider.of<MainProvider>(context, listen: false);
    final verseIndex = _getVerseIndex(mainProv);
    final lines = <String>[header, ''];
    for (final r in refs) {
      final displayBook = localeAwareBookName(
          r.englishBook, settings.locale, mainProv.currentVersion);
      final raw = verseIndex['${r.englishBook}-${r.chapter}-${r.verse}'] ?? '';
      final clean = sanitizeForSearch(raw)
          .replaceAll('\n', ' ')
          .replaceAll(_kMultiSpaceRe, ' ')
          .trim();
      lines.add('$displayBook ${r.chapter}:${r.verse}  $clean'.trim());
    }
    await ClipboardHelper.copyWithFeedback(
      context,
      lines.join('\n'),
      messageOverride: (uiStrings['copyAllResultsToast']?[settings.locale] ??
              'Copied {n} matches')
          .replaceAll('{n}', refs.length.toString()),
    );
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
                      icon: Icons.join_inner_rounded,
                      label: uiStrings['searchHelpAdvBoolean']?[locale] ??
                          'Combine Strong\'s numbers with the AND / OR / ✶ '
                              'buttons (they appear when you type a number): '
                              '"G25 AND G26" → verses with BOTH; "G25 OR G26" '
                              '→ EITHER; "G25✶" → every number starting with '
                              'G25.',
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

  // 2026-05-07 (v6): bare-bones search rewrite. Earlier versions
  // wrapped the for-loop in latch / polling / multi-step setState
  // chains; the user kept seeing "scanned 0 verses" no matter what
  // I tried. Strip the wrapping. Single async function, single
  // setState at the end, print every intermediate state so the user
  // can read it in browser DevTools console (debugPrint outputs to
  // console.log on Flutter web).
  Future<void> search() async {
    try {
      await _searchImpl();
    } catch (e, st) {
      // 2026-05-07 (v7 diag): wrap the whole body so any exception
      // bubbles into the console with a CLEAR marker. The user's
      // recent screenshot shows search() printing "start" + "mp"
      // and then nothing — most likely an uncaught exception.
      debugPrint('[YsWords search] EXCEPTION: $e\n$st');
      if (mounted) {
        setState(() {
          _versesLoadError = 'Search crashed: $e';
        });
      }
    }
  }

  Future<void> _searchImpl() async {
    // 2026-05-07 (v8): user removed the Word Study mode. Text
    // search is now PURE text scan -- no Strong's redirect, no
    // lemma redirect, no "did you mean" suggestion. Just iterate
    // mp.verses, match the sanitized text against the query, show
    // results. The "Search" chip / Enter submit always lands here.
    // Strong's-number queries (G2316 / H7200) still navigate to
    // the separate StrongsEntryPage via parseStrongsNumber inside
    // the TextField onSubmitted handler, before _searchImpl runs.
    final query = _textEditingController.text.trim();
    debugPrint('[YsWords search] start query="$query"');
    if (query.isEmpty) {
      setState(() => _resetSearchState());
      return;
    }

    final mp = Provider.of<MainProvider>(context, listen: false);
    debugPrint('[YsWords search] mp=${mp.hashCode} '
        'verses=${mp.verses.length} ver=${mp.currentVersion} '
        'curBook=${mp.currentBook}');
    debugPrint('[YsWords search] CHECKPOINT-1');

    // Load corpus if missing. Direct, no latch.
    if (mp.verses.isEmpty) {
      debugPrint('[YsWords search] verses empty, loading...');
      setState(() {
        _isLoadingVerses = true;
        _versesLoadError = null;
      });
      try {
        await FetchVerses.execute(mainProvider: mp);
      } catch (e) {
        debugPrint('[YsWords search] load failed: $e');
        if (!mounted) return;
        setState(() {
          _isLoadingVerses = false;
          _versesLoadError = e.toString();
        });
        return;
      }
      if (!mounted) return;
      setState(() => _isLoadingVerses = false);
      debugPrint(
          '[YsWords search] loaded; verses=${mp.verses.length}');
    }
    if (mp.verses.isEmpty) {
      debugPrint(
          '[YsWords search] still empty after load attempt — bail');
      setState(() {
        _resetSearchState();
        _versesLoadError =
            'Loaded but empty (version=${mp.currentVersion}).';
      });
      return;
    }
    _lastVersesLength = mp.verses.length;
    _lastLoadedVersion = mp.currentVersion;
    debugPrint('[YsWords search] CHECKPOINT-2');

    // 2026-05-07 (v8): Word Study removed at user request. Text
    // search no longer redirects to Strong's / lemma views. The
    // user wants the Search chip and Enter to ALWAYS produce a
    // verse list. No detours.

    // We already have `mp` from the top of search(). No setState
    // here yet — gather everything first, single setState at the
    // end so there is exactly one rebuild cycle and zero window
    // for state to drift.
    final verses = mp.verses;
    debugPrint('[YsWords search] for-loop verses=${verses.length} '
        'searchAll=$searchAll filter=$filterBook curBook=${mp.currentBook}');

    // 2026-05-08 (v1.0.1 perf): walk the parallel `verses` /
    // `searchKeys` arrays by index instead of going through `.where`
    // + `.toList()` + a fresh `sanitizeForSearch + replaceAll +
    // toLowerCase` per verse on every keystroke. The keys array is
    // built once per `setVerses` (lazy on first read) and reused
    // across keystrokes — collapsing each search from O(n × regex
    // chain) to O(n × String.contains).
    final searchKeys = mp.searchKeys;
    final queryNorm = query.replaceAll(' ', '').toLowerCase();
    final matches = <Verse>[];
    final localCounts = <String, int>{};
    final useFilter = filterBook != null;
    final useCurBook = !useFilter && !searchAll && mp.currentBook != null;
    final filterTarget = filterBook ?? mp.currentBook;
    int scanCount = 0;
    for (int i = 0; i < verses.length; i++) {
      final verse = verses[i];
      if (useFilter && verse.book != filterTarget) continue;
      if (useCurBook && verse.book != filterTarget) continue;
      scanCount++;
      if (searchKeys[i].contains(queryNorm)) {
        matches.add(verse);
        localCounts[verse.book] = (localCounts[verse.book] ?? 0) + 1;
      }
    }
    debugPrint('[YsWords search] matches.length=${matches.length}');

    // 2026-05-08 (v1.0.1 perf): bookOrder is cached on MainProvider
    // and only rebuilt when `setBooks` runs.
    final bookOrder = mp.bookOrder;
    matches.sort((a, b) {
      final orderA = bookOrder[a.book] ?? 9999;
      final orderB = bookOrder[b.book] ?? 9999;
      if (orderA != orderB) return orderA.compareTo(orderB);
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verse.compareTo(b.verse);
    });
    final sortedEntries = localCounts.entries.toList()
      ..sort((a, b) {
        final orderA = bookOrder[a.key] ?? 9999;
        final orderB = bookOrder[b.key] ?? 9999;
        return orderA.compareTo(orderB);
      });
    final orderedCounts = {for (final e in sortedEntries) e.key: e.value};

    if (!mounted) return;
    // Single atomic state update — replaces the previous pattern
    // that mutated _results / bookCounts outside setState then
    // setState'd searchPerformed at the end. Atomic update means
    // no half-built UI state is ever observable.
    setState(() {
      _resetSearchState();
      _results.addAll(matches);
      bookCounts = orderedCounts;
      _lastVersesAtSearch = verses.length;
      _lastSearchAll = searchAll;
      _lastFilterBook = filterBook;
      _lastCurrentBook = mp.currentBook;
      _lastScanCount = scanCount;
      searchPerformed = true;
    });

    // 2026-05-11 (v1.2.42): schedule a settle-debounced recents
    // commit. v1.2.41 fired `RecentSearchesService.add(...)` on
    // every successful live-search, which flooded the list with
    // partial-typing fragments ("lov" / "love" / "love i" /
    // "love is") and pushed the user's REAL past queries off the
    // 12-item cap. The new flow:
    //   • Every `search()` cancels any pending commit and
    //     re-schedules one 2.5 s after the last keystroke.
    //   • Only when the user stops typing for 2.5 s does the
    //     CURRENT live query land in recents.
    //   • Gates as before: length ≥ 3 + non-empty matches +
    //     dedup against the most-recent saved entry (so re-
    //     running the same query in a session doesn't re-touch
    //     the list).
    if (query.length >= 3 && matches.isNotEmpty) {
      _scheduleRecentsCommit(query);
    }
  }

  /// 2026-05-11 (v1.2.42): debounced recents commit. Cancelled +
  /// rescheduled on every successful search; only fires once the
  /// user has been idle for 2.5 s. Deduped against the in-memory
  /// `_recents` list so re-running an already-saved query in a
  /// session doesn't pointlessly re-touch SharedPreferences.
  Timer? _recentsCommitTimer;
  void _scheduleRecentsCommit(String query) {
    _recentsCommitTimer?.cancel();
    _recentsCommitTimer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      // Re-check the trim+length here (the field could have been
      // cleared while the timer was queued).
      final q = _textEditingController.text.trim();
      if (q.length < 3) return;
      // Only persist if the timer's snapshot query matches what's
      // STILL in the box (user hasn't typed away from it).
      if (q != query) return;
      // Skip the disk write when this query is already the most-
      // recent entry. Live-search re-runs the same query on
      // re-mount, on theme toggle, on Provider notify, etc. —
      // we don't want any of those to bump SharedPreferences.
      if (_recents.isNotEmpty &&
          _recents.first.query.toLowerCase() == q.toLowerCase()) {
        return;
      }
      // ignore: unawaited_futures
      RecentSearchesService.add(q).then((_) {
        if (mounted) _loadRecents();
      });
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
            // 2026-05-22 (v1.2.71): allow up to 2 lines so long
            // question-style queries don't clip. minLines: 1 keeps
            // the AppBar's normal height for short queries.
            minLines: 1,
            maxLines: 2,
            keyboardType: TextInputType.text,
            style: TextStyle(
              fontSize: settings.fontSize,
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
            cursorColor: Theme.of(context).appBarTheme.foregroundColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: uiStrings['search']?[settings.locale] ?? 'Search',
              hintStyle: TextStyle(
                color: (Theme.of(context).appBarTheme.foregroundColor ??
                        Theme.of(context).colorScheme.onSurface)
                    .withValues(alpha: 0.65),
              ),
            ),
            onChanged: (text) {
              // 2026-05-07 (v9): live search-as-you-type. Every
              // keystroke:
              //   1. Resets the search to default scope (entire
              //      Bible) and default mode (text). User wanted
              //      "every box edit returns to the default
              //      setting" so the filter never silently lingers
              //      across queries.
              //   2. Rebuilds the AppBar so the X-clear button
              //      shows / hides based on text emptiness.
              //   3. Reschedules a debounced search 250 ms after
              //      the last keystroke. This is enough time to
              //      let the user finish typing while keeping
              //      the results live -- no Enter required.
              //
              // 2026-05-08 (v1.1.6): also defensively unstick
              // `_aiBusy` here. User reported: "after AI search
              // returns no verses, deleting a char makes the AI
              // chip un-clickable". Without this, any edge case
              // that left `_aiBusy = true` (uncaught exception
              // during the AI Future, widget remount mid-flight,
              // etc.) would persist forever, greying the chip.
              // Editing the query is an unambiguous signal the
              // user wants a fresh search — abandon any stuck
              // in-flight AI state.
              setState(() {
                searchAll = true;
                filterBook = null;
                _aiBusy = false;
              });
              _liveSearchDebounce?.cancel();
              _liveSearchDebounce = Timer(
                const Duration(milliseconds: 250),
                () {
                  if (!mounted) return;
                  // Fire-and-forget; the search itself awaits its
                  // own internals and updates state at the end.
                  // ignore: unawaited_futures
                  search();
                },
              );
            },
            onSubmitted: (s) async {
              // 2026-05-07 (v9): cancel any pending debounce so the
              // explicit Enter doesn't end up double-running search.
              _liveSearchDebounce?.cancel();
              final trimmed = s.trim();
              if (trimmed.isEmpty) {
                // Empty submit = abandon the query but keep the
                // user's filter selection so the next typed query
                // honours it.
                await search();
                return;
              }
              // v1.3.91: boolean Strong's query ("G25 AND G26", "G25 OR
              // G26", "G25*") → combined occurrence search rendered in-page.
              // parseStrongsBoolean returns null for a single plain number,
              // so "G2316" still opens the lexicon entry below.
              final boolQuery = parseStrongsBoolean(trimmed);
              if (boolQuery != null) {
                await _runBooleanSearch(boolQuery);
                if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
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
            // v1.3.91: AND / OR / ✶ operator bar — appears once the query
            // contains a Strong's token, so users can build combined
            // original-language searches without typing the syntax.
            _buildOperatorBar(context, settings),
            // 2026-05-08 (v1.1.7): mode-chip strip removed at user
            // request. Reasoning:
            //
            //   • Text search already runs live on every keystroke
            //     (`onChanged` → 250 ms debounce → search()), so a
            //     dedicated "Search" chip was redundant.
            //   • AI search is a *fallback* — used when the literal
            //     text search returns nothing. Showing it as a
            //     peer chip next to the Search chip implied they
            //     were equivalent modes. The user's mental model:
            //     「找不到才用 AI 搜索」.
            //
            // The "Search with YsWords AI" button rendered inside
            // `_buildEmptyState` (only when text search returns 0
            // results) is now the single entry point for AI.
            // Removed two ergonomic problems with the old chip:
            //   - first-tap-no-response (the LiquidGlassButton +
            //     MouseRegion + AnimatedScale stack can swallow
            //     the first tap when the soft-keyboard transition
            //     steals focus on Flutter web);
            //   - the chip getting stuck greyed when `_aiBusy`
            //     leaked (already defensively patched in v1.1.6,
            //     but removing the chip removes the surface).
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
            else if (_booleanQuery != null) ...[
              _buildBooleanHeader(context, settings),
              Expanded(
                child: _buildBooleanRefList(context, settings),
              ),
            ]
            else if (_strongsKey != null) ...[
              _buildStrongsHeader(context, settings),
              Expanded(
                child: _buildStrongsRefList(context, settings),
              ),
            ] else ...[
            if (_results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (bookCounts.isNotEmpty) {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(
                                    uiStrings['bibleBooks']
                                            ?[settings.locale] ??
                                        'Bible Books',
                                    style: TextStyle(
                                        fontSize: settings.fontSize),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: bookCounts.entries
                                          .map((e) => Text(
                                              '${e.key} (${e.value})',
                                              style: TextStyle(
                                                  fontSize:
                                                      settings.fontSize)))
                                          .toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text(
                                          uiStrings['ok']?[settings.locale] ??
                                              'OK',
                                          style: TextStyle(
                                              fontSize: settings.fontSize)),
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
                              // matches.
                              ? (uiStrings['aiBibleSearchHeader']
                                          ?[settings.locale] ??
                                      'YsWords AI found {count} passages for '
                                          '"{query}" (reference only)')
                                  .replaceAll(
                                      '{count}', _results.length.toString())
                                  .replaceAll('{query}',
                                      _textEditingController.text.trim())
                              : '${(uiStrings['searchResultCount']?[settings.locale] ?? 'Total {count} matches, grouped by book:').replaceAll('{count}', _results.length.toString())} ${bookCounts.entries.take(3).map((e) => '${e.key}(${e.value})').join(settings.locale == 'en' ? ', ' : '，')}${bookCounts.length > 3 ? '...' : ''}${bookCounts.length > 3 ? '\n${uiStrings['viewMoreBooksHint']?[settings.locale] ?? ''}' : ''}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: settings.fontSize,
                          ),
                        ),
                      ),
                    ),
                    // 2026-05-07 (v10): copy-all-results button. User
                    // wanted to copy the entire result list at once
                    // (not tap each verse). Formats every match as
                    // "Book Chapter:Verse  text" on its own line and
                    // dumps the lot to the clipboard with the standard
                    // "Copied!" snackbar.
                    IconButton(
                      tooltip: uiStrings['copyAllResults']
                              ?[settings.locale] ??
                          'Copy all results',
                      icon: const Icon(Icons.content_copy_rounded, size: 18),
                      onPressed: _results.isEmpty
                          ? null
                          : () => _copyAllResults(context, settings),
                    ),
                  ],
                ),
              ),
            // 2026-05-08 (v1.1.5): when the AI returns refs but none
            // resolve to verses in the user's loaded version (e.g.
            // their Bible doesn't contain that book/range), still
            // surface the AI's suggestion list as reference cards
            // instead of the generic "No results found" empty state.
            // The cards show "Book ch:verseStart-verseEnd" + the AI's
            // one-sentence reason; tapping does best-effort navigation
            // via the existing reference-jump helper.
            if (_results.isEmpty && _aiRefs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Center(
                  child: Text(
                    (uiStrings['aiBibleSearchHeader']
                                ?[settings.locale] ??
                            'YsWords AI found {count} passages for '
                                '"{query}" (reference only)')
                        .replaceAll(
                            '{count}', _aiRefs.length.toString())
                        .replaceAll('{query}',
                            _textEditingController.text.trim()),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: settings.fontSize,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _results.isEmpty && _aiRefs.isNotEmpty
                  ? _buildAiRefList(context, settings)
                  : _results.isEmpty
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
                              // 2026-05-07 (v11): user reported that
                              // tapping a verse from the dashboard-
                              // launched search did nothing because
                              // Get.back() returned to the dashboard
                              // (which has no pendingJump handler).
                              // Use Get.off(HomePage) -- the same
                              // pattern LibraryPage uses -- so the
                              // user lands at the verse regardless of
                              // whether search was reached from the
                              // reader's AppBar OR the dashboard tile.
                              final mainProv = Provider.of<MainProvider>(
                                  context,
                                  listen: false);
                              prepareJumpToVerse(verse, mainProv);
                              Get.off(
                                () => const HomePage(),
                                transition: Transition.rightToLeft,
                              );
                            },
                            // v1.3.94: long-press to copy this verse.
                            onLongPress: () => _copyVerseLine(
                                context,
                                '${verse.book} ${verse.chapter}:'
                                    '${verse.verseLabel}',
                                verse.text),
                            // v1.3.95: unified result layout — reference on
                            // top (coloured, like the Strong's / boolean
                            // lists), highlighted verse text below.
                            title: Text(
                              '${verse.book} ${verse.chapter}:'
                                  '${verse.verseLabel}',
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Sanitize verse text: remove <note:…> and {...}, leave […]
                            subtitle: Builder(
                              builder: (context) {
                                final sanitized = sanitizeForSearch(verse.text);
                                return formatSearchText(
                                  input: sanitized,
                                  text: _textEditingController.text.trim(),
                                  context: context,
                                );
                              },
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
  // ── v1.3.91: operator bar (AND / OR / ✶ buttons) ───────────────────
  void _insertIntoQuery(String insert) {
    final c = _textEditingController;
    final base = c.text;
    final sel = c.selection;
    var start = sel.start;
    var end = sel.end;
    if (start < 0 || end < 0) {
      start = base.length;
      end = base.length;
    }
    final newText = base.replaceRange(start, end, insert);
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  Widget _buildOperatorBar(BuildContext context, AppSettings settings) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _textEditingController,
      builder: (context, value, _) {
        // Only surface once the query contains a Strong's token, so it
        // doesn't clutter ordinary keyword searches.
        if (!RegExp(r'[gGhH]\s*\d').hasMatch(value.text)) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        Widget chip(String label, String insert, String tip) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                tooltip: tip,
                onPressed: () => _insertIntoQuery(insert),
              ),
            );
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Row(
            children: [
              chip(
                  'AND',
                  ' AND ',
                  uiStrings['searchOpAndTip']?[settings.locale] ??
                      'Verses with BOTH'),
              chip(
                  'OR',
                  ' OR ',
                  uiStrings['searchOpOrTip']?[settings.locale] ??
                      'Verses with EITHER'),
              chip(
                  '✶',
                  '*',
                  uiStrings['searchOpStarTip']?[settings.locale] ??
                      'Prefix wildcard'),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: uiStrings['operatorHelpTitle']?[settings.locale] ??
                    'Combined search',
                icon: Icon(Icons.help_outline_rounded,
                    size: 18, color: scheme.primary),
                onPressed: () => _showOperatorHelp(context, settings),
              ),
            ],
          ),
        );
      },
    );
  }

  /// v1.3.91: focused explainer for the AND / OR / ✶ buttons, opened from
  /// the ? right beside them (so it's discoverable in-context rather than
  /// buried in the general search-help dialog).
  void _showOperatorHelp(BuildContext context, AppSettings settings) {
    final locale = settings.locale;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          uiStrings['operatorHelpTitle']?[locale] ?? 'Combined search',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchHelpRow(
                icon: Icons.join_inner_rounded,
                label: uiStrings['operatorHelpAnd']?[locale] ??
                    'AND — "G25 AND G26": verses with BOTH.',
              ),
              const SizedBox(height: 10),
              _SearchHelpRow(
                icon: Icons.join_full_rounded,
                label: uiStrings['operatorHelpOr']?[locale] ??
                    'OR — "G25 OR G26": verses with EITHER.',
              ),
              const SizedBox(height: 10),
              _SearchHelpRow(
                icon: Icons.star_outline_rounded,
                label: uiStrings['operatorHelpStar']?[locale] ??
                    '✶ — "G25✶": numbers starting with G25.',
              ),
              const SizedBox(height: 10),
              _SearchHelpRow(
                icon: Icons.lightbulb_outline_rounded,
                label: uiStrings['operatorHelpTip']?[locale] ??
                    'Type a number, then tap a button.',
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
      ),
    );
  }

  // ── v1.3.91: boolean Strong's search ───────────────────────────────
  Future<void> _runBooleanSearch(StrongsBooleanQuery query) async {
    setState(() {
      _resetSearchState();
      _booleanQuery = query;
      _booleanLoading = true;
    });
    // Resolve each term to its occurrence label-set (expanding wildcards),
    // then apply the AND/OR set algebra.
    final termRefs = <StrongsTerm, Set<String>>{};
    for (final t in query.terms) {
      if (termRefs.containsKey(t)) continue;
      final labels = <String>{};
      if (t.wildcard) {
        final nums = await ConcordanceService.numbersMatchingPrefix(t.number);
        for (final n in nums) {
          final r = await ConcordanceService.lookup(n);
          if (r != null) labels.addAll(r.refs.map((e) => e.label));
        }
      } else {
        final r = await ConcordanceService.lookup(t.number);
        if (r != null) labels.addAll(r.refs.map((e) => e.label));
      }
      termRefs[t] = labels;
    }
    final resultLabels = evaluateStrongsBoolean(
        query, (t) => termRefs[t] ?? const <String>{});
    final refs = <ConcordanceRef>[];
    for (final label in resultLabels) {
      final parsed = ConcordanceRef.tryParse(label);
      if (parsed != null) refs.add(parsed);
    }
    refs.sort((a, b) {
      final ai = standardBookOrder.indexOf(a.englishBook);
      final bi = standardBookOrder.indexOf(b.englishBook);
      if (ai != bi) return ai.compareTo(bi);
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verse.compareTo(b.verse);
    });
    if (!mounted) return;
    setState(() {
      _booleanRefs = refs;
      _booleanLoading = false;
      searchPerformed = true;
    });
  }

  String _booleanQueryLabel(StrongsBooleanQuery q) {
    final buf = StringBuffer(q.terms.first.toString());
    for (var i = 0; i < q.ops.length; i++) {
      buf.write(q.ops[i] == StrongsOp.and ? ' AND ' : ' OR ');
      buf.write(q.terms[i + 1].toString());
    }
    return buf.toString();
  }

  Widget _buildBooleanHeader(BuildContext context, AppSettings settings) {
    final q = _booleanQuery!;
    final count = _booleanRefs?.length ?? 0;
    final summary = (uiStrings['booleanSearchHeader']?[settings.locale] ??
            '{query} — {count} verses')
        .replaceAll('{query}', _booleanQueryLabel(q))
        .replaceAll('{count}', count.toString());
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: settings.fontSize,
              ),
            ),
          ),
          IconButton(
            tooltip:
                uiStrings['copyAllResults']?[settings.locale] ??
                    'Copy all results',
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            onPressed: (_booleanRefs == null || _booleanRefs!.isEmpty)
                ? null
                : () => _copyAllRefList(
                    context, settings, _booleanQueryLabel(q), _booleanRefs!),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanRefList(BuildContext context, AppSettings settings) {
    if (_booleanLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final refs = _booleanRefs ?? const <ConcordanceRef>[];
    final mainProv = Provider.of<MainProvider>(context, listen: false);
    if (refs.isEmpty) {
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
    final verseIndex = _getVerseIndex(mainProv);
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: refs.length,
      itemBuilder: (context, index) {
        final ref = refs[index];
        final displayBook = localeAwareBookName(
            ref.englishBook, settings.locale, mainProv.currentVersion);
        final preview =
            verseIndex['${ref.englishBook}-${ref.chapter}-${ref.verse}']
                ?.replaceAll('\n', ' ')
                .replaceAll(notePattern, '')
                .replaceAllMapped(bracePattern, (m) => m.group(1) ?? '')
                .replaceAllMapped(squarePattern, (m) => m.group(1) ?? '')
                .replaceAll(_kMultiSpaceRe, ' ')
                .trim();
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).hoverColor),
            ),
          ),
          child: ListTile(
            onTap: () => _navigateToRef(ref, mainProv),
            onLongPress: () => _copyVerseLine(context,
                '$displayBook ${ref.chapter}:${ref.verse}', preview),
            title: Text(
              '$displayBook ${ref.chapter}:${ref.verse}',
              style: TextStyle(fontSize: settings.fontSize),
            ),
            subtitle: preview != null && preview.isNotEmpty
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    usedLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (result != null && result.refs.isNotEmpty)
                  IconButton(
                    tooltip: uiStrings['copyAllResults']?[settings.locale] ??
                        'Copy all results',
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyAllRefList(
                        context, settings, '$num · $usedLabel', result.refs),
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
    // 2026-05-10 (v1.2.31): cached version-independent verse-text
    // lookup. See `_getVerseIndex` — rebuilds only on version /
    // verses-identity change, not every rebuild.
    final verseIndex = _getVerseIndex(mainProv);
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
            .replaceAll(_kMultiSpaceRe, ' ')
            .trim();
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).hoverColor),
            ),
          ),
          child: ListTile(
            onTap: () => _navigateToRef(ref, mainProv),
            onLongPress: () => _copyVerseLine(context,
                '$displayBook ${ref.chapter}:${ref.verse}', preview),
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
    // 2026-05-07 (v11): replace SearchPage with HomePage so the
    // user lands on the verse regardless of how search was reached.
    Get.off(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
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
    // 2026-05-07 (v11): replace SearchPage with HomePage so the
    // user lands on the verse regardless of how search was reached.
    Get.off(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
    return true;
  }

  /// 2026-05-08 (v1.1.5): render the full AI suggestion list as
  /// reference cards. Used when AI returned refs but none resolved
  /// to verses in the user's currently-loaded Bible version (or all
  /// were dropped by the filter scope) — previously we showed a
  /// generic "No results found" empty state with a tiny notice that
  /// users missed, leaving them to think the AI was broken.
  ///
  /// Each card shows:
  ///   • The reference (book + chapter:verseStart-verseEnd) in the
  ///     user's locale
  ///   • The AI's one-sentence reason for why it matches
  ///   • A subtle "reference only" tag for refs not in the loaded
  ///     version
  ///
  /// Tapping resolves the ref via [translateBookName] + the
  /// existing `prepareJumpToVerse` dance for refs that DO exist in
  /// the current version; for refs that don't, the tap surfaces a
  /// snackbar explaining the user can switch Bible versions to read
  /// the passage.
  Widget _buildAiRefList(BuildContext context, AppSettings settings) {
    final mp = Provider.of<MainProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: _aiRefs.length + (_aiNotice != null ? 1 : 0),
      itemBuilder: (context, index) {
        // Render the AI notice (filter / version warnings) as the
        // first row so users always see why some refs are
        // reference-only.
        if (_aiNotice != null && index == 0) {
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            // v1.2.38: shared markdown parser.
            child: Text.rich(
              TextSpan(
                children: parseAiMarkdown(
                  _aiNotice!,
                  base: TextStyle(
                    fontSize: settings.fontSize * 0.75,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          );
        }
        final ref = _aiRefs[index - (_aiNotice != null ? 1 : 0)];
        final unresolved = _aiUnresolvedRefDisplays.contains(ref.display);
        final displayBook = localeAwareBookName(
            ref.book, settings.locale, mp.currentVersion);
        final displayLabel = ref.verseStart == ref.verseEnd
            ? '$displayBook ${ref.chapter}:${ref.verseStart}'
            : '$displayBook ${ref.chapter}:${ref.verseStart}-${ref.verseEnd}';
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).hoverColor),
            ),
          ),
          child: ListTile(
            onTap: () {
              if (unresolved) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                  content: Text(
                    uiStrings['aiRefNotInVersion']?[locale] ??
                        'This passage isn\'t in your current Bible version. '
                            'Switch versions in Settings to read it.',
                  ),
                  duration: const Duration(seconds: 3),
                ));
                return;
              }
              // Use the existing reference-jump path. Walk the local
              // verse list to find the first verse in the ref's
              // chapter range, then prepareJumpToVerse → swap to
              // HomePage.
              final localBook =
                  translateBookName(ref.book, mp.currentVersion);
              final chapterMatches = mp.verses
                  .where((v) =>
                      v.book == localBook &&
                      v.chapter == ref.chapter &&
                      v.verse >= ref.verseStart &&
                      v.verse <= ref.verseEnd)
                  .toList();
              if (chapterMatches.isEmpty) return;
              prepareJumpToVerse(chapterMatches.first, mp);
              Get.off(
                () => const HomePage(),
                transition: Transition.rightToLeft,
              );
            },
            // v1.3.94: long-press to copy the reference (+ AI reason).
            onLongPress: () => _copyVerseLine(
                context, displayLabel, ref.reason.isEmpty ? null : ref.reason),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      fontSize: settings.fontSize,
                      fontWeight: FontWeight.w600,
                      color: unresolved
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                  ),
                ),
                if (unresolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      uiStrings['aiRefOnlyTag']?[locale] ??
                          'reference only',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: ref.reason.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    // 2026-05-11 (v1.2.38): render through shared
                    // markdown parser so Gemini's `**bold**` etc.
                    // displays as bold instead of literal `**`.
                    child: Text.rich(
                      TextSpan(
                        children: parseAiMarkdown(
                          ref.reason,
                          base: TextStyle(
                            fontSize: settings.fontSize * 0.78,
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
            trailing: unresolved
                ? null
                : Icon(Icons.chevron_right_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
          ),
        );
      },
    );
  }
}

/// 2026-05-07: single recent-search row in the redesigned empty
/// state. Mirrors the look of a Material list tile but tighter
/// (1 line, smaller padding) so a dozen entries fit without scrolling.
/// Tapping the body re-runs the query; tapping the × icon removes
/// just that entry from the history.
class _RecentSearchRow extends StatelessWidget {
  final String query;
  // 2026-05-24 (v1.2.91): when set, the row renders a small
  // "5 分钟前 / 5 minutes ago" caption under the query so the user
  // can tell at a glance how fresh each entry is. Null hides the
  // caption (legacy callers).
  final DateTime? createdAt;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentSearchRow({
    required this.query,
    required this.locale,
    required this.onTap,
    required this.onDelete,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // PERF: scoped select instead of full watch<AppSettings>() — this
    // row is instantiated for every recent search query inside a
    // plain (non-builder) ListView, so ALL rows are always mounted
    // at once, uncapped. Same pattern as VerseWidget /
    // ParagraphGroupWidget in bible_reading_pane.
    context.select<AppSettings, (String, double)>(
        (s) => (s.fontFamily, s.fontSize));
    final settings = context.read<AppSettings>();
    final relative = createdAt == null ? null : relativeTime(createdAt!, locale);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: (settings.fontSize - 1).clamp(13.0, 17.0),
                      color: scheme.onSurface,
                    ),
                  ),
                  if (relative != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      relative,
                      style: TextStyle(
                        fontSize:
                            (settings.fontSize - 5).clamp(10.0, 13.0),
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
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

// 2026-05-08 (v1.1.7): _SearchModeStrip + _ModeChip widgets removed
// at user request. Reasoning:
//
//   • Text search runs live on every keystroke (250 ms debounce in
//     `onChanged`), so a "Search" chip duplicated existing
//     behaviour.
//   • AI search is a *fallback* — used when the literal text search
//     returns nothing. Showing it as a peer chip next to "Search"
//     misled users into thinking they were equivalent modes. The
//     correct mental model: 「找不到才用 AI 搜索」.
//
// AI is now reachable only via the "Search with YsWords AI" button
// inside `_buildEmptyState`, which surfaces when `searchPerformed
// == true && _results.isEmpty`. Same `_askAi` handler — only the
// entry point changed.
//
// (The history of this strip lived through three iterations:
// v5 → 3 chips, v8 → 2 chips, v1.1.7 → removed.)

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
