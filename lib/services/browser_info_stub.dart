// Stub for non-web platforms. Returns empty strings -- the web
// implementation in `browser_info_web.dart` reads navigator.* via
// dart:js_interop. Conditional-import pattern matches what
// `link_opener_stub` / `share_service_stub` already do.

class BrowserInfo {
  const BrowserInfo({
    this.userAgent = '',
    this.browserLocale = '',
  });

  final String userAgent;
  final String browserLocale;
}

BrowserInfo readBrowserInfo() => const BrowserInfo();
