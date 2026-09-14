// 2026-09-14: a footnote opens under the line, not over it.
//
// 「我觉得sword words可以学习yahwehdehua 当注释很多可以expand close这样」.
//
// It was an `AlertDialog`, and the sibling app this one was pointed at
// records the same move away from exactly that, with the reason in its
// own source: a modal "shows one note and covers the verse it is about;
// two notes could never be read against each other" — 「译者注：可同时
// 展开多条」.
//
// What made it pressing here is the data, not the taste. 梁家鏗's own
// apparatus was adopted the same day: 1,132 footnotes became 2,209, and
// several are paragraphs — the note at 馬太福音 4:5 separates ἱερόν from
// ναός over four lines and closes 「參 SNT，10-12頁」. A dialog per note,
// each covering the verse it explains, cannot be read against anything.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/widgets/verse_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const noteA = 'the first note, about ἱερόν';
  const noteB = 'the second note, about ναός';

  const verses = [
    Verse(book: 'Matthew', chapter: 4, verse: 5,
        text: 'the holy city<note: $noteA> and the temple<note: $noteB>'),
  ];

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()
          ..currentBook = 'Matthew'
          ..currentChapter = 4
          ..setVerses(verses)),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VerseWidget(
                verse: verses.first, index: 0, isFirst: true),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Every note marker on screen, in order.
  Finder markers() => find.byIcon(Icons.notes_rounded);

  testWidgets('the note is not on screen until its marker is tapped',
      (tester) async {
    await pump(tester);
    expect(markers(), findsNWidgets(2));
    expect(find.text(noteA), findsNothing);
    expect(find.text(noteB), findsNothing);
  });

  testWidgets('tapping opens it in place, and opens no dialog',
      (tester) async {
    await pump(tester);
    await tester.tap(markers().first);
    await tester.pump();

    expect(find.text(noteA), findsOneWidget);
    // The whole point: the verse is still readable while the note is.
    expect(find.byType(AlertDialog), findsNothing,
        reason: 'a modal covers the verse the note is about');
    expect(find.byType(RichText), findsWidgets);
  });

  testWidgets('two notes stay open together — the thing a modal cannot do',
      (tester) async {
    await pump(tester);
    await tester.tap(markers().first);
    await tester.pump();
    await tester.tap(markers().last);
    await tester.pump();

    expect(find.text(noteA), findsOneWidget);
    expect(find.text(noteB), findsOneWidget,
        reason: 'opening the second note closed the first, which is the '
            'behaviour this replaced');
  });

  testWidgets('tapping again closes it', (tester) async {
    await pump(tester);
    await tester.tap(markers().first);
    await tester.pump();
    expect(find.text(noteA), findsOneWidget);

    await tester.tap(markers().first);
    await tester.pump();
    expect(find.text(noteA), findsNothing);
  });

  testWidgets('the open note is keyed by its text, not its position',
      (tester) async {
    // The spans are rebuilt from scratch on every paint. An index would
    // reopen whatever landed in that slot; a reader who opened the ἱερόν
    // note and then changed the reading version would find some other
    // note open in its place.
    await pump(tester);
    await tester.tap(markers().last);
    await tester.pump();
    expect(find.text(noteB), findsOneWidget);
    expect(find.text(noteA), findsNothing,
        reason: 'the second marker opened the first note');
  });
}
