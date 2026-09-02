import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/progress_pill_geometry.dart';

/// BUGS #1, root-caused 2026-09-02 from the crash email's full stack.
///
/// The mailed-in report (v1.4.178 web) carried ten frames, not the one
/// the queue had been quoting. Frame 3 —
/// `at bXv.$2 (…/main.dart.js:157724:95)` — decodes to the reading
/// pane's progress-pill arithmetic, where `.clamp(0.0, h - pillHeight)`
/// was handed a negative upper bound and threw
/// `ArgumentError.value(0)`: literally `Invalid argument: 0`.
///
/// Guarded in `2c32e1fd`, shipped v1.4.190. These are the inputs that
/// used to throw.
void main() {
  test('a track shorter than the pill does not throw', () {
    // The crash. pillHeight floors at 20, so any track under 20px
    // makes `h - pillHeight` negative.
    for (final h in [0.0, 1.0, 10.0, 19.9]) {
      final g = progressPillGeometry(
          trackHeight: h, menuScale: 1.0, progress: 0.5);
      expect(g.pillTravel, 0.0, reason: 'h=$h');
      expect(g.pillTop, 0.0, reason: 'h=$h');
    }
  });

  test('the UNGUARDED form really does throw, on the lower bound', () {
    // Keeps the tests above from being vacuous: without the floor, this
    // is the exact expression that shipped.
    //
    // The MESSAGE is platform-dependent and this test runs on the VM, so
    // it asserts the thrown value rather than the rendering:
    //
    //   VM       Invalid argument(s): 0.0     message-only, invalidValue null
    //   dart2js  Invalid argument: 0          ArgumentError.value(lowerLimit)
    //
    // Both measured 2026-09-02. The two SDKs build the error
    // differently — `js_number.dart` calls `argumentErrorValue`, so the
    // value is attached and "(s)" is dropped, and JS stringifies the
    // double `0.0` as `0`. That is why the user's report reads exactly
    // `Invalid argument: 0`, and part of why this only ever looked like
    // a web-only defect: the same throw from iOS or Android would have
    // arrived as `Invalid argument(s): 0.0` and might not have been
    // recognised as the same bug.
    //
    // So this asserts what holds on both: it throws instead of clamping.
    const h = 10.0, pillHeight = 20.0, clamped = 0.5;
    expect(
      () => (clamped * (h - pillHeight)).clamp(0.0, h - pillHeight),
      throwsA(isA<ArgumentError>().having(
          (e) => e.toString(), 'toString', contains('Invalid argument'))),
    );
  });

  test('a negative track height does not throw either', () {
    // Not merely theoretical: a mid-collapse layout pass can hand a
    // LayoutBuilder a zero or degenerate box.
    final g =
        progressPillGeometry(trackHeight: -50, menuScale: 1.0, progress: 1.0);
    expect(g.pillTravel, 0.0);
    expect(g.pillTop, 0.0);
  });

  test('the pill still travels the full track when there is room', () {
    final g = progressPillGeometry(
        trackHeight: 220, menuScale: 1.0, progress: 1.0);
    expect(g.pillHeight, 22.0);
    expect(g.pillTravel, 198.0);
    expect(g.pillTop, 198.0); // flush to the bottom, not past it
  });

  test('progress is clamped, so out-of-range input cannot overflow', () {
    final over = progressPillGeometry(
        trackHeight: 220, menuScale: 1.0, progress: 9.0);
    final under = progressPillGeometry(
        trackHeight: 220, menuScale: 1.0, progress: -9.0);
    expect(over.pillTop, 198.0);
    expect(under.pillTop, 0.0);
  });

  test('pill height stays inside 20–32 whatever the menu scale', () {
    // The bound that decides when the crash window opens: a track under
    // 20px is unsafe at ANY scale, and no scale makes the pill smaller.
    for (final s in [0.1, 0.5, 1.0, 2.0, 10.0]) {
      final g =
          progressPillGeometry(trackHeight: 500, menuScale: s, progress: 0.5);
      expect(g.pillHeight, inInclusiveRange(20.0, 32.0), reason: 's=$s');
    }
  });

  test('an unbounded track height yields no NaN pillTop', () {
    // LayoutBuilder can report infinity. The guard must not turn that
    // into a NaN offset, which would fail later and further away.
    final g = progressPillGeometry(
        trackHeight: double.infinity, menuScale: 1.0, progress: 0.0);
    expect(g.pillTop.isNaN, isFalse);
  });
}
