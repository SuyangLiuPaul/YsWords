import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';

/// A Stage-Manager-style stacked card navigation host.
///
/// Wrap the root of your app in [StackedCardScaffold]. From any descendant,
/// call `StackedCardScaffold.of(context).push(...)` to slide a new page in
/// from the right as a layer that overlaps — but does not fully replace —
/// the page beneath it. Each layer leaves a slim strip of the page below
/// visible on the left edge; tapping that strip promotes the underlying
/// layer back to the front.
///
/// Layer count is responsive:
///  - Phone (<600 dp): up to 3 cards (base + 2 overlays)
///  - Small tablet (<900 dp): 4 cards
///  - Large tablet (<1300 dp): 5 cards
///  - Desktop (≥1300 dp): 6 cards
/// Pushing past the maximum evicts the bottom-most overlay.
class StackedCardScaffold extends StatefulWidget {
  final Widget child;

  /// Tooltip / aria-label for adding another chapter.
  final String addLayerTooltip;

  /// Label used for the root reader in the stack switcher.
  final String baseLayerLabel;

  /// When non-null, descendants can call [StackedCardScaffoldState.requestAddLayer]
  /// to show the app's add-chapter picker, then push a new reader layer.
  final VoidCallback? onAddLayer;

  const StackedCardScaffold({
    super.key,
    required this.child,
    this.onAddLayer,
    this.addLayerTooltip = 'Open another chapter',
    this.baseLayerLabel = 'Reader',
  });

  static StackedCardScaffoldState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<StackedCardScaffoldState>();

  static StackedCardScaffoldState of(BuildContext context) {
    final state = maybeOf(context);
    assert(state != null, 'No StackedCardScaffold ancestor found in context');
    return state!;
  }

  @override
  State<StackedCardScaffold> createState() => StackedCardScaffoldState();
}

class _Layer<T> {
  final WidgetBuilder builder;
  final AnimationController controller;
  final Completer<T?> completer;
  final Object id;
  final String label;
  final IconData icon;
  _Layer(
    this.builder,
    this.controller,
    this.completer,
    this.id,
    this.label,
    this.icon,
  );
}

