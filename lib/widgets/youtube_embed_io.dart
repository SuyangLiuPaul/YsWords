import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'package:yswords/widgets/youtube_embed_src.dart';

/// The YouTube player, embedded in-app on iOS, Android and macOS.
///
/// 2026-08-23, from the user watching a featured video on the iPhone:
/// "iOS版本featured video跳到YouTube是特意的还是留在app上看" — asked
/// twice in one evening, which is its own answer. Linking out WAS
/// deliberate (the old stub's six-target reasoning), but the user wants
/// to stay in the app, so the three platforms with a real webview now
/// get the same youtube-nocookie embed the web build uses.
///
/// Windows and Linux still return null and keep the link-out path:
/// `webview_flutter` compiles there (it is a federated interface) but
/// has no implementation, so the gate is a RUNTIME platform check —
/// which is exactly what keeps all six targets building from one file
/// where a compile-time split could not tell desktop apart.
Widget? youtubeEmbed(String videoId, {int startSeconds = 0}) {
  if (!(Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
    return null;
  }
  return _YoutubeEmbed(videoId: videoId, startSeconds: startSeconds);
}

/// Always null here: the position-preserving language switch is web-only
/// for now.
///
/// The web build reads the player over `postMessage`. This one runs the
/// same iframe one layer down, inside a `webview_flutter` page we wrote,
/// so the answer would have to come back over a JS channel from that
/// wrapper — a second, differently-shaped mechanism, on the three
/// platforms hardest to verify from here. Returning null means
/// [youtubeEmbed]'s `startSeconds` stays 0 on native and the URL is
/// byte-for-byte the one that has been shipping, so nothing about
/// native playback changes while this is unbuilt.
int? youtubeEmbedPositionSeconds(String videoId) => null;

class _YoutubeEmbed extends StatefulWidget {
  const _YoutubeEmbed({required this.videoId, this.startSeconds = 0});

  final String videoId;
  final int startSeconds;

  @override
  State<_YoutubeEmbed> createState() => _YoutubeEmbedState();
}

class _YoutubeEmbedState extends State<_YoutubeEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // WebKit needs two things declared AT CREATION or inline playback
    // silently degrades: without `allowsInlineMediaPlayback` iOS hands
    // the video to the system fullscreen player the moment it starts
    // (the jump-out this widget exists to remove, one layer down), and
    // without an empty `mediaTypesRequiringUserAction` the autoplay in
    // the embed URL is ignored — the user taps the thumbnail and then
    // must tap the player's own button, the same video needing two
    // plays. Android's equivalent is a setter after creation.
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      // v1.4.130 loaded the embed URL as the TOP document and every
      // video failed with "Error 153 — Video player configuration
      // error". 153 is YouTube refusing an embed whose request carries
      // no embedding page: the iframe player is designed to live INSIDE
      // a page, and a bare webview navigation has no parent origin and
      // sends no Referer. So the player ships wrapped in a minimal
      // page, and `baseUrl` names an origin we control — the same one
      // the media-proxy fallback uses — which is what the Referer is
      // derived from.
      ..loadHtmlString(
          _wrapperHtml(widget.videoId, widget.startSeconds),
          baseUrl: 'https://yswords-qat.netlify.app');
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  /// Mirrors the web build's iframe (`youtube_embed_web.dart`): same
  /// nocookie host, same allow list (including the clipboard-write the
  /// player's own "copy link" needs), plus `playsinline` and
  /// `autoplay` — the widget only mounts after the thumbnail tap, so
  /// starting immediately is honouring that tap.
  ///
  /// The URL now comes from the shared [youtubeEmbedSrc] rather than a
  /// second copy of the same string, which is how the two stopped
  /// mirroring each other last time. `enableJsApi` is off here and
  /// [startSeconds] is always 0 (see [youtubeEmbedPositionSeconds]), so
  /// what this builds is byte-for-byte the URL that was here before.
  static String _wrapperHtml(String id, int startSeconds) => '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;height:100%;background:#000}
iframe{border:0;width:100%;height:100%}</style></head><body>
<iframe src="${youtubeEmbedSrc(id, startSeconds: startSeconds)}"
 allow="accelerometer; autoplay; encrypted-media; picture-in-picture; fullscreen; clipboard-write"
 allowfullscreen></iframe></body></html>''';

  @override
  Widget build(BuildContext context) =>
      WebViewWidget(controller: _controller);
}
