import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/originals_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/services/tagged_text_service.dart';
import 'package:yswords/widgets/implied_coverage_line.dart';
import 'package:yswords/widgets/originals_sheet.dart';

/// The same rules as `implied_coverage_line_test.dart`, but driven
/// through the real sheet on the real assets — because the line's whole
/// claim is about a *tapped* run, and a unit test on the widget cannot
/// show that the right run answers, that the line trails the primary
/// entry rather than leading it, or that a run with nothing to add
/// stays silent when it is tapped.
///
/// 創世記 1:1 is the fixture because the corpus gives it both cases in
/// one verse: 「起初，」 has no `i` at all and 「天」 has `i: ["H853"]` —
/// אֵת, the direct-object marker, which the Chinese does not spell and
/// which no run of that verse carries as its `s`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `pumpAndSettle` cannot be used here: the sheet shows a
  // CircularProgressIndicator while it resolves, and an indeterminate
  // spinner never lets the frame scheduler go quiet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Every asset the sheet reads, pulled in through `runAsync` first.
  ///
  /// `rootBundle` is real I/O and cannot complete inside the fake async
  /// zone a pumped widget runs in — without this the sheet's future
  /// never resolves and the verse never renders, which looks exactly
  /// like the feature being broken. All four services memoise
  /// statically, so once warmed the sheet's awaits land on microtasks
  /// that `pump` drains.
  Future<void> warm(WidgetTester tester, String englishBook, Verse v) async {
    await tester.runAsync(() async {
      await TaggedTextService.forVerse(
        version: 'cuvs-yhwh',
        englishBook: englishBook,
        chapter: v.chapter,
        verse: v.verse,
      );
      await OriginalsService.forVerse(englishBook, v.chapter, v.verse,
          version: 'cuvs-yhwh');
      await StrongsService.lookup('H1');
      await StrongsService.lookup('G1');
      await ConcordanceService.lookup('H1', version: 'cuvs-yhwh');
    });
  }

  Future<void> open(WidgetTester tester, Verse verse) async {
    // The sheet is one long ListView whose children are built lazily, so
    // on a phone-sized surface the entry card and everything under it —
    // the implied line included — is never constructed, and
    // `find.byType` reports the feature missing when it is merely
    // offscreen. A tall window instead of scrolling, so a layout change
    // cannot quietly turn these assertions into no-ops.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(1200, 6000);
    view.devicePixelRatio = 1.0;

    // The entry card's concordance section wraps a ListTile in a
    // DecoratedBox that paints a background, which Flutter asserts about
    // in debug. It predates this feature and has nothing to do with it,
    // but it would otherwise fail every test here as an unexpected
    // exception. Swallowed by its exact message — set here rather than
    // in setUp, because `testWidgets` installs its own handler when the
    // test body starts and would overwrite an earlier one. Anything
    // else still fails loudly.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details
          .exceptionAsString()
          .contains('ListTile background color or ink splashes')) {
        return;
      }
      onError?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = onError;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: OriginalsSheet(
              verses: [verse],
              locale: 'zh-Hans',
              currentVersion: 'cuvs-yhwh',
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  // The tagged line is one `Text.rich`, so a run is a TextSpan and not
  // a Text widget of its own: `find.text` cannot reach it, and
  // `tapOnText` refuses 「天」 because 創世記 1:1's own word chips print
  // the same character three more times. Fire the span's recognizer,
  // which is the callback a real tap dispatches to.
  Future<void> tapRun(WidgetTester tester, String run) async {
    TextSpan? target;
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final span = text.textSpan;
      if (span is! TextSpan) continue;
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan &&
            child.text == run &&
            child.recognizer is TapGestureRecognizer) {
          target = child;
        }
      }
    }
    expect(target, isNotNull,
        reason: 'no tappable run "$run" on the tagged line');
    (target!.recognizer! as TapGestureRecognizer).onTap!();
    await settle(tester);
  }

  const genesis11 = Verse(
    book: '创世记',
    chapter: 1,
    verse: 1,
    text: '起初，神创造天地。',
  );

  const john35 = Verse(
    book: '约翰福音',
    chapter: 3,
    verse: 5,
    text: '耶稣说：“我实实在在的告诉你，人若不是从水和圣灵生的，就不能进神的国。',
  );

  testWidgets('tapping a run with `i` opens the line', (tester) async {
    await warm(tester, 'Genesis', genesis11);
    await open(tester, genesis11);
    expect(find.byType(ImpliedCoverageLine), findsNothing,
        reason: 'nothing is tapped yet, so there is nothing to be secondary to');

    await tapRun(tester, '天');

    expect(find.byType(ImpliedCoverageLine), findsOneWidget);
    expect(find.textContaining('「天」这段译文一并涵盖的其他原文词'), findsOneWidget);
    // Scoped: 創世記 1:1's original really has אֵת twice, so the
    // word chips above print H853 on their own account.
    expect(
      find.descendant(
          of: find.byType(ImpliedCoverageLine), matching: find.text('H853')),
      findsOneWidget,
    );
  });

  testWidgets('the primary answer leads and the implied line trails it',
      (tester) async {
    await warm(tester, 'Genesis', genesis11);
    await open(tester, genesis11);
    await tapRun(tester, '天');

    // 天 renders H8064 שָׁמַיִם, and the sheet says so twice above the
    // coverage line: the word chip for שָׁמַיִם carries H8064 with its
    // gloss, and the entry card headlines it. The line comes after the
    // chips and before the card, so a reader meets the primary answer
    // first either way.
    final line = tester.getTopLeft(find.byType(ImpliedCoverageLine));
    final chip = tester.getBottomLeft(find.text('H8064').first);
    expect(line.dy, greaterThan(chip.dy),
        reason: 'the coverage line must never sit above the chip row that '
            'gives the tapped run its own number');
    // The entry card's own H8064 badge — the last of the two on screen,
    // the first being the chip's.
    final card = tester.getTopLeft(find.text('H8064').last);
    expect(line.dy, lessThan(card.dy),
        reason: 'and it must stay inside the verse block, next to the span '
            'it describes — after the entry card it lands 2,500px down');

    // Every word of it is smaller than the verse it annotates.
    for (final text in tester.widgetList<Text>(find.descendant(
        of: find.byType(ImpliedCoverageLine), matching: find.byType(Text)))) {
      expect(text.style?.fontSize, lessThan(kTaggedVerseFontSize),
          reason: '"${text.data}" is not subordinate to the verse line');
    }
  });

  testWidgets('tapping a run with no `i` leaves the line closed',
      (tester) async {
    await warm(tester, 'Genesis', genesis11);
    await open(tester, genesis11);
    await tapRun(tester, '起初，');
    expect(find.byType(ImpliedCoverageLine), findsOneWidget,
        reason: 'the widget is in the tree — it is its output that is empty');
    // Zero HEIGHT, not zero size: the widget is a Column child and
    // still stretches to the list's width when it renders nothing.
    expect(tester.getSize(find.byType(ImpliedCoverageLine)).height, 0);
    expect(find.textContaining('这段译文一并涵盖'), findsNothing);
  });

  testWidgets('an `i` that only repeats the run\'s own `s` says nothing',
      (tester) async {
    // 約翰福音 3:5 「我实实在在的」 ships as s=G281 with i=["G281"].
    await warm(tester, 'John', john35);
    await open(tester, john35);
    await tapRun(tester, '我实实在在的');
    expect(tester.getSize(find.byType(ImpliedCoverageLine)).height, 0);

    // The same verse's 的国。 has i:["G3588"], and that one does speak.
    // This is the verse the span repair was argued over: beforehand both
    // 神 and 的国。 showed G3588, so ὁ was reachable twice while θεός and
    // βασιλεία were reachable nowhere; the repair inverted it. ὁ is
    // reachable again now, labelled as coverage rather than as the
    // word's own identity.
    await tapRun(tester, '的国。');
    expect(find.textContaining('「的国。」这段译文一并涵盖的其他原文词'),
        findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(ImpliedCoverageLine), matching: find.text('G3588')),
      findsOneWidget,
    );
  });
}
