import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/utils/route_paths.dart';

/// The shareable song link, added 2026-09-07.
///
/// The user asked for it off the player: "我要分享歌曲的话能不能有share
/// 直接就是这个网页界面呢". It could not be done because the player and
/// the song sheet are SCREENS, not pages — the address bar stays on
/// whatever route you came from, so there was nothing to copy.
///
/// The fix is a query on the already-registered `/songs`, and the choice
/// of a query over a `/songs/:songId` route is the load-bearing part —
/// see [songSharePath]'s own comment for why a two-segment template
/// beside `/songs/downloads` and `/songs/playlists` is a collision.
void main() {
  group('songSharePath', () {
    test('carries the id in a query, on the registered /songs route', () {
      expect(songSharePath('cdc:d0180'), '/songs?song=cdc%3Ad0180');
    });

    test('percent-encodes the colon every id carries', () {
      // Song ids are `<source>:<code>` — `cdc:d0180`, `fydt:216099`.
      // A raw colon in a query value is legal, but the encoded form is
      // what stays correct if an id grows a character that is not, and
      // it is the same choice `songSubPagePath` already made.
      for (final id in ['cdc:d0180', 'fydt:216099', 'cgdc:h01']) {
        expect(songSharePath(id), contains('%3A'), reason: id);
        expect(songSharePath(id), isNot(contains(':')), reason: id);
      }
    });

    test('the id survives the round trip', () {
      // The whole feature is this line: what the share button writes,
      // `Get.parameters['song']` has to read back unchanged. GetX
      // decodes the query, so `Uri.parse` is the same operation.
      for (final id in ['cdc:d0180', 'fydt:216099', 'setapak:s1']) {
        final parsed = Uri.parse(songSharePath(id));
        expect(parsed.path, '/songs');
        expect(parsed.queryParameters['song'], id, reason: id);
      }
    });

    test('it does not collide with the literal siblings', () {
      // `/songs/downloads` and `/songs/playlists` are registered,
      // literal and two segments long. The share link is ONE segment
      // plus a query, so it cannot be mistaken for either — which is
      // the entire reason it is not `/songs/:songId`.
      final shared = Uri.parse(songSharePath('cdc:d0180'));
      expect(shared.pathSegments, ['songs']);
      for (final literal in const ['/songs/downloads', '/songs/playlists']) {
        expect(Uri.parse(literal).pathSegments, hasLength(2));
        expect(shared.path, isNot(literal));
      }
    });
  });

  group('songShareUrl', () {
    test('is absolute and hash-routed', () {
      final url = songShareUrl('cdc:d0180');
      expect(url, contains('#/songs?song=cdc%3Ad0180'));
      // Resolved against Uri.base rather than a hard-coded origin, so it
      // is right on all four Netlify sites, both prod domains and
      // yahwehword.com. Under the test harness Uri.base is a file URL —
      // what matters is that an origin was applied at all, not which.
      expect(Uri.parse(url).hasScheme, isTrue);
    });

    test('names the song and nothing else', () {
      // Guards the one thing that would make this feature a liability:
      // the payload must not become the lyrics. The sheet has a
      // separate Lyrics copy button for anyone who wants the text on
      // purpose; a share that carried it would push a publisher's words
      // into a group chat every time someone passed on a song.
      final url = songShareUrl('cdc:d0180');
      expect(url.split('?').last, 'song=cdc%3Ad0180');
    });
  });
}
