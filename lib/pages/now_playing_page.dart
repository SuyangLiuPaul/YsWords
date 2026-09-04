import 'dart:async';

// Flutter's material library exports its own RepeatMode (for
// RepeatingAnimationBuilder), which collides with the player's. Hide
// it here — this file only ever means the playback one.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/song_copy.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/remote_image.dart';
import 'package:yswords/widgets/song_actions.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/scroll_to_top_on_status_bar_tap.dart';

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
        // Saving lives here too. This is the screen you are on when you
        // decide you like a song, and until now keeping it meant going
        // back to the list to find it again.
        actions: [
          if (player.current != null) ...[
            SongFavouriteButton(song: player.current!, locale: locale),
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20),
              tooltip: uiStrings['copySelection']?[locale] ?? 'Copy',
              onPressed: () => ClipboardHelper.copyWithFeedback(
                  context, songCopyText(player.current!, locale)),
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded, size: 22),
              tooltip: uiStrings['songsAddToPlaylist']?[locale],
              onPressed: () =>
                  showAddToPlaylistSheet(context, player.current!, locale),
            ),
          ],
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
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
                    const SizedBox(height: 14),
                    // Switch the WHOLE queue's mix mid-listen. The
                    // per-song chips in the detail sheet only ever
                    // changed one song, and a playlist's preference
                    // could only be set before pressing play — so
                    // "drop the vocals, I'm driving" meant going back
                    // and rebuilding the queue.
                    _MixPicker(player: player, scheme: scheme, locale: locale),
                    const SizedBox(height: 12),
                    _SecondaryRow(
                        player: player, scheme: scheme, locale: locale),
                    // "3 / 47" used to be a dead label. It is the only
                    // place the rest of the queue is visible at all, so
                    // it is now the way in: tap to see what is coming
                    // and jump straight to a track without pressing
                    // next eleven times.
                    if (queue.length > 1) ...[
                      const SizedBox(height: 20),
                      _QueueButton(
                        queue: queue,
                        scheme: scheme,
                        locale: locale,
                        onTap: () => _showQueue(context, locale),
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

void _showQueue(BuildContext context, String locale) {
  showModalBottomSheet<void>(
    // useSafeArea: without it Flutter wraps the sheet in
    // MediaQuery.removePadding(removeTop: true), so any SafeArea
    // INSIDE the sheet sees padding.top == 0 and does nothing —
    // the header then draws under the clock and the notch.
    useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _QueueSheet(locale: locale),
  );
}

class _QueueButton extends StatelessWidget {
  final SongQueue queue;
  final ColorScheme scheme;
  final String locale;
  final VoidCallback onTap;

  const _QueueButton({
    required this.queue,
    required this.scheme,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${uiStrings['songsQueue']?[locale] ?? 'Queue'}'
                  '  ·  ${queue.index + 1} / ${queue.length}'
                  '${queue.sourceLabel == null ? '' : '  ·  ${queue.sourceLabel}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Icon(Icons.expand_less_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The playing order, with the current track highlighted.
///
/// Opens scrolled to the current track rather than to the top: in a
/// 47-song queue the useful part is "what is next", and starting at
/// row 1 would make the user find their place by hand.
class _QueueSheet extends StatefulWidget {
  final String locale;
  const _QueueSheet({required this.locale});

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  static const _rowHeight = 56.0;
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    final index = SongPlayerService.instance.queue.index;
    _controller = ScrollController(
      // Two rows above the current one, so it reads as "here, with
      // context" instead of pinned to the very top edge.
      initialScrollOffset: ((index - 2) * _rowHeight).clamp(0.0, 1e6),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = SongPlayerService.instance;
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final locale = widget.locale;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72),
        child: ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final queue = player.queue;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          uiStrings['songsQueue']?[locale] ?? 'Queue',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ScrollToTopOnStatusBarTap(
                    controller: _controller,
                    child: ListView.builder(
                    controller: _controller,
                    itemExtent: _rowHeight,
                    itemCount: queue.length,
                    itemBuilder: (context, i) {
                      final item = queue.items[i];
                      final current = i == queue.index;
                      return Material(
                        color: current
                            ? scheme.primaryContainer.withValues(alpha: 0.4)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => player.playAt(i),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: current
                                      ? Icon(
                                          player.isPlaying
                                              ? Icons.volume_up_rounded
                                              : Icons.pause_rounded,
                                          size: 16,
                                          color: scheme.primary)
                                      : Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurfaceVariant,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: settings.fontFamily,
                                          fontFamilyFallback:
                                              kCjkFontFallback,
                                          fontSize: 14,
                                          fontWeight: current
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        [
                                          item.song.album ??
                                              item.song.sourceLabel,
                                          // Which mix, when it is not
                                          // the sung take — an
                                          // instrumental queue should
                                          // say so on every row.
                                          if (item.kind == 'instrumental')
                                            uiStrings[
                                                        'songsTrackInstrumental']
                                                    ?[locale] ??
                                                'Instrumental',
                                          if (item.kind == 'accompaniment')
                                            uiStrings[
                                                        'songsTrackAccompaniment']
                                                    ?[locale] ??
                                                'Accompaniment',
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                // Drop a track you do not want. The
                                // queue model has supported this since
                                // it was built; nothing could call it,
                                // so an unwanted song stayed until the
                                // whole queue was rebuilt.
                                IconButton(
                                  icon: const Icon(
                                      Icons.remove_circle_outline, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  color: scheme.onSurfaceVariant,
                                  tooltip: uiStrings[
                                      'songsRemoveFromQueue']?[locale],
                                  onPressed: () => player.removeFromQueue(i),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  ),
                ),
              ],
            );
          },
        ),
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
          // Only fydt publishes artwork, so a missing image is the
          // common case, not an error — and fydt.org goes down, which
          // is how the song list produced a 60-second SocketException
          // per row. RemoteImage shares the failure memo with the list,
          // so opening Now Playing on a song whose art just failed does
          // not re-probe a host we already know is unreachable.
          child: ColoredBox(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            child: RemoteImage(
              // See songs_page.dart: no CORS header on the artwork
              // hosts, so web needs a real <img> element.
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              url: url,
              // `contain`, not `cover`. fydt's covers are square, but
              // cgdc's artwork is a songbook LOGO and the shapes vary
              // wildly — 2026 SAIL is 1418×341 (4.16:1) while 2025
              // Nearer is 531×543. Cropping a wordmark to a square
              // shows its middle third and reads as nothing at all.
              // On a square image contain and cover are identical, so
              // this costs the square ones nothing.
              fit: BoxFit.contain,
              cacheWidth:
                  (side * MediaQuery.devicePixelRatioOf(context)).round(),
              fallback: (_) => _placeholder(),
            ),
          ),
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

/// The scrubber owns the thumb while a finger is on it.
///
/// It used to seek on every drag frame. Each seek made the engine's
/// position stream emit, the stream rebuilt the Slider from the
/// ENGINE's position rather than from the finger, and the thumb was
/// pulled backwards out from under the drag — "拖动的时候很难不顺".
/// The held value also has to survive the release: [SongPlayerService]
/// updates `position` only from the player's ~200ms position stream, so
/// for a frame or two after the seek the engine still reports where the
/// track WAS, which reads as the drag snapping back.
class _Scrubber extends StatefulWidget {
  final SongPlayerService player;
  final ColorScheme scheme;
  const _Scrubber({required this.player, required this.scheme});

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  /// Milliseconds the thumb is pinned to: where the finger is while a
  /// drag runs, then where it was released until the engine catches up.
  double? _held;
  bool _dragging = false;

  /// Releases the pin even if the engine never reports arriving —
  /// a failed seek must not leave the thumb lying about the position.
  Timer? _giveUp;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_onPlayerTick);
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerTick);
    _giveUp?.cancel();
    super.dispose();
  }

  void _onPlayerTick() {
    if (_dragging || _held == null) return;
    final pos = widget.player.position.inMilliseconds.toDouble();
    if ((pos - _held!).abs() < 1000) _unpin();
  }

  void _unpin() {
    _giveUp?.cancel();
    _giveUp = null;
    if (!mounted) return;
    setState(() => _held = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final total = widget.player.duration;
    final max = total.inMilliseconds.toDouble();
    final shown = Duration(
        milliseconds: (_held ?? widget.player.position.inMilliseconds.toDouble())
            .round());
    final value =
        max <= 0 ? 0.0 : shown.inMilliseconds.toDouble().clamp(0.0, max);
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
                : (v) => setState(() {
                      _dragging = true;
                      _held = v;
                    }),
            onChangeEnd: max <= 0
                ? null
                : (v) {
                    setState(() {
                      _dragging = false;
                      _held = v;
                    });
                    widget.player.seek(Duration(milliseconds: v.round()));
                    _giveUp?.cancel();
                    _giveUp = Timer(const Duration(seconds: 3), _unpin);
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // The elapsed side follows the thumb, not the engine —
              // a number that disagrees with where you are holding the
              // thumb is the same complaint in a different place.
              Text(SongPlayerService.formatDuration(shown),
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

/// Which mix the queue plays: sung take, instrumental, accompaniment.
///
/// Large targets and a single row, because the realistic moment for
/// using it is at a red light. Choosing a non-vocal mix pairs it with
/// [TrackFallback.skip]: the whole point of an accompaniment queue in
/// a car is that it never surprises you with singing — so a song that
/// has no accompaniment drops out rather than reverting to vocals.
class _MixPicker extends StatelessWidget {
  final SongPlayerService player;
  final ColorScheme scheme;
  final String locale;
  const _MixPicker({
    required this.player,
    required this.scheme,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final current = player.trackPreference;
    final options = <(TrackPreference, IconData, String)>[
      (
        TrackPreference.vocal,
        Icons.mic_rounded,
        uiStrings['songsTrackVocal']?[locale] ?? 'Song',
      ),
      (
        TrackPreference.accompaniment,
        Icons.queue_music_rounded,
        uiStrings['songsTrackAccompaniment']?[locale] ?? 'Accompaniment',
      ),
      (
        TrackPreference.instrumental,
        Icons.piano_rounded,
        uiStrings['songsTrackInstrumental']?[locale] ?? 'Instrumental',
      ),
    ];

    final queue = player.queue;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (pref, icon, label) in options)
          ChoiceChip(
            avatar: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: current == pref,
            // Greyed out when no song in the queue publishes that mix,
            // rather than accepting the tap and doing nothing: only two
            // of the four sources record accompaniments at all, so a
            // queue filtered to the other two had a chip that could
            // never work. Reported from the phone as pressing
            // Accompaniment and still hearing singing.
            onSelected: queue.hasMix(pref)
                ? (_) => player.setTrackPreference(
                      pref,
                      fallback: pref == TrackPreference.vocal
                          ? TrackFallback.useVocal
                          : TrackFallback.skip,
                    )
                : null,
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
    final sleepEndOfTrack = player.sleepAtEndOfTrack;
    final sleepArmed = sleepAt != null || sleepEndOfTrack;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          icon: Icon(
            sleepArmed ? Icons.bedtime_rounded : Icons.bedtime_outlined,
            size: 18,
            color: sleepArmed ? scheme.primary : scheme.onSurfaceVariant,
          ),
          label: Text(
            !sleepArmed
                ? (uiStrings['songsSleepTimer']?[locale] ?? 'Sleep timer')
                : sleepEndOfTrack
                    ? (uiStrings['songsSleepEndOfSongShort']?[locale] ??
                        'End of song')
                    : _remaining(sleepAt!),
            style: TextStyle(
              fontSize: 13,
              color: sleepArmed ? scheme.primary : scheme.onSurfaceVariant,
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
      // useSafeArea: without it Flutter wraps the sheet in
      // MediaQuery.removePadding(removeTop: true), so any SafeArea
      // INSIDE the sheet sees padding.top == 0 and does nothing —
      // the header then draws under the clock and the notch.
      useSafeArea: true,
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
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: Text(
                  uiStrings['songsSleepCustom']?[locale] ?? 'Custom…'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickCustomSleep(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note_rounded),
              title: Text(uiStrings['songsSleepEndOfSong']?[locale] ??
                  'End of this song'),
              onTap: () {
                player.setSleepAtEndOfTrack(true);
                Navigator.of(sheetCtx).pop();
              },
            ),
            if (player.sleepAt != null || player.sleepAtEndOfTrack)
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

  /// A plain in-sheet stepper rather than a package picker or
  /// [showTimePicker] — that dialog is a time-of-day, not a duration,
  /// and pulling in a duration-picker package for one bottom sheet is
  /// not worth the bundle cost across six targets.
  void _pickCustomSleep(BuildContext context) {
    var minutes = 90;
    showModalBottomSheet<void>(
      useSafeArea: true,
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: minutes > 5
                          ? () => setState(() => minutes -= 5)
                          : null,
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        '$minutes '
                        '${uiStrings['songsMinutes']?[locale] ?? 'minutes'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: minutes < 240
                          ? () => setState(() => minutes += 5)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    player.setSleepTimer(Duration(minutes: minutes));
                    Navigator.of(sheetCtx).pop();
                  },
                  child: Text(uiStrings['songsSleepSet']?[locale] ?? 'Set'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
