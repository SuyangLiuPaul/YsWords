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
        // playsinline + autoplay: 2026-08-24, "好像WhatsApp那样YouTube
        // 对话框在播放音乐" — the embed only ever mounts after a tap (the
        // videos page's poster, or the link that opened the player
        // sheet), so starting immediately is honouring that tap rather
        // than ambushing anyone, and iOS Safari needs playsinline or it
        // hands the video to the system fullscreen player, which is the
        // jump-out this whole path exists to remove. The io variant has
        // said the same since 2026-08-23; these two are meant to mirror
        // each other.
        ..src = 'https://www.youtube-nocookie.com/embed/$videoId'
            '?rel=0&playsinline=1&autoplay=1'
        // clipboard-write: 2026-08-23, the player's own "copy link"
        // showed "Unable to copy link to clipboard" — a cross-origin
        // iframe cannot touch the clipboard unless the embedding page
        // delegates that permission explicitly. autoplay is delegated
        // for the same reason: without it in the allow list the browser
        // refuses the autoplay above and shows the poster instead —
        // which is exactly today's behaviour, so the worst case here is
        // no worse than before.
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
