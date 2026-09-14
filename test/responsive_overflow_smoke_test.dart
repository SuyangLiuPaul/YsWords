import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/pages/about_page.dart';
import 'package:yswords/pages/dashboard_page.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/library_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';

/// 2026-06-11 audit: responsive overflow smoke tests.
///
/// Pumps real pages at the four widths that bracket the supported
/// devices — iPhone SE (320), iPhone 14/15 (390), iPad portrait (768)
/// and desktop (1280) — and asserts the layout pass throws nothing.
/// RenderFlex overflows surface as test exceptions, so any future
/// "RIGHT OVERFLOWED BY N PIXELS" regression on these pages fails CI
/// instead of shipping.
///
/// Pages covered: About, Settings, Library, Dashboard — and, since
/// 2026-09-14, Home, which is the screen the app opens on and was the one
/// page excluded here. The note this replaces said "the reading pane
/// needs loaded bible data and is covered by the on-device flows"; the
/// first half is true and the second was a hope. Seeding two verses into
/// the provider lays the whole reading surface out, which is all the four
/// widths below need.
///
/// The sibling change in the Sword repo found a real defect the moment
/// its main screen joined this list — an 18px overflow in the toolbar at
/// 320px, clipping a command with nothing on screen to say so. That is
/// the argument for this one: the page a reader spends every minute on
/// was the page no width test covered.
///
/// Each page is pumped with fresh providers and empty SharedPreferences
/// (the cold-install state, which is also the state most likely to show
/// placeholder/empty layouts that overflow).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = <String, Size>{
    'iPhone SE 320x568': Size(320, 568),
    'iPhone 390x844': Size(390, 844),
    'iPad portrait 768x1024': Size(768, 1024),
    'desktop 1280x800': Size(1280, 800),
  };

  final pages = <String, Widget Function()>{
    'AboutPage': () => const AboutPage(),
    'SettingsPage': () => const SettingsPage(),
    'LibraryPage': () => const LibraryPage(),
    'DashboardPage': () => const DashboardPage(),
    'HomePage': () => const HomePage(),
  };

  /// Enough scripture for the reading surface to have something to lay
  /// out. An empty provider would render placeholders and pass for the
  /// wrong reason.
  const seed = [
    Verse(book: '约翰福音', chapter: 3, verse: 1, text: 'seed 1'),
    Verse(book: '约翰福音', chapter: 3, verse: 2, text: 'seed 2'),
  ];

  Future<void> pumpAt(
    WidgetTester tester,
    Widget page,
    Size logicalSize, {
    double menuScale = 1.0,
    double fontSize = 20.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = logicalSize;
    final settings = AppSettings();
    await settings.setMenuScale(menuScale);
    await settings.setFontSize(fontSize);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()
            // All four of these are needed and the reason is worth
            // recording, because three of them look redundant: the pane
            // pages through CHAPTERS, so it needs `books` to know which
            // page the reader is on, and it filters the verse list by
            // book and chapter to fill that page. Seed only `verses` and
            // the header renders, the "1 / 2" counter renders, and not
            // one verse does — a page that passes a "nothing threw"
            // test while laying out almost nothing. The guard at the
            // foot of this file is what caught that, and is why it
            // exists.
            ..currentBook = '约翰福音'
            ..currentChapter = 3
            ..setBooks([
              Book(title: '约翰福音',
                  chapters: [Chapter(title: 3, verses: seed)]),
            ])
            ..setVerses(seed)),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(home: page),
      ),
    );
    // A handful of fixed frames instead of pumpAndSettle: pages kick
    // off async loads (prefs, asset JSON) whose spinners would keep
    // pumpAndSettle waiting forever.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // 2026-09-14: the second axis, and the one that was missing.
  //
  // Every case here ran at menu scale 1.0, and the Menu Size slider goes
  // to 1.5. At the top of it, on a 320px screen, the reading page's
  // bottom bar — six fixed-size icon buttons in a plain `Row` —
  // overflowed by 64 pixels: the striped band a reader reads as the app
  // being broken. It had presumably been there since the sixth button
  // was added, and this file laid that very page out at that very width
  // without seeing it, because it only ever asked at 1.0x.
  //
  // A reader who needs a larger interface is disproportionately likely
  // to be holding a small phone, so the two ends of the grid that look
  // least likely are the pair most worth testing together.
  // Paired rather than crossed, and both numbers matter: the chrome
  // takes its icon size from `fontSize.clamp(16, 28) * menuScale`, so
  // the clamp is only saturated at the top of the FONT slider and the
  // overflow above needed both sliders up. 1.0x/20pt is what the app
  // ships as; 1.5x/40pt is both sliders at their maximum, which is the
  // only corner where the chrome is as large as it can get. The two
  // mixed combinations sit between them.
  const configs = <String, (double, double)>{
    'default 1.0x / 20pt': (1.0, 20.0),
    'largest 1.5x / 40pt': (1.5, 40.0),
  };

  for (final pageEntry in pages.entries) {
    for (final sizeEntry in sizes.entries) {
      for (final config in configs.entries) {
        final (menuScale, fontSize) = config.value;
        testWidgets('${pageEntry.key} lays out at ${sizeEntry.key} '
            'at ${config.key} without overflow', (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          addTearDown(tester.view.reset);

          await pumpAt(tester, pageEntry.value(), sizeEntry.value,
              menuScale: menuScale, fontSize: fontSize);
          expect(
            tester.takeException(),
            isNull,
            reason: '${pageEntry.key} threw during layout at '
                '${sizeEntry.key} at ${config.key}',
          );

          // Dispose the page so timers/listeners registered in initState
          // are cancelled before the test ends (pending-timer guard).
          // The 700ms drains `AppSettings`' own notify debounce, which
          // `setMenuScale` starts and the widget tree outlives.
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 700));
        });
      }
    }
  }

  testWidgets('HomePage really lays the verses out — the width tests above '
      'are not measuring an empty page', (tester) async {
    // Every assertion above is "nothing threw", which a page that
    // rendered nothing also satisfies. HomePage is the one that could:
    // it shows a loading state until verses arrive, and if the seed
    // never reached the pane the four widths would be measuring a
    // spinner. This is what says they are not.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    await pumpAt(tester, const HomePage(), const Size(320, 568));

    // Walked by hand rather than through `find.textContaining`, which
    // matches a `Text`'s own string and does not see a verse: the pane
    // builds each one as `InlineSpan`s inside a `RichText`, so the words
    // on screen live in `text.toPlainText()` and nowhere else.
    final onScreen = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .where((t) => t.contains('seed'))
        .length;
    expect(onScreen, greaterThan(0),
        reason: 'the seeded verses are not on screen, so the overflow '
            'tests above are laying out a page with a header and no '
            'scripture');

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700));
  });
}
