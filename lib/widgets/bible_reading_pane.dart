import 'dart:async';
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
import 'package:yswords/models/bible_map.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/books_page.dart';
import 'package:yswords/pages/map_viewer_page.dart';
import 'package:yswords/pages/search_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/map_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart'
    show translateBookName, toEnglish;
import 'package:yswords/widgets/highlights_sheet.dart';
import 'package:yswords/widgets/originals_sheet.dart';
import 'package:yswords/widgets/verse_widget.dart';
import 'package:yswords/widgets/paragraph_group_widget.dart';

class BibleReadingPane extends StatefulWidget {
  final bool showSidebarToggle;
  final bool sidebarOpen;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onToggleSplitView;
  final bool splitViewActive;
  final VoidCallback? onClose;
  final bool showSearchAndSettings;

  const BibleReadingPane({
    super.key,
    this.showSidebarToggle = false,
    this.sidebarOpen = false,
    this.onToggleSidebar,
    this.onToggleSplitView,
    this.splitViewActive = false,
    this.onClose,
    this.showSearchAndSettings = true,
  });

  @override
  State<BibleReadingPane> createState() => _BibleReadingPaneState();
}

class _BibleReadingPaneState extends State<BibleReadingPane> {
  MainProvider? _positionsProvider;
  int _visibleItemIndex = 0;
  bool _showVersePosition = false;
  Timer? _versePositionTimer;
  /// Pane-local messenger so SnackBars (e.g. the "Copied!" toast) appear
  /// only in the pane that triggered them. Without this, `ScaffoldMessenger
  /// .of(context)` resolves to the app-root messenger and the toast is
  /// shown over both panes in split view.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  /// Maps whose chapter range covers the current book + chapter exactly.
  List<BibleMap> _chapterMaps = [];

