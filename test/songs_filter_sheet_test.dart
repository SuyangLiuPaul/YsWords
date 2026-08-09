import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/songs_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_service.dart';

/// 2026-08-09. The Songs filter sheet grew a Media section on top of
/// the existing Language / Source / Theme / Book ones, which pushed
/// the Apply button below ~60 Theme + Book chips — you had to scroll
/// the whole sheet to reach the one control that closes it. Apply now
/// lives in the header row.
///
/// responsive_all_pages_smoke_test only ever pumps the PAGE, so a
/// modal sheet's layout was never exercised anywhere. These tests open
/// the real sheet at the narrowest supported width, which is where a
/// header carrying title + Clear + Apply + close is most likely to
/// overflow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // AppSettings defaults to zh-Hans, so the sheet renders 应用 / 语言,
  // not the English labels. Resolve through uiStrings rather than
  // hard-coding either language, so changing the default locale does
  // not silently turn these into no-ops.
  final locale = AppSettings().locale;
  final applyLabel = uiStrings['apply']![locale]!;
  final languageLabel = uiStrings['songsFilterLanguage']![locale]!;

  Future<void> pumpSongsPage(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;

    // Warm SongService's cache through runAsync first. The page reads
    // assets/songs.json via rootBundle, and that needs REAL async time
    // — tester.pump() only advances the fake clock, so without this the
    // FutureBuilder is still showing its spinner and the search/filter
    // bar (and therefore the Filter button) does not exist yet.
    // SongService memoises, so the widget's own load() then resolves
    // from cache.
    await tester.runAsync(SongService.load);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: SongsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> openFilterSheet(WidgetTester tester) async {
    // The button swaps icon when a filter is active; nothing is
    // selected in these tests, so it is the plain one.
    final filterButton = find.byIcon(Icons.filter_list);
    expect(filterButton, findsOneWidget,
        reason: 'the Filter button should be on the search bar');
    await tester.tap(filterButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  const sizes = <String, Size>{
    'SE 320': Size(320, 568),
    'phone 390': Size(390, 844),
    'tablet 768': Size(768, 1024),
  };

  for (final entry in sizes.entries) {
    testWidgets('filter sheet @ ${entry.key}: no overflow, Apply reachable '
        'without scrolling', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(tester.view.reset);

      await pumpSongsPage(tester, entry.value);
      await openFilterSheet(tester);

      expect(tester.takeException(), isNull,
          reason: 'the filter sheet threw during layout at ${entry.key}');

      // Apply must be hit-testable on the first frame the sheet is
      // open — that is the whole point of moving it into the header.
      final apply = find.widgetWithText(FilledButton, applyLabel);
      expect(apply, findsOneWidget);
      await tester.tap(apply);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    });
  }

  testWidgets('Apply sits above the scrollable filter body', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    await pumpSongsPage(tester, const Size(390, 844));
    await openFilterSheet(tester);

    final apply = find.widgetWithText(FilledButton, applyLabel);
    final language = find.text(languageLabel);
    expect(apply, findsOneWidget);
    expect(language, findsOneWidget);

    // Header row, so it renders above the first filter section rather
    // than after the last one.
    expect(
      tester.getTopLeft(apply).dy,
      lessThan(tester.getTopLeft(language).dy),
      reason: 'Apply should be in the header, not below the filters',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
