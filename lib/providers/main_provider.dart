import 'dart:async';
import 'dart:collection' show LinkedHashMap;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/services/fetch_books.dart' show bookNameToEnglish;
import 'package:yswords/services/fetch_verses.dart' show FetchVerses;
import 'package:yswords/services/realtime_db_sync_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

// MainProvider class to extends ChangeNotifier for state management

class MainProvider extends ChangeNotifier {
  final String _storagePrefix;

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
    currentVersion = version;
    verses = cached;
    _selectedIds.clear();
    // Same per-verse caches that setVerses invalidates — these are
    // derived from the verse list so they need a rebuild after the
    // swap. v1.2.16: paragraph-groups cache is now multi-slot LRU
    // keyed by version+chapter, so don't clear it here — entries
    // from a different version coexist safely and any reusable
    // chapter cache stays warm for re-visits.
    _searchKeysCache = null;
    _searchKeysCacheLength = -1;
    _bookOrderCache = null;
    notifyListeners();
    return true;
  }

  void setBooks(List<Book> list) {
    // Deduplicate by title while preserving first occurrence
    final seen = <String>{};
    books = list.where((b) => seen.add(b.title)).toList();
    // Book list changed → bookOrder lookup map is stale.
    _bookOrderCache = null;
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
  static const int _kParagraphCacheLimit = 30;
  final LinkedHashMap<
      String,
      ({
        List<List<Verse>> groups,
        Map<int, int> verseToItem,
        Map<int, int> itemToVerseIndex,
      })> _paragraphGroupsCache = LinkedHashMap();

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

  // Contollers and Listeners for managing scroll positions and items
  ItemScrollController itemScrollController = ItemScrollController();
  ScrollOffsetController scrollOffsetController = ScrollOffsetController();
  ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  ScrollOffsetListener scrollOffsetListener = ScrollOffsetListener.create();

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

  /// Returns true if the verse has any note text attached.
  bool isVerseNoted(Verse v) => (_verseNotes[v.id]?.isNotEmpty ?? false);

  /// Returns the note text for [v], or null if no note exists.
  String? getVerseNote(Verse v) => _verseNotes[v.id];

  /// Set or replace the note for [verse]. Pass an empty string to
  /// remove the note. Persists to SharedPreferences and notifies.
  void setVerseNote({required Verse verse, required String text}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _verseNotes.remove(verse.id);
    } else {
      _verseNotes[verse.id] = trimmed;
    }
    _saveNotes();
    notifyListeners();
  }

  /// Same as [setVerseNote] but for an empty string — convenience.
  void clearVerseNote({required Verse verse}) {
    if (_verseNotes.remove(verse.id) != null) {
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
      RealtimeDbSyncService.instance.requestUpload();
    } catch (e, st) {
      debugPrint('MainProvider._saveNotes failed: $e\n$st');
    }
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    _verseNotes = {};
    final json =
        prefs.getString(ProfileService.instance.scopedKey('verseNotes'));
    if (json == null) return;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    _verseNotes = {
      for (final e in decoded.entries) e.key: e.value as String,
    };
  }

  void _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(ProfileService.instance.scopedKey('bookmarks'),
          _bookmarks.toList());
      RealtimeDbSyncService.instance.requestUpload();
    } catch (e, st) {
      debugPrint('MainProvider._saveBookmarks failed: $e\n$st');
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

  /// Like [jumpToIndex] but uses `scrollTo` with a 1 ms duration.
  /// Round 56: fixes a "first tap from Library goes to top of
  /// chapter" bug — `jumpTo` silently no-ops when the
  /// `ScrollablePositionedList` is `isAttached` but hasn't yet
  /// finished measuring its items (true on a fresh HomePage
  /// mount). `scrollTo` with a tiny duration handles that case
  /// gracefully and lands on the right item.
  void scrollToIndexAnimated({required int index, Duration duration = const Duration(milliseconds: 1)}) {
    final mapped = _verseToItemMap[index] ?? index;
    if (itemScrollController.isAttached) {
      itemScrollController.scrollTo(
        index: mapped,
        duration: duration,
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
  }

  Future<void> restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getString('${_storagePrefix}version');
    final savedBook = prefs.getString('${_storagePrefix}book');
    final savedChapter = prefs.getInt('${_storagePrefix}chapter');

    if (savedVersion != null) {
      var v = savedVersion.toLowerCase();
      // Migration 2026-05: NIV asset was removed for licensing reasons.
      // Existing users whose saved version is 'niv' would get an empty
      // verse list, so route them to KJV (closest English fallback that
      // is unambiguously public domain).
      if (v == 'niv') v = 'kjv';
      currentVersion = v;
    }
    if (savedBook != null) currentBook = savedBook;
    if (savedChapter != null) currentChapter = savedChapter;

    await _loadHighlights();
    await _loadNotes();
    await _loadBookmarks();

    notifyListeners();
  }
}
