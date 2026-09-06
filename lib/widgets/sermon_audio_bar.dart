import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/sermon_audio_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// The player for Pastor Eric's recorded sermons, docked under the
/// transcript.
///
/// It sits at the bottom of the page rather than inline in the body for
/// one reason: these are 35–70 minute talks and people read along while
/// they listen. A control that scrolls away is a control you have to go
/// hunting for every time you want to pause.
///
/// **Tape sides are the whole design constraint.** A sermon was recorded
/// on both sides of a cassette, so it arrives as two files — sometimes
/// three — and side b opens mid-sentence. So the bar auto-advances
/// (handled in [SermonAudioService]), and it *names* the part whenever
/// there is more than one, because otherwise the audio appears to stop
/// halfway through a talk for no visible reason.
///
/// Renders nothing at all when the sermon has no audio, rather than a
/// disabled button. 289 of the 429 sermons have audio as of 2026-09-06
/// (the original corpus; the 140 later merged in from 福音电台 do not),
/// but that is a fact about today's index, not an invariant.
class SermonAudioBar extends StatefulWidget {
  const SermonAudioBar({super.key, required this.sermonId});

  final String sermonId;

  @override
  State<SermonAudioBar> createState() => _SermonAudioBarState();
}

class _SermonAudioBarState extends State<SermonAudioBar> {
  final _svc = SermonAudioService.instance;

  /// While the user drags, the slider must follow the finger and not the
  /// stream — otherwise every position tick yanks the thumb back.
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onServiceChanged);
    _svc.load();
  }

  @override
  void dispose() {
    _svc.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    // The service defers a resume-seek until a duration is known —
    // seeking before that is clamped to zero and the listener silently
    // restarts the talk. Something has to poke it once the duration
    // lands, and this is the only live listener.
    if (_svc.isCurrent(widget.sermonId)) _svc.applyPendingSeek();
    if (mounted) setState(() {});
  }

  String _t(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    if (!_svc.hasAudio(widget.sermonId)) return const SizedBox.shrink();

    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = _svc.isCurrent(widget.sermonId);
    final playing = isCurrent && _svc.isPlaying;
    final loading = isCurrent && _svc.isLoading;

    final duration = isCurrent ? _svc.duration : Duration.zero;
    final position = isCurrent ? _svc.position : Duration.zero;
    final maxMs = duration.inMilliseconds.toDouble();
    final posMs = position.inMilliseconds
        .toDouble()
        .clamp(0.0, maxMs > 0 ? maxMs : 0.0);

    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrent && _svc.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    // 'blocked' means the browser refused to START
                    // playback without a tap still "fresh" — the
                    // recording is fine and one more tap plays it. The
                    // generic message below would send someone
                    // hunting for a broken sermon that does not exist;
                    // see `global_mini_player.dart`'s identical case
                    // for the songs player.
                    _svc.error == 'blocked'
                        ? (uiStrings['songsPlaybackBlocked']?[locale] ??
                            'Tap play again — the browser needs a tap '
                                'before it will start audio.')
                        : _t('sermonAudioError',
                            'This recording will not play right now',
                            locale),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.error,
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    iconSize: 30,
                    icon: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Icon(playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                    color: scheme.primary,
                    tooltip: _t('sermonListen', 'Listen', locale),
                    onPressed:
                        loading ? null : () => _svc.play(widget.sermonId),
                  ),
                  IconButton(
                    iconSize: 20,
                    icon: const Icon(Icons.replay_30_rounded),
                    tooltip: _t('sermonAudioBack30', 'Back 30 seconds', locale),
                    onPressed: isCurrent
                        ? () => _svc.nudge(const Duration(seconds: -30))
                        : null,
                  ),
                  IconButton(
                    iconSize: 20,
                    icon: const Icon(Icons.forward_30_rounded),
                    tooltip:
                        _t('sermonAudioFwd30', 'Forward 30 seconds', locale),
                    onPressed: isCurrent
                        ? () => _svc.nudge(const Duration(seconds: 30))
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                          ),
                          child: Slider(
                            value: _dragValue ?? posMs,
                            max: maxMs > 0 ? maxMs : 1,
                            // A slider over an unknown duration would jump
                            // to the end on the first touch.
                            onChanged: maxMs > 0
                                ? (v) => setState(() => _dragValue = v)
                                : null,
                            onChangeEnd: maxMs > 0
                                ? (v) {
                                    _svc.seek(
                                        Duration(milliseconds: v.round()));
                                    setState(() => _dragValue = null);
                                  }
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Row(
                            children: [
                              Text(
                                '${SermonAudioService.formatDuration(position)}'
                                ' / '
                                '${SermonAudioService.formatDuration(duration)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              if (isCurrent && _svc.hasMultipleParts) ...[
                                const SizedBox(width: 10),
                                Text(
                                  _t('sermonAudioPart', 'Part %1 of %2',
                                          locale)
                                      .replaceFirst('%1', '${_svc.partNumber}')
                                      .replaceFirst('%2', '${_svc.partCount}'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                    fontFamily: settings.fontFamily,
                                    fontFamilyFallback: kCjkFontFallback,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
