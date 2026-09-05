// 2026-05-19 (v1.2.54): cross-platform dispatcher for the URL sync
// layer. Web target gets the real implementation that:
//
//   • Reads `window.location.hash` on boot, parses it into a
//     book / chapter / verse / version tuple, and applies it to
//     MainProvider / AppSettings (so deep links cold-open at the
//     right passage).
//   • Listens to MainProvider changes after boot, debounces them
//     ~150 ms, and REPLACES the current URL with the new state, so
//     the address bar always names the passage on screen and the
//     link is always shareable.
//   • Listens to `popstate` so the browser's back / forward
//     buttons drive the reader.
//
// 2026-09-05: the two bullets above used to say the write was a
// `history.pushState`, so that each chapter became its own browser-
// history entry and the browser's Back and Forward buttons moved
// between chapters. That was false in both halves and is corrected
// here rather than softened. Measured in headless Chrome against a
// real release build: the push DID create an
// entry, but it was one the Flutter web engine did not recognise, so
// one Back cascaded past every chapter at once and then PUSHED a page
// (`unknownRoute`) instead of popping. Back never navigated between
// chapters, and Forward has never been reachable at all in
// single-entry history mode. See `_writeStateToUrl` in
// `url_sync_service_web.dart` for the trace.
//
// Native targets get the stub (no-op) — Android / iOS / desktop
// don't have a URL bar, so URL sync is meaningless there. The
// conditional import keeps the analyzer happy on every platform
// without dragging `dart:js_interop` into native compile units.
//
// Public API mirrors the existing `ShareService` pattern:
//
//   await UrlSyncService.init(mainProvider, appSettings);
//
// Caller fires-and-forgets; the service self-wires its listeners
// and unsubscribes are not needed (singleton lifetime = app
// lifetime).

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';

import 'url_sync_service_stub.dart'
    if (dart.library.js_interop) 'url_sync_service_web.dart' as impl;

class UrlSyncService {
  /// 2026-06-11 (v1.3.61): snapshot `window.location.hash` BEFORE the
  /// Flutter engine starts. With a plain `MaterialApp(home:)`, the web
  /// engine reports the initial route ('/') shortly after first frame
  /// and OVERWRITES the URL fragment — so by the time [init] ran
  /// (post-restoreState, seconds into boot) a shared deep link like
  /// `#/revelation/17:1?v=biblexg-v2` was already wiped and the apply
  /// silently no-op'd; the first state write then replaced the link
  /// with the boot default. Call this synchronously at the very top of
  /// `main()`; native targets no-op.
  static void captureBootHash() => impl.captureBootHash();

  /// 2026-06-12 (v1.3.62 UX): register a callback fired exactly once
  /// when a BOOT deep link (a reader hash present at cold open) has
  /// been successfully applied to MainProvider. main.dart uses it to
  /// land the user directly in the reader — without it, a shared link
  /// dropped people on the Dashboard where they had to tap "Read
  /// Bible" themselves. Native targets never fire it.
  static void setBootDeepLinkCallback(void Function() cb) =>
      impl.setBootDeepLinkCallback(cb);

  /// 2026-06-12 (v1.3.62 UX): notify the URL layer that a navigator
  /// route was pushed/popped. The Flutter web engine writes the
  /// route's (minified) name into the URL fragment on push — e.g.
  /// `#/minified:Xt` — clobbering our canonical share link. This
  /// schedules a rewrite of the proper `#/<book>/<chapter>?v=`
  /// fragment shortly after the engine's write. Native no-op.
  ///
  /// 2026-09-01 (URL-routing Stage 2): `routeName` is the route now on
  /// top of the Navigator stack (the pushed route on `didPush`, the
  /// revealed one on `didPop` — see `main.dart`'s `_UrlRestoreObserver`).
  /// When it's one of [setKnownRoutes]' registered paths, the correction
  /// below is skipped entirely: GetX's named push already wrote that
  /// path to the URL directly, and rewriting it back to the Bible
  /// position is exactly the "two histories" bug
  /// `docs/url-routing-plan.md` §5 traces.
  static void onRouteChanged({String? routeName}) =>
      impl.onRouteChanged(routeName: routeName);

  /// 2026-09-01 (URL-routing Stage 2): the set of paths registered in
  /// `main.dart`'s `getPages` table (e.g. `{'/about', '/highlights'}`).
  /// Call once at boot, before any navigation. Lets the web impl tell a
  /// registered non-Bible route apart from the Bible reader without
  /// hard-coding the path list a second time. Native no-op.
  static void setKnownRoutes(Set<String> routeNames) =>
      impl.setKnownRoutes(routeNames);

  // 2026-09-03: `setPopRouteCallback` is GONE, not deprecated. It was
  // added 2026-09-01 on the reasoning that "`popstate` alone only
  // updates `window.location`; the Flutter Navigator never hears about
  // it" (docs/url-routing-plan.md §5 point 6). Measured in a real
  // release web build, the Navigator hears about it fine: Flutter's own
  // `SingleEntryBrowserHistory` turns the Back press into a `popRoute`
  // platform message and `WidgetsApp.didPopRoute` pops one route,
  // BEFORE this package's popstate listener even runs. Registering a
  // second pop on top of that made one Back unwind two pages. See
  // `url_sync_service_web.dart`'s popstate listener for the trace.

  /// 2026-09-01 (URL-routing Stage 2): fired once, at boot, if the URL
  /// the app was opened with names a registered route directly (e.g. a
  /// bookmark to `/#/about`) rather than a Bible reference. The
  /// existing boot-hash apply only understands the Bible grammar
  /// (docs/url-routing-plan.md §1) and silently no-ops on anything
  /// else, so a registered route needs its own boot path — this is it.
  /// Register before first navigation; native no-op.
  static void setBootRouteCallback(void Function(String routeName) cb) =>
      impl.setBootRouteCallback(cb);

  /// Initialise. Web reads the boot URL, applies it to providers,
  /// then starts listening for further state / popstate events.
  /// Native targets no-op.
  static Future<void> init({
    required MainProvider mainProvider,
    required AppSettings appSettings,
  }) =>
      impl.urlSyncInit(
        mainProvider: mainProvider,
        appSettings: appSettings,
      );
}
