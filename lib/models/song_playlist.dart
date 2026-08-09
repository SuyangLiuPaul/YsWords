import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';

/// How a playlist decides what is in it.
enum PlaylistKind {
  /// Built-in, always present, cannot be deleted or renamed. One tap
  /// on any row adds to it.
  favourites,

  /// A fixed list of songs the user curated.
  static_,

  /// A saved FILTER rather than a saved list.
  ///
  /// "福音电台 + 安静 + 有伴奏" stays correct as the catalogue grows —
  /// the church added 63 songs in one sync this week, and a snapshot
  /// taken before that would silently have gone stale. This is the
  /// honest answer to "play my filter", which is what people actually
  /// mean when they build one.
  smart,
}

/// The filter behind a smart playlist. Mirrors the Songs page's own
/// filter state so "save this filter" is a literal copy.
class PlaylistFilter {
  final String language; // 'all' | zh | en | id
  final String source; // 'all' | fydt | cahaya | cdc | cgdc
  final String theme; // 'all' | theme key
  final String book; // 'all' | English book name
  final String media; // 'all' | audio | video | score
  final String query;

  const PlaylistFilter({
    this.language = 'all',
    this.source = 'all',
    this.theme = 'all',
    this.book = 'all',
    this.media = 'all',
    this.query = '',
  });

  bool get isEmpty =>
      language == 'all' &&
      source == 'all' &&
      theme == 'all' &&
      book == 'all' &&
      media == 'all' &&
      query.trim().isEmpty;

  /// Apply to a catalogue. Deliberately duplicates the page's filter
  /// logic rather than sharing it, because the page's version also
  /// handles sorting and live text entry; keeping them separate means
  /// a smart playlist cannot break when the page's UI changes.
  List<Song> apply(List<Song> all) {
    Iterable<Song> out = all;
    if (language != 'all') out = out.where((s) => s.language == language);
    if (source != 'all') out = out.where((s) => s.source == source);
    if (theme != 'all') out = out.where((s) => s.themes.contains(theme));
    if (book != 'all') out = out.where((s) => s.verseBook == book);
    switch (media) {
      case 'audio':
        out = out.where((s) => s.hasAudio);
        break;
      case 'video':
        out = out.where((s) => s.hasVideo);
        break;
      case 'score':
        out = out.where((s) => s.scoreUrl != null);
        break;
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((s) =>
          s.title.toLowerCase().contains(q) ||
          (s.code?.toLowerCase().contains(q) ?? false) ||
          (s.album?.toLowerCase().contains(q) ?? false) ||
          s.themes.any((t) => t.toLowerCase().contains(q)));
    }
    return out.toList();
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'source': source,
        'theme': theme,
        'book': book,
        'media': media,
        'query': query,
      };

  factory PlaylistFilter.fromJson(Map<String, dynamic> j) => PlaylistFilter(
        language: j['language'] as String? ?? 'all',
        source: j['source'] as String? ?? 'all',
        theme: j['theme'] as String? ?? 'all',
        book: j['book'] as String? ?? 'all',
        media: j['media'] as String? ?? 'all',
        query: j['query'] as String? ?? '',
      );
}

/// A user playlist.
class SongPlaylist {
  final String id;
  final String name;
  final PlaylistKind kind;

  /// Song ids, in the user's order. Empty for smart playlists.
  final List<String> songIds;

  /// The saved filter. Null for static playlists and favourites.
  final PlaylistFilter? filter;

  /// Which rendering to play. A playlist carries its own preference so
  /// 「开车安静」 can be instrumental-only while 「敬拜」 stays vocal —
  /// which is the entire reason the catalogue's 208 instrumental and
  /// 108 accompaniment tracks are worth having.
  final TrackPreference preference;

  /// What to do when a song has no track of the preferred kind.
  /// [TrackFallback.skip] is what makes an instrumental playlist
  /// trustworthy in a car: you are never surprised by vocals.
  final TrackFallback fallback;

  final String? createdAt;

  const SongPlaylist({
    required this.id,
    required this.name,
    required this.kind,
    this.songIds = const [],
    this.filter,
    this.preference = TrackPreference.vocal,
    this.fallback = TrackFallback.useVocal,
    this.createdAt,
  });

  static const favouritesId = '__favourites__';

  bool get isFavourites => kind == PlaylistKind.favourites;
  bool get isSmart => kind == PlaylistKind.smart;

  /// Renaming and deleting are blocked only for favourites — it is a
  /// fixed part of the UI, not something the user made.
  bool get canRename => !isFavourites;
  bool get canDelete => !isFavourites;

  /// Resolve to actual songs against a catalogue.
  ///
  /// Static playlists keep the user's order, which `where` on the
  /// catalogue would lose — so index the catalogue and walk the ids.
  List<Song> resolve(List<Song> catalogue) {
    if (isSmart) return filter?.apply(catalogue) ?? const [];
    final byId = {for (final s in catalogue) s.id: s};
    return [
      for (final id in songIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  SongPlaylist copyWith({
    String? name,
    List<String>? songIds,
    PlaylistFilter? filter,
    TrackPreference? preference,
    TrackFallback? fallback,
  }) =>
      SongPlaylist(
        id: id,
        name: name ?? this.name,
        kind: kind,
        songIds: songIds ?? this.songIds,
        filter: filter ?? this.filter,
        preference: preference ?? this.preference,
        fallback: fallback ?? this.fallback,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'songIds': songIds,
        if (filter != null) 'filter': filter!.toJson(),
        'preference': preference.name,
        'fallback': fallback.name,
        'createdAt': createdAt,
      };

  factory SongPlaylist.fromJson(Map<String, dynamic> j) {
    final rawFilter = j['filter'];
    return SongPlaylist(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      kind: PlaylistKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => PlaylistKind.static_,
      ),
      songIds:
          ((j['songIds'] as List?) ?? const []).map((e) => '$e').toList(),
      filter: rawFilter is Map
          ? PlaylistFilter.fromJson(rawFilter.cast<String, dynamic>())
          : null,
      preference: TrackPreference.values.firstWhere(
        (p) => p.name == j['preference'],
        orElse: () => TrackPreference.vocal,
      ),
      fallback: TrackFallback.values.firstWhere(
        (f) => f.name == j['fallback'],
        orElse: () => TrackFallback.useVocal,
      ),
      createdAt: j['createdAt'] as String?,
    );
  }
}
