import 'package:flutter/material.dart';
import 'dart:async' show unawaited;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_playlist.dart';
import 'package:yswords/pages/song_downloads_page.dart';
import 'package:yswords/pages/song_playlists_page.dart';
import 'package:yswords/pages/song_score_page.dart';
import 'package:yswords/pages/song_video_page.dart';
import 'package:yswords/services/song_download_service.dart';
import 'package:yswords/services/song_download_types.dart';
import 'package:yswords/services/song_playlist_service.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/app_scroll_behavior.dart'
    show kSelectableTextPhysics;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/song_actions.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/scroll_to_top_on_status_bar_tap.dart';
import 'package:yswords/widgets/remote_image.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Church-songs directory page.
///
/// Round 56 shipped this as a pure index — title, URL, theme tags —
/// where every tap bounced out to the publishing church's own site.
/// It was deleted in v1.3.126 when those links went stale after
/// fydt.org migrated its backend.
///
/// 2026-08-09 (v2) rebuilds it against fydt.org's `fydt-api/v1` JSON
/// API, adds cgdc.hk's yearly camp songbooks, and plays the media
/// in-app rather than linking out. 559 songs shown, every one of them
/// with playable audio; each row names its source.
///
/// The catalogue upstream holds 606 across four sites. Cahaya
/// (Indonesian) is hidden here because all 47 of its songs live on
/// SoundCloud or YouTube, neither of which exposes a stream URL a
/// player can open — see `SongService.hiddenSources`, which is one set
/// and reversible if that ever changes.
///
/// The media streams from each church's own servers — nothing is
/// rehosted. All catalogues are published by our own church's
/// pastors, who approved in-app playback.
class SongsPage extends StatefulWidget {
  const SongsPage({super.key});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  Future<List<Song>>? _future;

  /// An AutoScrollController rather than a plain one, so the list can be
  /// sent to a row BY INDEX. Rows are variable height — titles wrap,
  /// theme chips wrap — so there is no offset arithmetic that would land
  /// on the right song.
  final _scrollCtrl = AutoScrollController();

  /// The list exactly as the user is seeing it, captured during build so
  /// the player listener can locate the playing song without redoing the
  /// whole filter and sort.
  List<Song> _visible = const [];

  /// The song the list has already been scrolled to, so repeated
  /// rebuilds do not keep re-scrolling to the same row.
  String? _scrolledToId;

  /// When the user last dragged the list themselves.
  ///
  /// Auto-advance yanking the list out from under someone who is
  /// browsing would be worse than the scrolling they asked to avoid, so
  /// a track change within [_userScrollGrace] of a manual drag is left
  /// alone. Arriving on the page fresh has no recent drag, so that case
  /// always scrolls — which is the one being asked for.
  DateTime? _userScrolledAt;
  static const _userScrollGrace = Duration(seconds: 6);

  /// 'all' | 'zh' | 'en' | 'id'.
  String _langFilter = 'all';
  /// 'all' | one of the source ids in songs.json (`fydt`, `cahaya`,
  /// `cdc`).
  String _sourceFilter = 'all';
  /// 'all' | 'audio' | 'video' | 'score'. Not every song in the
  /// catalogue has every medium — CDC publishes no video at all and
  /// ~23 of its mp3s were never uploaded — so this lets someone who
  /// specifically wants something to listen to or a score to print
  /// skip the rows that cannot give it to them.
  String _mediaFilter = 'all';
  /// 'all' | one of the auto-derived theme tags (Chinese key).
  String _themeFilter = 'all';
  /// 'all' | English book name when the song's verse field maps to
  /// a recognised Bible book. Aligned with sermons-page filter so
  /// the UX is consistent across the app.
  String _bookFilter = 'all';
  /// 'all' | an album name. cgdc releases one album a year
  /// (`2026 SAIL 乘風破浪`, `2025 Nearer 更亲近`, …), which is how that
  /// congregation actually refers to its songs — "the 2024 ones" — so
  /// a year picker is the filter they will reach for. Empty for every
  /// other source, and the section hides itself when no loaded song
  /// has an album.
  String _albumFilter = 'all';
  String _query = '';
  /// 'recent' (default — newest first by updatedAt) |
  /// 'added'  (newest first by firstSeenAt) |
  /// 'title'  (A→Z by title) |
  /// 'source' (catalogue order: source then code/title)
  String _sort = 'recent';

