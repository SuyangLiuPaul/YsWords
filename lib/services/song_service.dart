import 'package:yswords/models/song.dart';
import 'package:yswords/services/remote_data_service.dart';

/// Bundle wrapper so the catalogue fits [RemoteDataService]'s generic
/// `T`. Callers still work with `List<Song>`; the unwrapping happens
/// inside the service.
class _SongBundle {
  final List<Song> songs;
  final Map<String, dynamic>? meta;
  final DateTime? generatedAt;
  const _SongBundle(this.songs, this.meta, this.generatedAt);
}

class _SongServiceImpl extends RemoteDataService<_SongBundle> {
  static const String _defaultRemote =
      'https://yswords-data.netlify.app/data/songs.json';

  static const String _envUrl = String.fromEnvironment(
    'SONGS_URL',
    defaultValue: _defaultRemote,
  );

  @override
  String get bundledAssetPath => 'assets/songs.json';

  @override
  String get remoteUrl => _envUrl;

  /// `v2` — the schema gained `audioTracks` when CDC's per-language
  /// takes were modelled. A `v1` payload cached before that would
  /// decode fine but silently lack every alternate mix, so old caches
  /// must be discarded rather than reused.
  @override
  String get cachePrefsKey => 'songs.cachedJson.v2';

  /// The upstream catalogue is re-synced daily (18:00 UTC), so there
  /// is still nothing to gain from pulling ~700 KB on every cold
  /// start. Twelve hours means a new song reaches an active user
  /// within half a day of publication while costing at most two
  /// fetches a day; the bundled/cached copy still renders instantly,
  /// and the Songs page's pull-to-refresh forces a fresh pull.
  @override
  Duration get minRefreshInterval => const Duration(hours: 12);

