import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/song_playlist_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/route_paths.dart' show songShareUrl;

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

/// Share this song as a link that OPENS this song.
///
/// Added to `song_actions.dart` on 2026-09-07 for the same reason
/// [SongFavouriteButton] moved here a month earlier, and reported the
/// same way: the button existed only on the songs list's detail sheet,
/// so the screen you are actually on when you decide to pass a song
/// on — Now Playing — could not do it. The user's words were "还是不能
/// share", from the player, with the share already shipped.
///
/// **The payload is the bare link and nothing else** — no title line,
/// no lyrics.
///
/// It carried a `title\nlink` pair for one day. The user asked for the
/// change in the same breath as reporting that a shared link had landed
/// them back in the Bible reader: "我们只要一个link按完那个share后".
/// Those two are probably the same fault. A message whose first line is
/// text and whose second is a URL is a blob that the receiving app has
/// to guess at, and the common guesses — linkify the whole thing,
/// linkify up to the first delimiter, build a preview card from a
/// truncated href — all end at an origin with the `?song=` query gone,
/// which boots the app to whatever it was last showing. One bare URL
/// has nothing to guess at.
///
/// Lyrics were never in it and still are not: the detail sheet's Lyrics
/// section has its own copy button for anyone who wants the words on
/// purpose, and a share that quietly carried them would push a
/// publisher's text into a group chat every time someone meant to pass
/// on a song.
///
/// `title:` is still handed to the platform share sheet — that is the
/// dialog's own heading, not part of what gets pasted. The `url:` field
/// is deliberately NOT set alongside it: a target that renders both
/// would show the link twice, which is the thing being fixed.
///
/// [size] exists because the app bars this sits in are not all the same
/// density — the sheet header runs 20px icons, the player's transport
/// side runs 22px — and a share icon that is the odd one out in its own
/// row reads as a different KIND of button.
class SongShareButton extends StatelessWidget {
  final Song song;
  final String locale;
  final double size;
  const SongShareButton({
    super.key,
    required this.song,
    required this.locale,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.share_outlined, size: size),
      tooltip: uiStrings['share']?[locale] ?? 'Share',
      onPressed: () => ClipboardHelper.shareOrCopy(
        context,
        songShareUrl(song.id),
        title: song.title,
      ),
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
