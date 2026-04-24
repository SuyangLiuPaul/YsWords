import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:yswords/constants/book_groups.dart'
    show oldTestamentBooks, newTestamentBooks;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/version_mapper.dart' show toEnglish;

class BooksPage extends StatefulWidget {
  final int chapterIdx;
  final String bookIdx;
  const BooksPage({super.key, required this.chapterIdx, required this.bookIdx});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  final AutoScrollController _autoScrollController = AutoScrollController();
  Book? currentBook;
  bool showOldTestament = true;
  bool hasOldTestament = false;
  bool hasNewTestament = false;
  bool _initialScrollDone = false;

  Map<String, bool> expandStatus = {};
  bool _showGridView = false;
  String? _gridSelectedBook;

  @override
  void dispose() {
    _autoScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final mainProvider = Provider.of<MainProvider>(context, listen: false);

    // Map displayed titles back to English keys (支持简 / 繁 / 英)
    final bookTitlesEng = mainProvider.books
        .map<String>((b) => toEnglish(b.title) ?? b.title)
        .toSet();

    hasOldTestament = bookTitlesEng.any(
      (b) => oldTestamentBooks.contains(b),
    );
    hasNewTestament = bookTitlesEng.any(
      (b) => newTestamentBooks.contains(b),
    );

    // Default to OT if available; show NT only when no OT exists
    showOldTestament = hasOldTestament;

    // All start collapsed
    for (var book in mainProvider.books) {
      expandStatus[book.title] = false;
    }

    // Auto‑expand the current book (but only when a bookIdx was passed in)
    if (widget.bookIdx.isNotEmpty && expandStatus.containsKey(widget.bookIdx)) {
      expandStatus[widget.bookIdx] = true;
    }

    // **Scroll (but do not expand) to the book passed in via widget.bookIdx**
    final verseBook = widget.bookIdx;
    // if that book actually exists in our list...
    final bookEntry =
        mainProvider.books.firstWhereOrNull((b) => b.title == verseBook);
    if (bookEntry != null) {
      // show the correct side (OT/NT)
      showOldTestament = _isOldTestament(bookEntry.title);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialScrollDone) {
          final filtered = mainProvider.books
              .where((b) => showOldTestament
                  ? _isOldTestament(b.title)
                  : !_isOldTestament(b.title))
              .toList();
          final idx = filtered.indexWhere((b) => b.title == bookEntry.title);
          if (idx != -1) {
            // Scroll to the book index
            Future.microtask(() {
              if (mounted) {
                _autoScrollController.scrollToIndex(
                  idx,
                  preferPosition: AutoScrollPosition.begin,
                  duration: const Duration(milliseconds: 10),
                );
              }
            });
          }
          _initialScrollDone = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return Consumer<MainProvider>(
      builder: (context, mainProvider, child) {
        final books = mainProvider.books;
        final filteredBooks = books.where((book) {
          return showOldTestament
              ? _isOldTestament(book.title)
              : !_isOldTestament(book.title);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(
                uiStrings['bibleBooks']?[settings.locale] ?? 'Bible Books'),
          ),
          body: Column(
            children: [
              // Top row: OT/NT toggle + Grid/List toggle
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // OT/NT toggle
                    if (hasOldTestament && hasNewTestament)
                      Row(
                        children: [
                          if (hasOldTestament)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    showOldTestament = true;
                                    expandStatus.updateAll((key, _) => false);
                                    _gridSelectedBook = null;
                                  });
                                  if (!_showGridView) {
                                    _autoScrollController.scrollToIndex(
                                      0,
                                      preferPosition: AutoScrollPosition.begin,
                                      duration: const Duration(milliseconds: 10),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: showOldTestament
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surface,
                                  foregroundColor: showOldTestament
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                ),
                                child: Text(
                                  uiStrings['oldTestament']?[settings.locale] ??
                                      'Old Testament',
                                  style: TextStyle(
                                    fontSize: settings.fontSize,
                                    fontFamily: settings.fontFamily,
                                  ),
                                ),
                              ),
                            ),
                          if (hasNewTestament)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    showOldTestament = false;
                                    expandStatus.updateAll((key, _) => false);
                                    _gridSelectedBook = null;
                                  });
                                  if (!_showGridView) {
                                    _autoScrollController.scrollToIndex(
                                      0,
                                      preferPosition: AutoScrollPosition.begin,
                                      duration: const Duration(milliseconds: 10),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: !showOldTestament
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surface,
                                  foregroundColor: !showOldTestament
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                ),
                                child: Text(
                                  uiStrings['newTestament']?[settings.locale] ??
                                      'New Testament',
                                  style: TextStyle(
                                      fontSize: settings.fontSize,
                                      fontFamily: settings.fontFamily),
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      const Spacer(),
                    // Grid/List toggle
                    ToggleButtons(
                      isSelected: [_showGridView == false, _showGridView == true],
                      onPressed: (index) {
                        setState(() {
                          _showGridView = index == 1;
                          _gridSelectedBook = null;
                          expandStatus.updateAll((key, _) => false);
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                      children: [
                        Tooltip(
                          message: uiStrings['listView']?[settings.locale] ?? 'List',
                          child: Icon(Icons.list, size: settings.fontSize * 1.1),
                        ),
                        Tooltip(
                          message: uiStrings['gridView']?[settings.locale] ?? 'Grid',
                          child: Icon(Icons.grid_view, size: settings.fontSize * 1.1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: _showGridView
                    ? _buildGridView(context, mainProvider, settings, filteredBooks)
                    : _buildListView(context, mainProvider, settings, filteredBooks),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context, MainProvider mainProvider,
      AppSettings settings, List<Book> filteredBooks) {
    return ListView.builder(
      itemCount: filteredBooks.length,
      physics: const BouncingScrollPhysics(),
      controller: _autoScrollController,
      itemBuilder: (context, index) {
        Book book = filteredBooks[index];
        return AutoScrollTag(
          key: ValueKey(index),
          controller: _autoScrollController,
          index: index,
          child: Container(
            decoration: expandStatus[book.title] == true
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 0.3,
                      ),
                    ),
                  ),
            child: Theme(
              data: Theme.of(context).copyWith(
                expansionTileTheme: const ExpansionTileThemeData(),
              ),
              child: ExpansionTile(
                title: Text(
                  book.title,
                  style: TextStyle(
                      fontSize: settings.fontSize,
                      fontFamily: settings.fontFamily),
                ),
                initiallyExpanded: expandStatus[book.title] ?? false,
                maintainState: true,
                onExpansionChanged: (expanded) {
                  setState(() {
                    expandStatus[book.title] = expanded;
                  });
                },
                children: [
                  _buildChapterGrid(
                      context, mainProvider, settings, book),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context, MainProvider mainProvider,
      AppSettings settings, List<Book> filteredBooks) {
    final scheme = Theme.of(context).colorScheme;

    // If a book is selected, show its chapters
    if (_gridSelectedBook != null) {
      final book = filteredBooks.firstWhereOrNull((b) => b.title == _gridSelectedBook);
      if (book != null) {
        return Column(
          children: [
            // Back to book grid
            InkWell(
              onTap: () => setState(() => _gridSelectedBook = null),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, size: settings.fontSize, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: settings.fontSize,
                        fontFamily: settings.fontFamily,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.1,
                ),
                itemCount: book.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = book.chapters[index];
                  final selected = chapter.title == widget.chapterIdx &&
                      widget.bookIdx == book.title;
                  return _chapterTile(
                    context, mainProvider, settings, book, chapter, selected, scheme,
                  );
                },
              ),
            ),
          ],
        );
      }
    }

    // Show book grid
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 2.5,
      ),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final book = filteredBooks[index];
        final isCurrent = widget.bookIdx == book.title;
        return Card(
          color: isCurrent ? scheme.primary : scheme.surfaceContainerHighest,
          elevation: isCurrent ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isCurrent ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _gridSelectedBook = book.title),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: settings.fontSize * 0.85,
                        fontFamily: settings.fontFamily,
                        fontWeight: FontWeight.w500,
                        color: isCurrent ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                    Text(
                      '${book.chapters.length}',
                      style: TextStyle(
                        fontSize: settings.fontSize * 0.6,
                        color: isCurrent ? scheme.onPrimary.withValues(alpha: 0.7) : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChapterGrid(BuildContext context, MainProvider mainProvider,
      AppSettings settings, Book book) {
    return Wrap(
      alignment: WrapAlignment.start,
      children: List.generate(book.chapters.length, (i) {
        final chapter = book.chapters[i];
        final selected = chapter.title == widget.chapterIdx &&
            widget.bookIdx == book.title;
        final scheme = Theme.of(context).colorScheme;
        return _chapterTile(
            context, mainProvider, settings, book, chapter, selected, scheme);
      }),
    );
  }

  Widget _chapterTile(BuildContext context, MainProvider mainProvider,
      AppSettings settings, Book book, Chapter chapter, bool selected, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 55,
        width: 55,
        child: Card(
          color: selected ? scheme.primary : null,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(7.5),
            onTap: () {
              final matched = mainProvider.verses
                  .where((v) => v.book == book.title && v.chapter == chapter.title)
                  .toList();
              if (matched.isEmpty) return;
              mainProvider.setCurrentChapter(book: book.title, chapter: chapter.title);
              mainProvider.updateCurrentVerse(verse: matched.first);
              mainProvider.jumpToTop();
              Get.back();
            },
            child: Center(
              child: Text(
                chapter.title.toString(),
                style: TextStyle(
                  fontSize: settings.fontSize * 0.9,
                  fontFamily: settings.fontFamily,
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isOldTestament(String displayedTitle) {
    final en = toEnglish(displayedTitle) ?? displayedTitle;
    return oldTestamentBooks.contains(en);
  }
}
