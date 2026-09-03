// The book picker's table-of-contents view — the default since
// 2026-09-03, replacing the grid of 39/27 identical one-character
// squares the user called strange ("我怎么看左边那个blocks其实看起来很
// 奇怪设计能够更好些吗", 2026-08-16).
//
// **A redesign that loses a book is worse than an ugly keypad**, so the
// first two tests are a census: every one of the 66 books must have a
// row, and the grouping must not be able to swallow one. The third
// checks the thing a picker is FOR — that picking still navigates —
// and the fourth pins the catch-all, which is the only way a book could
// ever go missing here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/widgets/book_chapter_picker.dart';

/// Canonical English titles and their real chapter counts. Real counts
/// matter: the row draws a length bar scaled against the longest book
/// on screen, so 诗篇's 150 is what every other OT bar is measured by.
const _ot = <String, int>{
  'Genesis': 50, 'Exodus': 40, 'Leviticus': 27, 'Numbers': 36,
  'Deuteronomy': 34, 'Joshua': 24, 'Judges': 21, 'Ruth': 4,
  '1 Samuel': 31, '2 Samuel': 24, '1 Kings': 22, '2 Kings': 25,
  '1 Chronicles': 29, '2 Chronicles': 36, 'Ezra': 10, 'Nehemiah': 13,
  'Esther': 10, 'Job': 42, 'Psalms': 150, 'Proverbs': 31,
  'Ecclesiastes': 12, 'Song of Solomon': 8, 'Isaiah': 66,
  'Jeremiah': 52, 'Lamentations': 5, 'Ezekiel': 48, 'Daniel': 12,
  'Hosea': 14, 'Joel': 3, 'Amos': 9, 'Obadiah': 1, 'Jonah': 4,
  'Micah': 7, 'Nahum': 3, 'Habakkuk': 3, 'Zephaniah': 3,
  'Haggai': 2, 'Zechariah': 14, 'Malachi': 4,
};

const _nt = <String, int>{
  'Matthew': 28, 'Mark': 16, 'Luke': 24, 'John': 21, 'Acts': 28,
  'Romans': 16, '1 Corinthians': 16, '2 Corinthians': 13,
  'Galatians': 6, 'Ephesians': 6, 'Philippians': 4, 'Colossians': 4,
  '1 Thessalonians': 5, '2 Thessalonians': 3, '1 Timothy': 6,
  '2 Timothy': 4, 'Titus': 3, 'Philemon': 1, 'Hebrews': 13,
  'James': 5, '1 Peter': 5, '2 Peter': 3, '1 John': 5, '2 John': 1,
  '3 John': 1, 'Jude': 1, 'Revelation': 22,
};

MainProvider _wholeBible({Map<String, int> extra = const {}}) {
  final counts = <String, int>{..._ot, ..._nt, ...extra};
  final verses = <Verse>[
    for (final entry in counts.entries)
      for (var c = 1; c <= entry.value; c++)
        for (var v = 1; v <= 3; v++)
          Verse(
              book: entry.key,
              chapter: c,
              verse: v,
              text: '${entry.key} $c:$v'),
  ];
  final mp = MainProvider();
  mp.setVerses(verses);
  mp.setBooks([
    for (final entry in counts.entries)
      Book(
        title: entry.key,
        chapters: [
          for (var c = 1; c <= entry.value; c++)
            Chapter(
              title: c,
              verses: verses
                  .where((v) => v.book == entry.key && v.chapter == c)
                  .toList(),
            ),
        ],
      ),
  ]);
  mp.setCurrentChapter(book: 'Genesis', chapter: 1);
  return mp;
}

/// Records what the host was asked to navigate to.
class _Nav {
  String? book;
  int? chapter;
  int? verse;
}

