import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/video_series.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/media_focus.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/youtube_embed.dart';

const String kVideosAssetPath = 'assets/videos.json';

Future<List<VideoSeries>> loadVideoSeries() async {
  final raw = await rootBundle.loadString(kVideosAssetPath);
  return VideoSeries.listFromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// The video section: a list of series, not a single video.
///
/// A one-episode series opens straight into its player rather than
/// showing an episode list with one row in it.
class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  List<VideoSeries>? _series;
  Object? _error;

  @override
  void initState() {
    super.initState();
    loadVideoSeries().then(
      (s) => mounted ? setState(() => _series = s) : null,
      onError: (Object e) => mounted ? setState(() => _error = e) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final scheme = Theme.of(context).colorScheme;
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(
        ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width));

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['videosTitle']?[locale] ?? 'Featured videos'),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: _body(locale, scheme),
        ),
      ),
    );
  }

  Widget _body(String locale, ColorScheme scheme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text('$_error',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    final series = _series;
    if (series == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (series.isEmpty) {
      return Center(
        child: Text(uiStrings['oneGodEmpty']?[locale] ?? 'Nothing here yet.',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: series.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _card(series[i], locale, scheme),
    );
  }

  Widget _card(VideoSeries s, String locale, ColorScheme scheme) {
    final cover = s.episodes.isEmpty ? null : s.episodes.first.defaultTrack;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushPage(VideoSeriesPage(series: s)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cover != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  cover.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(Icons.ondemand_video_rounded,
                        size: 40, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.titleFor(locale),
                    style: TextStyle(
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.taglineFor(locale),
                    style: TextStyle(
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _episodeCount(s.episodes.length, locale),
                    style: TextStyle(fontSize: 12, color: scheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _episodeCount(int n, String locale) {
    if (locale.startsWith('zh')) return '$n 集';
    return n == 1 ? '1 video' : '$n videos';
  }
}

/// One series: the player, the language buttons, and the episode list.
class VideoSeriesPage extends StatefulWidget {
  const VideoSeriesPage({super.key, required this.series});

  final VideoSeries series;

  @override
  State<VideoSeriesPage> createState() => _VideoSeriesPageState();
}

class _VideoSeriesPageState extends State<VideoSeriesPage> {
  late VideoEpisode _episode = widget.series.episodes.first;

  /// Set in [initState] from the app language — see
  /// [VideoEpisode.trackForLocale]. After that the reader owns it: the
  /// language buttons still switch by hand, and moving between episodes
  /// keeps the current language whenever that episode has it.
  late String _lang;

  @override
  void initState() {
    super.initState();
    final locale = context.read<AppSettings>().locale;
    _lang = _episode.trackForLocale(locale)?.lang ??
        _episode.defaultTrack?.lang ??
        'en';
  }

  /// Null until the user asks for a video. The embed is not mounted
  /// before then, so opening the page never autoplays and never costs
  /// a YouTube request for someone who was only browsing the list.
  VideoTrack? _playing;

  VideoTrack? get _selected =>
      _episode.trackFor(_lang) ?? _episode.defaultTrack;

  Future<void> _play(BuildContext context, VideoTrack track) async {
    // A video starting silences the hymn. The reverse cannot be
    // honoured here — the iframe owns its own playback and exposes no
    // pause to us — so this page deliberately does not register with
    // MediaFocus as something that can be paused. Claiming without
    // registering is exactly that asymmetry, made explicit.
    await MediaFocus.instance.claim(this);
    if (youtubeEmbed(track.youtubeId) != null) {
      if (mounted) setState(() => _playing = track);
      return;
    }
    if (context.mounted) {
      await LinkOpener.openOrWarn(context, track.watchUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final scheme = Theme.of(context).colorScheme;
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(
        ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width));
    final s = widget.series;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(s.titleFor(locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _player(scheme, locale),
              const SizedBox(height: 12),
              _languageRow(locale),
              const SizedBox(height: 14),
              Text(
                _episode.titleFor(locale),
                style: TextStyle(
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                uiStrings[s.creditKey]?[locale] ?? 'Christian Disciples Church',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if (!s.isSingle) ...[
                const SizedBox(height: 18),
                Text(
                  s.taglineFor(locale),
                  style: TextStyle(
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                for (final e in s.episodes) _episodeTile(e, locale, scheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _player(ColorScheme scheme, String locale) {
    final track = _selected;
    if (track == null) {
      return const SizedBox.shrink();
    }
    final playing = _playing;
    if (playing != null && playing.youtubeId == track.youtubeId) {
      final embed = youtubeEmbed(track.youtubeId);
      if (embed != null) {
        return AspectRatio(aspectRatio: 16 / 9, child: embed);
      }
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: InkWell(
        onTap: () => _play(context, track),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              track.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: scheme.surface),
            ),
            const ColoredBox(color: Color(0x33000000)),
            Center(
              child: Icon(Icons.play_circle_filled_rounded,
                  size: 64, color: Colors.white.withValues(alpha: 0.92)),
            ),
            if (youtubeEmbed(track.youtubeId) == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Text(
                  uiStrings['videosWatchOnYouTube']?[locale] ??
                      'Watch on YouTube',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Built from THIS episode's tracks, never the series'. 在十字架下 has
  /// Mandarin on episode 1 and nowhere else (the user is adding the rest
  /// as they record them), so episodes 2-10 must show no Mandarin button
  /// — offering one that played the Cantonese take would be the app
  /// saying something untrue.
  Widget _languageRow(String locale) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final t in _episode.tracks)
          ChoiceChip(
            selected: t.lang == _lang,
            label: Text(uiStrings[t.labelKey]?[locale] ?? t.lang),
            onSelected: (_) {
              if (t.lang == _lang) return;
              setState(() {
                _lang = t.lang;
                // Switching language re-arms the poster rather than
                // swapping the iframe under a playing video.
                _playing = null;
              });
            },
          ),
      ],
    );
  }

  Widget _episodeTile(VideoEpisode e, String locale, ColorScheme scheme) {
    final current = e.id == _episode.id;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor:
            current ? scheme.primary : scheme.surfaceContainerHighest,
        child: Text(
          '${e.number}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: current ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        e.titleFor(locale),
        style: TextStyle(
          fontFamilyFallback: kCjkFontFallback,
          fontSize: 14,
          fontWeight: current ? FontWeight.w700 : FontWeight.w400,
          color: scheme.onSurface,
        ),
      ),
      onTap: () => setState(() {
        _episode = e;
        _playing = null;
        if (e.trackFor(_lang) == null) {
          // This episode has nothing in the current language. Fall back
          // the same way the page opened — by locale — rather than to
          // whichever track happens to be first in the JSON.
          _lang = e.trackForLocale(locale)?.lang ??
              e.defaultTrack?.lang ??
              _lang;
        }
      }),
    );
  }
}
