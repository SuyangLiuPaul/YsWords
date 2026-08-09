import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_playlist.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/pages/now_playing_page.dart';
import 'package:yswords/pages/song_playlist_detail_page.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_playlist_service.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Playlists — favourites, curated lists, and saved filters.
class SongPlaylistsPage extends StatefulWidget {
  const SongPlaylistsPage({super.key});

  @override
  State<SongPlaylistsPage> createState() => _SongPlaylistsPageState();
}

class _SongPlaylistsPageState extends State<SongPlaylistsPage> {
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

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['songsPlaylists']?[locale] ?? 'Playlists'),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: FutureBuilder<List<Song>>(
        future: _catalogue,
        builder: (context, snap) {
          final catalogue = snap.data ?? const <Song>[];
          return ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final playlists = _service.ordered;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: playlists.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      if (i == playlists.length) {
                        return _NewPlaylistButton(
                          locale: locale,
                          onCreate: (name) => _service.create(name),
                        );
                      }
                      final p = playlists[i];
                      return _PlaylistTile(
                        playlist: p,
                        songs: p.resolve(catalogue),
                        settings: settings,
                        scheme: scheme,
                        locale: locale,
                        service: _service,
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final SongPlaylist playlist;
  final List<Song> songs;
  final AppSettings settings;
  final ColorScheme scheme;
  final String locale;
  final SongPlaylistService service;

  const _PlaylistTile({
    required this.playlist,
    required this.songs,
    required this.settings,
    required this.scheme,
    required this.locale,
    required this.service,
  });

  String get _title => playlist.isFavourites
      ? (uiStrings['songsFavourites']?[locale] ?? 'Favourites')
      : playlist.name;

  Future<void> _play(BuildContext context, {bool shuffle = false}) async {
    final player = SongPlayerService.instance;
    await player.playQueue(
      songs,
      shuffle: shuffle,
      preference: playlist.preference,
      fallback: playlist.fallback,
      label: _title,
    );
    if (!context.mounted) return;
    if (player.queue.isEmpty) {
      // A playlist set to instrumental-only with skip can resolve to
      // nothing — say so rather than appear to ignore the tap.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uiStrings['songsQueueEmpty']?[locale] ??
            'None of these songs have playable audio.'),
      ));
      return;
    }
    pushPage(const NowPlayingPage());
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      '${songs.length}',
      if (playlist.isSmart)
        uiStrings['songsSmartPlaylist']?[locale] ?? 'saved filter',
      if (playlist.preference != TrackPreference.vocal)
        playlist.preference == TrackPreference.instrumental
            ? (uiStrings['songsTrackInstrumental']?[locale] ?? 'Instrumental')
            : (uiStrings['songsTrackAccompaniment']?[locale] ??
                'Accompaniment'),
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        // Tapping opens the playlist rather than playing it. Play was
        // the whole tile's job when there was nowhere to open — now
        // that its contents have a page, opening is the safer default:
        // it is one tap to play from there, and a mis-tap that starts
        // 47 songs in the car is worse than one that shows a list.
        onTap: () => pushPage(
            SongPlaylistDetailPage(playlistId: playlist.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Icon(
                playlist.isFavourites
                    ? Icons.favorite_rounded
                    : (playlist.isSmart
                        ? Icons.auto_awesome_motion_rounded
                        : Icons.queue_music_rounded),
                color: playlist.isFavourites
                    ? scheme.error
                    : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (songs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  tooltip: uiStrings['songsPlayAll']?[locale],
                  color: scheme.primary,
                  onPressed: () => _play(context),
                ),
              if (songs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.shuffle_rounded, size: 20),
                  tooltip: uiStrings['songsShuffle']?[locale],
                  color: scheme.onSurfaceVariant,
                  onPressed: () => _play(context, shuffle: true),
                ),
              PopupMenuButton<String>(
                tooltip: '',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) => _onMenu(context, v),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'preference',
                    child: Text(uiStrings['songsTrackPreference']?[locale] ??
                        'Track preference'),
                  ),
                  if (playlist.canRename)
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(uiStrings['rename']?[locale] ?? 'Rename'),
                    ),
                  if (playlist.canDelete)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(uiStrings['delete']?[locale] ?? 'Delete'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenu(BuildContext context, String action) {
    switch (action) {
      case 'rename':
        _promptRename(context);
        break;
      case 'delete':
        _confirmDelete(context);
        break;
      case 'preference':
        _pickPreference(context);
        break;
    }
  }

  void _promptRename(BuildContext context) {
    final controller = TextEditingController(text: playlist.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(uiStrings['rename']?[locale] ?? 'Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) {
            service.rename(playlist, v);
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              service.rename(playlist, controller.text);
              Navigator.of(ctx).pop();
            },
            child: Text(uiStrings['save']?[locale] ?? 'Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_title),
        content: Text(uiStrings['songsDeletePlaylist']?[locale] ??
            'Delete this playlist? The songs themselves are not removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () {
              service.delete(playlist);
              Navigator.of(ctx).pop();
            },
            child: Text(uiStrings['delete']?[locale] ?? 'Delete'),
          ),
        ],
      ),
    );
  }

  /// The quiet-music control: which mix this playlist plays, and what
  /// to do when a song has not got it.
  void _pickPreference(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ListTile + a trailing check rather than RadioListTile:
            // groupValue/onChanged were deprecated in favour of a
            // RadioGroup ancestor, and a plain tile keeps this sheet
            // simple while staying obvious about which is selected.
            for (final entry in <(TrackPreference, TrackFallback, String)>[
              (
                TrackPreference.vocal,
                TrackFallback.useVocal,
                uiStrings['songsTrackVocal']?[locale] ?? 'Song'
              ),
              (
                TrackPreference.instrumental,
                TrackFallback.skip,
                '${uiStrings['songsTrackInstrumental']?[locale] ?? 'Instrumental'}'
                    ' · ${uiStrings['songsSkipMissing']?[locale] ?? 'skip if missing'}'
              ),
              (
                TrackPreference.instrumental,
                TrackFallback.useVocal,
                '${uiStrings['songsTrackInstrumental']?[locale] ?? 'Instrumental'}'
                    ' · ${uiStrings['songsFallbackVocal']?[locale] ?? 'else the sung take'}'
              ),
              (
                TrackPreference.accompaniment,
                TrackFallback.skip,
                '${uiStrings['songsTrackAccompaniment']?[locale] ?? 'Accompaniment'}'
                    ' · ${uiStrings['songsSkipMissing']?[locale] ?? 'skip if missing'}'
              ),
            ])
              ListTile(
                title: Text(entry.$3),
                trailing: '${entry.$1.name}/${entry.$2.name}' ==
                        '${playlist.preference.name}/${playlist.fallback.name}'
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
                onTap: () {
                  service.setPreference(playlist, entry.$1, entry.$2);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NewPlaylistButton extends StatelessWidget {
  final String locale;
  final void Function(String name) onCreate;
  const _NewPlaylistButton({required this.locale, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(uiStrings['songsNewPlaylist']?[locale] ?? 'New playlist'),
      onPressed: () {
        final controller = TextEditingController();
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
                Text(uiStrings['songsNewPlaylist']?[locale] ?? 'New playlist'),
            content: TextField(
              controller: controller,
              autofocus: true,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) onCreate(v);
                Navigator.of(ctx).pop();
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    onCreate(controller.text);
                  }
                  Navigator.of(ctx).pop();
                },
                child: Text(uiStrings['create']?[locale] ?? 'Create'),
              ),
            ],
          ),
        );
      },
    );
  }
}
