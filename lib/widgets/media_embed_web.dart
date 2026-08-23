import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Any embeddable third-party media, as a real `<iframe>` in the page.
///
/// 2026-08-24: the YouTube-only embed grew a sibling because the user
/// asked for the same treatment beyond YouTube — "另外soundcloud也是一样
/// 的概念…其他如果有的话也是一样一并做了". Rather than one file per
/// provider, this takes a finished embed URL and the provider decision
/// lives in [embeddableMedia].
///
/// `youtube_embed_web.dart` stays as it is: the videos page builds its
/// own nocookie URL and carries flags this generic view should not
/// assume for every provider.
Widget? mediaEmbed(String embedUrl) => _MediaEmbed(embedUrl: embedUrl);

class _MediaEmbed extends StatefulWidget {
  const _MediaEmbed({required this.embedUrl});

  final String embedUrl;

  @override
  State<_MediaEmbed> createState() => _MediaEmbedState();
}

class _MediaEmbedState extends State<_MediaEmbed> {
  /// A fresh view type per mount.
  ///
  /// It used to be keyed on the URL's hashCode, which meant reopening
  /// the same track reused the registered factory — and a factory is
  /// registered once but INVOKED per view, so that was survivable. The
  /// real reason to make it unique is teardown: it lets this State own
  /// exactly one element and blank it on dispose, instead of sharing an
  /// element with a view that may still be alive.
  late final String _viewType =
      'media-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  web.HTMLIFrameElement? _frame;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final frame = web.document.createElement('iframe')
          as web.HTMLIFrameElement
        ..src = widget.embedUrl
        // Same delegations the YouTube iframe needs, and for the same
        // reasons: without `autoplay` in the allow list the browser
        // refuses the autoplay in the URL, and a cross-origin frame
        // cannot reach the clipboard unless the embedder says so.
        ..allow = 'accelerometer; autoplay; encrypted-media; '
            'picture-in-picture; fullscreen; clipboard-write'
        ..allowFullscreen = true;
      frame.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%';
      _frame = frame;
      return frame;
    });
  }

  @override
  void dispose() {
    // Closing the window MUST stop the sound. 2026-08-24, from the
    // phone: "为什么关掉那个windows并没有音乐停 soundcloud".
    //
    // Flutter removes the element when the platform view goes, but the
    // ordering is not ours to rely on and a detached iframe can keep
    // playing until it is collected. Pointing it at about:blank ends
    // the document, and the audio ends with it — the same teardown the
    // io variant does through its controller.
    _frame?.src = 'about:blank';
    _frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