  @override
  _SongBundle parse(Map<String, dynamic> json) {
    final songs = (json['songs'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final meta = json['_meta'];
    DateTime? gen;
    Map<String, dynamic>? metaMap;
    if (meta is Map) {
      metaMap = Map<String, dynamic>.from(meta);
      final s = meta['generatedAt'];
      if (s is String) gen = DateTime.tryParse(s);
    }
    return _SongBundle(songs, metaMap, gen);
  }

  @override
  DateTime? generatedAt(_SongBundle bundle) => bundle.generatedAt;
}

/// Loads the church-songs catalogue.
///
/// 2026-08-09: this used to read `assets/songs.json` and nothing else,
/// so a song added upstream only reached users when someone cut a new
/// app build. The catalogue is now published as a dataset on
/// yswords-data and this rides the same three-tier path the Bible
/// Evidence archive uses:
///
///   1. SharedPreferences cache (last successful network fetch)
///   2. the bundled `assets/songs.json` snapshot
///   3. a background refresh from yswords-data
///
/// The first call returns instantly from cache or bundle — the network
/// is never on the critical path — and the refreshed copy is there for
/// the next one. Offline, or with yswords-data down, the bundled
/// snapshot keeps the whole directory browsable.
class SongService {
  static final _SongServiceImpl _impl = _SongServiceImpl();

  /// Sources hidden from the app. Empty since 2026-08-17.
  ///
  /// `cahaya` (cahayapengharapan.org) was hidden because it publishes no
  /// audio of its own — all 47 of its songs live on SoundCloud (27) or
  /// YouTube (36), neither of which exposes a stream URL a player can
  /// open, so every one of those rows showed a language badge where the
  /// rest of the catalogue shows a play button. The user asked for them
  /// back ("还是enable吧"), and the row now offers the external source
  /// instead of an inert badge, which is what made them worth hiding.
  ///
  /// Hiding was always a presentation decision — yswords-data carries
  /// all 609 songs either way, because a data repository's job is to be
  /// complete. Put a source id back in this set to hide it again.
  static const Set<String> hiddenSources = <String>{};

  /// Never throws: falls back through cache → bundle.
  static Future<List<Song>> load() async {
    final bundle = await _impl.load();
    return bundle.songs
        .where((s) => !hiddenSources.contains(s.source))
        .toList();
  }

  /// One song by its stable `<source>:<slug>` id, or null if the
  /// catalogue has no such row.
  ///
  /// URL-routing Stage 5 (`docs/url-routing-plan.md` §6 batch 4): the
  /// cold-load lookup behind `/songs/:songId/score` and
  /// `/songs/:songId/video`. Goes through [load], so it inherits its
  /// never-throws cache → bundle → network path: a cold deep link
  /// resolves against the bundled `assets/songs.json` with no network at
  /// all. Searches the UNFILTERED catalogue is NOT what this does — it
  /// reuses [load], so a song from a hidden source stays unreachable by
  /// URL exactly as it is unreachable in the list.
  static Future<Song?> byId(String id) async {
    for (final s in await load()) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Force a network pull, e.g. from pull-to-refresh. Best-effort —
  /// a failure leaves the current catalogue in place.
  static Future<List<Song>> refresh() async {
    await _impl.refresh(force: true);
    return load();
  }

  /// Catalogue metadata (`generatedAt`, per-source counts, the
  /// attribution block). Null until [load] has run.
  static Map<String, dynamic>? get meta => _impl.cachedOrNull?.meta;

  /// When the loaded catalogue was generated upstream — shown on the
  /// page so "why don't I see the new song yet" has an answer.
  static DateTime? get generatedAt => _impl.cachedOrNull?.generatedAt;

  /// Distinct theme tags, most-used first. Drives the theme chip row.
  static List<String> distinctThemes(List<Song> songs) {
    final counts = <String, int>{};
    for (final s in songs) {
      for (final t in s.themes) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final list = counts.keys.toList();
    list.sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return list;
  }

  /// Distinct sources in a fixed order — fydt, cahaya, cdc — rather
  /// than by frequency, so the chip row doesn't reshuffle as the
  /// catalogue grows.
  static List<String> distinctSources(List<Song> songs) {
    const order = ['fydt', 'cahaya', 'cdc'];
    final present = songs.map((s) => s.source).toSet();
    return [
      ...order.where(present.contains),
      ...present.where((s) => !order.contains(s)).toList()..sort(),
    ];
  }

  /// Album names present in the catalogue, newest first.
  ///
  /// Only cgdc groups songs this way — one album per year, named like
  /// `2025 Nearer 更亲近` — so for a catalogue without albums this is
  /// empty and the filter section hides itself rather than showing an
  /// "All" chip with nothing beside it.
  ///
  /// Sorted on the leading year descending so next year's album lands
  /// at the front on its own, with no code change when cgdc publishes
  /// it. Anything without a leading year sorts last, alphabetically.
  static List<String> distinctAlbums(List<Song> songs) {
    final present = <String>{};
    for (final s in songs) {
      final a = s.album?.trim();
      if (a != null && a.isNotEmpty) present.add(a);
    }
    final list = present.toList();
    list.sort((a, b) {
      final cmp = _albumYear(b).compareTo(_albumYear(a));
      return cmp != 0 ? cmp : a.compareTo(b);
    });
    return list;
  }

  static final _yearPrefix = RegExp(r'^\s*(\d{4})');

  static int _albumYear(String album) =>
      int.tryParse(_yearPrefix.firstMatch(album)?.group(1) ?? '') ?? 0;

  /// Distinct languages, in a fixed order for the same reason.
  static List<String> distinctLanguages(List<Song> songs) {
    const order = ['zh', 'en', 'id'];
    final present = songs.map((s) => s.language).toSet();
    return [
      ...order.where(present.contains),
      ...present.where((s) => !order.contains(s)).toList()..sort(),
    ];
  }

  /// Count per source, for the header summary line.
  static Map<String, int> countBySource(List<Song> songs) {
    final counts = <String, int>{};
    for (final s in songs) {
      counts[s.source] = (counts[s.source] ?? 0) + 1;
    }
    return counts;
  }
}
