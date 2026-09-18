// 2026-09-14: pulling the home screen down does something.
//
// This gesture was on this page once and was taken off on 2026-08-16,
// with the reader's own words for a reason: 「往下滑的时候，感觉并没有用，
// 而且那个转转的也并不自然」. It was right — every block on the dashboard
// is either live-reactive or a deterministic-by-date pick from a bundled
// asset, so the pull re-read two warm caches and the spinner collapsed
// having changed nothing.
//
// It is back because it now carries the two things this screen genuinely
// cannot do on its own: push the local snapshot to the cloud, and ask
// whether a newer version exists before the reader's chosen interval
// comes round. This file is about the difference — that the work is
// really attached, and that signed out the sync half is absent rather
// than pretended at.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/constants/update_check_frequency.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/services/update_check_scheduler.dart';
import 'package:yahwehs_words/pages/dashboard_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/update_service.dart';

import 'dart:io';

UpdateInfo _info({required bool available}) => UpdateInfo(
      updateAvailable: available,
      currentVersion: '1.5.29',
      latestVersion: available ? '1.5.30' : '1.5.29',
      downloadUrl: 'https://example.invalid/YsWords-Android-1.5.30.apk',
      releaseUrl: 'https://example.invalid/release',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> settings({
    bool auto = true,
    UpdateCheckFrequency every = UpdateCheckFrequency.monthly,
    DateTime? lastChecked,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final s = AppSettings();
    await s.setAutoCheckUpdates(auto);
    await s.setUpdateCheckFrequency(every);
    if (lastChecked != null) await s.markUpdateChecked(lastChecked);
    return s;
  }

  final now = DateTime(2026, 9, 14, 14, 52);

  group('the manual check answers when asked', () {
    test('it ignores the interval — four minutes after the last check is '
        'still an answer', () async {
      // The scheduled path would decline this, and that is the whole
      // difference: a reader who pulled the screen down meant it.
      final s = await settings(
          every: UpdateCheckFrequency.monthly,
          lastChecked: now.subtract(const Duration(minutes: 4)));
      var calls = 0;
      Future<UpdateInfo?> check() async {
        calls++;
        return _info(available: true);
      }

      expect(
          await runScheduledUpdateCheck(s,
              now: now, supported: true, check: check),
          isNull);
      expect(calls, 0, reason: 'the scheduled path should have declined');

      final info =
          await runManualUpdateCheck(s, now: now, supported: true, check: check);
      expect(calls, 1);
      expect(info?.latestVersion, '1.5.30');
    });

    test('it ignores the switch, because the switch is about the app '
        'asking on its own', () async {
      // 「自动检查更新」 off means no unprompted request. It does not mean
      // refusing to answer a reader who pulled the screen down.
      final s = await settings(auto: false, lastChecked: DateTime(2020));
      var calls = 0;
      final info = await runManualUpdateCheck(s, now: now, supported: true,
          check: () async {
        calls++;
        return _info(available: true);
      });
      expect(calls, 1);
      expect(info?.latestVersion, '1.5.30');
    });

    test('it still spends the period, so the automatic check does not ask '
        'again an hour later', () async {
      final s = await settings(every: UpdateCheckFrequency.daily);
      await runManualUpdateCheck(s, now: now, supported: true,
          check: () async => _info(available: true));
      expect(s.lastUpdateCheck, now);
      expect(s.updateCheckDueAt(now.add(const Duration(hours: 1))), isFalse);
    });

    test('an unsupported platform is still not asked', () async {
      // There is no out-of-date web install — the tab reloads onto the
      // newest build — so there is nothing to ask GitHub. The web half of
      // the pull is `WebUpdateChecker.checkNow`, not this.
      var calls = 0;
      final info = await runManualUpdateCheck(await settings(),
          now: now,
          supported: false, check: () async {
        calls++;
        return _info(available: true);
      });
      expect(calls, 0);
      expect(info, isNull);
    });

    test('being up to date still says nothing', () async {
      expect(
          await runManualUpdateCheck(await settings(),
              now: now,
              supported: true,
              check: () async => _info(available: false)),
          isNull);
    });
  });

  group('the wiring, which is the half these functions cannot assert', () {
    final source = File('lib/pages/dashboard_page.dart').readAsStringSync();

    test('the dashboard mounts a RefreshIndicator around its list', () {
      expect(source.contains('RefreshIndicator('), isTrue);
      expect(source.contains('onRefresh: _pullToRefresh'), isTrue);
      // Without this the pull does nothing on any screen tall enough to
      // hold the whole page, which on a tablet is every screen.
      expect(source.contains('AlwaysScrollableScrollPhysics'), isTrue);
    });

    test('the pull carries all three pieces of work', () {
      expect(source.contains('CloudSyncService.instance.syncNow()'), isTrue,
          reason: 'the sync half');
      expect(source.contains('WebUpdateChecker.instance.checkNow()'), isTrue,
          reason: 'the web-build half');
      expect(source.contains('runManualUpdateCheck('), isTrue,
          reason: 'the release half');
    });

    test('signed out, the sync half is absent rather than attempted', () {
      // 「如果没有登陆就没sync功能」. Guarded at the call rather than inside
      // `syncNow`, which would return false and set an error status — a
      // spinner that waits on a call known to fail is the August
      // complaint with extra steps.
      expect(source.contains('if (CloudAuthService.instance.isSignedIn)'),
          isTrue);
    });
  });

  // Ported from `dashboard_pull_refresh_removed_test.dart`, which pinned
  // the OPPOSITE claim and said so in as many words: "these tests pin
  // that removal so a future 'add RefreshIndicator back' refactor has to
  // argue with this story first." This is the argument, and it is the
  // one that story asked for — the gesture is back because it now
  // carries work the page cannot otherwise do, which is exactly what the
  // 2026-08-16 note said it lacked. Same owner, same screen, opposite
  // request; the file it replaces is gone rather than edited, because
  // its NAME asserts the claim that stopped being true.
  group('the gesture is on the page', () {
    Future<void> pumpDashboard(WidgetTester tester) async {
      // Onboarding marked seen so its modal does not cover the page —
      // the drag has to land on the ListView, not on a dialog barrier.
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
      // loads whose spinners would keep pumpAndSettle waiting forever.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the dashboard body has a RefreshIndicator', (tester) async {
      await pumpDashboard(tester);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('往下滑 summons the spinner, which is the whole point',
        (tester) async {
      // The exact gesture from both reports — the one that asked for it
      // to go, and the one that asked for it back.
      await pumpDashboard(tester);
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RefreshProgressIndicator), findsOneWidget,
          reason: 'the pull did not reach the trigger distance, so this '
              'file is not testing the gesture it names');
      // Let the refresh finish so no timer outlives the test.
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });
  });
}
