import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:yswords/services/media_focus.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/pages/song_score_page.dart' show SongNotFoundScaffold;
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/route_paths.dart' show songSubPagePath;
import 'package:yswords/widgets/localized_back_button.dart';

/// The music video, played inside the app.
///
/// 82 songs publish a direct mp4 (fydt's own CDN) and every one of them
/// used to hand off to the browser. That is worse than it sounds on a
/// phone: leaving the app stops the audio queue, and coming back does
/// not restore it.
///
/// **Only the mp4s.** YouTube and SoundCloud rows keep opening
/// externally — embedding those needs a WebView on five of the six
/// platforms this app ships to, which is the trade the Song model
/// already documents and this page does not reopen.
class SongVideoPage extends StatefulWidget {
  final Song song;
  final String locale;
  const SongVideoPage({super.key, required this.song, required this.locale});

  /// Where `video_player` actually has an implementation.
  ///
  /// The plugin ships iOS, Android, macOS and web. Windows and Linux
  /// have no federated implementation, and calling it there throws at
  /// runtime rather than failing to build — so those two keep the
  /// link-out they already had. Claiming support and then crashing
  /// would be worse than the browser tab.
  ///
  /// Uses `defaultTargetPlatform` rather than `dart:io`'s `Platform`:
  /// importing dart:io here would not compile for web at all, and the
  /// kIsWeb guard would never get the chance to run.
  static bool get isSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static Future<void> open(
      BuildContext context, Song song, String locale) async {
    final url = song.videoUrl;
    if (url == null) return;
    if (!isSupported) {
      await LinkOpener.openOrWarn(context, url, locale: locale);
      return;
    }
    // URL-routing Stage 5 (`docs/url-routing-plan.md` §6 batch 4) — the
    // second of the two raw-`Navigator.push` sites §2 found. See
    // `SongScorePage.open` for why this moved onto `pushPage`.
    await pushPage<void>(
      SongVideoPage(song: song, locale: locale),
      routeName: songSubPagePath(song.id, 'video'),
    );
  }

  @override
  State<SongVideoPage> createState() => _SongVideoPageState();
}

class _SongVideoPageState extends State<SongVideoPage> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Registered so the reverse holds too: starting a hymn pauses
    // this video. Pause, not dispose — coming back to the page should
    // find the video where it was.
    MediaFocus.instance.register(this, () async {
      final c = _controller;
      if (c != null && c.value.isPlaying) await c.pause();
    });
    _init();
  }

  Future<void> _init() async {
    final url = widget.song.videoUrl;
    if (url == null) return;
    try {
      // Same same-origin rewrite the audio uses: on web the church CDN
      // sends no Access-Control-Allow-Origin, so a direct load is
      // blocked before any bytes arrive. Returns the URL untouched on
      // native, where there is no CORS to satisfy.
      final c = VideoPlayerController.networkUrl(
        Uri.parse(SongPlayerService.resolvePlaybackUrl(url)),
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
      await MediaFocus.instance.claim(this);
      await c.play();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    MediaFocus.instance.unregister(this);
    // Stopping matters as much as freeing: a video left playing into a
    // disposed page keeps its audio session open and fights the song
    // queue for the output.
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = widget.song.videoUrl;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (url != null)
            IconButton(
              tooltip:
                  uiStrings['songsOpenOriginal']?[widget.locale] ?? 'Original',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => LinkOpener.openOrWarn(context, url, locale: widget.locale),
            ),
        ],
      ),
      body: Center(child: _body(scheme, url)),
    );
  }

  Widget _body(ColorScheme scheme, String? url) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              uiStrings['songsVideoFailed']?[widget.locale] ??
                  'The video could not be played.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text('$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.white38)),
            if (url != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white),
                onPressed: () => LinkOpener.openOrWarn(context, url, locale: widget.locale),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(uiStrings['songsOpenOriginal']?[widget.locale] ??
                    'Original page'),
              ),
            ],
          ],
        ),
      );
    }

    final c = _controller;
    if (c == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
        VideoProgressIndicator(c, allowScrubbing: true),
        const SizedBox(height: 8),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (context, v, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 44,
                color: Colors.white,
                icon: Icon(v.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded),
                onPressed: () async {
                  if (v.isPlaying) {
                    await c.pause();
                    return;
                  }
                  await MediaFocus.instance.claim(this);
                  await c.play();
                },
              ),
              const SizedBox(width: 12),
              Text(
                '${SongPlayerService.formatDuration(v.position)}'
                ' / '
                '${SongPlayerService.formatDuration(v.duration)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// URL-routing Stage 5 (`docs/url-routing-plan.md` §6 batch 4): the
/// cold-load resolver behind `/songs/:songId/video`. Twin of
/// `SongScoreByIdPage` — see that class for why the async id → [Song]
/// step needs a widget of its own, and `SongNotFoundScaffold` (shared
/// with it) for the not-found body.
///
/// A song that exists but publishes no mp4 falls through to
/// [SongVideoPage], which already renders its own "no video" state — so
/// this wrapper only answers "is there such a song."
class SongVideoByIdPage extends StatefulWidget {
  final String id;
  const SongVideoByIdPage({super.key, required this.id});

  @override
  State<SongVideoByIdPage> createState() => _SongVideoByIdPageState();
}

class _SongVideoByIdPageState extends State<SongVideoByIdPage> {
  Song? _song;
  bool _resolving = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final found = await SongService.byId(widget.id);
    if (!mounted) return;
    setState(() {
      _song = found;
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final locale = Provider.of<AppSettings>(context, listen: false).locale;
    final song = _song;
    if (song == null) return SongNotFoundScaffold(locale: locale);
    return SongVideoPage(song: song, locale: locale);
  }
}
