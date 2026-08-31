// Platform-aware page reload for the web update checker.
//
// Deliberately NOT `clearCacheAndReload()`: that one wipes EVERY Cache
// Storage bucket, including `song-media-*`, which is where a user's
// downloaded songs live. Throwing away someone's offline music to pick
// up a routine version bump would be a worse bug than the staleness it
// fixes. A plain reload is enough here — the entry files are served
// `no-store` and the app's own service worker is network-first, so a
// reload always lands on the newly deployed build.
//
// Callers just `import 'page_reload.dart'`; the conditional import
// keeps `dart:js_interop` off the native compile path.

export 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_web.dart';
