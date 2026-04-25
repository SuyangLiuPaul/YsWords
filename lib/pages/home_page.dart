import 'dart:ui';

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
import 'package:yswords/widgets/sidebar_panel.dart';
import 'package:yswords/widgets/stacked_card_nav.dart';
import 'package:yswords/utils/responsive.dart';
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
  bool _sidebarOpen = false;

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
    if (nextIndex != _visibleItemIndex && mounted) {
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
                body: LayoutBuilder(builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final isWideScreen = ResponsiveBreakpoints.isTabletOrWider(screenWidth);
                  final dc = ResponsiveBreakpoints.classOf(screenWidth);
                  final maxW = ResponsiveBreakpoints.maxContentWidth(dc);
                  final sidebarW = _sidebarOpen ? ResponsiveBreakpoints.sidebarWidth : 0.0;

                  Widget readingStack = Stack(
                    children: [
                    Padding(
                      padding: EdgeInsets.only(
                        right: ResponsiveBreakpoints.readingPadding(dc),
                      ),
                      child: ScrollablePositionedList.builder(
                        // +1 for the chapter header (item 0)
                        // +1 for the trailing FAB-clearance spacer
                        itemCount: paragraphGroups.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final topInset = MediaQuery.of(context).padding.top;
                            // Floating header occupies ~52 px plus the top
                            // safe-area inset. Add an 8 px breathing gap so
                            // the first verse never tucks under the header.
                            return SizedBox(
                                height:
                                    topInset + 64 * settings.menuScale + 12);
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
                          // Trailing clearance so the last verse is not
                          // tucked under _ReaderStatusBar. The status bar
                          // itself is ~85–100 px plus the device bottom
                          // safe-area inset, so we add both here and scale
                          // with menu size for larger UI settings.
                          final bottomInset =
                              MediaQuery.of(context).padding.bottom;
                          return SizedBox(
                              height: bottomInset + 96 * settings.menuScale);
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
                      onAddLayer: StackedCardScaffold.maybeOf(context)
                                  ?.canAddLayer ==
                              true
                          ? StackedCardScaffold.maybeOf(context)!
                              .requestAddLayer
                          : null,
                      onSwitchLayer: StackedCardScaffold.maybeOf(context)
                                  ?.hasOverlays ==
                              true
                          ? StackedCardScaffold.maybeOf(context)!
                              .showLayerSwitcher
                          : null,
                      openPageCount:
                          (StackedCardScaffold.maybeOf(context)?.overlayCount ??
                                  0) +
                              1,
                      showSidebarToggle: isWideScreen,
                      sidebarOpen: _sidebarOpen,
                      onToggleSidebar: _toggleSidebar,
                      paragraphMode: settings.paragraphMode,
                      onToggleParagraphMode: () =>
                          settings.setParagraphMode(!settings.paragraphMode),
                      deviceClass: dc,
                      onBookTap: isWideScreen
                          ? () {
                              mainProvider.clearSelectedVerses();
                              _toggleSidebar();
                            }
                          : () {
                              mainProvider.clearSelectedVerses();
                              final chapter =
                                  mainProvider.currentVerse?.chapter ?? 1;
                              final book =
                                  mainProvider.currentVerse?.book ?? '';
                              final stack =
                                  StackedCardScaffold.maybeOf(context);
                              if (stack != null) {
                                stack.push(
                                  (_) => BooksPage(
                                    chapterIdx: chapter,
                                    bookIdx: book,
                                  ),
                                  label:
                                      uiStrings['bibleBooks']?[settings.locale] ??
                                          'Bible Books',
                                  icon: Icons.menu_book_rounded,
                                );
                              } else {
                                Get.to(
                                  () => BooksPage(
                                    chapterIdx: chapter,
                                    bookIdx: book,
                                  ),
                                  transition: Transition.leftToRight,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                      onVersionSelected: (version) async {
                        final p = context.read<MainProvider>();
                        final messenger = ScaffoldMessenger.of(context);
                        p.clearSelectedVerses();
                        final prevEn = toEnglish(p.currentBook);
                        p.setVersion(version);
                        await FetchVerses.execute(mainProvider: p);
                        await FetchBooks.execute(mainProvider: p);
                        if (p.verses.isEmpty) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                uiStrings['loadErrorBody']?[settings.locale] ??
                                    'Could not load verses. Please retry.',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          return;
                        }
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
                        final stack = StackedCardScaffold.maybeOf(context);
                        if (stack != null) {
                          stack.push(
                            (_) => SearchPage(),
                            label:
                                uiStrings['search']?[settings.locale] ??
                                    'Search',
                            icon: Icons.search_rounded,
                          );
                        } else {
                          Get.to(
                            () => SearchPage(),
                            transition: Transition.rightToLeft,
                          );
                        }
                      },
                      onSettings: () {
                        mainProvider.clearSelectedVerses();
                        final stack = StackedCardScaffold.maybeOf(context);
                        if (stack != null) {
                          stack.push(
                            (_) => SettingsPage(),
                            label:
                                uiStrings['settings']?[settings.locale] ??
                                    'Settings',
                            icon: Icons.settings_rounded,
                          );
                        } else {
                          Get.to(() => SettingsPage());
                        }
                      },
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: isSelected
                          ? _SelectionActionBar(
                              selectedCount: mainProvider.selectedVerses.length,
                              anyHighlighted: mainProvider.selectedVerses.any(
                                  (v) => mainProvider.isVerseHighlighted(v)),
                              deviceClass: dc,
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
                              onToggleParagraphMode: () =>
                                  settings.setParagraphMode(!settings.paragraphMode),
                              deviceClass: dc,
                            ),
                    ),
                  ],
                  );

                  if (!isWideScreen) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: readingStack,
                      ),
                    );
                  }

                  return Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        width: sidebarW,
                        child: ClipRect(
                          child: _sidebarOpen
                              ? SidebarPanel(
                                  currentBook: mainProvider.currentBook ?? '',
                                  currentChapter: mainProvider.currentChapter ?? 1,
                                  onChapterSelected: _onSidebarChapterSelected,
                                  onClose: _toggleSidebar,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxW),
                            child: readingStack,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
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

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
  }

  void _onSidebarChapterSelected(String book, int chapter) {
    final provider = Provider.of<MainProvider>(context, listen: false);
    final matched = provider.verses
        .where((v) => v.book == book && v.chapter == chapter)
        .toList();
    if (matched.isEmpty) return;
    provider.setCurrentChapter(book: book, chapter: chapter);
    provider.updateCurrentVerse(verse: matched.first);
    provider.jumpToTop();
    setState(() {
      _sidebarOpen = false;
      _visibleItemIndex = 0;
    });
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
  final VoidCallback? onToggleParagraphMode;
  final DeviceClass deviceClass;

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
    this.onToggleParagraphMode,
    required this.deviceClass,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final detailFontSize =
        (settings.fontSize.clamp(10.0, 16.0) * settings.menuScale).toDouble();
    final modeLabel = paragraphMode
        ? (uiStrings['paragraphFlow']?[settings.locale] ?? 'Paragraph Flow')
        : (uiStrings['verseByVerse']?[settings.locale] ?? 'Verse by Verse');
    final versePosition = (uiStrings['versePosition']?[settings.locale] ??
            'Verse {current} of {total}')
        .replaceAll('{current}', verseCount == 0 ? '0' : '${verseIndex + 1}')
        .replaceAll('{total}', '$verseCount');
    final inset = ResponsiveBreakpoints.headerInset(deviceClass);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
        child: _GlassSurface(
          radius: 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: (3 * settings.menuScale).clamp(2.5, 6.0),
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  color: scheme.primary,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8 * settings.menuScale, 6 * settings.menuScale, 8 * settings.menuScale, 8 * settings.menuScale),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: uiStrings['previousChapter']?[settings.locale] ??
                          'Previous Chapter',
                      onPressed: canGoPrevious ? onPrevious : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: onToggleParagraphMode,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '$versionLabel • '),
                                  TextSpan(
                                    text: modeLabel,
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                style: TextStyle(
                                  fontFamily: settings.fontFamily,
                                  fontSize: detailFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              versePosition,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontSize: detailFontSize * 0.88,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
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
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;

  const _GlassSurface({
    required this.child,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color:
                  scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
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
  final DeviceClass deviceClass;

  const _SelectionActionBar({
    required this.selectedCount,
    required this.anyHighlighted,
    required this.onCopy,
    required this.onClear,
    required this.onHighlight,
    required this.onRemoveHighlight,
    required this.deviceClass,
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
    final settings = context.read<AppSettings>();
    final locale = settings.locale;
    final ms = settings.menuScale;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16 * ms),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiStrings['highlightColor']?[locale] ?? 'Highlight color',
                style: TextStyle(fontSize: 16 * ms, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16 * ms),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _highlightColors.map((argb) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onHighlight(argb);
                    },
                    child: Container(
                      width: 44 * ms,
                      height: 44 * ms,
                      margin: EdgeInsets.symmetric(horizontal: 6 * ms),
                      decoration: BoxDecoration(
                        color: Color(argb),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (anyHighlighted) ...[
                SizedBox(height: 12 * ms),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRemoveHighlight();
                  },
                  icon: Icon(Icons.highlight_remove, size: 20 * ms),
                  label: Text(
                    uiStrings['removeHighlight']?[locale] ?? 'Remove highlight',
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
    final fontSize =
        (settings.fontSize.clamp(11.0, 18.0) * settings.menuScale).toDouble();
    final inset = ResponsiveBreakpoints.headerInset(deviceClass);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
        child: _GlassSurface(
          radius: 22,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12 * settings.menuScale, 8 * settings.menuScale, 12 * settings.menuScale, 8 * settings.menuScale),
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
                Flexible(
                  child: FilledButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(
                      uiStrings['copySelection']?[settings.locale] ?? 'Copy',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
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
  final VoidCallback? onAddLayer;
  final VoidCallback? onSwitchLayer;
  final int openPageCount;
  final bool showSidebarToggle;
  final bool sidebarOpen;
  final VoidCallback? onToggleSidebar;
  final bool paragraphMode;
  final VoidCallback? onToggleParagraphMode;
  final DeviceClass deviceClass;

  const _FloatingHeader({
    required this.showBookInfo,
    required this.book,
    required this.chapter,
    required this.version,
    required this.onBookTap,
    required this.onVersionSelected,
    required this.onSearch,
    required this.onSettings,
    this.onAddLayer,
    this.onSwitchLayer,
    this.openPageCount = 1,
    this.showSidebarToggle = false,
    this.sidebarOpen = false,
    this.onToggleSidebar,
    this.paragraphMode = false,
    this.onToggleParagraphMode,
    required this.deviceClass,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final fontSize =
        (settings.fontSize.clamp(12.0, 19.0) * settings.menuScale).toDouble();
    final iconSize =
        (settings.fontSize.clamp(16.0, 28.0) * settings.menuScale).toDouble();
    final iconPad = (iconSize * 0.45).clamp(6.0, 10.0);

    final inset = ResponsiveBreakpoints.headerInset(deviceClass);

    return Positioned(
      top: 0,
      left: inset,
      right: inset,
      child: SafeArea(
        bottom: false,
        child: _GlassSurface(
          radius: 22,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6 * settings.menuScale, vertical: 4 * settings.menuScale),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSidebarToggle)
                        IconButton(
                          onPressed: onToggleSidebar,
                          icon: Icon(
                            sidebarOpen
                                ? Icons.chevron_left_rounded
                                : Icons.menu_book_rounded,
                            size: iconSize,
                          ),
                          padding: EdgeInsets.all(iconPad),
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          tooltip: sidebarOpen
                              ? (uiStrings['close']?[settings.locale] ??
                                  'Close')
                              : (uiStrings['bibleBooks']?[settings.locale] ??
                                  'Bible Books'),
                        ),
                      if (showBookInfo) ...[
                        Flexible(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onBookTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Text(
                                '$book $chapter',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: settings.fontFamily,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          position: PopupMenuPosition.under,
                          tooltip:
                              uiStrings['changeVersion']?[settings.locale] ??
                                  'Change Version',
                          itemBuilder: (context) => availableVersions
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
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showSidebarToggle && onToggleParagraphMode != null)
                      IconButton(
                        onPressed: onToggleParagraphMode,
                        icon: Icon(
                          paragraphMode
                              ? Icons.format_align_left
                              : Icons.format_list_numbered_rounded,
                          size: iconSize,
                        ),
                        padding: EdgeInsets.all(iconPad),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        tooltip: paragraphMode
                            ? (uiStrings['paragraphFlow']?[settings.locale] ??
                                'Paragraph Flow')
                            : (uiStrings['verseByVerse']?[settings.locale] ??
                                'Verse by Verse'),
                      ),
                    if (onAddLayer != null)
                      IconButton(
                        onPressed: onAddLayer,
                        icon:
                            Icon(Icons.library_add_rounded, size: iconSize),
                        padding: EdgeInsets.all(iconPad),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        tooltip: uiStrings['openAnotherChapter']
                                ?[settings.locale] ??
                            'Open another chapter',
                      ),
                    if (onSwitchLayer != null)
                      IconButton(
                        onPressed: onSwitchLayer,
                        icon: Badge(
                          label: Text('$openPageCount'),
                          child:
                              Icon(Icons.layers_rounded, size: iconSize),
                        ),
                        padding: EdgeInsets.all(iconPad),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        tooltip: uiStrings['switchPage']?[settings.locale] ??
                            'Switch page',
                      ),
                    IconButton(
                      onPressed: onSearch,
                      icon: Icon(Icons.search_rounded, size: iconSize),
                      padding: EdgeInsets.all(iconPad),
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      onPressed: onSettings,
                      icon: Icon(Icons.settings, size: iconSize),
                      padding: EdgeInsets.all(iconPad),
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
