import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Multi-color Google "G" logo, drawn with primitives so we don't
/// need to bundle a PNG / SVG asset or add the `google_sign_in_web`
/// package just for its button. Looks identical to the canonical
/// Google brand mark at sizes >= 16 dp.
///
/// Construction:
///   • Four ~90° colored arcs form the C-shape outer ring (red top,
///     yellow left, green bottom, blue right).
///   • A small horizontal white bar simulates the inner "G" stroke
///     (the bar that distinguishes G from C).
///   • Right-side mouth gap is the natural break between blue (top)
///     and green (bottom) arcs — no clipping needed.
class GoogleGLogo extends StatelessWidget {
  /// Logical size in dp; the painter scales internally.
  final double size;
  const GoogleGLogo({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: const _GoogleGPainter(),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  // Google brand colors (https://about.google/brand-resource-center/)
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.20;
    final r = (s - stroke) / 2;
    final c = Offset(s / 2, s / 2);
    final rect = Rect.fromCircle(center: c, radius: r);

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Sweep is in radians, CW from the 3-o'clock position.
    // The mouth opens at the right side, with blue (top) and green
    // (bottom) ending just shy of 0° to leave a small visual gap.
    const startTopBlue = -math.pi / 2 - math.pi / 9; // ~-110°
    const sweepTopBlue = math.pi / 2 + math.pi / 9; // ~110°
    p.color = _blue;
    canvas.drawArc(rect, startTopBlue, sweepTopBlue, false, p);

    // Red — top-left quadrant.
    p.color = _red;
    canvas.drawArc(
        rect, math.pi + math.pi / 2.2, math.pi / 2.2, false, p);

    // Yellow — bottom-left quadrant.
    p.color = _yellow;
    canvas.drawArc(rect, math.pi - math.pi / 2.5,
        math.pi / 2.5, false, p);

    // Green — bottom-right quadrant, ending before the mouth gap.
    p.color = _green;
    canvas.drawArc(rect, math.pi / 2.5, math.pi / 2.5 - math.pi / 12,
        false, p);

    // Inner horizontal bar — the "G" arm. Starts at the right edge
    // (just outside the ring's mouth gap), extends left to the
    // vertical center, painted in blue to match the upper arc.
    final barHeight = stroke * 0.92;
    final barLeft = c.dx;
    final barRight = c.dx + r + stroke * 0.45;
    final barRect = Rect.fromLTRB(
      barLeft,
      c.dy - barHeight / 2,
      barRight,
      c.dy + barHeight / 2,
    );
    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _blue
      ..isAntiAlias = true;
    canvas.drawRect(barRect, barPaint);

    // Cap the inner end of the bar with a square of the same color
    // (avoids a sub-pixel seam against the ring on web).
    canvas.drawCircle(
        Offset(barLeft, c.dy), barHeight / 2 - 0.5, barPaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleGPainter oldDelegate) => false;
}
