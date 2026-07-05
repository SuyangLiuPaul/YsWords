import 'dart:ui';

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
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart' show toEnglish;
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

class BookChapterPicker extends StatefulWidget {
  final String currentBook;
  final int currentChapter;
  final void Function(String book, int chapter) onChapterSelected;

  const BookChapterPicker({
    super.key,
    required this.currentBook,
    required this.currentChapter,
    required this.onChapterSelected,
  });

  @override
  State<BookChapterPicker> createState() => _BookChapterPickerState();
}

class _BookChapterPickerState extends State<BookChapterPicker> {
  final AutoScrollController _autoScrollController = AutoScrollController();
  bool showOldTestament = true;
  bool hasOldTestament = false;
  bool hasNewTestament = false;
  bool _initialScrollDone = false;

  Map<String, bool> expandStatus = {};
  String? _gridSelectedBook;

  /// Round 56: when the user picks a chapter we transition the
  /// picker IN-PLACE to a verse grid for that chapter (instead of
  /// firing onChapterSelected immediately). Tracks the chapter
  /// being verse-picked. Null = books/chapters mode.
  String? _verseStepBook;
  int? _verseStepChapter;

  @override
  void dispose() {
    _autoScrollController.dispose();
    super.dispose();
  }

  /// 2026-05-22 (v1.2.76): when the reading pane navigates to a new
  /// book/chapter (next/prev arrows, search, history, cross-ref jump
  /// from another tab), the parent rebuilds this widget with new
  /// `currentBook`/`currentChapter` props but the local
  /// `_verseStepBook`/`_verseStepChapter` state still points at the
  /// previous chapter — so the iPad split-view sidebar continues
  /// showing the OLD verse grid (e.g. "使徒行传 12" while the right
  /// pane reads 列王纪上 18). Reset the verse-step whenever the
  /// effective book/chapter changes so the picker stays in sync
  /// with the active reading pane.
  @override
  void didUpdateWidget(covariant BookChapterPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bookChanged = oldWidget.currentBook != widget.currentBook;
    final chapterChanged = oldWidget.currentChapter != widget.currentChapter;
    if (!bookChanged && !chapterChanged) return;

    // Decide what to do with each piece of local state, then commit
    // all changes in a single setState at the end. Single batched
    // rebuild is cheaper and avoids three back-to-back frame schedules.
    bool? newShowOldTestament;
    String? newVerseStepBook = _verseStepBook;
    int? newVerseStepChapter = _verseStepChapter;
    String? newGridSelectedBook = _gridSelectedBook;
    final newExpand = Map<String, bool>.from(expandStatus);
    bool anyChange = false;

    final inVerseStep =
        _verseStepBook != null && _verseStepChapter != null;
    if (inVerseStep) {
      if (_verseStepBook == widget.currentBook && chapterChanged) {
        // Same book, different chapter (Prev/Next button on the
        // reading pane). Keep the user in verse-step but follow into
        // the new chapter's verse grid. This matches user intent:
        // they opened verse-step to pick from this book; navigating
        // chapters in the pane should slide the grid forward, not
        // bounce them back out to the chapters strip.
        newVerseStepChapter = widget.currentChapter;
        anyChange = true;
      } else if (_verseStepBook != widget.currentBook) {
        // Cross-book navigation (search/cross-ref/history) — the
        // verse-step is no longer relevant. Drop it so the user
        // doesn't see "使徒行传 12" verses while reading 列王纪上.
        newVerseStepBook = null;
        newVerseStepChapter = null;
        anyChange = true;
      }
    }

    // Grid mode: drop the drill-in if the reading pane jumped to a
    // different book.
    if (_gridSelectedBook != null &&
        _gridSelectedBook != widget.currentBook) {
      newGridSelectedBook = null;
      anyChange = true;
    }

    // Expansion state — collapse the old book's chapter strip and
    // expand the new one so the sidebar updates to surface where the
    // reader currently is.
    if (bookChanged && widget.currentBook.isNotEmpty) {
      if (newExpand.containsKey(oldWidget.currentBook)) {
        newExpand[oldWidget.currentBook] = false;
      }
      if (newExpand.containsKey(widget.currentBook)) {
        newExpand[widget.currentBook] = true;
      }
      final newBookEntry = Provider.of<MainProvider>(context, listen: false)
          .books
          .firstWhereOrNull((b) => b.title == widget.currentBook);
      if (newBookEntry != null) {
        newShowOldTestament = _isOldTestament(newBookEntry.title);
      }
      anyChange = true;
    }

    if (!anyChange) return;

    setState(() {
      _verseStepBook = newVerseStepBook;
      _verseStepChapter = newVerseStepChapter;
      _gridSelectedBook = newGridSelectedBook;
      expandStatus
        ..clear()
        ..addAll(newExpand);
      if (newShowOldTestament != null) showOldTestament = newShowOldTestament;
    });

    // After the testament tab / current book changed, re-run the
    // initial-scroll handshake so the list view scrolls to the new
    // current book on the next frame. Cheap one-off — the same
    // post-frame callback the initState path uses.
    if (bookChanged && widget.currentBook.isNotEmpty) {
      _initialScrollDone = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialScrollDone) return;
        final mainProvider =
            Provider.of<MainProvider>(context, listen: false);
        final filtered = mainProvider.books
            .where((b) => showOldTestament
                ? _isOldTestament(b.title)
                : !_isOldTestament(b.title))
            .toList();
        final idx =
            filtered.indexWhere((b) => b.title == widget.currentBook);
        final currentSettings =
            Provider.of<AppSettings>(context, listen: false);
        if (idx != -1 &&
            currentSettings.booksViewMode != 'grid' &&
            _autoScrollController.hasClients) {
          _autoScrollController.scrollToIndex(
            idx,
            preferPosition: AutoScrollPosition.begin,
            duration: const Duration(milliseconds: 250),
          );
        }
        _initialScrollDone = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final mainProvider = Provider.of<MainProvider>(context, listen: false);

    final bookTitlesEng = mainProvider.books
        .map<String>((b) => toEnglish(b.title) ?? b.title)
        .toSet();

    hasOldTestament = bookTitlesEng.any(
      (b) => oldTestamentBooks.contains(b),
    );
    hasNewTestament = bookTitlesEng.any(
      (b) => newTestamentBooks.contains(b),
    );

    showOldTestament = hasOldTestament;

    for (var book in mainProvider.books) {
      expandStatus[book.title] = false;
    }

    if (widget.currentBook.isNotEmpty &&
        expandStatus.containsKey(widget.currentBook)) {
      expandStatus[widget.currentBook] = true;
    }

    final verseBook = widget.currentBook;
    final bookEntry =
        mainProvider.books.firstWhereOrNull((b) => b.title == verseBook);
    if (bookEntry != null) {
      showOldTestament = _isOldTestament(bookEntry.title);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialScrollDone) {
          final filtered = mainProvider.books
              .where((b) => showOldTestament
                  ? _isOldTestament(b.title)
                  : !_isOldTestament(b.title))
              .toList();
          final idx = filtered.indexWhere((b) => b.title == bookEntry.title);
          // Only scroll when the list view is actually rendered.
          // In grid mode the AutoScrollController is unattached.
          final currentSettings =
              Provider.of<AppSettings>(context, listen: false);
          if (idx != -1 && currentSettings.booksViewMode != 'grid') {
            Future.microtask(() {
              if (mounted && _autoScrollController.hasClients) {
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
        // 2026-06-28: keep the testament toggle in sync with the CURRENT
        // version. `hasOldTestament`/`hasNewTestament` used to be computed
        // once in initState, so switching to a NT-only edition (LJK1/LJK2)
        // left the 希伯来圣经 button showing — and selected — even though
        // that version ships no OT (user report: "open another version and
        // top those not updated"). didUpdateWidget also early-returns when
        // only the version changed (same book/chapter), so the toggle never
        // refreshed. Recompute every build (cheap set-membership over the
        // book list) from this Consumer's live `mainProvider.books`, then
        // clamp `showOldTestament` to a testament that actually has books.
        final bookTitlesEng = mainProvider.books
            .map<String>((b) => toEnglish(b.title) ?? b.title)
            .toSet();
        hasOldTestament =
            bookTitlesEng.any((b) => oldTestamentBooks.contains(b));
        hasNewTestament =
            bookTitlesEng.any((b) => newTestamentBooks.contains(b));
        if (showOldTestament && !hasOldTestament && hasNewTestament) {
          showOldTestament = false;
        } else if (!showOldTestament && !hasNewTestament && hasOldTestament) {
          showOldTestament = true;
        }

        // Round 56: when a chapter has been picked, switch the entire
        // picker contents to the verse-grid step. Books / chapters
        // disappear; user gets a focused full-width grid of every
        // verse in the chosen chapter, plus a back button to return
        // to chapters and a "Top of chapter" tile to skip verse-pick.
        if (_verseStepBook != null && _verseStepChapter != null) {
          return _buildVerseStep(
            context: context,
            mainProvider: mainProvider,
            settings: settings,
          );
        }

        final books = mainProvider.books;
        final filteredBooks = books.where((book) {
          return showOldTestament
              ? _isOldTestament(book.title)
              : !_isOldTestament(book.title);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: BooksGlassSurface(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, barConstraints) {
                      final isNarrow = barConstraints.maxWidth < 300;

                      final viewToggle = ToggleButtons(
                        isSelected: [
                          settings.booksViewMode != 'grid',
                          settings.booksViewMode == 'grid',
                        ],
                        onPressed: (index) {
                          final target = index == 1 ? 'grid' : 'list';
                          settings.setBooksViewMode(target);
                          setState(() {
                            _gridSelectedBook = null;
                            expandStatus.updateAll((key, _) => false);
                            // Re-expand the current book so list view
                            // doesn't appear empty after switching from grid.
                            if (target == 'list' &&
                                widget.currentBook.isNotEmpty) {
                              expandStatus[widget.currentBook] = true;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        constraints: BoxConstraints(
                            minWidth: 42 * settings.menuScale, minHeight: 36 * settings.menuScale),
                        children: [
                          Tooltip(
                            message: uiStrings['listView']
                                    ?[settings.locale] ??
                                'List',
                            child: Icon(Icons.list_rounded,
                                size: settings.fontSize * 1.05),
                          ),
                          Tooltip(
                            message: uiStrings['gridView']
                                    ?[settings.locale] ??
                                'Grid',
                            child: Icon(Icons.grid_view_rounded,
                                size: settings.fontSize * 1.05),
                          ),
                        ],
                      );

                      // Always use the full label — Hebrew Bible /
                      // Greek Bible / 希伯来圣经 / 希腊圣经. The button
                      // text uses FittedBox(scaleDown) (see
                      // _testamentButton) so the label is shrunk to
                      // fit when the button is narrow rather than
                      // truncated with an invisible "…" that made
                      // "希伯来圣经" look like "希伯来圣" and
                      // "Hebrew Bible" look like "Hebrew".
                      final otLabel =
                          uiStrings['oldTestament']?[settings.locale] ??
                              'Hebrew Bible';
                      final ntLabel =
                          uiStrings['newTestament']?[settings.locale] ??
                              'Greek Bible';

                      if (isNarrow) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasOldTestament && hasNewTestament)
                              Row(
                                children: [
                                  Expanded(
                                    child: _testamentButton(
                                      context: context,
                                      settings: settings,
                                      selected: showOldTestament,
                                      label: otLabel,
                                      onPressed: () =>
                                          _setTestament(settings, true),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _testamentButton(
                                      context: context,
                                      settings: settings,
                                      selected: !showOldTestament,
                                      label: ntLabel,
                                      onPressed: () =>
                                          _setTestament(settings, false),
                                    ),
                                  ),
                                ],
                              ),
                            if (hasOldTestament && hasNewTestament)
                              const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [viewToggle],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          if (hasOldTestament && hasNewTestament)
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    if (hasOldTestament)
                                      _testamentButton(
                                        context: context,
                                        settings: settings,
                                        selected: showOldTestament,
                                        label:
                                            uiStrings['oldTestament']
                                                    ?[settings.locale] ??
                                                'Hebrew Bible',
                                        onPressed: () =>
                                            _setTestament(settings, true),
                                      ),
                                    if (hasOldTestament && hasNewTestament)
                                      const SizedBox(width: 10),
                                    if (hasNewTestament)
                                      _testamentButton(
                                        context: context,
                                        settings: settings,
                                        selected: !showOldTestament,
                                        label:
                                            uiStrings['newTestament']
                                                    ?[settings.locale] ??
                                                'Greek Bible',
                                        onPressed: () =>
                                            _setTestament(settings, false),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 8),
                          viewToggle,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: settings.booksViewMode == 'grid'
                  ? _buildGridView(
                      context, mainProvider, settings, filteredBooks)
                  : _buildListView(
                      context, mainProvider, settings, filteredBooks),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectChapter(
      MainProvider mainProvider, String bookTitle, int chapter) async {
    // Round 56: ALWAYS transition to the in-place verse-grid step
    // (no Settings toggle — the user wants this as default UX,
    // mirroring how YouVersion / Bible Hub etc. flow). Setting
    // these state fields swaps the picker view from books+chapters
    // to a full verse grid for the picked chapter.
    setState(() {
      _verseStepBook = bookTitle;
      _verseStepChapter = chapter;
    });
  }

  /// Called when the user picks a verse on the in-place verse grid.
  /// Sets a pendingJump and fires the original onChapterSelected so
  /// the host page (BooksPage / sidebar) closes the picker and
  /// navigates the reader. `verseNum == 0` means "top of chapter".
  void _onVersePicked(MainProvider mainProvider, int verseNum) {
    final book = _verseStepBook;
    final chapter = _verseStepChapter;
    if (book == null || chapter == null) return;
    if (verseNum > 0) {
      final chapterVerses = mainProvider.verses
          .where((v) => v.book == book && v.chapter == chapter)
          .toList()
        ..sort((a, b) => a.verse.compareTo(b.verse));
      final relIdx = chapterVerses.indexWhere((v) => v.verse == verseNum);
      if (relIdx >= 0) {
        mainProvider.setPendingJump(chapterVerseIndex: relIdx);
      }
    }
    widget.onChapterSelected(book, chapter);
  }

  void _backFromVerseStep() {
    setState(() {
      _verseStepBook = null;
      _verseStepChapter = null;
    });
  }

  /// Verse-grid step. Full-width responsive grid of all verse
  /// numbers in the chosen chapter. Tap a number → onVersePicked.
  /// Tap "Top of chapter" → onVersePicked(0) (skip verse pick).
  /// Tap back arrow → returns to books/chapters view.
  Widget _buildVerseStep({
    required BuildContext context,
    required MainProvider mainProvider,
    required AppSettings settings,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final book = _verseStepBook!;
    final chapter = _verseStepChapter!;
    final verses = mainProvider.verses
        .where((v) => v.book == book && v.chapter == chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: BooksGlassSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip:
                        uiStrings['back']?[locale] ?? 'Back',
                    onPressed: _backFromVerseStep,
                  ),
                  Expanded(
                    child: Text(
                      uiStrings['versePickerTitle']?[locale] ??
                          'Pick a verse',
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: settings.fontSize,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$book  $chapter',
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: (settings.fontSize - 2).clamp(12.0, 16.0),
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: LayoutBuilder(
              builder: (gridCtx, constraints) {
                final w = constraints.maxWidth;
                final cols = w < 360
                    ? 6
                    : w < 480
                        ? 7
                        : w < 640
                            ? 8
                            : w < 800
                                ? 10
                                : 12;
                const gap = 6.0;
                final tileW = (w - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: tileW * 2 + gap,
                      child: _VersePickerChip(
                        label: uiStrings['versePickerTop']?[locale] ??
                            'Top',
                        color: scheme.surfaceContainerHigh,
                        fg: scheme.onSurface,
                        onTap: () => _onVersePicked(mainProvider, 0),
                      ),
                    ),
                    for (final v in verses)
                      SizedBox(
                        width: tileW,
                        child: _VersePickerChip(
                          label: '${v.verse}',
                          color: scheme.primaryContainer,
                          fg: scheme.onPrimaryContainer,
                          onTap: () =>
                              _onVersePicked(mainProvider, v.verse),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _testamentButton({
    required BuildContext context,
    required AppSettings settings,
    required bool selected,
    required String label,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? scheme.primary.withValues(alpha: 0.92)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: 14 * settings.menuScale,
            vertical: 10 * settings.menuScale),
      ),
      // FittedBox(scaleDown) shrinks the label proportionally if the
      // button is too narrow for the natural-size text, instead of
      // truncating with a near-invisible ellipsis that swallowed the
      // last character ("Hebrew Bible" → "Hebrew", "希伯来圣经" → "希伯来圣").
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: settings.fontSize.clamp(13.0, 17.0).toDouble(),
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
          fontWeight: FontWeight.w700,
        ),
      ),
      ),
    );
  }

  void _setTestament(AppSettings settings, bool oldTestament) {
    setState(() {
      showOldTestament = oldTestament;
      expandStatus.updateAll((key, _) => false);
      _gridSelectedBook = null;
    });
    // Only scroll if the controller is actually attached to a ListView.
    // In grid mode, or during transitions before the new list mounts,
    // the controller has no positions and scrollToIndex will throw a
    // null check error inside the scroll_to_index package.
    if (settings.booksViewMode != 'grid' &&
        _autoScrollController.hasClients) {
      _autoScrollController.scrollToIndex(
        0,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 10),
      );
    }
  }

  Widget _buildListView(BuildContext context, MainProvider mainProvider,
      AppSettings settings, List<Book> filteredBooks) {
    final scheme = Theme.of(context).colorScheme;
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
                textColor: scheme.primary,
                iconColor: scheme.primary,
                title: Text(
                  book.title,
                  style: TextStyle(
                      fontSize: settings.fontSize,
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      decoration: TextDecoration.none,
                      color: expandStatus[book.title] == true
                          ? scheme.primary
                          : scheme.onSurface),
                ),
                initiallyExpanded: expandStatus[book.title] ?? false,
                maintainState: true,
                onExpansionChanged: (expanded) {
                  setState(() {
                    expandStatus[book.title] = expanded;
                  });
                },
                children: [
                  _buildChapterGrid(context, mainProvider, settings, book),
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

    if (_gridSelectedBook != null) {
      final book =
          filteredBooks.firstWhereOrNull((b) => b.title == _gridSelectedBook);
      if (book != null) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: BooksGlassSurface(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _gridSelectedBook = null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded,
                            size: settings.fontSize * 1.1,
                            color: scheme.onSurface),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            book.title,
                            style: TextStyle(
                              fontSize: settings.fontSize * 1.1,
                              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${book.chapters.length} '
                            '${uiStrings['chapters']?[settings.locale] ?? 'ch'}',
                            style: TextStyle(
                              fontSize: settings.fontSize * 0.75,
                              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final tileTarget = 56.0 * settings.menuScale;
                final cols =
                    (constraints.maxWidth / tileTarget).floor().clamp(4, 10);
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: book.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = book.chapters[index];
                    final selected =
                        chapter.title == widget.currentChapter &&
                            widget.currentBook == book.title;
                    return _gridChapterTile(context, mainProvider, settings,
                        book, chapter, selected, scheme);
                  },
                );
              }),
            ),
          ],
        );
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final targetWidth = 80.0 * settings.menuScale;
      final cols = (constraints.maxWidth / targetWidth).floor().clamp(4, 10);
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: filteredBooks.length,
        itemBuilder: (context, index) {
          final book = filteredBooks[index];
          final isCurrent = widget.currentBook == book.title;
          return _bookTile(context, settings, book, isCurrent, scheme);
        },
      );
    });
  }

  Widget _bookTile(BuildContext context, AppSettings settings, Book book,
      bool isCurrent, ColorScheme scheme) {
    final bgColor = isCurrent
        ? scheme.primary.withValues(alpha: 0.92)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.62);
    final fgColor = isCurrent ? scheme.onPrimary : scheme.onSurface;
    final shortName = _shortBookTitle(book.title);
    return Tooltip(
      message: book.title,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _gridSelectedBook = book.title),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            // 2026-06-30: even padding so the glyph is centred with
            // consistent breathing room on all four sides.
            padding: const EdgeInsets.all(7),
            // 2026-05-10 (v1.2.19): switched fit from `scaleDown` →
            // `contain` so single-char labels ("创") scale UP to fill
            // the tile and long ones ("撒母耳记") scale DOWN.
            // 2026-06-30: user reported the CJK glyphs looked THIN and
            // small. Root cause: w500 weight + a loose line box
            // (`height: 1.1` plus the CJK font's generous ascent/
            // descent) meant the FittedBox was fitting a text box far
            // taller than the visible glyph, so the glyph rendered at
            // ~half the tile. Fixes: (1) always BOLD (w700) — the big
            // visibility win for a single stroke-dense character; (2)
            // `height: 1.0` + a `forceStrutHeight` strut that clamps
            // the line box to the glyph, so `contain` now scales the
            // GLYPH (not the whitespace) to fill the tile.
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                softWrap: false,
                strutStyle: const StrutStyle(
                  height: 1.0,
                  forceStrutHeight: true,
                  leading: 0,
                ),
                style: TextStyle(
                  fontSize: settings.fontSize * 1.15,
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                  height: 1.0,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _shortBookTitle(String title) {
    const abbr = <String, String>{
      'Genesis': 'Gen', 'Exodus': 'Exod', 'Leviticus': 'Lev',
      'Numbers': 'Num', 'Deuteronomy': 'Deut', 'Joshua': 'Josh',
      'Judges': 'Judg', 'Ruth': 'Ruth', '1 Samuel': '1Sam',
      '2 Samuel': '2Sam', '1 Kings': '1Kgs', '2 Kings': '2Kgs',
      '1 Chronicles': '1Chr', '2 Chronicles': '2Chr', 'Ezra': 'Ezra',
      'Nehemiah': 'Neh', 'Esther': 'Est', 'Job': 'Job',
      'Psalms': 'Ps', 'Psalm': 'Ps', 'Proverbs': 'Prov',
      'Ecclesiastes': 'Eccl', 'Song of Solomon': 'Song',
      'Song of Songs': 'Song', 'Isaiah': 'Isa', 'Jeremiah': 'Jer',
      'Lamentations': 'Lam', 'Ezekiel': 'Ezek', 'Daniel': 'Dan',
      'Hosea': 'Hos', 'Joel': 'Joel', 'Amos': 'Amos',
      'Obadiah': 'Obad', 'Jonah': 'Jonah', 'Micah': 'Mic',
      'Nahum': 'Nah', 'Habakkuk': 'Hab', 'Zephaniah': 'Zeph',
      'Haggai': 'Hag', 'Zechariah': 'Zech', 'Malachi': 'Mal',
      'Matthew': 'Matt', 'Mark': 'Mark', 'Luke': 'Luke',
      'John': 'John', 'Acts': 'Acts', 'Romans': 'Rom',
      '1 Corinthians': '1 Cor', '2 Corinthians': '2 Cor',
      'Galatians': 'Gal', 'Ephesians': 'Eph', 'Philippians': 'Phil',
      'Colossians': 'Col', '1 Thessalonians': '1Th',
      '2 Thessalonians': '2Th', '1 Timothy': '1Tim',
      '2 Timothy': '2Tim', 'Titus': 'Titus', 'Philemon': 'Phlm',
      'Hebrews': 'Heb', 'James': 'Jas', '1 Peter': '1Pet',
      '2 Peter': '2Pet', '1 John': '1Jn', '2 John': '2Jn',
      '3 John': '3Jn', 'Jude': 'Jude', 'Revelation': 'Rev',
      '创世纪': '创', '创世记': '创', '創世紀': '創', '創世記': '創',
      '出埃及记': '出', '出埃及記': '出', '利未记': '利', '利未記': '利',
      '民数记': '民', '民數記': '民', '申命记': '申', '申命記': '申',
      '约书亚记': '书', '約書亞記': '書', '士师记': '士', '士師記': '士',
      '路得记': '得', '路得記': '得', '撒母耳记上': '撒上', '撒母耳記上': '撒上',
      '撒母耳记下': '撒下', '撒母耳記下': '撒下', '列王纪上': '王上',
      '列王紀上': '王上', '列王纪下': '王下', '列王紀下': '王下',
      '历代志上': '代上', '歷代志上': '代上', '历代志下': '代下',
      '歷代志下': '代下', '以斯拉记': '拉', '以斯拉記': '拉',
      '尼希米记': '尼', '尼希米記': '尼', '以斯帖记': '斯', '以斯帖記': '斯',
      '约伯记': '伯', '約伯記': '伯', '诗篇': '诗', '詩篇': '詩',
      '箴言': '箴', '传道书': '传', '傳道書': '傳', '雅歌': '歌',
      '以赛亚书': '赛', '以賽亞書': '賽', '耶利米书': '耶', '耶利米書': '耶',
      '耶利米哀歌': '哀', '以西结书': '结', '以西結書': '結',
      '但以理书': '但', '但以理書': '但', '何西阿书': '何', '何西阿書': '何',
      '约珥书': '珥', '約珥書': '珥', '阿摩司书': '摩', '阿摩司書': '摩',
      '俄巴底亚书': '俄', '俄巴底亞書': '俄', '约拿书': '拿', '約拿書': '拿',
      '弥迦书': '弥', '彌迦書': '彌', '那鸿书': '鸿', '那鴻書': '鴻',
      '哈巴谷书': '哈', '哈巴谷書': '哈', '西番雅书': '番', '西番雅書': '番',
      '哈该书': '该', '哈該書': '該', '撒迦利亚书': '亚', '撒迦利亞書': '亞',
      '玛拉基书': '玛', '瑪拉基書': '瑪', '马太福音': '太', '馬太福音': '太',
      '马可福音': '可', '馬可福音': '可', '路加福音': '路',
      '约翰福音': '约', '約翰福音': '約', '使徒行传': '徒', '使徒行傳': '徒',
      '罗马书': '罗', '羅馬書': '羅', '哥林多前书': '林前', '哥林多前書': '林前',
      '哥林多后书': '林后', '哥林多後書': '林後', '加拉太书': '加',
      '加拉太書': '加', '以弗所书': '弗', '以弗所書': '弗',
      '腓立比书': '腓', '腓立比書': '腓', '歌罗西书': '西', '歌羅西書': '西',
      '帖撒罗尼迦前书': '帖前', '帖撒羅尼迦前書': '帖前',
      '帖撒罗尼迦后书': '帖后', '帖撒羅尼迦後書': '帖後',
      '提摩太前书': '提前', '提摩太前書': '提前',
      '提摩太后书': '提后', '提摩太後書': '提後',
      '提多书': '多', '提多書': '多', '腓利门书': '门', '腓利門書': '門',
      '希伯来书': '来', '希伯來書': '來', '雅各书': '雅', '雅各書': '雅',
      '彼得前书': '彼前', '彼得前書': '彼前', '彼得后书': '彼后',
      '彼得後書': '彼後', '约翰一书': '约一', '約翰一書': '約一',
      '约翰二书': '约二', '約翰二書': '約二', '约翰三书': '约三',
      '約翰三書': '約三', '犹大书': '犹', '猶大書': '猶',
      '启示录': '启', '啟示錄': '啟',
    };
    return abbr[title] ?? title;
  }

  Widget _gridChapterTile(
      BuildContext context,
      MainProvider mainProvider,
      AppSettings settings,
      Book book,
      Chapter chapter,
      bool selected,
      ColorScheme scheme) {
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 1.5 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectChapter(
            mainProvider, book.title, chapter.title),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            chapter.title.toString(),
            style: TextStyle(
              fontSize: settings.fontSize * 0.95,
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChapterGrid(BuildContext context, MainProvider mainProvider,
      AppSettings settings, Book book) {
    return Wrap(
      alignment: WrapAlignment.start,
      children: List.generate(book.chapters.length, (i) {
        final chapter = book.chapters[i];
        final selected =
            chapter.title == widget.currentChapter &&
                widget.currentBook == book.title;
        final scheme = Theme.of(context).colorScheme;
        return _chapterTile(
            context, mainProvider, settings, book, chapter, selected, scheme);
      }),
    );
  }

  Widget _chapterTile(
      BuildContext context,
      MainProvider mainProvider,
      AppSettings settings,
      Book book,
      Chapter chapter,
      bool selected,
      ColorScheme scheme) {
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final tileSize = ResponsiveBreakpoints.chapterTileSize(dc);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: tileSize,
        width: tileSize,
        child: Card(
          color: selected ? scheme.primary : null,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _selectChapter(
                mainProvider, book.title, chapter.title),
            child: Center(
              child: Text(
                chapter.title.toString(),
                style: TextStyle(
                  fontSize: settings.fontSize * 0.9,
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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

class BooksGlassSurface extends StatelessWidget {
  final Widget child;

  const BooksGlassSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.78),
            borderRadius: BorderRadius.circular(18),
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

/// Small tappable verse-number chip used in the verse picker
/// modal. Mirrors the styling of the chapter chips so users
/// can transfer their muscle memory.
class _VersePickerChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color fg;
  final VoidCallback onTap;
  const _VersePickerChip({
    required this.label,
    required this.color,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 38, minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
