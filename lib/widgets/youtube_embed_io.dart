import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The YouTube player, embedded in-app on iOS, Android and macOS.
///
/// 2026-08-23, from the user watching a featured video on the iPhone:
/// "iOS版本featured video跳到YouTube是特意的还是留在app上看" — asked
/// twice in one evening, which is its own answer. Linking out WAS
/// deliberate (the stub's six-target reasoning), but the user wants to
/// stay in the app, so the three platforms with a real webview now get
/// the same youtube-nocookie embed the web build uses.
///
/// Windows and Linux still return null and keep the link-out path:
/// `webview_flutter` compiles there (it is a federated interface) but
/// has no implementation, so the gate is a RUNTIME platform check —
/// which is exactly what keeps all six targets building from one file
/// where a compile-time split could not tell desktop apart.
Widget? youtubeEmbed(String videoId) {
  if (!(Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
    return null;
  }
  return _YoutubeEmbed(videoId: videoId);
}

class _YoutubeEmbed extends StatefulWidget {
  const _YoutubeEmbed({required this.videoId});

  final String videoId;

  @override
  State<_YoutubeEmbed> createState() => _YoutubeEmbedState();
}

class _YoutubeEmbedState extends State<_YoutubeEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(_embedUrl(widget.videoId)));
  }

  /// Same host and flags as the web iframe (`youtube_embed_web.dart`),
  /// plus two that only matter inside a native webview:
  ///
  /// * `playsinline=1` — without it iOS hands the video to the
  ///   system's fullscreen player the moment it starts, which is the
  ///   jump-out this exists to remove, just one layer down.
  /// * `autoplay=1` — the widget only mounts after the user tapped the
  ///   thumbnail (see `_player` in videos_page.dart), so starting
  ///   immediately is honouring that tap, not autoplaying on arrival.
  ///   Without it the user taps the thumbnail and then must tap the
  ///   iframe's own play button — the same video needing two plays.
  static String _embedUrl(String id) =>
      'https://www.youtube-nocookie.com/embed/$id'
      '?rel=0&playsinline=1&autoplay=1';

  @override
  Widget build(BuildContext context) =>
      WebViewWidget(controller: _controller);
}
