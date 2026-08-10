import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/song_playlist_service.dart';

/// Saving a song, wherever you happen to be.
///
/// These lived as private helpers inside songs_page, which meant the
/// Now Playing screen — the one place you are guaranteed to be while
/// deciding you like a song — could not offer either of them. Shared
/// rather than copied: two favourite buttons would drift.
/// One-tap favourite toggle.
///
/// Favourites is an ordinary playlist with a reserved id, so this is
/// just a shortcut into the same store the Playlists page reads —
/// no parallel state to keep in sync.
class SongFavouriteButton extends StatelessWidget {
  final Song song;
  final String locale;
  const SongFavouriteButton(
      {super.key, required this.song, required this.locale});

  @override
  Widget build(BuildContext context) {
    final service = SongPlaylistService.instance;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final on = service.isFavourite(song);
        return IconButton(
          icon: Icon(
            on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 22,
            color: on ? scheme.error : null,
          ),
          tooltip: uiStrings['songsFavourites']?[locale] ?? 'Favourites',
          onPressed: () => service.toggleFavourite(song),
        );
      },
    );
  }
}

void showAddToPlaylistSheet(BuildContext context, Song song, String locale) {
  final service = SongPlaylistService.instance;
  service.load();
  showModalBottomSheet<void>(
    // useSafeArea: without it Flutter wraps the sheet in
    // MediaQuery.removePadding(removeTop: true), so any SafeArea
    // INSIDE the sheet sees padding.top == 0 and does nothing —
    // the header then draws under the clock and the notch.
    useSafeArea: true,
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final playlists = service.ordered;
          final containing = service.playlistIdsContaining(song);
          return ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  uiStrings['songsAddToPlaylist']?[locale] ??
                      'Add to playlist',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              for (final p in playlists)
                ListTile(
                  enabled: !p.isSmart,
                  leading: Icon(
                    p.isFavourites
                        ? Icons.favorite_rounded
                        : (p.isSmart
                            ? Icons.auto_awesome_motion_rounded
                            : Icons.queue_music_rounded),
                  ),
                  title: Text(p.isFavourites
                      ? (uiStrings['songsFavourites']?[locale] ??
                          'Favourites')
                      : p.name),
                  subtitle: p.isSmart
                      ? Text(uiStrings['songsSmartPlaylist']?[locale] ??
                          'saved filter')
                      : null,
                  trailing: containing.contains(p.id)
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: p.isSmart
                      ? null
                      : () {
                          containing.contains(p.id)
                              ? service.removeSong(p, song)
                              : service.addSong(p, song);
                        },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: Text(uiStrings['songsNewPlaylist']?[locale] ??
                    'New playlist'),
                onTap: () async {
                  final created = await service.create(song.title);
                  await service.addSong(created, song);
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}
