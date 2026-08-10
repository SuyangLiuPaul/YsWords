// Cross-platform "open URL in browser" helper.
//
//   • web    — a synthetic anchor click with target="_blank", so an
//              installed PWA hands the link to Safari instead of
//              loading it in its own chrome-less window.
//   • native — `url_launcher` in externalApplication mode.
//
// Uses the same conditional-import pattern as `ShareService`.
//
// 2026-08-11: the native side was a stub returning `false` — a
// placeholder from when this app shipped web only, left in place long
// after it did not. Every external link on iOS, Android, macOS and
// Windows silently did nothing, which surfaced as "original page is not
// clickable in iPhone". It was never a UI problem; the button was fine
// and the service under it refused.

import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';

import 'link_opener_stub.dart'
    if (dart.library.js_interop) 'link_opener_web.dart' as impl;

class LinkOpener {
  /// Open [url] in a new tab (web) or the external browser (native).
  ///
  /// Returns true on apparent success. "Apparent" is load-bearing on
  /// web: a pop-up blocker can swallow the open with no DOM API to
  /// detect it, so `true` means "the browser accepted the gesture", not
  /// "the user is looking at the page". Callers that need certainty
  /// should also offer copy-the-link.
  ///
  /// **Always tell the user when this returns false.** The whole reason
  /// the native stub went unnoticed for so long is that a silent
  /// `false` is indistinguishable from a tap that never registered.
  static Future<bool> open(String url) => impl.openUrl(url);

  /// Whether this platform can open URLs at all. True everywhere the
  /// app currently ships; kept as a hook for a target where it isn't.
  static bool get isAvailable => impl.openIsAvailable();

  /// [open], but says so when it fails.
  ///
  /// **Prefer this over [open] at every UI call site.** Eight of the
  /// sixteen callers discarded the boolean, so on native they rendered
  /// a button that did nothing and reported nothing — the failure mode
  /// that hid the dead native stub for months. Patching those eight
  /// individually would only mean the ninth forgets, so the reporting
  /// lives here, next to the thing that can fail.
  ///
  /// Safe to call without awaiting; it guards `context.mounted` itself.
  static Future<bool> openOrWarn(
    BuildContext context,
    String url, {
    String? locale,
  }) async {
    final ok = await open(url);
    if (!ok && context.mounted) {
      final loc = locale ?? Localizations.localeOf(context).toLanguageTag();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          uiStrings['songsOpenFailed']?[loc] ??
              uiStrings['songsOpenFailed']?['en'] ??
              'Could not open the link. Please try again.',
        ),
      ));
    }
    return ok;
  }
}
