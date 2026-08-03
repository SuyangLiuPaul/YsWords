import 'package:flutter/animation.dart';

/// Canonical animation durations and curves, so "quick transition" doesn't
/// silently mean 200ms in one widget and 300ms in another. Values below are
/// deliberately app-wide constants, not per-widget tuning knobs.
class AppMotion {
  const AppMotion._();

  /// Micro-interactions: tap feedback, small toggles.
  static const fast = Duration(milliseconds: 150);

  /// Page/route transitions, most enter/exit animations.
  static const standard = Duration(milliseconds: 250);

  /// Sheets, dialogs, and other larger reveals.
  static const slow = Duration(milliseconds: 350);

  /// Things arriving on screen.
  static const enter = Curves.easeOutCubic;

  /// Things leaving the screen.
  static const exit = Curves.easeInCubic;

  /// Back-and-forth motion (page-swipe settle, toggle animations).
  static const symmetric = Curves.easeInOutCubic;
}
