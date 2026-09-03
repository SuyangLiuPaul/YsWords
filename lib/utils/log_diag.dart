import 'package:flutter/foundation.dart';

/// Diagnostic logging that survives a release web build.
///
/// **Why this exists.** `debugPrint` emits NOTHING from a release web
/// build. Measured 2026-09-02 with a single-build control: two adjacent
/// statements in `BibleReadingPane`'s builder, one `print` and one
/// `debugPrint`, same frame, same bundle — only the `print` reached the
/// browser console.
///
/// **The mechanism, found 2026-09-03.** This is not a web-platform
/// quirk and nothing is being tree-shaken. `lib/main.dart` opens with
///
///     if (kReleaseMode) {
///       debugPrint = (String? message, {int? wrapWidth}) {};
///     }
///
/// — an intentional 2026-06-11 info-disclosure fix, since `debugPrint`
/// is NOT stripped from release builds and ~100 sync/auth call sites
/// were landing in the browser console of the deployed site. The
/// override is unconditional on platform, so the forensic chains are
/// mute in a release build on *every* target; the web is merely where
/// it was noticed, because the web is where the console is user-visible
/// and where this app's bug reports come from.
///
/// [diagShouldUsePrint] deliberately does NOT widen to all release
/// builds. On release iOS/Android the platform log is not something a
/// user can open and paste, so routing there buys no support value and
/// would only put the chain back into logcat. If that ever changes,
/// widen the pure function and extend `test/log_diag_test.dart` — the
/// rule lives in one place precisely so that is a one-line decision.
///
/// That mattered because v1.2.50 added the `[Yahweh's Words jump]`
/// forensic chain specifically "so users who still report problems can
/// paste the browser console output", and **the web is where this app's
/// bug reports come from**. The instrument had never worked on the
/// platform it was built for. It also cost a whole debugging session:
/// an empty console was read as "this code never ran", when the code ran
/// fine and simply could not speak.
///
/// **What this is NOT for.** Do not convert the app's `debugPrint` calls
/// wholesale. Most are developer noise, and shipping them all to a
/// release console would drown the few lines that a support
/// conversation actually needs — and cost paint time in a hot loop.
/// `logDiag` is for the short chains deliberately written to be READ BY
/// USERS: the jump forensics first.
void logDiag(String message) {
  if (diagShouldUsePrint(isWeb: kIsWeb, isRelease: kReleaseMode)) {
    // ignore: avoid_print
    print(message);
    return;
  }
  // Everywhere else debugPrint is the better choice: it throttles, so a
  // burst cannot drop lines out of the platform log the way raw print
  // can on Android.
  debugPrint(message);
}

/// Whether [logDiag] must fall back to `print`.
///
/// Split out as a pure function so the routing rule is testable without
/// a browser: `kIsWeb` and `kReleaseMode` are compile-time constants
/// that a unit test cannot vary.
bool diagShouldUsePrint({required bool isWeb, required bool isRelease}) =>
    isWeb && isRelease;
