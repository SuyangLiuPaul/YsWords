import 'package:flutter/material.dart';

/// A rounded surface with a colored **left accent stripe**.
///
/// WHY THIS EXISTS — the obvious way to draw "rounded card + left
/// accent" is a single `BoxDecoration` combining a `borderRadius`
/// with a directional `Border(left: BorderSide(...))`. That is a
/// Flutter trap: when such a decoration is painted, `Border.paint`
/// throws
///
///   "A borderRadius can only be given on borders with uniform colors."
///
/// because the four sides aren't uniform (only `left` is visible).
/// In debug/profile it red-screens the frame; in release the assert
/// is stripped so the radius is silently dropped on the border stroke
/// (subtly wrong corners). Either way it's a latent bug — it was the
/// root cause of the reported `InkDecoration.paintFeature` crash on
/// the dashboard daily-verse card (v1.3.47).
///
/// The correct pattern, encapsulated here: draw the stripe as a
/// *child* (a thin `Container`) inside a `ClipRRect`, never as a
/// `Border` side. An optional [outlineColor] adds a **uniform**
/// 4-side outline (uniform border + radius is allowed) painted
/// *behind* the clipped content, so the stripe still reads as the
/// left edge — exactly reproducing the old "left=accent, other three
/// sides=outline" look without the illegal decoration.
class LeftAccentCard extends StatelessWidget {
  const LeftAccentCard({
    super.key,
    required this.child,
    required this.accentColor,
    this.accentWidth = 3,
    this.background,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = EdgeInsets.zero,
    this.outlineColor,
    this.outlineWidth = 1,
  });

  /// The card's content. Receives [padding] inside the stripe.
  final Widget child;

  /// Colour of the left accent stripe.
  final Color accentColor;

  /// Width of the left accent stripe in logical pixels.
  final double accentWidth;

  /// Optional fill behind the content. Null → transparent (lets an
  /// ancestor `Material`/`ColoredBox` show through).
  final Color? background;

  /// Corner rounding. May be asymmetric (e.g. only the right corners).
  final BorderRadius borderRadius;

  /// Padding applied to [child] (the stripe sits outside this).
  final EdgeInsetsGeometry padding;

  /// Optional uniform outline drawn on all four sides. The stripe
  /// paints over its left edge, so visually left=accent, others=outline.
  final Color? outlineColor;

  /// Outline stroke width (only used when [outlineColor] is set).
  final double outlineWidth;

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: background ?? Colors.transparent,
        child: Row(
          // Stretch the stripe to the full intrinsic height of the
          // content beside it.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: accentWidth, color: accentColor),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );

    final outline = outlineColor;
    if (outline != null) {
      content = DecoratedBox(
        // Uniform border + radius is legal — this is the whole point.
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: outline, width: outlineWidth),
        ),
        child: content,
      );
    }
    return content;
  }
}
