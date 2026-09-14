// 2026-09-08: the daily update check does its job and stays quiet.
//
// The feature's whole risk is being a nuisance. A check that fires on
// every launch, or blocks the first frame, or announces "you are up to
// date" to someone who did not ask, is worse than no check — the reader
// turns it off and then never hears about the release that matters.
//
// So the rules are asserted rather than described. Every one of these
// was a way this could have gone wrong, and the two YsWords-specific
// ones — the web gate and the per-device timestamp — are the two places
// this differs from the SeekSparks original it was ported from.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/update_check_frequency.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/update_check_scheduler.dart';
import 'package:yswords/services/update_service.dart';
import 'package:yswords/widgets/update_check_tile.dart';

UpdateInfo _info({required bool available}) => UpdateInfo(
      updateAvailable: available,
      currentVersion: '1.5.15',
      latestVersion: available ? '1.5.16' : '1.5.15',
      downloadUrl: 'https://example.invalid/YsWords-Android-1.5.16.apk',
      releaseUrl: 'https://example.invalid/release',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> settings({
    bool auto = true,
    DateTime? lastChecked,
    UpdateCheckFrequency? every,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final s = AppSettings();
    await s.setAutoCheckUpdates(auto);
    if (every != null) await s.setUpdateCheckFrequency(every);
    if (lastChecked != null) await s.markUpdateChecked(lastChecked);
    return s;
  }

  final now = DateTime(2026, 9, 8, 9, 0);

  group('when the check runs', () {
    test('a day after the last check it runs and reports the newer build',
        () async {
      var calls = 0;
      final info = await runScheduledUpdateCheck(
        await settings(lastChecked: now.subtract(const Duration(days: 1))),
        now: now,
        supported: true,
        check: () async {
          calls++;
          return _info(available: true);
        },
      );
      expect(calls, 1);
      expect(info?.latestVersion, '1.5.16');
    });

    test('an hour after the last check it does not touch the network',
        () async {
      var calls = 0;
      final info = await runScheduledUpdateCheck(
        await settings(lastChecked: now.subtract(const Duration(hours: 1))),
        now: now,
        supported: true,
        check: () async {
          calls++;
          return _info(available: true);
        },
      );
      expect(calls, 0, reason: 'not due — the request must not be made');
      expect(info, isNull);
    });

    test('a reader who has never checked is due on their first launch',
        () async {
      var calls = 0;
      await runScheduledUpdateCheck(
        await settings(),
        now: now,
        supported: true,
        check: () async {
          calls++;
          return _info(available: false);
        },
      );
      expect(calls, 1,
          reason: 'epoch 0 is "never", which is further back than a day');
    });

    test('an up-to-date answer is reported as nothing to say', () async {
      final info = await runScheduledUpdateCheck(
        await settings(),
        now: now,
        supported: true,
        check: () async => _info(available: false),
      );
      expect(info, isNull,
          reason: 'the caller offers whatever it gets back, so "you are '
              'already current" must not come back as a result');
    });

    test('the switch turned off stops the check without spending the day',
        () async {
      var calls = 0;
      final s = await settings(auto: false);
      await runScheduledUpdateCheck(s, now: now, supported: true, check: () async {
        calls++;
        return _info(available: true);
      });
      expect(calls, 0);
      expect(s.lastUpdateCheck.millisecondsSinceEpoch, 0,
          reason: 'a check that never ran must not be recorded as having '
              'run, or switching the setting back on would wait a day');
    });
  });

  group('the mark-before-call ordering', () {
    test('the timestamp is already stamped by the time the request is made',
        () async {
      // The ordering itself, observed from inside the network call: if
      // the stamp came after, a second launch arriving during this await
      // would still read the check as due and fire a second request.
      final s = await settings();
      late bool dueDuringCall;
      await runScheduledUpdateCheck(
        s,
        now: now,
        supported: true,
        check: () async {
          dueDuringCall = s.updateCheckDueAt(now);
          return _info(available: true);
        },
      );
      expect(dueDuringCall, isFalse);
      expect(s.lastUpdateCheck, now);
    });

    test('two launches racing each other produce exactly one request',
        () async {
      var calls = 0;
      final s = await settings();
      Future<UpdateInfo?> slowCheck() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _info(available: true);
      }

      await Future.wait([
        runScheduledUpdateCheck(s, now: now, supported: true, check: slowCheck),
        runScheduledUpdateCheck(s, now: now, supported: true, check: slowCheck),
      ]);
      expect(calls, 1);
    });

    test('a failed check still spends the day, and spends it only once',
        () async {
      // The offline-every-morning case. The first call fails; the day is
      // spent anyway. The second call — a minute later, a relaunch — must
      // find itself not due, so the failure is neither retried nor
      // re-stamped with the later time.
      var calls = 0;
      final s = await settings();
      Future<UpdateInfo?> failing() async {
        calls++;
        return null; // UpdateService swallows its own errors and returns null.
      }

      final first =
          await runScheduledUpdateCheck(s, now: now, supported: true, check: failing);
      final later = now.add(const Duration(minutes: 1));
      final second = await runScheduledUpdateCheck(s,
          now: later, supported: true, check: failing);

      expect(first, isNull);
      expect(second, isNull);
      expect(calls, 1, reason: 'the second launch must not retry');
      expect(s.lastUpdateCheck, now,
          reason: 'stamped once, at the moment the check was attempted — '
              're-stamping at $later would push the next check a full day '
              'past a relaunch the reader did not ask to cost them');
    });
  });

  group('the platform gate', () {
    test('an unsupported platform asks nothing and spends nothing', () async {
      // This is the web/PWA case, which is YsWords' primary channel.
      // WebUpdateChecker already polls version.json and can reload the
      // page; a GitHub release has no meaning to a browser tab. Note
      // that the day is NOT spent either — the gate is checked before
      // the stamp, so a desktop build sharing prefs with nothing still
      // gets its own first check.
      var calls = 0;
      final s = await settings();
      final info = await runScheduledUpdateCheck(s,
          now: now,
          supported: false,
          check: () async {
            calls++;
            return _info(available: true);
          });
      expect(info, isNull);
      expect(calls, 0);
      expect(s.lastUpdateCheck.millisecondsSinceEpoch, 0);
    });

    test('UpdateService still refuses to answer on the web', () {
      // The gate above is only honest if the thing it defaults to is.
      // `isSupported` is what `runScheduledUpdateCheck` reads when no
      // override is passed, and the web arm of it is the whole reason
      // the daily check is not duplicated on top of WebUpdateChecker.
      expect(UpdateService.isSupported, isTrue,
          reason: 'the VM test host is a native platform; this asserts '
              'the gate is real rather than always-false');
      // The kIsWeb arm cannot be exercised from the VM, so the web
      // decision is pinned by the source instead: nothing may make the
      // daily scheduler reachable on the web without editing this line
      // and arguing with the comment above it.
      final source = File('lib/services/update_service.dart').readAsStringSync();
      expect(source.contains('if (kIsWeb) return false;'), isTrue,
          reason: 'UpdateService.isSupported must keep refusing on the '
              'web — WebUpdateChecker owns that question, and two '
              'mechanisms answering it is the duplication this port set '
              'out to avoid');
    });
  });

  group('the settings toggle', () {
    testWidgets('defaults to on, and the reader can turn it off for good',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final s = AppSettings();
      await s.loadSettings();
      expect(s.autoCheckUpdates, isTrue,
          reason: 'one request a day on a build with no store behind it '
              'is worth making by default');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettings>.value(
          value: s,
          child: const MaterialApp(
            home: Scaffold(body: AutoUpdateCheckToggle(locale: 'en')),
          ),
        ),
      );
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(s.autoCheckUpdates, isFalse);

      // Persistence: a fresh load of the same prefs must still be off.
      final reloaded = AppSettings();
      await reloaded.loadSettings();
      expect(reloaded.autoCheckUpdates, isFalse);
      expect(reloaded.updateCheckDueAt(now), isFalse);

      // AppSettings.notifyListeners schedules a 600 ms debounce for the
      // userPrefs sync blob. Drain it, or the binding fails the test on
      // a pending timer — and the drain is worth having anyway: it
      // proves the toggle does not leave a sync write queued behind it.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('per-device, not per-profile', () {
    test('switching profiles does not restart the daily cadence', () async {
      // The decision this pins: the thing being checked is one installed
      // binary on one machine, so the record of having checked it is not
      // the property of whichever reader is signed in. A household on a
      // shared tablet would otherwise ask GitHub once per person.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProfileService.instance.init();
      final first = AppSettings();
      await first.setAutoCheckUpdates(true);
      await first.markUpdateChecked(now);

      final other = await ProfileService.instance.create('Second reader');
      await ProfileService.instance.setCurrent(other.id);

      final second = AppSettings();
      await second.loadSettings();
      expect(second.lastUpdateCheck, now);
      expect(second.updateCheckDueAt(now.add(const Duration(hours: 2))),
          isFalse);
    });

    test('the two keys are stored unscoped, so nothing syncs them',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final s = AppSettings();
      await s.setAutoCheckUpdates(false);
      await s.markUpdateChecked(now);
      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys, contains('autoCheckUpdates'));
      expect(keys, contains('lastUpdateCheckMs'));
      expect(keys.where((k) => k.startsWith('profile.')), isEmpty,
          reason: 'a `profile.<id>.` prefix is what the RTDB sync layer '
              'walks; keeping these out of it is what stops a phone check '
              "from silencing a desktop's for the day");
    });
  });

  // 2026-09-14: the gap was a compiled `Duration(days: 1)` and is now the
  // reader's choice. These are about what the four choices mean, and about
  // the one that has no gap at all.
  group("the interval is the reader's", () {
    final anHourAgo = now.subtract(const Duration(hours: 1));

    Future<int> callsAt(UpdateCheckFrequency every, DateTime last) async {
      var calls = 0;
      await runScheduledUpdateCheck(
        await settings(every: every, lastChecked: last),
        now: now,
        supported: true,
        check: () async {
          calls++;
          return _info(available: true);
        },
      );
      return calls;
    }

    test('every launch means every launch, an hour later included',
        () async {
      expect(await callsAt(UpdateCheckFrequency.everyLaunch, anHourAgo), 1);
    });

    test('daily, weekly and monthly all decline an hour later', () async {
      for (final every in const [
        UpdateCheckFrequency.daily,
        UpdateCheckFrequency.weekly,
        UpdateCheckFrequency.monthly,
      ]) {
        expect(await callsAt(every, anHourAgo), 0, reason: every.prefValue);
      }
    });

    test('each one fires once its own gap has passed, and not before',
        () async {
      // The whole table rather than one example: a wrong `gap` on any
      // value shows up here as the adjacent row's answer.
      for (final every in UpdateCheckFrequency.values) {
        final gap = every.gap;
        if (gap > Duration.zero) {
          expect(
              await callsAt(
                  every, now.subtract(gap - const Duration(minutes: 1))),
              0,
              reason: '${every.prefValue} fired a minute early');
        }
        expect(await callsAt(every, now.subtract(gap)), 1,
            reason: '${every.prefValue} did not fire on its own gap');
      }
    });

    test('a weekly reader is not asked daily, which is the whole point',
        () async {
      final s = await settings(every: UpdateCheckFrequency.weekly);
      var calls = 0;
      Future<UpdateInfo?> check() async {
        calls++;
        return _info(available: true);
      }

      await runScheduledUpdateCheck(s,
          now: now, supported: true, check: check);
      expect(calls, 1, reason: 'never checked is longer ago than any gap');
      for (var day = 1; day < 7; day++) {
        await runScheduledUpdateCheck(s,
            now: now.add(Duration(days: day)), supported: true, check: check);
      }
      expect(calls, 1,
          reason: 'six more launches inside the week asked again');
      await runScheduledUpdateCheck(s,
          now: now.add(const Duration(days: 7)),
          supported: true,
          check: check);
      expect(calls, 2);
    });

    test('the switch still wins over any interval', () async {
      expect(await callsAt(UpdateCheckFrequency.everyLaunch, DateTime(2020)),
          1);
      var calls = 0;
      await runScheduledUpdateCheck(
        await settings(
            auto: false,
            every: UpdateCheckFrequency.everyLaunch,
            lastChecked: DateTime(2020)),
        now: now,
        supported: true,
        check: () async {
          calls++;
          return _info(available: true);
        },
      );
      expect(calls, 0,
          reason: 'off means no request, whatever the frequency says');
    });

    test('the choice survives a reload, and an unknown value reads as '
        'daily', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final a = AppSettings();
      await a.setUpdateCheckFrequency(UpdateCheckFrequency.monthly);

      final b = AppSettings();
      await b.loadSettings();
      expect(b.updateCheckFrequency, UpdateCheckFrequency.monthly);

      // A value from a newer build, or a key left over from a rename.
      // Defaulting to the documented default is the only answer that
      // cannot surprise anybody.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'updateCheckFrequency': 'fortnightly',
      });
      final c = AppSettings();
      await c.loadSettings();
      expect(c.updateCheckFrequency, UpdateCheckFrequency.daily);
    });

    test('the default is daily, and nothing has to be stored to get it',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final s = AppSettings();
      expect(s.updateCheckFrequency, UpdateCheckFrequency.daily);
      expect(s.autoCheckUpdates, isTrue);
    });
  });
}
