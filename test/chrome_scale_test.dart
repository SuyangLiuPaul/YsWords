import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/chrome_scale.dart';

/// The rule itself, beside the screen-level measurement in
/// `header_pill_truncation_test.dart`. That file says the pills fit;
/// this one says why, and pins the two properties a later "simplify
/// this" would quietly drop.
void main() {
  test('the narrowest supported screen affords exactly the default', () {
    // 320px is the iPhone 4 / original SE viewport. It must afford 1.0x
    // and not a hair less: the bottom bar's six buttons fit there at
    // 1.0x today, and capping below it would shrink the interface for
    // every reader on an old phone who never touched the slider.
    expect(chromeScaleFor(320, 1.0), 1.0);
    expect(chromeScaleFor(320, 1.5), 1.0);
  });

  test('a reader under the cap keeps the scale they chose', () {
    // The cap is a ceiling, never a target. 0.7 is the bottom of the
    // slider and someone who wants a denser interface gets it at every
    // width.
    expect(chromeScaleFor(320, 0.7), 0.7);
    expect(chromeScaleFor(1280, 0.7), 0.7);
    expect(chromeScaleFor(1280, 1.2), 1.2);
  });

  test('the whole slider is available once the screen can hold it', () {
    // 480 = 320 * 1.5, so it is the first width that affords the top of
    // the slider, and nothing wider is capped at all.
    expect(chromeScaleFor(480, 1.5), 1.5);
    expect(chromeScaleFor(1280, 1.5), 1.5);
    expect(chromeScaleFor(3840, 1.5), 1.5);
  });

  test('the cap rises with the width, in between', () {
    expect(chromeScaleFor(360, 1.5), closeTo(1.125, 0.001));
    expect(chromeScaleFor(390, 1.5), closeTo(1.21875, 0.001));
    expect(chromeScaleFor(430, 1.5), closeTo(1.34375, 0.001));
  });

  test('it never returns something a widget cannot multiply by', () {
    // A zero or negative width is not a real screen, but a MediaQuery
    // read during a first frame or an offstage measure can hand one
    // over, and a 0x-scaled interface is an invisible one.
    for (final w in <double>[0, -1, 1, 12]) {
      expect(chromeScaleFor(w, 1.5), 1.0, reason: 'width $w');
      expect(chromeScaleFor(w, 1.0), 1.0, reason: 'width $w');
    }
  });
}
