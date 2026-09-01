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
/// URL-routing Stage 2 (`docs/url-routing-plan.md`): paths registered
/// as a `GetPage` in `main.dart`'s `getPages` table. `pushPage` routes a
/// call here through `Get.toNamed` instead of the anonymous `Get.to`
/// below when the caller passes one of these as `routeName` explicitly
/// — so GetX's named-route push writes the real path to the browser URL
/// directly, no need for the 350ms "rewrite to Bible position"
/// correction (`url_sync_service_web.dart`'s `onRouteChanged`) that
/// every other page still relies on.
///
/// 2026-09-01: the first version of this keyed off
/// `page.runtimeType.toString()` instead, to avoid the caller having to
/// pass anything new. That's broken in exactly the build this app
/// ships: `flutter build web --release` minifies class names, so a real
/// `AboutPage` instance's `runtimeType.toString()` is NOT the string
/// `"AboutPage"` at runtime — confirmed by grepping the built
/// `main.dart.js`, where the literal `AboutPage` appears exactly once,
/// as this very map's (then string) key, and nowhere in the compiled
/// class's own tag. The lookup silently never matched, so the whole
/// mechanism no-op'd in the one build that matters. Matching on the
/// explicit `routeName` string instead sidesteps minification
/// entirely — string literals are never renamed.
///
/// Kept in sync with `getPages` by hand until Stage 3 converts the rest
/// of §6's batches — a path pushed here that's missing from `getPages`
/// would throw inside GetX's route resolver, so an entry only belongs
/// here once the matching `GetPage` exists.
const Set<String> _registeredRoutePaths = {'/about', '/highlights'};

Future<T?>? pushPage<T>(
  Widget page, {
  bool reverse = false,
  String? routeName,
  bool preventDuplicates = true,
}) {
  if (routeName != null && _registeredRoutePaths.contains(routeName)) {
    return Get.toNamed<T>(
      routeName,
      preventDuplicates: preventDuplicates,
    );
  }
  return Get.to<T>(
    () => page,
    routeName: routeName ?? '/${page.runtimeType}',
    preventDuplicates: preventDuplicates,
    transition: reverse ? Transition.leftToRight : Transition.rightToLeft,
    duration: AppMotion.standard,
    curve: AppMotion.enter,
  );
}
