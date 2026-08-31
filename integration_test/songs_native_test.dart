import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_playlist.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/playback/song_playback_engine.dart';
import 'package:yswords/services/song_download_service.dart';
import 'package:yswords/services/song_download_types.dart';
import 'package:yswords/services/song_playlist_service.dart';
import 'package:yswords/services/song_service.dart';

/// Songs, on a real device.
///
/// Everything under `test/` runs on flutter_tester, where audioplayers,
/// path_provider and shared_preferences have no platform side at all —
/// so downloads, playback and playlist persistence had 500-odd passing
/// tests and had never once written a file, opened an audio stream or
/// survived a real preference round-trip. This closes that gap.
///
/// Run it with:
///   `flutter test integration_test/songs_native_test.dart -d DEVICE`
///
/// It streams a few hundred KB from the church servers, so it is a
/// manual/pre-release check rather than part of CI — GitHub runners
/// hammering those hosts is exactly what the sync workflow is careful
/// to avoid.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late List<Song> catalogue;

  /// A song this machine can actually stream, or null.
  ///
  /// The catalogue points at three third-party hosts and any of them
  /// may be unreachable from wherever this runs — fydt.org and
  /// christiandiscipleschurch.org both firewalled the development
  /// machine mid-project and still time out there, while cgdc.hk
  /// answers. Picking `catalogue.first` therefore tests the network,
  /// not the app: the first attempt failed with
  /// `AVPlayerItem.Status.failed` purely because the host never
  /// replied. Probe first, and say plainly when nothing is reachable
  /// rather than reporting a red build someone will spend an hour on.
  Song? reachable;

  /// The URL the player would actually open for [song].
  ///
  /// `audioUrl` is null on rows whose audio lives only in the track
  /// list — `hasPlayableAudio` deliberately falls back to it — so
  /// reaching for `audioUrl!` blew up in setUpAll on the first such
  /// song. Mirror what the player does instead of assuming.
  String? primaryUrl(Song song) => song.audioUrl ??
      (song.audioTracks.isEmpty ? null : song.audioTracks.first.url);

  setUpAll(() async {
    catalogue = await SongService.load();
    expect(catalogue, isNotEmpty);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    final tried = <String>{};
    for (final song in catalogue.where((s) => s.hasPlayableAudio)) {
      final url = primaryUrl(song);
      if (url == null) continue;
      final host = Uri.parse(url).host;
      if (!tried.add(host)) continue;
      try {
        final req = await client
            .getUrl(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-2047');
        final res = await req.close().timeout(const Duration(seconds: 10));
        await res.drain<void>();
        if (res.statusCode == 200 || res.statusCode == 206) {
          reachable = song;
          debugPrint('[integration] streaming from $host');
          break;
        }
      } catch (_) {
        debugPrint('[integration] $host unreachable, trying the next');
      }
    }
    client.close(force: true);
  });

  group('offline downloads', () {
    testWidgets('writes a real file and reports it as downloaded',
        (tester) async {
      expect(SongDownloadService.isSupported, isTrue,
          reason: 'downloads should be available on a native build');

      final service = SongDownloadService.instance;
      await service.init();

      final song = reachable;
      if (song == null) {
        markTestSkipped('no church host is reachable from this machine');
        return;
      }
      // Start from a known state in case a previous run left it behind.
      await service.delete(song);
      expect(service.isDownloaded(song), isFalse);

      await service.enqueue([song]);

      // Give the real network time. Church mp3s are ~5 MB, so this is
      // deliberately generous; the assertion below is what matters.
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (DateTime.now().isBefore(deadline)) {
        final status = service.statusOf(song);
        if (status.state == SongDownloadState.done ||
            status.state == SongDownloadState.failed) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      final status = service.statusOf(song);
      expect(status.state, SongDownloadState.done,
          reason: 'download did not finish: ${status.error}');
      expect(status.bytes, greaterThan(10000),
          reason: 'a real mp3 should be more than a few KB');

      // The index says done — check the filesystem agrees, which is the
      // whole point of running this on a device.
      final path = service.localPathFor(song);
      expect(path, isNotNull);
      final file = File(path!);
      expect(file.existsSync(), isTrue, reason: 'no file at $path');
      expect(file.lengthSync(), status.bytes);
      // `.part` is the in-progress name; a finished download must have
      // been renamed, or a resumed app would treat it as complete.
      expect(path.endsWith('.part'), isFalse);

      await service.delete(song);
      expect(service.isDownloaded(song), isFalse);
      expect(File(path).existsSync(), isFalse,
          reason: 'delete should remove the file, not just the index');
    });
  });

  group('playback', () {
    testWidgets('the native engine actually opens a stream', (tester) async {
      final engine = SongPlaybackEngine();
      addTearDown(engine.dispose);
      expect(engine.isAvailable, isTrue,
          reason: 'the audio plugin should be registered on a device');

      final song = reachable;
      if (song == null) {
        markTestSkipped('no church host is reachable from this machine');
        return;
      }

      Duration? lastPosition;
      Duration? duration;
      String? error;
      engine.onPosition.listen((p) => lastPosition = p);
      engine.onDuration.listen((d) => duration = d);
      engine.onError.listen((e) => error = e.$2);

      await engine.play(primaryUrl(song)!);

      // Real time AND frames. audioplayers publishes position from a
      // FramePositionUpdater — a frame callback — so a plain
      // `Future.delayed` lets the audio decode while the position
      // stream stays silent, and the first run of this test reported
      // "position never advanced" against a stream that was playing
      // perfectly well. runAsync gives the wall clock; pump gives the
      // frames.
      for (var i = 0; i < 32; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump();
        if (duration != null && (lastPosition?.inMilliseconds ?? 0) > 0) break;
      }

      expect(error, isNull, reason: 'playback reported: $error');
      expect(duration, isNotNull,
          reason: 'no duration — the stream never opened');
      expect(duration!.inSeconds, greaterThan(10));
      expect(lastPosition, isNotNull);
      expect(lastPosition!.inMilliseconds, greaterThan(0),
          reason: 'position never advanced, so nothing was decoding');

      await engine.pause();
      final atPause = lastPosition!;
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump();
      }
      expect(lastPosition!.inMilliseconds - atPause.inMilliseconds,
          lessThan(1500),
          reason: 'pause did not stop the clock');

      await engine.stop();
    });
  });

  group('playlists', () {
    testWidgets('survive a real preferences round-trip', (tester) async {
      final service = SongPlaylistService.instance;
      await service.resetForTest();
      await service.load();

      final three = catalogue.take(3).toList();
      final playlist = await service.create('device check');
      await service.addSongs(playlist, three);

      await service.reorder(
          service.playlists.firstWhere((p) => p.id == playlist.id), 2, 0);
      await service.removeSong(
          service.playlists.firstWhere((p) => p.id == playlist.id), three[0]);

      // Drop every in-memory copy and read it back off the device.
      await service.resetForTest(keepStored: true);
      await service.load();

      final reloaded =
          service.playlists.where((p) => p.id == playlist.id).toList();
      expect(reloaded, hasLength(1),
          reason: 'the playlist did not survive a reload');
      expect(reloaded.single.songIds, [three[2].id, three[1].id],
          reason: 'order and removal should both persist');

      // Favourites is created on demand and must not be duplicated by
      // a reload.
      expect(
        service.playlists.where((p) => p.kind == PlaylistKind.favourites),
        hasLength(1),
      );

      await service.resetForTest();
    });
  });

  group('queue', () {
    testWidgets('shuffle keeps the current track first', (tester) async {
      final playable =
          catalogue.where((s) => s.hasPlayableAudio).take(12).toList();
      final queue = SongQueue.fromSongs(playable, startIndex: 4);
      final current = queue.current!.song.id;

      final shuffled = queue.withShuffle(true);
      expect(shuffled.current!.song.id, current,
          reason: 'shuffling should not skip the song already playing');
      expect(shuffled.items.map((i) => i.song.id).toSet(),
          queue.items.map((i) => i.song.id).toSet(),
          reason: 'shuffle must not lose or duplicate a track');
    });
  });
}
