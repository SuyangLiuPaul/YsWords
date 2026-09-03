// 2026-09-03: the note editor's formatting strip — bold, italic, list.
//
// Two layers, tested separately because they fail differently:
//
//   • `applyNoteFormat` is a pure function over (text, selection,
//     action). Its whole job is getting the toggle and the resulting
//     caret right, which is exactly the kind of thing that is painful
//     to debug through a widget tree.
//   • The strip itself has to be wired to the real `showNoteEditor`
//     sheet, write through the controller, and leave the caret where
//     the user can keep typing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/note_markdown.dart';
import 'package:yswords/widgets/bible_reading_pane.dart' show showNoteEditor;

TextSelection _sel(int base, int extent) =>
    TextSelection(baseOffset: base, extentOffset: extent);

void main() {
  group('applyNoteFormat — bold and italic', () {
    test('wraps the selection', () {
      final e = applyNoteFormat('hello world', _sel(6, 11),
          NoteFormatAction.bold);
      expect(e.text, 'hello **world**');
      // Selection lands on the word, not on the delimiters, so the
      // user can immediately hit italic too.
      expect(e.text.substring(e.selection.start, e.selection.end), 'world');
    });

    test('italic uses a single asterisk', () {
      final e = applyNoteFormat('hello world', _sel(6, 11),
          NoteFormatAction.italic);
      expect(e.text, 'hello *world*');
    });

    test('empty selection inserts a pair and puts the caret inside', () {
      final e = applyNoteFormat('ab', _sel(1, 1), NoteFormatAction.bold);
      expect(e.text, 'a****b');
      expect(e.selection.isCollapsed, isTrue);
      expect(e.selection.baseOffset, 3); // between the two `**`
    });

    test('unwraps when the selection includes the delimiters', () {
      final e = applyNoteFormat('**word**', _sel(0, 8), NoteFormatAction.bold);
      expect(e.text, 'word');
    });

    test('unwraps when the delimiters sit just outside the selection', () {
      // Double-tapping a bolded word selects `word`, not `**word**`.
      final e = applyNoteFormat('a **word** b', _sel(4, 8),
          NoteFormatAction.bold);
      expect(e.text, 'a word b');
      expect(e.text.substring(e.selection.start, e.selection.end), 'word');
    });

    test('bold inside italic nests rather than corrupting', () {
      final e = applyNoteFormat('*soft word*', _sel(6, 10),
          NoteFormatAction.bold);
      expect(e.text, '*soft **word***');
    });

    test('an invalid selection appends at the end instead of throwing', () {
      // A field that has never been focused reports offset -1.
      final e = applyNoteFormat('note', const TextSelection.collapsed(offset: -1),
          NoteFormatAction.bold);
      expect(e.text, 'note****');
    });
  });

  group('applyNoteFormat — lists', () {
    test('adds a marker to the caret line', () {
      final e = applyNoteFormat('milk\neggs', _sel(2, 2),
          NoteFormatAction.bulletList);
      expect(e.text, '- milk\neggs');
    });

    test('marks every line the selection touches', () {
      final e = applyNoteFormat('milk\neggs\nbread', _sel(2, 12),
          NoteFormatAction.bulletList);
      expect(e.text, '- milk\n- eggs\n- bread');
    });

    test('strips markers when every touched line already has one', () {
      final e = applyNoteFormat('- milk\n- eggs', _sel(0, 13),
          NoteFormatAction.bulletList);
      expect(e.text, 'milk\neggs');
    });

    test('a partly-listed block gets completed, not stripped', () {
      final e = applyNoteFormat('- milk\neggs', _sel(0, 11),
          NoteFormatAction.bulletList);
      expect(e.text, '- milk\n- eggs');
    });

    test('an ordered list counts as listed and can be stripped', () {
      final e = applyNoteFormat('1. milk\n2. eggs', _sel(0, 15),
          NoteFormatAction.bulletList);
      expect(e.text, 'milk\neggs');
    });

    test('indentation and blank lines survive', () {
      final e = applyNoteFormat('  milk\n\n  eggs', _sel(0, 14),
          NoteFormatAction.bulletList);
      expect(e.text, '  - milk\n\n  - eggs');
    });
  });

  group('the formatting strip is wired to the real editor', () {
    testWidgets('tapping Bold wraps the typed word and keeps the caret usable',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final mainProvider = MainProvider();
      final settings = AppSettings();
      const verse = Verse(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          text: 'In the beginning God created the heavens and the earth.');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mainProvider),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showNoteEditor(
                    context: context,
                    verses: const [verse],
                    locale: 'en',
                    mainProvider: mainProvider,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final body = find.byType(TextField).last;
      await tester.enterText(body, 'grace');
      await tester.pump();

      // Select the whole word, the way a double-tap would.
      final field = tester.widget<TextField>(body);
      field.controller!.selection = _sel(0, 5);
      await tester.pump();

      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Italic'), findsOneWidget);
      expect(find.byTooltip('Bulleted list'), findsOneWidget);

      await tester.tap(find.byTooltip('Bold'));
      await tester.pump();

      expect(field.controller!.text, '**grace**');
      // The caret went back to the body, so the next keystroke lands
      // in the note rather than nowhere.
      expect(field.focusNode!.hasFocus, isTrue);

      await tester.tap(find.byTooltip('Bulleted list'));
      await tester.pump();
      expect(field.controller!.text, '- **grace**');

      // Same 10 s enforceTimer wind-down the chip-strip test documents:
      // dismissing by tap trips a pre-existing post-dismiss
      // restoreScroll fragility unrelated to formatting.
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('the editor renders formatting without eating characters',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final mainProvider = MainProvider();
      final settings = AppSettings();
      const verse = Verse(
          book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mainProvider),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showNoteEditor(
                    context: context,
                    verses: const [verse],
                    locale: 'en',
                    mainProvider: mainProvider,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      const typed = '**bold** and *italic* and 5 * 4 = 20';
      await tester.enterText(find.byType(TextField).last, typed);
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'source-mode spans must satisfy the '
              'TextEditingController length invariant');

      // The controller still holds every character the user typed —
      // the editor styles the delimiters, it does not remove them.
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, typed);

      await tester.pump(const Duration(seconds: 11));
    });
  });
}
