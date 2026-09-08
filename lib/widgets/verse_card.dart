// The shareable verse card — the thing that gets rasterised to a PNG.
//
// Deliberately a plain, pure widget with no provider lookups and no
// `Theme.of(context)`: everything it paints comes in through the
// constructor. That is not fastidiousness, it is what makes the export
// possible at all. `RenderRepaintBoundary.toImage` rasterises whatever
// the boundary last painted, so the card has to be able to paint
// CORRECTLY somewhere other than the reader's own screen — in a
// light-mode preview while the app is dark, at a fixed 360 dp width
// while the phone is 412 dp wide, and inside a headless test with no
// MediaQuery worth speaking of. A widget that reads its colours from
// the ambient theme cannot do any of those.
//
// What was rejected: YouVersion's editor. It offers blur, brightness,
// letter-spacing and line-height sliders over a photo library. Every
// one of those is a decision the reader has to make before they can
// send a verse to someone, and the photo library is an asset-licensing
// problem this app does not need. Three background treatments drawn
// from the reader's own theme seed, times light/dark, is six cards —
// enough that it does not feel canned, few enough that it is one tap.

import 'package:flutter/material.dart';

import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/theme_accent.dart';

/// The card's logical width. Everything else about the card is
/// derived or intrinsic.
///
/// 360 dp because it is the narrowest phone this app supports (the
/// reading pane's own `screenW < 390` breakpoint is measured against
/// the same class of device), so a preview at this width fits on every
/// screen without being scaled down — and because 360 × the export's
/// pixel ratio of 3 lands on 1080 px, which is the width WeChat
/// Moments, Instagram and X all publish at without resampling.
const double kVerseCardWidth = 360;

/// Floor on the card's height. A three-word verse ("Jesus wept.")
/// would otherwise export as a letterbox strip that reads as a
/// cropping accident rather than a card.
const double kVerseCardMinHeight = 360;

/// The card's padding, and the only magic number in its layout.
const double kVerseCardPadding = 28;

/// The three background treatments.
///
/// All three are built from the reader's own `primaryColor` seed via
/// [verseCardScheme], so a reader who set the app to plum gets plum
/// cards. None of them introduces a colour this app does not already
/// paint elsewhere.
enum VerseCardStyle {
  /// Surface + hairline border. The default, and the one that survives
  /// being posted next to somebody else's screenshot.
  plain,

  /// Filled with `primaryContainer` — the same tint the app uses for
  /// the dark AppBar and for every chip.
  tinted,

  /// `primaryContainer` → `secondaryContainer` on the diagonal.
  ///
  /// Both ends are container tones, which is why the single
  /// `onPrimaryContainer` foreground is legible across the whole
  /// sweep. A gradient running `primary` → `primaryContainer` was
  /// tried first and abandoned: it needs `onPrimary` at one end and
  /// `onPrimaryContainer` at the other, and text cannot be two
  /// colours at once.
  gradient,
}

/// Build the [ColorScheme] a card paints with, for [brightness],
/// from the reader's chosen [seed] colour.
///
/// **Why this mirrors `main.dart` instead of reading the app's theme.**
/// The card offers a light/dark toggle, so it needs BOTH schemes at
/// once; `Theme.of(context)` only ever yields the one that is active.
/// `MaterialApp` does not expose its `theme` / `darkTheme` to
/// descendants, so there is no way to ask the app for the other one.
///
/// The recipe below is `main.dart`'s, token for token — the vibrant
/// `fromSeed` variant it switched to in Round 56 so a chosen colour
/// actually reads as that colour, plus the dark-mode `primary`
/// override from [darkReadingAccent] that exists precisely because
/// Material's own dark mapping loses the hue. Hoisting the recipe out
/// of `main.dart` into a shared helper would be the tidier fix and is
/// the right one to make later; `main.dart` is not this change's to
/// edit.
ColorScheme verseCardScheme({
  required Color seed,
  required Brightness brightness,
}) {
  final base = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );
  if (brightness == Brightness.light) return base;
  final accent = darkReadingAccent(seed);
  return base.copyWith(primary: accent, onPrimary: onAccentColor(accent));
}

/// Type size for a verse body of [characters] characters.
///
/// A ladder rather than a continuous function, and rather than a
/// [FittedBox]. `BoxFit.scaleDown` inside a fixed box is the usual
/// reflex here and it is wrong for scripture: a reader who selects the
/// whole of Psalm 119 would get a 1080 px image of type too small to
/// read on the phone it was sent to, and would have no way to tell
/// that had happened. Here the type steps down to a legible floor and
/// then the CARD grows instead. A tall card is an honest picture of a
/// long selection; a shrunk one is not.
///
/// The thresholds are verse-shaped rather than round: ~120 chars is a
/// single English verse, ~260 is two or three, ~520 is a short
/// paragraph, and past ~1200 the reader is sharing a passage and has
/// accepted that it will be a wall of text.
double verseCardBodyFontSize(int characters) {
  if (characters <= 120) return 22;
  if (characters <= 260) return 19;
  if (characters <= 520) return 16;
  if (characters <= 1200) return 13.5;
  return 11.5;
}

/// The text style the card paints its verse body in.
///
/// Public because the CJK-glyph test rasterises exactly this style —
/// asserting against a style the card does not actually use would
/// prove nothing. [kCjkFontFallback] is the load-bearing part: without
/// it CanvasKit has no CJK font in its registry and every Chinese
/// character exports as tofu.
TextStyle verseCardBodyStyle({
  required int characters,
  required Color color,
  String? fontFamily,
}) =>
    TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: verseCardBodyFontSize(characters),
      height: 1.62,
      fontWeight: FontWeight.w500,
      color: color,
    );

