import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'package:yswords/widgets/youtube_embed_src.dart';

/// The YouTube player, embedded as a real `<iframe>` in the page.
///
/// No package needed: Flutter web can hand a DOM element to the
/// compositor directly, and YouTube's own iframe brings its player,
/// its captions and its fullscreen with it. Adding a plugin here would
/// buy an API we do not use and cost two of the six targets.
///
/// `enablejsapi` is on so the page can ask the player for its position
/// before a language switch — the position-preserving switch the
/// self-hosted player had, carried over. See
/// [youtubeEmbedPositionSeconds].
Widget? youtubeEmbed(String videoId, {int startSeconds = 0}) {
  _installMessageListener();
  final viewType = youtubeEmbedViewType(videoId, startSeconds);
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
        // each other, and now share `youtubeEmbedSrc` so they cannot
        // drift apart quietly.
        ..src = youtubeEmbedSrc(
          videoId,
          startSeconds: startSeconds,
          enableJsApi: true,
          origin: web.window.location.origin,
        )
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
      _armPositionReporting(frame, videoId);
      return frame;
    });
  }
  return HtmlElementView(viewType: viewType);
}

/// Where the player for [videoId] last said it was, in whole seconds, or
/// null if it never said.
///
/// Read at the moment of a language switch, while the old iframe is
/// still on screen — the answer is a cached one, but it is cached from a
/// player that is still running, and a synchronous read is what the call
/// site needs: `setState` tears the iframe down in the same frame, and
/// there is no awaiting a window that is about to stop existing.
int? youtubeEmbedPositionSeconds(String videoId) => _positions[videoId];

final Set<String> _registered = <String>{};

/// videoId → last reported whole second. Survives the iframe it came
/// from, on purpose: that is the only reason there is anything to hand
/// back after the switch.
final Map<String, int> _positions = <String, int>{};

bool _listening = false;

void _installMessageListener() {
  if (_listening) return;
  _listening = true;
  web.window.addEventListener(
    'message',
    ((web.MessageEvent event) {
      // These messages drive where the reader lands in an hour-long
      // teaching, so anything not from the player's own origin is
      // ignored outright rather than parsed and then judged.
      if (!kYoutubeMessageOrigins.contains(event.origin)) return;
      // `dartify` rather than `isA<JSString>()`: the latter needs Dart
      // 3.4 and this package's SDK floor is 3.2.3. The player's frames
      // arrive as JSON strings; anything else converts to something that
      // is not a String and is dropped on the next line.
      final data = event.data?.dartify();
      if (data is! String) return;
      final hit = youtubePositionFromMessage(data);
      if (hit == null) return;
      final id = hit.id;
      if (id == null || id.isEmpty) return;
      _positions[id] = youtubeResumeSeconds(hit.seconds);
    }).toJS,
  );
}

/// Ask this player to start reporting its position.
///
/// An `enablejsapi` player answers nothing until it is spoken to, and it
/// cannot be spoken to until its own scripts are up — which is after the
/// iframe's `load` on a cold connection and, on a slow one, a good while
/// after. So the handshake goes out on load and then a few more times;
/// a `listening` message the player has already accepted is a no-op, and
/// the alternative is a switch that silently starts from zero.
void _armPositionReporting(web.HTMLIFrameElement frame, String videoId) {
  final payload = youtubeListeningMessage(videoId);
  void poke() {
    frame.contentWindow?.postMessage(payload.toJS, kYoutubeEmbedHost.toJS);
  }

  frame.onload = ((web.Event _) => poke()).toJS;
  var tries = 0;
  Timer.periodic(const Duration(milliseconds: 500), (timer) {
    poke();
    if (++tries >= 10 || !frame.isConnected) timer.cancel();
  });
}
