import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/song_playlist_service.dart';
import 'package:yswords/services/song_file_saver.dart';
import 'package:yswords/services/song_player_service.dart' show SongPlayerService;
import 'package:yswords/utils/floating_toast.dart';

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

/// One file the reader can save from a song: its label key, the URL as
/// the player would fetch it, and the name and type it lands as.
class SongSaveOption {
  const SongSaveOption({
    required this.labelKey,
    required this.fallback,
    required this.url,
    required this.fileName,
    required this.mime,
  });
  final String labelKey;
  final String fallback;
  final String url;
  final String fileName;
  final String mime;
}

/// Everything [song] offers as a file, in the order the player's own
/// chips use — the sung track, the sing-along, the instrumental, then
/// the score. A song with no audio and no score offers nothing, and the
/// button for it is not drawn.
List<SongSaveOption> songSaveOptions(Song song) {
  String ext(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final m = RegExp(r'\.([A-Za-z0-9]{2,4})$').firstMatch(path);
    final e = m?.group(1)?.toLowerCase();
    return (e == null || e.isEmpty) ? 'mp3' : e;
  }

  String mimeOf(String e) => switch (e) {
        'mp3' => 'audio/mpeg',
        'm4a' || 'mp4' => 'audio/mp4',
        'aac' => 'audio/aac',
        'wav' => 'audio/wav',
        'ogg' || 'oga' => 'audio/ogg',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

  SongSaveOption? audio(String key, String fallback, String? url,
      String suffix) {
    if (url == null || url.isEmpty) return null;
    final e = ext(url);
    return SongSaveOption(
      labelKey: key,
      fallback: fallback,
      url: SongPlayerService.resolvePlaybackUrl(url),
      fileName: safeFileName('${song.title}$suffix', extension: e),
      mime: mimeOf(e),
    );
  }

  final vocalUrl = song.audioUrl ??
      (song.audioTracks.isNotEmpty ? song.audioTracks.first.url : null);
  // Not `?element`: that is Dart 3.8, and this project pins lower.
  final out = <SongSaveOption>[
    for (final o in [
      audio('songsTrackVocal', 'Song', vocalUrl, ''),
      audio('songsTrackAccompaniment', 'Sing-along', song.accompanimentUrl,
          ' (伴唱)'),
      audio('songsTrackInstrumental', 'Instrumental', song.instrumentalUrl,
          ' (伴奏)'),
    ])
      if (o != null) o,
  ];
  final score = song.scoreUrl;
  if (score != null && score.isNotEmpty) {
    out.add(SongSaveOption(
      labelKey: 'songsSaveScore',
      fallback: 'Score (PDF)',
      url: SongPlayerService.resolvePlaybackUrl(score),
      fileName: safeFileName(song.title, extension: 'pdf'),
      mime: 'application/pdf',
    ));
  }
  return out;
}

/// 「保存文件」: the song's audio or score, saved where the reader can
/// find it — see `song_file_saver.dart` for where that is per platform.
/// Absent when the build cannot save files or the song offers none.
class SongSaveButton extends StatelessWidget {
  const SongSaveButton({
    super.key,
    required this.song,
    required this.locale,
    this.size = 20,
  });

  final Song song;
  final String locale;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!SongFileSaver.isSupported) return const SizedBox.shrink();
    final options = songSaveOptions(song);
    if (options.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon: Icon(Icons.download_outlined, size: size),
      tooltip: uiStrings['songsSaveFile']?[locale] ?? 'Save file',
      onPressed: () => showSongSaveSheet(context, song, locale, options),
    );
  }
}

void showSongSaveSheet(
    BuildContext context, Song song, String locale, List<SongSaveOption> options) {
  showModalBottomSheet<void>(
    useSafeArea: true,
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              uiStrings['songsSaveFileTitle']?[locale] ?? 'Save to this device',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          for (final o in options)
            ListTile(
              leading: Icon(o.mime == 'application/pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.audiotrack_outlined),
              title: Text(uiStrings[o.labelKey]?[locale] ?? o.fallback),
              subtitle: Text(o.fileName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _saveWithFeedback(context, o, locale);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _saveWithFeedback(
    BuildContext context, SongSaveOption o, String locale) async {
  final scheme = Theme.of(context).colorScheme;
  showFloatingToast(
    context,
    message: uiStrings['songsSaving']?[locale] ?? 'Saving…',
    icon: Icons.downloading_outlined,
    background: scheme.inverseSurface,
    duration: const Duration(milliseconds: 1200),
  );
  final outcome =
      await SongFileSaver.save(url: o.url, fileName: o.fileName, mime: o.mime);
  if (!context.mounted) return;
  switch (outcome) {
    case SaveSaved(location: 'browser'):
      showFloatingToast(context,
          message: uiStrings['songsSavedByBrowser']?[locale] ??
              'Your browser is downloading it.',
          icon: Icons.check_circle_outline,
          background: scheme.inverseSurface);
    case SaveSaved(location: 'files-app'):
      showFloatingToast(context,
          message: uiStrings['songsSavedToFilesApp']?[locale] ??
              'Saved. Find it in Files → On My iPhone → 雅伟之言.',
          icon: Icons.check_circle_outline,
          background: scheme.inverseSurface,
          duration: const Duration(milliseconds: 3200));
    case SaveSaved(:final location):
      showFloatingToast(context,
          message: (uiStrings['songsSavedTo']?[locale] ?? 'Saved to {where}')
              .replaceAll('{where}', location),
          icon: Icons.check_circle_outline,
          background: scheme.inverseSurface,
          duration: const Duration(milliseconds: 3200));
    case SaveFailed(:final reason):
      debugPrint('[SongSaveButton] save failed: $reason');
      showFloatingToast(context,
          message: uiStrings['songsSaveFailed']?[locale] ??
              'Could not save it. Try again in a moment.',
          icon: Icons.error_outline,
          background: scheme.error);
  }
}
