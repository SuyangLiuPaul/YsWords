// 2026-09-08: the once-a-day update check.
//
// `UpdateService` has been able to answer "is this build stale?" since
// v1.3.88, but only when asked — the one caller is `UpdateCheckTile`,
// a button on the About page. A reader on a sideloaded APK has no store
// telling them anything, so the app's honesty about its own version
// depended on them wandering into About and pressing a button they had
// no reason to suspect existed. This file is the half that asks on
// their behalf. Ported from SeekSparks, which had the same gap and had
// gone nineteen releases behind its own newest tag before anyone
// noticed.
//
// Three rules, and each one is about NOT being annoying:
//
//   1. **Never blocks.** Fired and forgotten; nothing on screen waits
//      for it and a failure is silent. Somebody opened the app to read
//      a verse, not to be shown a spinner about a version number.
//   2. **Once a day, whatever the answer.** The timestamp is stamped
//      even when the check FAILS — a device that is offline every
//      morning would otherwise retry on every launch all day, which is
//      the opposite of what "daily" means.
//   3. **Says nothing when there is nothing to say.** Up to date is
//      silent. The reader hears from this code only when a newer build
//      actually exists.
//
// Not the web. This is deliberately NOT wired into the PWA, which is
// YsWords' primary channel: `WebUpdateChecker` already polls
// `version.json` every 30 minutes, raises `update_banner.dart`, and can
// reload the page itself. A GitHub release has no meaning to a browser
// tab — there is no asset it could install — so running this there
// would be a second mechanism answering a question the first one
// already answers better. `UpdateService.isSupported` returns false on
// web and the gate below inherits that; nothing extra was needed.
library;

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/update_service.dart';

/// Runs the daily check if it is due, and reports a newer release.
///
/// Returns null when the check did not run, could not run, failed, or
/// found nothing — the caller has exactly one thing to do with a
/// non-null result, which is offer it.
///
/// [now], [supported] and [check] are injectable so the whole decision
/// — due / not due / disabled / unsupported — is testable without a
/// clock, a platform or a network.
Future<UpdateInfo?> runDailyUpdateCheck(
  AppSettings settings, {
  DateTime? now,
  bool? supported,
  Future<UpdateInfo?> Function()? check,
}) async {
  // The platform gate is NOT a setting, which is why it is read here
  // rather than folded into `updateCheckDueAt`. On the web the PWA
  // serves the latest build on reload and WebUpdateChecker watches it
  // live, so there is no such thing as an out-of-date web install and
  // nothing to ask GitHub about.
  if (!(supported ?? UpdateService.isSupported)) return null;

  final at = now ?? DateTime.now();
  if (!settings.updateCheckDueAt(at)) return null;

  // Stamped BEFORE the network call, not after. Two launches in quick
  // succession would otherwise both see the check as due and both fire
  // it, and an await is exactly the window for that. It also means a
  // device that cannot reach GitHub burns its one attempt for the day
  // instead of retrying on every cold start — which is the behaviour
  // asked for: "once a day" has to mean once a day even when the
  // answer never arrives.
  await settings.markUpdateChecked(at);

  final info = await (check ?? UpdateService.checkForUpdate)();
  if (info == null || !info.updateAvailable) return null;
  return info;
}
