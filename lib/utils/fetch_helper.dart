// 2026-05-20 (v1.2.67): platform-aware re-export for a fire-and-
// forget URL fetch. Used by `offline_pack_service` to pre-warm
// the browser cache for assets, sermons, etc.
//
// Web: dispatches a `fetch(url)` and awaits its completion (uses
// the browser's HTTP cache + service-worker cache machinery — the
// whole point of pre-warm).
//
// Native: no service worker on iOS / Android, no pre-warming
// concept. The "offline pack" UI is web-specific anyway (toggle
// is hidden on native via `kIsWeb`), so the no-op is safe — the
// callsite is unreachable on native unless somebody manually
// rebuilds the UI to expose it.

export 'fetch_helper_io.dart'
    if (dart.library.js_interop) 'fetch_helper_web.dart';
