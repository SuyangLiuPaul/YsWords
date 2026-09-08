import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/originals_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/services/tagged_text_service.dart';
import 'package:yswords/widgets/originals_sheet.dart';

/// The owner's screenshot, reproduced and then fixed.
///
/// 2026-09-08: 「这个还没做好 words要看选择可以看到的有数字的和翻译可以选
/// 版本的」 — in Words, the reader should be able to SEE the numbered
/// line, and the translation should let them PICK a version. He was
/// reading 和合本雅偉版 **繁體**, and got a grid of word cards with no
/// line and no control.
///
/// Both halves of that failed for reasons no unit test could reach:
///
///   * `assets/tagged/` held one directory, `cuvs-yhwh`, so the
///     Traditional edition had no runs to draw;
///   * the line the sheet drew for the editions that DID have runs
///     printed no numbers at all.
///
/// So this file drives the real widget on the real assets, on the exact
/// version he was reading.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const genesis11 = Verse(
    book: '創世紀',
    chapter: 1,
    verse: 1,
    text: '起初，神創造天地。',
  );

  /// Real file I/O never completes inside `testWidgets`' fake-async
  /// zone, so every asset the sheet reads is pulled into its service's
  /// static cache first and the widget's awaits then resolve from
  /// memory. Same note as `originals_sheet_chinese_lexicon_test.dart`.
  Future<void> warmCaches(WidgetTester tester, String version) =>
      tester.runAsync(() async {
        await OriginalsService.forVerse('Genesis', 1, 1, version: version);
        await TaggedTextService.forVerse(
            version: version,
            englishBook: 'Genesis',
            chapter: 1,
            verse: 1);
        for (final n in ['H7225', 'H430', 'H1254', 'H8064', 'H776']) {
          await StrongsService.lookup(n);
          await ConcordanceService.lookup(n, version: version);
        }
      });

  Widget sheet(String currentVersion, {String locale = 'zh-Hant'}) =>
      MultiProvider(
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
              currentVersion: currentVersion,
            ),
          ),
        ),
      );

  /// Every string in the tree, flattened — the tagged line is one
  /// `Text.rich`, so its numbers are not findable as separate widgets.
  String renderedText(WidgetTester tester) {
    final buffer = StringBuffer();
    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      buffer.write(w.text.toPlainText());
      buffer.write('\n');
    }
    return buffer.toString();
  }

  testWidgets('a 繁體 reader gets the numbered line in their own script',
      (tester) async {
    await warmCaches(tester, 'cuvs-yhwh-tr');
    await tester.pumpWidget(sheet('cuvs-yhwh-tr'));
    await tester.pumpAndSettle();

    final text = renderedText(tester);
    // Traditional characters, from the derived layer — 創造 and not
    // 创造. Before this layer existed the sheet fell back to the plain
    // verse here, which contains the same characters, so the number
    // below is what actually distinguishes the two states.
    expect(text, contains('創造'));
    // The numbers. This is the half of the request the picker does not
    // deliver: 起初 H7225, 神 H430, 創造 H1254.
    expect(text, contains('H7225'));
    expect(text, contains('H1254'));
    // The picker, on the reader's own edition because it is now tagged.
    expect(find.text('和合本雅偉版(繁體)'), findsOneWidget);
    // ...and no "we substituted somebody else's translation" note.
    expect(find.textContaining('沒有原文編號對照'), findsNothing);
  });

  testWidgets('the numbers go behind showStrongsInOriginals, the switch '
      'that already governs this sheet\'s other badges', (tester) async {
    await warmCaches(tester, 'cuvs-yhwh-tr');
    final settings = AppSettings();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: OriginalsSheet(
            verses: [genesis11],
            allVerses: [genesis11],
            locale: 'zh-Hant',
            currentVersion: 'cuvs-yhwh-tr',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(renderedText(tester), contains('H7225'));

    await tester.runAsync(() => settings.setShowStrongsInOriginals(false));
    await tester.pumpAndSettle();
    final off = renderedText(tester);
    // The words stay; only the apparatus goes.
    expect(off, contains('創造'));
    expect(off, isNot(contains('H7225')));
  });

  testWidgets('a reader on an untagged edition is told whose translation '
      'the line is', (tester) async {
    await warmCaches(tester, 'cuvs-yhwh-tr');
    await tester.runAsync(() async {
      await OriginalsService.forVerse('Genesis', 1, 1,
          version: 'biblexg-v2-tr');
    });
    await tester.pumpWidget(sheet('biblexg-v2-tr'));
    await tester.pumpAndSettle();

    // Nothing narrows in silence: the substitution is named, and the
    // edition substituted is the one in the reader's OWN script.
    expect(find.textContaining('沒有原文編號對照，下面這行是'), findsOneWidget);
    expect(find.text('和合本雅偉版(繁體)'), findsOneWidget);
  });

  /// Tap the word [word] where it stands in the tagged line.
  ///
  /// A real hit test at a real pixel, not a poke at the recognizer:
  /// the owner's report is that the gesture does not arrive, and a
  /// test that reaches into the span and calls `onTap` itself would
  /// pass on the day the line stopped receiving taps at all.
  Future<void> tapInLine(WidgetTester tester, String word) async {
    // The line, not the H7225 badge under the רֵאשִׁית chip in the
    // grid — both are `RichText` and both carry the number.
    final finder = find.byWidgetPredicate((w) =>
        w is RichText &&
        w.text.toPlainText().contains('H7225') &&
        w.text.toPlainText().contains('H430'));
    expect(finder, findsOneWidget, reason: 'the tagged line should be on screen');
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    final plain = paragraph.text.toPlainText();
    final start = plain.indexOf(word);
    expect(start, isNonNegative, reason: '$word should be in the line');
    final a = paragraph.getOffsetForCaret(
        TextPosition(offset: start), Rect.zero);
    final b = paragraph.getOffsetForCaret(
        TextPosition(offset: start + word.length), Rect.zero);
    final height =
        paragraph.getFullHeightForCaret(TextPosition(offset: start));
    final local = Offset((a.dx + b.dx) / 2, a.dy + height / 2);
    await tester.tapAt(paragraph.localToGlobal(local));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a word in the numbered line opens its lexicon entry',
      (tester) async {
    await warmCaches(tester, 'cuvs-yhwh-tr');
    await tester.pumpWidget(sheet('cuvs-yhwh-tr'));
    await tester.pumpAndSettle();

    // Nothing is open yet: the back arrow belongs to the entry card
    // and is drawn only while a root entry is being browsed, which is
    // the state a tap on the line is supposed to produce.
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    // H7225 is on screen once already — the badge under the רֵאשִׁית
    // chip in the grid below. The entry card adds a second.
    expect(find.text('H7225'), findsOneWidget);

    await tapInLine(tester, '起初');

    expect(find.byIcon(Icons.arrow_back), findsOneWidget,
        reason: 'the tap should have opened the lexicon entry');
    // And the reader can SEE it. That is the half that failed: the
    // entry resolved and the card was built at the FOOT of a
    // 2,000-pixel list, below the verse line and below the whole grid
    // of word chips — 41 logical pixels past the bottom of a
    // 339-pixel viewport on this surface, further on a phone. Nothing
    // on screen moved, so 摩西 read as dead.
    final list = tester.getRect(find.byType(ListView));
    final card = tester.getRect(find.byIcon(Icons.arrow_back));
    expect(card.top, greaterThanOrEqualTo(list.top));
    expect(card.bottom, lessThanOrEqualTo(list.bottom));
  });

  testWidgets('the number is part of the word it tags, not a dead zone',
      (tester) async {
    await warmCaches(tester, 'cuvs-yhwh-tr');
    await tester.pumpWidget(sheet('cuvs-yhwh-tr'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    // `摩西 H4872` reads as one thing and the owner circled the whole of
    // it. Half of it used to answer nothing.
    await tapInLine(tester, 'H7225');
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('the line\'s tap recognizers outlive a rebuild', (tester) async {
    await warmCaches(tester, 'cuvs-yhwh-tr');
    final settings = AppSettings();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: OriginalsSheet(
            verses: [genesis11],
            allVerses: [genesis11],
            locale: 'zh-Hant',
            currentVersion: 'cuvs-yhwh-tr',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    GestureRecognizer? recognizerFor(String word) {
      final line = find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('H7225') &&
          w.text.toPlainText().contains('H430'));
      final paragraph = tester.renderObject<RenderParagraph>(line);
      final at = paragraph.text.toPlainText().indexOf(word);
      final span = paragraph.text.getSpanForPosition(TextPosition(offset: at));
      return (span as TextSpan?)?.recognizer;
    }

    final before = recognizerFor('起初');
    expect(before, isNotNull);
    // A rebuild the reader can cause without touching the line at all.
    await tester.runAsync(() => settings.setShowStrongsInOriginals(false));
    await tester.pumpAndSettle();
    await tester.runAsync(() => settings.setShowStrongsInOriginals(true));
    await tester.pumpAndSettle();

    // The same object, not a fresh one. Each build used to mint a
    // TapGestureRecognizer per run and drop the last build's on the
    // floor undisposed — and they could not simply be added to
    // `_tapRecognizers`, which `_loadRootEntry` empties from inside a
    // tap callback and would therefore dispose mid-gesture.
    expect(identical(recognizerFor('起初'), before), isTrue);
  });
}