  @override
  void initState() {
    super.initState();
    _future = SongService.load();
    SongPlayerService.instance.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    SongPlayerService.instance.removeListener(_onPlayerChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Follow the playing song down the list.
  ///
  /// 2026-08-11, asked for by the user: "我在哪里按了歌曲，在这个 list
  /// 里面自动划到那个地方，不然我要划划划". With 559 rows and a queue
  /// that auto-advances, the playing song walks steadily away from
  /// whatever is on screen and finding it again is a long scroll.
  ///
  /// Deliberately does nothing when the user has just scrolled — see
  /// [_userScrolledAt]. Following the song is help; hijacking the
  /// viewport mid-browse is not.
  void _onPlayerChanged() {
    if (!mounted) return;
    final id = SongPlayerService.instance.current?.id;
    if (id == null || id == _scrolledToId) return;

    final since = _userScrolledAt == null
        ? null
        : DateTime.now().difference(_userScrolledAt!);
    if (since != null && since < _userScrollGrace) return;

    final row = _visible.indexWhere((s) => s.id == id);
    if (row < 0) return;   // playing something the current filter hides
    _scrolledToId = id;
    // +2: the intro card and the search/filter bar occupy 0 and 1.
    unawaited(_scrollCtrl.scrollToIndex(
      row + 2,
      preferPosition: AutoScrollPosition.middle,
      duration: const Duration(milliseconds: 450),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['songsPageTitle']?[locale] ?? 'Songs'),
        // LanguageSwitcherButton was added across the app while Songs
        // was deleted (v1.3.126–v1.4.11), so restoring the page from
        // its pre-deletion snapshot brought back an AppBar that had
        // missed the change. Every other page pairs it with the home
        // button — match them.
        actions: [
          if (SongDownloadService.isSupported)
            IconButton(
              icon: const Icon(Icons.download_for_offline_outlined),
              tooltip: uiStrings['songsDownloads']?[locale] ?? 'Downloads',
              onPressed: () => pushPage(const SongDownloadsPage(), routeName: '/songs/downloads'),
            ),
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: uiStrings['songsPlaylists']?[locale] ?? 'Playlists',
            onPressed: () => pushPage(const SongPlaylistsPage(), routeName: '/songs/playlists'),
          ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? const <Song>[];
          if (all.isEmpty) {
            return Center(
              child: Text(
                uiStrings['songsEmpty']?[locale] ??
                    'No songs available.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            );
          }
          final themes = SongService.distinctThemes(all);
          final availableBooks = _booksWithSongs(all);
          final albums = SongService.distinctAlbums(all);
          final filtered = _filter(all);
          final hasFilter = _langFilter != 'all' ||
              _sourceFilter != 'all' ||
              _themeFilter != 'all' ||
              _bookFilter != 'all' ||
              _albumFilter != 'all' ||
              _mediaFilter != 'all';
          // What the player listener searches to find the playing row.
          _visible = filtered;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                children: [
                  Expanded(
                    child: ScrollToTopOnStatusBarTap(
                      controller: _scrollCtrl,
                      child: NotificationListener<UserScrollNotification>(
                        // Only a DRAG counts as the user scrolling.
                        // `scrollToIndex` also emits ScrollNotifications,
                        // so listening to those would have the auto-
                        // scroll suppress its own next move.
                        onNotification: (n) {
                          if (n.direction != ScrollDirection.idle) {
                            _userScrolledAt = DateTime.now();
                          }
                          return false;
                        },
                        child: Scrollbar(
                controller: _scrollCtrl,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filtered.length + 2,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _IntroCard(
                          settings: settings, scheme: scheme);
                    }
                    if (i == 1) {
                      return _SearchAndFilterBar(
                        settings: settings,
                        scheme: scheme,
                        locale: locale,
                        query: _query,
                        hasActiveFilter: hasFilter,
                        langFilter: _langFilter,
                        sourceFilter: _sourceFilter,
                        themeFilter: _themeFilter,
                        bookFilter: _bookFilter,
                        albumFilter: _albumFilter,
                        mediaFilter: _mediaFilter,
                        sort: _sort,
                        availableThemes: themes,
                        availableBooks: availableBooks,
                        availableAlbums: albums,
                        availableSources:
                            SongService.distinctSources(all),
                        availableLanguages:
                            SongService.distinctLanguages(all),
                        matchCount: filtered.length,
                        totalCount: all.length,
                        onQuery: (v) => setState(() => _query = v),
                        onClearAll: () => setState(() {
                          _langFilter = 'all';
                          _sourceFilter = 'all';
                          _themeFilter = 'all';
                          _bookFilter = 'all';
                          _albumFilter = 'all';
                          _mediaFilter = 'all';
                        }),
                        onLangChanged: (v) =>
                            setState(() => _langFilter = v),
                        onSourceChanged: (v) =>
                            setState(() => _sourceFilter = v),
                        onThemeChanged: (v) =>
                            setState(() => _themeFilter = v),
                        onBookChanged: (v) =>
                            setState(() => _bookFilter = v),
                        onAlbumChanged: (v) =>
                            setState(() => _albumFilter = v),
                        onMediaChanged: (v) =>
                            setState(() => _mediaFilter = v),
                        onSortChanged: (v) =>
                            setState(() => _sort = v),
                        onPlayAll: (shuffle) =>
                            _playFiltered(filtered, shuffle, locale),
                        onSaveFilter: () => _saveFilterAsPlaylist(locale),
                        onDownloadAll: () =>
                            _downloadFiltered(filtered, locale),
                      );
                    }
                    final song = filtered[i - 2];
                    // Tagged so `scrollToIndex` can find this row. The
                    // index is the LIST index, not the song index — the
                    // intro card and the filter bar hold 0 and 1.
                    return AutoScrollTag(
                      key: ValueKey(song.id),
                      controller: _scrollCtrl,
                      index: i,
                      child: _SongTile(
                        song: song,
                        settings: settings,
                        scheme: scheme,
                        locale: locale,
                        // Tapping play starts the LIST at this song, not
                        // the song on its own. A one-song queue has
                        // nothing to skip to, which is why the lock
                        // screen's ⏮ ⏭ were dead — and queueing what the
                        // user is looking at is what every music app
                        // does anyway.
                        onPlay: () => _playFiltered(filtered, false, locale,
                            startSongId: song.id),
                      ),
                    );
                  },
                ),
              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Play the songs currently matching the filter as one queue.
  ///
  /// Acts on the FILTER, not the whole catalogue: narrow to 安静 +
  /// 有伴奏 and hit shuffle and you have a quiet driving playlist
  /// without saving anything first.
  Future<void> _playFiltered(
    List<Song> filtered,
    bool shuffle,
    String locale, {
    String? startSongId,
  }) async {
    final player = SongPlayerService.instance;
    await player.playQueue(
      filtered,
      shuffle: shuffle,
      // By id, not position: fromSongs drops unplayable songs, so a row
      // number taken from the visible list would land on the wrong one.
      startSongId: startSongId,
      label: _queueLabel(locale),
    );
    if (!mounted) return;
    // fromSongs drops anything with no playable audio, so a filter
    // that matched only SoundCloud-hosted rows yields an empty queue.
    // Say so rather than appearing to do nothing.
    if (player.queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uiStrings['songsQueueEmpty']?[locale] ??
            'None of these songs have playable audio.'),
      ));
    }
  }

  /// Queue the filtered songs for offline download, after telling the
  /// user what it will cost.
  ///
  /// The size is an ESTIMATE from duration at ~128 kbps — the
  /// catalogue does not publish file sizes, and quoting a precise
  /// figure we cannot know would be worse than admitting the range.
  /// Downloading all 559 would be multiple gigabytes, so the number
  /// goes in front of the decision, not after it.
  Future<void> _downloadFiltered(List<Song> filtered, String locale) async {
    final service = SongDownloadService.instance;
    await service.init();
    final pending =
        filtered.where((s) => s.hasPlayableAudio && !service.isDownloaded(s));
    final count = pending.length;
    if (count == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uiStrings['songsNoDownloads']?[locale] ??
            'Nothing to download.'),
      ));
      return;
    }
    final size = SongDownloadService.estimateBytes(pending);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            uiStrings['songsDownloadFiltered']?[locale] ?? 'Download'),
        content: Text('$count · '
            '${uiStrings['songsDownloadSize']?[locale] ?? 'about'} '
            '${formatDownloadBytes(size)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(uiStrings['songsDownload']?[locale] ?? 'Download'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await service.enqueue(pending);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(uiStrings['songsDownloadStarted']?[locale] ??
          'Added to the download queue.'),
      action: SnackBarAction(
        label: uiStrings['songsDownloads']?[locale] ?? 'Downloads',
        onPressed: () => pushPage(const SongDownloadsPage(), routeName: '/songs/downloads'),
      ),
    ));
  }