class StackedCardScaffoldState extends State<StackedCardScaffold>
    with TickerProviderStateMixin {
  final List<_Layer> _layers = [];

  /// Total cards we allow on screen for [width] (base + overlays).
  int _maxTotalCards(double width) {
    if (width < 600) return 3;
    if (width < 900) return 4;
    if (width < 1300) return 5;
    return 6;
  }

  /// Width of the visible strip of the layer below.
  double _stripWidth(double width) {
    if (width < 600) return 18.0;
    if (width < 900) return 26.0;
    return 34.0;
  }

  /// Vertical offset for overlay layers on phones so the layer below
  /// peeks through at the top, giving users a visual toggle hint.
  double _phoneLayerTopOffset(int index, double width) {
    if (width >= 600) return 0.0;
    return 44.0 + (index * 8.0);
  }

  bool get hasOverlays => _layers.isNotEmpty;
  int get overlayCount => _layers.length;
  bool get canAddLayer {
    if (widget.onAddLayer == null) return false;
    final w = MediaQuery.of(context).size.width;
    return _layers.length < _maxTotalCards(w) - 1;
  }

  void requestAddLayer() {
    widget.onAddLayer?.call();
  }

  void showLayerSwitcher() {
    _showLayerSwitcher(context);
  }

  Future<T?> push<T>(
    WidgetBuilder builder, {
    String? label,
    IconData icon = Icons.layers_rounded,
  }) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
    final completer = Completer<T?>();
    final layer = _Layer<T>(
      builder,
      controller,
      completer,
      Object(),
      label ?? 'Page ${_layers.length + 1}',
      icon,
    );

    // Enforce max-layer cap by evicting oldest overlays.
    final maxTotal = _maxTotalCards(MediaQuery.of(context).size.width);
    final maxOverlays = maxTotal - 1; // base counts as one card
    while (_layers.length >= maxOverlays) {
      final old = _layers.removeAt(0);
      old.controller.dispose();
      if (!old.completer.isCompleted) old.completer.complete(null);
    }

    setState(() => _layers.add(layer));
    controller.forward();
    return completer.future;
  }

  /// Pop the top-most overlay. Returns true if a layer was popped.
  bool pop<T>([T? result]) {
    if (_layers.isEmpty) return false;
    final top = _layers.last;
    top.controller.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() => _layers.remove(top));
      top.controller.dispose();
      if (!top.completer.isCompleted) {
        top.completer.complete(result);
      }
    });
    return true;
  }

  /// Close any overlay by index. The top layer uses [pop] so it keeps
  /// the normal reverse animation/result behavior.
  bool closeAt(int index) {
    if (index < 0 || index >= _layers.length) return false;
    if (index == _layers.length - 1) return pop();

    final layer = _layers[index];
    layer.controller.reverse().whenComplete(() {
      if (!mounted) return;
      if (_layers.contains(layer)) {
        setState(() => _layers.remove(layer));
        layer.controller.dispose();
        if (!layer.completer.isCompleted) layer.completer.complete(null);
      }
    });
    return true;
  }

  /// Bring the layer at [index] to the top of the stack.
  void promote(int index) {
    if (index < 0 || index >= _layers.length) return;
    if (index == _layers.length - 1) return;
    setState(() {
      final l = _layers.removeAt(index);
      _layers.add(l);
    });
  }

  /// Pop every overlay in sequence (used when the base strip is tapped).
  void popAll() {
    final snapshot = List<_Layer>.from(_layers);
    for (final layer in snapshot) {
      layer.controller.reverse().whenComplete(() {
        if (!mounted) return;
        if (_layers.contains(layer)) {
          setState(() => _layers.remove(layer));
          layer.controller.dispose();
          if (!layer.completer.isCompleted) layer.completer.complete(null);
        }
      });
    }
  }

  void _showLayerSwitcher(BuildContext context) {
    final settings = context.read<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final title = uiStrings['openPages']?[locale] ?? 'Open pages';
    final reader = uiStrings['reader']?[locale] ?? widget.baseLayerLabel;
    final current = uiStrings['currentPage']?[locale] ?? 'Current';
    final closeLabel = uiStrings['closePage']?[locale] ?? 'Close page';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: uiStrings['close']?[locale] ?? 'Close',
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                ListTile(
                  leading: Icon(Icons.menu_book_rounded, color: scheme.primary),
                  title: Text(reader),
                  subtitle: _layers.isEmpty ? Text(current) : null,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    popAll();
                  },
                ),
                for (var i = 0; i < _layers.length; i++)
                  ListTile(
                    leading: Icon(_layers[i].icon, color: scheme.primary),
                    title: Text(
                      _layers[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle:
                        i == _layers.length - 1 ? Text(current) : null,
                    trailing: IconButton(
                      tooltip: closeLabel,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        closeAt(i);
                      },
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      promote(i);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    for (final l in _layers) {
      l.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final stripW = _stripWidth(w);
    final mobileFullScreen = w < 600;

    return PopScope(
      canPop: _layers.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _layers.isNotEmpty) pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: Theme.of(context).colorScheme.surface,
          systemNavigationBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Base layer (the wrapped child).
                Positioned.fill(child: widget.child),

                // A tap-zone over the base's exposed strip pops all overlays.
                // On phones overlays are full-screen, so switching is handled
                // by explicit app-bar controls instead of tiny edge strips.
                if (_layers.isNotEmpty && !mobileFullScreen)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: stripW,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: popAll,
                    ),
                  ),

                // Overlay layers, in z-order (lowest first → topmost last).
                // On phones, interleave tap zones for exposed top strips.
                for (int i = 0; i < _layers.length; i++) ...[
                  // Phone: tap zone for the exposed top strip of this layer.
                  if (mobileFullScreen && i < _layers.length - 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _phoneLayerTopOffset(i, constraints.maxWidth),
                      height: _phoneLayerTopOffset(i + 1, constraints.maxWidth) -
                          _phoneLayerTopOffset(i, constraints.maxWidth),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => promote(i),
                      ),
                    ),
                  _buildLayer(
                    context: context,
                    layer: _layers[i],
                    index: i,
                    isTop: i == _layers.length - 1,
                    stripWidth: stripW,
                    mobileFullScreen: mobileFullScreen,
                    screenWidth: constraints.maxWidth,
                    screenHeight: constraints.maxHeight,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLayer({
    required BuildContext context,
    required _Layer layer,
    required int index,
    required bool isTop,
    required double stripWidth,
    required bool mobileFullScreen,
    required double screenWidth,
    required double screenHeight,
  }) {
    // Layer at index `i` is offset by (i+1) strip widths from the left:
    //   base strip exposed at 0..stripWidth
    //   layer 0 strip exposed at stripWidth..2*stripWidth
    //   etc.
    final targetLeft = mobileFullScreen ? 0.0 : (index + 1) * stripWidth;
    final targetTop = _phoneLayerTopOffset(index, screenWidth);

    return AnimatedBuilder(
      key: ValueKey(layer.id),
      animation: layer.controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(layer.controller.value);
        final left = (screenWidth) * (1 - t) + targetLeft * t;
        return Positioned(
          left: left,
          top: targetTop,
          bottom: 0,
          right: 0,
          child: Opacity(
            opacity: (0.4 + 0.6 * t).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: _LayerCard(
        isTop: isTop,
        stripWidth: stripWidth,
        onPromoteTap: isTop ? null : () => promote(index),
        fullScreen: mobileFullScreen,
        adjustedWidth: screenWidth - targetLeft,
        screenHeight: screenHeight - targetTop,
        layerIndex: index,
        child: Builder(builder: layer.builder),
      ),
    );
  }
}

const _layerAccentColors = <Color>[
  Color(0xFF5B9FED), // blue
  Color(0xFF6BCB77), // green
  Color(0xFFFF6B6B), // coral
  Color(0xFFFFD93D), // amber
  Color(0xFFC084FC), // violet
  Color(0xFF38BDF8), // sky
];

class _LayerCard extends StatelessWidget {
  final bool isTop;
  final double stripWidth;
  final VoidCallback? onPromoteTap;
  final double adjustedWidth;
  final double screenHeight;
  final bool fullScreen;
  final int layerIndex;
  final Widget child;

  const _LayerCard({
    required this.isTop,
    required this.stripWidth,
    required this.onPromoteTap,
    required this.adjustedWidth,
    required this.screenHeight,
    required this.fullScreen,
    required this.layerIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final accentColor = _layerAccentColors[layerIndex % _layerAccentColors.length];
    final tintedSurface = Color.lerp(scheme.surface, accentColor, 0.04)!;

    final adjustedMedia = media.copyWith(
      size: Size(adjustedWidth, screenHeight),
      padding: media.padding.copyWith(left: 0),
      viewPadding: media.viewPadding.copyWith(left: 0),
    );

    return ClipRRect(
      borderRadius: fullScreen
          ? const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            )
          : const BorderRadius.only(
              topLeft: Radius.circular(22),
              bottomLeft: Radius.circular(22),
            ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tintedSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.22),
              blurRadius: 28,
              offset: const Offset(-8, 0),
            ),
          ],
          border: Border(
            left: fullScreen
                ? BorderSide.none
                : BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
          ),
        ),
        child: Stack(
          children: [
            // Accent bar at top.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 3.0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: accentColor),
              ),
            ),
            Positioned.fill(
              child: MediaQuery(
                data: adjustedMedia,
                child: Material(
                  type: MaterialType.transparency,
                  child: child,
                ),
              ),
            ),
            // Subtle dim + tap-catcher on the strip when this layer isn't top.
            if (!isTop && !fullScreen)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: stripWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPromoteTap,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.06),
                    ),
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 42,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
