import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';

/// Pure-logic tests for the playback queue. No player, no platform —
/// these pin the semantics that are easy to get subtly wrong and
/// miserable to debug through a real audio session.
void main() {
  _insertionRules();
  _removalRules();
  Song song(
    String id, {
    String? vocal = 'v',
    String? instrumental,
    String? accompaniment,
    String language = 'zh',
    List<SongTrackInfo>? tracks,
  }) =>
      Song(
        id: id,
        title: id,
        language: language,
        source: 'fydt',
        sourceLabel: 'FYDT',
        url: 'https://fydt.org/$id',
        audioUrl: vocal == null ? null : 'https://x/$id-$vocal.mp3',
        instrumentalUrl:
            instrumental == null ? null : 'https://x/$id-$instrumental.mp3',
        accompanimentUrl:
            accompaniment == null ? null : 'https://x/$id-$accompaniment.mp3',
        audioTracks: tracks ??
            [
              if (vocal != null)
                SongTrackInfo(url: 'https://x/$id-$vocal.mp3', kind: 'vocal'),
              if (instrumental != null)
                SongTrackInfo(
                    url: 'https://x/$id-$instrumental.mp3',
                    kind: 'instrumental'),
              if (accompaniment != null)
                SongTrackInfo(
                    url: 'https://x/$id-$accompaniment.mp3',
                    kind: 'accompaniment'),
            ],
        themes: const [],
      );

  group('track resolution', () {
    test('instrumental preference picks the instrumental', () {
      final q = SongQueue.fromSongs(
        [song('a', instrumental: 'i')],
        preference: TrackPreference.instrumental,
      );
      expect(q.length, 1);
      expect(q.current!.kind, 'instrumental');
      expect(q.current!.url, contains('-i.mp3'));
    });

    test('skip fallback drops songs with no instrumental — the point '
        'of a quiet playlist', () {
      final q = SongQueue.fromSongs(
        [song('a', instrumental: 'i'), song('b'), song('c')],
        preference: TrackPreference.instrumental,
        fallback: TrackFallback.skip,
      );
      expect(q.length, 1,
          reason: 'b and c have no instrumental; an instrumental-only '
              'queue must not quietly play their vocals');
      expect(q.items.single.song.id, 'a');
    });

    test('useVocal fallback keeps them, marked as fallbacks', () {
      final q = SongQueue.fromSongs(
        [song('a', instrumental: 'i'), song('b')],
        preference: TrackPreference.instrumental,
        fallback: TrackFallback.useVocal,
      );
      expect(q.length, 2);
      expect(q.items[0].isFallback, isFalse);
      expect(q.items[1].isFallback, isTrue);
    });

    test('songs with no audio at all are never queued', () {
      final q = SongQueue.fromSongs([song('a', vocal: null), song('b')]);
      expect(q.length, 1);
      expect(q.items.single.song.id, 'b');
    });

    test('among several vocal takes, the song\'s own language wins', () {
      final s = Song(
        id: 'cdc:d0375',
        title: 'Arise and Shine',
        language: 'en',
        source: 'cdc',
        sourceLabel: 'CDC',
        url: 'https://x/',
        themes: const [],
        audioTracks: const [
          SongTrackInfo(url: 'https://x/zh.mp3', kind: 'vocal', lang: 'zh'),
          SongTrackInfo(url: 'https://x/en.mp3', kind: 'vocal', lang: 'en'),
        ],
      );
      final q = SongQueue.fromSongs([s]);
      expect(q.current!.url, 'https://x/en.mp3',
          reason: 'a song listed as English should not start in Chinese');
    });
  });

  group('advance', () {
    SongQueue three({RepeatMode repeat = RepeatMode.off, int index = 0}) =>
        SongQueue.fromSongs([song('a'), song('b'), song('c')],
            repeat: repeat, startIndex: index);

    test('walks forward and stops at the end with repeat off', () {
      expect(three().nextIndex(), 1);
      expect(three(index: 2).nextIndex(), isNull);
      expect(three(index: 2).hasNext, isFalse);
    });

    test('repeat all wraps in both directions', () {
      expect(three(index: 2, repeat: RepeatMode.all).nextIndex(), 0);
      expect(three(index: 0, repeat: RepeatMode.all).previousIndex(), 2);
    });

    test('repeat one stays put', () {
      final q = three(index: 1, repeat: RepeatMode.one);
      expect(q.nextIndex(), 1);
      expect(q.previousIndex(), 1);
    });

    test('previous stops at the start with repeat off', () {
      expect(three().previousIndex(), isNull);
      expect(three().hasPrevious, isFalse);
    });
  });

  group('shuffle', () {
    test('keeps the current track playing and puts it first', () {
      final q = SongQueue.fromSongs(
        [for (var i = 0; i < 10; i++) song('s$i')],
        startIndex: 4,
      );
      final playing = q.current!.song.id;
      final shuffled = q.withShuffle(true, random: Random(1));
      expect(shuffled.shuffled, isTrue);
      expect(shuffled.current!.song.id, playing,
          reason: 'turning shuffle on must not cut off the current song');
      expect(shuffled.length, 10, reason: 'no track may be lost');
      expect(shuffled.items.map((i) => i.song.id).toSet().length, 10,
          reason: 'no track may be duplicated');
    });

    test('the order is fixed once shuffled, so previous is meaningful',
        () {
      final q = SongQueue.fromSongs(
        [for (var i = 0; i < 8; i++) song('s$i')],
      ).withShuffle(true, random: Random(7));

      final order = q.items.map((i) => i.song.id).toList();
      // Advancing does not reshuffle: walking forward then back must
      // return to the same track.
      final atTwo = q.copyWith(index: 2);
      final back = atTwo.copyWith(index: atTwo.previousIndex()!);
      expect(back.current!.song.id, order[1]);
      expect(atTwo.items.map((i) => i.song.id).toList(), order,
          reason: 'the queue must not re-randomise between advances');
    });

    test('turning shuffle off restores a stable order and keeps the '
        'current track', () {
      final q = SongQueue.fromSongs(
        [for (var i = 0; i < 6; i++) song('s$i')],
        startIndex: 3,
      );
      final playing = q.current!.song.id;
      final restored =
          q.withShuffle(true, random: Random(3)).withShuffle(false);
      expect(restored.shuffled, isFalse);
      expect(restored.current!.song.id, playing);
      expect(restored.length, 6);
    });

    test('shuffling an empty queue does not throw', () {
      expect(SongQueue.empty.withShuffle(true).isEmpty, isTrue);
    });
  });

  group('removeAt', () {
    test('dropping a dead track keeps the current selection sane', () {
      final q = SongQueue.fromSongs(
        [song('a'), song('b'), song('c')],
        startIndex: 2,
      );
      // Remove something BEFORE the cursor — the cursor shifts down so
      // it still points at the same song.
      final after = q.removeAt(0);
      expect(after.length, 2);
      expect(after.current!.song.id, 'c');
    });

    test('removing the last item leaves a valid empty-ish queue', () {
      final q = SongQueue.fromSongs([song('a')]);
      final after = q.removeAt(0);
      expect(after.isEmpty, isTrue);
      expect(after.current, isNull);
      expect(() => after.nextIndex(), returnsNormally);
    });

    test('an out-of-range index is a no-op', () {
      final q = SongQueue.fromSongs([song('a')]);
      expect(q.removeAt(5).length, 1);
      expect(q.removeAt(-1).length, 1);
    });
  });
}

