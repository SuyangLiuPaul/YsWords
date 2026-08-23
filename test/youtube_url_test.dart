import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/youtube_url.dart';

/// 2026-08-24: "歌曲里面有几个是YouTube如果按了去YouTube了，但是web 和ios
/// 能不能不跳转出去，好像WhatsApp那样YouTube对话框在播放音乐，其实整个app
/// 都要这样".
///
/// The in-app player takes an id, so this function decides — for every
/// link in the app — whether the user stays or leaves. Both directions
/// are worth pinning down: a shape it fails to recognise is a link that
/// silently keeps the old jump-out, and a shape it recognises wrongly is
/// a player mounted on a video that does not exist.
void main() {
  const id = 'dQw4w9WgXcQ';

  group('recognises every shape the app can hold', () {
    test('youtu.be short link', () {
      expect(youtubeVideoId('https://youtu.be/$id'), id);
    });

    test('watch?v=', () {
      expect(youtubeVideoId('https://www.youtube.com/watch?v=$id'), id);
    });

    test('/embed/ — including our own nocookie player URL', () {
      expect(youtubeVideoId('https://www.youtube.com/embed/$id'), id);
      expect(
        youtubeVideoId('https://www.youtube-nocookie.com/embed/$id?rel=0'),
        id,
      );
    });

    test('/shorts/, /live/ and the legacy /v/', () {
      expect(youtubeVideoId('https://www.youtube.com/shorts/$id'), id);
      expect(youtubeVideoId('https://www.youtube.com/live/$id'), id);
      expect(youtubeVideoId('https://www.youtube.com/v/$id'), id);
    });

    test('extra query params do not hide the id', () {
      // The three that actually turn up: a start time, the share token
      // YouTube appends on mobile, and a playlist context.
      expect(youtubeVideoId('https://youtu.be/$id?t=42&si=AbCdEfGh'), id);
      expect(
        youtubeVideoId('https://www.youtube.com/watch?v=$id&list=PL123&t=90'),
        id,
      );
      // Order does not matter either — `v` is read by name, not position.
      expect(youtubeVideoId('https://www.youtube.com/watch?t=90&v=$id'), id);
    });

    test('the host variants', () {
      expect(youtubeVideoId('https://m.youtube.com/watch?v=$id'), id);
      expect(youtubeVideoId('https://music.youtube.com/watch?v=$id'), id);
      expect(youtubeVideoId('https://youtube.com/watch?v=$id'), id);
      expect(youtubeVideoId('http://www.youtube.com/watch?v=$id'), id);
      // Hosts are case-insensitive in the wild; ids are not.
      expect(youtubeVideoId('https://WWW.YouTube.COM/watch?v=$id'), id);
    });

    test('a scheme-less paste still resolves', () {
      // Parses as a bare path with no host, which would otherwise read
      // as "not YouTube" — and the opener has to add a scheme anyway.
      expect(youtubeVideoId('youtu.be/$id'), id);
      expect(youtubeVideoId('www.youtube.com/watch?v=$id'), id);
    });

    test('surrounding whitespace is not the user\'s fault', () {
      expect(youtubeVideoId('  https://youtu.be/$id\n'), id);
    });

    test('ids using the full URL-safe alphabet survive', () {
      expect(youtubeVideoId('https://youtu.be/-_aA09zZ8x1'), '-_aA09zZ8x1');
    });
  });

  group('returns null — the caller must open these the old way', () {
    test('the other places this app links to', () {
      expect(
        youtubeVideoId('https://w.soundcloud.com/player/?url=https%3A//x/1'),
        isNull,
      );
      expect(youtubeVideoId('https://www.cdchurch.org/songs/1'), isNull);
      expect(youtubeVideoId('mailto:someone@youtube.com'), isNull);
      expect(youtubeVideoId('https://example.org/watch?v=$id'), isNull);
    });

    test('a look-alike host is not YouTube', () {
      // The check is the whole host, not a substring: "youtube.com" as a
      // suffix or a subdomain of someone else's domain is somebody
      // else's server, and embedding it would be worse than a wrong
      // link.
      expect(youtubeVideoId('https://notyoutube.com/watch?v=$id'), isNull);
      expect(youtubeVideoId('https://youtube.com.evil.tld/watch?v=$id'),
          isNull);
    });

    test('YouTube pages that are not a single video', () {
      expect(
        youtubeVideoId('https://www.youtube.com/playlist?list=PL123'),
        isNull,
      );
      expect(
        youtubeVideoId('https://www.youtube.com/embed/videoseries?list=PL1'),
        isNull,
      );
      expect(youtubeVideoId('https://www.youtube.com/@somechannel'), isNull);
      expect(youtubeVideoId('https://www.youtube.com/'), isNull);
    });

    test('an id of the wrong length or alphabet', () {
      // Truncated, over-long, or carrying a character the id alphabet
      // has no room for. Each one would mount a player showing
      // YouTube's error card; a browser tab is the better failure.
      expect(youtubeVideoId('https://youtu.be/short'), isNull);
      expect(youtubeVideoId('https://youtu.be/waaaaaaaytoolongforanid'),
          isNull);
      expect(youtubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXc'),
          isNull);
      expect(youtubeVideoId('https://www.youtube.com/watch?v=dQw4.9WgXcQ'),
          isNull);
    });

    test('watch with no v at all', () {
      expect(youtubeVideoId('https://www.youtube.com/watch'), isNull);
      expect(youtubeVideoId('https://www.youtube.com/watch?v='), isNull);
      expect(youtubeVideoId('https://youtu.be/'), isNull);
    });

    test('empty and blank input', () {
      expect(youtubeVideoId(''), isNull);
      expect(youtubeVideoId('   '), isNull);
    });

    test('a malformed percent-escape answers null instead of throwing', () {
      // `Uri.pathSegments` and `Uri.queryParameters` decode, and decoding
      // an impossible escape throws FormatException. This function sits
      // in front of every link tap in the app now, so throwing here would
      // promote a bad URL to a crash.
      expect(youtubeVideoId('https://www.youtube.com/watch?v=%FF%FE'), isNull);
      expect(youtubeVideoId('https://www.youtube.com/watch?v=%E0%A4%A'),
          isNull);
      expect(youtubeVideoId('https://youtu.be/%E0%A4%A/x'), isNull);
    });
  });
}
