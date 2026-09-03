import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/youtube_embed_src.dart';

/// The position-preserving language switch.
///
/// The self-hosted player this page replaced kept your place when you
/// switched language; the YouTube embed re-armed the poster, so switching
/// 40 minutes into an hour-long teaching meant finding those 40 minutes
/// again by hand.
///
/// The queue item said `enablejsapi` was already on the iframe. It was
/// not — `youtube_embed_web.dart` said so in a comment while its `src`
/// string carried `rel=0&playsinline=1&autoplay=1` and nothing else, so
/// the player had never been asked a question and would not have answered
/// one. That is the class of mistake these tests exist for: the video
/// plays either way, and the flag's absence shows up only as a feature
/// that quietly does nothing.
void main() {
  group('the embed URL', () {
    test('without the API it is the URL that has always shipped', () {
      // Both platform variants build their URL here now. This exact
      // string is what the native wrapper embedded before the change,
      // and native still passes no API flag and no start second — so if
      // this test goes red, native playback changed.
      expect(
        youtubeEmbedSrc('abc123'),
        'https://www.youtube-nocookie.com/embed/abc123'
        '?rel=0&playsinline=1&autoplay=1',
      );
    });

    test('the API needs the flag AND the embedding origin', () {
      // A player given `enablejsapi` but no `origin` refuses the
      // handshake in most browsers, which fails the same way as no flag
      // at all: silently, with the video still playing.
      expect(
        youtubeEmbedSrc('abc123',
            enableJsApi: true, origin: 'https://yswords.netlify.app'),
        'https://www.youtube-nocookie.com/embed/abc123'
        '?rel=0&playsinline=1&autoplay=1&enablejsapi=1'
        '&origin=https%3A%2F%2Fyswords.netlify.app',
      );
    });

    test('a resume second becomes ?start=', () {
      expect(youtubeEmbedSrc('abc123', startSeconds: 2412),
          endsWith('&start=2412'));
    });

    test('zero adds nothing — the poster path must stay untouched', () {
      expect(youtubeEmbedSrc('abc123', startSeconds: 0), isNot(contains('start')));
      expect(youtubeEmbedSrc('abc123', startSeconds: -5), isNot(contains('start')));
    });

    test('it never points at youtube.com', () {
      // The whole embed exists on the nocookie host. A URL built here
      // that pointed at the tracking host would undo that quietly.
      expect(youtubeEmbedSrc('abc123', enableJsApi: true, origin: 'https://x'),
          startsWith('https://www.youtube-nocookie.com/'));
    });
  });

  group('the platform-view key', () {
    test('the start second is part of it', () {
      // `registerViewFactory` keeps the FIRST factory registered under a
      // name. Keyed on the video id alone, switching language away and
      // back would reuse the factory built for start=0 and drop the
      // reader at the beginning — the exact bug this item is about,
      // reintroduced one layer down.
      expect(youtubeEmbedViewType('abc123', 0), 'youtube-abc123-0');
      expect(youtubeEmbedViewType('abc123', 2412), 'youtube-abc123-2412');
      expect(youtubeEmbedViewType('abc123', 0),
          isNot(youtubeEmbedViewType('abc123', 2412)));
    });
  });

  group('the listening handshake', () {
    test('carries the video id, which is what comes back on every reply',
        () {
      expect(youtubeListeningMessage('abc123'),
          '{"event":"listening","id":"abc123","channel":"widget"}');
    });
  });

  group('reading a position off a player message', () {
    test('an infoDelivery frame yields its id and currentTime', () {
      final hit = youtubePositionFromMessage(
          '{"event":"infoDelivery","id":"abc123",'
          '"info":{"currentTime":2412.87,"duration":3600}}');
      expect(hit, isNotNull);
      expect(hit!.id, 'abc123');
      expect(hit.seconds, closeTo(2412.87, 0.001));
    });

    test('the frames that carry no time are ignored', () {
      expect(youtubePositionFromMessage('{"event":"onReady","id":"abc123"}'),
          isNull);
      expect(
          youtubePositionFromMessage(
              '{"event":"infoDelivery","id":"abc123","info":{"playerState":1}}'),
          isNull);
    });

    test('junk is ignored rather than thrown on', () {
      // A `message` listener is fed by every frame on the page, not just
      // ours. An exception here would surface as a red screen during a
      // sermon.
      expect(youtubePositionFromMessage('not json at all'), isNull);
      expect(youtubePositionFromMessage('{"currentTime":5}'), isNull);
      expect(youtubePositionFromMessage('[]'), isNull);
      expect(youtubePositionFromMessage('{"info":"currentTime"}'), isNull);
    });

    test('a nonsense currentTime is dropped, not clamped', () {
      // Sending the reader to second 0 of an hour-long teaching is a
      // visible failure; sending them somewhere arbitrary is worse.
      for (final bad in ['-30', 'null', '"12"', '1e999']) {
        expect(
          youtubePositionFromMessage(
              '{"event":"infoDelivery","id":"a","info":{"currentTime":$bad}}'),
          isNull,
          reason: 'currentTime: $bad',
        );
      }
    });
  });

  group('turning a position into a start second', () {
    test('it floors', () {
      // Landing a shade early repeats a syllable; landing a shade late
      // eats one, and the reader switched language to hear it again.
      expect(youtubeResumeSeconds(2412.87), 2412);
      expect(youtubeResumeSeconds(0.9), 0);
    });

    test('nothing known means start from the top', () {
      expect(youtubeResumeSeconds(null), 0);
      expect(youtubeResumeSeconds(-4), 0);
      expect(youtubeResumeSeconds(double.nan), 0);
      expect(youtubeResumeSeconds(double.infinity), 0);
    });
  });

  group('the wiring the browser would otherwise have to prove', () {
    // These three live in files that import `dart:ui_web` / `dart:io` and
    // cannot be loaded by the VM test runner, so they are read as source.
    // Each one is a silent failure if it regresses.
    test('the web iframe actually asks for the API', () {
      final src =
          File('lib/widgets/youtube_embed_web.dart').readAsStringSync();
      expect(src, contains('enableJsApi: true'));
      expect(src, contains('origin: web.window.location.origin'));
      expect(src, contains('startSeconds: startSeconds'));
      // The bug this item started from: the comment claimed the flag was
      // on while the URL was hand-built without it.
      expect(RegExp(r"\.\.src = '").hasMatch(src), isFalse,
          reason: 'the src must come from youtubeEmbedSrc, not a second '
              'hand-written copy of it');
    });

    test('only origins belonging to the player are believed', () {
      final src =
          File('lib/widgets/youtube_embed_web.dart').readAsStringSync();
      expect(src, contains('kYoutubeMessageOrigins.contains(event.origin)'));
      expect(kYoutubeMessageOrigins, contains(kYoutubeEmbedHost));
      expect(kYoutubeMessageOrigins.every((o) => o.startsWith('https://')),
          isTrue);
    });

    test('the language switch asks before it unmounts', () {
      final src = File('lib/pages/videos_page.dart').readAsStringSync();
      // The read has to happen outside setState: setState tears the
      // iframe down in the same frame.
      final onSelected = src.indexOf('onSelected: (_) {');
      final read = src.indexOf('youtubeEmbedPositionSeconds(', onSelected);
      final setState = src.indexOf('setState(() {', onSelected);
      expect(read, greaterThan(0));
      expect(read, lessThan(setState),
          reason: 'the player must be asked before its iframe is gone');
      // And a fresh play must not inherit a stale position.
      expect(src, contains('_resumeAt = 0;'));
      expect(src, contains('startSeconds: _resumeAt'));
    });
  });
}
