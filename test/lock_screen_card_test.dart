import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/song_audio_handler.dart';

import 'support/fake_song_playback_engine.dart';

/// The lock screen's card, and when it must go away.
///
/// 2026-09-13, from the owner's iPhone:「正在播放不是不用了吗放在那里」
/// — a card for 良善的神, paused at 0:00, still on the lock screen after
/// the player had been put away.
///
/// Two things draw that card and only one of them was ever taken back.
/// `playbackState` already went to `idle` on an empty queue;
/// `mediaItem` — the metadata, which is the half that draws the title
/// and the artwork — was published only when there was a current item
/// and otherwise left exactly as the OS last saw it.
void main() {
  Song song(String id) => Song(
        id: id,
        title: id,
        language: 'zh',
        source: 'cgdc',
        sourceLabel: 'CGDC',
        url: 'https://example.test/$id',
        audioUrl: 'https://example.test/$id.mp3',
        audioTracks: [
          SongTrackInfo(url: 'https://example.test/$id.mp3', kind: 'vocal'),
        ],
        themes: const [],
      );

  List<Song> songs(int n) => [for (var i = 0; i < n; i++) song('s$i')];

  test('dismissing takes the card down, not just the sound', () async {
    final handler = SongAudioHandler(engine: FakeSongPlaybackEngine());
    await handler.setQueue(SongQueue.fromSongs(songs(3)), autoPlay: false);
    expect(handler.mediaItem.value, isNotNull);
    expect(handler.queue.value, hasLength(3),
        reason: 'CarPlay reads this list');

    await handler.dismiss();

    expect(handler.mediaItem.value, isNull,
        reason: 'the metadata is what draws the card; leaving it is how '
            '良善的神 stayed on the lock screen after the player was put '
            'away');
    expect(handler.queue.value, isEmpty,
        reason: 'a dismissed player must not still offer a track list to '
            'jump around in');
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('stopping is NOT dismissing — the card stays, because the queue does',
      () async {
    // `stop()` halts playback and keeps the queue on purpose: the sleep
    // timer firing, or running off the end, should leave pressing play
    // as the obvious next move. The card belongs to the queue, so it
    // stays too.
    final handler = SongAudioHandler(engine: FakeSongPlaybackEngine());
    await handler.setQueue(SongQueue.fromSongs(songs(3)), autoPlay: false);
    await handler.stop();

    expect(handler.mediaItem.value, isNotNull);
    expect(handler.playbackState.value.playing, isFalse);
  });
}
