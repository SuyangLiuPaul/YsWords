import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/format_searched_text.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:flutter/services.dart';

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

  // Method to perform the search
  Future<void> search() async {
    setState(() {
      _results.clear();
      bookCounts.clear();
      searchPerformed = false;
    });

    final mainProvider = Provider.of<MainProvider>(context, listen: false);
    final verses = mainProvider.verses;
    final source = filterBook != null
        ? verses.where((v) => v.book == filterBook)
        : searchAll
            ? verses
            : verses.where((v) => v.book == mainProvider.currentBook);

    final notePattern  = RegExp(r'<note:[^>]*>');
    final bracePattern = RegExp(r'\{[^}]*\}');

    for (var verse in source) {
      // sanitize out notes and braces before searching
      final sanitized = verse.text
          .replaceAll(notePattern, '')
          .replaceAll(bracePattern, '')
          .trim();
      final textNorm = sanitized.replaceAll(" ", "").toLowerCase();
      final queryNorm =
          _textEditingController.text.trim().replaceAll(" ", "").toLowerCase();
      if (textNorm.contains(queryNorm)) {
        if (!_results.contains(verse)) {
          _results.add(verse);
          bookCounts[verse.book] = (bookCounts[verse.book] ?? 0) + 1;
        }
      }
    }

    final bookOrder = { for (var i = 0; i < mainProvider.books.length; i++) mainProvider.books[i].title: i };

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
    bookCounts = { for (var e in sortedEntries) e.key: e.value };

    setState(() {
      searchPerformed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    // Patterns to strip out notes and curly annotations
    final notePattern  = RegExp(r'<note:[^>]*>');
    final bracePattern = RegExp(r'\{[^}]*\}');
    return Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          // Search input field in the app bar
          title: TextField(
            autofocus: true,
            controller: _textEditingController,
            style: TextStyle(fontSize: settings.fontSize),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: uiStrings['search']?[settings.locale] ?? 'Search',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z\u4E00-\u9FFF ]')),
            ],
            onChanged: (text) {
              setState(() {
                if (text.trim().isEmpty) {
                  searchAll = true;
                  filterBook = null;
                }
              });
            },
            onSubmitted: (s) async {
              if (s.trim().isEmpty) {
                setState(() {
                  searchAll = true;
                  filterBook = null;
                });
              }
              await search();
              _scrollController.jumpTo(0.0);
            },
            textInputAction: TextInputAction.search,
          ),
          actions: [
            PopupMenuButton<Object>(
              tooltip: uiStrings['showMenu']?[settings.locale] ?? 'Show menu',
              icon: const Icon(Icons.filter_list),
              onSelected: (value) async {
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
                // Immediately perform search and scroll to top
                await search();
                _scrollController.jumpTo(0.0);
              },
              itemBuilder: (_) {
                // base scope items
                final items = <PopupMenuEntry<Object>>[
                  PopupMenuItem<bool>(
                      value: false,
                      child: Text(uiStrings['searchCurrentBook']?[settings.locale] ?? 'Search Current Book', style: TextStyle(fontSize: settings.fontSize))),
                  PopupMenuItem<bool>(
                      value: true,
                      child: Text(uiStrings['searchEntireBible']?[settings.locale] ?? 'Search Entire Bible', style: TextStyle(fontSize: settings.fontSize))),
                ];
                // divider
                items.add(const PopupMenuDivider());
                // use bookCounts for per-book counts
                bookCounts.forEach((book, count) {
                  items.add(
                    PopupMenuItem<String>(
                      value: book,
                      child: Text('$book ($count)', style: TextStyle(fontSize: settings.fontSize)),
                    ),
                  );
                });
                return items;
              },
            ),
            // Clear search button when there's input
            if (_textEditingController.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  setState(() {
                    _textEditingController.clear();
                    FocusScope.of(context).unfocus(); // 关闭键盘
                    _results.clear();
                    bookCounts.clear();
                    searchPerformed = false;
                    searchAll = true; // ✅ 恢复为整本搜索
                    filterBook = null; // ✅ 清除书卷筛选
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        body: Column(
          children: [
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
                            title: Text(uiStrings['bibleBooks']
                                    ?[settings.locale] ??
                                'Bible Books',
                              style: TextStyle(fontSize: settings.fontSize),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: bookCounts.entries
                                    .map((e) => Text('${e.key} (${e.value})', style: TextStyle(fontSize: settings.fontSize)))
                                    .toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(uiStrings['ok']?[settings.locale] ?? 'OK', style: TextStyle(fontSize: settings.fontSize)),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  child: Text(
                    ((uiStrings['searchResultCount']?[settings.locale] ??
                                    'Total {count} matches, grouped by book:')
                                .replaceAll(
                                    '{count}', _results.length.toString()) +
                            bookCounts.entries
                                .take(3)
                                .map((e) => '${e.key}(${e.value})')
                                .join('，') +
                            (bookCounts.length > 3 ? '...' : '')) +
                        (bookCounts.length > 3
                            ? '\n${uiStrings['viewMoreBooksHint']?[settings.locale] ?? ''}'
                            : ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: settings.fontSize,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _results.isEmpty && searchPerformed
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          uiStrings['noResults']?[settings.locale] ??
                              'No results found',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.outline,
                              )
                              .copyWith(fontSize: settings.fontSize),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
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
                              final mainProv = Provider.of<MainProvider>(
                                  context,
                                  listen: false);
                              mainProv.setCurrentChapter(
                                  book: verse.book, chapter: verse.chapter);
                              mainProv.updateCurrentVerse(verse: verse);
                              Get.back();
                              Future.delayed(const Duration(milliseconds: 1), () {
                                final chapterVerses = mainProv.verses
                                    .where((v) => v.book == verse.book && v.chapter == verse.chapter)
                                    .toList();
                                chapterVerses.sort((a, b) => a.verse.compareTo(b.verse)); // Ensure order
                                final relIdx = chapterVerses.indexWhere((v) => v.verse == verse.verse);
                                if (relIdx < 0) return;
                                mainProv.jumpToIndex(index: relIdx);
                                mainProv.setHighlightIndex(relIdx);
                                Future.delayed(const Duration(milliseconds: 800), () {
                                  mainProv.clearHighlightIndex();
                                });
                              });
                            },
                            // Sanitize verse text: remove <note:…> and {...}, leave […]
                            title: Builder(
                              builder: (context) {
                                final sanitized = verse.text
                                    .replaceAll(notePattern, '')
                                    .replaceAll(bracePattern, '')
                                    .trim();
                                return formatSearchText(
                                  input: sanitized,
                                  text: _textEditingController.text.trim(),
                                  context: context,
                                );
                              },
                            ),
                            subtitle: Text(
                                '${verse.book} ${verse.chapter}:${verse.verse}',
                                style: TextStyle(fontSize: settings.fontSize * 0.85),
                            ),
                          ),
                        );
                      },
                    ),
            )
          ],
        ));
  }
}
