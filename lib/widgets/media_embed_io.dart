import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Any embeddable third-party media, in a webview.
///
/// Gated at RUNTIME to the three platforms with a webview implementation.
/// `webview_flutter` is a federated interface, so Windows and Linux
/// compile this file happily and simply have nothing behind it — a
/// compile-time split could not tell desktop apart, and this is what
/// keeps all six targets building from one source.
Widget? mediaEmbed(String embedUrl) {
  if (!(Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
    return null;
  }
  return _MediaEmbed(embedUrl: embedUrl);
}

/// Whether this platform's webview actually implements
/// `WebViewController.setBackgroundColor`.
///
/// macOS does not. `webview_flutter_wkwebview` routes setBackgroundColor
/// through `PlatformWebView.setOpaque`, and the macOS half of that plugin
/// leaves setOpaque unimplemented — so calling it throws
/// `UnimplementedError: opaque is not implemented on macOS` rather than
/// degrading. Reported from a real macOS 26.5.2 install on 1.4.169.
///
/// Takes the OS name instead of reading `Platform` directly so the rule
/// can be tested on any host. The alternative — asserting on the source
/// text of the call site — pins the spelling of a fix rather than the
/// behaviour it encodes.
@visibleForTesting
bool webviewSupportsBackgroundColor(String operatingSystem) =>
    operatingSystem != 'macos';

class _MediaEmbed extends StatefulWidget {
  const _MediaEmbed({required this.embedUrl});

  final String embedUrl;

  @override
  State<_MediaEmbed> createState() => _MediaEmbedState();
}

class _MediaEmbedState extends State<_MediaEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // WebKit needs both declared AT CREATION or inline playback quietly
    // degrades: without allowsInlineMediaPlayback iOS hands the video to
    // the system fullscreen player the moment it starts — the jump-out
    // this whole path exists to remove, one layer down — and without an
    // empty mediaTypesRequiringUserAction the autoplay that honours the
    // tap is ignored, so the same track needs two taps.
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
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    // setBackgroundColor THROWS on macOS. Reported from a real macOS
    // 26.5.2 install running 1.4.169, 2026-08-27:
    //
    //   UnimplementedError: opaque is not implemented on macOS
    //     PlatformWebView.setOpaque
    //     WebKitWebViewController.setBackgroundColor
    //     _MediaEmbedState.initState
    //
    // webview_flutter_wkwebview implements setBackgroundColor by way of
    // setOpaque, and its macOS half does not implement setOpaque at all —
    // so this threw during initState for every embed on the Songs page.
    // The platform gate above deliberately admits macOS (it has a real
    // webview); what it could not know is that one method of that
    // webview is iOS-only.
    //
    // Skipping it costs nothing to look at: _wrapper() already paints
    // `background:#000` on html and body, so the black is the page's,
    // not the widget's. The call is kept on iOS/Android because there it
    // suppresses the white flash BEFORE that HTML has loaded.
    if (webviewSupportsBackgroundColor(Platform.operatingSystem)) {
      _controller.setBackgroundColor(const Color(0xFF000000));
    }

    // Wrapped in a page rather than navigated to directly, and with a
    // baseUrl naming an origin we control. A bare navigation to an
    // embed URL has no embedding page and sends no Referer, which is
    // what made every YouTube video answer "Error 153" on 2026-08-23.
    _controller.loadHtmlString(_wrapper(widget.embedUrl),
        baseUrl: 'https://yswords-qat.netlify.app');
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  static String _wrapper(String src) => '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;height:100%;background:#000}
iframe{border:0;width:100%;height:100%}</style></head><body>
<iframe src="$src"
 allow="accelerometer; autoplay; encrypted-media; picture-in-picture; fullscreen; clipboard-write"
 allowfullscreen></iframe></body></html>''';

  @override
  void dispose() {
    // Closing the window MUST stop the sound.
    //
    // 2026-08-24, from the phone: "为什么关掉那个windows并没有音乐停
    // soundcloud". Removing the widget disposes this State, but a
    // WebViewController is not torn down with it — the platform keeps
    // the WKWebView (or the Android WebView) and its page alive, and a
    // page that is playing audio goes on playing it with nothing left
    // on screen to stop it. There is no pause API to call either: the
    // frame owns its own transport, which is the same asymmetry the
    // MediaFocus claim documents.
    //
    // Navigating to a blank page is the teardown that exists: it
    // unloads the document, and the media goes with it. `about:blank`
    // rather than clearing the cache — the point is to end THIS page,
    // not to forget every page.
    _controller.loadRequest(Uri.parse('about:blank')).catchError((_) {
      // The view may already be gone; nothing left to silence.
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      WebViewWidget(controller: _controller);
}