Future<AppSettings> _pump(
  WidgetTester tester,
  MainProvider mp, {
  _Nav? nav,
  Size size = const Size(520, 4200),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final settings = AppSettings();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mp),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BookChapterPicker(
            currentBook: 'Genesis',
            currentChapter: 1,
            onChapterSelected: (book, chapter, {int? verse}) {
              nav
                ?..book = book
                ..chapter = chapter
                ..verse = verse;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return settings;
}

String _s(String key, String locale) => uiStrings[key]![locale]!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the default view is the table of contents', (tester) async {
    final settings = await _pump(tester, _wholeBible());
    expect(settings.booksViewMode, 'sections',
        reason: 'the complaint was about the DEFAULT view, so the '
            'redesign has to be the default');
    // The three-way toggle: contents / list / grid, all reachable.
    expect(find.byIcon(Icons.toc_rounded), findsOneWidget);
    expect(find.byIcon(Icons.list_rounded), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });

  testWidgets('all 39 Old Testament books have a row, under the five '
      'divisions', (tester) async {
    final settings = await _pump(tester, _wholeBible());
    final locale = settings.locale;

    for (final title in _ot.keys) {
      expect(find.text(title), findsOneWidget,
          reason: '$title must be reachable in the table of contents');
    }
    for (final id in const [
      'divLaw',
      'divHistory',
      'divWisdom',
      'divMajorProphets',
      'divMinorProphets',
    ]) {
      expect(find.text(_s(id, locale)), findsOneWidget,
          reason: '$id must head its group');
    }
    // The header carries the group size — 5 / 12 / 5 / 5 / 12 = 39.
    final unit = _s('booksUnit', locale);
    // Law, Poetry & Wisdom, Major Prophets.
    expect(find.text('5 $unit'), findsNWidgets(3));
    // History, Minor Prophets.
    expect(find.text('12 $unit'), findsNWidgets(2));
    // And the book's length is on the row: 诗篇 is 150 chapters.
    expect(find.text('150'), findsOneWidget);
  });

  testWidgets('all 27 New Testament books have a row, under the five '
      'divisions', (tester) async {
    final settings = await _pump(tester, _wholeBible());
    final locale = settings.locale;

    await tester.tap(find.text(_s('newTestament', locale)));
    await tester.pump(const Duration(milliseconds: 300));

    for (final title in _nt.keys) {
      expect(find.text(title), findsOneWidget,
          reason: '$title must be reachable in the table of contents');
    }
    for (final id in const [
      'divGospels',
      'divActs',
      'divPauline',
      'divGeneralEpistles',
      'divRevelation',
    ]) {
      expect(find.text(_s(id, locale)), findsOneWidget,
          reason: '$id must head its group');
    }
    // No OT book leaked across the testament toggle.
    expect(find.text('Genesis'), findsNothing);
  });

  testWidgets('picking a book still navigates: book → chapter → verse',
      (tester) async {
    final nav = _Nav();
    await _pump(tester, _wholeBible(), nav: nav);

    // A book deep in a division, not the first row.
    await tester.tap(find.text('Zechariah'));
    await tester.pump(const Duration(milliseconds: 300));

    // The same chapter grid the grid view drills into.
    await tester.tap(find.text('14').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Zechariah  14'), findsOneWidget);

    await tester.tap(find.text('2').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(nav.book, 'Zechariah');
    expect(nav.chapter, 14);
    expect(nav.verse, 2);
  });

  testWidgets('a one-chapter book is still a tappable row', (tester) async {
    final nav = _Nav();
    await _pump(tester, _wholeBible(), nav: nav);

    // Obadiah has one chapter — the case a proportional length bar can
    // most easily render as nothing at all.
    await tester.tap(find.text('Obadiah'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('1').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Obadiah  1'), findsOneWidget);
  });

  testWidgets('a book the division table does not know is still listed',
      (tester) async {
    // The grouping must never be able to drop a row. A version with an
    // unrecognised title lands under the catch-all header.
    final settings = await _pump(
      tester,
      _wholeBible(extra: const {'Wisdom of Solomon': 19}),
    );
    await tester.tap(find.text(_s('newTestament', settings.locale)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Wisdom of Solomon'), findsOneWidget);
    expect(find.text(_s('divOther', settings.locale)), findsOneWidget);
  });

  testWidgets('the old grid is still one tap away', (tester) async {
    final settings = await _pump(tester, _wholeBible());
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    // AppSettings.notifyListeners debounces its persist by 600 ms; let
    // it fire so the test does not end with a pending timer.
    await tester.pump(const Duration(milliseconds: 700));

    expect(settings.booksViewMode, 'grid');
    // The abbreviation tiles are back.
    expect(find.text('Gen'), findsOneWidget);
    expect(find.text('Ps'), findsOneWidget);
  });

  test('a stored view choice is honoured; only the absent case moved', () {
    expect(normalizeBooksViewMode('grid'), 'grid');
    expect(normalizeBooksViewMode('list'), 'list');
    expect(normalizeBooksViewMode('sections'), 'sections');
    expect(normalizeBooksViewMode(null), 'sections');
    expect(normalizeBooksViewMode('nonsense'), 'sections');
  });
}
