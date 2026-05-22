// 2026-05-22 (v1.2.71): native (iOS / Android / macOS / Linux /
// Windows) implementation of BrowserInfo. Reports the OS family +
// version + locale-from-Platform so the feedback form captures
// device context on native too. The "browser" name is historical —
// the struct doubles as the platform-info struct for non-web.
//
// On web, the parallel `browser_info_web.dart` populates userAgent
// + browserLocale via navigator.* through dart:js_interop. Both
// files share the same BrowserInfo shape so feedback_service.dart
// reads them uniformly.

import 'dart:io' show Platform;

class BrowserInfo {
  const BrowserInfo({
    this.userAgent = '',
    this.browserLocale = '',
  });

  final String userAgent;
  final String browserLocale;
}

BrowserInfo readBrowserInfo() {
  // Build a synthetic user-agent-like string that captures the
  // native platform + OS version. Example payloads:
  //   "iOS 17.5.1 (Dart Flutter native)"
  //   "Android 14 (Dart Flutter native)"
  //   "macOS Version 14.5 (Build 23F79) (Dart Flutter native)"
  // The string format mirrors web user-agents so the server-side
  // feedback handler can render it in the same diagnostic block
  // without any branching.
  try {
    final os = Platform.operatingSystem; // ios, android, macos, ...
    final ver = Platform.operatingSystemVersion;
    final pretty = switch (os) {
      'ios' => 'iOS',
      'macos' => 'macOS',
      'android' => 'Android',
      'linux' => 'Linux',
      'windows' => 'Windows',
      'fuchsia' => 'Fuchsia',
      _ => os,
    };
    return BrowserInfo(
      userAgent: '$pretty $ver (Dart Flutter native)',
      browserLocale: Platform.localeName,
    );
  } catch (_) {
    // Defensive — Platform isn't available on web, but we're in the
    // stub path that only runs on native. Still guard so a runtime
    // error doesn't break feedback submission.
    return const BrowserInfo();
  }
}
