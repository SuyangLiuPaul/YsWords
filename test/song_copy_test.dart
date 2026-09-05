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

  group('the details action never carries lyrics', () {
    // This group used to be called "lyrics are never copied" and said
    // that widening it was the owner's call. The owner made that call
    // on 2026-09-05 and lyrics are now copyable — but through
    // songLyricsCopyText and its own button, NOT through this one.
    //
    // So the assertions survive the decision they were written under,
    // and they are worth more now than they were before: with a lyric
    // copy path in the same file, "the details action grew a lyric
    // body" is a live mistake rather than a hypothetical one. Two
    // actions, two shapes; someone who wanted a citation should not
    // get forty lines of verse.
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

  group('songLyricsCopyText', () {
    // The lyrics action, approved by the owner on 2026-09-05.
    const body = 'First line\nSecond line\n\nSecond stanza';

    test('title, the words, then the source line — blocks blank-separated',
        () {
      final out = songLyricsCopyText(
        _song(lyrics: body, code: 'H123', composer: 'Anon', durationSec: 185),
        'en',
      );
      final blocks = out.split('\n\n');
      expect(blocks.first, 'A Song Title');
      expect(out.split('\n').last, 'https://example.test/song');
      // The words survive intact, stanza break included. Splitting on
      // the blank line would have cut the body in half if the blocks
      // were not assembled as blocks.
      expect(out.contains(body), isTrue,
          reason: 'the lyric body was reflowed on its way to the clipboard');
    });

    test('the words are passed through verbatim', () {
      // These are transcribed texts. Trailing spaces, doubled blank
      // lines and the source's own punctuation are how the church
      // published them; the copy path is not an editor.
      const awkward = '主啊，  祢是我的\n\n\n避难所……\n「永远的膀臂」';
      final out = songLyricsCopyText(_song(lyrics: awkward), 'en');
      expect(out.contains(awkward), isTrue);
    });

    test('the credit appears exactly once', () {
      // The failure this guards is a paste that says "CGDC · H7 · Anon"
      // at the top AND at the bottom, which is what you get if the
      // title block is built with formatEntryForCopy's body slot as
      // well as the closing block.
      final s = _song(lyrics: body, code: 'H7', composer: 'Anon');
      final meta = songMetaLine(s, 'en');
      final out = songLyricsCopyText(s, 'en');
      expect(meta.split(' · ').length, greaterThan(1),
          reason: 'the fixture must have a credit for this to test '
              'anything');
      expect(RegExp(RegExp.escape(meta)).allMatches(out).length, 1);
      expect(RegExp(RegExp.escape('A Song Title')).allMatches(out).length, 1);
    });

    test('the source line is the one the details action ends with', () {
      // Both actions close on the same two lines. Pinned so the lyric
      // paste cannot drift into naming the source differently from the
      // metadata paste taken off the same sheet.
      final s = _song(lyrics: body, code: 'H7', durationSec: 60);
      final lyricTail =
          songLyricsCopyText(s, 'en').split('\n\n').last.split('\n');
      final detailTail = songCopyText(s, 'en').split('\n').sublist(1);
      expect(lyricTail, detailTail);
    });

    test('localised source name, same as the metadata action', () {
      final s = Song(
        id: 'y',
        title: '復活頌',
        language: 'zh',
        source: 'ydh',
        sourceLabel: '雅伟的话 Yahweh De Hua',
        url: 'https://yahwehdehua.net/assets/page/easter/',
        composer: 'Rosablanca Suen',
        lyrics: body,
        audioTracks: const [],
        themes: const [],
      );
      expect(songLyricsCopyText(s, 'zh-Hant').contains('雅偉的話'), isTrue);
      expect(songLyricsCopyText(s, 'en').contains('Yahweh De Hua Ministry'),
          isTrue);
    });

    group('a song with no words offers nothing', () {
      // The licence gate, such as it is. There is no licence field on
      // Song and none in assets/songs.json — the catalogue expresses
      // "we may not reproduce this" by not carrying `lyrics` at all
      // (the two setapak rows are covers, and ship without them). An
      // empty string is formatEntryForCopy's "draw no button" signal,
      // so honouring the absence here is what keeps the button off
      // those rows.
      test('null lyrics copy as the empty string', () {
        expect(songLyricsCopyText(_song(), 'en'), '');
      });

      test('and so do blank ones — not as an orphaned title', () {
        expect(songLyricsCopyText(_song(lyrics: '   \n\n  '), 'en'), '');
      });
    });
  });
}
