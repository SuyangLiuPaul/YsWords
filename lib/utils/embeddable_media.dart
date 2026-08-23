import 'package:yswords/utils/youtube_url.dart';

/// What a third-party media link looks like when it can be played
/// inside the app, and how tall its player wants to be.
class EmbeddableMedia {
  const EmbeddableMedia({
    required this.embedUrl,
    required this.aspectRatio,
    required this.provider,
  });

  /// The URL to put in the frame — already the provider's PLAYER URL,
  /// not the page a human would visit.
  final String embedUrl;

  /// Video is 16:9. Audio players are short and wide, and giving one a
  /// video's height would show a strip of player over a lot of nothing.
  final double aspectRatio;

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
      aspectRatio: 16 / 9,
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
        embedUrl: url,
        // SoundCloud's own recommended height for the compact player is
        // 166 px; at the widths this window uses that lands near 3:1.
        aspectRatio: 3,
        provider: 'soundcloud',
      );
    }
    if (host == 'api.soundcloud.com' || host == 'soundcloud.com') {
      return EmbeddableMedia(
        embedUrl: 'https://w.soundcloud.com/player/?url='
            '${Uri.encodeComponent(url)}',
        aspectRatio: 3,
        provider: 'soundcloud',
      );
    }
  }
  return null;
}
