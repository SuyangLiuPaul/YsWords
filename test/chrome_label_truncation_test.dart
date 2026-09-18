// 2026-09-14: no chrome label is drawn narrower than the words in it.
//
// The companion to `responsive_overflow_smoke_test.dart`, and the half it
// cannot see. That file asserts nothing threw, which catches a `Row` that
// ran out of width — but a `Text` with `maxLines: 1` and
// `TextOverflow.ellipsis` does not throw when it runs out of width. It
// succeeds, quietly, by deleting words. Both files lay these pages out at
// the same sizes; only this one notices.
//
// This is where the defect class was found. 「和合本雅伟版」 was drawn as
// 「雅…」 in the reading header, reported four times over three fixes — and
// `header_pill_truncation_test.dart` is the measured guard for those two
// pills specifically. This file is the wider net: every one-line label the
// reading surface draws, so the next one does not need four rounds either.
// The sibling Sword repo found two more the same way, in an app bar and a
// pane title.
//
// The measurement is a `RenderParagraph`'s laid-out width against the
// width its own text wants on one line. Both sliders are at maximum,
// because that is the configuration the whole family of defects lives in
// and the one no test had ever asked about.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/book.dart';
import 'package:yahwehs_words/models/chapter.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/pages/home_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The longest book name in the catalogue, because the header folds on
  // width and this is the name that pushes it.
  const book = '帖撒罗尼迦后书';
  const seed = [
    Verse(book: book, chapter: 3, verse: 1, text: '这是第一节'),
    Verse(book: book, chapter: 3, verse: 2, text: '这是第二节'),
  ];

  const sizes = <String, Size>{
    'iPhone SE 320x568': Size(320, 568),
    'iPhone 390x844': Size(390, 844),
  };

  // HomePage alone, and that is the whole reading surface: the header
  // pills, the chapter chrome and the bottom bar. The other pages are
  // lists of content — sermon titles, note previews, book names — where a
  // one-line label ending in an ellipsis is the list working, and an
  // allow-list long enough to cover them would stop being a guard.
  final pages = <String, Widget Function()>{
    'HomePage': () => const HomePage(),
  };

  /// Labels allowed to truncate, with the reason each one is content
  /// rather than chrome.
  ///
  /// Deliberately tiny, and every entry is a decision rather than a
  /// convenience: the point of this file is that a clipped label is a
  /// defect until somebody argues otherwise in writing.
  bool allowed(String text) {
      // A verse is prose and belongs to the reader; a pane showing two
      // lines of Genesis 1:1 and an ellipsis is reading, not clipping.
      return text.contains('这是第') ||
          // The resume-reading card quotes where the reader left off; a
          // quotation cut to one line is the card working.
          text.contains('…');
  }

  Future<List<String>> clippedOn(
      WidgetTester tester, Widget page, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    // Both sliders at maximum. `chrome_scale`-style caps and clamps mean
    // this is not simply "bigger everywhere" — it is the one corner where
    // every fixed-size piece of chrome is as large as it can get.
    await settings.setMenuScale(1.5);
    await settings.setFontSize(40);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => MainProvider()
              ..currentBook = book
              ..currentChapter = 3
              ..setBooks([
                Book(title: book,
                    chapters: [Chapter(title: 3, verses: seed)]),
              ])
              ..setVerses(seed)),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp(home: page),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    // `allRenderObjects` rather than a walk from the binding's root:
    // `renderViewElement` is deprecated, and CI analyses with infos
    // fatal, so the walk that read best locally failed the build.
    // A Set: `allRenderObjects` reaches the same paragraph through more
    // than one root, so a clipped label would otherwise be named twice in
    // the failure message.
    final out = <String>{};
    for (final o in tester.allRenderObjects) {
      if (o is RenderParagraph &&
          o.hasSize &&
          o.maxLines == 1 &&
          o.overflow == TextOverflow.ellipsis) {
        final text = o.text.toPlainText();
        final short = o.getMaxIntrinsicWidth(double.infinity) - o.size.width;
        if (short > 0.5 && !allowed(text)) {
          out.add('"$text" short by ${short.toStringAsFixed(1)}px');
        }
      }
    }
    // Drained before the tree goes: `AppSettings` debounces its notify
    // behind a timer the widget tree outlives, and the binding's
    // pending-timer guard would otherwise fail every case here for a
    // reason that has nothing to do with a label.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700));
    return out.toList();
  }

  for (final page in pages.entries) {
    for (final size in sizes.entries) {
      testWidgets('${page.key} deletes no words at ${size.key}, both '
          'sliders at maximum', (tester) async {
        addTearDown(tester.view.reset);
        final bad = await clippedOn(tester, page.value(), size.value);
        expect(bad, isEmpty,
            reason: 'ellipsised on ${size.key}: ${bad.join(", ")}. An '
                'ellipsis is not an overflow — the layout succeeded and '
                'the reader lost the words.');
      });
    }
  }

  testWidgets('the measurement can fail — a label given no room is caught',
      (tester) async {
    // Without this, a change that stopped the walk from reaching anything
    // (a renamed binding field, a page that renders a spinner at these
    // sizes) would turn every case above green while measuring nothing.
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 20,
          child: Text('a label with far more words than twenty pixels',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ));
    await tester.pump();

    final found = <String>[
      for (final o in tester.allRenderObjects)
        if (o is RenderParagraph &&
            o.hasSize &&
            o.maxLines == 1 &&
            o.overflow == TextOverflow.ellipsis &&
            o.getMaxIntrinsicWidth(double.infinity) - o.size.width > 0.5)
          o.text.toPlainText(),
    ];
    expect(found.toSet(), hasLength(1),
        reason: 'the walk above no longer finds a clipped label even when '
            'one is put in front of it');
  });
}
