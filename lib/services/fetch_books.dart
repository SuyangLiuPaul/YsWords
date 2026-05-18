import 'package:yswords/constants/book_names.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/providers/main_provider.dart';

// 2026-05-18 (v1.2.53): `bookNameToEnglish` moved to a dependency-
// free file in `lib/constants/book_names.dart`. Re-exported here so
// existing call-sites that do `import '...fetch_books.dart' show
// bookNameToEnglish` keep working unchanged.
export 'package:yswords/constants/book_names.dart' show bookNameToEnglish;

const List<String> standardBookOrder = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth',
  '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
  '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
  'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
  'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
  'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
  'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
  'Matthew', 'Mark', 'Luke', 'John', 'Acts',
  'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
  'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
  '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
  'Hebrews', 'James', '1 Peter', '2 Peter',
  '1 John', '2 John', '3 John', 'Jude', 'Revelation',
  // Add Chinese Simplified and Traditional names afterwards if needed separately.
];


// Class repsonsible for fetching books based on the provided verses

class FetchBooks {
  static Future<void> execute({required MainProvider mainProvider}) async {
    final verses = mainProvider.verses;

    // Collect unique book titles mapped to English
    final seen = <String>{};
    final foundBookTitles = <String>[];
    for (final v in verses) {
      final englishBook = bookNameToEnglish[v.book] ?? v.book;
      if (seen.add(englishBook)) foundBookTitles.add(englishBook);
    }

    // Sort book titles according to standard biblical order
    final bookTitles =
        standardBookOrder.where((b) => foundBookTitles.contains(b)).toList();

    // Build complete book list first, then set once to avoid N+1 rebuilds
    final builtBooks = <Book>[];

    for (final bookTitle in bookTitles) {
      final availableVerses = verses
          .where((v) => (bookNameToEnglish[v.book] ?? v.book) == bookTitle)
          .toList();
      if (availableVerses.isEmpty) continue;

      final availableChapters = availableVerses
          .map((e) => e.chapter)
          .toSet()
          .toList()
        ..sort();

      final chapters = <Chapter>[
        for (final element in availableChapters)
          Chapter(
            title: element,
            verses: (availableVerses.where((v) => v.chapter == element).toList()
              ..sort((a, b) => a.verse.compareTo(b.verse))),
          )
      ];

      // Use the localized book name from the first verse for display
      final localizedBookName = availableVerses.first.book;
      builtBooks.add(Book(title: localizedBookName, chapters: chapters));
    }

    mainProvider.setBooks(builtBooks);
  }
}
