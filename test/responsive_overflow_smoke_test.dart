import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/about_page.dart';
import 'package:yswords/pages/dashboard_page.dart';
import 'package:yswords/pages/library_page.dart';
import 'package:yswords/pages/settings_page.dart';
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
/// Pages covered: About, Settings, Library, Dashboard. The reading
/// pane needs loaded bible data and is covered by the on-device
/// flows. Each page is pumped with fresh providers and empty
/// SharedPreferences (the cold-install state, which is also the state
/// most likely to show placeholder/empty layouts that overflow).
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
  };

  Future<void> pumpAt(
    WidgetTester tester,
    Widget page,
    Size logicalSize,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = logicalSize;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
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

  for (final pageEntry in pages.entries) {
    for (final sizeEntry in sizes.entries) {
      testWidgets('${pageEntry.key} lays out at ${sizeEntry.key} '
          'without overflow', (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        addTearDown(tester.view.reset);

        await pumpAt(tester, pageEntry.value(), sizeEntry.value);
        expect(
          tester.takeException(),
          isNull,
          reason: '${pageEntry.key} threw during layout at '
              '${sizeEntry.key}',
        );

        // Dispose the page so timers/listeners registered in initState
        // are cancelled before the test ends (pending-timer guard).
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      });
    }
  }
}
