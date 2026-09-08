import 'package:flutter/material.dart';
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
}
