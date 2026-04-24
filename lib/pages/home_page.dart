import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/books_page.dart';
import 'package:yswords/pages/search_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/version_mapper.dart'
    show translateBookName, toEnglish;
import 'package:yswords/widgets/verse_widget.dart';
import 'package:yswords/widgets/paragraph_group_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MainProvider? _positionsProvider;
  int _visibleItemIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final mainProvider = context.read<MainProvider>();
      _attachPositionsListener(mainProvider);
      if (mainProvider.verses.isEmpty) {
        await FetchVerses.execute(mainProvider: mainProvider);
        if (!mounted) return;
        await FetchBooks.execute(mainProvider: mainProvider);
      }
    });
  }

  @override
  void dispose() {
    _positionsProvider?.itemPositionsListener.itemPositions
        .removeListener(_handleItemPositionsChanged);
    super.dispose();
  }

  void _attachPositionsListener(MainProvider provider) {
    if (_positionsProvider == provider) return;
    _positionsProvider?.itemPositionsListener.itemPositions
        .removeListener(_handleItemPositionsChanged);
    _positionsProvider = provider;
    provider.itemPositionsListener.itemPositions
        .addListener(_handleItemPositionsChanged);
  }

  void _handleItemPositionsChanged() {
    final positions =
        _positionsProvider?.itemPositionsListener.itemPositions.value;
    if (positions == null || positions.isEmpty || !mounted) return;

    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList();
    if (visible.isEmpty) return;

    visible.sort((a, b) {
      final edge = a.itemLeadingEdge.compareTo(b.itemLeadingEdge);
      return edge != 0 ? edge : a.index.compareTo(b.index);
    });
    final nextIndex = visible.first.index;
    if (nextIndex != _visibleItemIndex) {
      setState(() => _visibleItemIndex = nextIndex);
    }
  }

  String formattedSelectedVerses({required List<Verse> verses}) {
    if (verses.isEmpty) return '';
    final settings = context.read<AppSettings>();

    int bookOrder(String book) {
      final en = toEnglish(book) ?? book;
      final idx = standardBookOrder.indexOf(en);
      return idx < 0 ? standardBookOrder.length : idx;
    }

    final sorted = [...verses]..sort((a, b) {
        final bookCmp = bookOrder(a.book).compareTo(bookOrder(b.book));
        if (bookCmp != 0) return bookCmp;
        if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
        return a.verse.compareTo(b.verse);
      });

    final first = sorted.first;

    switch (settings.copyFormat) {
      case 'withRef':
        return sorted
            .map((v) =>
                '[${v.book} ${v.chapter}:${v.verseLabel}] ${sanitizeForSearch(v.text)}')
            .join('\n');
      case 'devotional':
        final versesText =
            sorted.map((v) => sanitizeForSearch(v.text)).join('\n');
        final range = _formatVerseRangeLabels(sorted);
        return '$versesText\n(${first.book} ${first.chapter}:$range)';
      case 'plain':
      default:
        final body = sorted
            .map((v) => '${v.verseLabel} ${sanitizeForSearch(v.text)}')
            .join('\n');
        return '${first.book} ${first.chapter}\n$body';
    }
  }

  static String _formatVerseRange(List<int> nums) {
    if (nums.isEmpty) return '';
    final sorted = [...nums]..sort();
    final parts = <String>[];
    int start = sorted[0];
    int end = start;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        parts.add(start == end ? '$start' : '$start–$end');
        start = sorted[i];
        end = start;
      }
    }
    parts.add(start == end ? '$start' : '$start–$end');
    return parts.join(', ');
  }

  static String _formatVerseRangeLabels(List<Verse> verses) {
    if (verses.isEmpty) return '';
    if (verses.any((v) => v.verseLabel != '${v.verse}')) {
      return verses.map((v) => v.verseLabel).join(', ');
    }
    return _formatVerseRange(verses.map((v) => v.verse).toList());
  }

  Future<void> _copySelectedVerses({
    required MainProvider mainProvider,
    required AppSettings settings,
  }) async {
    final text = formattedSelectedVerses(verses: mainProvider.selectedVerses);
    await ClipboardHelper.copyText(text);
    mainProvider.clearSelectedVerses();
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final copiedLabel = uiStrings['copied']?[settings.locale] ?? 'Copied!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              copiedLabel,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: scheme.primary.withValues(alpha: 0.8),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        final verses = mainProvider.verses
            .where((v) =>
                v.book == mainProvider.currentBook &&
                v.chapter == mainProvider.currentChapter)
            .toList()
          ..sort((a, b) => a.verse.compareTo(b.verse));
        final hasParagraphData = verses.any((v) => v.isParagraphStart == true);

        // Paragraph mode → always group so verses flow continuously in one RichText.
        //   - With paragraph metadata: group by isParagraphStart / reference type
        //   - Without metadata: the whole chapter becomes a single flowing paragraph
        // Verse-by-verse mode: one verse per item.
        List<List<Verse>> paragraphGroups;
        if (settings.paragraphMode) {
          paragraphGroups = _groupIntoParagraphs(verses);
        } else {
          paragraphGroups = verses.map((v) => [v]).toList();
        }

        // Build verse-to-item index map for scroll/jump.
        // Item 0 is the chapter header → groups start at item 1.
        final verseToItemMap = <int, int>{};
        final itemToVerseIndex = <int, int>{0: 0};
        int vIdx = 0;
        for (int g = 0; g < paragraphGroups.length; g++) {
          itemToVerseIndex[g + 1] = vIdx;
          for (int v = 0; v < paragraphGroups[g].length; v++) {
            verseToItemMap[vIdx] = g + 1;
            vIdx++;
          }
        }
        mainProvider.setVerseToItemMap(verseToItemMap);

        // final paragraphs = _groupVersesIntoParagraphs(verses);
        final currentVerse = mainProvider.currentVerse ??
            (verses.isNotEmpty ? verses.first : null);
        final isSelected = mainProvider.selectedVerses.isNotEmpty;
        final visibleItemIndex = _visibleItemIndex < 0
            ? 0
            : (_visibleItemIndex > paragraphGroups.length + 1
                ? paragraphGroups.length + 1
                : _visibleItemIndex);
        final rawVisibleVerseIndex = itemToVerseIndex[visibleItemIndex] ??
            (visibleItemIndex > paragraphGroups.length ? verses.length - 1 : 0);
        final visibleVerseIndex = verses.isEmpty
            ? 0
            : rawVisibleVerseIndex.clamp(0, verses.length - 1).toInt();
        final visibleVerse =
            verses.isEmpty ? currentVerse : verses[visibleVerseIndex];
        final chapterProgress = verses.isEmpty
            ? 0.0
            : ((visibleVerseIndex + 1) / verses.length)
                .clamp(0.0, 1.0)
                .toDouble();

        return SelectionContainer.disabled(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -300) {
                _goToNextChapter();
              } else if (velocity > 300) {
                _goToPreviousChapter();
              }
            },
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                systemNavigationBarColor: Theme.of(context).colorScheme.surface,
                systemNavigationBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
              ),
              child: Scaffold(
                body: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ScrollablePositionedList.builder(
                        // +1 for the chapter header (item 0)
                        // +1 for the trailing FAB-clearance spacer
                        itemCount: paragraphGroups.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return SizedBox(height: settings.fontSize * 0.5);
                          }
                          final groupIdx = index - 1;
                          if (groupIdx < paragraphGroups.length) {
                            final group = paragraphGroups[groupIdx];
                            int startIdx = 0;
                            for (int g = 0; g < groupIdx; g++) {
                              startIdx += paragraphGroups[g].length;
                            }
                            final isFirst = groupIdx == 0;
                            if (group.length == 1) {
                              return VerseWidget(
                                verse: group.first,
                                index: startIdx,
                                hasParagraphData: hasParagraphData,
                                isFirst: isFirst,
                              );
                            }
                            return ParagraphGroupWidget(
                              group: group,
                              startVerseIndex: startIdx,
                              isFirst: isFirst,
                            );
                          }
                          return const SizedBox(height: 120);
                        },
                        itemScrollController: mainProvider.itemScrollController,
                        itemPositionsListener:
                            mainProvider.itemPositionsListener,
                        scrollOffsetController:
                            mainProvider.scrollOffsetController,
                        scrollOffsetListener: mainProvider.scrollOffsetListener,
                      ),
                    ),
                    // Floating header: always shows book/chapter/version, search/settings
                    _FloatingHeader(
                        showBookInfo: currentVerse != null,
                        book: currentVerse?.book ?? '',
                        chapter: currentVerse?.chapter ?? 0,
                        version: mainProvider.currentVersion,
                        onBookTap: () {
                          mainProvider.clearSelectedVerses();
                          Get.to(
                            () => BooksPage(
                              chapterIdx:
                                  mainProvider.currentVerse?.chapter ?? 1,
                              bookIdx: mainProvider.currentVerse?.book ?? '',
                            ),
                            transition: Transition.leftToRight,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        onVersionSelected: (version) async {
                          final p = context.read<MainProvider>();
                          p.clearSelectedVerses();
                          final prevEn = toEnglish(p.currentBook);
                          p.setVersion(version);
                          await FetchVerses.execute(mainProvider: p);
                          await FetchBooks.execute(mainProvider: p);
                          if (p.verses.isEmpty) return;
                          final targetBook = prevEn == null
                              ? null
                              : translateBookName(prevEn, version);
                          final targetChapter = p.currentChapter;
                          final match = p.verses.firstWhere(
                            (v) =>
                                (targetBook == null || v.book == targetBook) &&
                                (targetChapter == null ||
                                    v.chapter == targetChapter),
                            orElse: () => p.verses.first,
                          );
                          p.setCurrentChapter(
                              book: match.book, chapter: match.chapter);
                          p.updateCurrentVerse(verse: match);
                          p.jumpToTop();
                          if (mounted) {
                            setState(() => _visibleItemIndex = 0);
                          }
                        },
                        onSearch: () {
                          mainProvider.clearSelectedVerses();
                          Get.to(
                            () => SearchPage(),
                            transition: Transition.rightToLeft,
                          );
                        },
                        onSettings: () {
                          mainProvider.clearSelectedVerses();
                          Get.to(() => SettingsPage());
                        },
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: isSelected
                          ? _SelectionActionBar(
                              selectedCount: mainProvider.selectedVerses.length,
                              anyHighlighted: mainProvider.selectedVerses
                                  .any((v) => mainProvider.isVerseHighlighted(v)),
                              onCopy: () => _copySelectedVerses(
                                mainProvider: mainProvider,
                                settings: settings,
                              ),
                              onClear: mainProvider.clearSelectedVerses,
                              onHighlight: (color) {
                                mainProvider.setHighlightsForVerses(
                                  verses: mainProvider.selectedVerses,
                                  color: color,
                                );
                                mainProvider.clearSelectedVerses();
                              },
                              onRemoveHighlight: () {
                                mainProvider.removeHighlightsForVerses(
                                  verses: mainProvider.selectedVerses,
                                );
                                mainProvider.clearSelectedVerses();
                              },
                            )
                          : _ReaderStatusBar(
                              verse: visibleVerse,
                              verseIndex: visibleVerseIndex,
                              verseCount: verses.length,
                              progress: chapterProgress,
                              versionLabel: shortBibleVersionLabel(
                                  mainProvider.currentVersion),
                              paragraphMode: settings.paragraphMode,
                              canGoPrevious: _hasPreviousChapter(mainProvider),
                              canGoNext: _hasNextChapter(mainProvider),
                              onPrevious: _goToPreviousChapter,
                              onNext: _goToNextChapter,
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

  void _goToNextChapter() {
    final provider = Provider.of<MainProvider>(context, listen: false);
    provider.clearSelectedVerses();
    final books = provider.books;
    final currentBook = provider.currentBook;
    final currentChapter = provider.currentChapter;
    if (currentBook == null || currentChapter == null) return;

    // 找到当前书卷在列表中的索引
    final bookIdx = books.indexWhere((b) => b.title == currentBook);
    if (bookIdx < 0) return;
    final chapters = books[bookIdx].chapters;
    final chapIdx = chapters.indexWhere((c) => c.title == currentChapter);
    String nextBook;
    int nextChap;
    if (chapIdx < chapters.length - 1) {
      nextBook = currentBook;
      nextChap = chapters[chapIdx + 1].title;
    } else if (bookIdx < books.length - 1) {
      final nextBookIdx = bookIdx + 1;
      nextBook = books[nextBookIdx].title;
      nextChap = books[nextBookIdx].chapters.first.title;
    } else {
      return;
    }

    _switchTo(provider, nextBook, nextChap);
  }

  void _goToPreviousChapter() {
    final provider = Provider.of<MainProvider>(context, listen: false);
    provider.clearSelectedVerses();
    final books = provider.books;
    final currentBook = provider.currentBook;
    final currentChapter = provider.currentChapter;
    if (currentBook == null || currentChapter == null) return;

    final bookIdx = books.indexWhere((b) => b.title == currentBook);
    if (bookIdx < 0) return;
    final chapters = books[bookIdx].chapters;
    final chapIdx = chapters.indexWhere((c) => c.title == currentChapter);
    String prevBook;
    int prevChap;
    if (chapIdx > 0) {
      prevBook = currentBook;
      prevChap = chapters[chapIdx - 1].title;
    } else if (bookIdx > 0) {
      final prevBookIdx = bookIdx - 1;
      prevBook = books[prevBookIdx].title;
      prevChap = books[prevBookIdx].chapters.last.title;
    } else {
      return;
    }

    _switchTo(provider, prevBook, prevChap);
  }

  void _switchTo(MainProvider provider, String book, int chap) {
    final matched = provider.verses
        .where((v) => v.book == book && v.chapter == chap)
        .toList();

    if (matched.isEmpty) return;
    provider.setCurrentChapter(book: book, chapter: chap);
    provider.updateCurrentVerse(verse: matched.first);
    provider.jumpToTop();
    if (mounted) {
      setState(() => _visibleItemIndex = 0);
    }
  }

  bool _hasNextChapter(MainProvider provider) {
    final currentBook = provider.currentBook;
    final currentChapter = provider.currentChapter;
    if (currentBook == null || currentChapter == null) return false;
    final bookIdx = provider.books.indexWhere((b) => b.title == currentBook);
    if (bookIdx < 0) return false;
    final chapters = provider.books[bookIdx].chapters;
    final chapIdx = chapters.indexWhere((c) => c.title == currentChapter);
    return chapIdx >= 0 &&
        (chapIdx < chapters.length - 1 || bookIdx < provider.books.length - 1);
  }

  bool _hasPreviousChapter(MainProvider provider) {
    final currentBook = provider.currentBook;
    final currentChapter = provider.currentChapter;
    if (currentBook == null || currentChapter == null) return false;
    final bookIdx = provider.books.indexWhere((b) => b.title == currentBook);
    if (bookIdx < 0) return false;
    final chapters = provider.books[bookIdx].chapters;
    final chapIdx = chapters.indexWhere((c) => c.title == currentChapter);
    return chapIdx >= 0 && (chapIdx > 0 || bookIdx > 0);
  }

  /// Groups consecutive inline verses into paragraph blocks.
  /// Paragraph-start verses begin a new group; reference verses get their own group.
  static List<List<Verse>> _groupIntoParagraphs(List<Verse> verses) {
    if (verses.isEmpty) return [];
    final groups = <List<Verse>>[];
    List<Verse> currentGroup = [];

    for (final verse in verses) {
      final startsNew =
          verse.isParagraphStart || verse.paragraphType == 'reference';
      if (startsNew && currentGroup.isNotEmpty) {
        groups.add(currentGroup);
        currentGroup = [];
      }
      currentGroup.add(verse);
    }
    if (currentGroup.isNotEmpty) groups.add(currentGroup);
    return groups;
  }
}

class _ReaderStatusBar extends StatelessWidget {
  final Verse? verse;
  final int verseIndex;
  final int verseCount;
  final double progress;
  final String versionLabel;
  final bool paragraphMode;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _ReaderStatusBar({
    required this.verse,
    required this.verseIndex,
    required this.verseCount,
    required this.progress,
    required this.versionLabel,
    required this.paragraphMode,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final statusFontSize = settings.fontSize.clamp(13.0, 16.0).toDouble();
    final detailFontSize = settings.fontSize.clamp(11.0, 13.0).toDouble();
    final modeLabel = paragraphMode
        ? (uiStrings['paragraphFlow']?[settings.locale] ?? 'Paragraph Flow')
        : (uiStrings['verseByVerse']?[settings.locale] ?? 'Verse by Verse');
    final versePosition = (uiStrings['versePosition']?[settings.locale] ??
            'Verse {current} of {total}')
        .replaceAll('{current}', verseCount == 0 ? '0' : '${verseIndex + 1}')
        .replaceAll('{total}', '$verseCount');
    final title = verse == null
        ? (uiStrings['bible']?[settings.locale] ?? 'Bible')
        : '${verse!.book} ${verse!.chapter}:${verse!.verseLabel}';
    final detail = '$versionLabel | $modeLabel | $versePosition';

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: uiStrings['previousChapter']?[settings.locale] ??
                        'Previous Chapter',
                    onPressed: canGoPrevious ? onPrevious : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: statusFontSize,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: detailFontSize,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: uiStrings['nextChapter']?[settings.locale] ??
                        'Next Chapter',
                    onPressed: canGoNext ? onNext : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final bool anyHighlighted;
  final VoidCallback onCopy;
  final VoidCallback onClear;
  final ValueChanged<int> onHighlight;
  final VoidCallback onRemoveHighlight;

  const _SelectionActionBar({
    required this.selectedCount,
    required this.anyHighlighted,
    required this.onCopy,
    required this.onClear,
    required this.onHighlight,
    required this.onRemoveHighlight,
  });

  static const _highlightColors = <int>[
    0xFFFFF176, // yellow
    0xFFA5D6A7, // green
    0xFF90CAF9, // blue
    0xFFF48FB1, // pink
    0xFFFFCC80, // orange
    0xFFCE93D8, // purple
  ];

  void _showColorPicker(BuildContext context) {
    final locale = context.read<AppSettings>().locale;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiStrings['highlightColor']?[locale] ?? 'Highlight color',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _highlightColors.map((argb) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onHighlight(argb);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Color(argb),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (anyHighlighted) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRemoveHighlight();
                  },
                  icon: const Icon(Icons.highlight_remove, size: 20),
                  label: Text(
                    uiStrings['removeHighlight']?[locale] ??
                        'Remove highlight',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final label =
        (uiStrings['selectedVerses']?[settings.locale] ?? '{count} selected')
            .replaceAll('{count}', '$selectedCount');
    final fontSize = settings.fontSize.clamp(13.0, 16.0).toDouble();

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              IconButton(
                tooltip:
                    uiStrings['clearSelection']?[settings.locale] ?? 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip:
                    uiStrings['highlight']?[settings.locale] ?? 'Highlight',
                onPressed: () => _showColorPicker(context),
                icon: const Icon(Icons.format_color_fill),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
                label: Text(
                  uiStrings['copySelection']?[settings.locale] ?? 'Copy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent top bar: book/chapter (tappable), version picker, search, settings.
/// Always visible with a solid background. All elements scale with font size.
class _FloatingHeader extends StatelessWidget {
  final bool showBookInfo;
  final String book;
  final int chapter;
  final String version;
  final VoidCallback onBookTap;
  final ValueChanged<String> onVersionSelected;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  const _FloatingHeader({
    required this.showBookInfo,
    required this.book,
    required this.chapter,
    required this.version,
    required this.onBookTap,
    required this.onVersionSelected,
    required this.onSearch,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final fontSize = settings.fontSize.clamp(14.0, 17.0).toDouble();
    final iconSize = settings.fontSize.clamp(18.0, 26.0).toDouble();
    final iconPad = (iconSize * 0.45).clamp(6.0, 10.0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Material(
          elevation: 1,
          shadowColor: scheme.shadow.withValues(alpha: 0.08),
          color: scheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                if (showBookInfo) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onBookTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Text(
                        '$book $chapter',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    position: PopupMenuPosition.under,
                    tooltip: uiStrings['changeVersion']?[settings.locale] ??
                        'Change Version',
                    itemBuilder: (context) => bibleVersions
                        .map((v) => PopupMenuItem(
                              value: v.value,
                              child: Text(v.menuLabel),
                            ))
                        .toList(),
                    onSelected: onVersionSelected,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        shortBibleVersionLabel(version),
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: fontSize * 0.85,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  onPressed: onSearch,
                  icon: Icon(Icons.search_rounded, size: iconSize),
                  padding: EdgeInsets.all(iconPad),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: onSettings,
                  icon: Icon(Icons.settings, size: iconSize),
                  padding: EdgeInsets.all(iconPad),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
