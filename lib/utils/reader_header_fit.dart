/// WHETHER THE READER HEADER'S TWO PILLS BOTH FIT, measured.
///
/// The header centres a book pill (「撒母耳記上 16」) and a version pill
/// (「雅偉版 ⌄」) between the leading and trailing icon clusters. When
/// they do not both fit, ONE of them has to give, and it matters which:
/// the book name has a short form the reader still recognises (撒上 16);
/// the version label does not. An elided version pill says 「雅…」, which
/// names nothing.
///
/// This decision has been made four times by SCREEN WIDTH — 450, then
/// 390, then 390 x the menu scale — and reported again after each one,
/// most recently from an iPhone 12 reading 撒母耳記上 in Traditional
/// Chinese. A screen-width threshold cannot be right: the pills are not
/// given the screen. They are given whatever the icon clusters either
/// side of them leave, which moves with the locale, the menu scale, the
/// reader's font size, split view, and which trailing actions the
/// chapter happens to have.
///
/// So ask the row. [available] is the width the pair was actually given.
library;

import 'package:flutter/widgets.dart';

/// The width one line of [text] takes in [style], in logical pixels.
///
/// [scaler] is the caller's own `MediaQuery.textScalerOf`: a reader with
/// the system type size turned up draws these labels wider than a plain
/// `TextPainter` would, and a measurement that misses that is a
/// measurement of somebody else's phone.
double headerLabelWidth(String text, TextStyle style,
    {TextScaler scaler = TextScaler.noScaling}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textScaler: scaler,
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// Whether the book pill must fold to its short form for the version
/// pill to be readable.
///
/// [chrome] is everything in the row that is not those two strings: both
/// pills' horizontal padding, the gap between them, and the version
/// chip's chevron.
bool readerHeaderFoldsBookName({
  required double available,
  required double fullBookWidth,
  required double versionWidth,
  required double chrome,
}) {
  if (!available.isFinite || available <= 0) return false;
  return fullBookWidth + versionWidth + chrome > available;
}
