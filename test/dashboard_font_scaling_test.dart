import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/dashboard_page.dart';
import 'package:yswords/providers/main_provider.dart';

/// The dashboard must scale as ONE page.
///
/// 2026-08-25, from the user: the home layout "其实是不一致的". Part of it
/// was measurable rather than a matter of taste — Featured's title and
/// subtitle were hardcoded at 15 and 12, and the quick-links group labels
/// at 11.5, while every other block derived its sizes from
/// `settings.fontSize`. Dragging the font slider up grew Today's Evidence
/// and left those behind, so the page came apart the further a reader
/// pushed the setting they push precisely because text is too small.
///
/// These tests read the size off the rendered widget, not off the source,
/// so a future refactor that reintroduces a literal fails here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> pumpAt(WidgetTester tester, double fontSize) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'onboarding.seen.v3': true});
    final settings = AppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await settings.setFontSize(fontSize);
    // AppSettings.notifyListeners arms a 600ms debounce before it
    // persists. Pump past it or the test ends holding a pending timer,
    // which fails regardless of what it was asserting.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 100));
    return settings;
  }

  /// The rendered size of the first Text whose data equals [exact].
  double sizeOf(WidgetTester tester, String exact) {
    final w = tester.widget<Text>(find.text(exact).first);
    return w.style!.fontSize!;
  }

  /// Resolve through the SETTINGS locale, not 'en'. The app defaults to
  /// Chinese, so an English lookup finds text that is never rendered.
  String label(AppSettings s, String key, String fallback) =>
      uiStrings[key]?[s.locale] ?? uiStrings[key]?['en'] ?? fallback;

  testWidgets('Featured grows with the font slider, like every other block',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final s1 = await pumpAt(tester, 14.0);
    final songsTitle = label(s1, 'songsPageTitle', 'Songs');
    final small = sizeOf(tester, songsTitle);

    await pumpAt(tester, 26.0);
    final large = sizeOf(tester, songsTitle);

    expect(small, lessThan(large),
        reason: 'the Featured title ignored settings.fontSize — it was a '
            'hardcoded 15 until 2026-08-25');
    // Capped, not unbounded: chrome must not tower over its own icon.
    expect(large, lessThanOrEqualTo(18.0));
  });

  testWidgets('the quick-links group label grows too', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final s1 = await pumpAt(tester, 14.0);
    final groupLabel = label(s1, 'quickLinksFrequent', 'Frequently used');
    final small = sizeOf(tester, groupLabel);

    await pumpAt(tester, 26.0);
    final large = sizeOf(tester, groupLabel);

    expect(small, lessThan(large),
        reason: 'this label was a hardcoded 11.5 — the smallest text on the '
            'page and the one that most needed to respond to the slider');
    expect(large, lessThanOrEqualTo(14.0));
  });

  testWidgets('quick links has a section header, named as Settings names it',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final s = await pumpAt(tester, 20.0);
    // The same uiStrings key the Settings reorder row uses. Sharing the
    // key is the point: Settings listed a block by a name that appeared
    // nowhere on the home page, because quickLinks was the only section
    // without a header of its own.
    expect(
        find.text(label(s, 'dashboardSection_quickLinks_label', 'Quick links')),
        findsOneWidget);
  });
}
