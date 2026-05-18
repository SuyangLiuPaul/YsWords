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
