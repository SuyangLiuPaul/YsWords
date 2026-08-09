import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/now_playing_page.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/utils/app_nav.dart';

/// App-wide playback strip.
///
/// The mini-player used to live only on the Songs page, so navigating
/// anywhere else left a song playing with no transport, no title and
/// no way to stop it — reported as "switch screens and I can't hear
/// it", because from the user's side a vanished player and stopped
/// audio look identical.
///
/// Wrapped around the whole app in main.dart rather than added to each
/// page, so a page added later cannot forget it.
class GlobalMiniPlayer extends StatelessWidget {
  final Widget child;
  const GlobalMiniPlayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final player = SongPlayerService.instance;
    return Column(
      children: [
        Expanded(child: child),
        ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            if (player.current == null && player.error == null) {
              return const SizedBox.shrink();
            }
            return const _Strip();
          },
        ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip();

  @override
  Widget build(BuildContext context) {
    final player = SongPlayerService.instance;
    final scheme = Theme.of(context).colorScheme;
    final locale = context.watch<AppSettings>().locale;

    final error = player.error;
    if (error != null) {
      return Material(
        color: scheme.errorContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 18, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    uiStrings['songsPlaybackFailed']?[locale] ??
                        'Could not play that track.',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onErrorContainer),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: scheme.onErrorContainer,
                  onPressed: player.clearError,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final song = player.current!;
    final total = player.duration;
    final pos = player.position;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final queue = player.queue;

    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            InkWell(
              onTap: () => pushPage(const NowPlayingPage()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            '${SongPlayerService.formatDuration(pos)}'
                            ' / ${SongPlayerService.formatDuration(total)}'
                            '${queue.length > 1 ? '  ·  ${queue.index + 1}/${queue.length}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (queue.length > 1)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: scheme.onSurfaceVariant,
                        onPressed: player.previous,
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      color: scheme.primary,
                      onPressed: () => player.toggle(
                          song, player.track, player.currentUrl),
                    ),
                    if (queue.length > 1)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: scheme.onSurfaceVariant,
                        onPressed: player.next,
                      )
                    else
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.stop_rounded),
                        color: scheme.onSurfaceVariant,
                        onPressed: player.stop,
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
