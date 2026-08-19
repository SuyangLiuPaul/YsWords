import 'package:flutter/widgets.dart';

/// No in-page embed off the web.
///
/// `youtube_player_iframe` and every webview-backed alternative cover
/// Android / iOS / macOS and stop there — this app ships to Windows and
/// Linux as well, and the repo has already chosen six-target packages
/// over better-on-three ones once (audioplayers over just_audio). So
/// the native builds link out to YouTube instead of embedding, which
/// works everywhere and claims nothing it cannot do.
Widget? youtubeEmbed(String videoId) => null;
