import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/one_god_episode.dart';
import 'package:yswords/models/subtitle_track.dart';
import 'package:yswords/services/one_god_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// 獨一真神 — the same teaching in English, Cantonese and Mandarin.
///
/// The three recordings are one episode with three tracks, not three
/// items, because that is what they are: "内容是一样". Switching
/// language **keeps your position**, which is the point — someone
/// checking how a phrase was rendered in Cantonese should not have to
/// find their place again.
class OneGodPage extends StatefulWidget {
  const OneGodPage({super.key});

  @override
  State<OneGodPage> createState() => _OneGodPageState();
}

class _OneGodPageState extends State<OneGodPage> {
  OneGodBundle? _bundle;
  Object? _loadError;

  VideoPlayerController? _controller;
  Object? _videoError;
  bool _switching = false;

  String _lang = 'cmn';
  bool _showTranscript = false;

  /// Locale key of the subtitle track on screen, or null for off.
  /// Persisted across a language switch when the new recording offers
  /// the same one — someone reading Traditional wants Traditional again.
  String? _subLocale;
  SubtitleTrack _subs = SubtitleTrack.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(OneGodService.assetPath);
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final bundle = OneGodBundle(
        episodes: [
          for (final e in (doc['episodes'] as List? ?? []))
            OneGodEpisode.fromJson(e as Map<String, dynamic>),
        ],
        videoBase: OneGodService.videoBase,
      );
      if (!mounted) return;
      setState(() => _bundle = bundle);
      final ep = bundle.episodes.isEmpty ? null : bundle.episodes.first;
      if (ep != null) await _open(ep, _lang);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// Load [lang] for [ep], resuming wherever the previous track was.
  ///
  /// The recordings are not the same length (17:17 / 17:18 / 18:35), so
  /// the resume point is clamped — seeking past the end of a shorter
  /// take would otherwise land the user at a black frame.
  Future<void> _open(OneGodEpisode ep, String lang) async {
    final track = ep.trackFor(lang);
    if (track == null) return;
    final bundle = _bundle;
    if (bundle == null) return;

    final previous = _controller;
    final resumeAt = previous?.value.position ?? Duration.zero;
    final wasPlaying = previous?.value.isPlaying ?? false;

    setState(() {
      _switching = true;
      _videoError = null;
    });

    try {
      final next = VideoPlayerController.networkUrl(
        Uri.parse(bundle.urlFor(track)),
      );
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      final total = next.value.duration;
      if (resumeAt > Duration.zero && resumeAt < total) {
        await next.seekTo(resumeAt);
      }
      // Carry the subtitle choice across if this recording has it;
      // otherwise fall to its first available track rather than
      // silently turning captions off on someone who was reading them.
      String? nextSub;
      if (_subLocale != null && track.subtitles.containsKey(_subLocale)) {
        nextSub = _subLocale;
      } else if (_subLocale != null && track.subtitles.isNotEmpty) {
        nextSub = track.subtitles.keys.first;
      }
      final loaded = await _loadSubs(track, nextSub);

      setState(() {
        _controller = next;
        _lang = lang;
        _switching = false;
        _subLocale = nextSub;
        _subs = loaded;
      });
      // Dispose the OLD controller only after the new one is on screen,
      // so switching language does not flash an empty box.
      await previous?.pause();
      await previous?.dispose();
      if (wasPlaying) await next.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoError = e;
          _switching = false;
        });
      }
    }
  }

  Future<SubtitleTrack> _loadSubs(OneGodTrack track, String? locale) async {
    final path = locale == null ? null : track.subtitles[locale];
    if (path == null) return SubtitleTrack.empty;
    try {
      return SubtitleTrack.parse(await rootBundle.loadString(path));
    } catch (e) {
      // A missing or broken caption file must never take the video with
      // it — subtitles are an accessory to the thing the user came for.
      debugPrint('[OneGod] subtitles $path failed: $e');
      return SubtitleTrack.empty;
    }
  }

  Future<void> _setSubtitle(OneGodEpisode ep, String? locale) async {
    final track = ep.trackFor(_lang);
    if (track == null) return;
    final loaded = await _loadSubs(track, locale);
    if (!mounted) return;
    setState(() {
      _subLocale = locale;
      _subs = loaded;
    });
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
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
        title: Text(uiStrings['oneGodTitle']?[locale] ?? 'The Only True God'),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: _body(settings, locale, scheme),
        ),
      ),
    );
  }

  Widget _body(AppSettings settings, String locale, ColorScheme scheme) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text('$_loadError',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    final bundle = _bundle;
    if (bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bundle.episodes.isEmpty) {
      return Center(
        child: Text(uiStrings['oneGodEmpty']?[locale] ?? 'Nothing here yet.',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    final ep = bundle.episodes.first;
    final transcript = ep.transcriptFor(locale);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _player(scheme, locale),
        const SizedBox(height: 12),
        _languageRow(ep, scheme, locale),
        const SizedBox(height: 8),
        _subtitleRow(ep, scheme, locale),
        const SizedBox(height: 16),
        Text(
          ep.titleFor(locale),
          style: TextStyle(
            fontFamily: settings.fontFamily,
            fontFamilyFallback: kCjkFontFallback,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          uiStrings['oneGodCredit']?[locale] ?? 'Christian Disciples Church',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        if (transcript.isNotEmpty) ...[
          const SizedBox(height: 16),
          _transcriptToggle(scheme, locale, transcript.length),
          if (_showTranscript) ...[
            const SizedBox(height: 10),
            _transcript(transcript, settings, scheme),
          ],
        ],
      ],
    );
  }

  Widget _player(ColorScheme scheme, String locale) {
    if (_videoError != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_rounded,
                      size: 40, color: Colors.white54),
                  const SizedBox(height: 10),
                  Text(
                    uiStrings['songsVideoFailed']?[locale] ??
                        'The video could not be played.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text('$_videoError',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
            // Drawn by us, not by the platform: `video_player` has no
            // caption API that behaves the same on web, iOS, Android
            // and macOS, and a subtitle that appears on one platform
            // and not another is worse than none.
            if (!_subs.isEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (context, v, _) {
                    final cue = _subs.cueAt(v.position);
                    if (cue == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Text(
                            cue.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.35,
                              // A hard shadow keeps it readable over a
                              // bright frame even where the scrim is
                              // thin.
                              shadows: [
                                Shadow(blurRadius: 3, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // Only while a language switch is in flight — the old frame
            // stays visible underneath so the screen never goes blank.
            if (_switching)
              const ColoredBox(
                color: Color(0x66000000),
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
        VideoProgressIndicator(c, allowScrubbing: true),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (context, v, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 26,
                icon: const Icon(Icons.replay_10_rounded),
                color: scheme.onSurfaceVariant,
                onPressed: () => c.seekTo(
                    v.position - const Duration(seconds: 10)),
              ),
              IconButton(
                iconSize: 44,
                color: scheme.primary,
                icon: Icon(v.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded),
                onPressed: () => v.isPlaying ? c.pause() : c.play(),
              ),
              IconButton(
                iconSize: 26,
                icon: const Icon(Icons.forward_10_rounded),
                color: scheme.onSurfaceVariant,
                onPressed: () => c.seekTo(
                    v.position + const Duration(seconds: 10)),
              ),
              const SizedBox(width: 8),
              Text(
                '${_hms(v.position)} / ${_hms(v.duration)}',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The three recordings. Position carries across — see [_open].
  Widget _languageRow(
      OneGodEpisode ep, ColorScheme scheme, String locale) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final t in ep.tracks)
          ChoiceChip(
            selected: t.lang == _lang,
            label: Text(uiStrings[t.labelKey]?[locale] ?? t.lang),
            onSelected: _switching
                ? null
                : (_) {
                    if (t.lang != _lang) _open(ep, t.lang);
                  },
          ),
      ],
    );
  }

  /// Subtitle picker. Offers only what THIS recording actually has —
  /// see [OneGodTrack.subtitles]. Listing a language we cannot
  /// synchronise would be offering a caption that drifts.
  Widget _subtitleRow(
      OneGodEpisode ep, ColorScheme scheme, String locale) {
    final track = ep.trackFor(_lang);
    final available = track?.subtitles.keys.toList() ?? const <String>[];
    if (available.isEmpty) return const SizedBox.shrink();

    const names = {
      'zh-Hant': 'oneGodSubHant',
      'zh-Hans': 'oneGodSubHans',
      'en': 'oneGodSubEn',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.closed_caption_outlined,
            size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              selected: _subLocale == null,
              label: Text(uiStrings['oneGodSubOff']?[locale] ?? 'Off'),
              onSelected: (_) => _setSubtitle(ep, null),
            ),
            for (final k in available)
              ChoiceChip(
                selected: _subLocale == k,
                label: Text(uiStrings[names[k]]?[locale] ?? k),
                onSelected: (_) => _setSubtitle(ep, k),
              ),
          ],
        ),
      ],
    );
  }

  Widget _transcriptToggle(
      ColorScheme scheme, String locale, int paragraphs) {
    return Row(
      children: [
        Expanded(
          child: Text(
            uiStrings['oneGodTranscript']?[locale] ?? 'Transcript',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface),
          ),
        ),
        Switch(
          value: _showTranscript,
          onChanged: (v) => setState(() => _showTranscript = v),
        ),
      ],
    );
  }

  Widget _transcript(
      List<String> paras, AppSettings settings, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Said plainly rather than left to be discovered: the church's
          // document has no timings anywhere in it, so this text cannot
          // follow the video and must not look like it is trying to.
          Text(
            uiStrings['oneGodTranscriptNote']?[settings.locale] ??
                'Full text of the teaching. It does not follow the video '
                    '— the source document carries no timings.',
            style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final p in paras) ...[
            SelectableText(
              p,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.fontSize.clamp(14.0, 20.0),
                height: 1.75,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  static String _hms(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
