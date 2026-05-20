// 2026-05-20 (v1.2.67): platform-aware re-export for the
// `yswordsClearCacheAndReload()` function defined in web/index.html.
// Conditional import picks the web stub on web builds and the
// native no-op on iOS / Android / desktop builds — avoids the
// v1.2.7 `dart:js_interop` compile error that blocked native
// builds.
//
// Callers just `import 'clear_cache_helper.dart'` and call
// `clearCacheAndReload()` with no concern for platform.

export 'clear_cache_helper_io.dart'
    if (dart.library.js_interop) 'clear_cache_helper_web.dart';
