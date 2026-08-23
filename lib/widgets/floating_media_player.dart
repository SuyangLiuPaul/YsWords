import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/media_focus.dart';
import 'package:yswords/utils/embeddable_media.dart';
import 'package:yswords/widgets/media_embed.dart';

/// A draggable window that keeps playing while the app stays usable.
///
/// 2026-08-24, the user, after the first version put the video in a
/// modal sheet: "现在是有youtube在song里面但是就不能退出去了，能不能好像
/// WhatsApp一样窗口可以移动一样可以用app". Two complaints in one
/// sentence and the second answers the first — a modal is a trap by
/// definition, and what was wanted was a window you can push aside.
///
/// THE CONTROLS SIT ABOVE THE FRAME, NEVER OVER IT. On Flutter web an
/// embedded `<iframe>` is a platform view, and platform views can paint
/// on top of Flutter widgets: a close button drawn over the video is
/// present in the tree, invisible on screen, and swallows nothing —
/// which is the most likely reason the sheet's own close button did not
/// get the user out. Keeping every control outside the frame's rect
/// makes that impossible rather than unlikely.
///
/// It lives in the ROOT overlay so navigating does not close it, which
/// is the whole point of a window you can leave up. Root, not the
/// nearest: an entry in a route's overlay dies with that route, and
/// this repo has already met "No Overlay widget found" doing overlay
/// work near route changes.
class FloatingMediaPlayer {
  FloatingMediaPlayer._();

  static OverlayEntry? _entry;
  static final ValueNotifier<Offset> _position =
      ValueNotifier<Offset>(Offset.zero);

  /// The one live window, if any. Exposed so a test can assert the
  /// window opened without reaching into the overlay.
  static bool get isShowing => _entry != null;

  /// Test seam. A widget test runs on the host VM, where the io embed
  /// reports macOS as embeddable and then throws on mount for want of a
  /// registered webview platform. Null in every build; both the
  /// capability check and the player go through it, so a test cannot be
  /// given one without the other.
  @visibleForTesting
  static Widget? Function(String embedUrl)? debugEmbedBuilder;

  static Widget? _embed(String url) =>
      (debugEmbedBuilder ?? mediaEmbed)(url);

  /// Whether [url] can play in this window on this platform.
  ///
  /// Null-or-false has one meaning for every caller: open the link the
  /// way you always did. Either it is not embeddable media, or it is
  /// and this platform has no frame to put it in (Windows and Linux
  /// compile `webview_flutter` with nothing behind it).
  static bool canPlay(String url) {
    final media = embeddableMedia(url);
    if (media == null) return false;
    return _embed(media.embedUrl) != null;
  }

  /// Open [url] in the floating window, replacing whatever was playing.
  static void show(
    BuildContext context,
    String url, {
    required String locale,
    required Future<void> Function() onOpenExternally,
  }) {
    final media = embeddableMedia(url);
    if (media == null) return;
    final embed = _embed(media.embedUrl);
    if (embed == null) return;

    // A video starting silences the hymn. The reverse cannot be
    // honoured — the frame owns its own playback and exposes no pause
    // to us — so this deliberately claims focus without registering as
    // something that can be paused. Same asymmetry the videos page
    // documents, made explicit here too.
    MediaFocus.instance.claim(_focusToken);

    hide();

    final overlay = Overlay.of(context, rootOverlay: true);
    final size = MediaQuery.of(context).size;
    const width = 320.0;
    final height = width / media.aspectRatio + _kBarHeight;
    // Bottom-right, a thumb's width clear of the edges — out of the way
    // of the reading column, and clear of the bottom chrome bar.
    _position.value = Offset(
      (size.width - width - 16).clamp(0.0, double.infinity),
      (size.height - height - 96).clamp(0.0, double.infinity),
    );

    final entry = OverlayEntry(
      builder: (ctx) => _Window(
        position: _position,
        width: width,
        aspectRatio: media.aspectRatio,
        provider: media.provider,
        locale: locale,
        onOpenExternally: onOpenExternally,
        child: embed,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
    // Nothing to release: this window never REGISTERED as pausable —
    // the frame owns its playback and gives us no pause — so there is
    // no holder entry to remove. Claiming without registering is the
    // asymmetry, stated here rather than papered over.
  }

  static final Object _focusToken = Object();
}

const double _kBarHeight = 34;

class _Window extends StatefulWidget {
  const _Window({
    required this.position,
    required this.width,
    required this.aspectRatio,
    required this.provider,
    required this.locale,
    required this.onOpenExternally,
    required this.child,
  });

  final ValueNotifier<Offset> position;
  final double width;
  final double aspectRatio;
  final String provider;
  final String locale;
  final Future<void> Function() onOpenExternally;
  final Widget child;

  @override
  State<_Window> createState() => _WindowState();
}

class _WindowState extends State<_Window> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final height = widget.width / widget.aspectRatio + _kBarHeight;

    return ValueListenableBuilder<Offset>(
      valueListenable: widget.position,
      builder: (context, pos, child) => Positioned(
        left: pos.dx,
        top: pos.dy,
        width: widget.width,
        height: height,
        // `child` is passed through untouched so the frame is NOT
        // rebuilt as the window moves. Rebuilding it would tear the
        // platform view down and back up, restarting playback on every
        // drag — the one thing a movable player must not do.
        child: child!,
      ),
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        color: Colors.black,
        child: Column(
          children: [
            SizedBox(
              height: _kBarHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  final next = widget.position.value + d.delta;
                  // Clamped so the bar can never be dragged off-screen;
                  // losing the bar means losing the close button, and
                  // the frame below it cannot be dragged at all (the
                  // platform view takes those pointers).
                  widget.position.value = Offset(
                    next.dx.clamp(
                        -widget.width + 72, media.size.width - 72),
                    next.dy.clamp(
                        media.padding.top, media.size.height - _kBarHeight),
                  );
                },
                child: Container(
                  color: scheme.surfaceContainerHighest,
                  padding: const EdgeInsets.only(left: 10, right: 2),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.provider == 'soundcloud'
                              ? 'SoundCloud'
                              : 'YouTube',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip:
                            uiStrings['videosWatchOnYouTube']?[widget.locale] ??
                                'Watch on YouTube',
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        onPressed: () async {
                          FloatingMediaPlayer.hide();
                          await widget.onOpenExternally();
                        },
                      ),
                      IconButton(
                        tooltip:
                            uiStrings['close']?[widget.locale] ?? 'Close',
                        icon: const Icon(Icons.close_rounded, size: 16),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        onPressed: FloatingMediaPlayer.hide,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}