  /// Save the active filter as a smart playlist.
  ///
  /// Deliberately saves the FILTER, not the songs it currently
  /// matches: 63 songs joined the catalogue in one sync this week, and
  /// a snapshot taken beforehand would have quietly gone stale.
  Future<void> _saveFilterAsPlaylist(String locale) async {
    final suggested = _queueLabel(locale);
    final controller = TextEditingController(text: suggested);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(uiStrings['songsSaveFilter']?[locale] ??
            'Save this filter as a playlist'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(uiStrings['save']?[locale] ?? 'Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;

    await SongPlaylistService.instance.create(
      name,
      filter: PlaylistFilter(
        language: _langFilter,
        source: _sourceFilter,
        theme: _themeFilter,
        book: _bookFilter,
        album: _albumFilter,
        media: _mediaFilter,
        query: _query,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(uiStrings['songsSavedPlaylist']?[locale] ?? 'Saved.'),
      action: SnackBarAction(
        label: uiStrings['songsPlaylists']?[locale] ?? 'Playlists',
        onPressed: () => pushPage(const SongPlaylistsPage(), routeName: '/songs/playlists'),
      ),
    ));
  }

  /// A short name for what is playing, shown on the now-playing screen
  /// and in the OS media session.
  String _queueLabel(String locale) {
    final parts = <String>[
      // Album first when set: it is the most specific thing a user can
      // pick, and "2025 Nearer 更亲近" on the lock screen says more
      // than "CGDC · Chinese" ever would.
      if (_albumFilter != 'all') _albumFilter,
      if (_sourceFilter != 'all') localizedSongSource(_sourceFilter, locale),
      if (_langFilter != 'all') localizedSongLanguage(_langFilter, locale),
      if (_themeFilter != 'all') localizedSongTheme(_themeFilter, locale),
    ];
    if (parts.isEmpty) {
      return uiStrings['songsPageTitle']?[locale] ?? 'Songs';
    }
    return parts.join(' · ');
  }

  /// Set of English book names that at least one song's `verse`
  /// field maps to. Drives the book chip row in the filter sheet —
  /// books with no songs render dimmed (sermons-page parity).
  Set<String> _booksWithSongs(List<Song> all) {
    final out = <String>{};
    for (final s in all) {
      final b = s.verseBook;
      if (b != null) out.add(b);
    }
    return out;
  }

  List<Song> _filter(List<Song> all) {
    Iterable<Song> out = all;
    if (_langFilter != 'all') {
      out = out.where((s) => s.language == _langFilter);
    }
    if (_sourceFilter != 'all') {
      out = out.where((s) => s.source == _sourceFilter);
    }
    if (_themeFilter != 'all') {
      out = out.where((s) => s.themes.contains(_themeFilter));
    }
    if (_bookFilter != 'all') {
      out = out.where((s) => s.verseBook == _bookFilter);
    }
    if (_albumFilter != 'all') {
      out = out.where((s) => s.album?.trim() == _albumFilter);
    }
    switch (_mediaFilter) {
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
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((s) => s.matchesQuery(q));
    }
    final list = out.toList();
    _applySort(list);
    return list;
  }

  /// Order the matched songs by the user's chosen sort key.
  /// Implemented in-place so we don't allocate a second list.
  void _applySort(List<Song> list) {
    switch (_sort) {
      case 'recent':
        // Newest updatedAt first; ties broken by title for
        // stable ordering. Songs without timestamps (legacy
        // entries) sink to the bottom.
        list.sort((a, b) {
          final ax = a.updatedAt ?? '';
          final bx = b.updatedAt ?? '';
          final cmp = bx.compareTo(ax);
          return cmp != 0 ? cmp : a.title.compareTo(b.title);
        });
        break;
      case 'added':
        list.sort((a, b) {
          final ax = a.firstSeenAt ?? '';
          final bx = b.firstSeenAt ?? '';
          final cmp = bx.compareTo(ax);
          return cmp != 0 ? cmp : a.title.compareTo(b.title);
        });
        break;
      case 'title':
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'source':
        list.sort((a, b) {
          final src = a.source.compareTo(b.source);
          if (src != 0) return src;
          final ac = a.code ?? a.title;
          final bc = b.code ?? b.title;
          return ac.compareTo(bc);
        });
        break;
    }
  }
}

class _IntroCard extends StatelessWidget {
  final AppSettings settings;
  final ColorScheme scheme;
  const _IntroCard({required this.settings, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final locale = settings.locale;
    final title =
        uiStrings['songsIntroTitle']?[locale] ?? 'Church Songs Directory';
    final body = uiStrings['songsIntroBody']?[locale] ??
        'Songs from 福音电台 (fydt.org), Christian Disciples Church '
            'and CGDC Hong Kong. Tap ▶ to listen, or open an entry for '
            'the instrumental, music video, sheet music and lyrics.';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.library_music_rounded,
                  color: scheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
              fontSize: 12,
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round 56 (continued): refactored to mirror the sermons-page
/// pattern. Search field + Filter button inline; tapping the
/// button opens a modal sheet that hosts every filter (language,
/// source, theme, book). Active filters render below as deletable
/// InputChips. Theme labels run through `localizedSongTheme` so
/// 敬拜 displays as "Worship" / "敬拜" / "敬拜" depending on locale.
class _SearchAndFilterBar extends StatelessWidget {
  final AppSettings settings;
  final ColorScheme scheme;
  final String locale;
  final String query;
  final bool hasActiveFilter;
  final String langFilter;
  final String sourceFilter;
  final String themeFilter;
  final String bookFilter;
  final String albumFilter;
  final String mediaFilter;
  final String sort;
  final List<String> availableThemes;
  final Set<String> availableBooks;
  final List<String> availableAlbums;
  final List<String> availableSources;
  final List<String> availableLanguages;
  final int matchCount;
  final int totalCount;
  final ValueChanged<String> onQuery;
  final VoidCallback onClearAll;
  final ValueChanged<String> onLangChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<String> onBookChanged;
  final ValueChanged<String> onAlbumChanged;
  final ValueChanged<String> onMediaChanged;
  final ValueChanged<String> onSortChanged;
  /// Play the current filter result; the bool is 'shuffled'.
  final void Function(bool shuffle) onPlayAll;
  /// Save the active filter as a smart playlist.
  final VoidCallback onSaveFilter;
  /// Queue the filtered songs for offline download.
  final VoidCallback onDownloadAll;

  const _SearchAndFilterBar({
    required this.settings,
    required this.scheme,
    required this.locale,
    required this.query,
    required this.hasActiveFilter,
    required this.langFilter,
    required this.sourceFilter,
    required this.themeFilter,
    required this.bookFilter,
    required this.albumFilter,
    required this.mediaFilter,
    required this.sort,
    required this.availableThemes,
    required this.availableBooks,
    required this.availableAlbums,
    required this.availableSources,
    required this.availableLanguages,
    required this.matchCount,
    required this.totalCount,
    required this.onQuery,
    required this.onClearAll,
    required this.onLangChanged,
    required this.onSourceChanged,
    required this.onThemeChanged,
    required this.onBookChanged,
    required this.onAlbumChanged,
    required this.onMediaChanged,
    required this.onSortChanged,
    required this.onPlayAll,
    required this.onSaveFilter,
    required this.onDownloadAll,
  });

  @override
  Widget build(BuildContext context) {
    final searchHint = uiStrings['songsSearchHint']?[locale] ??
        'Search song title, theme, or code…';
    final filterLabel =
        uiStrings['songsFilterTitle']?[locale] ?? 'Filter';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: onQuery,
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize:
                      (settings.fontSize - 1).clamp(13.0, 17.0),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openFilterSheet(context),
              icon: Icon(
                hasActiveFilter
                    ? Icons.filter_list_alt
                    : Icons.filter_list,
                size: 18,
              ),
              label: Text(filterLabel,
                  style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: hasActiveFilter
                    ? scheme.primaryContainer
                        .withValues(alpha: 0.4)
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            // Round 56: sort picker. Compact PopupMenuButton — same
            // affordance as the IconButton+Menu pattern used in
            // sermon_detail_page.dart so the songs page feels
            // consistent with the rest of the app.
            PopupMenuButton<String>(
              tooltip: uiStrings['songsSortTooltip']?[locale] ??
                  'Sort',
              icon: const Icon(Icons.sort, size: 20),
              initialValue: sort,
              onSelected: onSortChanged,
              itemBuilder: (_) => [
                _sortItem('recent',
                    uiStrings['songsSortRecent']?[locale] ??
                        'Recently updated',
                    Icons.update),
                _sortItem('added',
                    uiStrings['songsSortAdded']?[locale] ??
                        'Recently added',
                    Icons.fiber_new),
                _sortItem('title',
                    uiStrings['songsSortTitle']?[locale] ??
                        'Title (A-Z)',
                    Icons.sort_by_alpha),
                _sortItem('source',
                    uiStrings['songsSortSource']?[locale] ??
                        'Source / catalogue',
                    Icons.library_books),
              ],
            ),
          ],
        ),
        if (hasActiveFilter) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (langFilter != 'all')
                InputChip(
                  avatar: const Icon(Icons.language, size: 16),
                  label: Text(_langDisplayLabel(langFilter)),
                  onDeleted: () => onLangChanged('all'),
                ),
              if (sourceFilter != 'all')
                InputChip(
                  avatar: const Icon(Icons.public, size: 16),
                  label: Text(_sourceDisplayLabel(sourceFilter)),
                  onDeleted: () => onSourceChanged('all'),
                ),
              if (themeFilter != 'all')
                InputChip(
                  avatar: const Icon(Icons.label_outline, size: 16),
                  label: Text(localizedSongTheme(
                      themeFilter, locale)),
                  onDeleted: () => onThemeChanged('all'),
                ),
              if (bookFilter != 'all')
                InputChip(
                  avatar: Icon(Icons.bookmark,
                      size: 16, color: scheme.primary),
                  label: Text(
                      localeAwareBookName(bookFilter, locale)),
                  onDeleted: () => onBookChanged('all'),
                ),
              if (albumFilter != 'all')
                InputChip(
                  avatar: const Icon(Icons.album_outlined, size: 16),
                  // Album names run to "2025 Nearer 更亲近" — three
                  // words in two scripts. Bounded so one chip cannot
                  // take the whole row on a narrow phone.
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(albumFilter,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  onDeleted: () => onAlbumChanged('all'),
                ),
              if (mediaFilter != 'all')
                InputChip(
                  avatar: Icon(_mediaIcon(mediaFilter), size: 16),
                  label: Text(_mediaDisplayLabel(mediaFilter)),
                  onDeleted: () => onMediaChanged('all'),
                ),
              ActionChip(
                avatar: const Icon(Icons.clear_all, size: 16),
                label: Text(
                    uiStrings['clearFilter']?[locale] ?? 'Clear'),
                onPressed: onClearAll,
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        // Wrap, not Row: at 320px the count plus two labelled buttons
        // overflows by ~2px, and a hard Row would throw. Wrapping lets
        // the buttons drop to their own line on the narrowest phones
        // instead.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            Text(
              '$matchCount / $totalCount',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
            // These act on the CURRENT FILTER, not the whole
            // catalogue — "shuffle" after narrowing to 安静 + 有伴奏
            // is the quiet-driving playlist, without needing to save
            // anything first.
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(uiStrings['songsPlayAll']?[locale] ?? 'Play all',
                  style: const TextStyle(fontSize: 12)),
              onPressed: matchCount == 0 ? null : () => onPlayAll(false),
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
              onPressed: matchCount == 0 ? null : () => onPlayAll(true),
            ),
            // Saving the FILTER, not the 559 rows it currently
            // matches — the list stays correct as the catalogue grows.
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: uiStrings['songsSaveFilter']?[locale],
              onPressed: hasActiveFilter ? onSaveFilter : null,
            ),
            if (SongDownloadService.isSupported)
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: uiStrings['songsDownloadFiltered']?[locale],
                onPressed: matchCount == 0 ? null : onDownloadAll,
              ),
            ]),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _sortItem(
      String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Text(label),
          if (sort == value) ...[
            const Spacer(),
            Icon(Icons.check, size: 16, color: scheme.primary),
          ],
        ],
      ),
    );
  }

  String _langDisplayLabel(String key) =>
      localizedSongLanguage(key, locale);

  String _sourceDisplayLabel(String key) =>
      localizedSongSource(key, locale);

  String _mediaDisplayLabel(String key) {
    switch (key) {
      case 'audio':
        return uiStrings['songsFilterHasAudio']?[locale] ?? 'Audio';
      case 'video':
        return uiStrings['songsFilterHasVideo']?[locale] ?? 'Video';
      case 'score':
        return uiStrings['songsFilterHasScore']?[locale] ?? 'Score';
    }
    return key;
  }

  IconData _mediaIcon(String key) {
    switch (key) {
      case 'audio':
        return Icons.headphones_rounded;
      case 'video':
        return Icons.movie_rounded;
      case 'score':
        return Icons.picture_as_pdf_rounded;
    }
    return Icons.perm_media_rounded;
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      // useSafeArea: without it Flutter wraps the sheet in
      // MediaQuery.removePadding(removeTop: true), so any SafeArea
      // INSIDE the sheet sees padding.top == 0 and does nothing —
      // the header then draws under the clock and the notch.
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return _SongFilterSheet(
          locale: locale,
          settings: settings,
          availableThemes: availableThemes,
          availableBooks: availableBooks,
          availableAlbums: availableAlbums,
          availableSources: availableSources,
          availableLanguages: availableLanguages,
          initial: (
            lang: langFilter,
            source: sourceFilter,
            theme: themeFilter,
            book: bookFilter,
            album: albumFilter,
            media: mediaFilter,
          ),
          onApply: (sel) {
            onLangChanged(sel.lang);
            onSourceChanged(sel.source);
            onThemeChanged(sel.theme);
            onBookChanged(sel.book);
            onAlbumChanged(sel.album);
            onMediaChanged(sel.media);
            Navigator.of(sheetCtx).pop();
          },
          onClear: () {
            onLangChanged('all');
            onSourceChanged('all');
            onThemeChanged('all');
            onBookChanged('all');
            onAlbumChanged('all');
            onMediaChanged('all');
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }
}

/// Modal-sheet filter — mirrors `_PassageFilterSheet` from
/// sermons_page.dart so users get the same affordance across pages.
/// Hosts every song filter so the inline bar above stays clean.
/// Every facet the sheet edits, carried as one value.
///
/// Was six positional `String`s on `onApply`. Adding the album facet
/// would have made seven interchangeable strings whose order only the
/// call site knew — a named record costs nothing and makes a
/// transposed argument a compile error instead of a filter that
/// silently searches the wrong field.
typedef SongFilterSelection = ({
  String lang,
  String source,
  String theme,
  String book,
  String album,
  String media,
});

class _SongFilterSheet extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  final List<String> availableThemes;
  final Set<String> availableBooks;
  final List<String> availableAlbums;
  final List<String> availableSources;
  final List<String> availableLanguages;
  final SongFilterSelection initial;
  final void Function(SongFilterSelection selection) onApply;
  final VoidCallback onClear;

  const _SongFilterSheet({
    required this.locale,
    required this.settings,
    required this.availableThemes,
    required this.availableBooks,
    required this.availableAlbums,
    required this.availableSources,
    required this.availableLanguages,
    required this.initial,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_SongFilterSheet> createState() => _SongFilterSheetState();
}

class _SongFilterSheetState extends State<_SongFilterSheet> {
  late String _lang;
  late String _source;
  late String _theme;
  late String _book;
  late String _album;
  late String _media;

  @override
  void initState() {
    super.initState();
    _lang = widget.initial.lang;
    _source = widget.initial.source;
    _theme = widget.initial.theme;
    _book = widget.initial.book;
    _album = widget.initial.album;
    _media = widget.initial.media;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final allLabel =
        uiStrings['statsOriginalsAll']?[locale] ?? 'All';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        // 2026-08-10: the header sits OUTSIDE the scroll view.
        //
        // v1.4.20 moved Apply from the bottom of the sheet to the top,
        // but left it inside the SingleChildScrollView — so it was
        // above the sections and still scrolled away with them. Adding
        // the Album section made the sheet tall enough that scrolling
        // to a year chip put Apply ~260px above the top of the screen,
        // which a widget test caught by tapping thin air.
        //
        // Header fixed, sections scrolling under it: now Apply is one
        // tap away whatever is scrolled into view, which is what
        // moving it up was for.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The title uses Expanded so this row degrades by
            // ellipsising the label rather than overflowing on a
            // narrow phone.
            Row(
                children: [
                  Icon(Icons.tune, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uiStrings['songsFilterTitle']?[locale] ?? 'Filter',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onClear,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 36),
                    ),
                    child:
                        Text(uiStrings['clearFilter']?[locale] ?? 'Clear'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => widget.onApply((
                      lang: _lang,
                      source: _source,
                      theme: _theme,
                      book: _book,
                      album: _album,
                      media: _media,
                    )),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(uiStrings['apply']?[locale] ?? 'Apply'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel(
                        text: uiStrings['songsFilterLanguage']?[locale] ??
                            'Language',
                        scheme: scheme),
                    const SizedBox(height: 6),
                    // Wrap of chips rather than a SegmentedButton: adding
                    // Indonesian took this to four options, and four
                    // segments of localised text overflow a narrow phone.
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(allLabel),
                          selected: _lang == 'all',
                          onSelected: (_) => setState(() => _lang = 'all'),
                        ),
                        for (final code in widget.availableLanguages)
                          ChoiceChip(
                            label: Text(localizedSongLanguage(code, locale)),
                            selected: _lang == code,
                            onSelected: (_) => setState(() => _lang = code),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionLabel(
                        text: uiStrings['songsFilterSource']?[locale] ??
                            'Source',
                        scheme: scheme),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(allLabel),
                          selected: _source == 'all',
                          onSelected: (_) => setState(() => _source = 'all'),
                        ),
                        for (final code in widget.availableSources)
                          ChoiceChip(
                            label: Text(localizedSongSource(code, locale)),
                            selected: _source == code,
                            onSelected: (_) => setState(() => _source = code),
                          ),
                      ],
                    ),
                    // Album — cgdc only, one release a year. Hidden entirely
                    // when nothing in the loaded catalogue has an album, so
                    // the other three sources never see a dead section.
                    if (widget.availableAlbums.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SectionLabel(
                          text: uiStrings['songsFilterAlbum']?[locale] ??
                              'Album / year',
                          scheme: scheme),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: Text(allLabel),
                            selected: _album == 'all',
                            onSelected: (_) => setState(() => _album = 'all'),
                          ),
                          for (final a in widget.availableAlbums)
                            ChoiceChip(
                              avatar: const Icon(Icons.album_outlined, size: 16),
                              // Bounded: names carry an English and a Chinese
                              // title after the year, and an unbounded chip
                              // would push the row past a 320px screen.
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 190),
                                child: Text(a,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              selected: _album == a,
                              onSelected: (_) => setState(
                                  () => _album = _album == a ? 'all' : a),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _SectionLabel(
                        text: uiStrings['songsFilterMedia']?[locale] ?? 'Media',
                        scheme: scheme),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(allLabel),
                          selected: _media == 'all',
                          onSelected: (_) => setState(() => _media = 'all'),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.headphones_rounded, size: 16),
                          label: Text(
                              uiStrings['songsFilterHasAudio']?[locale] ?? 'Audio'),
                          selected: _media == 'audio',
                          onSelected: (_) => setState(() => _media = 'audio'),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.movie_rounded, size: 16),
                          label: Text(
                              uiStrings['songsFilterHasVideo']?[locale] ?? 'Video'),
                          selected: _media == 'video',
                          onSelected: (_) => setState(() => _media = 'video'),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: Text(
                              uiStrings['songsFilterHasScore']?[locale] ?? 'Score'),
                          selected: _media == 'score',
                          onSelected: (_) => setState(() => _media = 'score'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionLabel(
                        text: uiStrings['songsFilterTheme']?[locale] ??
                            'Theme',
                        scheme: scheme),
                    const SizedBox(height: 6),
                    // 2026-09-03: the theme chips used to sit in their
                    // own `ConstrainedBox(0.22 h) → SingleChildScrollView`
                    // INSIDE this sheet's outer scroll view. Two
                    // scrollables in one axis: the sheet took every
                    // drag, so the inner box never moved while its own
                    // scrollbar rendered as though it would — the exact
                    // defect fixed in the AI exegesis panel, which the
                    // earlier sweep missed because it looked only for
                    // fixed-POINT caps and this one is a fraction. The
                    // chips flow into the sheet's one scroll view now.
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(allLabel),
                          selected: _theme == 'all',
                          onSelected: (_) => setState(() => _theme = 'all'),
                        ),
                        for (final t in widget.availableThemes)
                          ChoiceChip(
                            label: Text(localizedSongTheme(t, locale)),
                            selected: _theme == t,
                            onSelected: (_) => setState(() => _theme = t),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionLabel(
                        text: uiStrings['sermonFilterBookLabel']
                                    ?[locale] ??
                            'Book',
                        scheme: scheme),
                    const SizedBox(height: 6),
                    // Same as the theme section above: 66 book chips
                    // used to be clipped into a 0.30-viewport box that
                    // could not be dragged.
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(allLabel),
                          selected: _book == 'all',
                          onSelected: (_) => setState(() => _book = 'all'),
                        ),
                        for (final b in standardBookOrder)
                          _BookChip(
                            book: b,
                            locale: locale,
                            hasSongs: widget.availableBooks.contains(b),
                            selected: _book == b,
                            onTap: () => setState(() {
                              _book = _book == b ? 'all' : b;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _SectionLabel({required this.text, required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface.withValues(alpha: 0.65),
      ),
    );
  }
}

class _BookChip extends StatelessWidget {
  final String book;
  final String locale;
  final bool hasSongs;
  final bool selected;
  final VoidCallback onTap;
  const _BookChip({
    required this.book,
    required this.locale,
    required this.hasSongs,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final localized = localeAwareBookName(book, locale, '');
    return ChoiceChip(
      label: Text(
        localized,
        style: TextStyle(
          fontSize: 13,
          color:
              hasSongs ? null : Theme.of(context).disabledColor,
        ),
      ),
      selected: selected,
      onSelected: hasSongs ? (_) => onTap() : null,
    );
  }
}


/// One row in the directory.
///
/// Pre-v2 this was a pure link-out: the whole tile opened the church's
/// site. It now leads with a play button for the songs we can stream
/// (a direct mp3), and tapping the row opens the detail sheet with the
/// alternate mixes, video, score and lyrics. "Open original" is still
/// there — it just isn't the only thing you can do any more.
class _SongTile extends StatelessWidget {
  final Song song;
  final AppSettings settings;
  final ColorScheme scheme;
  final String locale;
  /// Start playing from this row. Queues the whole filtered list.
  final VoidCallback onPlay;
  const _SongTile({
    required this.song,
    required this.settings,
    required this.scheme,
    required this.locale,
    required this.onPlay,
  });

  void _openDetail(BuildContext context) {
    showModalBottomSheet<void>(
      // useSafeArea: without it Flutter wraps the sheet in
      // MediaQuery.removePadding(removeTop: true), so any SafeArea
      // INSIDE the sheet sees padding.top == 0 and does nothing —
      // the header then draws under the clock and the notch.
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SongDetailSheet(
        song: song,
        settings: settings,
        locale: locale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langBadge = {
      'zh': '中',
      'en': 'EN',
      'id': 'ID',
    }[song.language] ??
        song.language.toUpperCase();

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            children: [
              _PlayButton(
                song: song,
                scheme: scheme,
                locale: locale,
                fallbackBadge: langBadge,
                onPlay: onPlay,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize:
                            (settings.fontSize - 1).clamp(14.0, 17.0),
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          localizedSongSource(song.source, locale),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        if (song.creditLine != null)
                          Text(
                            '· ${song.creditLine}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        if (song.durationLabel != null)
                          Text(
                            '· ${song.durationLabel}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.55),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        if (song.verse != null)
                          Text(
                            '· ${song.verse}',
                            style: TextStyle(
                                fontSize: 11, color: scheme.primary),
                          ),
                        for (final t in song.themes.take(2))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              localizedSongTheme(t, locale),
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Offline state, when this platform has downloads.
              if (SongDownloadService.isSupported)
                _DownloadIndicator(song: song, scheme: scheme),
              // Medium indicators, so the row says what it holds
              // before you open it.
              if (song.hasVideo)
                Icon(Icons.movie_rounded,
                    size: 16,
                    color: scheme.onSurface.withValues(alpha: 0.4)),
              if (song.scoreUrl != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.picture_as_pdf_rounded,
                    size: 16,
                    color: scheme.onSurface.withValues(alpha: 0.4)),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.primary.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leading play/pause control. Falls back to the language badge for
/// rows with no streamable audio (SoundCloud-only, or the handful of
/// CDC entries whose mp3 was never uploaded), so the column keeps its
/// alignment and the absence reads as intentional.
class _PlayButton extends StatelessWidget {
  final Song song;
  final ColorScheme scheme;
  final String locale;
  final String fallbackBadge;
  /// Start the list from this song. Only used when this row is not
  /// already the current one — otherwise the button is play/pause.
  final VoidCallback onPlay;
  const _PlayButton({
    required this.song,
    required this.scheme,
    required this.locale,
    required this.fallbackBadge,
    required this.onPlay,
  });

  /// Cover art behind the button, when the source publishes any.
  ///
  /// 199 of 606 songs have artwork and it used to appear only on the
  /// Now Playing screen. It rides *behind* the existing 40×40 control
  /// rather than taking a slot of its own, so the 407 songs without it
  /// are not left with a hole and every row keeps the same height —
  /// a list that changes rhythm depending on which source a song came
  /// from reads as broken rather than as richer.
  ///
  /// The scrim is not decoration: a play glyph tinted `primary` over an
  /// arbitrary photograph is a contrast accident waiting to happen, so
  /// over artwork the glyph goes white on a dark wash instead.
  ///
  /// **The scrim and the white glyph are tied to a frame actually
  /// arriving, not to `artworkUrl != null`.** The first version keyed
  /// both off the URL, which is wrong in the common case: only fydt
  /// publishes artwork, fydt.org is intermittently unreachable (it was
  /// returning nothing at all while this was being written), and a
  /// failed load then left a black wash and a white-on-nothing icon.
  /// Artwork we cannot fetch has to degrade to exactly the plain button,
  /// not to a damaged one.
  ///
  /// [face] is called with true only once the image is on screen.
  ///
  /// Goes through [RemoteImage] rather than `Image.network` directly.
  /// This exact widget produced a crash report from an iPhone —
  /// `SocketException: errno = 60` out of `NetworkImage._loadAsync` —
  /// because fydt.org (the only source that publishes artwork) was
  /// unreachable, `NetworkImage` has no timeout, and every row opened
  /// its own 60-second socket. RemoteImage adds the decode budget, the
  /// per-URL failure memo and the silence.
  Widget _withArtwork(BuildContext context, Widget Function(bool onArt) face,
      bool active) {
    // 40 logical px at the device's own ratio: decoding a full-size
    // album cover for a 40×40 slot is what put `memory:pressure` in the
    // same crash report's breadcrumbs.
    final px = (40 * MediaQuery.devicePixelRatioOf(context)).round();
    return RemoteImage(
      // fydt.org / CDC send no Access-Control-Allow-Origin, so on web
      // CanvasKit is not permitted to read the bytes and every row's
      // artwork came out blank while iOS showed it fine. `prefer` lays
      // out a real <img>, which the browser may paint cross-origin.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      url: song.artworkUrl,
      cacheWidth: px,
      cacheHeight: px,
      fallback: (_) => face(false),
      onLoaded: (_, img) => Stack(
        fit: StackFit.expand,
        children: [
          img,
          Container(
            color: Colors.black.withValues(alpha: active ? 0.28 : 0.42),
          ),
          face(true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!song.hasPlayableAudio) {
      // There is no stream to open, but nearly every such row publishes
      // the song somewhere else, so the slot goes there rather than
      // sitting inert. SoundCloud before YouTube: it is audio, and a tap
      // in a song list is a request to listen.
      final external = song.soundcloudUrl ?? song.youtubeUrl;
      final box = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: scheme.primary.withValues(alpha: 0.10)),
              _withArtwork(
                context,
                (onArt) {
                  final fg = onArt
                      ? Colors.white
                      : scheme.primary.withValues(alpha: 0.8);
                  return Center(
                    child: external == null
                        ? Text(
                            fallbackBadge,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          )
                        // The same glyphs the detail sheet's link chips
                        // use, so one icon means one destination.
                        : Icon(
                            song.soundcloudUrl != null
                                ? Icons.cloud_rounded
                                : Icons.smart_display_rounded,
                            size: 20,
                            color: fg,
                          ),
                  );
                },
                false,
              ),
            ],
          ),
        ),
      );
      if (external == null) return box;
      return Semantics(
        button: true,
        label: uiStrings['songsListenElsewhere']?[locale] ??
            'Listen on another site',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () =>
                LinkOpener.openOrWarn(context, external, locale: locale),
            child: box,
          ),
        ),
      );
    }

    final player = SongPlayerService.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        // Any take of this song counts as "this row is playing" —
        // start the English version from the detail sheet and the row's
        // button should read as active, not idle.
        final isThis = player.current?.id == song.id;
        final playing = isThis && player.isPlaying;
        final loading = isThis && player.isLoading;
        return Semantics(
          button: true,
          label: playing
              ? (uiStrings['songsPause']?[locale] ?? 'Pause')
              : (uiStrings['songsPlay']?[locale] ?? 'Play'),
          child: Material(
            color: isThis
                ? scheme.primary
                : scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              // Already the current song → plain play/pause, so a tap
              // does not restart it. Otherwise start the list here,
              // which is what gives the lock screen a queue to skip
              // through.
              onTap: () => isThis
                  ? player.toggle(song, SongTrack.vocal, player.currentUrl)
                  : onPlay(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: _withArtwork(context, (onArt) {
                    final fg = onArt
                        ? Colors.white
                        : (isThis ? scheme.onPrimary : scheme.primary);
                    return Center(
                      child: loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: fg),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 22,
                              color: fg,
                            ),
                    );
                  }, isThis),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Detail sheet: everything the catalogue holds for one song —
/// alternate mixes, video, score, lyrics, and the link back to the
/// church's own page.
class _SongDetailSheet extends StatelessWidget {
  final Song song;
  final AppSettings settings;
  final String locale;
  const _SongDetailSheet({
    required this.song,
    required this.settings,
    required this.locale,
  });

  /// 2026-08-24: this was a hand-copied [LinkOpener.openOrWarn] —
  /// `open` plus the same snackbar, written out again because the sheet
  /// already had `locale` to hand. Harmless while the only difference
  /// was where the string came from, and then not: the in-app YouTube
  /// player hangs off `openOrWarn`, so the YouTube chip on these three
  /// rows was the one place in the app that still walked out to Safari
  /// after "web 和ios能不能不跳转出去". A local copy of a chokepoint is
  /// a chokepoint with a hole in it.
  Future<void> _open(BuildContext context, String url) =>
      LinkOpener.openOrWarn(context, url, locale: locale);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final player = SongPlayerService.instance;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontFamilyFallback: kCjkFontFallback,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            localizedSongSource(song.source, locale),
                            if (song.code != null) song.code!,
                            if (song.creditLine != null) song.creditLine!,
                            if (song.durationLabel != null)
                              song.durationLabel!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SongFavouriteButton(song: song, locale: locale),
                  // Downloading was bulk-only: you could take the whole
                  // filter offline but not the one hymn you are looking
                  // at, which is the commonest case before a flight or
                  // a drive out of coverage.
                  if (SongDownloadService.isSupported &&
                      song.hasPlayableAudio)
                    _SongDownloadButton(
                        song: song, scheme: scheme, locale: locale),
                  IconButton(
                    icon: const Icon(Icons.playlist_add_rounded, size: 22),
                    tooltip: uiStrings['songsAddToPlaylist']?[locale],
                    onPressed: () => showAddToPlaylistSheet(context, song, locale),
                  ),
                  // Queue it without interrupting what is playing.
                  // Standard in every music app and absent here: you
                  // heard something you wanted next and the only way to
                  // get it was to stop the current song.
                  if (song.hasPlayableAudio)
                    PopupMenuButton<bool>(
                      tooltip: '',
                      icon: const Icon(Icons.queue_rounded, size: 21),
                      onSelected: (next) => _queueSong(context, song,
                          playNext: next, locale: locale),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: true,
                          child: Text(uiStrings['songsPlayNext']?[locale] ??
                              'Play next'),
                        ),
                        PopupMenuItem(
                          value: false,
                          child: Text(uiStrings['songsAddToQueue']?[locale] ??
                              'Add to queue'),
                        ),
                      ],
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Audio mixes ───────────────────────────
                      if (song.hasPlayableAudio ||
                          song.hasAlternateMixes) ...[
                        _SectionLabel(
                            text: uiStrings['songsSectionAudio']?[locale] ??
                                'Audio',
                            scheme: scheme),
                        const SizedBox(height: 6),
                        // Built from the real track list rather than
                        // three fixed slots: CDC publishes some songs
                        // sung in BOTH English and Chinese, and those
                        // two takes both occupy the "vocal" slot, so a
                        // fixed layout could only ever show one of
                        // them.
                        ListenableBuilder(
                          listenable: player,
                          builder: (context, _) => Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in _tracksFor(song))
                                _TrackChip(
                                  song: song,
                                  track: _slotFor(t.kind),
                                  url: t.url,
                                  label: _trackLabel(t, song, locale),
                                  icon: _trackIcon(t.kind),
                                  scheme: scheme,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Links out ─────────────────────────────
                      _SectionLabel(
                          text: uiStrings['songsSectionLinks']?[locale] ??
                              'Open',
                          scheme: scheme),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (song.videoUrl != null)
                            _LinkChip(
                              // Plays in-app now (mp4 only). Falls back
                              // to the browser on Windows/Linux, where
                              // video_player has no implementation.
                              icon: Icons.movie_rounded,
                              label: uiStrings['songsWatchMv']?[locale] ??
                                  'Music video',
                              onTap: () => SongVideoPage.open(
                                  context, song, locale),
                            ),
                          if (song.youtubeUrl != null)
                            _LinkChip(
                              icon: Icons.smart_display_rounded,
                              label: 'YouTube',
                              onTap: () =>
                                  _open(context, song.youtubeUrl!),
                            ),
                          if (song.soundcloudUrl != null)
                            _LinkChip(
                              icon: Icons.cloud_rounded,
                              label: 'SoundCloud',
                              onTap: () =>
                                  _open(context, song.soundcloudUrl!),
                            ),
                          if (song.scoreUrl != null)
                            _LinkChip(
                              // Opens in-app, from the downloaded copy
                              // when there is one.
                              icon: Icons.picture_as_pdf_rounded,
                              label: uiStrings['songsScore']?[locale] ??
                                  'Sheet music',
                              onTap: () => SongScorePage.open(
                                  context, song, locale),
                            ),
                          _LinkChip(
                            icon: Icons.open_in_new_rounded,
                            label:
                                uiStrings['songsOpenOriginal']?[locale] ??
                                    'Original page',
                            onTap: () => _open(context, song.url),
                          ),
                        ],
                      ),

                      // ── Lyrics ────────────────────────────────
                      if (song.lyrics != null) ...[
                        const SizedBox(height: 14),
                        _SectionLabel(
                            text: uiStrings['songsSectionLyrics']?[locale] ??
                                'Lyrics',
                            scheme: scheme),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SelectableText(
                            song.lyrics!,
                            scrollPhysics: kSelectableTextPhysics,
                            style: TextStyle(
                              fontFamily: settings.fontFamily,
                              fontFamilyFallback: kCjkFontFallback,
                              fontSize: (settings.fontSize - 2)
                                  .clamp(13.0, 17.0),
                              height: 1.6,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],

                      // ── Themes ────────────────────────────────
                      if (song.themes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in song.themes)
                              Chip(
                                label: Text(
                                  localizedSongTheme(t, locale),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),
                      Text(
                        uiStrings['songsAttribution']?[locale] ??
                            'Published by our church. Audio, video and '
                                'sheet music stream from the source site.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.45,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The audio takes to offer for [song].
///
/// Prefers the catalogue's full `audioTracks` list. Falls back to the
/// three scalar fields for any row synced before that list existed, so
/// a stale bundled snapshot still shows its audio.
List<SongTrackInfo> _tracksFor(Song song) {
  if (song.audioTracks.isNotEmpty) return song.audioTracks;
  return [
    if (song.audioUrl != null)
      SongTrackInfo(url: song.audioUrl!, kind: 'vocal'),
    if (song.instrumentalUrl != null)
      SongTrackInfo(url: song.instrumentalUrl!, kind: 'instrumental'),
    if (song.accompanimentUrl != null)
      SongTrackInfo(url: song.accompanimentUrl!, kind: 'accompaniment'),
  ];
}

SongTrack _slotFor(String kind) => switch (kind) {
      'instrumental' => SongTrack.instrumental,
      'accompaniment' => SongTrack.accompaniment,
      _ => SongTrack.vocal,
    };

IconData _trackIcon(String kind) => switch (kind) {
      'instrumental' => Icons.piano_rounded,
      'accompaniment' => Icons.queue_music_rounded,
      _ => Icons.music_note_rounded,
    };

/// Chip label for one take. A language-tagged vocal is named by its
/// language ("English" / "中文") — on a bilingual song two chips would
/// otherwise both read "Song" and be indistinguishable.
String _trackLabel(SongTrackInfo t, Song song, String locale) {
  if (t.isVocal && t.lang != null && song.hasMultipleLanguages) {
    return localizedSongLanguage(t.lang!, locale);
  }
  switch (t.kind) {
    case 'instrumental':
      return uiStrings['songsTrackInstrumental']?[locale] ?? 'Instrumental';
    case 'accompaniment':
      return uiStrings['songsTrackAccompaniment']?[locale] ?? 'Accompaniment';
    default:
      return uiStrings['songsTrackVocal']?[locale] ?? 'Song';
  }
}

/// One selectable take inside the detail sheet.
class _TrackChip extends StatelessWidget {
  final Song song;
  final SongTrack track;
  final String url;
  final String label;
  final IconData icon;
  final ColorScheme scheme;
  const _TrackChip({
    required this.song,
    required this.track,
    required this.url,
    required this.label,
    required this.icon,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final player = SongPlayerService.instance;
    // Match on URL, not on the enum slot: two per-language vocals share
    // SongTrack.vocal, so an enum comparison would highlight both.
    final isThis = player.isCurrentUrl(song, url);
    final playing = isThis && player.isPlaying;
    return ActionChip(
      avatar: Icon(
        playing ? Icons.pause_rounded : icon,
        size: 16,
        color: isThis ? scheme.onPrimaryContainer : null,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: isThis ? scheme.primaryContainer : null,
      onPressed: () => player.toggle(song, track, url),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}


/// Pick which playlists a song belongs to.
///
/// Smart playlists are listed but not selectable: their membership
/// comes from a saved filter, so "add" would be a lie. Saying why is
/// better than hiding them and leaving the user wondering where their
/// playlist went.

/// Per-row offline state: a tick when stored, a ring while fetching,
/// nothing at all otherwise.
///
/// Deliberately quiet — most rows are not downloaded and an icon on
/// every one of 559 would be noise. Only says something when there is
/// something to say.
/// Download / remove one song, from its detail sheet.
///
/// Four states in one button because the sheet's header has room for
/// exactly one: not downloaded → download; queued or downloading →
/// progress, tap to cancel that song; done → tick, tap to remove;
/// failed → retry. Native only — [SongDownloadService.isSupported] is
/// false on web, where the browser cache is the offline story.
class _SongDownloadButton extends StatelessWidget {
  final Song song;
  final ColorScheme scheme;
  final String locale;

  const _SongDownloadButton({
    required this.song,
    required this.scheme,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final service = SongDownloadService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final status = service.statusOf(song);
        switch (status.state) {
          case SongDownloadState.done:
            return IconButton(
              icon: const Icon(Icons.download_done_rounded, size: 22),
              color: scheme.primary,
              tooltip: uiStrings['songsDeleteDownload']?[locale],
              onPressed: () => _confirmDelete(context, service),
            );
          case SongDownloadState.queued:
          case SongDownloadState.downloading:
            return IconButton(
              tooltip: uiStrings['cancel']?[locale],
              icon: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  // Null while the server sends no Content-Length —
                  // an indeterminate spinner is honest there, a bar
                  // stuck at 0% is not.
                  value: status.state == SongDownloadState.downloading
                      ? status.progress
                      : null,
                  color: scheme.primary,
                ),
              ),
              onPressed: () => service.delete(song),
            );
          case SongDownloadState.failed:
            return IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              color: scheme.error,
              tooltip: status.error,
              onPressed: () => service.enqueue([song]),
            );
          case SongDownloadState.none:
            return IconButton(
              icon: const Icon(Icons.download_rounded, size: 22),
              tooltip: uiStrings['songsDownloadSong']?[locale],
              onPressed: () => service.enqueue([song]),
            );
        }
      },
    );
  }

  void _confirmDelete(BuildContext context, SongDownloadService service) {
    final messenger = ScaffoldMessenger.of(context);
    service.delete(song);
    messenger.showSnackBar(SnackBar(
      content: Text(
          uiStrings['songsDownloadRemoved']?[locale] ?? 'Removed from device.'),
      action: SnackBarAction(
        label: uiStrings['undo']?[locale] ?? 'Undo',
        onPressed: () => service.enqueue([song]),
      ),
    ));
  }
}

class _DownloadIndicator extends StatelessWidget {
  final Song song;
  final ColorScheme scheme;
  const _DownloadIndicator({required this.song, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final service = SongDownloadService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final status = service.statusOf(song);
        switch (status.state) {
          case SongDownloadState.done:
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.download_done_rounded,
                  size: 16, color: scheme.primary),
            );
          case SongDownloadState.downloading:
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: status.progress,
                  color: scheme.primary,
                ),
              ),
            );
          case SongDownloadState.queued:
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.schedule_rounded,
                  size: 15, color: scheme.onSurfaceVariant),
            );
          case SongDownloadState.failed:
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.error_outline_rounded,
                  size: 15, color: scheme.error),
            );
          case SongDownloadState.none:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Queue a song, and say so — the queue is off-screen, so without a
/// confirmation the tap looks like it did nothing.
Future<void> _queueSong(BuildContext context, Song song,
    {required bool playNext, required String locale}) async {
  final messenger = ScaffoldMessenger.of(context);
  await SongPlayerService.instance.addToQueue(song, playNext: playNext);
  messenger.showSnackBar(SnackBar(
    content: Text(playNext
        ? (uiStrings['songsQueuedNext']?[locale] ?? 'Playing next.')
        : (uiStrings['songsQueuedEnd']?[locale] ?? 'Added to the queue.')),
    duration: const Duration(seconds: 2),
  ));
}
