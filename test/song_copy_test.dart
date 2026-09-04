// What a song puts on the clipboard.
//
// Shared by the song detail sheet, the now-playing screen and the score
// page, so this is where the shape is pinned rather than in three
// places that would drift.
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/utils/song_copy.dart';

Song _song({
  String? code,
  String? composer,
  int? durationSec,
  String? lyrics,
}) =>
    Song(
      id: 'x',
      title: 'A Song Title',
      language: 'zh',
      source: 'cgdc',
      sourceLabel: 'CGDC',
      url: 'https://example.test/song',
      code: code,
      composer: composer,
      durationSec: durationSec,
      lyrics: lyrics,
      audioTracks: const [],
      themes: const [],
    );

void main() {
  test('title, metadata line, and the source page — in that order', () {
    final out = songCopyText(_song(code: 'H123', durationSec: 185), 'en');
    final lines = out.split('\n');
    expect(lines.first, 'A Song Title');
    expect(lines.last, 'https://example.test/song');
    expect(lines.length, 3);
    expect(lines[1], contains('H123'));
  });

  test('absent metadata leaves no empty separators', () {
    // A song with no catalogue number, credit or duration reads as its
    // source alone — not as a row of dangling " · ".
    final line = songMetaLine(_song(), 'en');
    expect(line.contains('·'), isFalse,
        reason: 'separators appeared with nothing to separate: "$line"');
    expect(line.trim(), isNotEmpty);
  });

  test('the metadata line the screen draws is the one that is copied', () {
    // Both come from songMetaLine; this pins that the copy path has not
    // quietly grown a second builder.
    final s = _song(code: 'H7', composer: 'Anon', durationSec: 60);
    expect(songCopyText(s, 'en').split('\n')[1], songMetaLine(s, 'en'));
  });

  group('lyrics are never copied', () {
    // A DECISION, not an oversight, and the reason it is a test rather
    // than only a comment. Neither screen displays lyrics, and the
    // catalogue is already deliberate about whose words it carries at
    // all: yswords-data's fetch_setapak skips them because those posts
    // are covers it cannot license, while fetch_ydh carries them
    // because that ministry publishes its own. Widening this is the
    // owner's call — so if it ever widens, this test should be deleted
    // deliberately, with that decision in the diff.
    test('a song carrying lyrics still copies only its details', () {
      const marker = 'ZZ_LYRIC_BODY_MARKER_ZZ';
      final out = songCopyText(_song(lyrics: '$marker\nsecond line'), 'en');
      expect(out.contains(marker), isFalse,
          reason: 'the lyric body reached the clipboard');
      expect(out.split('\n').length, 3,
          reason: 'title, the source-only metadata line, and the source '
              'page — nothing else');
    });

    test('and neither does the metadata line', () {
      const marker = 'ZZ_LYRIC_BODY_MARKER_ZZ';
      expect(songMetaLine(_song(lyrics: marker), 'en').contains(marker),
          isFalse);
    });
  });
}
