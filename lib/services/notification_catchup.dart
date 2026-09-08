// 2026-09-08: make the reminder settings mean something on the web.
//
// The bug this fixes, stated plainly: yahwehword.com is YsWords' primary
// channel, the Settings page lets a reader switch on a daily verse at
// 07:00 with a weekday mask, and `notification_scheduler.dart` opens with
// `if (kIsWeb) return;`. So on the channel most people actually use, the
// reminder was a switch wired to nothing. A promise that silently never
// fires is worse than no promise.
//
// WHY CATCH-UP-ON-OPEN, AND WHAT WAS REJECTED
//
// A web page cannot wake itself. That is not a gap in this app, it is
// the platform, and the three ways around it were weighed:
//
//  • Web Push from a service worker. This is the only mechanism that can
//    deliver at 07:00 to a reader who is not looking. It needs a push
//    server holding VAPID keys and a subscription store — a backend.
//    YsWords is deliberately backend-light (its one server-side surface
//    is Firebase auth/RTDB for sync), and a reminder feature is not
//    worth acquiring a push service, its key rotation and its
//    per-subscription lifecycle. Rejected on cost, not on merit: it is
//    the only *correct* answer, and if a push backend ever exists for
//    another reason, this file should be replaced by it.
//
//  • `periodicSync` from the existing worker. `web/app_shell_sw.js` is a
//    real, registered, network-first worker, so there IS somewhere to put
//    a handler — but `navigator.periodicSync` is Chromium-only, is
//    granted only to INSTALLED apps that have accumulated site
//    engagement, has no guaranteed minimum interval, and is absent
//    entirely from every iOS browser (all of which are WebKit). It would
//    fire for some fraction of Chrome-on-Android installs and for nobody
//    else, which is the worst outcome available: a feature that works
//    just often enough that its failures look like bugs.
//
//  • Say the web cannot do it and hide the scheduling UI. Honest, and it
//    was the fallback if catch-up proved unworkable. It also throws away
//    the 3,650 bundled daily verses on the platform that has them.
//
// So: when the reader opens (or returns to) the app, any category that
// was due earlier today and has not already been shown today is
// delivered right then. That is what most PWAs in this position actually
// do, it needs no backend, it works offline, and it is truthful — the
// Settings page says so in one line, rather than letting the reader
// infer a 07:00 banner that will never arrive.
//
// THE "NOT ALREADY SHOWN TODAY" LEDGER
//
// One local, per-profile SharedPreferences key holds `{categoryId:
// "yyyy-mm-dd"}`. Deliberately NOT in `RealtimeDbSyncService`'s key
// lists: this records what one browser on one device put on screen, and
// syncing it would mean a phone's delivery suppressed the laptop's.
// Reading position syncs; "did this screen already show a banner" does
// not.
//
// A time-since-last-visit window was considered instead of a per-day
// ledger and rejected — it needs a second stored timestamp that drifts
// out of step with the ledger it is meant to complement, and answers a
// question ("was it due while you were away") that the simpler
// "was it due today, has it shown today" already answers correctly for
// every case that matters.
//
// A staleness cap ("don't bother showing the 07:00 verse at 23:40") was
// also considered and rejected. The reader asked for a daily verse and
// has not seen today's; a cap would silently swallow the day on exactly
// the days they were busiest, and no wording in Settings could explain
// where it went. The same-local-day rule is the whole bound.
//
// ARMING, so opting in does not detonate
//
// Without care, a reader switching everything on at 20:00 would be met
// by three banners at once — the 07:00, 12:00 and 19:00 categories are
// all "due today and never shown". [armToday] stamps today onto every
// category whose time has already passed at the moment the reader
// changes the settings, so a switch flipped this evening starts
// delivering tomorrow morning. `AppSettings` calls it on every
// notification-preference write.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/notification_category.dart';
import 'package:yswords/services/notification_content.dart';
import 'package:yswords/services/notification_service.dart';
import 'package:yswords/services/profile_service.dart';

class NotificationCatchup with WidgetsBindingObserver {
  NotificationCatchup._();
  static final NotificationCatchup instance = NotificationCatchup._();

  /// Base (pre-profile-scoping) key of the ledger. See the header: local
  /// only, never added to `RealtimeDbSyncService`.
  static const String ledgerBaseKey = 'notificationCatchupShown';

  /// How often a tab that stays open re-checks. A reader who leaves
  /// yahwehword.com open all day is the one case where catch-up can be
  /// nearly punctual, and the check is pure arithmetic over five map
  /// entries, so it costs effectively nothing to be within five minutes
  /// rather than "whenever they next click the tab".
  static const Duration pollInterval = Duration(minutes: 5);

  /// Test seam: lets the VM-side tests exercise the whole service
  /// without `kIsWeb`. Never set outside tests.
  @visibleForTesting
  static bool debugPretendWeb = false;

  /// Test seam for the clock. Never set outside tests.
  @visibleForTesting
  static DateTime Function() nowFn = DateTime.now;

  /// Native platforms have `flutter_local_notifications` and a real OS
  /// scheduler, which delivers whether the app is running or not. This
  /// service exists only for the platform that has neither.
  static bool get isSupported => kIsWeb || debugPretendWeb;

  Timer? _poll;
  bool _started = false;
  bool _running = false;

