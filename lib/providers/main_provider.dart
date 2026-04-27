import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/services/fetch_books.dart' show bookNameToEnglish;
import 'package:yswords/services/cloud_sync_service.dart';
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
    notifyListeners();
  }

  void setBooks(List<Book> list) {
    // Deduplicate by title while preserving first occurrence
    final seen = <String>{};
    books = list.where((b) => seen.add(b.title)).toList();
    notifyListeners();
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

  void _saveHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    // Profile-scoped — different signed-in users keep their own
    // annotations even when they share the same browser. Both
    // split-view panes share the same profile so they still see
    // the same set.
    prefs.setString(
        ProfileService.instance.scopedKey('highlights'),
        jsonEncode(_highlights));
    CloudSyncService.instance.requestUpload();
  }

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
    if (migrated && isPrimary) {
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
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(ProfileService.instance.scopedKey('verseNotes'),
        jsonEncode(_verseNotes));
    CloudSyncService.instance.requestUpload();
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
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(ProfileService.instance.scopedKey('bookmarks'),
        _bookmarks.toList());
    CloudSyncService.instance.requestUpload();
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

    if (savedVersion != null) currentVersion = savedVersion.toLowerCase();
    if (savedBook != null) currentBook = savedBook;
    if (savedChapter != null) currentChapter = savedChapter;

    await _loadHighlights();
    await _loadNotes();
    await _loadBookmarks();

    notifyListeners();
  }
}
