// A footnote belongs INSIDE the margin of the verse it annotates.
//
// 2026-09-16 「我在words上看这个标记是不是要有些indentation呢」, with a
// photograph of 哥林多后书 5 and an arrow at the left edge of
// 「① "凭据"：原文是"质"」. The marker sat further left than the verse
// text above it — the one element on the page that is subordinate to
// the verse was the one element standing outside its margin.
//
// The cause was an inset measured from the wrong thing.
// `VerseNotesBlock` had 0.6 em of its own, added the day it used to run
// edge to edge (「一方面在两侧很难看」), but the reader's paragraph is
// indented 20 px and 0.6 em is about 11. So the block reached ~9 px
// past the text on the left, in both reading modes.
//
// These assertions are geometric on purpose. The note's own words, its
// numbering and its folding are covered by `verse_notes_block_test`;
// what could not be seen there is where the block lands relative to the
// verse, because that is decided by the two CALLERS.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/widgets/paragraph_group_widget.dart';
import 'package:yswords/widgets/verse_notes_block.dart';
import 'package:yswords/widgets/verse_widget.dart';

const _note = '“凭据”：原文是“质”。';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Verse v(int n, {List<String> notes = const []}) => Verse.fromJson({
        'book': '哥林多后书',
        'chapter': 5,
        'verse': n,
        'text': '所以我们时常坦然无惧，并且晓得我们住在身内便与主相离。',
        'blockNotes': notes,
      });

  Future<void> pump(WidgetTester tester, {required bool paragraphMode}) async {
    final mp = MainProvider(storagePrefix: 'test');
    final verses = [v(4, notes: const [_note]), v(5)];
    mp.setVerses(verses);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mp),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: paragraphMode
                  ? ParagraphGroupWidget(group: verses, startVerseIndex: 0)
                  : Column(
                      children: [
                        for (var i = 0; i < verses.length; i++)
                          VerseWidget(verse: verses[i], index: i),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final mode in [true, false]) {
    final name = mode ? 'paragraph mode' : 'verse-per-line mode';

    testWidgets('$name: the note starts inside the verse it belongs to',
        (tester) async {
      await pump(tester, paragraphMode: mode);
      final marker = find.text('①');
      expect(marker, findsOneWidget,
          reason: 'the note must be on the page at all');
      // The verse's own text, which is what the note is subordinate to.
      final textLeft = tester
          .getTopLeft(find.byType(RichText).first)
          .dx;
      final noteLeft = tester.getTopLeft(marker).dx;
      expect(noteLeft, greaterThanOrEqualTo(textLeft),
          reason: 'the marker was $noteLeft, the verse text $textLeft — '
              'the note is standing outside the margin it annotates');
      // And subordinate, not merely level: a note flush with the verse
      // reads as another paragraph of the verse.
      expect(noteLeft, greaterThan(textLeft),
          reason: 'a note level with the text does not read as a note');
    });
  }

  testWidgets('the block on its own still has its own breathing room',
      (tester) async {
    // `textInsets` ADDS to the block's own 0.6 em; it does not replace
    // it. A caller that passes nothing keeps exactly what it had.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: VerseNotesBlock(
            notes: const [_note],
            settings: AppSettings(),
            locale: 'zh-Hans',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('①')).dx, greaterThan(0));
  });
}