  /// Begin watching. Idempotent; safe to call on every boot.
  void start(AppSettings settings) {
    if (!isSupported || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(pollInterval, (_) => unawaited(runNow(settings)));
    unawaited(runNow(settings));
  }

  @visibleForTesting
  void stop() {
    _poll?.cancel();
    _poll = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _running = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Returning to the tab is the moment the reader is most likely to
    // have missed something, and the only moment a catch-up banner is
    // about to be looked at rather than dismissed unseen.
    final settings = _settings;
    if (settings != null) unawaited(runNow(settings));
  }

  AppSettings? _settings;

  /// Deliver every category that is due today and has not been shown
  /// today. Returns the ids delivered, for tests and for logging.
  ///
  /// Never throws. A browser that revoked permission between the check
  /// and the call, a missing asset, a corrupt ledger — none of those are
  /// worth surfacing to a reader who asked for a verse.
  Future<List<String>> runNow(AppSettings settings) async {
    _settings = settings;
    if (!isSupported || _running) return const [];
    if (!settings.notificationsEnabled) return const [];
    if (NotificationService.permission != NotificationPermission.granted) {
      return const [];
    }
    _running = true;
    try {
      final now = nowFn();
      final prefs = await SharedPreferences.getInstance();
      final ledger = _readLedger(prefs);
      final due = dueCategories(
        notificationsEnabled: settings.notificationsEnabled,
        prefsFor: settings.notificationCategory,
        now: now,
        shownOn: ledger,
      );
      if (due.isEmpty) return const [];
      final today = dayKey(now);
      final delivered = <String>[];
      for (final id in due) {
        try {
          final content =
              await resolveNotificationContent(id, now, settings.locale);
          await NotificationService.show(
            title: content.title,
            body: content.body.isEmpty ? null : content.body,
            // One tag per category so a second delivery REPLACES the
            // first rather than stacking. A reader who left the tab open
            // over midnight should see one daily verse, not a pile.
            tag: 'yswords-reminder-$id',
          );
          ledger[id] = today;
          delivered.add(id);
        } catch (e) {
          debugPrint('[catchup] $id failed: $e');
        }
      }
      if (delivered.isNotEmpty) await _writeLedger(prefs, ledger);
      return delivered;
    } catch (e) {
      debugPrint('[catchup] run failed: $e');
      return const [];
    } finally {
      _running = false;
    }
  }

  /// Mark every category whose time has already passed today as already
  /// delivered, without delivering anything.
  ///
  /// Called whenever the reader changes a notification preference, so
  /// switching on a 07:00 verse at 20:00 starts tomorrow instead of
  /// firing immediately. Categories still ahead of the clock are left
  /// alone, so a 22:00 reminder set at 20:00 still arrives tonight.
  Future<void> armToday(AppSettings settings) async {
    if (!isSupported) return;
    try {
      final now = nowFn();
      final prefs = await SharedPreferences.getInstance();
      final ledger = _readLedger(prefs);
      final today = dayKey(now);
      var changed = false;
      for (final id in NotificationCategoryIds.phase1) {
        final p = settings.notificationCategory(id);
        if (_minuteOfDay(p.hour, p.minute) > _minuteOfDay(now.hour, now.minute)) {
          continue;
        }
        if (ledger[id] == today) continue;
        ledger[id] = today;
        changed = true;
      }
      if (changed) await _writeLedger(prefs, ledger);
    } catch (e) {
      debugPrint('[catchup] arm failed: $e');
    }
  }

  /// Forget the ledger for the active profile. Used by the settings
  /// reset path so a wiped install does not inherit "already shown".
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ProfileService.instance.scopedKey(ledgerBaseKey));
    } catch (_) {/* nothing to lose */}
  }

  // ---- pure decision logic -------------------------------------------

  /// The local calendar day, as the ledger stores it. Local, not UTC:
  /// "today's verse" is the reader's today.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static int _minuteOfDay(int hour, int minute) => hour * 60 + minute;

  /// Which categories should be delivered at [now], earliest scheduled
  /// time first.
  ///
  /// A category qualifies when the master switch is on, the category is
  /// on, [now] falls on one of its weekdays, its time of day has already
  /// passed, and [shownOn] does not already name today for it.
  ///
  /// Ordered by scheduled time so a reader opening the app in the
  /// evening sees the morning verse announced before the evening sermon,
  /// which is the order they would have arrived in.
  @visibleForTesting
  static List<String> dueCategories({
    required bool notificationsEnabled,
    required NotificationCategoryPrefs Function(String categoryId) prefsFor,
    required DateTime now,
    required Map<String, String> shownOn,
  }) {
    if (!notificationsEnabled) return const [];
    final today = dayKey(now);
    final nowMinutes = _minuteOfDay(now.hour, now.minute);
    final hits = <({String id, int at})>[];
    for (final id in NotificationCategoryIds.phase1) {
      final p = prefsFor(id);
      if (!p.enabled) continue;
      if (!p.weekdays.contains(now.weekday)) continue;
      final at = _minuteOfDay(p.hour, p.minute);
      if (at > nowMinutes) continue;
      if (shownOn[id] == today) continue;
      hits.add((id: id, at: at));
    }
    hits.sort((a, b) => a.at.compareTo(b.at));
    return [for (final h in hits) h.id];
  }

  // ---- ledger persistence --------------------------------------------

  Map<String, String> _readLedger(SharedPreferences prefs) {
    final raw =
        prefs.getString(ProfileService.instance.scopedKey(ledgerBaseKey));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is String) e.key.toString(): e.value as String,
      };
    } catch (_) {
      // Corrupt ledger reads as empty, which at worst re-delivers one
      // day's reminders. Refusing to run would lose them forever.
      return {};
    }
  }

  Future<void> _writeLedger(
      SharedPreferences prefs, Map<String, String> ledger) async {
    // Keep only the phase-1 ids so the blob cannot grow from a category
    // that was renamed or retired.
    final trimmed = {
      for (final id in NotificationCategoryIds.phase1)
        if (ledger[id] != null) id: ledger[id]!,
    };
    await prefs.setString(
        ProfileService.instance.scopedKey(ledgerBaseKey), jsonEncode(trimmed));
  }
}
