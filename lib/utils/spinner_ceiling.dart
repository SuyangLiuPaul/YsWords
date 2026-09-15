/// A ceiling on how long a gesture is allowed to show a spinner.
///
/// 2026-09-15, from an iPhone: 「我往下划一下这个就不走了一直在这里」 — the
/// dashboard's pull-to-refresh spun and never stopped.
///
/// It was not hung. It was awaiting `CloudSyncService.syncNow()`, whose
/// Firestore write has a **two-minute** timeout and, on timing out,
/// refreshes the auth token and tries **once more** — so the worst case
/// a reader can reach by pulling down is four minutes of a spinner with
/// no cancel and no text.
///
/// Those two minutes are right where they were written. `syncNow` is
/// the Settings screen's 「立即同步」 button: it sits beside a status
/// line that says what is happening, the reader chose to press it, and
/// a slow corporate VPN was the reported case that made 30 s too short.
/// A PULL is a different act with the same call underneath — no status
/// line, no cancel, and a reader who was only trying to scroll.
///
/// THE FIX IS NOT A SHORTER TIMEOUT, and this is the whole reason this
/// file exists rather than a number being edited elsewhere. Cutting the
/// sync's own timeout would break the case it was raised for. What is
/// wrong is that the GESTURE waits for the WORK. So the work is left
/// alone to finish in its own time — the upload still lands, and
/// Settings still shows its state — and only the spinner is bounded.
library;

import 'dart:async';

/// How long a pull may spin before the gesture gives up watching.
///
/// Long enough for a warm sync and an update check on a normal
/// connection, short enough that a reader on a bad one reads it as
/// "nothing to do" rather than as a frozen app. Past roughly ten
/// seconds an unexplained spinner stops being feedback and starts being
/// a fault report.
const Duration kPullSpinnerCeiling = Duration(seconds: 12);

/// Wait for [work], but never longer than [ceiling].
///
/// [work] is NOT cancelled — nothing here can cancel a Firestore write,
/// and cancelling would be the wrong thing anyway: the reader wants
/// their notes uploaded, they just do not want to watch. Its errors are
/// swallowed, because an unawaited future that throws takes down the
/// zone, and because a pull that ends in a red bar because the phone is
/// on a train is worse than a pull that quietly changes nothing.
///
/// Returns when whichever comes first has happened, so a caller can do
/// its own post-refresh work on the same frame.
/// A cancellable timer rather than `Future.any` over a
/// `Future.delayed`, and the difference is not cosmetic. A delayed
/// future cannot be cancelled: when the work wins the race, its timer
/// keeps running for the rest of the ceiling with nothing to do. In the
/// app that is a wasted timer; in a widget test it is a PENDING TIMER
/// at teardown, which fails the test outright — which is exactly how
/// `pull_to_refresh_test.dart` failed on the first version of this
/// function.
Future<void> waitWithCeiling(
  Future<void> work, {
  Duration ceiling = kPullSpinnerCeiling,
}) {
  final done = Completer<void>();
  final timer = Timer(ceiling, () {
    if (!done.isCompleted) done.complete();
  });
  work.catchError((Object _) {}).whenComplete(() {
    timer.cancel();
    if (!done.isCompleted) done.complete();
  });
  return done.future;
}
