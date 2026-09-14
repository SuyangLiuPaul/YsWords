/// The Menu Size slider, capped by the width there is to spend it on.
///
/// 2026-09-14. `setMenuScale` lets the reader take the interface to
/// 1.5x, and the chrome either side of the reading surface is built out
/// of fixed-size pieces: six icon buttons across the bottom bar, two
/// pills and two icon clusters across the top. At 1.5x those pieces
/// want more room than a 320px screen has, and neither bar answers by
/// shrinking:
///
///   • the bottom bar's `Row` overflowed by 64px — the striped band a
///     reader sees as the app being broken;
///   • the header's pills ellipsised instead, which is worse, because
///     nothing marks it: 「和合本雅伟版」 becomes 「雅…」 and the reader is
///     simply told the wrong thing about what they are reading.
///
/// That second one has now been reported four times (v1.3.160,
/// v1.3.161, 2026-09-08, and again here), and every previous fix went
/// at the labels — a shorter name, then a shorter name on every screen,
/// then a different way of dividing the row. All three were measured
/// with the slider at 1.0x, so all three left this multiplier out of
/// the account and the report came back from the next reader who had
/// moved it.
///
/// The rule: 1.0x is what the narrowest screen the app supports (320px,
/// the iPhone 4/SE viewport) can afford, and every further 320px of
/// width buys another 1.0x, up to the 1.5x the slider itself stops at.
/// A reader below that cap keeps exactly the scale they chose.
///
/// What is capped is CHROME. `settings.fontSize` — the scripture — is
/// untouched, and that is the thing a reader who reached for the Menu
/// Size slider was mostly after anyway.
double chromeScaleFor(double screenWidth, double menuScale) =>
    menuScale.clamp(0.7, (screenWidth / 320).clamp(1.0, 1.5)).toDouble();
