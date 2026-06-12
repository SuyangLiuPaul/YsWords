// 2026-05-19 (v1.2.54): cross-platform dispatcher for the URL sync
// layer. Web target gets the real implementation that:
//
//   • Reads `window.location.hash` on boot, parses it into a
//     book / chapter / verse / version tuple, and applies it to
//     MainProvider / AppSettings (so deep links cold-open at the
//     right passage).
//   • Listens to MainProvider changes after boot, debounces them
//     ~150 ms, and writes the new state back to the URL via
//     `history.pushState` so each chapter is a separate browser-
//     history entry (back / forward navigates between chapters).
//   • Listens to `popstate` so the browser's back / forward
//     buttons drive the reader.
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
  static void onRouteChanged() => impl.onRouteChanged();

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
