import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/dashboard_page.dart';
import 'package:yswords/providers/main_provider.dart';

/// The dashboard must not offer pull-to-refresh.
///
/// 2026-08-16, from the phone: "往下滑的时候，感觉并没有用，而且那个转转
/// 的也并不自然，你这方面考虑了吗，好好想想". The gesture genuinely did
/// nothing a user could see: `_pullToRefresh` awaited two loads that
/// both re-read a bundled asset through a warm in-memory cache and
/// re-picked the same date-deterministic item (daily verse, today's
/// evidence), while every other block on the page updates reactively
/// on its own (counts and recent bookmarks watch MainProvider; the
/// resume-sermon card re-resolves via service listeners; cloud sync is
/// a realtime subscription with nothing to manually pull). A spinner
/// that always collapses having changed nothing teaches people the
/// app is unresponsive, so the fix was to remove the gesture — these
/// tests pin that removal so a future "add RefreshIndicator back"
/// refactor has to argue with this story first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpDashboard(WidgetTester tester) async {
    // Mark the onboarding tour as seen so its modal doesn't cover the
    // dashboard — the drag below must land on the page's ListView,
    // not on a dialog barrier.
    SharedPreferences.setMockInitialValues(
        <String, Object>{'onboarding.seen.v3': true});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    // Fixed frames instead of pumpAndSettle: the page kicks off async
    // loads (prefs, asset JSON) that would keep pumpAndSettle waiting.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('dashboard body has no RefreshIndicator', (tester) async {
    await pumpDashboard(tester);
    expect(
      find.byType(RefreshIndicator),
      findsNothing,
      reason: 'Pull-to-refresh was removed 2026-08-16 because nothing '
          'on the dashboard can visibly change from a manual refresh; '
          're-adding the indicator re-introduces a spinner that always '
          'appears to do nothing.',
    );
  });

  testWidgets('dragging down does not conjure a refresh spinner',
      (tester) async {
    await pumpDashboard(tester);
    // The exact gesture from the report: 往下滑 (swipe down) from the
    // top of the page. With the indicator gone this must not summon
    // any circular spinner mid-drag or after release.
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    // Let the (nonexistent) refresh settle-out frames run too — the
    // old indicator showed its spinner only after the drag passed the
    // trigger distance and the finger lifted.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
