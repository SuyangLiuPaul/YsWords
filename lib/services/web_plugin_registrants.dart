// 2026-05-20 (v1.2.67 follow-up): platform-aware re-export for
// the v1.2.49 "self-register Firebase web plugins" code. Web
// build pulls in the actual `_web` packages + `webPluginRegistrar`;
// native build gets a no-op. Without this split, the iOS / Android
// compile fails because `cloud_firestore_web`,
// `firebase_auth_web`, etc. transitively import `dart:ui_web`
// which doesn't exist off-web.
//
// Callers just `import 'web_plugin_registrants.dart'` and call
// `registerWebPluginsIfNeeded()` — the function is gated on
// `kIsWeb` internally on web (no-op when not actually needed)
// and is a hard no-op on native.

export 'web_plugin_registrants_io.dart'
    if (dart.library.js_interop) 'web_plugin_registrants_web.dart';
