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
    // Past roughly ten seconds an unexplained spinner stops being
    // feedback and starts being a fault report. Pinned so a later
    // "just give it a bit longer" has to argue with this line.
    expect(kPullSpinnerCeiling.inSeconds, lessThanOrEqualTo(15));
    expect(kPullSpinnerCeiling.inSeconds, greaterThanOrEqualTo(8),
        reason: 'too short and a normal sync never gets to finish, so '
            'the pull stops doing its job');
  });
}
