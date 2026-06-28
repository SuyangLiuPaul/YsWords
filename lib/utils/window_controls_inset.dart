import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';

/// 2026-06-28: clearance for iPadOS 26's windowed-mode window controls.
///
/// In a window (not full-screen) iPadOS 26 draws macOS-style traffic-light
/// controls at the top-LEADING corner. The current Flutter engine does NOT
/// surface them as a safe-area inset, so `SafeArea` (which the app already
/// uses) has nothing to inset against and the app's own top-left UI (the
/// 书卷 sidebar header, the reading-pane home button) ends up underneath
/// them. User report + screenshot: traffic lights overlapping "书卷".
///
/// We can't read the control rect from Flutter, so we DETECT the windowed
/// iPad heuristically and reserve a top band so the leading UI drops below
/// the controls (mirroring how Apple Notes shifts its sidebar title down):
///   • iOS only (macOS/web/Android/Windows/Linux have their own title bars
///     or no overlapping controls; `defaultTargetPlatform` is iOS for both
///     iPhone + iPad).
///   • `viewPadding.top == 0` → there is NO status bar over the surface.
///     A full-screen iPad ALWAYS has a status-bar top inset, so a zero top
///     inset means the app is in a window. (viewPadding, not padding —
///     padding can be zeroed by an ancestor SafeArea; viewPadding is the
///     raw inset.)
///   • `viewPadding.left/right == 0` → no notch. Excludes a notched iPhone
///     in landscape (which also has `viewPadding.top == 0` but non-zero
///     side insets) so we never add this band on iPhone.
///
/// Returns [kWindowCtrlClearance] when an iPad window is detected, else 0.
/// Tunable: bump the constant if the controls still peek through.
const double kWindowCtrlClearance = 42.0;

double iPadWindowControlTopClearance(BuildContext context) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return 0;
  final v = MediaQuery.of(context).viewPadding;
  final windowedIPad =
      v.top < 1.0 && v.left < 1.0 && v.right < 1.0 && v.bottom < 1.0;
  return windowedIPad ? kWindowCtrlClearance : 0.0;
}
