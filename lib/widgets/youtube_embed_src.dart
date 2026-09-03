/// The parts of the YouTube embed that are just strings.
///
/// `youtube_embed_web.dart` imports `dart:ui_web` and `package:web`, and
/// `youtube_embed_io.dart` imports `dart:io` and `webview_flutter`, so
/// neither can be reached from a `flutter test` run. Everything here is
/// plain Dart on purpose: the embed URL and the `postMessage` protocol
/// are exactly the parts where a typo is silent — a dropped `enablejsapi`
/// still plays the video, it just never answers the question we are
/// asking it — so they live where they can be pinned.
library;

import 'dart:convert';

/// The privacy-enhanced host. Nothing here ever points at youtube.com.
const String kYoutubeEmbedHost = 'https://www.youtube-nocookie.com';

/// Origins a player message may legitimately arrive from. The embed is
/// served from the nocookie host, but the player's own scripts have
/// posted from `www.youtube.com` at times, so both are accepted — and
/// nothing else is, because these messages set playback state we act on.
const List<String> kYoutubeMessageOrigins = <String>[
  'https://www.youtube-nocookie.com',
  'https://www.youtube.com',
];

/// The embed URL.
///
/// `rel=0`, `playsinline=1` and `autoplay=1` are the pre-existing three —
/// see the notes in `youtube_embed_web.dart` for why each is there. The
/// two new ones:
///
///  * `enablejsapi=1` (+ `origin`) turns on the postMessage API, which is
///    the only way to ask a cross-origin player where it is. The comment
///    in `youtube_embed_web.dart` claimed this was already on since
///    2026-08; it was not — the flag never made it into the src string,
///    which is why the language switch had nothing to ask.
///  * `start` resumes at a whole second. YouTube ignores `start` unless
///    playback actually begins, which is why it is paired with the
///    autoplay that was already there.
String youtubeEmbedSrc(
  String videoId, {
  int startSeconds = 0,
  bool enableJsApi = false,
  String? origin,
}) {
  final buf = StringBuffer('$kYoutubeEmbedHost/embed/$videoId'
      '?rel=0&playsinline=1&autoplay=1');
  if (enableJsApi) {
    buf.write('&enablejsapi=1');
    // Without a matching `origin` the player refuses the API handshake
    // in most browsers, so an embed asking for the API must say where it
    // is embedded.
    if (origin != null && origin.isNotEmpty) {
      buf.write('&origin=${Uri.encodeComponent(origin)}');
    }
  }
  if (startSeconds > 0) buf.write('&start=$startSeconds');
  return buf.toString();
}

/// The platform-view key for one embed.
///
/// The start second is part of the key deliberately. `registerViewFactory`
/// keeps the FIRST factory registered under a name, so if the key were
/// the video id alone, a second mount of the same video — which is
/// precisely what resuming after a language switch is not, but what
/// switching back and forth becomes — would silently reuse the factory
/// built for `start=0` and drop the reader back at the beginning.
String youtubeEmbedViewType(String videoId, int startSeconds) =>
    'youtube-$videoId-$startSeconds';

/// The handshake that makes a player start reporting.
///
/// An `enablejsapi` player says nothing until the embedding page posts
/// `listening` at it; after that it posts `infoDelivery` frames carrying
/// `currentTime` for as long as it is playing. `id` is echoed back in
/// every reply, which is how a page with more than one player tells them
/// apart — so the video id is used as the id.
String youtubeListeningMessage(String videoId) => jsonEncode(<String, Object>{
      'event': 'listening',
      'id': videoId,
      'channel': 'widget',
    });

/// One player position read off a `postMessage` payload, or null when the
/// payload is not one.
///
/// Deliberately liberal about the frame and strict about the number: the
/// player posts several event shapes and more of them than not carry no
/// time at all, but a bad `currentTime` would send the reader to the
/// wrong place in the sermon, so anything non-finite or negative is
/// dropped rather than clamped.
({String? id, double seconds})? youtubePositionFromMessage(String raw) {
  if (!raw.contains('currentTime')) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  final info = decoded['info'];
  if (info is! Map) return null;
  final time = info['currentTime'];
  if (time is! num || !time.isFinite || time < 0) return null;
  final id = decoded['id'];
  return (id: id?.toString(), seconds: time.toDouble());
}

/// What to hand back as `start=` for a position of [seconds].
///
/// Floors rather than rounds: landing a shade early repeats a syllable,
/// landing a shade late eats one, and the reader switched language
/// because they wanted to hear it again.
int youtubeResumeSeconds(double? seconds) {
  if (seconds == null || !seconds.isFinite || seconds <= 0) return 0;
  return seconds.floor();
}
