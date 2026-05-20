// 2026-05-20 (v1.2.67): platform-aware re-export for the
// browser's `navigator.onLine` flag. Web build returns the real
// value; native build assumes online (no equivalent on iOS /
// Android without adding `connectivity_plus`). The shared
// service callers that read this value treat "false" as
// "definitely offline, skip the network op" — defaulting to
// "true" on native is safe and matches existing UX (network ops
// either succeed or fail with a clear error, never silently
// skipped).

export 'navigator_online_helper_io.dart'
    if (dart.library.js_interop) 'navigator_online_helper_web.dart';
