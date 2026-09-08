import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/chinese_lexicon_service.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/originals_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/services/tagged_text_service.dart';
import 'package:yswords/utils/strongs_inline.dart';
import 'package:yswords/widgets/originals_sheet.dart';

/// The word-study sheet — the surface this port was actually for.
///
/// `chinese_lexicon_test.dart` proves the module answers, and
/// `strongs_entry_grammar_code_test.dart` proves the standalone entry
/// page asks it. This file covers the sheet a reader reaches by tapping
/// a word while reading, where two claims have to hold that neither
/// other file can check:
///
///   * the fuller article appears BELOW the CBOL definition and its
///     CC-BY-NC-SA attribution line, not in place of them;
///   * the decoded grammar codes belong to the run the reader tapped
///     and do not survive onto the next word they open.
///
/// One thing here is NOT covered, and is written down rather than left
/// to look covered. `_loadRootEntry` takes the tapped run as an
/// explicit argument instead of reading `_impliedRun`, because that
/// field outlives the tap that set it and a word-family or synonym chip
/// tapped afterwards would otherwise inherit the previous run's codes.
/// The last test below exercises the ORIGINAL-WORD-CHIP path, which
/// clears `_impliedRun` itself and so stays green either way —
/// confirmed by making `_loadChinese` read `_impliedRun` and watching
/// all four tests still pass. Reaching the path that would fail needs a
/// verse whose lemma has a word family to tap; 创世记 1:1 renders none,
/// so the explicit argument is defensive, and stated as such.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const genesis11 = Verse(
    book: '创世记',
    chapter: 1,
    verse: 1,
    text: '起初，神创造天地。',
  );

  /// See the note in `strongs_entry_grammar_code_test.dart`: real file
  /// I/O never completes inside `testWidgets`' fake-async zone, so every
  /// asset the sheet reads is pulled into its service's static cache
  /// first and the widget's awaits then resolve from memory.
  Future<void> warmCaches(WidgetTester tester) => tester.runAsync(() async {
        await OriginalsService.forVerse('Genesis', 1, 1,
            version: 'cuvs-yhwh');
        await TaggedTextService.forVerse(
            version: 'cuvs-yhwh',
            englishBook: 'Genesis',
            chapter: 1,
            verse: 1);
        await StrongsService.lookup('H7225');
        await ConcordanceService.lookup('H7225', version: 'cuvs-yhwh');
        await StrongsService.lookup('H1254');
        await ConcordanceService.lookup('H1254', version: 'cuvs-yhwh');
        await ChineseLexiconService.lookup('H7225');
        await ChineseLexiconService.lookup('H8804');
      });

  Widget sheet(String locale) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OriginalsSheet(
              verses: const [genesis11],
              allVerses: const [genesis11],
              locale: locale,
              currentVersion: 'cuvs-yhwh',
            ),
          ),
        ),
      );

  /// Clear the sheet's own pre-existing debug-only complaint, and fail
  /// on anything else.
  ///
  /// Building the concordance section trips Flutter's ink-effects
  /// assertion — a `ListTile` inside a `DecoratedBox` that carries a
  /// background colour, whose nearest `Material` is above the box. It is
  /// nothing to do with this port: hiding the lexicon block entirely and
  /// re-running this file still raises it. In the app the same structure
  /// is mounted through `showModalBottomSheet` and the assertion only
  /// runs in debug, which is why it has never been seen. Swallowed
  /// NARROWLY so a real exception from the sheet still fails the test.
  void expectOnlyTheKnownInkWarning(WidgetTester tester) {
    final e = tester.takeException();
    if (e == null) return;
    expect(e.toString(), contains('ListTile'),
        reason: 'the sheet threw something other than the known '
            'ink-effects warning');
  }

  /// Pump, then scroll the sheet until [target] has been built — it is a
  /// lazy list and the lexicon block sits well below the fold.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 25 && target.evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pump();
    }
  }

  /// Fire the tagged line's span recogniser for one run.
  ///
  /// The line is a single `Text.rich` whose runs are SPANS with their
  /// own recognisers, so there is no widget to hand `tap`. This used to
  /// be done by offset — the test font is Ahem, every glyph exactly
  /// `fontSize` wide, 「起初，神创造天地。」 putting 创 at index 4. On
  /// 2026-09-08 the line grew the Strong's numbers, so its plain text is
  /// now 「起初 H7225 ，神 H430 创造 H1254 H8804 …」 and no arithmetic over
  /// the verse's own characters lands anywhere. Firing the recogniser is
  /// what `implied_coverage_sheet_test.dart` already does, and it does
  /// not care where on the line the run sits.
  ///
  /// Matched on the STEM: the number has to land against the word rather
  /// than after the punctuation the source baked onto it, so the
  /// tappable span is 创造 and any trailing 。/，is a span of its own.
  void tapRun(WidgetTester tester, String run) {
    final (stem, _) = splitTrailingCjkPunctuation(run);
    TextSpan? target;
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final span = text.textSpan;
      if (span is! TextSpan) continue;
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan &&
            (child.text == run || child.text == stem) &&
            child.recognizer is TapGestureRecognizer) {
          target = child;
        }
      }
    }
    expect(target, isNotNull,
        reason: 'no tappable run "$run" on the tagged line');
    (target!.recognizer! as TapGestureRecognizer).onTap!();
  }

  testWidgets('tapping an original word puts the fuller article under the '
      'CBOL definition, with the CBOL attribution still between them',
      (tester) async {
    await warmCaches(tester);
    await tester.pumpWidget(sheet('zh-Hans'));
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }

    // Open the first original-language word chip. Targeted by its
    // Strong's number rather than its Hebrew: the rendered lemma carries
    // cantillation marks whose combining order a literal in this file
    // does not reliably reproduce.
    await tester.tap(find.text('H7225').first, warnIfMissed: false);
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }

    final header = find.text(uiStrings['chineseLexTitle']!['zh-Hans']!);
    await reveal(tester, header);
    expectOnlyTheKnownInkWarning(tester);
    expect(header, findsOneWidget,
        reason: 'the fuller article never rendered on the word-study sheet');
    // The CBOL source line the sheet showed before the port is still
    // there — this is the "does not replace" claim, on screen.
    expect(find.textContaining('CBOL · bible.fhl.net'), findsOneWidget);
  });

  testWidgets('an English reader gets neither the article nor its heading, '
      'and so never pays the asset load', (tester) async {
    await warmCaches(tester);
    await tester.pumpWidget(sheet('en'));
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('H7225').first, warnIfMissed: false);
    final header = find.text(uiStrings['chineseLexTitle']!['en']!);
    await reveal(tester, header);
    expectOnlyTheKnownInkWarning(tester);
    expect(header, findsNothing);
  });

  testWidgets('tapping a Chinese word decodes the grammar code on that run '
      '— the blue number nothing in the app could explain before',
      (tester) async {
    await warmCaches(tester);
    await tester.pumpWidget(sheet('zh-Hans'));
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }

    // 创造 in 创世记 1:1 is the one run in the verse that carries a
    // grammar code: H8804, Qal perfect.
    tapRun(tester, '创造');
    for (var i = 0; i < 16; i++) {
      await tester.pump();
    }

    final heading = find.text(uiStrings['chineseLexGrammarTitle']!['zh-Hans']!);
    await reveal(tester, heading);
    expectOnlyTheKnownInkWarning(tester);
    expect(heading, findsOneWidget);
    expect(find.textContaining('H8804'), findsWidgets);
    expect(find.textContaining('Perfect'), findsOneWidget);
  });

  testWidgets('and those codes do not follow the reader onto the next word '
      '— they parse that run, not whatever entry is on screen later',
      (tester) async {
    await warmCaches(tester);
    await tester.pumpWidget(sheet('zh-Hans'));
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }

    // Tap 创造 (H1254, carries H8804) …
    tapRun(tester, '创造');
    for (var i = 0; i < 16; i++) {
      await tester.pump();
    }
    final heading = find.text(uiStrings['chineseLexGrammarTitle']!['zh-Hans']!);
    await reveal(tester, heading);
    expectOnlyTheKnownInkWarning(tester);
    expect(heading, findsOneWidget, reason: 'setup: the codes must appear '
        'before their disappearance means anything');

    // … then an original-word chip for a different number, which has no
    // grammar of its own. H8804 must not still be on screen.
    await tester.tap(find.text('H7225').first, warnIfMissed: false);
    for (var i = 0; i < 16; i++) {
      await tester.pump();
    }
    expectOnlyTheKnownInkWarning(tester);
    expect(heading, findsNothing);
    // 2026-09-08: was `findsNothing`. H8804 is still on screen once, and
    // has to be: the tagged line now prints the Strong's numbers in it,
    // and H8804 is 创造's grammar code — a fact about the VERSE, which
    // does not stop being true because the reader opened a different
    // entry. What must be gone is the decoded block under the card,
    // which is what `heading` above is.
    expect(find.textContaining('H8804'), findsOneWidget);
  });
}
