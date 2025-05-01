import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:clipboard/clipboard.dart';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:yswords/models/verse.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/books_page.dart';
import 'package:yswords/pages/search_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/read_last_index.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/widgets/verse_widget.dart';
import 'package:yswords/utils/version_mapper.dart'
    show translateBookName, toEnglish;
import 'package:yswords/constants/ui_strings.dart';

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
  bool _controllerInitialized = false;
  final ScrollController _fakeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final mainProvider = Provider.of<MainProvider>(context, listen: false);
      final settings = Provider.of<AppSettings>(context, listen: false);
      if (mainProvider.verses.isEmpty) {
        await FetchVerses.execute(
            mainProvider: mainProvider, settings: settings);
        await FetchBooks.execute(
            mainProvider: mainProvider, settings: settings);
      }
      await ReadLastIndex.execute().then((index) {
        if (index != null) {
          mainProvider.scrollToIndex(index: index);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_controllerInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = Provider.of<MainProvider>(context, listen: false);
        if (provider.books.isEmpty) return;

        setState(() {
          _controllerInitialized = true;
        });

        // ✅ Moved here!
        provider.clearSelectedVerses();
      });
    } else {
      // ✅ Clear outside build frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<MainProvider>(context, listen: false).clearSelectedVerses();
      });
    }
  }

  @override
  void dispose() {
    _fakeScrollController.dispose();
    Provider.of<MainProvider>(context, listen: false).clearSelectedVerses();
    super.dispose();
  }

  String formattedSelectedVerses({required List<Verse> verses}) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final notePattern = RegExp(r'<note:[^>]*>');
    final braceInnerPattern = RegExp(r'\{([^}]*)\}');
    final squareInnerPattern = RegExp(r'\[([^\]]*)\]');
    final sorted = [...verses]..sort((a, b) {
        final bookComparison = a.book.compareTo(b.book);
        if (bookComparison != 0) return bookComparison;
        if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
        return a.verse.compareTo(b.verse);
      });

    if (sorted.isEmpty) return '';

    final first = sorted.first;
    final header = '${first.book} ${first.chapter}';

    switch (settings.copyFormat) {
      case 'withRef':
        return sorted
            .map((v) {
              final cleanedText = v.text
                .replaceAll(notePattern, '')
                .replaceAllMapped(braceInnerPattern, (m) => m.group(1) ?? '')
                .replaceAllMapped(squareInnerPattern, (m) => m.group(1) ?? '')
                .trim();
              return '[${v.book} ${v.chapter}:${v.verse}] $cleanedText';
            })
            .join('\n');
      case 'plain':
        return '$header\n' +
            sorted
                .map((v) {
                  final cleanedText = v.text
                    .replaceAll(notePattern, '')
                    .replaceAllMapped(braceInnerPattern, (m) => m.group(1) ?? '')
                    .replaceAllMapped(squareInnerPattern, (m) => m.group(1) ?? '')
                    .trim();
                  return '${v.verse} $cleanedText';
                })
                .join('\n');
      case 'devotional':
        final book = first.book;
        final chapter = first.chapter;
        final versesText = sorted
            .map((v) =>
                v.text.replaceAll(notePattern, '') 
                    .replaceAllMapped(braceInnerPattern, (m) => m.group(1) ?? '')
                    .replaceAllMapped(squareInnerPattern, (m) => m.group(1) ?? '')
                    .trim())
            .join('\n');
        final verseNumbers = sorted.map((v) => v.verse).toList();

        String formatRange(List<int> nums) {
          if (nums.isEmpty) return '';
          nums.sort();
          final List<String> parts = [];
          int start = nums[0];
          int end = start;

          for (int i = 1; i < nums.length; i++) {
            if (nums[i] == end + 1) {
              end = nums[i];
            } else {
              if (start == end) {
                parts.add('$start');
              } else {
                parts.add('$start–$end');
              }
              start = nums[i];
              end = start;
            }
          }

          if (start == end) {
            parts.add('$start');
          } else {
            parts.add('$start–$end');
          }

          return parts.join(', ');
        }

        final range = formatRange(verseNumbers);
        return '$versesText\n($book $chapter:$range)';
      default:
        return sorted
            .map((v) => v.text.replaceAll(notePattern, '')
                .replaceAllMapped(braceInnerPattern, (m) => m.group(1) ?? '')
                .replaceAllMapped(squareInnerPattern, (m) => m.group(1) ?? '')
                .trim())
            .join('\n');
    }
  }

  List<InlineSpan> _buildVerseSpans(List<Verse> verses, BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final spans = <InlineSpan>[];
    final bracePattern = RegExp(r'\{([^}]+)\}');
    final notePattern  = RegExp(r'<note:([^>]+)>');

    for (var v in verses) {
      // Verse number
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () async {
            final original = v.text.replaceAll('\n', '');
            final sanitized = original.replaceAll(notePattern, '').replaceAll(bracePattern, '').trim();
            final toCopy = '${v.verse} $sanitized';
            await ClipboardHelper.copyText(toCopy);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied verse ${v.verse}')),
            );
          },
          child: Text(
            '${v.verse} ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: settings.fontSize,
              fontFamily: settings.fontFamily,
              height: settings.lineSpacing,
            ),
          ),
        ),
      ));

      // Prepare original text and extract notes
      final original = v.text.replaceAll('\n', '');
      // Remove note tags from display
      final raw = original.replaceAll(notePattern, '').trim();
      // Split on curly annotations, preserving them for badge rendering
      final parts = raw.splitMapJoin(
        bracePattern,
        onMatch: (m) => '||${m[0]}||',
        onNonMatch: (n) => n,
      ).split('||');

      for (var part in parts) {
        if (bracePattern.hasMatch(part)) {
          final annotation = bracePattern.firstMatch(part)!.group(1)!;
          // Retrieve the first note from the original full text
          final noteMatch = notePattern.firstMatch(original);
          final noteText  = noteMatch != null ? noteMatch.group(1)! : '';

          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Note'),
                    content: Text(noteText),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                margin: EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  annotation,
                  style: TextStyle(
                    fontSize: settings.fontSize * 0.85,
                    fontFamily: settings.fontFamily,
                    height: settings.lineSpacing,
                  ),
                ),
              ),
            ),
          ));
        } else {
          spans.add(TextSpan(
            text: part,
            style: TextStyle(
              fontSize: settings.fontSize,
              fontFamily: settings.fontFamily,
              height: settings.lineSpacing,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ));
        }
      }
    }

    return spans;
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

        // (groupVersesIntoParagraphs local function removed)

        // final paragraphs = _groupVersesIntoParagraphs(verses);
        final currentVerse = mainProvider.currentVerse ??
            (verses.isNotEmpty ? verses.first : null);
        final isSelected = mainProvider.selectedVerses.isNotEmpty;

        return SelectionArea(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                _goToNextChapter();
              } else if (details.primaryVelocity! > 0) {
                _goToPreviousChapter();
              }
            },
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                systemNavigationBarColor:
                    Theme.of(context).colorScheme.background,
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
                                  {
                                        'kjv': 'KJV',
                                        'leb': 'LEB',
                                        'cuvs-yhwh': 'cuvs(简)',
                                        'cuvs-yhwh-tr': 'cuvs(繁)',
                                        'BIBLEXG': 'biblexg(简)',
                                        'BIBLEXG-tr': 'biblexg(繁)',
                                      }[mainProvider.currentVersion] ??
                                      mainProvider.currentVersion,
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
                                final settings = Provider.of<AppSettings>(
                                    context,
                                    listen: false);
                                p.clearSelectedVerses();

                                final prevEn = toEnglish(p.currentBook);

                                p.setVersion(version);
                                await FetchVerses.execute(
                                    mainProvider: p, settings: settings);
                                await FetchBooks.execute(
                                    mainProvider: p, settings: settings);

                                String? targetBook = prevEn == null
                                    ? null
                                    : translateBookName(prevEn, version);

                                final match = p.verses.firstWhere(
                                  (v) =>
                                      v.book ==
                                          (targetBook ?? p.verses.first.book) &&
                                      v.chapter ==
                                          (p.currentChapter ?? v.chapter),
                                  orElse: () => p.verses.first,
                                );

                                p.setCurrentChapter(
                                    book: match.book, chapter: match.chapter);
                                p.updateCurrentVerse(verse: match);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                    value: 'kjv',
                                    child: Text('King James Version')),
                                PopupMenuItem(
                                    value: 'leb',
                                    child: Text('Lexham English Bible'),),
                                PopupMenuItem(
                                    value: 'cuvs-yhwh',
                                    child: Text('和合本雅伟版(简体)')),
                                PopupMenuItem(
                                    value: 'cuvs-yhwh-tr',
                                    child: Text('和合本雅伟版(繁體)')),
                                PopupMenuItem(
                                    value: 'BIBLEXG', child: Text('梁家铿译本(简体)')),
                                PopupMenuItem(
                                    value: 'BIBLEXG-tr',
                                    child: Text('梁家铿譯本(繁體)')),
                              ],
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
                      child: settings.readingModeCentered
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              child: Text.rich(
                                TextSpan(
                                    children:
                                        _buildVerseSpans(verses, context)),
                              ),
                            )
                          : Scrollbar(
                              controller: _fakeScrollController,
                              child: ScrollablePositionedList.builder(
                                itemCount: verses.length + 1,
                                itemBuilder: (context, index) {
                                  if (index < verses.length) {
                                    return VerseWidget(
                                      verse: verses[index],
                                      index: index,
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
                    ),
                  ],
                ),
                floatingActionButton: isSelected
                    ? FloatingActionButton(
                        onPressed: () async {
                          final text = formattedSelectedVerses(
                              verses: mainProvider.selectedVerses);
                          await FlutterClipboard.copy(text);
                          mainProvider.clearSelectedVerses();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    uiStrings['copied']?[settings.locale] ??
                                        'Copied!',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.8),
                              duration: Duration(milliseconds: 800),
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

    final first = matched.isNotEmpty ? matched.first : provider.verses.first;
    provider.setCurrentChapter(book: book, chapter: chap);
    provider.updateCurrentVerse(verse: first);

    provider.jumpToIndex(index: 0); 
  }

  List<List<Verse>> _groupVersesIntoParagraphs(List<Verse> verses) {
    final List<List<Verse>> paragraphs = [];
    List<Verse> current = [];
    for (var v in verses) {
      if (current.isEmpty ||
          v.verse == 1 ||
          v.verse > (current.last.verse + 1)) {
        if (current.isNotEmpty) paragraphs.add(current);
        current = [v];
      } else {
        current.add(v);
      }
    }
    if (current.isNotEmpty) paragraphs.add(current);
    return paragraphs;
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