/// Dropping a track from a queue you are listening to.
///
/// `removeAt` had existed with tests and no caller since the queue was
/// built; SongAudioHandler.removeFromQueue now uses it, and the parts
/// worth pinning are the index bookkeeping a listener would notice —
/// removing something above you must not move you to a different song.
void _removalRules() {
  Song s(String id) => Song(
        id: id,
        title: id,
        language: 'zh',
        source: 'fydt',
        sourceLabel: 'fydt',
        url: 'https://x/$id',
        audioUrl: 'https://x/$id.mp3',
        audioTracks: [SongTrackInfo(url: 'https://x/$id.mp3', kind: 'vocal')],
        themes: const [],
      );

  group('removeAt', () {
    test('removing above the current track keeps you on it', () {
      final q = SongQueue.fromSongs(
          [s('a'), s('b'), s('c'), s('d')], startSongId: 'c');
      expect(q.current!.song.id, 'c');
      final next = q.removeAt(0);
      expect(next.current!.song.id, 'c',
          reason: 'you should not be moved to another song');
      expect(next.items.map((i) => i.song.id), ['b', 'c', 'd']);
    });

    test('removing below the current track keeps you on it', () {
      final q = SongQueue.fromSongs([s('a'), s('b'), s('c')], startSongId: 'a');
      final next = q.removeAt(2);
      expect(next.current!.song.id, 'a');
      expect(next.length, 2);
    });

    test('removing the last track empties the queue', () {
      final q = SongQueue.fromSongs([s('only')]);
      expect(q.removeAt(0).isEmpty, isTrue);
    });

    test('an out-of-range index changes nothing', () {
      final q = SongQueue.fromSongs([s('a'), s('b')]);
      expect(q.removeAt(9).length, 2);
      expect(q.removeAt(-1).length, 2);
    });
  });
}

/// Queueing a song without interrupting what is playing.
void _insertionRules() {
  Song s(String id) => Song(
        id: id,
        title: id,
        language: 'zh',
        source: 'fydt',
        sourceLabel: 'fydt',
        url: 'https://x/$id',
        audioUrl: 'https://x/$id.mp3',
        audioTracks: [SongTrackInfo(url: 'https://x/$id.mp3', kind: 'vocal')],
        themes: const [],
      );

  QueueItem item(String id) =>
      QueueItem(song: s(id), url: 'https://x/$id.mp3', kind: 'vocal');

  group('insertAt', () {
    test('play next lands right after the current track', () {
      final q = SongQueue.fromSongs([s('a'), s('b'), s('c')], startSongId: 'b');
      final next = q.insertAt(q.index + 1, item('new'));
      expect(next.items.map((i) => i.song.id), ['a', 'b', 'new', 'c']);
      expect(next.current!.song.id, 'b',
          reason: 'queueing must never interrupt what is playing');
    });

    test('inserting above the current track keeps you on it', () {
      final q = SongQueue.fromSongs([s('a'), s('b'), s('c')], startSongId: 'c');
      final next = q.insertAt(0, item('new'));
      expect(next.current!.song.id, 'c');
      expect(next.items.first.song.id, 'new');
    });

    test('adding to the end leaves the position alone', () {
      final q = SongQueue.fromSongs([s('a'), s('b')], startSongId: 'a');
      final next = q.insertAt(q.length, item('new'));
      expect(next.items.map((i) => i.song.id), ['a', 'b', 'new']);
      expect(next.index, 0);
    });

    test('an out-of-range position is clamped, not crashed', () {
      final q = SongQueue.fromSongs([s('a')]);
      expect(q.insertAt(99, item('new')).length, 2);
      expect(q.insertAt(-5, item('new2')).length, 2);
    });
  });
}
