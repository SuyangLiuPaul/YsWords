import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_playlist.dart';
import 'package:yswords/pages/now_playing_page.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_playlist_service.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// What is actually inside one playlist.
///
/// The Playlists page could create, rename, delete and play a list but
/// never show it — `reorder` and `removeSong` had existed on the
/// service, with tests, and no way to reach them. So a song added by
/// mistake was stuck there permanently, and the order a static
/// playlist plays in was whatever order things happened to be added.
///
/// Takes an **id**, not a [SongPlaylist]. Every mutation republishes
/// the list, and a page holding a snapshot would keep rendering the
/// state from when it was pushed — the same stale-snapshot trap the
/// service guards against internally with `_live`.
class SongPlaylistDetailPage extends StatefulWidget {
  final String playlistId;
  const SongPlaylistDetailPage({super.key, required this.playlistId});

  @override
  State<SongPlaylistDetailPage> createState() =>
      _SongPlaylistDetailPageState();
}

class _SongPlaylistDetailPageState extends State<SongPlaylistDetailPage> {
  final _service = SongPlaylistService.instance;
  Future<List<Song>>? _catalogue;

  @override
  void initState() {
    super.initState();
    _catalogue = SongService.load();
    _service.load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(
        ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width));

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final playlist = _find();
        final title = playlist == null
            ? (uiStrings['songsPlaylists']?[locale] ?? 'Playlists')
            : _titleOf(playlist, locale);

        return Scaffold(
          appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(title, overflow: TextOverflow.ellipsis),
            actions: const [LanguageSwitcherButton(), HomeIconButton()],
          ),
          body: playlist == null
              // Deleted from another screen while this one was open.
              // Say so rather than render an empty list that looks like
              // a playlist which lost its songs.
              ? Center(
                  child: Text(
                    uiStrings['songsPlaylistGone']?[locale] ??
                        'This playlist no longer exists.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : FutureBuilder<List<Song>>(
                  future: _catalogue,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final songs = playlist.resolve(snap.data ?? const []);
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: _Body(
                          playlist: playlist,
                          songs: songs,
                          settings: settings,
                          scheme: scheme,
                          locale: locale,
                          onPlay: (index, shuffle) =>
                              _play(playlist, songs, index, shuffle, locale),
                          onReorder: (from, to) =>
                              _service.reorder(playlist, from, to),
                          onRemove: (song) => _remove(playlist, song, locale),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  SongPlaylist? _find() {
    for (final p in _service.playlists) {
      if (p.id == widget.playlistId) return p;
    }
    return null;
  }

  static String _titleOf(SongPlaylist p, String locale) => p.isFavourites
      ? (uiStrings['songsFavourites']?[locale] ?? 'Favourites')
      : p.name;

  Future<void> _play(SongPlaylist playlist, List<Song> songs, int startIndex,
      bool shuffle, String locale) async {
    final messenger = ScaffoldMessenger.of(context);
    final player = SongPlayerService.instance;
    await player.playQueue(
      songs,
      // By id: fromSongs drops songs with no playable track — and an
      // instrumental-only playlist with skip can drop most of them —
      // so a row number from this page would start on the wrong song.
      startSongId:
          startIndex >= 0 && startIndex < songs.length
              ? songs[startIndex].id
              : null,
      shuffle: shuffle,
      preference: playlist.preference,
      fallback: playlist.fallback,
      label: _titleOf(playlist, locale),
    );
    if (!mounted) return;
    if (player.queue.isEmpty) {
      // An instrumental-only playlist with skip can resolve to nothing.
      messenger.showSnackBar(SnackBar(
        content: Text(uiStrings['songsQueueEmpty']?[locale] ??
            'None of these songs have playable audio.'),
      ));
      return;
    }
    pushPage(const NowPlayingPage());
  }

  Future<void> _remove(
      SongPlaylist playlist, Song song, String locale) async {
    final messenger = ScaffoldMessenger.of(context);
    final index = playlist.songIds.indexOf(song.id);
    await _service.removeSong(playlist, song);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
          uiStrings['songsRemovedFromPlaylist']?[locale] ?? 'Removed.'),
      // Removing is one tap with no confirmation, which is right for
      // something this cheap — as long as it is reversible. Undo puts
      // the song back where it was, not on the end.
      action: SnackBarAction(
        label: uiStrings['undo']?[locale] ?? 'Undo',
        onPressed: () async {
          await _service.addSong(playlist, song);
          if (index >= 0) {
            final now = _find();
            if (now != null) {
              await _service.reorder(
                  now, now.songIds.length - 1, index);
            }
          }
        },
      ),
    ));
  }
}

