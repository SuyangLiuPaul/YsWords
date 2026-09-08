/// The wall itself: one verse, very large, with the reference in a
/// corner and nothing else.
///
/// Split out of `projection_page.dart` because the page is the OPERATOR
/// — cursor, keys, control strip, the second edition's corpus — and this
/// is the CONGREGATION. The two have different audiences and almost no
/// shared state, and keeping them apart is what lets a test assert what
/// the room can see without driving a keyboard.
///
/// ## THE CHOSEN SIZE IS A CEILING
///
/// [typeSize] is what the operator asked for, and the passage is drawn
/// at that size whenever it fits. When it does not, `BoxFit.scaleDown`
/// shrinks the whole block rather than letting it run off the wall or
/// clip — a clipped verse is not an ugly verse, it is a DIFFERENT verse,
/// and the congregation has no way to know which. The fit's child is
/// pinned to the full usable WIDTH, so the horizontal scale factor is
/// always exactly 1 and the only thing `scaleDown` can respond to is a
/// block too tall for the room. Without that pin a `FittedBox` gives its
/// child unbounded width and the verse lays out as a single line.
///
/// ## WHY THE SECOND EDITION IS STACKED, NOT COLUMNED
///
/// Split view (`home_page.dart`'s `_buildSideBySide`) puts editions side
/// by side because a desk is wider than it is tall and the reader is
/// comparing words. A projector is 16:9 and the congregation is reading
/// sentences, so two half-width columns would halve the line length and
/// roughly double the number of lines — the same words, in a narrower
/// measure, smaller. Stacked, both editions keep the full width.
///
/// Note that `home_page.dart` itself already agrees: below the tablet
/// breakpoint it drops split view to `_buildTopBottom`. This is the same
/// judgement about the same trade-off, reached for a screen whose
/// aspect ratio is fixed at 16:9 and whose reader is forty feet away.
///
/// The second block is set slightly smaller ([kProjectionSecondScale]).
/// Not because it matters less, but because something has to lead: two
/// blocks of identical type with a gap between them read as one
/// paragraph that has been interrupted, and the room needs to know at a
/// glance which one is the sermon's text.
///
/// ## EVERY STYLE HERE PINS `kCjkFontFallback`
///
/// `main.dart`'s two themes already carry `NotoSansSC-YsWords` in their
/// own `fontFamilyFallback`, so inheriting would work today. Scripture
/// surfaces in this app pin it anyway — `main.dart`'s own comment says
/// "verse text + word spans already use kCjkFontFallback", and
/// `build_verse_content_spans.dart` sets it on all eleven of its styles
/// — and this is the surface where the failure is worst. On Flutter
/// web's CanvasKit an unresolved face draws as tofu, and 34 tofu boxes
/// at 76 px on a wall in front of a congregation is not a degraded
/// reading, it is no reading at all. One inherited property away from
/// that is too close, so the reference gets the pin too even though it
/// is chrome — a reference is exactly the string most likely to be a
/// book name in Chinese.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:yswords/constants/bible_versions.dart'
    show shortBibleVersionLabel;
import 'package:yswords/constants/projection_strings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// The palette the projection paints in, whatever the reader's own
/// theme is set to.
///
/// Every other surface in this app follows `settings.themeMode`, and
/// this one does not, because the surface is not the reader's desk. A
/// projector ADDS light: white pixels wash a room, dark pixels are the
/// closest thing a projector has to "off", and the blank key is only
/// honest if blanking lands on the same dark ground the passage was
/// already sitting on. Blanking a light page to black is a flash across
/// the whole wall.
///
/// It is still YsWords' own palette and introduces no new colour: this
/// is the exact expression `main.dart` builds its `seededDark` with —
/// same seed (the reader's chosen theme colour), same
/// `DynamicSchemeVariant.vibrant` — with only `brightness` forced.
///
/// `main.dart` then overrides `primary` with `darkReadingAccent(seed)`
/// so thin accents stay hue-faithful. That override is deliberately NOT
/// reproduced here, because nothing on a wall paints `primary`: there is
/// nothing clickable, nothing selected, and no link. Copying an override
/// whose only purpose is legibility of an accent this surface does not
/// draw would be cargo cult, not fidelity.
ColorScheme projectionDarkScheme(Color seed) => ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );

/// The second edition's size, as a fraction of the first's.
const double kProjectionSecondScale = 0.82;

/// The corner reference's size, as a fraction of the passage's.
const double kProjectionReferenceScale = 0.26;

/// The size the corner reference will not go below however small the
/// operator sets the passage.
///
/// The reference is the one thing on the wall the congregation uses to
/// find the place in their own Bible, so it is the last thing that
/// should become unreadable when the operator winds the type down to fit
/// a long verse.
///
/// Worth knowing which of the two numbers is actually in force: below
/// about 100 px of passage type the FLOOR governs and the ratio does
/// nothing, so across the bottom two-thirds of `kProjectionTypeSteps`
/// the reference is a fixed 26 px. That is the intent, not an accident —
/// the reference's job does not get smaller because the verse did. The
/// ratio exists for the top of the ladder, where 26 px under 184 px
/// scripture would read as a mistake rather than as restraint.
const double kProjectionReferenceFloor = 26.0;

