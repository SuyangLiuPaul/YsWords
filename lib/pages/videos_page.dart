import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/video_series.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/jump_to_reference.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/entry_copy.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/media_focus.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/remote_image.dart';
import 'package:yswords/widgets/youtube_embed.dart';

const String kVideosAssetPath = 'assets/videos.json';

/// Memoised like `MapService.loadMaps()` / `SermonService.loadIndex()` —
/// added when `/videos/:id` (`VideoSeriesByIdPage` below) started
/// calling this a second time in the same session (list page, then a
/// cold deep-link into a series): a bare bundled-asset read is cheap
/// once, but re-parsing `assets/videos.json` on every navigation is
/// pointless work with nothing that ever changes it at runtime.
List<VideoSeries>? _cachedSeries;

Future<List<VideoSeries>> loadVideoSeries() async {
  final cached = _cachedSeries;
  if (cached != null) return cached;
  final raw = await rootBundle.loadString(kVideosAssetPath);
  final parsed =
      VideoSeries.listFromJson(jsonDecode(raw) as Map<String, dynamic>);
  _cachedSeries = parsed;
  return parsed;
}

/// URL-routing Stage 4 (`docs/url-routing-plan.md` §6 batch 2): the
/// `/videos/:id` cold-load / shared-link entry point, following the
/// same pattern as `SermonByIdPage` — resolve the id against
/// [loadVideoSeries] (the bundled `assets/videos.json`, so this never
/// hits the network), show a spinner while resolving, then swap in the
/// real [VideoSeriesPage] once found. An id with no match (a stale or
/// hand-typed link) shows an explicit not-found state.
///
/// The one in-app call site (`videos_page.dart`'s own card `onTap`)
/// keeps pushing [VideoSeriesPage] directly with the series object it
/// already has — only a cold load or browser Back/Forward into this
/// path goes through the id lookup here.
class VideoSeriesByIdPage extends StatefulWidget {
  final String id;
  const VideoSeriesByIdPage({super.key, required this.id});

  @override
  State<VideoSeriesByIdPage> createState() => _VideoSeriesByIdPageState();
}

