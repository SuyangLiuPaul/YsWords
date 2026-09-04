// 2026-09-04, reported from a device: the "Greek Bible" chip in the book
// picker's top bar was cut off mid-word against the view-mode toggle.
//
// The cause was a horizontal `SingleChildScrollView` wrapped around the
// two testament buttons. A scroll view hands its children UNBOUNDED
// width, so the `FittedBox(scaleDown)` inside `_testamentButton` — the
// entire mechanism that exists to shrink a label rather than cut it, and
// which carries a 2026-04-27 comment saying so — could never fire. The
// buttons took their natural width and the scroll view clipped whatever
// ran past.
//
// **Why this needs a position assertion and not an overflow one.** An
// ordinary overflowing Row throws the yellow-and-black RenderFlex error,
// which a widget test catches for free. A scroll view does not: it clips
// in silence. Nothing appeared in any log, and the label still *exists*
// in the tree at full width — it is simply painted outside the viewport.
// So the property to pin is geometric: the label must END before the
// view-mode toggle BEGINS, at every width a real device might have.
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

/// One book from each testament — enough for the bar to draw both
/// buttons, and far cheaper than building all 66.
MainProvider _bothTestaments() {
  const counts = <String, int>{'Genesis': 50, 'Matthew': 28};
  final verses = <Verse>[
    for (final e in counts.entries)
      for (var c = 1; c <= e.value; c++)
        Verse(book: e.key, chapter: c, verse: 1, text: '${e.key} $c:1'),
  ];
  final mp = MainProvider();
  mp.setVerses(verses);
  mp.setBooks([
    for (final e in counts.entries)
      Book(
        title: e.key,
        chapters: [
          for (var c = 1; c <= e.value; c++)
            Chapter(
              title: c,
              verses: verses
                  .where((v) => v.book == e.key && v.chapter == c)
                  .toList(),
            ),
        ],
      ),
  ]);
  return mp;
}

Future<AppSettings> _pump(
  WidgetTester tester,
  double width, {
  String locale = 'en',
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 2400);
  addTearDown(tester.view.reset);
  final settings = AppSettings();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: _bothTestaments()),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BookChapterPicker(
            currentBook: 'Genesis',
            currentChapter: 1,
            onChapterSelected: (book, chapter, {int? verse}) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  // The default is zh-Hans, and that default is exactly why the first
  // version of this test passed against the bug: 希腊圣经 is four glyphs
  // and fits where "Greek Bible" does not. The reported screenshot had
  // the UI in English over a Chinese Bible, which is an ordinary
  // combination — the book names come from the version, the chrome from
  // the locale.
  await settings.setLocale(locale);
  // AppSettings debounces its persist by 600 ms; let it fire, or the
  // test ends with a pending timer and the framework fails it for that
  // instead of for anything about the layout.
  await tester.pump(const Duration(milliseconds: 700));
  return settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 320 is a small phone; 1000 is the Mi Pad in landscape. The reported
  // device sat in the middle of this range, and the broken branch is
  // taken at every one of them — `isNarrow` is `< 300`, so the Column
  // fallback essentially never runs on real hardware.
  // Both locales, because the labels are wildly different lengths and
  // only the English pair is long enough to overflow: a sweep that ran
  // Chinese only passed against the very bug this file is named for.
  for (final locale in const <String>['en', 'zh-Hans']) {
  for (final width in const <double>[320, 380, 420, 520, 700, 1000]) {
    testWidgets('$locale at ${width}px: both testament labels fit beside '
        'the view toggle', (tester) async {
      final settings = await _pump(tester, width, locale: locale);
      expect(settings.locale, locale, reason: 'the locale did not take');
      final ot = uiStrings['oldTestament']![locale]!;
      final nt = uiStrings['newTestament']![locale]!;

      expect(find.text(ot), findsOneWidget);
      expect(find.text(nt), findsOneWidget);

      // The view-mode toggle. Below ~300px of BAR width (not screen
      // width — the bar sits inside the sheet's padding, which is why
      // 320px of screen still takes it) the layout drops the toggle onto
      // its own second row, and there the buttons are entitled to the
      // full width. Asserting "left of the toggle" unconditionally would
      // fail that layout for being correct, so the row test decides
      // which constraint applies.
      final toggle = tester.getRect(find.byIcon(Icons.toc_rounded));

      for (final label in <String>[ot, nt]) {
        final r = tester.getRect(find.text(label));
        final sameRow = r.top < toggle.bottom && toggle.top < r.bottom;
        if (sameRow) {
          expect(r.right, lessThanOrEqualTo(toggle.left),
              reason: '"$label" runs past the view toggle at ${width}px — '
                  'that is the clip, and it is silent');
        }
        expect(r.left, greaterThanOrEqualTo(0.0),
            reason: '"$label" starts off the left edge at ${width}px');
        expect(r.right, lessThanOrEqualTo(width),
            reason: '"$label" runs off the screen at ${width}px');
      }

      // Both labels must be whole words, not the truncation the
      // FittedBox exists to prevent: a non-empty rect means it laid out,
      // and find.text matches the FULL string, so a clipped-to-"Greek"
      // label would not be found at all.
      expect(tester.getRect(find.text(nt)).width, greaterThan(0));
    });
  }
  }

  testWidgets('tapping the Greek Bible chip still switches testament',
      (tester) async {
    // Geometry is not the point on its own — the chip has to keep
    // working. A button squeezed to zero width would satisfy every
    // assertion above.
    final settings = await _pump(tester, 420);
    final nt = uiStrings['newTestament']![settings.locale]!;
    await tester.tap(find.text(nt));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Matthew'), findsWidgets);
  });
}
