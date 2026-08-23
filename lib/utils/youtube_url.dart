// Recovering the video id from any YouTube address the app can hold.
//
// 2026-08-24, the user, about the songs list: "歌曲里面有几个是YouTube
// 如果按了去YouTube了，但是web 和ios能不能不跳转出去，好像WhatsApp那样
// YouTube对话框在播放音乐，其实整个app都要这样". A YouTube link must open
// a player INSIDE the app — and not only in Songs, everywhere.
//
// The player takes an id; the app holds addresses. `Song.youtubeUrl`
// and `VideoTrack.watchUrl` build `watch?v=` strings out of ids we
// already have, but the addresses that actually reach [LinkOpener] also
// come from scraped catalogue rows and hand-written links, so the id has
// to be read back out of the URL rather than assumed.
//
// Deliberately a plain function in `utils/` with no Flutter import: the
// routing decision in `link_opener.dart` is then one call instead of a
// regex that would have to be got right at every call site, and the URL
// shapes can be tested without a widget binding.

/// Every YouTube video id is exactly 11 characters of the URL-safe
/// base64 alphabet — the same shape `video_series_test.dart` already
/// holds the bundled ids to. Matching it exactly is the point rather
/// than an accident: `/playlist`, a channel handle and a truncated
/// paste all fail it, and failing means the link opens in the browser
/// the way it always did instead of mounting a player that would only
/// show YouTube's own error card.
final RegExp _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Hosts that serve the watch page and the iframe player.
const Set<String> _watchHosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtube-nocookie.com',
  'www.youtube-nocookie.com',
};

/// The link-shortener host, where the whole path is the id.
const Set<String> _shortHosts = {'youtu.be', 'www.youtu.be'};

/// Path prefixes that carry the id in the NEXT segment.
const Set<String> _idInSecondSegment = {'embed', 'shorts', 'live', 'v'};

/// `/embed/videoseries?list=…` is YouTube's playlist embed, and
/// "videoseries" happens to be exactly 11 characters of the id
/// alphabet — the one word that walks through the shape check while
/// naming no video at all. A set of one, because it is a collision
/// rather than a rule.
const Set<String> _reserved = {'videoseries'};

/// The video id inside [url], or null when [url] is not a YouTube video.
///
/// Handles every shape this app can hold, with any extra query string
/// (`?t=`, `&list=`, the `?si=` share tokens YouTube now appends):
///
///   * `https://youtu.be/ID`
///   * `https://www.youtube.com/watch?v=ID`
///   * `https://www.youtube.com/embed/ID` (and the nocookie host our own
///     embeds use, so a URL this app generated round-trips)
///   * `https://www.youtube.com/shorts/ID`, `/live/ID`, `/v/ID`
///
/// Returns null for anything else — SoundCloud, the church's own site,
/// `mailto:`, a playlist, an empty string. **Null means "not ours", and
/// every caller must treat it as "open this the way you used to".**
String? youtubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  var uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (!uri.hasScheme && uri.host.isEmpty) {
    // "youtu.be/ID" pasted without a scheme parses as a bare path with
    // no host at all. Re-read it as https rather than miss it; the
    // opener would have had to add a scheme anyway.
    uri = Uri.tryParse('https://$trimmed');
    if (uri == null) return null;
  }

  final host = uri.host.toLowerCase();
  if (!_shortHosts.contains(host) && !_watchHosts.contains(host)) return null;

  // `pathSegments` and `queryParameters` percent-DECODE, and decoding
  // throws on a malformed escape ("…?v=%FF%FE" → FormatException). This
  // function now stands in front of every link tap in the app, so an
  // escaping exception here would turn a bad URL into a crash — where
  // before it was merely a link the browser would complain about.
  // Swallowing it lands on null, which is the same answer as "not a
  // YouTube video": open it the old way and let the browser say so.
  try {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (_shortHosts.contains(host)) {
      return segments.isEmpty ? null : _asVideoId(segments.first);
    }

    if (segments.isNotEmpty) {
      final first = segments.first.toLowerCase();
      if (first == 'watch') return _asVideoId(uri.queryParameters['v']);
      if (segments.length > 1 && _idInSecondSegment.contains(first)) {
        return _asVideoId(segments[1]);
      }
    }
    // `youtube.com/?v=ID` — rare, but it is a valid watch address and
    // costs one line to honour.
    return _asVideoId(uri.queryParameters['v']);
  } on FormatException {
    return null;
  }
}

String? _asVideoId(String? candidate) =>
    candidate != null &&
            _videoId.hasMatch(candidate) &&
            !_reserved.contains(candidate)
        ? candidate
        : null;
