import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// The YouTube player, embedded as a real `<iframe>` in the page.
///
/// No package needed: Flutter web can hand a DOM element to the
/// compositor directly, and YouTube's own iframe brings its player,
/// its captions and its fullscreen with it. Adding a plugin here would
/// buy an API we do not use and cost two of the six targets.
///
/// `enablejsapi` is on so a later change can ask the player for its
/// position before a language switch — the position-preserving switch
/// the self-hosted player had is worth carrying over, and this is the
/// hook it will need.
Widget? youtubeEmbed(String videoId) {
  final viewType = 'youtube-$videoId';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final frame = web.document.createElement('iframe')
          as web.HTMLIFrameElement
        ..src = 'https://www.youtube-nocookie.com/embed/$videoId?rel=0'
        // clipboard-write: 2026-08-23, the player's own "copy link"
        // showed "Unable to copy link to clipboard" — a cross-origin
        // iframe cannot touch the clipboard unless the embedding page
        // delegates that permission explicitly.
        ..allow = 'accelerometer; encrypted-media; picture-in-picture; '
            'fullscreen; clipboard-write'
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