class _VideoSeriesByIdPageState extends State<VideoSeriesByIdPage> {
  VideoSeries? _series;
  bool _resolving = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final all = await loadVideoSeries();
    VideoSeries? found;
    for (final s in all) {
      if (s.id == widget.id) {
        found = s;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _series = found;
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final series = _series;
    if (series == null) {
      final locale = Provider.of<AppSettings>(context, listen: false).locale;
      return Scaffold(
        appBar: AppBar(leading: const LocalizedBackButton()),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              uiStrings['videoSeriesNotFound']?[locale] ??
                  'Video series not found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    return VideoSeriesPage(series: series);
  }
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
        onTap: () => pushPage(VideoSeriesPage(series: s),
            routeName: '/videos/${s.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cover != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                // RemoteImage, not Image.network, for one reason: the
                // failure memo. See [_episodeThumb] for the whole
                // argument — the short version is that these point at
                // i.ytimg.com, which is unreachable for the users this
                // app deliberately ships an offline snapshot for.
                child: RemoteImage(
                  url: cover.thumbnailUrl,
                  fit: BoxFit.cover,
                  fallback: (_) => ColoredBox(
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

  /// Where the next embed should start, in whole seconds.
  ///
  /// Only ever non-zero for one case: the reader switched language while
  /// a video was playing, and the outgoing player told us where it was.
  /// The self-hosted player this page replaced kept your place across
  /// that switch and the YouTube embed did not — it re-armed the poster,
  /// so switching language 40 minutes into a teaching meant finding
  /// those 40 minutes again by hand.
  ///
  /// Reset to 0 by every other way of arriving at a video (the poster
  /// tap, a change of episode), because those are all "start this from
  /// the beginning" and a stale resume there would be worse than none.
  int _resumeAt = 0;

  /// Skips a marked track even if [_lang] names it: [_lang] is normally
  /// kept in sync with a playable track by [initState] and the episode
  /// switch below, but falling back here too means a stale `_lang` can
  /// never land the reader on a dead video.
  VideoTrack? get _selected {
    final t = _episode.trackFor(_lang);
    if (t != null && !t.isUnavailable) return t;
    return _episode.defaultTrack;
  }

  Future<void> _play(BuildContext context, VideoTrack track) async {
    // A video starting silences the hymn. The reverse cannot be
    // honoured here — the iframe owns its own playback and exposes no
    // pause to us — so this page deliberately does not register with
    // MediaFocus as something that can be paused. Claiming without
    // registering is exactly that asymmetry, made explicit.
    await MediaFocus.instance.claim(this);
    if (youtubeEmbed(track.youtubeId) != null) {
      if (mounted) {
        setState(() {
          _playing = track;
          // A tap on the poster is "play this", not "resume this".
          _resumeAt = 0;
        });
      }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: uiStrings['copySelection']?[locale] ?? 'Copy',
            onPressed: () => ClipboardHelper.copyWithFeedback(
              context,
              formatEntryForCopy(
                heading: _episode.titleFor(locale),
                body: uiStrings[s.creditKey]?[locale] ??
                    'Christian Disciples Church',
                refs: _episode.refs.map((r) => _refLabel(r, locale)),
                // The track actually on screen, not the episode's
                // default: the reader chose a language, and a link that
                // opens a different one is a wrong answer that looks
                // right.
                url: _selected?.watchUrl,
              ),
            ),
          ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
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
              _refsRow(locale, scheme),
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
                _wholeSeriesRow(s, locale, scheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "Watch the whole series" — all ten parts in one video.
  ///
  /// Below the episode list, not inside it. The church publishes these
  /// compilations and the app had been ignoring them because adding an
  /// eleventh row to a series titled "A 10-Part Journey" makes the app
  /// contradict itself. A separate row is the answer to that, and it is
  /// why the exclusion test can stay exactly as it is.
  ///
  /// Opens on YouTube rather than in the embedded player: these run over
  /// an hour, the page's player has no position memory (see the
  /// language-switch note in the queue), and losing your place an hour
  /// in is worse than leaving the app.
  Widget _wholeSeriesRow(
      VideoSeries s, String locale, ColorScheme scheme) {
    final compilations = s.playableCompilations;
    if (compilations.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings['videoWholeSeries']?[locale] ??
                'Watch the whole series',
            style: TextStyle(
              fontFamilyFallback: kCjkFontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in compilations)
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: Text(
                    uiStrings[c.labelKey]?[locale] ?? c.lang,
                    style: const TextStyle(
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () =>
                      LinkOpener.openOrWarn(context, c.watchUrl),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The scripture this episode is built on, as chips that open the
  /// passage.
  ///
  /// The church's page prints these under every part and the app showed
  /// none of them, which in a Bible app is the wrong way round: a
  /// viewer hears 「父親啊，赦免他們」 quoted and has to go looking for it.
  ///
  /// Renders nothing at all when an episode has no references —
  /// episode 1 genuinely cites none, and a "Scripture" heading over an
  /// empty row would read as a loading failure.
  Widget _refsRow(String locale, ColorScheme scheme) {
    final refs = _episode.refs;
    if (refs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings['videoScripture']?[locale] ?? 'Scripture',
            style: TextStyle(
              fontFamilyFallback: kCjkFontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in refs) _refChip(r, locale, scheme),
            ],
          ),
        ],
      ),
    );
  }

  /// `John 3:16` in the reader's language, as the chip prints it.
  ///
  /// Shared with the copy action so the clipboard says what the screen
  /// says. The reader's own version names the book where it can, so the
  /// chip agrees with the header they are about to land on.
  String _refLabel(VideoRef r, String locale) {
    final version = context.read<MainProvider>().currentVersion;
    return '${localeAwareBookName(r.book, locale, version)} '
        '${r.chapter}:${r.verse}';
  }

  Widget _refChip(VideoRef r, String locale, ColorScheme scheme) {
    return ActionChip(
      label: Text(
        _refLabel(r, locale),
        style: TextStyle(
          fontFamilyFallback: kCjkFontFallback,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
      ),
      avatar: Icon(Icons.menu_book_outlined,
          size: 16, color: scheme.onSecondaryContainer),
      backgroundColor: scheme.secondaryContainer,
      side: BorderSide.none,
      onPressed: () => _openRef(r),
    );
  }

  /// Same path every other citation in the app takes: resolve (with the
  /// full-canon fallback for a version that lacks the book), report
  /// what happened, then open the reader. Never navigates on a failed
  /// resolve — a chip that silently does nothing is better than one
  /// that lands the reader somewhere else.
  Future<void> _openRef(VideoRef r) async {
    final mp = context.read<MainProvider>();
    final result = await resolveAndPrepareJump(
      reference: BibleReference(
        englishBook: r.book,
        chapter: r.chapter,
        verseStart: r.verse,
        verseEnd: r.verse,
      ),
      mp: mp,
    );
    if (!mounted) return;
    final ok = await showJumpResultSnackBar(context, result);
    if (!ok || !mounted) return;
    // The video is left playing on purpose. Unmounting the embed is the
    // only stop this page has — `_play` explains why it never registers
    // with MediaFocus — and it is not a pause: coming back would restart
    // the teaching from zero. Someone who taps a verse the speaker just
    // quoted wants to read along, not to lose their place.
    pushPage(const HomePage(), routeName: '/HomePage');
  }

  /// The poster frame behind the play overlay.
  ///
  /// 2026-09-03. The queue listed "convert the other `Image.network`
  /// calls to `RemoteImage`" and then corrected itself: the others
  /// already carry `errorBuilder`, a decode cap and
  /// `webHtmlElementStrategy`, so there is nothing to fix. Re-audited
  /// all 9 call sites, and that is true of 6 of them. These two were
  /// the exception, and two of the three concerns really do not apply:
  ///
  ///   • **The decode cap is moot here.** YouTube's `hqdefault.jpg` is
  ///     480×360 — about 690 KB decoded. Capping it would save nothing.
  ///     That is why it was never added, and it stays absent.
  ///   • **`webHtmlElementStrategy` is not needed.** It exists for
  ///     hosts that send no `Access-Control-Allow-Origin`, which is
  ///     what blanked the song artwork on web. `i.ytimg.com` answers
  ///     `access-control-allow-origin: *` (checked, not assumed), so
  ///     CanvasKit is allowed to read the bytes and the default
  ///     `never` is correct. Do not add `prefer` here by analogy.
  ///
  /// **What does apply is the failure memo**, and for a reason the
  /// original note did not weigh: this app is built for users behind
  /// the GFW — `pubspec.yaml` bundles a whole song catalogue snapshot
  /// on exactly that premise — and `i.ytimg.com` is blocked there.
  /// For those users every one of these thumbnails is a socket that
  /// will never answer, `NetworkImage` has no timeout, and nothing
  /// remembered the failure, so scrolling back paid the full OS wait
  /// again. That is the same mechanism as the `errno = 60` song-list
  /// crash at 7–10 images instead of 199: not a crash, but a page that
  /// hangs grey for a minute every time it is opened, in the one
  /// region that cannot fix it by trying again.
  Widget _player(ColorScheme scheme, String locale) {
    final track = _selected;
    if (track == null) {
      return const SizedBox.shrink();
    }
    final playing = _playing;
    if (playing != null && playing.youtubeId == track.youtubeId) {
      final embed = youtubeEmbed(track.youtubeId, startSeconds: _resumeAt);
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
            RemoteImage(
              url: track.thumbnailUrl,
              fit: BoxFit.cover,
              fallback: (_) => ColoredBox(color: scheme.surface),
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
  ///
  /// [VideoEpisode.playableTracks], not `tracks`: a track can exist in
  /// the data (its id is the only way to recover it later) while being
  /// marked unavailable, and a chip that opens "This video is private"
  /// is the same false claim as one that opens the wrong language.
  Widget _languageRow(String locale) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final t in _episode.playableTracks)
          ChoiceChip(
            selected: t.lang == _lang,
            label: Text(uiStrings[t.labelKey]?[locale] ?? t.lang),
            onSelected: (_) {
              if (t.lang == _lang) return;
              // Ask the outgoing player where it is BEFORE `setState`
              // unmounts its iframe — this is the only moment the
              // question can be asked, and the answer is already cached
              // from the player's own reports, so it is a synchronous
              // read of a window that is about to stop existing.
              final was = _playing;
              final resume = was == null
                  ? 0
                  : (youtubeEmbedPositionSeconds(was.youtubeId) ?? 0);
              final next = _episode.trackFor(t.lang) ?? _episode.defaultTrack;
              setState(() {
                _lang = t.lang;
                // Playing → stay playing, at the same place in the other
                // language's take of the same episode. Only browsing →
                // leave the poster armed, which is what it was already
                // doing and what the reader asked for by not pressing
                // play.
                //
                // Nothing here can be done on a platform whose player
                // cannot answer: `youtubeEmbedPositionSeconds` returns
                // null there, `resume` falls to 0, and the switch behaves
                // exactly as it did before.
                _resumeAt = resume;
                _playing = was == null ? null : next;
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
        // A different episode is a different teaching; a position from
        // the last one would be meaningless in it.
        _resumeAt = 0;
        final inLang = e.trackFor(_lang);
        if (inLang == null || inLang.isUnavailable) {
          // This episode has nothing PLAYABLE in the current language —
          // either it never had this language, or (onegod/01's English)
          // it did and was later marked unavailable. Fall back the same
          // way the page opened — by locale — rather than to whichever
          // track happens to be first in the JSON.
          _lang = e.trackForLocale(locale)?.lang ??
              e.defaultTrack?.lang ??
              _lang;
        }
      }),
    );
  }
}
