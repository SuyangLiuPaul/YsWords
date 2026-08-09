import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_playlist.dart';
import 'package:yswords/models/song_queue.dart';

/// Stores the user's playlists and favourites.
///
/// Local only, in SharedPreferences. The app has cloud sync for notes
/// and bookmarks and playlists could ride it later, but that is a
/// separate decision about what belongs in someone's account — this
/// keeps the feature usable today without making that call.
///
/// Favourites is a real playlist with a reserved id rather than a
/// separate list, so everything downstream — play, shuffle,
/// instrumental preference, the add sheet — works on it for free.
class SongPlaylistService extends ChangeNotifier {
  SongPlaylistService._();

  static final SongPlaylistService instance = SongPlaylistService._();

  static const _key = 'songs.playlists.v1';

  final List<SongPlaylist> _playlists = [];
  bool _loaded = false;

  List<SongPlaylist> get playlists => List.unmodifiable(_playlists);

  /// User playlists, favourites first — it is the one people reach for.
  List<SongPlaylist> get ordered {
    final fav = _playlists.where((p) => p.isFavourites);
    final rest = _playlists.where((p) => !p.isFavourites).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [...fav, ...rest];
  }

  SongPlaylist get favourites => _playlists.firstWhere(
        (p) => p.isFavourites,
        orElse: () => const SongPlaylist(
          id: SongPlaylist.favouritesId,
          name: '',
          kind: PlaylistKind.favourites,
        ),
      );

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final list = json.decode(raw) as List;
        _playlists
          ..clear()
          ..addAll(list.whereType<Map>().map(
              (e) => SongPlaylist.fromJson(e.cast<String, dynamic>())));
      }
    } catch (e) {
      debugPrint('[SongPlaylistService] load failed: $e');
    }
    _ensureFavourites();
    notifyListeners();
  }

  void _ensureFavourites() {
    if (_playlists.any((p) => p.isFavourites)) return;
    _playlists.insert(
      0,
      SongPlaylist(
        id: SongPlaylist.favouritesId,
        name: '',
        kind: PlaylistKind.favourites,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, json.encode([for (final p in _playlists) p.toJson()]));
    } catch (e) {
      debugPrint('[SongPlaylistService] save failed: $e');
    }
    notifyListeners();
  }

  // ── Favourites ──────────────────────────────────────────────────

  bool isFavourite(Song song) => favourites.songIds.contains(song.id);

  Future<void> toggleFavourite(Song song) async {
    await load();
    final fav = favourites;
    final ids = [...fav.songIds];
    ids.contains(song.id) ? ids.remove(song.id) : ids.add(song.id);
    _replace(fav.copyWith(songIds: ids));
    await _persist();
  }

  // ── CRUD ────────────────────────────────────────────────────────

  Future<SongPlaylist> create(
    String name, {
    PlaylistFilter? filter,
    List<String> songIds = const [],
    TrackPreference preference = TrackPreference.vocal,
    TrackFallback fallback = TrackFallback.useVocal,
  }) async {
    await load();
    final playlist = SongPlaylist(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: _uniqueName(name),
      kind: filter == null ? PlaylistKind.static_ : PlaylistKind.smart,
      songIds: songIds,
      filter: filter,
      preference: preference,
      fallback: fallback,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    _playlists.add(playlist);
    await _persist();
    return playlist;
  }

  /// Names are not identifiers, so duplicates are legal — but two
  /// playlists both called "开车" are indistinguishable in a picker,
  /// which is a usability bug even if the data is fine.
  String _uniqueName(String wanted) {
    final base = wanted.trim().isEmpty ? 'Playlist' : wanted.trim();
    if (!_playlists.any((p) => p.name == base)) return base;
    for (var n = 2; n < 100; n++) {
      final candidate = '$base $n';
      if (!_playlists.any((p) => p.name == candidate)) return candidate;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> rename(SongPlaylist playlist, String name) async {
    final live = _live(playlist);
    if (!live.canRename) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _replace(live.copyWith(name: _uniqueName(trimmed)));
    await _persist();
  }

  Future<void> delete(SongPlaylist playlist) async {
    if (!playlist.canDelete) return;
    _playlists.removeWhere((p) => p.id == playlist.id);
    await _persist();
  }

  Future<void> setPreference(
    SongPlaylist playlist,
    TrackPreference preference,
    TrackFallback fallback,
  ) async {
    _replace(_live(playlist).copyWith(
        preference: preference, fallback: fallback));
    await _persist();
  }

  Future<void> addSong(SongPlaylist playlist, Song song) async {
    final live = _live(playlist);
    if (live.isSmart) return; // membership comes from the filter
    if (live.songIds.contains(song.id)) return;
    _replace(live.copyWith(songIds: [...live.songIds, song.id]));
    await _persist();
  }

  Future<void> addSongs(SongPlaylist playlist, Iterable<Song> songs) async {
    final live = _live(playlist);
    if (live.isSmart) return;
    final ids = [...live.songIds];
    for (final s in songs) {
      if (!ids.contains(s.id)) ids.add(s.id);
    }
    _replace(live.copyWith(songIds: ids));
    await _persist();
  }

  Future<void> removeSong(SongPlaylist playlist, Song song) async {
    final live = _live(playlist);
    if (live.isSmart) return;
    _replace(live.copyWith(
        songIds: [...live.songIds]..remove(song.id)));
    await _persist();
  }

  Future<void> reorder(SongPlaylist playlist, int from, int to) async {
    final live = _live(playlist);
    if (live.isSmart) return;
    final ids = [...live.songIds];
    if (from < 0 || from >= ids.length) return;
    final id = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), id);
    _replace(live.copyWith(songIds: ids));
    await _persist();
  }

  /// The stored version of [playlist], not the caller's copy.
  ///
  /// Callers hold snapshots — a widget captures a playlist, the user
  /// taps twice, and the second call would otherwise write stale
  /// songIds over the first edit. Always re-read by id before
  /// mutating.
  SongPlaylist _live(SongPlaylist playlist) =>
      _playlists.firstWhere((p) => p.id == playlist.id,
          orElse: () => playlist);

  void _replace(SongPlaylist updated) {
    final at = _playlists.indexWhere((p) => p.id == updated.id);
    if (at < 0) {
      _playlists.add(updated);
    } else {
      _playlists[at] = updated;
    }
  }

  /// Which of the user's playlists already contain [song] — drives the
  /// checkmarks in the add sheet.
  Set<String> playlistIdsContaining(Song song) => {
        for (final p in _playlists)
          if (!p.isSmart && p.songIds.contains(song.id)) p.id,
      };

  /// Drop the in-memory state.
  ///
  /// [keepStored] leaves what is on disk alone, which is how a test
  /// simulates a fresh launch: clear the cache, call [load] again, and
  /// whatever comes back came from the device rather than from memory.
  /// Without it there is no way to tell a working `_persist` from a
  /// service that has simply never forgotten anything.
  @visibleForTesting
  Future<void> resetForTest({bool keepStored = false}) async {
    _playlists.clear();
    _loaded = false;
    if (keepStored) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