  /// Maps that mention the current book at all (any chapter range).
  /// Used as the fallback when [_chapterMaps] is empty so the user
  /// still gets a relevant suggestion (e.g. Acts 22 → Paul's journeys).
  List<BibleMap> _bookMaps = [];
  String _lastBookChapter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mainProvider = context.read<MainProvider>();
      _attachPositionsListener(mainProvider);
    });
  }

  @override
  void dispose() {
    _versePositionTimer?.cancel();
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
      _versePositionTimer?.cancel();
      _versePositionTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showVersePosition = false);
      });
      setState(() {
        _visibleItemIndex = nextIndex;
        _showVersePosition = true;
      });
    }
  }

  void _updateMapsForBookChapter(String book, int chapter) {
    final key = '$book:$chapter';
    if (key == _lastBookChapter) return;
    _lastBookChapter = key;
    final en = bookNameToEnglish[book] ?? book;
    Future.wait([
      MapService.mapsForBookChapter(en, chapter),
      MapService.mapsForBook(en),
    ]).then((results) {
      if (!mounted) return;
      // Discard a stale result if the user already switched chapters
      // while this Future was in flight — without this guard, an old
      // chapter's maps could overwrite the new chapter's maps and
      // briefly flicker the wrong fallback in the picker.
      if (_lastBookChapter != key) return;
      final chapterMaps = results[0];
      final bookMaps = results[1];
      // Subtract chapter matches so the "book" section only shows the
      // additional related maps and we don't render duplicates.
      final extraBookMaps = bookMaps
          .where((m) => !chapterMaps.any((c) => c.id == m.id))
          .toList();
      setState(() {
        _chapterMaps = chapterMaps;
        _bookMaps = extraBookMaps;
      });
    });
  }

  // ── Chapter navigation ──────────────────────────────────────────────

  void _goToNextChapter() {
    final provider = context.read<MainProvider>();
    provider.clearSelectedVerses();
    final books = provider.books;
    final currentBook = provider.currentBook;
    final currentChapter = provider.currentChapter;
    if (currentBook == null || currentChapter == null) return;

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
    final provider = context.read<MainProvider>();
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
    if (mounted) setState(() => _visibleItemIndex = 0);
  }

  // ── Copy / format helpers ───────────────────────────────────────────

  String _formattedSelectedVerses({required List<Verse> verses}) {
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
    final text =
        _formattedSelectedVerses(verses: mainProvider.selectedVerses);
    await ClipboardHelper.copyText(text);
    mainProvider.clearSelectedVerses();
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final copiedLabel =
        uiStrings['copied']?[settings.locale] ?? 'Copied!';
    _messengerKey.currentState?.showSnackBar(
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

  // ── Paragraph grouping ──────────────────────────────────────────────

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

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        _attachPositionsListener(mainProvider);

        // Show loading spinner when verses haven't been loaded yet
        if (mainProvider.verses.isEmpty && mainProvider.books.isEmpty) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final verses = mainProvider.verses
            .where((v) =>
                v.book == mainProvider.currentBook &&
                v.chapter == mainProvider.currentChapter)
            .toList()
          ..sort((a, b) => a.verse.compareTo(b.verse));
        final hasParagraphData =
            verses.any((v) => v.isParagraphStart == true);

        List<List<Verse>> paragraphGroups;
        if (settings.paragraphMode) {
          paragraphGroups = _groupIntoParagraphs(verses);
        } else {
          paragraphGroups = verses.map((v) => [v]).toList();
        }

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

        final currentVerse = mainProvider.currentVerse ??
            (verses.isNotEmpty ? verses.first : null);
        if (currentVerse != null) {
          _updateMapsForBookChapter(currentVerse.book, currentVerse.chapter);
        }
        final isSelected = mainProvider.selectedVerses.isNotEmpty;
        // Items: [chapter header(0), ...paragraphGroups, trailing spacer].
        // So valid item indices are 0 .. paragraphGroups.length + 1.
        final visibleItemIndex = _visibleItemIndex
            .clamp(0, paragraphGroups.length + 1)
            .toInt();
        final rawVisibleVerseIndex =
            itemToVerseIndex[visibleItemIndex] ??
                (visibleItemIndex > paragraphGroups.length
                    ? verses.length - 1
                    : 0);
        final visibleVerseIndex = verses.isEmpty
            ? 0
            : rawVisibleVerseIndex.clamp(0, verses.length - 1).toInt();
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
                systemNavigationBarColor:
                    Theme.of(context).colorScheme.surface,
                systemNavigationBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
              ),
              child: ScaffoldMessenger(
                key: _messengerKey,
                child: Scaffold(
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final paneWidth = constraints.maxWidth;
                    final dc = ResponsiveBreakpoints.classOf(paneWidth);
                    final isWideScreen = ResponsiveBreakpoints.isTabletOrWider(paneWidth);

                    return Stack(
                      children: [
                    Padding(
                      padding: EdgeInsets.only(
                        right: ResponsiveBreakpoints.readingPadding(dc),
                      ),
                      child: ScrollablePositionedList.builder(
                        itemCount: paragraphGroups.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final topInset =
                                MediaQuery.of(context).padding.top;
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
                          // Trailing spacer height matches whichever
                          // bottom bar is showing (selection action bar
                          // when verses are selected, otherwise the
                          // reader status bar). The selection bar is
                          // taller, so we pad more in that case to keep
                          // the last verse from being hidden under it.
                          final bottomInset =
                              MediaQuery.of(context).padding.bottom;
                          final extra = isSelected
                              ? 132 * settings.menuScale
                              : 96 * settings.menuScale;
                          return SizedBox(height: bottomInset + extra);
                        },
                        itemScrollController:
                            mainProvider.itemScrollController,
                        itemPositionsListener:
                            mainProvider.itemPositionsListener,
                        scrollOffsetController:
                            mainProvider.scrollOffsetController,
                        scrollOffsetListener:
                            mainProvider.scrollOffsetListener,
                      ),
                    ),
                    _FloatingHeader(
                      showBookInfo: currentVerse != null,
                      book: currentVerse?.book ?? '',
                      chapter: currentVerse?.chapter ?? 0,
                      version: mainProvider.currentVersion,
                      showSidebarToggle: widget.showSidebarToggle,
                      sidebarOpen: widget.sidebarOpen,
                      onToggleSidebar: widget.onToggleSidebar,
                      paragraphMode: settings.paragraphMode,
                      onToggleParagraphMode: () =>
                          settings.setParagraphMode(!settings.paragraphMode),
                      deviceClass: dc,
                      onToggleSplitView: widget.onToggleSplitView,
                      splitViewActive: widget.splitViewActive,
                      onClose: widget.onClose,
                      showSearchAndSettings: widget.showSearchAndSettings,
                      chapterMaps: _chapterMaps,
                      bookMaps: _bookMaps,
                      locale: settings.locale,
                      onBookTap: isWideScreen && widget.showSidebarToggle
                          ? () {
                              mainProvider.clearSelectedVerses();
                              widget.onToggleSidebar?.call();
                            }
                          : () {
                              mainProvider.clearSelectedVerses();
                              final chapter =
                                  mainProvider.currentVerse?.chapter ?? 1;
                              final book =
                                  mainProvider.currentVerse?.book ?? '';
                              final provider =
                                  context.read<MainProvider>();
                              Get.to(
                                () => BooksPage(
                                  chapterIdx: chapter,
                                  bookIdx: book,
                                  providerOverride: provider,
                                ),
                                transition: Transition.leftToRight,
                                duration:
                                    const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      onVersionSelected: (version) async {
                        if (!mounted) return;
                        final p = context.read<MainProvider>();
                        final messenger = _messengerKey.currentState;
                        p.clearSelectedVerses();
                        final prevEn = toEnglish(p.currentBook);
                        p.setVersion(version);
                        await FetchVerses.execute(mainProvider: p);
                        if (!mounted) return;
                        await FetchBooks.execute(mainProvider: p);
                        if (!mounted) return;
                        if (p.verses.isEmpty) {
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(
                                uiStrings['loadErrorBody']?[
                                        settings.locale] ??
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
                              (targetBook == null ||
                                  v.book == targetBook) &&
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
                      highlightCount:
                          mainProvider.highlights.length,
                      onHighlights: () => _showHighlightsSheet(
                        context: context,
                        highlights: mainProvider.highlights,
                        locale: settings.locale,
                      ),
                    ),
                    // Vertical position indicator on the right edge — a
                    // thin track + a small "current/total" pill that
                    // slides top-to-bottom as the user reads, then
                    // auto-fades after 2 s of inactivity.
                    if (!isSelected && verses.isNotEmpty)
                      Positioned(
                        right: ResponsiveBreakpoints.headerInset(dc) + 4,
                        top: MediaQuery.of(context).padding.top +
                            64 * settings.menuScale +
                            24,
                        bottom: MediaQuery.of(context).padding.bottom + 56,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _showVersePosition ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 400),
                            child: _VerticalProgressIndicator(
                              progress: chapterProgress,
                              currentLabel: '${visibleVerseIndex + 1}',
                              totalLabel: '${verses.length}',
                              fontFamily: settings.fontFamily,
                              menuScale: settings.menuScale,
                            ),
                          ),
                        ),
                      ),
                    // Bottom bar — selection actions or progress bar
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: isSelected
                          ? _SelectionActionBar(
                              selectedCount:
                                  mainProvider.selectedVerses.length,
                              anyHighlighted: mainProvider.selectedVerses
                                  .any((v) =>
                                      mainProvider.isVerseHighlighted(v)),
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
                              onOriginal: () => _showOriginalsSheet(
                                context: context,
                                verses: mainProvider.selectedVerses,
                                locale: settings.locale,
                              ),
                            )
                          : _ReaderStatusBar(
                              progress: chapterProgress,
                              deviceClass: dc,
                            ),
                    ),
                  ],
                );
                  },
                ),
              ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────

/// Thin vertical "scroll bookmark" on the right edge of the reader.
/// A small pill (e.g. `12 / 50`) slides top-to-bottom in lockstep with
/// the chapter progress. The whole widget is wrapped in an
/// [AnimatedOpacity] by the caller so it auto-fades after 2 s of
/// inactivity, matching the previous pill behavior.
class _VerticalProgressIndicator extends StatelessWidget {
  final double progress;
  final String currentLabel;
  final String totalLabel;
  final String fontFamily;
  final double menuScale;

  const _VerticalProgressIndicator({
    required this.progress,
    required this.currentLabel,
    required this.totalLabel,
    required this.fontFamily,
    required this.menuScale,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontSize = (10.0 * menuScale).clamp(9.0, 13.0).toDouble();

    return LayoutBuilder(builder: (ctx, constraints) {
      final h = constraints.maxHeight;
      final pillHeight = (22 * menuScale).clamp(20.0, 32.0).toDouble();
      // Anchor the pill so its center tracks the progress; clamp so it
      // never overflows the track.
      final clamped = progress.clamp(0.0, 1.0);
      final pillTop =
          (clamped * (h - pillHeight)).clamp(0.0, h - pillHeight).toDouble();

      return SizedBox(
        width: 56 * menuScale,
        height: h,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // Background track — full height.
            Positioned(
              right: 1,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Filled portion from the top down to the pill.
            Positioned(
              right: 1,
              top: 0,
              child: Container(
                width: 2,
                height: pillTop + pillHeight / 2,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Floating "current/total" pill.
            Positioned(
              right: 6,
              top: pillTop,
              child: Container(
                height: pillHeight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surface
                      .withValues(alpha: isDark ? 0.86 : 0.92),
                  borderRadius: BorderRadius.circular(pillHeight / 2),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.45),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.32 : 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: currentLabel,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' / $totalLabel',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ReaderStatusBar extends StatelessWidget {
  final double progress;
  final DeviceClass deviceClass;

  const _ReaderStatusBar({
    required this.progress,
    required this.deviceClass,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: (2.5 * settings.menuScale).clamp(2.0, 4.0),
          backgroundColor:
              scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          color: scheme.primary.withValues(alpha: 0.7),
        ),
        SizedBox(height: bottomInset),
      ],
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
              color: scheme.outlineVariant
                  .withValues(alpha: isDark ? 0.35 : 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.12),
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
  final VoidCallback onOriginal;
  final DeviceClass deviceClass;

  const _SelectionActionBar({
    required this.selectedCount,
    required this.anyHighlighted,
    required this.onCopy,
    required this.onClear,
    required this.onHighlight,
    required this.onRemoveHighlight,
    required this.onOriginal,
    required this.deviceClass,
  });

  static const _highlightColors = <int>[
    0xFFFFF176,
    0xFFA5D6A7,
    0xFF90CAF9,
    0xFFF48FB1,
    0xFFFFCC80,
    0xFFCE93D8,
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
                style: TextStyle(
                    fontSize: 16 * ms, fontWeight: FontWeight.w600),
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
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
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
    final fontSize =
        (settings.fontSize.clamp(11.0, 18.0) * settings.menuScale)
            .toDouble();
    final inset = ResponsiveBreakpoints.headerInset(deviceClass);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
        child: _GlassSurface(
          radius: 22,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12 * settings.menuScale,
                8 * settings.menuScale, 12 * settings.menuScale, 8 * settings.menuScale),
            child: Row(
              children: [
                IconButton(
                  tooltip: uiStrings['clearSelection']?[settings.locale] ??
                      'Clear',
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
                      uiStrings['originalText']?[settings.locale] ?? 'Original',
                  onPressed: onOriginal,
                  icon: const Icon(Icons.translate),
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

/// Shows the original Hebrew/Greek text for the currently selected
/// verses as a draggable bottom sheet. Tapping a word in the sheet
/// expands its Strong's lexicon entry below; tapping a concordance
/// reference closes the sheet and jumps the reader to that verse.
void _showOriginalsSheet({
  required BuildContext context,
  required List<Verse> verses,
  required String locale,
}) {
  if (verses.isEmpty) return;
  // Capture the provider synchronously — by the time the user taps a
  // concordance reference the sheet's BuildContext may be defunct, so
  // we rely on the provider reference instead.
  final mainProvider = context.read<MainProvider>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => OriginalsSheet(
      verses: verses,
      locale: locale,
      currentVersion: mainProvider.currentVersion,
      onNavigateRef: (ref) {
        Navigator.of(sheetCtx).maybePop();
        _navigateToConcordanceRef(
          mainProvider: mainProvider,
          ref: ref,
          locale: locale,
        );
      },
    ),
  );
}

void _showHighlightsSheet({
  required BuildContext context,
  required Map<String, int> highlights,
  required String locale,
}) {
  final mainProvider = context.read<MainProvider>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => HighlightsSheet(
      highlights: highlights,
      locale: locale,
      onNavigate: (englishBook, chapter, verse) {
        Navigator.of(sheetCtx).maybePop();
        final localBook =
            translateBookName(englishBook, mainProvider.currentVersion);
        final match = mainProvider.verses.where(
          (v) => v.book == localBook &&
              v.chapter == chapter &&
              v.verse == verse,
        );
        if (match.isEmpty) return;
        final v = match.first;
        mainProvider.setCurrentChapter(book: v.book, chapter: v.chapter);
        mainProvider.updateCurrentVerse(verse: v);
        Future.delayed(const Duration(milliseconds: 250), () {
          final chapterVerses = mainProvider.verses
              .where((cv) => cv.book == v.book && cv.chapter == v.chapter)
              .toList()
            ..sort((a, b) => a.verse.compareTo(b.verse));
          final relIdx = chapterVerses.indexWhere((cv) => cv.verse == v.verse);
          if (relIdx < 0) return;
          mainProvider.jumpToIndex(index: relIdx);
          mainProvider.setHighlightIndex(relIdx);
          Future.delayed(const Duration(milliseconds: 1200), () {
            mainProvider.clearHighlightIndex();
          });
        });
      },
    ),
  );
}

/// Jump the reader to a `ConcordanceRef` (e.g. "John 3:16") translated
/// into the current version's book naming. Mirrors the search-page
/// pattern: setCurrentChapter → updateCurrentVerse → jumpToIndex →
/// momentary highlight. Falls back silently when the verse isn't in
/// the current version (e.g. an OT ref while reading a NT-only edition).
void _navigateToConcordanceRef({
  required MainProvider mainProvider,
  required ConcordanceRef ref,
  required String locale,
}) {
  final localBook =
      translateBookName(ref.englishBook, mainProvider.currentVersion);
  final match = mainProvider.verses.where(
    (v) => v.book == localBook &&
        v.chapter == ref.chapter &&
        v.verse == ref.verse,
  );
  if (match.isEmpty) return;
  final verse = match.first;
  mainProvider.setCurrentChapter(book: verse.book, chapter: verse.chapter);
  mainProvider.updateCurrentVerse(verse: verse);
  Future.delayed(const Duration(milliseconds: 250), () {
    final chapterVerses = mainProvider.verses
        .where((v) => v.book == verse.book && v.chapter == verse.chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    final relIdx =
        chapterVerses.indexWhere((v) => v.verse == verse.verse);
    if (relIdx < 0) return;
    mainProvider.jumpToIndex(index: relIdx);
    mainProvider.setHighlightIndex(relIdx);
    Future.delayed(const Duration(milliseconds: 1200), () {
      mainProvider.clearHighlightIndex();
    });
  });
}

/// Shows the map picker as a tabbed sheet.
///
///   - "For this chapter" — exact chapter matches (highlighted; auto-
///     selected as the default tab when at least one exists).
///   - "For this book" — additional maps that mention this book.
///     Auto-selected when no chapter match exists, with a small note
///     explaining that nothing matches the exact chapter.
///   - "All maps" — the full library, always available so users can
///     browse even on chapters with zero matches (Judges, Job, etc.).
void _showMapPicker(
  BuildContext context, {
  required List<BibleMap> chapterMaps,
  required List<BibleMap> bookMaps,
  required String locale,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      return _MapPickerSheet(
        chapterMaps: chapterMaps,
        bookMaps: bookMaps,
        locale: locale,
      );
    },
  );
}

class _MapPickerSheet extends StatefulWidget {
  final List<BibleMap> chapterMaps;
  final List<BibleMap> bookMaps;
  final String locale;
  const _MapPickerSheet({
    required this.chapterMaps,
    required this.bookMaps,
    required this.locale,
  });

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<BibleMap> _allMaps = const [];
  bool _allLoading = true;

  // Tab indices that are visible in the current configuration.
  // The "Chapter" tab is hidden when there are no chapter matches —
  // so we don't waste a tab on an empty list.
  late final List<_MapTab> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs();
    // Auto-select the "book" tab when no chapter-specific match exists,
    // so the picker opens directly on the most useful list. Falls back
    // to index 0 (always valid) when the book tab isn't present. The
    // final clamp guarantees we never feed an out-of-range index to
    // TabController, even if _buildTabs() composition changes later.
    final bookIdx = _tabs.indexWhere((t) => t.kind == _MapTabKind.book);
    final initial = (widget.chapterMaps.isEmpty && bookIdx >= 0) ? bookIdx : 0;
    _tab = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initial.clamp(0, _tabs.length - 1),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final all = await MapService.loadMaps();
    if (!mounted) return;
    setState(() {
      _allMaps = all;
      _allLoading = false;
    });
  }

  List<_MapTab> _buildTabs() {
    final tabs = <_MapTab>[];
    if (widget.chapterMaps.isNotEmpty) {
      tabs.add(_MapTab(_MapTabKind.chapter,
          uiStrings['mapsForThisChapter']?[widget.locale] ??
              'For this chapter'));
    }
    if (widget.bookMaps.isNotEmpty) {
      tabs.add(_MapTab(_MapTabKind.book,
          uiStrings['mapsForThisBook']?[widget.locale] ?? 'For this book'));
    }
    tabs.add(_MapTab(
        _MapTabKind.all, uiStrings['mapsAll']?[widget.locale] ?? 'All maps'));
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaH = MediaQuery.of(context).size.height;
    final sheetHeight = mediaH * 0.7;

    return SizedBox(
      height: sheetHeight,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uiStrings['maps']?[widget.locale] ?? 'Maps',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: uiStrings['close']?[widget.locale] ?? 'Close',
                  ),
                ],
              ),
            ),
            // Tab strip — only render when there's more than one tab.
            if (_tabs.length > 1)
              TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final t in _tabs) Tab(text: t.label)],
              ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  for (final t in _tabs) _buildTabContent(t.kind),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(_MapTabKind kind) {
    switch (kind) {
      case _MapTabKind.chapter:
        return _mapList(widget.chapterMaps);
      case _MapTabKind.book:
        return Column(
          children: [
            if (widget.chapterMaps.isEmpty)
              _FallbackNote(
                text: uiStrings['mapsNoneForChapterFallback']
                        ?[widget.locale] ??
                    'No map specifically for this chapter — here are related maps:',
              ),
            Expanded(child: _mapList(widget.bookMaps)),
          ],
        );
      case _MapTabKind.all:
        if (_allLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return _mapList(_allMaps);
    }
  }

  Widget _mapList(List<BibleMap> maps) {
    if (maps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            uiStrings['noMapsForChapter']?[widget.locale] ??
                'No maps for this chapter',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: maps.length,
      itemBuilder: (ctx, i) => _MapTile(
        map: maps[i],
        locale: widget.locale,
        related: [
          ...widget.chapterMaps,
          ...widget.bookMaps,
        ],
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

enum _MapTabKind { chapter, book, all }

class _MapTab {
  final _MapTabKind kind;
  final String label;
  const _MapTab(this.kind, this.label);
}

class _FallbackNote extends StatelessWidget {
  final String text;
  const _FallbackNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  final BibleMap map;
  final String locale;
  final List<BibleMap> related;
  final VoidCallback onClose;
  const _MapTile({
    required this.map,
    required this.locale,
    required this.related,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 44,
          height: 44,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Image.asset(
            'assets/maps/${map.file}',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.map, size: 22, color: scheme.primary),
          ),
        ),
      ),
      title: Text(
        map.localizedTitle(locale),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: map.localizedDescription(locale).isNotEmpty
          ? Text(
              map.localizedDescription(locale),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            )
          : null,
      trailing:
          Icon(Icons.chevron_right_rounded, size: 20, color: scheme.outline),
      onTap: () {
        onClose();
        Get.to(() => MapViewerPage(
              map: map,
              locale: locale,
              relatedMaps: related,
            ));
      },
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  final bool showBookInfo;
  final String book;
  final int chapter;
  final String version;
  final VoidCallback onBookTap;
  final ValueChanged<String> onVersionSelected;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final bool showSidebarToggle;
  final bool sidebarOpen;
  final VoidCallback? onToggleSidebar;
  final bool paragraphMode;
  final VoidCallback? onToggleParagraphMode;
  final DeviceClass deviceClass;
  final VoidCallback? onToggleSplitView;
  final bool splitViewActive;
  final VoidCallback? onClose;
  final bool showSearchAndSettings;
  final List<BibleMap> chapterMaps;
  final List<BibleMap> bookMaps;
  final String locale;
  final int highlightCount;
  final VoidCallback? onHighlights;

  const _FloatingHeader({
    required this.showBookInfo,
    required this.book,
    required this.chapter,
    required this.version,
    required this.onBookTap,
    required this.onVersionSelected,
    required this.onSearch,
    required this.onSettings,
    this.showSidebarToggle = false,
    this.sidebarOpen = false,
    this.onToggleSidebar,
    this.paragraphMode = false,
    this.onToggleParagraphMode,
    required this.deviceClass,
    this.onToggleSplitView,
    this.splitViewActive = false,
    this.onClose,
    this.showSearchAndSettings = true,
    this.chapterMaps = const [],
    this.bookMaps = const [],
    this.locale = 'en',
    this.highlightCount = 0,
    this.onHighlights,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final fontSize =
        (settings.fontSize.clamp(12.0, 19.0) * settings.menuScale).toDouble();
    final iconSize =
        (settings.fontSize.clamp(16.0, 28.0) * settings.menuScale)
            .toDouble();
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
            padding: EdgeInsets.symmetric(
                horizontal: 6 * settings.menuScale,
                vertical: 4 * settings.menuScale),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onClose != null)
                        IconButton(
                          onPressed: onClose,
                          icon: Icon(Icons.close_rounded, size: iconSize),
                          padding: EdgeInsets.all(iconPad),
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          tooltip: 'Close',
                        ),
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
                          tooltip: uiStrings['changeVersion']
                                  ?[settings.locale] ??
                              'Change Version',
                          itemBuilder: (context) => availableVersions
                              .map((v) => PopupMenuItem(
                                    value: v.value,
                                    // Constrain + ellipsize so localized
                                    // long labels (e.g.
                                    // "原文释经圣经第二版 (繁)") never push
                                    // the popup past the screen edge.
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxWidth: 280),
                                      child: Text(
                                        v.menuLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onSelected: onVersionSelected,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              shortBibleVersionLabel(version),
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontSize: fontSize * 0.85,
                                fontWeight: FontWeight.w600,
                                color:
                                    scheme.primary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Right-side actions: Material 3 best practice — keep
                // the most-used action (Search) visible and consolidate
                // everything else into a single overflow menu so the
                // book/chapter label on the left has room to render
                // (avoids "马可..." truncation in narrow layouts and
                // split view).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showSearchAndSettings)
                      IconButton(
                        onPressed: onSearch,
                        icon: Icon(Icons.search_rounded, size: iconSize),
                        padding: EdgeInsets.all(iconPad),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        tooltip: uiStrings['search']?[locale] ?? 'Search',
                      ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: iconSize),
                      padding: EdgeInsets.all(iconPad),
                      tooltip: uiStrings['more']?[locale] ?? 'More',
                      position: PopupMenuPosition.under,
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<String>>[];
                        if (highlightCount > 0) {
                          items.add(PopupMenuItem(
                            value: 'highlights',
                            child: _menuRow(
                              context,
                              icon: Icons.bookmark_rounded,
                              iconColor: scheme.primary,
                              label: uiStrings['myHighlights']?[locale] ??
                                  'My Highlights',
                              trailing: highlightCount.toString(),
                            ),
                          ));
                        }
                        items.add(PopupMenuItem(
                          value: 'maps',
                          child: _menuRow(
                            context,
                            icon: chapterMaps.isNotEmpty
                                ? Icons.map_rounded
                                : Icons.map_outlined,
                            iconColor: chapterMaps.isNotEmpty
                                ? scheme.primary
                                : null,
                            label: uiStrings['maps']?[locale] ?? 'Maps',
                            trailing: chapterMaps.isNotEmpty
                                ? chapterMaps.length.toString()
                                : null,
                          ),
                        ));
                        if (onToggleSplitView != null) {
                          items.add(PopupMenuItem(
                            value: 'split',
                            child: _menuRow(
                              context,
                              icon: splitViewActive
                                  ? Icons.close_fullscreen
                                  : Icons.vertical_split,
                              label: splitViewActive
                                  ? (uiStrings['closeSplitView']?[locale] ??
                                      'Close Split View')
                                  : (uiStrings['openSplitView']?[locale] ??
                                      'Open Split View'),
                            ),
                          ));
                        }
                        if (showSidebarToggle &&
                            onToggleParagraphMode != null) {
                          items.add(PopupMenuItem(
                            value: 'paragraph',
                            child: _menuRow(
                              context,
                              icon: paragraphMode
                                  ? Icons.format_align_left
                                  : Icons.format_list_numbered_rounded,
                              iconColor:
                                  paragraphMode ? scheme.primary : null,
                              label: paragraphMode
                                  ? (uiStrings['paragraphFlow']?[locale] ??
                                      'Paragraph Flow')
                                  : (uiStrings['verseByVerse']?[locale] ??
                                      'Verse by Verse'),
                            ),
                          ));
                        }
                        if (showSearchAndSettings) {
                          items.add(const PopupMenuDivider());
                          items.add(PopupMenuItem(
                            value: 'settings',
                            child: _menuRow(
                              context,
                              icon: Icons.settings_outlined,
                              label: uiStrings['settings']?[locale] ??
                                  'Settings',
                            ),
                          ));
                        }
                        return items;
                      },
                      onSelected: (value) {
                        switch (value) {
                          case 'highlights':
                            onHighlights?.call();
                            break;
                          case 'maps':
                            _showMapPicker(
                              context,
                              chapterMaps: chapterMaps,
                              bookMaps: bookMaps,
                              locale: locale,
                            );
                            break;
                          case 'split':
                            onToggleSplitView?.call();
                            break;
                          case 'paragraph':
                            onToggleParagraphMode?.call();
                            break;
                          case 'settings':
                            onSettings();
                            break;
                        }
                      },
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

  /// Compact menu row used inside the overflow popup. The optional
  /// [trailing] string renders as a small count badge on the right.
  Widget _menuRow(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String label,
    String? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor ?? scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
