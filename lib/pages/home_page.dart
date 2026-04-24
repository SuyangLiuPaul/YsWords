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

class CustomFloatingActionButtonLocation extends FloatingActionButtonLocation {
  final double xOffset;
  final double yOffset;

  const CustomFloatingActionButtonLocation({
    this.xOffset = 0.0,
    this.yOffset = 0.0,
  });

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final endFloat =
        FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    return endFloat.translate(xOffset, yOffset);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final mainProvider = context.read<MainProvider>();
      if (mainProvider.verses.isEmpty) {
        await FetchVerses.execute(mainProvider: mainProvider);
        if (!mounted) return;
        await FetchBooks.execute(mainProvider: mainProvider);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
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
        final hasParagraphData =
            verses.any((v) => v.isParagraphStart == true);

        // (groupVersesIntoParagraphs local function removed)

        // final paragraphs = _groupVersesIntoParagraphs(verses);
        final currentVerse = mainProvider.currentVerse ??
            (verses.isNotEmpty ? verses.first : null);
        final isSelected = mainProvider.selectedVerses.isNotEmpty;

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
                floatingActionButtonAnimator: NoScalingAnimation(),
                appBar: AppBar(
                  title: LayoutBuilder(
                    builder: (context, constraints) {
                      // double scale =
                      //     (constraints.maxWidth / 375).clamp(0.75, 1.0);
                      double baseFontSize =
                          Theme.of(context).textTheme.titleLarge?.fontSize ??
                              20;
                      if (currentVerse == null) {
                        return Text(
                          uiStrings['bible']?[settings.locale] ?? 'Bible',
                          style: TextStyle(
                            fontSize: baseFontSize,
                            fontFamily: settings.fontFamily,
                          ),
                        );
                      }
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  final mainProvider =
                                      Provider.of<MainProvider>(context,
                                          listen: false);
                                  mainProvider.clearSelectedVerses();
                                  Get.to(
                                    () => BooksPage(
                                      chapterIdx:
                                          mainProvider.currentVerse?.chapter ??
                                              1,
                                      bookIdx:
                                          mainProvider.currentVerse?.book ?? '',
                                    ),
                                    transition: Transition.leftToRight,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  child: Text(
                                    '${currentVerse.book} ${currentVerse.chapter}',
                                    style: TextStyle(
                                      fontFamily: settings.fontFamily,
                                      fontSize: settings.fontSize,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              tooltip: uiStrings['changeVersion']
                                      ?[settings.locale] ??
                                  'Change Version',
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  shortBibleVersionLabel(
                                      mainProvider.currentVersion),
                                  style: TextStyle(
                                    fontFamily: settings.fontFamily,
                                    fontSize: settings.fontSize,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              onSelected: (version) async {
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
                                      (targetBook == null ||
                                          v.book == targetBook) &&
                                      (targetChapter == null ||
                                          v.chapter == targetChapter),
                                  orElse: () => p.verses.first,
                                );

                                p.setCurrentChapter(
                                    book: match.book, chapter: match.chapter);
                                p.updateCurrentVerse(verse: match);
                              },
                              itemBuilder: (context) => bibleVersions
                                  .map(
                                    (version) => PopupMenuItem(
                                      value: version.value,
                                      child: Text(version.menuLabel),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  actions: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 377) {
                          return PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              if (value == 'search') {
                                mainProvider.clearSelectedVerses();
                                Get.to(
                                  () => SearchPage(),
                                  transition: Transition.rightToLeft,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'search',
                                child: ListTile(
                                  leading: Icon(Icons.search),
                                  title: Text(uiStrings['search']
                                          ?[settings.locale] ??
                                      'Search'),
                                ),
                              ),
                            ],
                          );
                        } else {
                          double screenWidth =
                              MediaQuery.of(context).size.width;
                          double scale = (screenWidth / 375).clamp(0.5, 1.0);
                          double baseFontSize = Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.fontSize ??
                              20;
                          // Use padding and constrained box to limit right margin and width
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.scale(
                                    scale: scale,
                                    child: IconButton(
                                      padding: EdgeInsets.all(8.0 * scale),
                                      constraints: const BoxConstraints(),
                                      icon: Icon(Icons.search_rounded,
                                          size: baseFontSize * scale),
                                      onPressed: () {
                                        mainProvider.clearSelectedVerses();
                                        Get.to(
                                          () => SearchPage(),
                                          transition: Transition.rightToLeft,
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 2 * scale),
                                  Transform.scale(
                                    scale: scale,
                                    child: IconButton(
                                      padding: EdgeInsets.all(8.0 * scale),
                                      constraints: const BoxConstraints(),
                                      icon: Icon(Icons.settings,
                                          size: baseFontSize * scale),
                                      onPressed: () {
                                        mainProvider.clearSelectedVerses();
                                        Get.to(() => SettingsPage());
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                body: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ScrollablePositionedList.builder(
                          itemCount: verses.length + 1,
                          itemBuilder: (context, index) {
                            if (index < verses.length) {
                              return VerseWidget(
                                verse: verses[index],
                                index: index,
                                hasParagraphData: hasParagraphData,
                              );
                            }
                            return const SizedBox(height: 120);
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
                  ],
                ),
                floatingActionButton: isSelected
                    ? FloatingActionButton(
                        onPressed: () async {
                          final text = formattedSelectedVerses(
                              verses: mainProvider.selectedVerses);
                          await ClipboardHelper.copyText(text);
                          mainProvider.clearSelectedVerses();
                          if (!context.mounted) return;
                          final scheme = Theme.of(context).colorScheme;
                          final copiedLabel = uiStrings['copied']
                                  ?[settings.locale] ??
                              'Copied!';
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
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.8),
                              duration: const Duration(milliseconds: 800),
                            ),
                          );
                        },
                        child: const Icon(Icons.copy_rounded),
                      )
                    : null,
                floatingActionButtonLocation:
                    CustomFloatingActionButtonLocation(
                  xOffset: -16,
                  yOffset: -16,
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
    } else {
      final nextBookIdx = (bookIdx + 1) % books.length;
      nextBook = books[nextBookIdx].title;
      nextChap = books[nextBookIdx].chapters.first.title;
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
    } else {
      final prevBookIdx = (bookIdx - 1 + books.length) % books.length;
      prevBook = books[prevBookIdx].title;
      prevChap = books[prevBookIdx].chapters.last.title;
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
    provider.jumpToIndex(index: 0);
  }
}

class NoScalingAnimation extends FloatingActionButtonAnimator {
  @override
  Offset getOffset(
      {required Offset begin, required Offset end, required double progress}) {
    return Offset.lerp(begin, end, 1)!; // Instantly move without animation
  }

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) {
    return AlwaysStoppedAnimation(1); // No rotation
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) {
    return AlwaysStoppedAnimation(1); // No scaling animation
  }
}
