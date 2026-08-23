import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Any embeddable third-party media, as a real `<iframe>` in the page.
///
/// 2026-08-24: the YouTube-only embed grew a sibling because the user
/// asked for the same treatment beyond YouTube — "另外soundcloud也是一样
/// 的概念…其他如果有的话也是一样一并做了". Rather than one file per
/// provider, this takes a finished embed URL and the provider decision
/// lives in [embeddableMediaUrl].
///
/// `youtube_embed_web.dart` stays as it is: the videos page builds its
/// own nocookie URL and carries flags this generic view should not
/// assume for every provider.
Widget? mediaEmbed(String embedUrl) {
  final viewType = 'media-${embedUrl.hashCode}';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final frame = web.document.createElement('iframe')
          as web.HTMLIFrameElement
        ..src = embedUrl
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
      return frame;
    });
  }
  return HtmlElementView(viewType: viewType);
}

final Set<String> _registered = <String>{};
