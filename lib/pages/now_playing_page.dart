// Flutter's material library exports its own RepeatMode (for
// RepeatingAnimationBuilder), which collides with the player's. Hide
// it here — this file only ever means the playback one.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Full-screen player.
///
/// Deliberately large-target and low-density: the stated use case is
/// listening in a car, where every extra glance costs attention. The
/// transport row uses 44–64px hit areas, the scrubber is full width,
/// and nothing here needs a long press or a swipe.
class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final player = SongPlayerService.instance;
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['songsNowPlaying']?[locale] ?? 'Now playing'),
      ),
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final item = player.currentItem;
          if (item == null) {
            return Center(
              child: Text(
                uiStrings['songsNothingPlaying']?[locale] ??
                    'Nothing is playing.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            );
          }
          final song = item.song;
          final queue = player.queue;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Artwork(url: song.artworkUrl, scheme: scheme),
                    const SizedBox(height: 22),
                    Text(
                      song.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (song.creditLine != null) song.creditLine!,
                        song.album ?? song.sourceLabel,
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    if (item.kind != 'vocal') ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            item.kind == 'instrumental'
                                ? Icons.piano_rounded
                                : Icons.queue_music_rounded,
                            size: 16,
                          ),
                          label: Text(
                            item.kind == 'instrumental'
                                ? (uiStrings['songsTrackInstrumental']
                                        ?[locale] ??
                                    'Instrumental')
                                : (uiStrings['songsTrackAccompaniment']
                                        ?[locale] ??
                                    'Accompaniment'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _Scrubber(player: player, scheme: scheme),
                    const SizedBox(height: 8),
                    _Transport(player: player, scheme: scheme, locale: locale),
                    const SizedBox(height: 16),
                    _SecondaryRow(
                        player: player, scheme: scheme, locale: locale),
                    if (queue.length > 1) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          '${queue.index + 1} / ${queue.length}'
                          '${queue.sourceLabel == null ? '' : ' · ${queue.sourceLabel}'}',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final String? url;
  final ColorScheme scheme;
  const _Artwork({required this.url, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final side = (MediaQuery.of(context).size.width * 0.62).clamp(180.0, 320.0);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: side,
          height: side,
          child: url == null
              ? _placeholder()
              // Only fydt publishes artwork, so a missing image is the
              // common case, not an error — fall back silently.
              : Image.network(url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder()),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: Icon(Icons.library_music_rounded,
            size: 64, color: scheme.primary.withValues(alpha: 0.55)),
      );
}

class _Scrubber extends StatelessWidget {
  final SongPlayerService player;
  final ColorScheme scheme;
  const _Scrubber({required this.player, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final total = player.duration;
    final pos = player.position;
    final max = total.inMilliseconds.toDouble();
    final value = max <= 0
        ? 0.0
        : pos.inMilliseconds.toDouble().clamp(0.0, max);
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: value,
            max: max <= 0 ? 1 : max,
            // Disabled until a duration is known, rather than showing a
            // scrubber that jumps back when the user lets go.
            onChanged: max <= 0
                ? null
                : (v) =>
                    player.seek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(SongPlayerService.formatDuration(pos),
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              Text(SongPlayerService.formatDuration(total),
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  final SongPlayerService player;
  final ColorScheme scheme;
  final String locale;
  const _Transport({
    required this.player,
    required this.scheme,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final queue = player.queue;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 26,
          tooltip: uiStrings['songsShuffle']?[locale] ?? 'Shuffle',
          isSelected: queue.shuffled,
          color: queue.shuffled ? scheme.primary : scheme.onSurfaceVariant,
          icon: const Icon(Icons.shuffle_rounded),
          onPressed: () => player.setShuffle(!queue.shuffled),
        ),
        IconButton(
          iconSize: 34,
          tooltip: uiStrings['songsPrevious']?[locale] ?? 'Previous',
          color: scheme.onSurface,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: queue.isEmpty ? null : player.previous,
        ),
        // Primary control, deliberately the biggest thing on screen.
        SizedBox(
          width: 64,
          height: 64,
          child: Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              // toggle() on the already-current URL flips play/pause,
              // so both directions are the same call.
              onTap: () => player.toggle(
                  player.current!, player.track, player.currentUrl),
              child: player.isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: scheme.onPrimary),
                    )
                  : Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 36,
                      color: scheme.onPrimary,
                    ),
            ),
          ),
        ),
        IconButton(
          iconSize: 34,
          tooltip: uiStrings['songsNext']?[locale] ?? 'Next',
          color: scheme.onSurface,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: queue.isEmpty ? null : player.next,
        ),
        IconButton(
          iconSize: 26,
          tooltip: uiStrings['songsRepeat']?[locale] ?? 'Repeat',
          isSelected: queue.repeat != RepeatMode.off,
          color: queue.repeat == RepeatMode.off
              ? scheme.onSurfaceVariant
              : scheme.primary,
          icon: Icon(queue.repeat == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded),
          onPressed: () => player.setRepeat(switch (queue.repeat) {
            RepeatMode.off => RepeatMode.all,
            RepeatMode.all => RepeatMode.one,
            RepeatMode.one => RepeatMode.off,
          }),
        ),
      ],
    );
  }
}

/// Sleep timer + stop. Secondary because neither is needed mid-drive.
class _SecondaryRow extends StatelessWidget {
  final SongPlayerService player;
  final ColorScheme scheme;
  final String locale;
  const _SecondaryRow({
    required this.player,
    required this.scheme,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final sleepAt = player.sleepAt;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          icon: Icon(
            sleepAt == null
                ? Icons.bedtime_outlined
                : Icons.bedtime_rounded,
            size: 18,
            color: sleepAt == null ? scheme.onSurfaceVariant : scheme.primary,
          ),
          label: Text(
            sleepAt == null
                ? (uiStrings['songsSleepTimer']?[locale] ?? 'Sleep timer')
                : _remaining(sleepAt),
            style: TextStyle(
              fontSize: 13,
              color: sleepAt == null ? scheme.onSurfaceVariant : scheme.primary,
            ),
          ),
          onPressed: () => _pickSleep(context),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: Icon(Icons.stop_rounded,
              size: 18, color: scheme.onSurfaceVariant),
          label: Text(uiStrings['songsStop']?[locale] ?? 'Stop',
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant)),
          onPressed: player.stop,
        ),
      ],
    );
  }

  String _remaining(DateTime at) {
    final left = at.difference(DateTime.now());
    if (left.isNegative) return '—';
    final m = left.inMinutes + 1;
    return '$m min';
  }

  void _pickSleep(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in [15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$minutes '
                    '${uiStrings['songsMinutes']?[locale] ?? 'minutes'}'),
                onTap: () {
                  player.setSleepTimer(Duration(minutes: minutes));
                  Navigator.of(sheetCtx).pop();
                },
              ),
            if (player.sleepAt != null)
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(
                    uiStrings['songsSleepCancel']?[locale] ?? 'Cancel timer'),
                onTap: () {
                  player.setSleepTimer(null);
                  Navigator.of(sheetCtx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
