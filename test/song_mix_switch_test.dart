import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';

/// Switching the whole queue's mix while it is playing.
///
/// The per-song chips in the detail sheet only ever affected one song,
/// and a playlist's preference could only be chosen before pressing
/// play — so "drop the vocals, I'm driving" meant going back and
/// rebuilding the queue.
///
/// Tested against `SongQueue.withPreference` rather than the handler.
/// Driving it through the handler means touching the audio plugin, and
/// in a test environment that plugin's start-up future never settles,
/// so the file wedged instead of failing. The rules that matter here
/// are about the queue, not about decoding.
void main() {
  Song song(String id, {String? instrumental, String? accompaniment}) => Song(
        id: id,
        title: id,
        language: 'zh',
        source: 'fydt',
        sourceLabel: 'fydt',
        url: 'https://x/$id',
        audioUrl: 'https://x/$id.mp3',
        instrumentalUrl: instrumental,
        accompanimentUrl: accompaniment,
        audioTracks: [
          SongTrackInfo(url: 'https://x/$id.mp3', kind: 'vocal'),
          if (instrumental != null)
            SongTrackInfo(url: instrumental, kind: 'instrumental'),
          if (accompaniment != null)
            SongTrackInfo(url: accompaniment, kind: 'accompaniment'),
        ],
        themes: const [],
      );

  test('switching mix keeps the current song and the running order', () {
    final songs = [
      for (var i = 0; i < 4; i++)
        song('s$i', accompaniment: 'https://x/s$i-acc.mp3'),
    ];
    final queue = SongQueue.fromSongs(songs, startSongId: 's2');
    expect(queue.current!.song.id, 's2');

    final next = queue.withPreference(
        TrackPreference.accompaniment, TrackFallback.skip);

    expect(next.current!.song.id, 's2',
        reason: 'changing the mix should not move you to another song');
    expect(next.current!.kind, 'accompaniment');
    expect(next.current!.url, 'https://x/s2-acc.mp3');
    expect(next.items.map((i) => i.song.id).toList(),
        ['s0', 's1', 's2', 's3'],
        reason: 'the running order must survive a mix change');
  });

  test('a shuffled queue stays shuffled and is not reshuffled', () {
    final songs = [
      for (var i = 0; i < 8; i++)
        song('s$i', accompaniment: 'https://x/s$i-acc.mp3'),
    ];
    final shuffled = SongQueue.fromSongs(songs, shuffled: true);
    final order = shuffled.items.map((i) => i.song.id).toList();

    final next = shuffled.withPreference(
        TrackPreference.accompaniment, TrackFallback.skip);

    expect(next.shuffled, isTrue);
    expect(next.items.map((i) => i.song.id).toList(), order,
        reason: 'changing the mix must not re-roll the shuffle');
  });

  test('accompaniment with skip drops songs that lack it', () {
    final queue = SongQueue.fromSongs([
      song('has', accompaniment: 'https://x/has-acc.mp3'),
      song('lacks'),
      song('also', accompaniment: 'https://x/also-acc.mp3'),
    ]);

    final next = queue.withPreference(
        TrackPreference.accompaniment, TrackFallback.skip);

    expect(next.items.map((i) => i.song.id).toList(), ['has', 'also'],
        reason: 'a queue set to accompaniment must never sing');
    expect(next.items.every((i) => i.kind == 'accompaniment'), isTrue);
  });

  test('useVocal falls back instead of dropping the song', () {
    final queue = SongQueue.fromSongs([
      song('has', accompaniment: 'https://x/has-acc.mp3'),
      song('lacks'),
    ]);

    final next = queue.withPreference(
        TrackPreference.accompaniment, TrackFallback.useVocal);

    expect(next.length, 2);
    expect(next.items[1].kind, 'vocal',
        reason: 'the song with no accompaniment keeps its sung take');
  });

  test('a mix nothing has yields an empty queue for the caller to reject',
      () {
    final queue = SongQueue.fromSongs(
        [for (var i = 0; i < 3; i++) song('s$i')], startSongId: 's1');

    final next = queue.withPreference(
        TrackPreference.instrumental, TrackFallback.skip);

    expect(next.isEmpty, isTrue,
        reason: 'the handler keeps the old queue and reports no-tracks '
            'rather than stopping the music');
  });

  test('going back to vocal restores the sung take', () {
    final songs = [
      for (var i = 0; i < 3; i++)
        song('s$i', accompaniment: 'https://x/s$i-acc.mp3'),
    ];
    final acc = SongQueue.fromSongs(songs).withPreference(
        TrackPreference.accompaniment, TrackFallback.skip);
    expect(acc.current!.kind, 'accompaniment');

    final back =
        acc.withPreference(TrackPreference.vocal, TrackFallback.useVocal);

    expect(back.current!.kind, 'vocal');
    expect(back.current!.url, 'https://x/s0.mp3');
    expect(back.length, 3);
  });
}
