/// Geometry for the reading pane's vertical progress pill.
///
/// This is the confirmed throw site of BUGS #1 — the mailed-in
/// `Invalid argument: 0` on v1.4.178 web. The crash report's third stack
/// frame (`main.dart.js:157724:95`) decodes to this calculation:
///
///     e = B.h.P(22*f,20,32)              (22 * menuScale).clamp(20, 32)
///     d = h - e
///     c = B.h.P(B.h.P(g.c,0,1)*d,0,d)    (progress.clamp(0,1) * d).clamp(0, d)
///
/// When the track is shorter than the pill — a mid-collapse layout pass,
/// a very short viewport — `d` goes negative, and Dart's `clamp` THROWS
/// `ArgumentError.value(lowerLimit)` when `upper < lower` instead of
/// clamping to it. With a lower bound of `0`, that renders as exactly
/// `Invalid argument: 0`.
///
/// Guarded in `2c32e1fd` (shipped v1.4.190) by flooring the travel at 0
/// before it is used as an upper bound. Extracted here 2026-09-02 so the
/// guard has a test that exercises the failing input directly — the
/// commit that fixed it could only add a boot-state test, because the
/// arithmetic was buried in a private widget's LayoutBuilder.
library;

typedef ProgressPillGeometry = ({
  double pillHeight,
  double pillTravel,
  double pillTop,
});

ProgressPillGeometry progressPillGeometry({
  required double trackHeight,
  required double menuScale,
  required double progress,
}) {
  final pillHeight = (22 * menuScale).clamp(20.0, 32.0).toDouble();
  final clamped = progress.clamp(0.0, 1.0);
  // The floor is the fix. `trackHeight - pillHeight` is negative
  // whenever the track cannot fit the pill, and feeding that straight in
  // as an upper bound is what threw.
  final pillTravel = (trackHeight - pillHeight).clamp(0.0, double.infinity);
  final pillTop = (clamped * pillTravel).clamp(0.0, pillTravel).toDouble();
  return (pillHeight: pillHeight, pillTravel: pillTravel, pillTop: pillTop);
}
