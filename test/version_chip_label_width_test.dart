import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// The version pill in the reading-pane header, measured rather than
/// counted.
///
/// The pill has been fixed for truncation twice. v1.3.160 gave the
/// Chinese editions a `narrowLabel` because 和合本雅伟版 was being cut to
/// 和合本雅…; v1.3.161 then stopped gating it on screen width at all,
/// on the finding recorded in `bible_reading_pane.dart` that "no screen-
/// width threshold is ever really wide enough" — the chip shares its row
/// with the book-title pill and the trailing icon cluster, so it only
/// ever gets a slice. `narrowBibleVersionLabel` is therefore what the
/// chip shows on EVERY screen, and its width is the whole contract.
///
/// `bible_versions_language_test.dart` guards the Chinese labels with a
/// three-rune cap, which is a fine proxy for CJK — three Han characters
/// are about three ems — and a useless one for anything else. 'BSB-Y' is
/// five runes and narrower than '梁繁', which is two. So the Latin
/// labels are measured, at the pill's real `TextStyle`, against the
/// widest label the pill is known to hold: 雅伟版.
///
/// Why a comparison and not an absolute pixel budget: the budget is not
/// knowable from this file. It depends on the book name beside it, the
/// icon cluster, the reader's `menuScale`, and the screen. What IS
/// knowable is that 雅伟版 fits — two rounds of user feedback settled
/// that — so "no wider than 雅伟版" is a claim this test can actually
/// stand behind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Without the real font every glyph gets an identical advance in
    // `flutter_test`, and a width comparison between Han characters and
    // Latin ones becomes a character count wearing a disguise — which
    // is precisely the measurement this file exists to replace.
    await (FontLoader('NotoSansSC-YsWords')
          ..addFont(rootBundle.load('assets/fonts/NotoSansSC-YsWords.otf')))
        .load();
  });

  /// The chip's own style, from `bible_reading_pane.dart`: the reader's
  /// font size scaled by 0.78, semi-bold, CJK fallback attached.
  double widthOf(String label, double readerFontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'NotoSansSC-YsWords',
          fontFamilyFallback: kCjkFontFallback,
          fontSize: readerFontSize * 0.78,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  // 12 and 40 are the ends of the reader's font-size slider
  // (`settings_page.dart`); 20 is the default. The chip scales with it,
  // so a label that fits at 20 and not at 40 is a label that truncates
  // for every reader who has ever enlarged the text.
  const readerSizes = [12.0, 20.0, 40.0];

  test('no version narrows to a label wider than 雅伟版, the widest the '
      'pill was fixed to hold', () {
    for (final size in readerSizes) {
      final budget = widthOf('雅伟版', size);
      for (final v in availableVersions) {
        final label = narrowBibleVersionLabel(v.value);
        expect(widthOf(label, size), lessThanOrEqualTo(budget),
            reason: '${v.value} narrows to "$label", which is wider than '
                '雅伟版 at reader size $size — the pill will ellipsise it');
      }
    }
  });

  test('the four texts imported in 2026-09-08 are the ones this was '
      'written for, and each is narrower than what it replaces', () {
    // Named rather than derived: the point of this test was the four
    // new editions, and a loop over `availableVersions` would keep
    // passing if they silently left the catalogue.
    const added = {
      'bsb-yhwh': 'BSB-Y',
      'asv-yhwh': 'ASV-Y',
      'wh': 'WH',
    };
    added.forEach((code, expected) {
      expect(narrowBibleVersionLabel(code), expected);
    });
    // The full labels are what would have shipped without a
    // `narrowLabel`, and they are the reason these two have one.
    for (final size in readerSizes) {
      expect(widthOf('BSB (Yahweh)', size),
          greaterThan(widthOf('雅伟版', size)),
          reason: 'if the full label now fits, the narrowLabel on '
              'bsb-yhwh is no longer earning its place');
      expect(widthOf('BSB-Y', size), lessThan(widthOf('BSB (Yahweh)', size)));
    }
  });

  test('every edition offers the pill something to draw', () {
    for (final v in availableVersions) {
      expect(narrowBibleVersionLabel(v.value).trim(), isNotEmpty,
          reason: v.value);
    }
  });
}
