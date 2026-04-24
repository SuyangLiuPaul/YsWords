import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/book.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

// MainProvider class to extends ChangeNotifier for state management

class MainProvider extends ChangeNotifier {
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
    saveCurrentState();
    notifyListeners();
  }

  List<Verse> verses = [];
  // Set to store selected verse IDs
  final Set<String> _selectedIds = {};

  // Map to store verse highlight colors (verse ID → ARGB int)
  Map<String, int> _highlights = {};

  // List of Store Verse Objects
  List<Verse> get selectedVerses =>
      verses.where((v) => _selectedIds.contains(v.id)).toList();
  Set<String> get selectedIds => _selectedIds;

  bool isSelected(Verse v) => _selectedIds.contains(v.id);

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
  }

  void removeHighlight({required Verse verse}) {
    _highlights.remove(verse.id);
    _saveHighlights();
    notifyListeners();
  }

  void setHighlightsForVerses({required List<Verse> verses, required int color}) {
    for (final v in verses) {
      _highlights[v.id] = color;
    }
    _saveHighlights();
    notifyListeners();
  }

  void removeHighlightsForVerses({required List<Verse> verses}) {
    for (final v in verses) {
      _highlights.remove(v.id);
    }
    _saveHighlights();
    notifyListeners();
  }

  void _saveHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('highlights', jsonEncode(_highlights));
  }

  Future<void> _loadHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('highlights');
    if (json != null) {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _highlights = decoded.map((k, v) => MapEntry(k, v as int));
    }
  }

  // Method to set the current book and chapter, persist state, and notify listeners
  void setCurrentChapter({required String book, required int chapter}) {
    currentBook = book;
    currentChapter = chapter;
    saveCurrentState();
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
    if (currentBook != null) prefs.setString('book', currentBook!);
    if (currentChapter != null) prefs.setInt('chapter', currentChapter!);
    prefs.setString('version', currentVersion);
  }

  Future<void> restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getString('version');
    final savedBook = prefs.getString('book');
    final savedChapter = prefs.getInt('chapter');

    if (savedVersion != null) currentVersion = savedVersion.toLowerCase();
    if (savedBook != null) currentBook = savedBook;
    if (savedChapter != null) currentChapter = savedChapter;

    await _loadHighlights();

    notifyListeners();
  }
}
