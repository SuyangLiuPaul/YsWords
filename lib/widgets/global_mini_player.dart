import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/now_playing_page.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/remote_image.dart';

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
            // NOT `const _Strip()`.
            //
            // 2026-08-11, reported from an iPhone as "it is playing but
            // the bottom is not moving": elapsed time frozen at 0:00 and
            // the button stuck on ▶, while the row above it correctly
            // showed ⏸ for the same song.
            //
            // A const constructor call is canonicalised, so every
            // rebuild handed `Element.updateChild` the *identical*
            // Widget instance. Its `child.widget == newWidget` fast path
            // then returns early without rebuilding — which silently
            // disabled this ListenableBuilder altogether. The player was
            // notifying correctly the whole time (`onPosition` →
            // `_broadcast()` → `notifyUi()` → `revision`); nothing
            // downstream ever re-read it.
            //
            // Without `const`, each rebuild is a fresh instance, the
            // identity check fails, and the strip repaints. Do not let a
            // `prefer_const_constructors` hint put it back: that lint is
            // wrong for a widget whose entire purpose is to re-read
            // mutable state on every notification.
            // ignore: prefer_const_constructors
            return _Strip();
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
                    // 'blocked' means the browser refused to start
                    // without a tap — the track is fine and one more
                    // tap plays it. Saying "could not play that track"
                    // there would send someone hunting for a dead link
                    // that does not exist.
                    switch (error) {
                      // The browser refused to start without a tap —
                      // the track is fine and one more tap plays it.
                      'blocked' => uiStrings['songsPlaybackBlocked']
                              ?[locale] ??
                          'Tap play again — the browser needs a tap '
                              'before it will start audio.',
                      // Asked for a mix nothing in the queue has.
                      'no-tracks' => uiStrings['songsNoTracksForMix']
                              ?[locale] ??
                          'None of these songs have that mix.',
                      _ => uiStrings['songsPlaybackFailed']?[locale] ??
                          'Could not play that track.',
                    },
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

    // Swipe the strip aside to dismiss it, the way every music app
    // lets you. The ✕ is the discoverable route; this is the one that
    // becomes muscle memory. `key` is required by Dismissible and must
    // be stable for the widget, not the song — keying it on the song id
    // would make a track change look like a dismissal.
    return Dismissible(
      key: const ValueKey('global-mini-player'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => player.dismiss(),
      background: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Icon(Icons.close_rounded,
                size: 20, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
      secondaryBackground: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.close_rounded,
                size: 20, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
      child: Material(
        color: scheme.surfaceContainerHigh,
        child: SafeArea(
          top: false,
          // The BAR stays full-bleed — a music bar that stopped at a
          // column edge would look detached from the window. Its
          // CONTENTS are centred in the same column every page uses.
          //
          // Reported from the web build: "网页版下面设计歌曲这个部分不行
          // iPhone版本没问题". On a phone the strip is the column, so
          // nothing looked wrong; on a desktop window the title was
          // pinned to the far left and the buttons to the far right
          // with a metre of empty bar between them, while the page
          // itself sat in a 640px column in the middle.
          child: Center(
            child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveBreakpoints.settingsMaxWidth(
                  ResponsiveBreakpoints.classOf(
                      MediaQuery.of(context).size.width)),
            ),
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
                    // Small enough to cost nothing, big enough to tell
                    // you what is playing at a glance. `cacheWidth`
                    // keeps the decode budget at the displayed size.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: RemoteImage(
                          // These hosts (fydt.org, CDC) send no
                          // Access-Control-Allow-Origin, so on web
                          // CanvasKit may not read the bytes it just
                          // downloaded and the artwork renders blank.
                          // `prefer` makes Flutter lay out a real <img>
                          // element, which the browser is allowed to
                          // paint cross-origin. Native ignores this.
                          // Reported: "为什么歌曲的图片在iPhone有web没有呢".
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.prefer,
                          url: song.artworkUrl,
                          cacheWidth: 102,
                          cacheHeight: 102,
                          fit: BoxFit.cover,
                          fallback: (_) => ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.music_note_rounded,
                                size: 18, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                      ),
                    // Always present, whatever the queue length.
                    //
                    // This used to be an `else` on the branch above: a
                    // stop button ONLY when the queue held one song. But
                    // every row's play button queues the whole filtered
                    // list, so in normal use the queue is long and there
                    // was no way to put the player away — and `stop()`
                    // would not have hidden the strip anyway, since it
                    // keeps the queue. Reported as "去其他页面底下还是有
                    // 播放器，一直在那里，但是每次退出才没有".
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded),
                      color: scheme.onSurfaceVariant,
                      tooltip: uiStrings['songsClosePlayer']?[locale] ??
                          'Close player',
                      onPressed: player.dismiss,
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}
