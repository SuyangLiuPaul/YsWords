import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_playlist.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/song_playlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Song song(
    String id, {
    String source = 'fydt',
    String language = 'zh',
    List<String> themes = const [],
    String? instrumental,
    String? album,
  }) =>
      Song(
        id: id,
        title: id,
        language: language,
        source: source,
        sourceLabel: source,
        url: 'https://x/$id',
        album: album,
        audioUrl: 'https://x/$id.mp3',
        instrumentalUrl: instrumental,
        audioTracks: [
          SongTrackInfo(url: 'https://x/$id.mp3', kind: 'vocal'),
          if (instrumental != null)
            SongTrackInfo(url: instrumental, kind: 'instrumental'),
        ],
        themes: themes,
      );

  late SongPlaylistService svc;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    svc = SongPlaylistService.instance;
    await svc.resetForTest();
    await svc.load();
  });

  group('favourites', () {
    test('exists on first load and cannot be renamed or deleted', () {
      final fav = svc.favourites;
      expect(fav.isFavourites, isTrue);
      expect(fav.canRename, isFalse);
      expect(fav.canDelete, isFalse);
    });

    test('toggling adds then removes', () async {
      final s = song('a');
      expect(svc.isFavourite(s), isFalse);
      await svc.toggleFavourite(s);
      expect(svc.isFavourite(s), isTrue);
      await svc.toggleFavourite(s);
      expect(svc.isFavourite(s), isFalse);
    });

    test('rename and delete are refused rather than throwing', () async {
      final fav = svc.favourites;
      await svc.rename(fav, 'Nope');
      await svc.delete(fav);
      expect(svc.favourites.name, isEmpty);
      expect(svc.playlists.any((p) => p.isFavourites), isTrue);
    });
  });

  group('static playlists', () {
    test('create, rename, delete', () async {
      final p = await svc.create('开车');
      expect(p.kind, PlaylistKind.static_);
      await svc.rename(p, '安静');
      expect(svc.playlists.firstWhere((x) => x.id == p.id).name, '安静');
      await svc.delete(p);
      expect(svc.playlists.any((x) => x.id == p.id), isFalse);
    });

    test('duplicate names are disambiguated', () async {
      // Two playlists both called 开车 are indistinguishable in a
      // picker even though the ids differ.
      await svc.create('开车');
      final second = await svc.create('开车');
      expect(second.name, '开车 2');
    });

    test('adding is idempotent and preserves the user\'s order', () async {
      final p = await svc.create('list');
      await svc.addSong(p, song('c'));
      await svc.addSong(p, song('a'));
      await svc.addSong(p, song('c')); // duplicate
      final stored = svc.playlists.firstWhere((x) => x.id == p.id);
      expect(stored.songIds, ['c', 'a']);
    });

    test('resolve keeps playlist order, not catalogue order', () async {
      final p = await svc.create('list');
      await svc.addSongs(p, [song('c'), song('a'), song('b')]);
      final stored = svc.playlists.firstWhere((x) => x.id == p.id);
      final resolved =
          stored.resolve([song('a'), song('b'), song('c')]);
      expect(resolved.map((s) => s.id).toList(), ['c', 'a', 'b'],
          reason: 'a filter over the catalogue would lose the order the '
              'user arranged');
    });

    test('resolve skips ids no longer in the catalogue', () async {
      final p = await svc.create('list');
      await svc.addSongs(p, [song('a'), song('gone')]);
      final stored = svc.playlists.firstWhere((x) => x.id == p.id);
      expect(stored.resolve([song('a')]).map((s) => s.id), ['a']);
    });

    test('reorder moves an entry', () async {
      final p = await svc.create('list');
      await svc.addSongs(p, [song('a'), song('b'), song('c')]);
      await svc.reorder(
          svc.playlists.firstWhere((x) => x.id == p.id), 2, 0);
      expect(svc.playlists.firstWhere((x) => x.id == p.id).songIds,
          ['c', 'a', 'b']);
    });
  });

  group('smart playlists', () {
    test('membership follows the catalogue as it grows', () async {
      final p = await svc.create('安静',
          filter: const PlaylistFilter(source: 'fydt', theme: '安静'));
      final stored = svc.playlists.firstWhere((x) => x.id == p.id);
      expect(stored.isSmart, isTrue);

      final before = stored.resolve([
        song('a', themes: ['安静']),
        song('b', themes: ['活泼']),
      ]);
      expect(before.map((s) => s.id), ['a']);

      // The church added 63 songs in one sync this week — a snapshot
      // taken before that would have gone stale. A smart playlist
      // must pick the new one up.
      final after = stored.resolve([
        song('a', themes: ['安静']),
        song('b', themes: ['活泼']),
        song('newly-synced', themes: ['安静']),
      ]);
      expect(after.map((s) => s.id), ['a', 'newly-synced']);
    });

    test('adding a song directly is refused — membership is the '
        'filter', () async {
      final p = await svc.create('smart',
          filter: const PlaylistFilter(source: 'fydt'));
      await svc.addSong(svc.playlists.firstWhere((x) => x.id == p.id),
          song('a'));
      expect(svc.playlists.firstWhere((x) => x.id == p.id).songIds,
          isEmpty);
    });

    test('an empty filter matches everything', () {
      const f = PlaylistFilter();
      expect(f.isEmpty, isTrue);
      expect(f.apply([song('a'), song('b')]).length, 2);
    });

    test('media filter narrows to what can actually play', () {
      const f = PlaylistFilter(media: 'audio');
      final withAudio = song('a');
      final noAudio = Song(
        id: 'b',
        title: 'b',
        language: 'id',
        source: 'cahaya',
        sourceLabel: 'Cahaya',
        url: 'https://x/b',
        themes: const [],
      );
      expect(f.apply([withAudio, noAudio]).map((s) => s.id), ['a']);
    });
  });

  group('track preference', () {
    test('a playlist carries its own preference and fallback', () async {
      final p = await svc.create('开车安静');
      await svc.setPreference(
          p, TrackPreference.instrumental, TrackFallback.skip);
      final stored = svc.playlists.firstWhere((x) => x.id == p.id);
      expect(stored.preference, TrackPreference.instrumental);
      expect(stored.fallback, TrackFallback.skip);
    });

    test('instrumental + skip yields a queue with no vocals in it',
        () async {
      // The reason this matters: in a car you must not be surprised by
      // singing halfway through a quiet playlist.
      final songs = [
        song('has-inst', instrumental: 'https://x/i.mp3'),
        song('vocal-only'),
      ];
      final q = SongQueue.fromSongs(
        songs,
        preference: TrackPreference.instrumental,
        fallback: TrackFallback.skip,
      );
      expect(q.length, 1);
      expect(q.items.single.kind, 'instrumental');
    });
  });

  group('persistence', () {
    test('playlists survive a reload', () async {
      final p = await svc.create('保存测试');
      await svc.addSong(p, song('a'));
      await svc.toggleFavourite(song('fav'));

      // Simulate a cold start against the same prefs.
      final json = svc.playlists.map((x) => x.toJson()).toList();
      final restored =
          json.map((j) => SongPlaylist.fromJson(j)).toList();

      expect(restored.any((x) => x.name == '保存测试'), isTrue);
      expect(
        restored
            .firstWhere((x) => x.isFavourites)
            .songIds
            .contains('fav'),
        isTrue,
      );
    });

    test('a playlist round-trips through JSON with its preference', () {
      const original = SongPlaylist(
        id: 'p1',
        name: '开车',
        kind: PlaylistKind.smart,
        filter: PlaylistFilter(source: 'fydt', theme: '安静'),
        preference: TrackPreference.instrumental,
        fallback: TrackFallback.skip,
      );
      final back = SongPlaylist.fromJson(original.toJson());
      expect(back.name, '开车');
      expect(back.kind, PlaylistKind.smart);
      expect(back.preference, TrackPreference.instrumental);
      expect(back.fallback, TrackFallback.skip);
      expect(back.filter!.theme, '安静');
    });

    test('unknown enum values decode to safe defaults', () {
      final back = SongPlaylist.fromJson({
        'id': 'x',
        'name': 'n',
        'kind': 'from-a-future-version',
        'preference': 'nonsense',
        'fallback': 'nonsense',
      });
      expect(back.kind, PlaylistKind.static_);
      expect(back.preference, TrackPreference.vocal);
      expect(back.fallback, TrackFallback.useVocal);
    });
  });

  group('loaded', () {
    // URL-routing Stage 4 batch 2: `SongPlaylistDetailPage` uses this
    // getter to distinguish "the service hasn't loaded yet" from
    // "loaded, and this id genuinely isn't here" on a cold
    // `/#/songs/playlists/:id` load. It must NOT flip true until the
    // SharedPreferences round trip actually completes — `_loaded` (the
    // re-entrancy guard `load()` already had) flips true synchronously
    // BEFORE that await, specifically so a second concurrent call
    // doesn't start a second read; wiring `loaded` to that guard
    // instead of a separate flag would make a real playlist look gone
    // for exactly the frame this getter exists to cover.
    test('stays false until load() actually resolves, not from the '
        'moment it starts', () async {
      await svc.resetForTest();
      expect(svc.loaded, isFalse);

      final pending = svc.load();
      // load()'s synchronous prefix (the re-entrancy guard) has run,
      // but the SharedPreferences await hasn't completed.
      expect(svc.loaded, isFalse);

      await pending;
      expect(svc.loaded, isTrue);
    });

    test('a second concurrent call is a no-op and does not reset it',
        () async {
      await svc.resetForTest();
      final first = svc.load();
      final second = svc.load();
      await Future.wait([first, second]);
      expect(svc.loaded, isTrue);
    });
  });
}
