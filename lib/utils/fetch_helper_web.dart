// 2026-05-20 (v1.2.67): web impl — `fetch(url)` and await. The
// browser's HTTP cache + (if installed) service worker cache
// absorbs the response transparently, which is exactly what
// `offline_pack_service` wants for pre-warm.

import 'dart:js_interop';

@JS('fetch')
external JSPromise<JSAny?> _fetchPromise(String url);

Future<void> fetchUrl(String url) async {
  await _fetchPromise(url).toDart;
}
