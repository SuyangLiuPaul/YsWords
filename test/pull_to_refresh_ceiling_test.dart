// The pull always lets go.
//
// 2026-09-15, from an iPhone: 「我往下划一下这个就不走了一直在这里」.
//
// The dashboard's pull-to-refresh awaited `Future.wait` over three
// things, one of which is `CloudSyncService.syncNow()`. That call's
// Firestore write has a two-minute timeout and, on timing out,
// refreshes the auth token and tries ONCE MORE — so the worst case a
// reader could reach by pulling down was four minutes of a spinner with
// no cancel, no status line and no explanation.
//
// It was never a hang. It was a wait, sized for a different surface: on
// the Settings screen the same call sits under a 「立即同步」 button the
// reader chose to press, beside text that says what is happening, and a
// slow corporate VPN is the reported case that made 30 s too short
// there.
//
// So the assertions below are about the SHAPE of the fix rather than
// about which call was slow: the work is not cancelled and not
// hurried, and the gesture stops watching. Anything else added to that
// `Future.wait` later is covered by the same rule.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/spinner_ceiling.dart';

void main() {
  test('a pull over work that never finishes still lets go', () {
    fakeAsync((async) {
      // The four-minute case, as a future that simply never completes.
      final stuck = Completer<void>();
      var released = false;
      waitWithCeiling(stuck.future).then((_) => released = true);

      async.elapse(kPullSpinnerCeiling - const Duration(seconds: 1));
      expect(released, isFalse, reason: 'it gave up before the ceiling');

      async.elapse(const Duration(seconds: 2));
      expect(released, isTrue,
          reason: 'the spinner is still turning past the ceiling — which '
              'is the bug, one layer down');
    });
  });

  test('work that finishes quickly is not made to wait for the ceiling',
      () {
    // The common case, and the reason the ceiling is a race rather than
    // a delay: a warm sync on a good connection must feel instant.
    fakeAsync((async) {
      var released = false;
      waitWithCeiling(Future<void>.delayed(const Duration(seconds: 1)))
          .then((_) => released = true);
      async.elapse(const Duration(seconds: 2));
      expect(released, isTrue);
    });
  });

  test('the work is left running — it is not cancelled', () {
    // The whole design. A reader who pulled down wants their notes
    // uploaded; they just do not want to watch. Cutting the work short
    // would trade a visible annoyance for an invisible data loss.
    fakeAsync((async) {
      var finished = false;
      final slow = Future<void>.delayed(
          kPullSpinnerCeiling + const Duration(seconds: 30),
          () => finished = true);
      waitWithCeiling(slow);

      async.elapse(kPullSpinnerCeiling + const Duration(seconds: 1));
      expect(finished, isFalse);

      async.elapse(const Duration(seconds: 40));
      expect(finished, isTrue,
          reason: 'the upload was abandoned when the spinner stopped');
    });
  });

  test('work that throws does not take the zone down with it', () {
    // An unawaited future that throws is an uncaught async error. The
    // gesture must swallow it: a pull that ends in a red bar because
    // the phone is on a train is worse than one that quietly changes
    // nothing.
    fakeAsync((async) {
      var released = false;
      waitWithCeiling(Future<void>.error(StateError('offline')))
          .then((_) => released = true);
      async.elapse(const Duration(seconds: 1));
      expect(released, isTrue);
    });
  });

  test('the ceiling is short enough to read as "nothing to do"', () {
    // 2026-09-18: 12 → 5, and the lower bound went with it. 「这个是首页
    // 不用12秒 可以5s够了」 — it was reported a second time, as a spinner
    // that "is still there", by the reader it was already meant to
    // protect.
    //
    // The old floor of 8 seconds was defending the SYNC's chance to
    // finish inside the gesture. That was the wrong thing to defend:
    // nothing on the home screen is waiting on the sync, and the work
    // is never cut short — only the watching is. What the floor is for
    // now is that the spinner must be seen at all, or a pull looks like
    // it did nothing.
    expect(kPullSpinnerCeiling.inSeconds, lessThanOrEqualTo(6),
        reason: 'an unexplained spinner stops being feedback and starts '
            'being a fault report');
    expect(kPullSpinnerCeiling.inSeconds, greaterThanOrEqualTo(2),
        reason: 'shorter than this and the reader cannot tell the pull '
            'was heard');
  });
}
