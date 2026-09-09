import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A horizontal scroller that says when there is more.
///
/// The selection action bar grew to eight icons. On a phone that is
/// wider than the screen, and a bare `SingleChildScrollView` gives no
/// sign of it: the row ends at the screen edge looking complete, and
/// the reader has no reason to swipe. The owner's own words, 2026-09-09:
/// 「下面几乎满了 不往右划根本不知道」.
///
/// So the edge that has more content behind it gets a short fade into
/// the bar's own colour and a chevron. The chevron is a real button —
/// tapping it scrolls most of a viewport — because a hint you can act
/// on beats a hint you have to interpret. When everything fits, nothing
/// is drawn; when the reader has scrolled to the end, the right hint
/// goes away and the left one appears.
///
/// Two things the first version got wrong, both caught in review the
/// same day:
///
///   * The whole band was an opaque tap target stacked over the scroll
///     view, so a swipe that STARTED on the band — on the cut-off icon,
///     the natural place to grab — neither scrolled nor tapped: the
///     Stack hands the pointer to the topmost hit child and never
///     consults the scrollable beneath. Now the fade is pointer-
///     transparent, only the narrow chevron column takes pointers, and
///     a drag that begins there is forwarded to the scroll position
///     through [ScrollPosition.drag], so it scrolls exactly as a drag
///     anywhere else would.
///   * It appeared for any overflow over one pixel, so four hidden
///     pixels earned a 28-px overlay across the very icon it was
///     hinting at. [kOverflowHintThreshold] now asks for enough hidden
///     width to be worth pointing at.
///
/// [fadeColor] must be the colour of the surface the scroller sits on,
/// or the fade reads as a smudge rather than as the bar continuing.
class OverflowHintScroll extends StatefulWidget {
  const OverflowHintScroll({
    super.key,
    required this.child,
    required this.fadeColor,
    this.minWidth,
    this.hintWidth = 32,
    this.chevronWidth = 24,
    this.moreLabel,
    this.backLabel,
  });

  final Widget child;
  final Color fadeColor;

  /// When set, the child is laid out at least this wide — the caller
  /// centres a `spaceEvenly` row inside the viewport when it fits.
  final double? minWidth;

  /// Width of the fade band. Only [chevronWidth] of it takes pointers.
  final double hintWidth;

  /// Width of the tappable/draggable chevron column at the very edge.
  final double chevronWidth;

  /// Accessibility label for the chevron that scrolls FORWARD.
  final String? moreLabel;

  /// Accessibility label for the chevron that scrolls BACK.
  ///
  /// Separate from [moreLabel] because the two chevrons do opposite
  /// things and a screen reader announces only this string: with one
  /// label for both, a reader hears "More" on the control that takes
  /// them backwards. Sighted readers get the direction from the glyph;
  /// this is the same information, for the people who cannot see it.
  final String? backLabel;

  @override
  State<OverflowHintScroll> createState() => _OverflowHintScrollState();
}

/// Hidden extent below which no hint is drawn: a few pixels of overflow
/// leave the last icon effectively whole, and a hint there would cover
/// more than it reveals.
const double kOverflowHintThreshold = 12;

class _OverflowHintScrollState extends State<OverflowHintScroll> {
  final ScrollController _controller = ScrollController();
  bool _canLeft = false;
  bool _canRight = false;
  Drag? _drag;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recheck);
    // Metrics are unknown until the first layout; ScrollMetricsNotification
    // covers later resizes, this covers the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recheck());
  }

  @override
  void dispose() {
    _drag?.cancel();
    _controller.removeListener(_recheck);
    _controller.dispose();
    super.dispose();
  }

  void _recheck() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    if (!p.hasContentDimensions) return;
    final left = p.pixels > kOverflowHintThreshold;
    final right = p.maxScrollExtent - p.pixels > kOverflowHintThreshold;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _nudge(double sign) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final target = (p.pixels + sign * p.viewportDimension * 0.8)
        .clamp(0.0, p.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  // A drag that begins on the chevron is handed to the scroll position,
  // which is what Scrollable itself does with a drag that begins on the
  // content. The chevron therefore scrolls on swipe AND on tap.
  void _dragStart(DragStartDetails d) {
    if (!_controller.hasClients) return;
    _drag?.cancel();
    _drag = _controller.position.drag(d, () => _drag = null);
  }

  void _dragUpdate(DragUpdateDetails d) => _drag?.update(d);

  void _dragEnd(DragEndDetails d) {
    _drag?.end(d);
    _drag = null;
  }

  void _dragCancel() {
    _drag?.cancel();
    _drag = null;
  }

  @override
  Widget build(BuildContext context) {
    final inner = widget.minWidth == null
        ? widget.child
        : ConstrainedBox(
            constraints: BoxConstraints(minWidth: widget.minWidth!),
            child: widget.child,
          );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _recheck();
        return false;
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: inner,
          ),
          if (_canLeft)
            _EdgeHint(
              alignLeft: true,
              width: widget.hintWidth,
              chevronWidth: widget.chevronWidth,
              color: widget.fadeColor,
              label: widget.backLabel ?? widget.moreLabel,
              onTap: () => _nudge(-1),
              onDragStart: _dragStart,
              onDragUpdate: _dragUpdate,
              onDragEnd: _dragEnd,
              onDragCancel: _dragCancel,
            ),
          if (_canRight)
            _EdgeHint(
              alignLeft: false,
              width: widget.hintWidth,
              chevronWidth: widget.chevronWidth,
              color: widget.fadeColor,
              label: widget.moreLabel,
              onTap: () => _nudge(1),
              onDragStart: _dragStart,
              onDragUpdate: _dragUpdate,
              onDragEnd: _dragEnd,
              onDragCancel: _dragCancel,
            ),
        ],
      ),
    );
  }
}

class _EdgeHint extends StatelessWidget {
  const _EdgeHint({
    required this.alignLeft,
    required this.width,
    required this.chevronWidth,
    required this.color,
    required this.label,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final bool alignLeft;
  final double width;
  final double chevronWidth;
  final Color color;
  final String? label;
  final VoidCallback onTap;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final edge = alignLeft ? Alignment.centerLeft : Alignment.centerRight;
    return Positioned(
      top: 0,
      bottom: 0,
      left: alignLeft ? 0 : null,
      right: alignLeft ? null : 0,
      width: width,
      child: Stack(
        children: [
          // The fade is purely visual: pointers pass through it to the
          // icon underneath and to the scroll view.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: alignLeft
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    end: edge,
                    colors: [color.withValues(alpha: 0), color],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: edge,
            child: SizedBox(
              width: chevronWidth,
              height: double.infinity,
              child: Semantics(
                button: true,
                label: label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onHorizontalDragStart: onDragStart,
                  onHorizontalDragUpdate: onDragUpdate,
                  onHorizontalDragEnd: onDragEnd,
                  onHorizontalDragCancel: onDragCancel,
                  child: Icon(
                    alignLeft
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 22,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
