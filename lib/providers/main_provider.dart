import 'dart:async';
import 'dart:collection' show LinkedHashMap;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/services/error_reporter.dart';
import 'package:yswords/services/fetch_books.dart' show bookNameToEnglish;
import 'package:yswords/services/fetch_verses.dart' show FetchVerses;
import 'package:yswords/services/realtime_db_sync_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-05-24 (v1.3.3): bundles the four scrollable_positioned_list
/// controllers that each `_ChapterPage` in the Bible reader PageView
/// needs to drive its own SPL.
///
/// Background: the PageView used to swap between a "preview" widget
/// and the "active SPL" widget at the same page index every time
/// the user swiped. The widget-tree replacement cost ~1 s of jank
/// even after the v1.2.99 cache + v1.3.1 prewarm fixes. v1.3.3
/// makes every page a real SPL with its own local controllers —
/// `AutomaticKeepAliveClientMixin` keeps adjacent pages alive across
/// swipes, so no rebuild happens on settle. The active page (the
/// one whose chapter matches `mainProvider.currentChapter`)
/// registers via `setActiveChapterControllers` so external scroll
/// commands (pendingJump from search / library / sermon refs,
/// scroll-to-top button, jumpToTop on chapter change) reach the
/// correct SPL through the existing `itemScrollController` getter.
class ChapterControllers {
  final ItemScrollController itemScrollController;
  final ScrollOffsetController scrollOffsetController;
  final ItemPositionsListener itemPositionsListener;
  final ScrollOffsetListener scrollOffsetListener;

  ChapterControllers({
    required this.itemScrollController,
    required this.scrollOffsetController,
    required this.itemPositionsListener,
    required this.scrollOffsetListener,
  });
}

// MainProvider class to extends ChangeNotifier for state management

class MainProvider extends ChangeNotifier {
  final String _storagePrefix;

  // 2026-06-15 (v1.3.80): last lastRead blob we synced. Content guard
  // mirroring AppSettings' userPrefs guard — saveCurrentState() is
  // called on navigation AND on rebuilds (e.g. PageView re-settling on
  // the same chapter, restoreState's boot-seed). Without this, each
  // call stamped lastReadTimestamp = now() + requestUpload even when
  // the position was unchanged, feeding the Syncing↔Synced flicker
  // loop. Skip the stamp + upload when the synced blob is identical.
  String? _lastSyncedReadBlob;

