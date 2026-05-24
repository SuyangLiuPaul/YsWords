/// PWA install-prompt facade.
///
/// 2026-05-24 (v1.3.25): added so the Flutter side can detect:
///   - whether the user is ALREADY running in installed mode
///     (Add-to-Home-Screen on iOS, installed PWA on Android,
///     chrome://apps launch on desktop) — so we hide the affordance
///   - whether the browser is offering a native install prompt
///     (Chrome fires `beforeinstallprompt` when the SW + manifest
///     align — currently dormant because the cache-bust script
///     unregisters every SW on load, but the bridge is in place)
///   - the user's platform (iOS Safari = Share → AHTS dialog;
///     Android Chrome = native install picker; desktop = AHTS or
///     a permanent app)
///
/// The web implementation reads `window.yswordsInstall` from
/// `index.html`. Native (iOS / macOS / Android) returns "already
/// installed" semantics since the user is in the native shell.
library;

import 'package:yswords/services/install_prompt_service_stub.dart'
    if (dart.library.js_interop) 'package:yswords/services/install_prompt_service_web.dart'
    as platform;

/// Hint for which install-flow UI to show.
enum InstallFlowKind {
  /// User is already running in installed/standalone mode — hide
  /// the affordance entirely.
  alreadyInstalled,

  /// Browser is offering a native install prompt (Chrome / Edge
  /// after the SW + manifest checks pass). Call
  /// `InstallPromptService.show()` to trigger it.
  nativePrompt,

  /// iOS Safari — no programmatic install API; show the manual
  /// "tap Share → Add to Home Screen" instructions.
  iosManual,

  /// Desktop browser (Chrome / Edge / Brave) where Add-to-Home-
  /// Screen exists but no `beforeinstallprompt` has fired yet. Show
  /// the instructions for opening the install menu.
  desktopManual,

  /// Native build — the app is already an installed native
  /// binary; no install affordance needed.
  notApplicable,
}

class InstallPromptService {
  /// Inspect the current environment and return the best install
  /// affordance to surface.
  static InstallFlowKind detect() => platform.detect();

  /// Trigger the native install prompt. Returns 'accepted',
  /// 'dismissed', or 'unavailable'. Only meaningful when
  /// `detect()` returned `nativePrompt`.
  static Future<String> show() => platform.show();
}
