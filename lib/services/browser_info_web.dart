// Web implementation: pull `navigator.userAgent` + `navigator.language`
// via dart:js_interop so the feedback function gets enough info to
// debug a report (browser, OS, language preference). Mirrors the
// JS-interop pattern already used in `link_opener_web` /
// `share_service_web`.

import 'dart:js_interop';

import 'browser_info_stub.dart';

@JS('navigator.userAgent')
external String get _navigatorUserAgent;

@JS('navigator.language')
external String get _navigatorLanguage;

BrowserInfo readBrowserInfo() {
  try {
    return BrowserInfo(
      userAgent: _navigatorUserAgent,
      browserLocale: _navigatorLanguage,
    );
  } catch (_) {
    return const BrowserInfo();
  }
}