/// Resolved colours for one [VerseCardStyle] against one [ColorScheme].
@immutable
class VerseCardPalette {
  final Gradient? gradient;
  final Color background;

  /// Verse text.
  final Color foreground;

  /// The reference line and the version pill.
  final Color accent;

  /// The licence line and the app name — present, not shouting.
  final Color muted;

  /// Hairline border + rule above the footer. Transparent where the
  /// fill already separates the card from whatever is behind it.
  final Color border;

  const VerseCardPalette({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.muted,
    required this.border,
    this.gradient,
  });

  factory VerseCardPalette.of(VerseCardStyle style, ColorScheme s) {
    switch (style) {
      case VerseCardStyle.plain:
        return VerseCardPalette(
          background: s.surface,
          foreground: s.onSurface,
          accent: s.primary,
          muted: s.onSurfaceVariant,
          border: s.outlineVariant,
        );
      case VerseCardStyle.tinted:
        return VerseCardPalette(
          background: s.primaryContainer,
          foreground: s.onPrimaryContainer,
          accent: s.onPrimaryContainer,
          muted: s.onPrimaryContainer.withValues(alpha: 0.72),
          border: s.onPrimaryContainer.withValues(alpha: 0.16),
        );
      case VerseCardStyle.gradient:
        return VerseCardPalette(
          background: s.primaryContainer,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [s.primaryContainer, s.secondaryContainer],
          ),
          foreground: s.onPrimaryContainer,
          accent: s.onPrimaryContainer,
          muted: s.onPrimaryContainer.withValues(alpha: 0.72),
          border: s.onPrimaryContainer.withValues(alpha: 0.16),
        );
    }
  }
}

/// A composed, exportable verse card: reference, verse text, the
/// translation's name, and whatever credit that translation is owed.
class VerseCard extends StatelessWidget {
  /// Localised citation, e.g. `约翰福音 3:16` — already formatted by the
  /// caller, because the reader's own book names and verse-range rules
  /// live in the reading pane.
  final String reference;

  /// The verse text, already run through `sanitizeForCopy` so the
  /// corpus's internal `{}` / `[]` markup and poetry newlines do not
  /// end up on a picture.
  final String body;

  /// Short label of the translation — `KJV`, `和合本雅伟版`.
  final String versionLabel;

  /// The translation's credit line, or null when the app owes none.
  /// Sourced from the same strings the About page renders, never
  /// paraphrased here.
  final String? licence;

  /// The app's own name, in the reader's language.
  final String appName;

  final VerseCardStyle style;
  final ColorScheme scheme;

  /// The reader's chosen font, so a shared card looks like the app
  /// they are reading in. Null falls back to the engine default.
  final String? fontFamily;

  const VerseCard({
    super.key,
    required this.reference,
    required this.body,
    required this.versionLabel,
    required this.appName,
    required this.scheme,
    this.licence,
    this.style = VerseCardStyle.plain,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final palette = VerseCardPalette.of(style, scheme);
    return Container(
      width: kVerseCardWidth,
      constraints: const BoxConstraints(minHeight: kVerseCardMinHeight),
      decoration: BoxDecoration(
        color: palette.gradient == null ? palette.background : null,
        gradient: palette.gradient,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(kVerseCardPadding),
      // Two children and `spaceBetween`, so a short verse sits under
      // the reference with the footer pinned to the bottom edge, and a
      // long one simply pushes the footer down. An `Expanded` in the
      // middle would be the obvious alternative and cannot work: the
      // card's height is intrinsic, so there is no free space to
      // expand into.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Passage(
            reference: reference,
            body: body,
            palette: palette,
            fontFamily: fontFamily,
          ),
          _Footer(
            versionLabel: versionLabel,
            licence: licence,
            appName: appName,
            palette: palette,
            fontFamily: fontFamily,
          ),
        ],
      ),
    );
  }
}

class _Passage extends StatelessWidget {
  final String reference;
  final String body;
  final VerseCardPalette palette;
  final String? fontFamily;

  const _Passage({
    required this.reference,
    required this.body,
    required this.palette,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reference,
          style: TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: kCjkFontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: palette.accent,
          ),
        ),
        const SizedBox(height: 16),
        // No maxLines and no overflow handling anywhere on this Text.
        // That is the point: the only two outcomes available to it are
        // "wrap" and "make the card taller", which is what the type
        // ladder in [verseCardBodyFontSize] is built around.
        Text(
          body,
          style: verseCardBodyStyle(
            characters: body.characters.length,
            color: palette.foreground,
            fontFamily: fontFamily,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final String versionLabel;
  final String? licence;
  final String appName;
  final VerseCardPalette palette;
  final String? fontFamily;

  const _Footer({
    required this.versionLabel,
    required this.appName,
    required this.palette,
    this.licence,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: palette.border),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                versionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ],
        ),
        if (licence != null && licence!.isNotEmpty) ...[
          const SizedBox(height: 8),
          // Small, but never elided. A credit line that a card can
          // truncate is not a credit line — if it does not fit, the
          // card grows, same rule as the verse body.
          Text(
            licence!,
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: 9,
              height: 1.5,
              color: palette.muted,
            ),
          ),
        ],
      ],
    );
  }
}
