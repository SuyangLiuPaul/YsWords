import 'package:flutter/widgets.dart';

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

  /// [d], or nothing at all if the reader has asked for less motion.
  ///
  /// 2026-09-14, from the accessibility pass. WCAG 2.3.3 asks that
  /// motion animation triggered by interaction can be turned off, and
  /// the platform switch that says so — Reduce Motion on iOS/macOS,
  /// "Remove animations" on Android, `prefers-reduced-motion: reduce`
  /// in a browser — arrives in Flutter as
  /// [MediaQueryData.disableAnimations]. Two widgets in this app read it
  /// ([PressScale] and the liquid-glass surface); every other animation
  /// ignored it, because an implicit animation takes the duration it is
  /// handed and the framework never checks the flag on its behalf.
  ///
  /// Deliberately applied to MOVEMENT and not to fades. 2.3.3 is about
  /// motion — something travelling, scaling or spinning — and a 150ms
  /// crossfade is not that; zeroing every AnimatedSwitcher would make
  /// labels change by jump cut for a reader who asked for calm, which is
  /// not calmer. What takes it here: the two reading-pane chrome bars
  /// that slide 1.4x their own height, the whole reading column sliding
  /// sideways when the sidebar opens, the sidebar itself, the disclosure
  /// rotations and the panes that resize.
  ///
  /// `Duration.zero` rather than something short: an implicit animation
  /// with a zero duration jumps straight to its new value, which is what
  /// "no animation" means. A 1ms animation still schedules a frame and
  /// still ticks a curve.
  static Duration duration(BuildContext context, Duration d) =>
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
          ? Duration.zero
          : d;
}
