import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:yswords/constants/motion.dart';

/// Canonical page-push helper — every `Get.to(...)` in the app should
/// route through here instead of specifying its own transition/duration/
/// curve, so page navigation feels consistent everywhere and the timing
/// can be tuned in one place ([AppMotion]).
/// 2026-08-03: `routeName` MUST be derived from the page widget, never
/// left null. GetX's `Get.to` does `routeName ??= "/${page.runtimeType}"`
/// where `page` is the BUILDER CLOSURE, then silently returns null when
/// `preventDuplicates && routeName == currentRoute`.
///
/// The old per-call-site `Get.to(() => SettingsPage(), ...)` gave each
/// closure a distinct type (`() => SettingsPage`), so every page got a
/// unique route name. Routing through this helper types the closure by
/// the `Widget` parameter instead — `() => Widget` for EVERY call site —
/// so after the first push `currentRoute` was already `/Widget` and every
/// later push matched it and did nothing. Symptom: the first navigation
/// worked, then Settings / Library / the book picker / most menu items
/// became dead taps app-wide. Passing the widget's own runtimeType
/// restores the old, correct per-page naming.
Future<T?>? pushPage<T>(
  Widget page, {
  bool reverse = false,
  String? routeName,
  bool preventDuplicates = true,
}) =>
    Get.to<T>(
      () => page,
      routeName: routeName ?? '/${page.runtimeType}',
      preventDuplicates: preventDuplicates,
      transition: reverse ? Transition.leftToRight : Transition.rightToLeft,
      duration: AppMotion.standard,
      curve: AppMotion.enter,
    );
