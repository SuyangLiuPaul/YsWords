import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/pages/strongs_entry_page.dart';
import 'package:yswords/utils/format_searched_text.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart'
    show localeAwareBookName, toEnglish, translateBookName;
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/models/app_settings.dart';
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

  // When the user typed a Strong's-number pattern (e.g. "G2316"), these
  // hold the lookup result; in this mode the regular text-search path
  // is bypassed and the UI renders concordance refs instead of verses.
  String? _strongsKey;
  StrongsEntry? _strongsEntry;
  ConcordanceResult? _strongsResult;

  @override
  void dispose() {
    _scrollController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  // Method to perform the search
  Future<void> search() async {
    final query = _textEditingController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results.clear();
        bookCounts.clear();
        _strongsKey = null;
        _strongsEntry = null;
        _strongsResult = null;
        searchPerformed = true;
      });
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
        _results.clear();
        bookCounts.clear();
        searchPerformed = false;
        _strongsKey = num;
        _strongsEntry = null;
        _strongsResult = null;
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

    setState(() {
      _results.clear();
      bookCounts.clear();
      _strongsKey = null;
      _strongsEntry = null;
      _strongsResult = null;
      searchPerformed = false;
    });

    final mainProvider = Provider.of<MainProvider>(context, listen: false);
    final verses = mainProvider.verses;
    final source = filterBook != null
        ? verses.where((v) => v.book == filterBook)
        : searchAll
            ? verses
            : verses.where((v) => v.book == mainProvider.currentBook);

    for (var verse in source) {
      final sanitized = sanitizeForSearch(verse.text);
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
              // Allow alphanumerics + Chinese chars + space + the
              // colon / dash / dot punctuation needed to type Bible
              // references like "John 3:16" or "约 3:16-18".
              FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9a-zA-Z\u4E00-\u9FFF :\-\.：。‐–—]')),
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
              final trimmed = s.trim();
              if (trimmed.isEmpty) {
                setState(() {
                  searchAll = true;
                  filterBook = null;
                });
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
              await search();
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0.0);
              }
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
            if (_strongsKey != null) ...[
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
                    '${(uiStrings['searchResultCount']?[settings.locale] ?? 'Total {count} matches, grouped by book:').replaceAll('{count}', _results.length.toString())} ${bookCounts.entries.take(3).map((e) => '${e.key}(${e.value})').join(settings.locale == 'en' ? ', ' : '，')}${bookCounts.length > 3 ? '...' : ''}${bookCounts.length > 3 ? '\n${uiStrings['viewMoreBooksHint']?[settings.locale] ?? ''}' : ''}',
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
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              searchPerformed
                                  ? Icons.search_off_rounded
                                  : Icons.search_rounded,
                              size: settings.fontSize * 2.4,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              searchPerformed
                                  ? (uiStrings['noResults']?[settings.locale] ??
                                      'No results found')
                                  : (uiStrings['searchHint']
                                          ?[settings.locale] ??
                                      'Type a word or phrase to search'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  )
                                  .copyWith(fontSize: settings.fontSize),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
                              // Capture the provider synchronously — by
                              // the time the delayed callbacks run we'll
                              // have popped this page so context lookups
                              // would be unsafe.
                              final mainProv = Provider.of<MainProvider>(
                                  context,
                                  listen: false);
                              mainProv.setCurrentChapter(
                                  book: verse.book, chapter: verse.chapter);
                              mainProv.updateCurrentVerse(verse: verse);
                              Get.back();
                              Future.delayed(
                                  const Duration(milliseconds: 300), () {
                                // Provider is captured; we don't touch
                                // BuildContext after this point.
                                final chapterVerses = mainProv.verses
                                    .where((v) =>
                                        v.book == verse.book &&
                                        v.chapter == verse.chapter)
                                    .toList()
                                  ..sort((a, b) =>
                                      a.verse.compareTo(b.verse));
                                final relIdx = chapterVerses
                                    .indexWhere((v) => v.verse == verse.verse);
                                if (relIdx < 0) return;
                                mainProv.jumpToIndex(index: relIdx);
                                mainProv.setHighlightIndex(relIdx);
                                Future.delayed(
                                    const Duration(milliseconds: 800), () {
                                  // It's safe to clear regardless of this
                                  // widget's lifetime — provider survives
                                  // the page pop.
                                  mainProv.clearHighlightIndex();
                                });
                              });
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
    final refs = result.refs;
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
    final mainProv = Provider.of<MainProvider>(context, listen: false);
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
    mainProv.setCurrentChapter(book: verse.book, chapter: verse.chapter);
    mainProv.updateCurrentVerse(verse: verse);
    Get.back();
    Future.delayed(const Duration(milliseconds: 300), () {
      final chapterVerses = mainProv.verses
          .where((v) => v.book == verse.book && v.chapter == verse.chapter)
          .toList()
        ..sort((a, b) => a.verse.compareTo(b.verse));
      final relIdx =
          chapterVerses.indexWhere((v) => v.verse == verse.verse);
      if (relIdx < 0) return;
      mainProv.jumpToIndex(index: relIdx);
      mainProv.setHighlightIndex(relIdx);
      Future.delayed(const Duration(milliseconds: 800), () {
        mainProv.clearHighlightIndex();
      });
    });
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

    mainProv.setCurrentChapter(book: hit.book, chapter: hit.chapter);
    mainProv.updateCurrentVerse(verse: hit);
    Get.back();
    Future.delayed(const Duration(milliseconds: 300), () {
      final relIdx =
          chapterMatches.indexWhere((v) => v.verse == hit.verse);
      if (relIdx < 0) return;
      mainProv.jumpToIndex(index: relIdx);
      mainProv.setHighlightIndex(relIdx);
      Future.delayed(const Duration(milliseconds: 800), () {
        mainProv.clearHighlightIndex();
      });
    });
    return true;
  }
}
