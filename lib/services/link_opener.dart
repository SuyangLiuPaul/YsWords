// Cross-platform "open URL in browser" helper.
//
//   • web    — a synthetic anchor click with target="_blank", so an
//              installed PWA hands the link to Safari instead of
//              loading it in its own chrome-less window.
//   • native — `url_launcher` in externalApplication mode.
//
// Uses the same conditional-import pattern as `ShareService`.
//
// 2026-08-24: not every link should leave. A YouTube video now plays in
// a sheet inside the app on the four targets that have a webview, and
// only falls out to the browser where one does not — see [openOrWarn].
//
// 2026-08-11: the native side was a stub returning `false` — a
// placeholder from when this app shipped web only, left in place long
// after it did not. Every external link on iOS, Android, macOS and
// Windows silently did nothing, which surfaced as "original page is not
// clickable in iPhone". It was never a UI problem; the button was fine
// and the service under it refused.

import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/widgets/youtube_player_sheet.dart';

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

  /// The link the user asked for, opened wherever it is best opened,
  /// and reported when that fails.
  ///
  /// **Prefer this over [open] at every UI call site.** Eight of the
  /// sixteen callers discarded the boolean, so on native they rendered
  /// a button that did nothing and reported nothing — the failure mode
  /// that hid the dead native stub for months. Patching those eight
  /// individually would only mean the ninth forgets, so the reporting
  /// lives here, next to the thing that can fail.
  ///
  /// 2026-08-24, the same argument a second time, for a second thing:
  /// "歌曲里面有几个是YouTube如果按了去YouTube了，但是web 和ios能不能不跳
  /// 转出去，好像WhatsApp那样YouTube对话框在播放音乐，其实整个app都要这样".
  /// A YouTube link now opens the in-app player instead of leaving the
  /// app — and it does so HERE, once, so "整个app" is a property of the
  /// chokepoint rather than a promise 17 call sites have to keep. Not
  /// one of them changed to get it.
  ///
  /// Everything that is not a playable YouTube video takes exactly the
  /// path it took before: [inAppYoutubeId] returns null for a non-video
  /// URL, and also on Windows and Linux, where there is no webview to
  /// embed into.
  ///
  /// Safe to call without awaiting; it guards `context.mounted` itself.
  static Future<bool> openOrWarn(
    BuildContext context,
    String url, {
    String? locale,
  }) async {
    final videoId = inAppYoutubeId(url);
    if (videoId != null) {
      await showYoutubeSheet(context, videoId, watchUrl: url, locale: locale);
      // The sheet opened; nothing to warn about. The bool means "the
      // tap was honoured", which it was — see [open] on why this
      // deliberately does not claim the user is watching.
      return true;
    }
    return openExternally(context, url, locale: locale);
  }

  /// [open], but says so when it fails. Leaves the app, always.
  ///
  /// Split out of [openOrWarn] on 2026-08-24 so the in-app player's own
  /// "Watch on YouTube" button has something to call: routing that
  /// through [openOrWarn] would hand the link straight back to the
  /// player it is trying to escape.
  ///
  /// Call this directly only when leaving is the point. Everywhere else
  /// [openOrWarn] is the one you want.
  static Future<bool> openExternally(
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
