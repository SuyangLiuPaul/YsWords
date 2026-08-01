// 2026-08-02: regression test for LIVE (not just save-time) book-name
// localization in the note editor.
//
// Field report: after shipping save-time normalization
// (normalizeNoteReferenceBookNames, wired into the Save button), the
// user reported "还是没有变" (still hasn't changed) — twice, with the
// same screenshot. The save-time fix was correct but invisible until
// Save+reopen, which reads exactly like "not working" even though it
// would have converted on the next save. This test drives the real
// TextField the way a user typing would (tester.enterText simulates
// the field's value changing to end in a freshly-typed "]"), and
// asserts the CONTROLLER'S TEXT itself — not just the read-only chip
// strip — is rewritten immediately, with no Save tap involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/widgets/bible_reading_pane.dart' show showNoteEditor;

void main() {
  testWidgets(
      'typing a reference that closes with "]" localizes its book name '
      'immediately, without tapping Save', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mainProvider = MainProvider();
    // Default currentVersion ('cuvs-yhwh') drives the localization —
    // localeAwareBookName prioritizes the READING VERSION's script
    // over the raw `locale` string, matching what the chip strip
    // already does and what the field report's screenshot showed
    // (a Chinese-version verse header alongside a hand-typed English
    // reference).
    final settings = AppSettings();
    const verse = Verse(
        book: '创世记', chapter: 1, verse: 1, text: '起初，神创造天地。');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MainProvider>.value(value: mainProvider),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showNoteEditor(
                  context: context,
                  verses: const [verse],
                  locale: 'zh-Hans',
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

    // Type an English abbreviation directly into the note body — the
    // scenario from the field report, not the "+ Verse" picker (which
    // already inserts pre-localized text). `enterText` sets the whole
    // field value at once with the cursor at the END of the entered
    // string — to simulate "the user just typed the closing bracket"
    // (the trigger this feature actually watches for), the entered
    // text must itself END in "]", matching where a real keystroke's
    // cursor would sit at that instant.
    await tester.enterText(
        find.byType(TextField).last, 'See [1 Kings 17:21]');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'See [列王纪上 17:21]',
        reason: 'the book name must be localized the instant the '
            'closing "]" is typed — not only after Save+reopen');

    // Sheet's own periodic scroll-restore enforceTimer self-cancels
    // past its internal cap — see note_editor_chip_strip_test.dart's
    // matching comment for why this is needed before the test ends.
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('an incomplete reference (no closing bracket yet) is left '
      'untouched', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mainProvider = MainProvider();
    final settings = AppSettings();
    const verse = Verse(
        book: '创世记', chapter: 1, verse: 1, text: '起初，神创造天地。');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MainProvider>.value(value: mainProvider),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showNoteEditor(
                  context: context,
                  verses: const [verse],
                  locale: 'zh-Hans',
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

    await tester.enterText(
        find.byType(TextField).last, 'Still typing [1 Kings 17:21');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'Still typing [1 Kings 17:21',
        reason: 'must never touch a reference the user has not finished '
            'typing yet (no closing bracket)');

    await tester.pump(const Duration(seconds: 11));
  });
}
