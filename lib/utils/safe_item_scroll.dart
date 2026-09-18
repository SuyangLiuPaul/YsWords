/// The one way this app animates a `ScrollablePositionedList` —
/// 2026-09-18, from a production error report.
///
/// `[SeekSparks 1.6.317 web] Bad state: No element`, Windows, Chrome —
/// reported from the sibling app, whose reader this one shares. Rebuilt
/// that release with source maps and read the stack against it: the
/// throw is `ScrollController.position` (`_positions.single`) inside
/// `scrollable_positioned_list` 0.3.8's `_scrollTo`, in the branch taken
/// when a scroll is requested while an earlier one is still animating:
///
///     if (_isTransitioning) {
///       _stopScroll(canceled: true);
///       SchedulerBinding.instance.addPostFrameCallback((_) async {
///         await _startScroll(...);   // no mounted / attached check
///
/// The second request is parked for a frame, and if the list is torn
/// down in that frame — a chapter turn, a pane rebuilt, the reader
/// leaving — it asks a detached controller for its position. Every guard
/// the call sites had (`isAttached`, `canScrollList`) is read when the
/// call is MADE, a frame before the failure, so none of them could see
/// it. The error is thrown in a post-frame callback nobody awaits, which
/// is why it reached the error mailer rather than the caller.
///
/// So the rule here is about the one path that can fail: never queue a
/// second animated scroll behind one of ours that is still running.
/// Jump instead. `jumpTo` is synchronous — it stops the running
/// animation and repositions in the same frame, with nothing left
/// waiting on a list that may be gone. The reader loses a 180 ms glide
/// on a request that arrived mid-glide, which is the only cost.
///
/// `test/safe_item_scroll_test.dart` reproduces the crash with the raw
/// call, pins that this one survives it, and fails on any `.scrollTo(`
/// in `lib/` outside this file.
library;

import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'
    show ItemScrollController;

/// Controllers with one of OUR animated scrolls still running.
final Expando<bool> _animating = Expando<bool>('scrollToSafely');

/// `controller.scrollTo`, minus the crash. See the library comment.
///
/// Does nothing when the list is not attached — the call sites all
/// checked that already, and still do, but a helper that is the only way
/// to scroll should not depend on every caller remembering.
Future<void> scrollToSafely(
  ItemScrollController controller, {
  required int index,
  required Duration duration,
  double alignment = 0,
  Curve curve = Curves.linear,
}) async {
  if (!controller.isAttached) return;
  if (_animating[controller] == true) {
    controller.jumpTo(index: index, alignment: alignment);
    return;
  }
  _animating[controller] = true;
  try {
    await controller.scrollTo(
      index: index,
      duration: duration,
      alignment: alignment,
      curve: curve,
    );
  } finally {
    _animating[controller] = null;
  }
}
