import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/widgets/bible_reading_pane.dart' show showNoteEditor;

/// 2026-07-19: regression test for the note-editor ref-chip strip.
/// A note with many (or repeated) `[Book Ch:V]` references used to
/// render inside an unbounded `Wrap`, which — being a non-flex
/// sibling of the `Expanded` body `TextField` — grew to consume
/// more and more vertical space, squeezing the writing area down to
/// a sliver. The fix caps the strip at a fixed-height horizontal
/// `ListView`. This test pumps the real `showNoteEditor` sheet,
/// types a note body with 15 references (including duplicates —
/// `extractNoteReferences` intentionally does not dedup), and
/// asserts the fix's two load-bearing properties directly.
void main() {
  testWidgets(
      'note editor ref-chip strip stays a bounded horizontal ListView '
      'and never overflows, even with many duplicate refs', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Narrow phone width — the original bug was worst here, where
    // there's the least vertical headroom for the Wrap to steal from
    // the writing TextField.
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mainProvider = MainProvider();
    final settings = AppSettings();
    const verse =
        Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning God created the heavens and the earth.');

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

    const refs = '[John 3:16] [John 3:16] [John 3:16] [John 3:16] [John 3:16] '
        '[Matt 5:1] [Matt 5:1] [Matt 5:1] [Rom 8:28] [Rom 8:28] [Rom 8:28] '
        '[Gen 1:1] [Gen 1:1] [Ps 23:1] [Ps 23:1]';
    await tester.enterText(find.byType(TextField).last, refs);
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason:
            'entering a note with many duplicate refs must not overflow the sheet');

    // The old unbounded Wrap is gone; the strip is a bounded,
    // horizontally-scrolling ListView instead.
    expect(find.byType(Wrap), findsNothing);
    final horizontalListViews = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal);
    expect(horizontalListViews, findsOneWidget);

    // All 15 refs (duplicates included — no dedup) reached the
    // ListView's item count. ListView.separated interleaves a
    // separator between each pair of items, so its delegate's
    // childCount is 2*itemCount - 1. Checked via the delegate
    // (not `find.byType(ActionChip)`) because ListView only builds
    // the chips currently within its viewport — the rest exist
    // virtually until scrolled into view, which is the fix's whole
    // point (bounded footprint regardless of ref count).
    final listView = tester.widget<ListView>(horizontalListViews);
    final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 2 * 15 - 1);

    // At least the chips that fit in the visible strip actually
    // rendered (proves refs parsed correctly, not just an empty
    // bounded box).
    expect(find.byType(ActionChip), findsWidgets);

    // Let the sheet's own 10 s enforceTimer (a periodic scroll-restore
    // safeguard, unrelated to this test's subject) tick past its
    // internal 625-tick cap so it self-cancels, rather than tapping
    // the close button — dismissing via a tap interacts with a
    // documented pre-existing fragility in this sheet's multi-shot
    // restoreScroll callbacks (post-dismiss Future.delayed callbacks
    // touching a deactivated context), which is orthogonal to the
    // chip-strip fix under test here.
    await tester.pump(const Duration(seconds: 11));
  });
}
