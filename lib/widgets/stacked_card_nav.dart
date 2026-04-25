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

  /// Tooltip / aria-label for the floating "+" button.
  final String addLayerTooltip;

  /// Label used for the root reader in the stack switcher.
  final String baseLayerLabel;

  /// When non-null, the scaffold renders a small floating "+" button at
  /// the bottom-left corner. Tapping it invokes [onAddLayer]; the
  /// callback is responsible for showing whatever picker UI is needed
  /// and then calling [push] with a builder for the new card. Leave
  /// `null` to hide the button entirely (e.g. while the splash screen
  /// is still on screen).
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

  bool get hasOverlays => _layers.isNotEmpty;
  int get overlayCount => _layers.length;

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
                if (_layers.isNotEmpty)
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
                for (int i = 0; i < _layers.length; i++)
                  _buildLayer(
                    context: context,
                    layer: _layers[i],
                    index: i,
                    isTop: i == _layers.length - 1,
                    stripWidth: stripW,
                    screenWidth: constraints.maxWidth,
                    screenHeight: constraints.maxHeight,
                  ),

                // Floating "+" launcher: shown only when the host wires
                // up [onAddLayer] (typically once the splash screen has
                // finished and the home reader is ready).
                if (widget.onAddLayer != null && _layers.isEmpty)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 12),
                        child: _AddLayerFab(
                          tooltip: widget.addLayerTooltip,
                          onTap: widget.onAddLayer!,
                        ),
                      ),
                    ),
                  ),
                if (widget.onAddLayer != null && _layers.isNotEmpty)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 12),
                        child: _StackControlPill(
                          count: _layers.length + 1,
                          addTooltip: widget.addLayerTooltip,
                          switchTooltip: uiStrings['switchPage']?[
                                  context.watch<AppSettings>().locale] ??
                              'Switch page',
                          closeTooltip: uiStrings['closePage']?[
                                  context.watch<AppSettings>().locale] ??
                              'Close page',
                          onAdd: widget.onAddLayer!,
                          onSwitch: () => _showLayerSwitcher(context),
                          onClose: pop,
                        ),
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

  Widget _buildLayer({
    required BuildContext context,
    required _Layer layer,
    required int index,
    required bool isTop,
    required double stripWidth,
    required double screenWidth,
    required double screenHeight,
  }) {
    // Layer at index `i` is offset by (i+1) strip widths from the left:
    //   base strip exposed at 0..stripWidth
    //   layer 0 strip exposed at stripWidth..2*stripWidth
    //   etc.
    final targetLeft = (index + 1) * stripWidth;

    return AnimatedBuilder(
      key: ValueKey(layer.id),
      animation: layer.controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(layer.controller.value);
        // Slide from off-screen right to its target left.
        final left = (screenWidth) * (1 - t) + targetLeft * t;
        return Positioned(
          left: left,
          top: 0,
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
        // Adjust MediaQuery so the page inside thinks its width is the
        // visible portion (full width minus its left offset). Otherwise a
        // Scaffold inside would compute layout for the whole screen.
        adjustedWidth: screenWidth - targetLeft,
        screenHeight: screenHeight,
        child: Builder(builder: layer.builder),
      ),
    );
  }
}

/// The "+" button rendered at the bottom-left corner of the scaffold
/// once the host wires up an [StackedCardScaffold.onAddLayer] callback.
class _AddLayerFab extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  const _AddLayerFab({required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.add_rounded, color: scheme.onPrimary, size: 26),
          ),
        ),
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final bool isTop;
  final double stripWidth;
  final VoidCallback? onPromoteTap;
  final double adjustedWidth;
  final double screenHeight;
  final Widget child;

  const _LayerCard({
    required this.isTop,
    required this.stripWidth,
    required this.onPromoteTap,
    required this.adjustedWidth,
    required this.screenHeight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);

    // Re-scope MediaQuery so descendants see the layer's actual bounds.
    final adjustedMedia = media.copyWith(
      size: Size(adjustedWidth, screenHeight),
      padding: media.padding.copyWith(left: 0),
      viewPadding: media.viewPadding.copyWith(left: 0),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(22),
        bottomLeft: Radius.circular(22),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.22),
              blurRadius: 28,
              offset: const Offset(-8, 0),
            ),
          ],
          border: Border(
            left: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
        ),
        child: Stack(
          children: [
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
            if (!isTop)
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

class _StackControlPill extends StatelessWidget {
  final int count;
  final String addTooltip;
  final String switchTooltip;
  final String closeTooltip;
  final VoidCallback onAdd;
  final VoidCallback onSwitch;
  final VoidCallback onClose;

  const _StackControlPill({
    required this.count,
    required this.addTooltip,
    required this.switchTooltip,
    required this.closeTooltip,
    required this.onAdd,
    required this.onSwitch,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.96),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: addTooltip,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            Tooltip(
              message: switchTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onSwitch,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_rounded, size: 20),
                      const SizedBox(width: 5),
                      Text(
                        '$count',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Tooltip(
              message: closeTooltip,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
