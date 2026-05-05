import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Round 56: church-songs directory page.
///
/// Shows the combined index of songs published by 福音电台
/// (fydt.org/xinge) and Christian Disciples Church
/// (christiandiscipleschurch.org/content/integrated-list-songs).
/// The app stores only metadata — title, URL, language, theme tags
/// — and tapping a song opens the original site in a new tab/
/// external browser. Audio playback, lyrics display and PDF download
/// happen on the source sites under each church's own publishing
/// arrangements; YsWords does not host or redistribute the content
/// itself.
class SongsPage extends StatefulWidget {
  const SongsPage({super.key});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  Future<List<Song>>? _future;
  final _scrollCtrl = ScrollController();

  /// 'all' | 'zh' | 'en' | 'th'.
  String _langFilter = 'all';
  /// 'all' | one of the source ids in songs.json (`fydt`, `cdc`).
  String _sourceFilter = 'all';
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
        actions: const [HomeIconButton()],
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
              _bookFilter != 'all';
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
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
                        sort: _sort,
                        availableThemes: themes,
                        availableBooks: availableBooks,
                        matchCount: filtered.length,
                        totalCount: all.length,
                        onQuery: (v) => setState(() => _query = v),
                        onClearAll: () => setState(() {
                          _langFilter = 'all';
                          _sourceFilter = 'all';
                          _themeFilter = 'all';
                          _bookFilter = 'all';
                        }),
                        onLangChanged: (v) =>
                            setState(() => _langFilter = v),
                        onSourceChanged: (v) =>
                            setState(() => _sourceFilter = v),
                        onThemeChanged: (v) =>
                            setState(() => _themeFilter = v),
                        onBookChanged: (v) =>
                            setState(() => _bookFilter = v),
                        onSortChanged: (v) =>
                            setState(() => _sort = v),
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
          );
        },
      ),
    );
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
        'Browse songs from 福音电台 (fydt.org) and Christian Disciples Church. '
            'Tap an entry to open the original page where you can listen, read lyrics and download the PDF.';
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
                    fontFamily: settings.fontFamily,
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
              fontFamily: settings.fontFamily,
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
  final String sort;
  final List<String> availableThemes;
  final Set<String> availableBooks;
  final int matchCount;
  final int totalCount;
  final ValueChanged<String> onQuery;
  final VoidCallback onClearAll;
  final ValueChanged<String> onLangChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<String> onBookChanged;
  final ValueChanged<String> onSortChanged;

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
    required this.sort,
    required this.availableThemes,
    required this.availableBooks,
    required this.matchCount,
    required this.totalCount,
    required this.onQuery,
    required this.onClearAll,
    required this.onLangChanged,
    required this.onSourceChanged,
    required this.onThemeChanged,
    required this.onBookChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final searchHint = uiStrings['songsSearchHint']?[locale] ??
        'Search song title, theme, or code…';
    final filterLabel =
        uiStrings['sermonFilterByPassage']?[locale] ?? 'Filter';
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
                  fontFamily: settings.fontFamily,
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
        Text(
          '$matchCount / $totalCount',
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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

  String _langDisplayLabel(String key) {
    if (key == 'zh') return '中文';
    if (key == 'en') return 'English';
    if (key == 'th') return 'ไทย';
    return key;
  }

  String _sourceDisplayLabel(String key) {
    if (key == 'fydt') return '福音电台';
    if (key == 'cdc') return 'CDC';
    return key;
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
          initialLang: langFilter,
          initialSource: sourceFilter,
          initialTheme: themeFilter,
          initialBook: bookFilter,
          onApply: (lang, source, theme, book) {
            onLangChanged(lang);
            onSourceChanged(source);
            onThemeChanged(theme);
            onBookChanged(book);
            Navigator.of(sheetCtx).pop();
          },
          onClear: () {
            onLangChanged('all');
            onSourceChanged('all');
            onThemeChanged('all');
            onBookChanged('all');
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
  final String initialLang;
  final String initialSource;
  final String initialTheme;
  final String initialBook;
  final void Function(String lang, String source, String theme,
      String book) onApply;
  final VoidCallback onClear;

  const _SongFilterSheet({
    required this.locale,
    required this.settings,
    required this.availableThemes,
    required this.availableBooks,
    required this.initialLang,
    required this.initialSource,
    required this.initialTheme,
    required this.initialBook,
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

  @override
  void initState() {
    super.initState();
    _lang = widget.initialLang;
    _source = widget.initialSource;
    _theme = widget.initialTheme;
    _book = widget.initialBook;
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
              Row(
                children: [
                  Icon(Icons.tune,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    uiStrings['sermonFilterByPassage']?[locale] ??
                        'Filter',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onClear,
                    child: Text(
                        uiStrings['clearFilter']?[locale] ?? 'Clear'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SectionLabel(
                  text: uiStrings['songsFilterLanguage']?[locale] ??
                      'Language',
                  scheme: scheme),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'all', label: Text(allLabel)),
                  const ButtonSegment(value: 'zh', label: Text('中文')),
                  const ButtonSegment(
                      value: 'en', label: Text('English')),
                ],
                selected: {_lang},
                onSelectionChanged: (s) =>
                    setState(() => _lang = s.first),
                multiSelectionEnabled: false,
                showSelectedIcon: false,
              ),
              const SizedBox(height: 14),
              _SectionLabel(
                  text: uiStrings['songsFilterSource']?[locale] ??
                      'Source',
                  scheme: scheme),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'all', label: Text(allLabel)),
                  const ButtonSegment(
                      value: 'fydt', label: Text('福音电台')),
                  const ButtonSegment(value: 'cdc', label: Text('CDC')),
                ],
                selected: {_source},
                onSelectionChanged: (s) =>
                    setState(() => _source = s.first),
                multiSelectionEnabled: false,
                showSelectedIcon: false,
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => widget.onApply(
                    _lang, _source, _theme, _book),
                child: Text(
                    uiStrings['apply']?[locale] ?? 'Apply'),
              ),
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

  Future<void> _open(BuildContext context) async {
    final ok = await LinkOpener.open(song.url);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          uiStrings['songsOpenFailed']?[locale] ??
              'Could not open the original page. Please try again.',
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final langBadge = {
      'zh': '中',
      'en': 'EN',
      'th': 'TH',
    }[song.language] ??
        '?';
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  langBadge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
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
                        fontSize: (settings.fontSize - 1)
                            .clamp(14.0, 17.0),
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          song.sourceLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        if (song.code != null)
                          Text(
                            '· ${song.code}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        if (song.verse != null)
                          Text(
                            '· ${song.verse}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                            ),
                          ),
                        for (final t in song.themes.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer
                                  .withValues(alpha: 0.6),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(
                              localizedSongTheme(t, locale),
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded,
                  size: 18,
                  color: scheme.primary
                      .withValues(alpha: 0.75)),
            ],
          ),
        ),
      ),
    );
  }
}
