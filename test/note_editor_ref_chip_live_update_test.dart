// 2026-07-31 (v1.3.149): regression guard for the "+ Verse Reference"
// button not live-updating the ref-chip strip.
//
// Root cause (confirmed against the Flutter SDK source, not just
// inference): `TextField.onChanged` only fires from
// `EditableTextState._formatAndSetValue`, which is the USER-input path
// (keyboard/IME). Programmatic writes to a `TextEditingController` go
// through `_didChangeTextEditingValue`, which only `setState()`s the
// field's own visible text — it never calls `onChanged`. The note
// editor's ref-chip strip is rebuilt from the sheet's OWN
// `setSheetState`, called inside `onChanged` for the typed-`[Book
// Ch:V]` path — but the "+ Verse Reference" button inserted its pick
// via `controller.value = ...` / `controller.text = ...` without ever
// calling `setSheetState`, so the chip silently failed to appear until
// something else (closing + reopening the editor after Save) forced a
// full rebuild.
//
// Field report: "为什么按了做笔记的经文下面没有实时加入经文在下面而保存
// 后才出现在下面" — this test drives the real button + picker flow and
// asserts the chip is visible BEFORE Save is ever tapped.

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
      'tapping + Verse Reference and inserting a pick shows the chip '
      'immediately, without tapping Save', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mainProvider = MainProvider();
    final settings = AppSettings();
    // Two verses so the picker has a real book/chapter/verse to walk
    // through (Genesis 1 is already the note's own subject, but the
    // picker operates over whatever's loaded in mainProvider.verses).
    const v1 = Verse(
        book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.');
    const v2 =
        Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'And the earth.');
    mainProvider.setVerses(const [v1, v2]);

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
                  verses: const [v1],
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

    // No chip yet — the note body is empty.
    expect(find.byType(ActionChip), findsNothing);

    // Tap "+ Verse" (label falls back to '+ Verse' when uiStrings
    // lacks the key in this test's minimal locale setup).
    final addRefButton = find.widgetWithIcon(TextButton, Icons.add_link_rounded);
    expect(addRefButton, findsOneWidget);
    await tester.tap(addRefButton);
    await tester.pumpAndSettle();

    // Picker sheet: book step. Note the grid also has a "Cancel"
    // OutlinedButton alongside the book tiles — target "Genesis" by
    // text, not `.first` (which would hit Cancel and dismiss the
    // picker instead of picking a book).
    expect(find.widgetWithText(OutlinedButton, 'Genesis'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Genesis'));
    await tester.pumpAndSettle();

    // Chapter step — only chapter 1 exists in the loaded verses.
    expect(find.widgetWithText(OutlinedButton, '1'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '1'));
    await tester.pumpAndSettle();

    // Verse step — tap verse 1's row by its rendered text. Material
    // buttons (OutlinedButton/FilledButton/TextButton) also wrap an
    // internal InkWell, so `find.byType(InkWell).first` is ambiguous;
    // tapping the verse's own text routes the gesture to its InkWell
    // ancestor unambiguously.
    expect(find.text('In the beginning.'), findsOneWidget);
    await tester.tap(find.text('In the beginning.'));
    await tester.pumpAndSettle();

    // Insert — pops the picker and returns the '[Book Ch:V]' string,
    // which the "+ Verse" onPressed inserts into the note body.
    final insertButton = find.widgetWithText(FilledButton, 'Insert');
    expect(insertButton, findsOneWidget);
    await tester.tap(insertButton);
    await tester.pumpAndSettle();

    // THE REGRESSION CHECK: the chip must already be visible here —
    // Save has never been tapped.
    expect(find.byType(ActionChip), findsOneWidget,
        reason: 'ref chip must appear immediately after inserting via '
            'the + Verse Reference button, not only after Save');

    // Let the sheet's own periodic scroll-restore enforceTimer tick
    // past its internal cap so it self-cancels before the test ends
    // (same technique as note_editor_chip_strip_test.dart — otherwise
    // the test framework's "Timer still pending" invariant check fails
    // at teardown, unrelated to what this test is actually verifying).
    await tester.pump(const Duration(seconds: 11));
  });
}
