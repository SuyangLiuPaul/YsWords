import 'dart:async';
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
    notifyListeners();
  }

  void setBooks(List<Book> list) {
    books = list;
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

  void setVersion(String version) {
    currentVersion = version;
    saveCurrentState();
    notifyListeners();
  }

  List<Verse> verses = [];
  // Set to store selected verse IDs
  final Set<String> _selectedIds = {};

  // List of Store Verse Objects
  List<Verse> get selectedVerses =>
      verses.where((v) => _selectedIds.contains(v.id)).toList();
  Set<String> get selectedIds => _selectedIds;

  bool isSelected(Verse v) => _selectedIds.contains(v.id);

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
    books.add(book);
    notifyListeners();
  }

  // Variable to store the current verse
  Verse? currentVerse;
  // Method to update the current verse and notify listeners
  void updateCurrentVerse({required Verse verse}) {
    currentVerse = verse;
    notifyListeners();
  }

  // Method to scroll to a specific index in the list and notify listeners
  void scrollToIndex({required int index}) {
    // debugPrint(
    //     '🌀 scrollToIndex: index=$index, controller attached: ${itemScrollController.isAttached}');
    if (itemScrollController.isAttached) {
      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 800),
      );
    } else {
      // debugPrint('⚠️ scrollToIndex skipped: controller not attached');
    }
    notifyListeners();
  }

  void jumpToIndex({required int index}) {
    if (itemScrollController.isAttached) {
      itemScrollController.jumpTo(index: index);
    }
  }

  // Method to toggle the selection of a Verse and notify listeners
  void toggleVerse({required Verse verse}) {
    if (!_selectedIds.remove(verse.id)) {
      _selectedIds.add(verse.id);
    }
    // debugPrint('selected=${_selectedIds.length}');

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

    if (savedVersion != null) currentVersion = savedVersion;
    if (savedBook != null) currentBook = savedBook;
    if (savedChapter != null) currentChapter = savedChapter;

    notifyListeners();
  }
}