/// The share of the viewport left as margin on each side, and top and
/// bottom.
///
/// A projected image is almost never square with the screen it lands on;
/// generous margins are what stop the first and last words of a verse
/// falling off the edge of the physical screen in a room nobody
/// calibrated. Vertical is roomier than horizontal because that is where
/// the control strip and the reference live.
const double kProjectionSideMargin = 0.07;
const double kProjectionVerticalMargin = 0.11;

class ProjectionStage extends StatelessWidget {
  const ProjectionStage({
    super.key,
    required this.verse,
    required this.reference,
    required this.versionCode,
    required this.typeSize,
    required this.blank,
    required this.locale,
    required this.scheme,
    this.secondOn = false,
    this.secondText,
    this.secondCode,
    this.secondLoading = false,
  });

  /// The verse on the wall, or null when the corpus has not arrived.
  final Verse? verse;

  /// Book, chapter and verse as the room reads it — built by the page,
  /// because the reference and the text must name the same edition.
  final String reference;

  final String versionCode;

  /// The size the operator asked for. A ceiling — see the library doc.
  final double typeSize;

  /// The blank key. The wall goes to the ground colour and stays there:
  /// the passage is not merely hidden, the whole stage is, reference
  /// included. A "blank" screen that still names a verse tells the room
  /// where the sermon is while the preacher is somewhere else.
  final bool blank;

  final String locale;

  /// The fixed dark palette — see [projectionDarkScheme]. Passed in
  /// rather than read off `Theme.of(context)` so the stage cannot
  /// accidentally inherit the reader's light theme, and so a test can
  /// render the wall without a `MaterialApp` theme at all.
  final ColorScheme scheme;

  final bool secondOn;
  final String? secondText;
  final String? secondCode;
  final bool secondLoading;

  @override
  Widget build(BuildContext context) {
    if (blank) return ColoredBox(color: scheme.surface);

    return ColoredBox(
      color: scheme.surface,
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth * kProjectionSideMargin;
          final top = box.maxHeight * kProjectionVerticalMargin;
          final usable = math.max(box.maxWidth - side * 2, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: side, vertical: top),
                  child: Center(
                    child: verse == null
                        ? _emptyState()
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: usable,
                              child: _passage(),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                left: side,
                right: side,
                bottom: top * _kReferenceInsetShare,
                child: _reference(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// How far up from the bottom edge the reference sits, as a share of
  /// the vertical margin — inside the margin the passage respects, so it
  /// can never collide with the text above it.
  static const double _kReferenceInsetShare = 0.35;

  /// The reference size actually in force: the ratio, floored.
  double get _referenceSize => math.max(
        typeSize * kProjectionReferenceScale,
        kProjectionReferenceFloor,
      );

  Widget _emptyState() => Text(
        _s('projectionNoPassage', 'No passage is open', locale),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontFamilyFallback: kCjkFontFallback,
          fontSize: _referenceSize,
        ),
      );

  Widget _passage() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            verse!.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: typeSize,
              height: _kLineHeight,
            ),
          ),
          if (secondOn) ...[
            SizedBox(height: typeSize * _kBlockGapShare),
            Text(
              _secondBody(),
              textAlign: TextAlign.center,
              style: TextStyle(
                // A missing or still-loading second edition is
                // apparatus, not scripture, and must not be mistaken
                // for the verse.
                color: secondText == null
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: typeSize * kProjectionSecondScale,
                height: _kLineHeight,
              ),
            ),
          ],
        ],
      );

  /// Looser than the reading pane's own leading, because the eye that
  /// has to find the next line is at the back of a hall rather than a
  /// foot from the glass, and because at this size the lines are far
  /// enough apart in absolute terms that a tight ratio reads as
  /// crowding.
  static const double _kLineHeight = 1.45;

  /// The gap between the two editions, as a share of the passage size —
  /// so it stays a gap at every step of the ladder instead of vanishing
  /// at 184 px and swallowing the wall at 40.
  static const double _kBlockGapShare = 0.6;

  String _secondBody() {
    if (secondLoading) {
      return _s('projectionSecondVersionLoading',
          'Loading the second edition', locale);
    }
    return secondText ??
        _s('projectionSecondVersionMissing',
            'This edition has no text here', locale);
  }

  /// The reference, and the edition or editions it belongs to.
  ///
  /// The edition tags are part of the reference and not a separate badge
  /// because the room's question is ONE question — *where is this, and
  /// in what?* — and because a second edition on the wall with no way to
  /// tell which translation is which is worse than one edition.
  Widget _reference() {
    if (verse == null) return const SizedBox.shrink();
    final tags = <String>[
      shortBibleVersionLabel(versionCode),
      if (secondOn && secondCode != null) shortBibleVersionLabel(secondCode!),
    ];
    return Text(
      '$reference · ${tags.join(" · ")}',
      style: TextStyle(
        color: scheme.onSurfaceVariant,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: _referenceSize,
      ),
    );
  }
}

/// `projectionStrings`, with English as the fallback locale before the
/// caller's own literal — the same `?[locale] ?? ?['en']` idiom every
/// `uiStrings` lookup in this repo uses.
String _s(String key, String fallback, String locale) =>
    projectionStrings[key]?[locale] ??
    projectionStrings[key]?['en'] ??
    fallback;
