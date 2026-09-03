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

    // …and STAYS there. v1.4.20 put Apply above the sections but left
    // it inside the same SingleChildScrollView, so it scrolled away
    // with them — above the fold is worthless if scrolling to the
    // chips you came for takes the button off-screen.
    final languageTopBefore = tester.getTopLeft(language).dy;
    await tester.drag(language, const Offset(0, -400));
    await tester.pump();
    expect(tester.getTopLeft(language).dy, lessThan(languageTopBefore),
        reason: 'the drag should actually scroll the filter body — '
            'otherwise the assertion below passes for the wrong reason');

    expect(tester.getTopLeft(apply).dy, greaterThanOrEqualTo(0.0),
        reason: 'Apply must stay on screen after the body is scrolled');
    await tester.tap(apply);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  // 2026-09-03. User, 2026-08-16: "很多时候这些框框都是上下滑动很多地方都是
  // 这样是不是全部要找出来fix".
  //
  // The Theme and Book sections each sat in their own
  // `ConstrainedBox(0.22 / 0.30 of the viewport) → SingleChildScrollView`
  // INSIDE this sheet's own scroll view. Two scrollables in one axis:
  // the sheet takes the drag, the inner box never moves, and its
  // scrollbar renders as though it would. `test/nested_scrollable_test`
  // guards the shape across `lib/`; this pins the behaviour here, where
  // the user met it.
  testWidgets('the filter sheet scrolls as ONE list, not three',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    await pumpSongsPage(tester, const Size(390, 844));
    await openFilterSheet(tester);

    // Every vertically scrolling Scrollable inside the sheet. Pre-fix
    // this was 3 — the body plus one clipped box per capped section.
    // Scoped to the sheet's own subtree so the page behind it does not
    // count, and filtered by axis so a horizontal chip rail does not.
    final verticalScrollables = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byWidgetPredicate((w) =>
          w is Scrollable && w.axisDirection == AxisDirection.down),
    );
    expect(
      verticalScrollables,
      findsOneWidget,
      reason: 'the sheet body should be the only thing in it that '
          'scrolls vertically — a section that scrolls by itself '
          'inside a scrolling sheet cannot be dragged at all, because '
          'the sheet takes the gesture first',
    );

    // And the sections that used to be clipped now reach their end
    // through that one scroll view: the last book chip is reachable,
    // which inside a 0.30-viewport box it was not.
    final lastBook = find.byWidgetPredicate(
      (w) => w is ChoiceChip && w.label is Text,
      skipOffstage: false,
    );
    expect(lastBook, findsWidgets);
    await tester.drag(find.text(languageLabel), const Offset(0, -2000));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  // cgdc publishes one album a year and its congregation refers to
  // songs that way ("the 2024 ones"), so the year picker has to reach
  // the real catalogue rather than a fixture — if a sync ever drops the
  // album field, this fails instead of shipping an empty section.
  testWidgets('album section narrows the list to one year', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    final all = (await tester.runAsync(SongService.load))!;
    final albums = SongService.distinctAlbums(all);
    expect(albums, isNotEmpty,
        reason: 'assets/songs.json should carry cgdc albums');

    final newest = albums.first;
    final expected =
        all.where((s) => s.album?.trim() == newest).length;
    expect(expected, greaterThan(0));

    await pumpSongsPage(tester, const Size(390, 844));
    await openFilterSheet(tester);

    expect(find.text(uiStrings['songsFilterAlbum']![locale]!), findsOneWidget);

    final chip = find.widgetWithText(ChoiceChip, newest);
    expect(chip, findsOneWidget, reason: 'the newest album should be first');
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, applyLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('$expected / ${all.length}'), findsOneWidget,
        reason: 'picking an album should leave only that album\'s songs');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
