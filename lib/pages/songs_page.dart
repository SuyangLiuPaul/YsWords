import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_playlist.dart';
import 'package:yswords/pages/song_downloads_page.dart';
import 'package:yswords/pages/song_playlists_page.dart';
import 'package:yswords/services/song_download_service.dart';
import 'package:yswords/services/song_download_types.dart';
import 'package:yswords/services/song_playlist_service.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
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
  final _scrollCtrl = ScrollController();

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
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
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
              onPressed: () => pushPage(const SongDownloadsPage()),
            ),
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: uiStrings['songsPlaylists']?[locale] ?? 'Playlists',
            onPressed: () => pushPage(const SongPlaylistsPage()),
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
          final filtered = _filter(all);
          final hasFilter = _langFilter != 'all' ||
              _sourceFilter != 'all' ||
              _themeFilter != 'all' ||
              _bookFilter != 'all' ||
              _mediaFilter != 'all';
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                children: [
                  Expanded(
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
                        mediaFilter: _mediaFilter,
                        sort: _sort,
                        availableThemes: themes,
                        availableBooks: availableBooks,
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
                    return _SongTile(
                      song: filtered[i - 2],
                      settings: settings,
                      scheme: scheme,
                      locale: locale,
                    );
                  },
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
      List<Song> filtered, bool shuffle, String locale) async {
    final player = SongPlayerService.instance;
    await player.playQueue(
      filtered,
      shuffle: shuffle,
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
        onPressed: () => pushPage(const SongDownloadsPage()),
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
        media: _mediaFilter,
        query: _query,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(uiStrings['songsSavedPlaylist']?[locale] ?? 'Saved.'),
      action: SnackBarAction(
        label: uiStrings['songsPlaylists']?[locale] ?? 'Playlists',
        onPressed: () => pushPage(const SongPlaylistsPage()),
      ),
    ));
  }

  /// A short name for what is playing, shown on the now-playing screen
  /// and in the OS media session.
  String _queueLabel(String locale) {
    final parts = <String>[
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
      out = out.where((s) {
        return s.title.toLowerCase().contains(q) ||
            (s.code?.toLowerCase().contains(q) ?? false) ||
            (s.verse?.toLowerCase().contains(q) ?? false) ||
            s.themes.any((t) => t.toLowerCase().contains(q));
      });
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
  final String mediaFilter;
  final String sort;
  final List<String> availableThemes;
  final Set<String> availableBooks;
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
    required this.mediaFilter,
    required this.sort,
    required this.availableThemes,
    required this.availableBooks,
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
          availableSources: availableSources,
          availableLanguages: availableLanguages,
          initialLang: langFilter,
          initialSource: sourceFilter,
          initialTheme: themeFilter,
          initialBook: bookFilter,
          initialMedia: mediaFilter,
          onApply: (lang, source, theme, book, media) {
            onLangChanged(lang);
            onSourceChanged(source);
            onThemeChanged(theme);
            onBookChanged(book);
            onMediaChanged(media);
            Navigator.of(sheetCtx).pop();
          },
          onClear: () {
            onLangChanged('all');
            onSourceChanged('all');
            onThemeChanged('all');
            onBookChanged('all');
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
class _SongFilterSheet extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  final List<String> availableThemes;
  final Set<String> availableBooks;
  final List<String> availableSources;
  final List<String> availableLanguages;
  final String initialLang;
  final String initialSource;
  final String initialTheme;
  final String initialBook;
  final String initialMedia;
  final void Function(String lang, String source, String theme, String book,
      String media) onApply;
  final VoidCallback onClear;

  const _SongFilterSheet({
    required this.locale,
    required this.settings,
    required this.availableThemes,
    required this.availableBooks,
    required this.availableSources,
    required this.availableLanguages,
    required this.initialLang,
    required this.initialSource,
    required this.initialTheme,
    required this.initialBook,
    required this.initialMedia,
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
  late String _media;

  @override
  void initState() {
    super.initState();
    _lang = widget.initialLang;
    _source = widget.initialSource;
    _theme = widget.initialTheme;
    _book = widget.initialBook;
    _media = widget.initialMedia;
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 2026-08-09: Apply lives in the header, not at the
              // bottom. Adding the Media section pushed the sheet past
              // a phone screen — with Theme and Book both expanded you
              // had to scroll through ~60 chips to reach a button whose
              // whole job is "I'm done". Pinning it here keeps it one
              // tap away whatever is scrolled into view. The title uses
              // Expanded so this row degrades by ellipsising the label
              // rather than overflowing on a narrow phone.
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
                    onPressed: () => widget.onApply(
                        _lang, _source, _theme, _book, _media),
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
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.22),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(allLabel),
                        selected: _theme == 'all',
                        onSelected: (_) =>
                            setState(() => _theme = 'all'),
                      ),
                      for (final t in widget.availableThemes)
                        ChoiceChip(
                          label: Text(localizedSongTheme(t, locale)),
                          selected: _theme == t,
                          onSelected: (_) =>
                              setState(() => _theme = t),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SectionLabel(
                  text: uiStrings['sermonFilterBookLabel']
                              ?[locale] ??
                      'Book',
                  scheme: scheme),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.30),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(allLabel),
                        selected: _book == 'all',
                        onSelected: (_) =>
                            setState(() => _book = 'all'),
                      ),
                      for (final b in standardBookOrder)
                        _BookChip(
                          book: b,
                          locale: locale,
                          hasSongs:
                              widget.availableBooks.contains(b),
                          selected: _book == b,
                          onTap: () => setState(() {
                            _book = _book == b ? 'all' : b;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              // Apply moved to the header row above — see the note
              // there. Nothing follows the Book section now, so the
              // sheet ends as soon as the chips do.
            ],
          ),
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
  const _SongTile({
    required this.song,
    required this.settings,
    required this.scheme,
    required this.locale,
  });

  void _openDetail(BuildContext context) {
    showModalBottomSheet<void>(
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
  const _PlayButton({
    required this.song,
    required this.scheme,
    required this.locale,
    required this.fallbackBadge,
  });

  @override
  Widget build(BuildContext context) {
    if (!song.hasPlayableAudio) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          fallbackBadge,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.primary.withValues(alpha: 0.8),
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
              onTap: () => player.toggle(song, SongTrack.vocal),
              child: SizedBox(
                width: 40,
                height: 40,
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isThis
                              ? scheme.onPrimary
                              : scheme.primary,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 22,
                        color:
                            isThis ? scheme.onPrimary : scheme.primary,
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

  Future<void> _open(BuildContext context, String url) async {
    final ok = await LinkOpener.open(url);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          uiStrings['songsOpenFailed']?[locale] ??
              'Could not open the link. Please try again.',
        ),
      ));
    }
  }

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
                  _FavouriteButton(song: song, locale: locale),
                  IconButton(
                    icon: const Icon(Icons.playlist_add_rounded, size: 22),
                    tooltip: uiStrings['songsAddToPlaylist']?[locale],
                    onPressed: () => _showAddToPlaylist(context, song, locale),
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
                              icon: Icons.movie_rounded,
                              label: uiStrings['songsWatchMv']?[locale] ??
                                  'Music video',
                              onTap: () =>
                                  _open(context, song.videoUrl!),
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
                              icon: Icons.picture_as_pdf_rounded,
                              label: uiStrings['songsScore']?[locale] ??
                                  'Sheet music',
                              onTap: () => _open(context, song.scoreUrl!),
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

/// One-tap favourite toggle.
///
/// Favourites is an ordinary playlist with a reserved id, so this is
/// just a shortcut into the same store the Playlists page reads —
/// no parallel state to keep in sync.
class _FavouriteButton extends StatelessWidget {
  final Song song;
  final String locale;
  const _FavouriteButton({required this.song, required this.locale});

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

/// Pick which playlists a song belongs to.
///
/// Smart playlists are listed but not selectable: their membership
/// comes from a saved filter, so "add" would be a lie. Saying why is
/// better than hiding them and leaving the user wondering where their
/// playlist went.
void _showAddToPlaylist(BuildContext context, Song song, String locale) {
  final service = SongPlaylistService.instance;
  service.load();
  showModalBottomSheet<void>(
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

/// Per-row offline state: a tick when stored, a ring while fetching,
/// nothing at all otherwise.
///
/// Deliberately quiet — most rows are not downloaded and an icon on
/// every one of 559 would be noise. Only says something when there is
/// something to say.
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
