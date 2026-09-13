import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/song_audio_handler.dart';

import 'support/fake_song_playback_engine.dart';

/// The two iPhone reports of 2026-09-13, and the scenarios around them.
///
///   「播放全部的时候第一个歌完了不会自动播放下一首」
///   「随机播放第一首总是第一首歌开始播」
///
/// The first is the gap BETWEEN songs on a backgrounded page: the next
/// file has to be fetched, and iOS suspends the page the moment audio
/// stops, so the fetch never finishes until the reader looks at their
/// phone. The fix is to fetch before the end — the handler asks the
/// engine to warm the next track inside a lead window, and the web
/// engine swaps a pre-buffered element in when the track ends. These
/// tests pin the HANDLER's half: what gets warmed, when, and — just as
/// important — when nothing should be.
///
/// The second was `fromSongs(shuffled: true)` pinning "the current item"
/// to the front, where the current item was only row one because the
/// index defaults to zero. Pinning is right while something is playing;
/// it is wrong before anything has.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<void> settle(WidgetTester tester, [int cycles = 10]) async {
    for (var i = 0; i < cycles; i++) {
      await tester.pump();
    }
  }

  group('shuffle does not always start on the first song', () {
    test('play-all shuffled: the first track is as random as the rest', () {
      // Ten seeds, twelve songs. If row one were pinned, every queue
      // would start on s0; a free shuffle starts elsewhere almost always.
      var startedOnFirst = 0;
      for (var seed = 0; seed < 10; seed++) {
        final q = SongQueue.fromSongs(songs(12),
            shuffled: true, random: Random(seed));
        expect(q.shuffled, isTrue);
        expect(q.index, 0, reason: 'playback starts at the head of the '
            'shuffled order');
        if (q.current!.song.id == 's0') startedOnFirst++;
      }
      expect(startedOnFirst, lessThan(10),
          reason: 'before the fix this was 10 of 10 — row one every time');
    });

    test('a song the listener tapped stays first even when shuffled', () {
      for (var seed = 0; seed < 10; seed++) {
        final q = SongQueue.fromSongs(songs(12),
            shuffled: true, startSongId: 's7', random: Random(seed));
        expect(q.current!.song.id, 's7',
            reason: 'tapping a row and choosing shuffle means "this one, '
                'then the rest in random order"');
      }
    });

    testWidgets('shuffle pressed while nothing has played may start anywhere',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final handler = SongAudioHandler(engine: engine);
      await handler.setQueue(SongQueue.fromSongs(songs(12)), autoPlay: false);
      var startedOnFirst = 0;
      for (var i = 0; i < 10; i++) {
        await handler.setShuffle(false);
        await handler.setShuffle(true);
        if (handler.songQueue.current!.song.id == 's0') startedOnFirst++;
      }
      expect(startedOnFirst, lessThan(10),
          reason: 'row one was only current because the index starts at 0');
      unawaited(handler.stop());
    });

    testWidgets('shuffle pressed mid-song keeps the song in your ears',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final handler = SongAudioHandler(engine: engine);
      await handler.setQueue(SongQueue.fromSongs(songs(12)), autoPlay: false);
      unawaited(handler.playAt(4));
      await settle(tester);
      engine.emitPosition(const Duration(seconds: 30));
      await settle(tester);
      for (var i = 0; i < 10; i++) {
        await handler.setShuffle(false);
        await handler.setShuffle(true);
        expect(handler.songQueue.current!.song.id, 's4',
            reason: 'shuffling must never cut off the current track');
      }
      unawaited(handler.stop());
    });
  });

  group('the next track is warmed before this one ends', () {
    Future<SongAudioHandler> playing(WidgetTester tester,
        FakeSongPlaybackEngine engine, SongQueue q, int at) async {
      final handler = SongAudioHandler(engine: engine);
      await handler.setQueue(q, autoPlay: false);
      unawaited(handler.playAt(at));
      await settle(tester);
      engine.emitDuration(const Duration(minutes: 3));
      await settle(tester);
      return handler;
    }

    testWidgets('inside the lead window, exactly once, for the next song',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final h = await playing(tester, engine, SongQueue.fromSongs(songs(3)), 0);

      engine.emitPosition(const Duration(minutes: 1));
      await settle(tester);
      expect(engine.preloadCalls, isEmpty,
          reason: 'two minutes from the end is not the window');

      engine.emitPosition(const Duration(minutes: 2, seconds: 45));
      await settle(tester);
      expect(engine.preloadCalls, ['https://example.test/s1.mp3']);

      engine.emitPosition(const Duration(minutes: 2, seconds: 50));
      engine.emitPosition(const Duration(minutes: 2, seconds: 55));
      await settle(tester);
      expect(engine.preloadCalls.length, 1,
          reason: 'timeupdate fires several times a second; the ask is '
              'made once');
      unawaited(h.stop());
    });

    testWidgets('nothing is warmed under repeat-one — the element loops',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final h = await playing(tester, engine,
          SongQueue.fromSongs(songs(3), repeat: RepeatMode.one), 0);
      engine.emitPosition(const Duration(minutes: 2, seconds: 50));
      await settle(tester);
      expect(engine.preloadCalls, isEmpty);
      unawaited(h.stop());
    });

    testWidgets('nothing is warmed at the end of the queue with repeat off',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final h = await playing(tester, engine, SongQueue.fromSongs(songs(3)), 2);
      engine.emitPosition(const Duration(minutes: 2, seconds: 50));
      await settle(tester);
      expect(engine.preloadCalls, isEmpty,
          reason: 'there is no next track to warm');
      unawaited(h.stop());
    });

    testWidgets('repeat-all warms the first track from the last',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final h = await playing(tester, engine,
          SongQueue.fromSongs(songs(3), repeat: RepeatMode.all), 2);
      engine.emitPosition(const Duration(minutes: 2, seconds: 50));
      await settle(tester);
      expect(engine.preloadCalls, ['https://example.test/s0.mp3']);
      unawaited(h.stop());
    });

    testWidgets('a shuffled queue warms the next in SHUFFLED order',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final q = SongQueue.fromSongs(songs(6),
          shuffled: true, startSongId: 's0', random: Random(3));
      final h = await playing(tester, engine, q, 0);
      final expected = q.items[1].song.id;
      engine.emitPosition(const Duration(minutes: 2, seconds: 50));
      await settle(tester);
      expect(engine.preloadCalls, ['https://example.test/$expected.mp3']);
      unawaited(h.stop());
    });

    testWidgets('"stop at the end of this song" warms nothing',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final h = await playing(tester, engine, SongQueue.fromSongs(songs(3)), 0);
      h.setSleepAtEndOfTrack(true);
      engine.emitPosition(const Duration(minutes: 2, seconds: 50));
      await settle(tester);
      expect(engine.preloadCalls, isEmpty,
          reason: 'fetching a song the listener asked not to hear is '
              'bandwidth in a car for nothing');
      unawaited(h.stop());
    });

    testWidgets('starting a new track resets the ask, so the NEXT next is warmed',
        (tester) async {
      final engine = FakeSongPlaybackEngine();
      final h = await playing(tester, engine, SongQueue.fromSongs(songs(3)), 0);
      engine.emitPosition(const Duration(minutes: 2, seconds: 50));
      await settle(tester);
      expect(engine.preloadCalls, ['https://example.test/s1.mp3']);
      unawaited(h.playAt(1));
      await settle(tester);
      engine.emitDuration(const Duration(minutes: 3));
      engine.emitPosition(const Duration(minutes: 2, seconds: 50));
      await settle(tester);
      expect(engine.preloadCalls,
          ['https://example.test/s1.mp3', 'https://example.test/s2.mp3']);
      unawaited(h.stop());
    });
  });
}
