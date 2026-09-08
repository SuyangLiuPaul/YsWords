import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/strongs_entry_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/chinese_lexicon_service.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/strongs_service.dart';

/// The dead end this port closed, tested through the page rather than
/// the service.
///
/// The search bar routes any Strong's-SHAPED string to
/// [StrongsEntryPage]. The 284 grammar codes on the tagged corpus are
/// Strong's-shaped — H8804 looks exactly like H430 — but they sit above
/// the top of both shipped lexicons, so `StrongsService.lookup` returned
/// null and the page answered 「找不到该编号」 for every one of them. A
/// reader who saw H8804 beside a word and searched it was told the
/// number does not exist.
///
/// `chinese_lexicon_test.dart` proves the module can decode the code;
/// this file proves the page asks it to. Without the wiring the tests
/// below fail while every test in that file still passes, which is the
/// point of writing them separately — verified by removing the branch
/// and the block in turn and watching them go red.
///
/// The last group covers the other half of the port on this page: the
/// fuller article must appear UNDER the CBOL definition, never instead
/// of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// Pull every asset these three lookups touch into its service's
  /// static cache before the widget is pumped.
  ///
  /// `testWidgets` runs in a fake-async zone where real file I/O never
  /// completes, so a page that awaits a 5 MB `rootBundle.loadString`
  /// sits on its spinner forever and `pumpAndSettle` times out on the
  /// spinner's own endless animation. Warming inside `runAsync` leaves
  /// the page's awaits resolving from memory, which the fake zone can
  /// drain. This is a harness detail — the page does the same work
  /// either way.
  Future<void> warmCaches(WidgetTester tester) => tester.runAsync(() async {
        await StrongsService.lookup('H430');
        await StrongsService.lookup('G25');
        await ConcordanceService.lookup('H430', version: 'kjv');
        await ChineseLexiconService.lookup('H8804');
        await ChineseLexiconService.lookup('G5656');
      });

  /// The locale a fresh [AppSettings] starts in — the app ships
  /// Simplified Chinese as its default, and asserting against the
  /// English strings quietly matched nothing at all in an earlier draft
  /// of this file.
  final locale = AppSettings().locale;

  Widget page(String number) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(home: StrongsEntryPage(number: number)),
      );

  testWidgets('searching a grammar code is answered with its parsing, not '
      'with "number not found"', (tester) async {
    await warmCaches(tester);
    await tester.pumpWidget(page('H8804'));
    await tester.pump();
    await tester.pump();

    expect(find.text(uiStrings['strongsNotFound']![locale]!), findsNothing);
    expect(find.textContaining('H8804'), findsWidgets);
    expect(find.textContaining('Perfect'), findsOneWidget);
  });

  testWidgets('and is labelled a grammar code, so a parsing note is not '
      'mistaken for a word entry', (tester) async {
    await warmCaches(tester);
    await tester.pumpWidget(page('G5656'));
    await tester.pump();
    await tester.pump();

    expect(find.text(uiStrings['chineseLexGrammarTitle']![locale]!),
        findsOneWidget);
    expect(find.text(uiStrings['chineseLexGrammarOnly']![locale]!),
        findsOneWidget);
    expect(find.textContaining('简单过去式'), findsOneWidget);
  });

  testWidgets('a number that is neither a word nor a grammar code still '
      'says so — the rescue did not swallow the honest failure',
      (tester) async {
    await warmCaches(tester);
    await tester.pumpWidget(page('H99999'));
    await tester.pump();
    await tester.pump();

    expect(find.text(uiStrings['strongsNotFound']![locale]!), findsOneWidget);
  });

  group('the fuller article on the entry page', () {
    testWidgets('appears under the CBOL definition rather than replacing '
        'it — two sources for one number, both still on screen',
        (tester) async {
      await warmCaches(tester);
      await tester.runAsync(() => ChineseLexiconService.lookup('H430'));
      await tester.pumpWidget(page('H430'));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      // The CBOL line the page already showed before the port, still
      // the first thing under the lemma card.
      final cbol = (await StrongsService.lookup('H430'))!;
      expect(find.text(cbol.localizedGloss(locale)), findsOneWidget);

      // And the article below it. The page is a lazy ListView, so this
      // has to be scrolled into existence rather than merely found.
      final header = find.text(uiStrings['chineseLexTitle']![locale]!);
      for (var i = 0; i < 12 && header.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pump();
      }
      expect(header, findsOneWidget);
      expect(find.textContaining('钦定本'), findsWidgets);
    });

    testWidgets('is not offered to an English reader, who never pays the '
        'asset load for it', (tester) async {
      await warmCaches(tester);
      final english = AppSettings();
      await english.setLocale('en');
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider<AppSettings>.value(value: english),
        ],
        child: const MaterialApp(home: StrongsEntryPage(number: 'H430')),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      final header = find.text(uiStrings['chineseLexTitle']!['en']!);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pump();
      }
      expect(header, findsNothing);
      // AppSettings.notifyListeners debounces; drain it so the test
      // does not end with a pending timer.
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
