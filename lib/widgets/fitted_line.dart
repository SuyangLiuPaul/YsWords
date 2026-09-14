// A single line that DROPS what it cannot fit instead of ellipsising.
//
// 2026-09-15, from a phone screenshot of the Home hero:
// 「另外这里可以fix吗如果没位置显示就不用… 怎么做好」 — the "读经" card
// read 「出埃及记 18 · 和合本雅伟版(…」 and the ellipsis was doing the
// worst possible job: it spent the last characters of the line on the
// OPENING BRACKET of a qualifier and then cut, so the reader was shown
// a fragment that answers nothing and still looks broken.
//
// The line is not one string, it is a list of facts in order of
// importance — where you are, and which edition you are in. An ellipsis
// treats them as one opaque run of characters and truncates wherever
// the pixels run out, which can land mid-word, mid-bracket or mid-name.
// Dropping a whole fact is the better trade: what remains is always
// complete and always true.
//
// So the caller hands over several complete renderings of the same
// line, most informative first, and this widget measures and shows the
// first one that fits. Nothing is ever cut; the last candidate is the
// one the caller is willing to show on the narrowest phone there is.
import 'package:flutter/material.dart';

class FittedLine extends StatelessWidget {
  /// Complete renderings of the same line, MOST informative first.
  ///
  /// Each entry must stand on its own — this widget picks one and shows
  /// it whole, so a candidate that only makes sense next to another is
  /// a bug in the caller, not something measurement can rescue.
  final List<String> candidates;

  final TextStyle? style;
  final TextAlign textAlign;

  const FittedLine({
    super.key,
    required this.candidates,
    this.style,
    this.textAlign = TextAlign.start,
  }) : assert(candidates.length > 0);

  @override
  Widget build(BuildContext context) {
    final effective = style ?? DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final chosen = maxWidth.isFinite
          ? fittingCandidate(
              candidates,
              maxWidth: maxWidth,
              style: effective,
              scaler: scaler,
              direction: direction,
            )
          : candidates.first;
      return Text(
        chosen,
        maxLines: 1,
        // The last candidate is the caller's floor, and a floor that
        // does not fit is still better shown cut than overflowing into
        // the widget next to it — but by then the choice is already
        // between two bad outcomes, and every candidate above it has
        // been tried.
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: effective,
      );
    });
  }
}

/// The first candidate that fits [maxWidth] on one line, or the last
/// one if none do. Exposed so a test can assert the CHOICE without
/// having to read pixels back off a rendered tree.
String fittingCandidate(
  List<String> candidates, {
  required double maxWidth,
  required TextStyle style,
  required TextScaler scaler,
  TextDirection direction = TextDirection.ltr,
}) {
  final painter = TextPainter(
    maxLines: 1,
    textDirection: direction,
    textScaler: scaler,
  );
  for (final candidate in candidates) {
    painter.text = TextSpan(text: candidate, style: style);
    painter.layout();
    if (painter.width <= maxWidth) {
      painter.dispose();
      return candidate;
    }
  }
  painter.dispose();
  return candidates.last;
}
