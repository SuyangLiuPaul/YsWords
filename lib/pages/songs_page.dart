import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/responsive.dart';
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
  /// 'all' | one of the auto-derived theme tags.
  String _themeFilter = 'all';
  String _query = '';

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
          final filtered = _filter(all);
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
                      return _FilterBar(
                        settings: settings,
                        scheme: scheme,
                        locale: locale,
                        availableThemes: themes,
                        langFilter: _langFilter,
                        sourceFilter: _sourceFilter,
                        themeFilter: _themeFilter,
                        query: _query,
                        matchCount: filtered.length,
                        totalCount: all.length,
                        onLang: (v) =>
                            setState(() => _langFilter = v),
                        onSource: (v) =>
                            setState(() => _sourceFilter = v),
                        onTheme: (v) =>
                            setState(() => _themeFilter = v),
                        onQuery: (v) => setState(() => _query = v),
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
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((s) {
        return s.title.toLowerCase().contains(q) ||
            (s.code?.toLowerCase().contains(q) ?? false) ||
            (s.verse?.toLowerCase().contains(q) ?? false) ||
            s.themes.any((t) => t.toLowerCase().contains(q));
      });
    }
    return out.toList();
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

class _FilterBar extends StatelessWidget {
  final AppSettings settings;
  final ColorScheme scheme;
  final String locale;
  final List<String> availableThemes;
  final String langFilter;
  final String sourceFilter;
  final String themeFilter;
  final String query;
  final int matchCount;
  final int totalCount;
  final ValueChanged<String> onLang;
  final ValueChanged<String> onSource;
  final ValueChanged<String> onTheme;
  final ValueChanged<String> onQuery;

  const _FilterBar({
    required this.settings,
    required this.scheme,
    required this.locale,
    required this.availableThemes,
    required this.langFilter,
    required this.sourceFilter,
    required this.themeFilter,
    required this.query,
    required this.matchCount,
    required this.totalCount,
    required this.onLang,
    required this.onSource,
    required this.onTheme,
    required this.onQuery,
  });

  @override
  Widget build(BuildContext context) {
    final allLabel =
        uiStrings['statsOriginalsAll']?[locale] ?? 'All';
    final searchHint = uiStrings['songsSearchHint']?[locale] ??
        'Search song title, theme, or code…';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
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
            fontSize: (settings.fontSize - 1).clamp(13.0, 17.0),
          ),
        ),
        const SizedBox(height: 10),
        // Language toggle
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'all', label: Text(allLabel)),
            const ButtonSegment(value: 'zh', label: Text('中文')),
            const ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {langFilter},
          onSelectionChanged: (s) => onLang(s.first),
          multiSelectionEnabled: false,
          showSelectedIcon: false,
        ),
        const SizedBox(height: 10),
        // Source toggle
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'all', label: Text(allLabel)),
            const ButtonSegment(value: 'fydt', label: Text('福音电台')),
            const ButtonSegment(value: 'cdc', label: Text('CDC')),
          ],
          selected: {sourceFilter},
          onSelectionChanged: (s) => onSource(s.first),
          multiSelectionEnabled: false,
          showSelectedIcon: false,
        ),
        const SizedBox(height: 10),
        // Theme chip row
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _Chip(
                label: allLabel,
                selected: themeFilter == 'all',
                onTap: () => onTheme('all'),
                scheme: scheme,
              ),
              for (final t in availableThemes)
                _Chip(
                  label: t,
                  selected: themeFilter == t,
                  onTap: () => onTheme(t),
                  scheme: scheme,
                ),
            ],
          ),
        ),
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
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
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
                              t,
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