class _Body extends StatelessWidget {
  final SongPlaylist playlist;
  final List<Song> songs;
  final AppSettings settings;
  final ColorScheme scheme;
  final String locale;
  final void Function(int startIndex, bool shuffle) onPlay;
  final void Function(int from, int to) onReorder;
  final void Function(Song song) onRemove;

  const _Body({
    required this.playlist,
    required this.songs,
    required this.settings,
    required this.scheme,
    required this.locale,
    required this.onPlay,
    required this.onReorder,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            playlist.isSmart
                ? (uiStrings['songsSmartPlaylistNote']?[locale] ??
                    'A saved filter — nothing matches it right now.')
                : (uiStrings['songsPlaylistEmpty']?[locale] ??
                    'Nothing here yet.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: [
        _Header(
          playlist: playlist,
          count: songs.length,
          scheme: scheme,
          locale: locale,
          onPlay: onPlay,
        ),
        Expanded(
          // A smart playlist's order comes from the catalogue, so
          // dragging a row would be a promise the model cannot keep —
          // it renders as a plain list instead of a reorderable one.
          child: playlist.isSmart
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: songs.length,
                  itemBuilder: (_, i) => _Row(
                    key: ValueKey(songs[i].id),
                    song: songs[i],
                    index: i,
                    settings: settings,
                    scheme: scheme,
                    locale: locale,
                    reorderable: false,
                    onTap: () => onPlay(i, false),
                    onRemove: null,
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: songs.length,
                  // onReorderItem, not the deprecated onReorder: it
                  // reports newIndex already adjusted for the removed
                  // row, which is exactly the convention the service's
                  // reorder() uses (remove, then insert). With the old
                  // callback every downward drag landed one row short
                  // unless the caller subtracted 1 itself.
                  onReorderItem: onReorder,
                  itemBuilder: (_, i) => _Row(
                    key: ValueKey(songs[i].id),
                    song: songs[i],
                    index: i,
                    settings: settings,
                    scheme: scheme,
                    locale: locale,
                    reorderable: true,
                    onTap: () => onPlay(i, false),
                    onRemove: () => onRemove(songs[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final SongPlaylist playlist;
  final int count;
  final ColorScheme scheme;
  final String locale;
  final void Function(int startIndex, bool shuffle) onPlay;

  const _Header({
    required this.playlist,
    required this.count,
    required this.scheme,
    required this.locale,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final hint = playlist.isSmart
        ? (uiStrings['songsSmartPlaylistNote']?[locale] ??
            'A saved filter — new matches appear here on their own.')
        : (uiStrings['songsDragToReorder']?[locale] ??
            'Press and hold a song to reorder');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap, not Row: at 320px the count plus two labelled buttons
          // overflows, and a hard Row would throw.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                      uiStrings['songsPlayAll']?[locale] ?? 'Play all',
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => onPlay(0, false),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: Text(
                      uiStrings['songsShuffle']?[locale] ?? 'Shuffle',
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => onPlay(0, true),
                ),
              ]),
            ],
          ),
          Text(
            hint,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Song song;
  final int index;
  final AppSettings settings;
  final ColorScheme scheme;
  final String locale;
  final bool reorderable;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _Row({
    super.key,
    required this.song,
    required this.index,
    required this.settings,
    required this.scheme,
    required this.locale,
    required this.reorderable,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final playing = SongPlayerService.instance.current?.id == song.id;
    final subtitle = <String>[
      localizedSongSource(song.source, locale),
      if (song.album != null) song.album!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: playing
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontFamilyFallback: kCjkFontFallback,
                          fontSize: 14,
                          fontWeight:
                              playing ? FontWeight.w700 : FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // A song with no audio still belongs in a playlist —
                // it may be there for its score or video — so mark it
                // rather than hide it.
                if (!song.hasPlayableAudio)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.music_off_rounded,
                        size: 16, color: scheme.onSurfaceVariant),
                  ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: uiStrings['songsRemoveFromPlaylist']?[locale],
                    color: scheme.onSurfaceVariant,
                    onPressed: onRemove,
                  ),
                if (reorderable)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.drag_handle_rounded,
                          size: 20, color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
