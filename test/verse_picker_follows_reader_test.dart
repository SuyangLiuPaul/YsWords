// The picker must never offer the verses of a chapter the reader has
// left. Reported 2026-08-16 with a screenshot: the pane was in 列王纪下 3
// while the picker was headed 使徒行传 15 offering verses 1-41.
//
// The picker re-syncs itself only in `didUpdateWidget`, so it learns that
// the reader moved ONLY through new props. The docked sidebar reads them
// live off the provider and was already correct; the full-screen route
// froze them as constructor arguments at push time, so no provider
// navigation underneath it — a web back/forward, a queued jump, a restore
// completing — could ever reach the picker. Both hosts are exercised
// here, and the second case fails on the pre-fix code.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/pages/books_page.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/navigate_to_chapter_verse.dart';
import 'package:yswords/widgets/book_chapter_picker.dart';

List<Verse> _chapterVerses(String book, int chapter, int count) => [
      for (var v = 1; v <= count; v++)
        Verse(book: book, chapter: chapter, verse: v, text: '$book $chapter:$v'),
    ];

MainProvider _provider() {
  final mp = MainProvider();
  final verses = <Verse>[
    for (var c = 1; c <= 3; c++) ..._chapterVerses('列王纪下', c, 25),
    for (var c = 1; c <= 15; c++)
      ..._chapterVerses('使徒行传', c, c == 15 ? 41 : 20),
  ];
  mp.setVerses(verses);
  mp.setBooks([
    Book(
      title: '列王纪下',
      chapters: [
        for (var c = 1; c <= 3; c++)
          Chapter(
              title: c,
              verses: verses
                  .where((v) => v.book == '列王纪下' && v.chapter == c)
                  .toList()),
      ],
    ),
    Book(
      title: '使徒行传',
      chapters: [
        for (var c = 1; c <= 15; c++)
          Chapter(
              title: c,
              verses: verses
                  .where((v) => v.book == '使徒行传' && v.chapter == c)
                  .toList()),
      ],
    ),
  ]);
  mp.setCurrentChapter(book: '使徒行传', chapter: 15);
  mp.updateCurrentVerse(
      verse: verses.firstWhere((v) => v.book == '使徒行传' && v.chapter == 15));
  return mp;
}

/// Mirrors the docked sidebar: the picker's props are read live off the
/// provider, so any reader navigation reaches the picker as new props.
class _SidebarHost extends StatelessWidget {
  const _SidebarHost();

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MainProvider>();
    return BookChapterPicker(
      currentBook: mp.currentBook ?? '',
      currentChapter: mp.currentChapter ?? 1,
      onChapterSelected: (book, chapter, {int? verse}) {
        navigateToChapterVerse(mp, book: book, chapter: chapter, verse: verse);
      },
    );
  }
}

Future<void> _pump(WidgetTester tester, MainProvider mp) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mp),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: const MaterialApp(home: Scaffold(body: _SidebarHost())),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('drilling into another book then navigating the reader away '
      'must not leave the verse grid on the other book', (tester) async {
    final mp = _provider();
    await _pump(tester, mp);

    // The reader is in 使徒行传 15; drill into that chapter's verse grid.
    await tester.tap(find.text('徒'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('15').first);
    await tester.pump(const Duration(milliseconds: 300));

    // Verse-step for 使徒行传 15 — legitimate, the user asked for it.
    expect(find.text('使徒行传  15'), findsOneWidget);

    // Now the reader moves elsewhere (search hit / cross-ref / swipe).
    mp.setCurrentChapter(book: '列王纪下', chapter: 3);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('使徒行传  15'), findsNothing,
        reason: 'the picker must not offer a chapter the reader left');
  });

  testWidgets('the full-screen picker follows the reader too', (tester) async {
    final mp = _provider();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: BooksPage(
            chapterIdx: mp.currentChapter!,
            bookIdx: mp.currentBook!,
            providerOverride: mp,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('徒'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('15').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('使徒行传  15'), findsOneWidget);

    mp.setCurrentChapter(book: '列王纪下', chapter: 3);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('使徒行传  15'), findsNothing,
        reason: 'the picker must not offer a chapter the reader left');
  });
}
