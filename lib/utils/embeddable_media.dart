import 'package:yswords/utils/youtube_url.dart';

/// What a third-party media link looks like when it can be played
/// inside the app, and how tall its player wants to be.
class EmbeddableMedia {
  const EmbeddableMedia({
    required this.embedUrl,
    required this.frameHeight,
    required this.provider,
  });

  /// The URL to put in the frame — already the provider's PLAYER URL,
  /// not the page a human would visit.
  final String embedUrl;

  /// How tall the frame wants to be at [width].
  ///
  /// Not an aspect ratio: video scales with width, but SoundCloud's
  /// compact widget has a FIXED minimum — 166 px, below which its own
  /// play button and scrubber are clipped. 2026-08-24, from the phone:
  /// "那个播放键在手机上都按不了". The window was ~107 px tall, so the
  /// controls were simply not on screen; nothing was wrong with the
  /// touch handling.
  final double Function(double width) frameHeight;

  /// 'youtube' | 'soundcloud'. Shown on the window's title bar so the
  /// user can tell what is playing without reading the frame.
  final String provider;
}

/// The player for [url], or null when there is nothing to embed.
///
/// 2026-08-24, the user, after the YouTube player landed in Songs:
/// "另外soundcloud也是一样的概念" and "其他如果有的话也是一样一并做了".
/// So this is the one place that decides what counts as embeddable, and
/// every surface asks it rather than testing for providers itself.
///
/// Deliberately NOT here: the `fydt.org` mp4s (they already have a
/// real in-app page, [SongVideoPage], which is better than a frame) and
/// the 580 sheet-music PDFs (a PDF in a small floating window is not a
/// reading experience; those want a page too).
EmbeddableMedia? embeddableMedia(String url) {
  final videoId = youtubeVideoId(url);
  if (videoId != null) {
    return EmbeddableMedia(
      // nocookie + the same flags the videos page uses: the frame only
      // ever mounts after a tap, so autoplay honours that tap, and
      // playsinline keeps iOS from grabbing the video into its own
      // fullscreen player.
      embedUrl: 'https://www.youtube-nocookie.com/embed/$videoId'
          '?rel=0&playsinline=1&autoplay=1',
      frameHeight: (w) => w * 9 / 16,
      provider: 'youtube',
    );
  }

  // The catalogue already stores SoundCloud as its PLAYER url
  // (`w.soundcloud.com/player/?url=...`), so a track needs no rewriting
  // — see Song.soundcloudUrl. Accept the api.soundcloud.com form too,
  // in case a future row carries the bare track URL.
  final u = Uri.tryParse(url);
  if (u != null) {
    final host = u.host.toLowerCase();
    if (host == 'w.soundcloud.com' && u.path.startsWith('/player')) {
      return EmbeddableMedia(
        embedUrl: _soundcloudCompact(url),
        frameHeight: (_) => _kSoundcloudHeight,
        provider: 'soundcloud',
      );
    }
    if (host == 'api.soundcloud.com' || host == 'soundcloud.com') {
      return EmbeddableMedia(
        embedUrl: _soundcloudCompact(
            'https://w.soundcloud.com/player/?url='
            '${Uri.encodeComponent(url)}'),
        frameHeight: (_) => _kSoundcloudHeight,
        provider: 'soundcloud',
      );
    }
  }
  return null;
}

/// SoundCloud's compact widget height. Their own documented minimum:
/// below it the play button and scrubber are clipped.
const double _kSoundcloudHeight = 170;

/// Ask SoundCloud for the COMPACT player rather than its default.
///
/// 2026-08-24, from the phone: the window showed SoundCloud's site
/// furniture — the logo, "Sign in", "Listen in app", a row of Home /
/// Feed / Search / Library / Download — and no usable transport. That
/// is the `visual=true` player, which SoundCloud serves by default: a
/// full-bleed artwork unit sized for a page, not a strip. `visual=false`
/// is the 166 px bar with a play button and a scrubber, which is what a
/// small floating window can actually show.
///
/// The rest trim what a hymn listener has no use for and what would not
/// fit anyway: related tracks, comments, the uploader header, reposts,
/// buy and download links.
String _soundcloudCompact(String playerUrl) {
  final u = Uri.parse(playerUrl);
  return u.replace(queryParameters: {
    ...u.queryParameters,
    'visual': 'false',
    'hide_related': 'true',
    'show_comments': 'false',
    'show_user': 'false',
    'show_reposts': 'false',
    'show_teaser': 'false',
    'buying': 'false',
    'download': 'false',
    'sharing': 'false',
    // NOT auto_play: mobile browsers refuse to start audio without a
    // gesture inside the frame, and asking anyway is what produces
    // SoundCloud's "Play on SoundCloud" interstitial over the player.
    // Letting the user press the widget's own button is the path that
    // actually plays.
  }).toString();
}