  MainProvider({String storagePrefix = ''}) : _storagePrefix = storagePrefix {
    // When the active profile changes, reload all profile-scoped
    // user data (highlights / notes / bookmarks) so the UI flips
    // atomically. Both panes in split-view share the same profile,
    // so each pane needs its own subscription.
    ProfileService.instance.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_onProfileChanged);
    super.dispose();
  }

  Future<void> _onProfileChanged() async {
    await _loadHighlights();
    await _loadNotes();
    await _loadBookmarks();
    onHighlightsMutated?.call();
    notifyListeners();
  }

  bool get isPrimary => _storagePrefix.isEmpty;

  // Index of a verse to temporarily highlight
  int? highlightIndex;

  /// Temporarily highlight the verse at [index]
  void setHighlightIndex(int index) {
    highlightIndex = index;
    notifyListeners();
  }

  /// Clear any temporary highlight
  void clearHighlightIndex() {
    highlightIndex = null;
    notifyListeners();
  }

  void setVerses(List<Verse> list) {
    verses = list;
    _selectedIds.clear();
    // 2026-05-08 (v1.0.1 perf): every change to `verses` invalidates
    // the per-verse caches we use to keep search + paragraph
    // grouping fast. Rebuilding them lazily on first access keeps
    // the version-switch path quick — the first interaction that
    // needs the cache pays for it.
    _searchKeysCache = null;
    _searchKeysCacheLength = -1;
    // 2026-05-10 (v1.2.16): no longer null out the paragraph-groups
    // cache here — it became a multi-slot LRU keyed by version +
    // book + chapter, so old entries from a different version stay
    // useful (don't accidentally clobber a pre-cached chapter the
    // user might come back to). LRU eviction handles memory cap.
    _bookOrderCache = null;
    // 2026-05-24 (v1.2.99): verses-by-chapter index. The PageView
    // chapter preview (lib/widgets/bible_reading_pane.dart's
    // _ChapterPreview) was doing `verses.where((v) => v.book == b &&
    // v.chapter == c)` on every page rebuild — O(31000) per page
    // and called for the 2-3 visible neighbour pages during every
    // swipe. With a swipe gesture running at 60 fps that's
    // ~5 million iterations / second. User reported persistent
    // "翻页还是有一点停顿" stutter even after the build-time sync
    // block fix. Invalidate this here so the next access rebuilds
    // it for the new verses list.
    _versesByChapterKey = null;
    // 2026-05-10 (v1.2.14): populate the per-version verse cache so
    // a future switch back to this version is truly instant
    // ("一瞬间", in the user's words). Skip empty lists — they
    // represent a failed load, not real data.
    if (list.isNotEmpty) _cacheVerses(currentVersion, list);
    notifyListeners();
  }

  // ── Per-version parsed-verse cache (v1.2.14) ────────────────────────
  //
  // Why this exists: switching Bible version triggers a synchronous
  // 5–10 MB `json.decode` that blocks the main thread for 1–3 s.
  // No isolate fix is available on Flutter web. But re-visiting a
  // version the user has ALREADY loaded this session doesn't need
  // to re-parse — the parsed `List<Verse>` is sittable in memory.
  // This LRU keeps the last `_kVersesCacheLimit` parsed lists so
  // jumping back to a recently-read version skips the parse step
  // entirely.
  //
  // Memory tax: ~6 MB per cached verse list × 4 = ~24 MB worst case.
  // Acceptable on every device that can run a Flutter web app.
  // 2026-05-10 (v1.2.16): bumped 6 → 15 to hold ALL 13 bundled
  // Bible versions plus the boot-time active one and one slot of
  // slack. v1.2.15 only pre-loaded 4 hand-picked versions; user
  // pushed back ("都要预加载啊在里面") so the post-boot pre-loader
  // now hits every version in `bibleVersions`. Memory cost: 13 ×
  // ~6 MB = ~78 MB for the parsed verse lists. Acceptable on every
  // device that runs Flutter web (1–2 GB heap budget).
  static const int _kVersesCacheLimit = 15;
  final LinkedHashMap<String, List<Verse>> _versesCache =
      LinkedHashMap<String, List<Verse>>();

  void _cacheVerses(String version, List<Verse> list) {
    // LRU touch: remove + re-insert so the most recently used key
    // sits at the end of the LinkedHashMap iteration order.
    _versesCache.remove(version);
    _versesCache[version] = list;
    while (_versesCache.length > _kVersesCacheLimit) {
      // Evict oldest (front of the LinkedHashMap).
      _versesCache.remove(_versesCache.keys.first);
    }
  }

  /// True if `version`'s parsed verse list is in the in-memory cache.
  /// Caller can short-circuit the FetchVerses pipeline when so.
  bool hasCachedVersion(String version) =>
      _versesCache.containsKey(version);

  /// 2026-05-24 (v1.3.23): test-only seeder. Skips the asset I/O
  /// that `preloadVersion()` does so unit tests can build a known
  /// LRU state in microseconds. NEVER call this from production
  /// code paths.
  @visibleForTesting
  void cacheVersionForTest(String version, List<Verse> list) {
    _cacheVerses(version, list);
  }

  /// 2026-05-24 (v1.3.22): drop all in-memory caches EXCEPT the
  /// currently-active version. Called from `_MainAppState
  /// .didHaveMemoryPressure` when iOS / Android signals the app
  /// to surrender memory. Total reclaim: up to ~70 MB of parsed
  /// verses + ~10 MB of paragraph groups.
  ///
  /// Re-populating after a pressure event happens lazily — the
  /// next version switch the user makes triggers a fresh
  /// FetchVerses (slower but recoverable). The current chapter
  /// stays on-screen because the active version's verses are
  /// referenced from `_verses`, not just the LRU.
  void dropCachesOnMemoryPressure() {
    final active = currentVersion;
    final keepActive = _versesCache.containsKey(active);
    final activeList = keepActive ? _versesCache[active] : null;
    _versesCache.clear();
    if (keepActive && activeList != null) {
      _versesCache[active] = activeList;
    }
    _paragraphGroupsCache.clear();
    // No notifyListeners — the on-screen rendering still uses
    // `_verses` which is unaffected; the dropped caches are only
    // for would-be future switches that haven't happened yet.
  }

  /// 2026-05-10 (v1.2.15): background pre-load — parse `version`
  /// silently and stash it in the LRU cache without touching
  /// `currentVersion` / `verses` / listeners. No-op if already
  /// cached or if the version is the one currently displayed.
  /// Called from main.dart after bootstrap settles, for each common
  /// alternative version, so a future user switch is a cache hit.
  Future<void> preloadVersion(String version) async {
    if (version == currentVersion) return;
    if (_versesCache.containsKey(version)) return;
    final list = await FetchVerses.loadVerseList(version);
    if (list == null) return;
    _cacheVerses(version, list);
    // No notifyListeners() — background work, nothing on-screen
    // depends on what's in the cache, only on the live `verses`
    // field. The user only finds out about the cache when they
    // actually switch to the pre-loaded version.
  }

  /// 2026-05-10 (v1.2.19): nuke the paragraph-groups cache for any
  /// key that doesn't belong to `version`. Used by `useCachedVersion`
  /// before swapping verse lists so a STALE `verseToItemMap` from
  /// a previous version's chapter (still resident in the 30-slot
  /// LRU because v1.2.16 stopped wiping the cache on version
  /// switch) can't surface during the next build's cache lookup
  /// and feed a wrong index map to the post-frame pendingJump
  /// drain. Symptom user reported as "by clicking verse it doesn't
  /// jump to right verse correctly" after v1.2.16 + v1.2.18.
  ///
  /// Strategy: keep ONLY entries already prefixed with the new
  /// version's key — those are guaranteed correct. Cross-version
  /// entries can be dropped; LRU will refill them on demand.
  void _evictParagraphCacheForVersionSwitch(String newVersion) {
    final keep = <String, dynamic>{};
    final prefix = '$newVersion|';
    for (final entry in _paragraphGroupsCache.entries) {
      if (entry.key.startsWith(prefix)) keep[entry.key] = entry.value;
    }
    _paragraphGroupsCache.clear();
    keep.forEach((k, v) {
      _paragraphGroupsCache[k] = v as ({
        List<List<Verse>> groups,
        Map<int, int> verseToItem,
        Map<int, int> itemToVerseIndex,
      });
    });
  }

  /// Swap the live `verses` list to the cached parsed list for
  /// `version`, mark `currentVersion`, and notify listeners. Skips
  /// the json.decode pipeline entirely. Returns false if there's no
  /// cached list (caller should fall back to FetchVerses.execute).
  bool useCachedVersion(String version) {
    final cached = _versesCache[version];
    if (cached == null) return false;
    // LRU touch on read.
    _versesCache.remove(version);
    _versesCache[version] = cached;
    // 2026-05-19 (v1.2.19): evict cross-version paragraph-cache
    // entries so a stale verseToItemMap can't slip through on the
    // next build's lookup. v1.2.16's "keep cross-version entries
    // for warm re-visits" optimisation was sound for paragraph
    // *groups* but the paired `verseToItemMap` is what drives
    // pendingJump scroll-targets and a stale one would silently
    // mis-aim. We only drop entries from OTHER versions; entries
    // from the new version (warm cache) stay.
    _evictParagraphCacheForVersionSwitch(version);
    // 2026-05-19 (v1.2.19): also drop any in-flight pending jump
    // queued before the swap. The verse index it points at was
    // computed against the OLD version's chapter; firing it
    // against the new version's reading-pane build is the most
    // direct way to land on a wrong verse.
    _pendingJumpChapterVerseIndex = null;
    currentVersion = version;
    verses = cached;
    _selectedIds.clear();
    // Same per-verse caches that setVerses invalidates — these are
    // derived from the verse list so they need a rebuild after the
    // swap.
    _searchKeysCache = null;
    _searchKeysCacheLength = -1;
    _bookOrderCache = null;
    // 2026-05-25 (v1.3.40): also invalidate the (book, chapter) →
    // verses index. Without this, switching FROM a partial-canon
    // version (e.g. LJK V2: Matthew only) TO a full-canon version
    // (NASB / CUVS-YHWH) left the index pointing at the old
    // version's data. `versesInChapter('Revelation', 2)` then
    // returned an empty list (the old version had no Revelation)
    // even though the new version did, and the page rendered the
    // "Switch to a full-canon version" empty-state — on a version
    // that IS full-canon. User report: header showed "Revelation 2
    // NASB" while body said "not available in current version".
    // `setVerses` already invalidates this index for the cold-load
    // path (line 116); this matches that behavior for the warm-
    // cache path.
    _versesByChapterKey = null;
    notifyListeners();
    return true;
  }

  void setBooks(List<Book> list) {
    // Deduplicate by title while preserving first occurrence
    final seen = <String>{};
    books = list.where((b) => seen.add(b.title)).toList();
    // Book list changed → bookOrder lookup map + chapter pager
    // index are stale.
    _bookOrderCache = null;
    _chapterList = null;
    notifyListeners();
  }

  // ── Search-key cache (v1.0.1 perf) ────────────────────────────────
  // Parallel array to `verses`: `_searchKeysCache[i]` is the
  // pre-sanitized lowercase no-space form of `verses[i].text`. The
  // search loop in `search_page.dart` used to call
  // `sanitizeForSearch(...).replaceAll(' ', '').toLowerCase()` for
  // every verse on every keystroke (~31,090 regex chains per stroke
  // for a whole-Bible corpus); caching it once per `setVerses` cuts
  // that to a single-pass O(n) the first time the user searches.
  List<String>? _searchKeysCache;
  int _searchKeysCacheLength = -1;

  /// Returns the parallel `List<String>` of normalized, lowercased,
  /// whitespace-stripped verse text — the form a substring search
  /// runs against. Built lazily; reused across keystrokes.
  List<String> get searchKeys {
    if (_searchKeysCache != null &&
        _searchKeysCacheLength == verses.length) {
      return _searchKeysCache!;
    }
    final out = List<String>.filled(verses.length, '', growable: false);
    for (int i = 0; i < verses.length; i++) {
      out[i] = sanitizeForSearch(verses[i].text)
          .replaceAll(' ', '')
          .toLowerCase();
    }
    _searchKeysCache = out;
    _searchKeysCacheLength = verses.length;
    return out;
  }

  // ── Paragraph-grouping cache (v1.0.1 perf, refactored multi-slot
  //    LRU in v1.2.16) ────────────────────────
  // The reading pane re-groups verses into paragraph blocks +
  // rebuilds verseToItemMap on every Consumer rebuild. Originally
  // (v1.0.1) a single-slot cache: switching version OR chapter
  // invalidated and forced recompute. v1.2.16 extends to a 30-
  // entry LRU keyed by (version | book | chapter | paragraphMode |
  // versesLength). Benefit: jumping back to a recently-viewed
  // (version, chapter) pair skips the recompute (~50 ms saved per
  // switch). Especially useful with v1.2.15+'s background pre-load
  // since the user is now likely to flip between many cached
  // versions on the same chapter.
  // 2026-05-24 (v1.2.99): bumped 30 → 300. v1.2.96's N-page PageView
  // means a user swiping a few chapters in either direction
  // immediately needs the paragraph grouping for prev / current /
  // next, plus pre-warmed neighbours. Cache miss = ~50 ms recompute
  // (per the original comment) which the user feels as stutter at
  // the moment the SPL builds on the new page. 300 entries × small
  // record per chapter ≈ <5 MB RAM — well within budget.
  static const int _kParagraphCacheLimit = 300;
  final LinkedHashMap<
      String,
      ({
        List<List<Verse>> groups,
        Map<int, int> verseToItem,
        Map<int, int> itemToVerseIndex,
      })> _paragraphGroupsCache = LinkedHashMap();

  // 2026-05-24 (v1.2.99): verses-by-chapter index. Built lazily on
  // first access and invalidated whenever `verses` changes
  // (setVerses clears `_versesByChapterKey`). Key format matches
  // `chapterList` entries: "<book>|<chapter>". Each value is the
  // pre-sorted verse list for that chapter — same shape the SPL
  // builder uses.
  Map<String, List<Verse>>? _versesByChapterKey;

  /// Fast O(1) lookup of verses in a given (book, chapter). Replaces
  /// the O(n) `verses.where(...)` filter that was hot-pathing the
  /// PageView preview build. Returns an empty list if the chapter
  /// doesn't exist in the current version.
  List<Verse> versesInChapter(String book, int chapter) {
    final cache = _versesByChapterKey ??= _buildVersesByChapterIndex();
    return cache['$book|$chapter'] ?? const <Verse>[];
  }

  Map<String, List<Verse>> _buildVersesByChapterIndex() {
    final out = <String, List<Verse>>{};
    for (final v in verses) {
      final key = '${v.book}|${v.chapter}';
      out.putIfAbsent(key, () => <Verse>[]).add(v);
    }
    // Sort each chapter's verses by verse number once, up front, so
    // callers don't have to.
    for (final list in out.values) {
      list.sort((a, b) => a.verse.compareTo(b.verse));
    }
    return out;
  }

  /// Cache key encodes every input that affects paragraph grouping
  /// output. Includes `currentVersion` (added v1.2.16) so two
  /// versions with the same per-chapter verse count don't collide.
  String _paragraphCacheKey({
    required String? book,
    required int? chapter,
    required bool paragraphMode,
    required int versesLength,
  }) =>
      '$currentVersion|${book ?? ''}|${chapter ?? ''}|$paragraphMode|$versesLength';

  /// Look up cached paragraph grouping for the given inputs, or
  /// `null` on cache miss.
  ({
    List<List<Verse>> groups,
    Map<int, int> verseToItem,
    Map<int, int> itemToVerseIndex,
  })? cachedParagraphGrouping({
    required String? book,
    required int? chapter,
    required bool paragraphMode,
    required int versesLength,
  }) {
    final key = _paragraphCacheKey(
      book: book,
      chapter: chapter,
      paragraphMode: paragraphMode,
      versesLength: versesLength,
    );
    final cached = _paragraphGroupsCache[key];
    if (cached != null) {
      // LRU touch: re-insert moves to most-recently-used end.
      _paragraphGroupsCache.remove(key);
      _paragraphGroupsCache[key] = cached;
    }
    return cached;
  }

  /// Store paragraph grouping output for the given inputs. Evicts
  /// the oldest entry if the LRU is at capacity.
  void setCachedParagraphGrouping({
    required String? book,
    required int? chapter,
    required bool paragraphMode,
    required int versesLength,
    required List<List<Verse>> groups,
    required Map<int, int> verseToItem,
    required Map<int, int> itemToVerseIndex,
  }) {
    final key = _paragraphCacheKey(
      book: book,
      chapter: chapter,
      paragraphMode: paragraphMode,
      versesLength: versesLength,
    );
    _paragraphGroupsCache.remove(key);
    _paragraphGroupsCache[key] = (
      groups: groups,
      verseToItem: verseToItem,
      itemToVerseIndex: itemToVerseIndex,
    );
    while (_paragraphGroupsCache.length > _kParagraphCacheLimit) {
      _paragraphGroupsCache.remove(_paragraphGroupsCache.keys.first);
    }
  }

  // ── Book-order cache (v1.0.1 perf) ───────────────────────────────
  // Search sorts results by canonical book order. The map used to
  // be rebuilt from `mp.books` on every keystroke; cached now and
  // invalidated when `setBooks` runs.
  Map<String, int>? _bookOrderCache;
  Map<String, int> get bookOrder {
    final cached = _bookOrderCache;
    if (cached != null) return cached;
    final m = <String, int>{
      for (var i = 0; i < books.length; i++) books[i].title: i,
    };
    _bookOrderCache = m;
    return m;
  }

  // 2026-05-24 (v1.3.3): per-chapter scroll controllers. Each
  // `_ChapterPage` in the PageView (lib/widgets/bible_reading_pane.dart)
  // owns its own ChapterControllers in State; the active page
  // registers via `setActiveChapterControllers` so external code
  // (jumper / pendingJump / scroll-to-top) reaching for
  // `mp.itemScrollController` is routed to the right SPL.
  //
  // The fallback instances below are never attached to any SPL —
  // they exist so external callers can safely read
  // `mp.itemScrollController` (etc.) before any page has had a
  // chance to register. The `isAttached` guard those callers
  // already perform protects them.
  final ItemScrollController _fallbackItemScrollController =
      ItemScrollController();
  final ScrollOffsetController _fallbackScrollOffsetController =
      ScrollOffsetController();
  final ItemPositionsListener _fallbackItemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetListener _fallbackScrollOffsetListener =
      ScrollOffsetListener.create();

  ChapterControllers? _activeChapterControllers;

  /// The active chapter page's controllers (or null if none has
  /// registered yet). Used by BibleReadingPane to detect when the
  /// active page changes so it can re-attach the auto-hide chrome
  /// scroll listener to the new page's `itemPositionsListener`.
  ChapterControllers? get activeChapterControllers =>
      _activeChapterControllers;

  /// Called by `_ChapterPageState` when it becomes the active
  /// (current-chapter) page. Subsequent reads of
  /// `itemScrollController` / `itemPositionsListener` / etc. return
  /// the controllers passed here. Fires `notifyListeners` so
  /// observers (auto-hide chrome) can re-attach to the new
  /// listener instance.
  void setActiveChapterControllers(ChapterControllers? c) {
    if (identical(_activeChapterControllers, c)) return;
    _activeChapterControllers = c;
    notifyListeners();
  }

  ItemScrollController get itemScrollController =>
      _activeChapterControllers?.itemScrollController ??
      _fallbackItemScrollController;
  ScrollOffsetController get scrollOffsetController =>
      _activeChapterControllers?.scrollOffsetController ??
      _fallbackScrollOffsetController;
  ItemPositionsListener get itemPositionsListener =>
      _activeChapterControllers?.itemPositionsListener ??
      _fallbackItemPositionsListener;
  ScrollOffsetListener get scrollOffsetListener =>
      _activeChapterControllers?.scrollOffsetListener ??
      _fallbackScrollOffsetListener;

  // Variables to store the current chapter and book
  int? currentChapter;
  String? currentBook;
  String currentVersion = 'cuvs-yhwh'; // default version

  // Error surfaced from the initial load (e.g. asset read/decode failure).
  // When non-null, the loading screen shows a retry UI.
  String? loadError;

  void setLoadError(String? error) {
    if (loadError == error) return;
    loadError = error;
    notifyListeners();
  }

  // 2026-07-21: true for the entire span of `_MainAppState._bootstrap()`
  // (main.dart), from app launch until that one-shot startup sequence
  // finishes — success OR failure. Defaults true because bootstrap is
  // always running at app start.
  //
  // Exists to fix a false-positive "Failed to load" flash: `_bootstrap()`
  // awaits `FetchVerses.execute()`, which legitimately takes anywhere up
  // to ~60 s on a slow connection (3 escalating-timeout attempts). But a
  // SEPARATE 4 s splash watchdog in `_MainAppState` unconditionally flips
  // `_loading = false` regardless of whether bootstrap has finished, so
  // `LoadingPage` gets mounted with `mainProvider.verses` still empty
  // whenever the real fetch takes longer than 4 s — a normal outcome on
  // a cold CDN edge or a slow network, not a failure. `LoadingPage`
  // previously treated `verses.isEmpty` alone as proof of failure and
  // showed the alarming error scaffold immediately, which then quietly
  // fixed itself once the still-running fetch finally resolved in the
  // background. Reported repeatedly as "always shows Failed to load,
  // then works after waiting" — this flag lets LoadingPage tell "still
  // legitimately loading" apart from "genuinely failed".
  bool bootInFlight = true;

  void setBootInFlight(bool value) {
    if (bootInFlight == value) return;
    bootInFlight = value;
    notifyListeners();
  }

  // 2026-05-10 (v1.2.10): in-flight load progress, used by the splash
  // page to show "Loading verses…" / "Retrying… (2/3)" so users
  // don't think the app is frozen during the (sometimes-slow) first
  // asset fetch. Both fields are 0 when nothing's loading.
  int loadAttempt = 0;
  int loadMaxAttempts = 0;

  /// Called by FetchVerses.execute()'s onAttempt callback for every
  /// retry. `attempt` is 1-indexed; `max` is the max attempts the
  /// caller will make. Set both to 0 when the load completes (success
  /// or final failure) to clear the splash subtitle.
  void setLoadProgress(int attempt, int max) {
    if (loadAttempt == attempt && loadMaxAttempts == max) return;
    loadAttempt = attempt;
    loadMaxAttempts = max;
    notifyListeners();
  }

  /// 2026-05-10 (v1.2.18): in-flight count for the eager pre-load
  /// of all 13 Bible versions during boot. The splash paints a
  /// "Loading versions: 5/13" subtitle when `versionPreloadTotal > 0`
  /// — clearer than reusing `loadAttempt` (which means retry count
  /// in the verse-fetch context). Cleared back to 0/0 when pre-
  /// load completes so the splash subtitle disappears before the
  /// `_loading = false` setState.
  int versionPreloadCount = 0;
  int versionPreloadTotal = 0;
  void setVersionPreloadProgress(int count, int total) {
    if (versionPreloadCount == count && versionPreloadTotal == total) return;
    versionPreloadCount = count;
    versionPreloadTotal = total;
    notifyListeners();
  }

  /// 2026-05-10 (v1.2.13): true while a version-switch is in flight
  /// (set by `bible_reading_pane.dart::onVersionSelected`). The
  /// reading pane paints an opaque "Loading [version]…" overlay on
  /// top of the chapter content while this is set, so the user
  /// doesn't see a frozen 1–3 s of the OLD version's verses while
  /// `json.decode` chews through 5–10 MB of the new version's JSON.
  /// Distinct from `loadAttempt` which is for the boot splash.
  bool versionSwitching = false;
  String versionSwitchingTo = '';

  void setVersionSwitching(bool v, {String to = ''}) {
    if (versionSwitching == v && versionSwitchingTo == to) return;
    versionSwitching = v;
    versionSwitchingTo = to;
    notifyListeners();
  }

  void setVersion(String version) {
    currentVersion = version;
    if (isPrimary) saveCurrentState();
    notifyListeners();
  }

  List<Verse> verses = [];
  // Set to store selected verse IDs
  final Set<String> _selectedIds = {};

  // Map to store verse highlight colors (verse ID → ARGB int)
  Map<String, int> _highlights = {};

  // Map of verse ID → user note text. Notes are persisted in
  // SharedPreferences globally (no prefix) the same way highlights
  // are, so split-view panes share them.
  Map<String, String> _verseNotes = {};

  // 2026-05-24 (v1.2.91): verse ID → epoch millis of the most
  // recent setVerseNote() write. Used by Library → Notes to sort
  // by "recently updated" / "oldest first" in addition to the
  // canonical Bible order. Persisted alongside `_verseNotes` (own
  // SharedPreferences key + RTDB sync key) so existing clients
  // upgrade gracefully — any note without a recorded timestamp is
  // stamped with the current time on first load after upgrade.
  Map<String, int> _verseNoteTimestamps = {};

  // 2026-05-24 (v1.2.91): optional user-supplied title for a note.
  // verseId → title. Empty / missing = no title (the Library tile
  // falls back to the verse reference as the header). Stored in
  // its own SharedPreferences key + RTDB sync key so older clients
  // that don't render titles still work fine.
  //
  // For multi-verse passage notes, every verse in the selection
  // gets the same title written to it (mirroring how the body is
  // written) — `_groupContiguousNotes` merges adjacent verses by
  // body equality, and titles are guaranteed equal if bodies are
  // equal because they were written together.
  Map<String, String> _verseNoteTitles = {};

  // Set of bookmarked verse IDs. Same global persistence as
  // highlights and notes.
  Set<String> _bookmarks = {};

  // List of Store Verse Objects
  List<Verse> get selectedVerses =>
      verses.where((v) => _selectedIds.contains(v.id)).toList();
  Set<String> get selectedIds => _selectedIds;

  bool isSelected(Verse v) => _selectedIds.contains(v.id);

  /// Read-only snapshot for UI rendering (e.g. HighlightsSheet).
  Map<String, int> get highlights => Map.unmodifiable(_highlights);

  /// Called after any local highlight mutation (add / remove).
  /// home_page.dart wires this up to sync the other split-view pane.
  VoidCallback? onHighlightsMutated;

  bool isVerseHighlighted(Verse v) => _highlights.containsKey(v.id);

  Color? getHighlightColor(Verse v) {
    final argb = _highlights[v.id];
    if (argb == null) return null;
    return Color(argb);
  }

  void setHighlight({required Verse verse, required int color}) {
    _highlights[verse.id] = color;
    _saveHighlights();
    notifyListeners();
    onHighlightsMutated?.call();
  }

  void removeHighlight({required Verse verse}) {
    _highlights.remove(verse.id);
    _saveHighlights();
    notifyListeners();
    onHighlightsMutated?.call();
  }

  void setHighlightsForVerses({required List<Verse> verses, required int color}) {
    for (final v in verses) {
      _highlights[v.id] = color;
    }
    _saveHighlights();
    notifyListeners();
    onHighlightsMutated?.call();
  }

  void removeHighlightsForVerses({required List<Verse> verses}) {
    for (final v in verses) {
      _highlights.remove(v.id);
    }
    _saveHighlights();
    notifyListeners();
    onHighlightsMutated?.call();
  }

  /// Overwrite the in-memory highlights with [data] and notify listeners.
  /// Does NOT save to SharedPreferences and does NOT fire [onHighlightsMutated]
  /// — this is used for cross-pane sync to avoid infinite-loop callbacks.
  void syncHighlights(Map<String, int> data) {
    _highlights = Map.from(data);
    notifyListeners();
  }

  /// Reload highlights from SharedPreferences and notify listeners.
  /// Called when the split-view secondary pane is first created.
  Future<void> reloadHighlights() async {
    await _loadHighlights();
    notifyListeners();
  }

  // Fire-and-forget local save. Errors from SharedPreferences are
  // exceedingly rare (quota / corrupt platform store) but we still
  // surface them via debugPrint so a regression is visible in the
  // browser console rather than silently swallowed.
  void _saveHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Profile-scoped — different signed-in users keep their own
      // annotations even when they share the same browser. Both
      // split-view panes share the same profile so they still see
      // the same set.
      await prefs.setString(
          ProfileService.instance.scopedKey('highlights'),
          jsonEncode(_highlights));
      RealtimeDbSyncService.instance.requestUpload();
    } catch (e, st) {
      debugPrint('MainProvider._saveHighlights failed: $e\n$st');
      // v1.3.22: silent debugPrint went nowhere in prod. Highlight
      // persistence is high-stakes — the user thinks their colour
      // is saved but the write actually failed.
      ErrorReporter.report(e, st, source: 'saveHighlights');
    }
  }

  // Static guard for the legacy-key migration in _loadHighlights.
  // Without this, every cloud-sync pull re-runs migration → re-saves
  // → re-triggers a cloud upload → next snapshot pull re-runs
  // migration → infinite syncing/synced flash. We only ever need to
  // migrate once per app session; after the first save the cloud
  // copy gets normalized and subsequent loads are no-ops.
  static bool _didMigrateHighlightKeys = false;

  Future<void> _loadHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    // Reload from the active profile's namespace. Reset the in-memory
    // map first so switching from a profile with highlights to one
    // without doesn't leave stale entries.
    _highlights = {};
    final json =
        prefs.getString(ProfileService.instance.scopedKey('highlights'));
    if (json == null) return;
    final decoded = jsonDecode(json) as Map<String, dynamic>;

    // Migrate legacy keys: highlights saved before the cross-version fix
    // used the localized book name in the ID (e.g. "历代志上-3-19" or
    // "創世記-1-1"). Re-key those to the canonical English form so the
    // sheet shows a single deduplicated list. If multiple legacy keys
    // collide with the same English key, the last one wins — fine for a
    // user-color choice (and any survivor is still correct).
    final out = <String, int>{};
    var migrated = false;
    for (final entry in decoded.entries) {
      final normalized = _normalizeHighlightKey(entry.key);
      if (normalized != entry.key) migrated = true;
      out[normalized] = entry.value as int;
    }
    _highlights = out;
    if (migrated && isPrimary && !_didMigrateHighlightKeys) {
      _didMigrateHighlightKeys = true;
      _saveHighlights();
    }
  }

  // ── Verse notes ─────────────────────────────────────────────────

  /// Read-only snapshot for UI rendering (e.g. notes-list page).
  Map<String, String> get verseNotes => Map.unmodifiable(_verseNotes);

  /// 2026-05-24 (v1.2.91): read-only snapshot of the timestamp map
  /// for sort-by-time in the Library view.
  Map<String, int> get verseNoteTimestamps =>
      Map.unmodifiable(_verseNoteTimestamps);

  /// Returns the epoch-ms when the note for [verseId] was last
  /// updated, or null if no note exists (or for legacy notes that
  /// pre-date timestamp tracking and somehow escaped the migration
  /// pass — defensive only; the loader stamps everything).
  int? getVerseNoteTimestamp(String verseId) => _verseNoteTimestamps[verseId];

  /// 2026-05-24 (v1.2.91): read-only snapshot of the titles map.
  Map<String, String> get verseNoteTitles =>
      Map.unmodifiable(_verseNoteTitles);

  /// Returns the user-supplied title for the note on [verseId], or
  /// null when no title is set (Library tile falls back to the
  /// verse reference for the header in that case).
  String? getVerseNoteTitle(String verseId) {
    final t = _verseNoteTitles[verseId];
    if (t == null || t.isEmpty) return null;
    return t;
  }

  /// Returns true if the verse has any note text attached.
  bool isVerseNoted(Verse v) => (_verseNotes[v.id]?.isNotEmpty ?? false);

  /// Returns the note text for [v], or null if no note exists.
  String? getVerseNote(Verse v) => _verseNotes[v.id];

  /// Set or replace the note for [verse]. Pass an empty string in
  /// [text] to remove the note. [title] is optional — empty title
  /// drops any previously-set title for this verse. Persists to
  /// SharedPreferences and notifies.
  ///
  /// 2026-05-24 (v1.2.91): added optional [title] parameter. The
  /// note editor passes both title + body in one call; the body
  /// being empty still removes the note (with its title and
  /// timestamp). Body non-empty + title empty keeps the body and
  /// clears the title (a one-touch way to remove a no-longer-useful
  /// title without losing the note itself).
  void setVerseNote({
    required Verse verse,
    required String text,
    String? title,
  }) {
    final trimmed = text.trim();
    final trimmedTitle = (title ?? '').trim();
    if (trimmed.isEmpty) {
      _verseNotes.remove(verse.id);
      _verseNoteTimestamps.remove(verse.id);
      _verseNoteTitles.remove(verse.id);
    } else {
      _verseNotes[verse.id] = trimmed;
      // Every save bumps the timestamp — sort-by-recent shows the
      // most recently edited note at the top. If users later want
      // a separate "created" vs "updated" distinction we'd add a
      // second map; for now WeDevote-style "latest activity" sort
      // is the most useful single signal.
      _verseNoteTimestamps[verse.id] =
          DateTime.now().millisecondsSinceEpoch;
      if (trimmedTitle.isEmpty) {
        _verseNoteTitles.remove(verse.id);
      } else {
        _verseNoteTitles[verse.id] = trimmedTitle;
      }
    }
    _saveNotes();
    notifyListeners();
  }

  /// Same as [setVerseNote] but for an empty string — convenience.
  void clearVerseNote({required Verse verse}) {
    if (_verseNotes.remove(verse.id) != null) {
      _verseNoteTimestamps.remove(verse.id);
      _verseNoteTitles.remove(verse.id);
      _saveNotes();
      notifyListeners();
    }
  }

  // ── Bookmarks ───────────────────────────────────────────────────

  /// Read-only snapshot of bookmarked verse IDs.
  Set<String> get bookmarks => Set.unmodifiable(_bookmarks);

  bool isBookmarked(Verse v) => _bookmarks.contains(v.id);

  void toggleBookmark({required Verse verse}) {
    if (_bookmarks.contains(verse.id)) {
      _bookmarks.remove(verse.id);
    } else {
      _bookmarks.add(verse.id);
    }
    _saveBookmarks();
    notifyListeners();
  }

  void _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ProfileService.instance.scopedKey('verseNotes'),
          jsonEncode(_verseNotes));
      // 2026-05-24 (v1.2.91): persist the timestamp sidecar with the
      // notes. Saved as a JSON {verseId: epochMs} map so users on
      // older builds (which don't read this key) are unaffected;
      // they'll keep canonical sort and never see the field.
      await prefs.setString(
          ProfileService.instance.scopedKey('verseNoteTimestamps'),
          jsonEncode(_verseNoteTimestamps));
      // 2026-05-24 (v1.2.91): persist the optional titles sidecar.
      // Empty map → remove the key entirely so users who never
      // typed a title don't carry a phantom `{}` entry around.
      if (_verseNoteTitles.isEmpty) {
        await prefs
            .remove(ProfileService.instance.scopedKey('verseNoteTitles'));
      } else {
        await prefs.setString(
            ProfileService.instance.scopedKey('verseNoteTitles'),
            jsonEncode(_verseNoteTitles));
      }
      RealtimeDbSyncService.instance.requestUpload();
    } catch (e, st) {
      debugPrint('MainProvider._saveNotes failed: $e\n$st');
      // v1.3.22: same rationale as saveHighlights — note loss is
      // user-data loss, not a tolerable silent failure.
      ErrorReporter.report(e, st, source: 'saveNotes');
    }
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    _verseNotes = {};
    _verseNoteTimestamps = {};
    _verseNoteTitles = {};
    final json =
        prefs.getString(ProfileService.instance.scopedKey('verseNotes'));
    if (json == null) return;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    _verseNotes = {
      for (final e in decoded.entries) e.key: e.value as String,
    };

    // 2026-05-24 (v1.2.91): load the timestamp sidecar.
    //
    // 2026-05-25 (v1.3.39): unknown timestamps now stamped as 0 (the
    // "unknown time" sentinel), NOT `DateTime.now()`. The old `now`
    // fallback lied to the user: after a fresh device sync OR an
    // upgrade from <v1.2.91 OR any RTDB round-trip that dropped the
    // sidecar, every untyped-stamp note rendered as "刚刚 / just
    // now" — a note written months ago suddenly showed as just
    // edited. User report: "the notes created or edit time is not
    // accurate". The honest fix is to mark the timestamp as unknown
    // and let the library page skip the "Edited X" label entirely
    // for those notes. Sort-by-recent treats 0 as oldest (it falls
    // through to canonical order at the bottom), matching what the
    // user expects: "I don't know when this was edited, so it can't
    // claim to be recent".
    final tsJson = prefs.getString(
        ProfileService.instance.scopedKey('verseNoteTimestamps'));
    if (tsJson != null) {
      try {
        final tsDecoded = jsonDecode(tsJson) as Map<String, dynamic>;
        // num covers both int and double — RTDB occasionally
        // round-trips ints through JS as doubles even when the
        // value is whole, so coerce defensively.
        _verseNoteTimestamps = {
          for (final e in tsDecoded.entries)
            if (e.value is num) e.key: (e.value as num).toInt(),
        };
      } catch (_) {/* corrupt → fall through to migration */}
    }
    var migrated = false;
    for (final id in _verseNotes.keys) {
      if (!_verseNoteTimestamps.containsKey(id)) {
        // 0 sentinel — see v1.3.39 note above for the full rationale.
        _verseNoteTimestamps[id] = 0;
        migrated = true;
      }
    }
    // Drop orphaned timestamps (note was deleted but stamp lingers).
    final toDrop = <String>[];
    for (final id in _verseNoteTimestamps.keys) {
      if (!_verseNotes.containsKey(id)) toDrop.add(id);
    }
    for (final id in toDrop) {
      _verseNoteTimestamps.remove(id);
    }
    if (migrated || toDrop.isNotEmpty) {
      // Persist the migration result so we don't re-migrate every
      // launch. Fire-and-forget — errors here are non-fatal.
      // ignore: unawaited_futures
      prefs.setString(
          ProfileService.instance.scopedKey('verseNoteTimestamps'),
          jsonEncode(_verseNoteTimestamps));
    }

    // 2026-05-24 (v1.2.91): load the optional titles sidecar.
    // Missing key → no titles (users who never typed a title or
    // upgraded from <v1.2.91); corrupt JSON → log + treat as
    // empty. Drop orphan titles (title for a note that was
    // deleted from another device before this device synced).
    final titlesJson =
        prefs.getString(ProfileService.instance.scopedKey('verseNoteTitles'));
    if (titlesJson != null) {
      try {
        final tDecoded = jsonDecode(titlesJson) as Map<String, dynamic>;
        _verseNoteTitles = {
          for (final e in tDecoded.entries)
            if (e.value is String && (e.value as String).isNotEmpty)
              e.key: e.value as String,
        };
      } catch (_) {/* corrupt → empty */}
    }
    var titlesChanged = false;
    final titleOrphans = <String>[];
    for (final id in _verseNoteTitles.keys) {
      if (!_verseNotes.containsKey(id)) titleOrphans.add(id);
    }
    for (final id in titleOrphans) {
      _verseNoteTitles.remove(id);
      titlesChanged = true;
    }
    if (titlesChanged) {
      // ignore: unawaited_futures
      if (_verseNoteTitles.isEmpty) {
        prefs.remove(ProfileService.instance.scopedKey('verseNoteTitles'));
      } else {
        prefs.setString(
            ProfileService.instance.scopedKey('verseNoteTitles'),
            jsonEncode(_verseNoteTitles));
      }
    }
  }

  void _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(ProfileService.instance.scopedKey('bookmarks'),
          _bookmarks.toList());
      RealtimeDbSyncService.instance.requestUpload();
    } catch (e, st) {
      debugPrint('MainProvider._saveBookmarks failed: $e\n$st');
      // v1.3.22: bookmark loss is user-data loss.
      ErrorReporter.report(e, st, source: 'saveBookmarks');
    }
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    _bookmarks = {};
    final list =
        prefs.getStringList(ProfileService.instance.scopedKey('bookmarks'));
    if (list == null) return;
    _bookmarks = list.toSet();
  }

  /// Maps a highlight ID like "历代志上-3-19" → "1 Chronicles-3-19".
  /// Splits from the right so books with hyphens-or-spaces still parse.
  static String _normalizeHighlightKey(String key) {
    final lastDash = key.lastIndexOf('-');
    if (lastDash < 0) return key;
    final verseLabel = key.substring(lastDash + 1);
    final rest = key.substring(0, lastDash);
    final prevDash = rest.lastIndexOf('-');
    if (prevDash < 0) return key;
    final chapter = rest.substring(prevDash + 1);
    final book = rest.substring(0, prevDash);
    final en = bookNameToEnglish[book] ?? book;
    return '$en-$chapter-$verseLabel';
  }

  // Method to set the current book and chapter, persist state, and notify listeners
  void setCurrentChapter({required String book, required int chapter}) {
    currentBook = book;
    currentChapter = chapter;
    if (isPrimary) saveCurrentState();
    notifyListeners();
  }

  // Method to add a verse to the list and notify listeners
  void addVerse({required Verse verse}) {
    verses.add(verse);
    notifyListeners();
  }

  // List to store Book Objects
  List<Book> books = [];

  // 2026-05-24 (v1.2.92): flat list of (book, chapter) tuples for
  // the currently-loaded version. Cached + invalidated whenever
  // `books` changes via setBooks() / version switch. Drives the
  // PageView chapter pager in BibleReadingPane — gives the
  // WeChat / 微读圣经 / WeDevote-style "swipe to next/prev chapter"
  // feel where the adjacent chapter is visible during the drag.
  List<({String book, int chapter})>? _chapterList;

  /// Returns the flat (book, chapter) list for the active version
  /// in canonical Bible order. Lazily computed from `books`.
  List<({String book, int chapter})> get chapterList {
    final cached = _chapterList;
    if (cached != null) return cached;
    final out = <({String book, int chapter})>[];
    for (final b in books) {
      for (final c in b.chapters) {
        out.add((book: b.title, chapter: c.title));
      }
    }
    _chapterList = out;
    return out;
  }

  /// Returns the index of (book, chapter) in [chapterList], or
  /// `null` if not found. O(n) — could be sped up with a Map cache
  /// if it shows up in profiles, but only fires on chapter
  /// transitions which are user-driven so the linear scan is fine.
  int? findChapterIndex(String? book, int? chapter) {
    if (book == null || chapter == null) return null;
    final list = chapterList;
    for (int i = 0; i < list.length; i++) {
      if (list[i].book == book && list[i].chapter == chapter) return i;
    }
    return null;
  }

  // Method to add a book to the list and notify listeners
  void addBook({required Book book}) {
    // Avoid duplicate entries; replace existing by title
    final idx = books.indexWhere((b) => b.title == book.title);
    if (idx >= 0) {
      books[idx] = book;
    } else {
      books.add(book);
    }
    notifyListeners();
  }

  // Variable to store the current verse
  Verse? currentVerse;
  // Method to update the current verse and notify listeners
  void updateCurrentVerse({required Verse verse}) {
    currentVerse = verse;
    notifyListeners();
  }

  // Verse-to-item index map for paragraph mode grouping
  Map<int, int> _verseToItemMap = {};

  void setVerseToItemMap(Map<int, int> map) {
    _verseToItemMap = map;
    // Intentionally no notifyListeners() — called during build
  }

  /// Pending cross-page jump request. Set by news/evidence/cross-ref
  /// detail pages BEFORE navigating to the reader; consumed by
  /// `BibleReadingPane` once the `ScrollablePositionedList`
  /// controller is attached AND `verseToItemMap` has been built for
  /// the requested book + chapter. Lets the source page hand off
  /// the navigation without guessing how long the build will take —
  /// pre-fix the 320ms delay was too short for cold-start /
  /// version-switch paths and the jump silently no-op'd.
  ///
  /// Cleared by `consumePendingJump` after the reader executes the
  /// jump + highlight, so subsequent unrelated chapter switches
  /// don't accidentally re-trigger the jump.
  int? _pendingJumpChapterVerseIndex;
  int get pendingJumpVerseIndex => _pendingJumpChapterVerseIndex ?? -1;
  bool get hasPendingJump => _pendingJumpChapterVerseIndex != null;

  void setPendingJump({required int chapterVerseIndex}) {
    _pendingJumpChapterVerseIndex = chapterVerseIndex;
    // Always notify, even if other state didn't change — round 52
    // bug: when the user tapped a note for a verse in the *current*
    // chapter, [prepareJumpToVerse] called setCurrentChapter (which
    // notifies, but for an unchanged chapter), updateCurrentVerse
    // (notifies for currentVerse change, fine), then setPendingJump
    // (NO notify). The reader's pendingJump consumer in
    // bible_reading_pane.dart only runs when the Consumer rebuilds,
    // and there was nothing that *forced* a rebuild after the
    // pendingJump was set. The user landed at the top of the chapter
    // because the post-frame callback was never scheduled. Notifying
    // here closes that race — any caller that sets a pending jump
    // gets a guaranteed reader rebuild, regardless of whether the
    // chapter actually changed.
    notifyListeners();
  }

  /// Returns the pending verse index and clears it. Reader calls
  /// this once it's actually performed the jump.
  int? consumePendingJump() {
    final v = _pendingJumpChapterVerseIndex;
    _pendingJumpChapterVerseIndex = null;
    return v;
  }

  // Method to scroll to a specific index in the list and notify listeners
  void scrollToIndex({required int index}) {
    final mapped = _verseToItemMap[index] ?? index;
    if (itemScrollController.isAttached) {
      itemScrollController.scrollTo(
        index: mapped,
        duration: const Duration(milliseconds: 800),
      );
    }
    notifyListeners();
  }

  void jumpToIndex({required int index}) {
    final mapped = _verseToItemMap[index] ?? index;
    if (itemScrollController.isAttached) {
      itemScrollController.jumpTo(index: mapped);
    }
  }

  /// Like [jumpToIndex] but uses `scrollTo` with a configurable
  /// duration. Round 56: fixes a "first tap from Library goes to
  /// top of chapter" bug — `jumpTo` silently no-ops when the
  /// `ScrollablePositionedList` is `isAttached` but hasn't yet
  /// finished measuring its items (true on a fresh HomePage
  /// mount). `scrollTo` with a tiny duration handles that case
  /// gracefully and lands on the right item.
  ///
  /// 2026-05-17 (v1.2.49): added [alignment] so the search /
  /// reference-jump path can land the target item ~25% from the
  /// top of the viewport instead of glued to the edge. With
  /// alignment 0.0 (the old default) a paragraph-mode jump made
  /// the user hunt for the highlighted verse inside the paragraph
  /// because the paragraph started right at the viewport top.
  /// alignment 0.25 keeps the target comfortably in reading
  /// position whether the SPL item is a single verse or a multi-
  /// verse paragraph.
  void scrollToIndexAnimated({
    required int index,
    Duration duration = const Duration(milliseconds: 1),
    double alignment = 0.0,
  }) {
    final mapped = _verseToItemMap[index] ?? index;
    if (itemScrollController.isAttached) {
      itemScrollController.scrollTo(
        index: mapped,
        duration: duration,
        alignment: alignment,
      );
    }
  }

  /// Jump to the very top of the chapter (chapter header).
  /// Use when switching chapters/books.
  void jumpToTop() {
    if (itemScrollController.isAttached) {
      itemScrollController.jumpTo(index: 0);
    }
  }

  // Method to toggle the selection of a Verse and notify listeners
  void toggleVerse({required Verse verse}) {
    if (!_selectedIds.remove(verse.id)) {
      _selectedIds.add(verse.id);
    }
    notifyListeners();
  }

  // Method to clear the selected verses and notify listeners
  void clearSelectedVerses() {
    _selectedIds.clear();
    notifyListeners();
  }

  Future<void> saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    if (currentBook != null) prefs.setString('${_storagePrefix}book', currentBook!);
    if (currentChapter != null) prefs.setInt('${_storagePrefix}chapter', currentChapter!);
    prefs.setString('${_storagePrefix}version', currentVersion);
    // 2026-05-25 (v1.3.41): also persist the last-read state as a
    // single JSON blob under the ProfileService-scoped 'lastRead'
    // key. RealtimeDbSyncService picks this up + a paired
    // 'lastReadTimestamp' int so reading position follows the
    // user across devices (newest-write-wins). The legacy
    // per-key triple above (book / chapter / version) stays as
    // a fallback for older clients that don't speak lastRead.
    if (isPrimary) {
      // Only the primary pane drives the sync. The secondary
      // split-pane has its own _storagePrefix and shouldn't
      // overwrite the main reading position.
      //
      // 2026-05-25 (v1.3.43): also include the "继续讲道" /
      // resume-sermon state. The dashboard `_loadResumeSermon`
      // helper reads two unscoped keys: `sermons_last_read`
      // (sermon ID) and `sermonScroll:{id}:{lang}` (pixel
      // offset). User report: "有一个有继续讲道在dashboard但是
      // 其他都没有，这个也有sync吗" — on Device A they have an
      // active "Continue Sermon" card, but Device B sees nothing
      // because the sermon ID was device-local. Folding into the
      // existing lastRead blob keeps the sync surface narrow.
      // Scroll-pixel offset is intentionally NOT synced because
      // it's screen-size-dependent — instead, when Device B
      // applies the blob, it gets the sermon ID and a 0% start
      // (no progress bar) until the user scrolls themselves.
      final sermonId = prefs.getString('sermons_last_read');
      final blob = jsonEncode({
        'version': currentVersion,
        if (currentBook != null) 'book': currentBook,
        if (currentChapter != null) 'chapter': currentChapter,
        if (sermonId != null && sermonId.isNotEmpty)
          'sermonId': sermonId,
      });
      // Content guard (v1.3.80): position unchanged → don't bump the
      // timestamp or trigger an upload (breaks the Syncing↔Synced
      // flicker loop; see _lastSyncedReadBlob).
      if (blob != _lastSyncedReadBlob) {
        _lastSyncedReadBlob = blob;
        await prefs.setString(
            ProfileService.instance.scopedKey('lastRead'), blob);
        await prefs.setInt(
            ProfileService.instance.scopedKey('lastReadTimestamp'),
            DateTime.now().millisecondsSinceEpoch);
        RealtimeDbSyncService.instance.requestUpload();
      }
    }
  }

  Future<void> restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    // 2026-05-25 (v1.3.41): prefer the synced JSON blob over the
    // legacy per-key triple. The blob is the one written by
    // saveCurrentState and synced by RealtimeDbSyncService — when
    // RTDB applies a newer remote write, the blob updates first,
    // then ProfileService notifies, and the next time the user
    // re-enters the reader, restoreState picks up the synced
    // position. Falls through to the legacy keys if no blob
    // exists yet (existing users upgrading from <v1.3.41).
    String? savedVersion;
    String? savedBook;
    int? savedChapter;
    if (isPrimary) {
      final blob = prefs.getString(
          ProfileService.instance.scopedKey('lastRead'));
      if (blob != null && blob.isNotEmpty) {
        try {
          final m = jsonDecode(blob) as Map<String, dynamic>;
          savedVersion = (m['version'] as String?)?.toLowerCase();
          savedBook = m['book'] as String?;
          final c = m['chapter'];
          if (c is int) savedChapter = c;
          if (c is num) savedChapter = c.toInt();
          // 2026-05-25 (v1.3.43): if the synced blob carries a
          // sermonId, mirror it back to the unscoped
          // `sermons_last_read` prefs key the dashboard's
          // _loadResumeSermon helper reads from. This is what
          // makes the "继续讲道" card appear on Device B after
          // Device A scrolled through a sermon. Scroll-position
          // pixels are intentionally NOT mirrored (screen-size
          // dependent) — Device B starts at 0% until the user
          // scrolls themselves.
          final sermonId = m['sermonId'];
          if (sermonId is String && sermonId.isNotEmpty) {
            await prefs.setString('sermons_last_read', sermonId);
          }
        } catch (_) {/* corrupt blob → fall through */}
      }
    }
    // Legacy fallback if the blob didn't yield a value.
    savedVersion ??= prefs.getString('${_storagePrefix}version');
    savedBook ??= prefs.getString('${_storagePrefix}book');
    savedChapter ??= prefs.getInt('${_storagePrefix}chapter');

    if (savedVersion != null) {
      var v = savedVersion.toLowerCase();
      // Migration 2026-05: NIV asset was removed for licensing reasons.
      // Existing users whose saved version is 'niv' would get an empty
      // verse list, so route them to KJV (closest English fallback that
      // is unambiguously public domain).
      if (v == 'niv') v = 'kjv';
      // 2026-05-26 (v1.3.46): one-time migration for English-locale
      // users whose saved version is the v1.3.40-era class-level
      // default `cuvs-yhwh`. v1.3.40 introduced locale-aware fresh-
      // install defaults (en→NASB) but it ONLY ran when savedVersion
      // was null — pre-v1.3.40 users (and fresh installs that hit
      // the v1.3.46-fixed-locale-prefs bug) had `cuvs-yhwh` saved
      // even though they were on English locale, so the new default
      // never reached them. Heuristic: an English-locale user with
      // exactly the old class-level default almost certainly didn't
      // deliberately pick Simplified Chinese; nudge them to NASB.
      // Anyone who actually wants CUVS-YHWH can switch back in the
      // version picker; the sentinel prevents this from re-firing.
      // Only fires on the primary pane (secondary split has its own
      // `_storagePrefix` and shouldn't be touched).
      if (isPrimary && v == 'cuvs-yhwh') {
        final migrated =
            prefs.getBool('migrated_locale_default_v1346') ?? false;
        final localeForMigration = prefs.getString('locale') ?? '';
        if (!migrated && localeForMigration == 'en') {
          v = 'nasb';
          // ignore: avoid_print
          print('[v1.3.46] migrated default from cuvs-yhwh→nasb '
              '(locale=en)');
          // Persist the new pick so subsequent boots don't roll back.
          // The lastRead blob seed-write at the end of restoreState
          // picks this up and uploads to RTDB.
          await prefs.setString('${_storagePrefix}version', 'nasb');
        }
        await prefs.setBool('migrated_locale_default_v1346', true);
      }
      currentVersion = v;
    } else {
      // 2026-05-25 (v1.3.40): no saved version yet → fresh install.
      // Pick a sensible default based on the user's locale. The
      // class-level default of 'cuvs-yhwh' was wrong for English
      // users (Bible app opening in Chinese on first launch felt
      // broken). AppSettings persists locale under the 'locale'
      // key — we read it directly here rather than holding a
      // reference to AppSettings to avoid the load-order coupling.
      //   en       → NASB (the user-preferred English default)
      //   zh-Hans  → CUVS-YHWH (和合本 Yahweh, Simplified)
      //   zh-Hant  → CUVS-YHWH-TR (和合本 Yahweh, Traditional)
      // Anything else falls through to CUVS-YHWH (Mandarin is the
      // app's primary audience; the China-mode build is gated by a
      // build flag, not locale).
      final locale = prefs.getString('locale') ?? '';
      switch (locale) {
        case 'en':
          currentVersion = 'nasb';
          break;
        case 'zh-Hant':
          currentVersion = 'cuvs-yhwh-tr';
          break;
        case 'zh-Hans':
        default:
          currentVersion = 'cuvs-yhwh';
          break;
      }
    }
    if (savedBook != null) currentBook = savedBook;
    if (savedChapter != null) currentChapter = savedChapter;

    await _loadHighlights();
    await _loadNotes();
    await _loadBookmarks();

    // 2026-05-25 (v1.3.42): seed the synced lastRead blob on boot
    // so the device's current position pushes to RTDB even when
    // the user hasn't changed anything yet this session. Without
    // this seed, the lastRead blob is only written when
    // currentVersion / currentBook / currentChapter changes —
    // meaning a user who upgrades to v1.3.41 + signs in but
    // doesn't navigate has an empty `users/{uid}/sync/lastRead`
    // node in RTDB until they swipe to a new chapter. That made
    // cross-device sync "feel broken on first try" because
    // Device B opened to an empty RTDB. saveCurrentState() is
    // idempotent (writes the SAME blob it would on a real change),
    // and the sync service has hash-based dedupe so calling it
    // once on every boot is cheap.
    if (isPrimary) {
      // ignore: unawaited_futures
      saveCurrentState();
    }

    notifyListeners();
  }
}
