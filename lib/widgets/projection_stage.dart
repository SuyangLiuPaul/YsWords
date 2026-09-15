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
/// ## THE GROUND IS THE OPERATOR'S TO CHOOSE, AND EVERY CHOICE IS DARK
///
/// 2026-09-09, from the owner: 「背景也不能set」. The ground was one
/// fixed scheme. It is now four, and the argument [projectionDarkScheme]
/// makes is not weakened by that — it is the constraint the whole set is
/// built inside, so it is worth restating in the form the set has to
/// satisfy:
///
/// **A projector ADDS light.** White pixels wash a room; dark pixels are
/// the closest thing a projector has to "off". So the blank key is only
/// honest when blanking lands on the SAME ground the passage was already
/// sitting on — blanking a light page to black is a flash across the
/// whole wall, and blanking a dark page to a different dark is a smaller
/// version of the same flash.
///
/// Two rules fall out of that, and both are pinned by tests rather than
/// left to a future reader's judgement:
///
///   1. **No ground may be brighter, anywhere, than the ground this page
///      already shipped with.** [ProjectionGround.seeded] is therefore
///      the ceiling as well as the default: every colour any other
///      ground paints is at or below its luminance, and every one of
///      them is under [kProjectionGroundMaxLuminance] outright. A light
///      ground is not offered, and should not be added — the room's
///      light comes from the projector, so a light ground is the lamp at
///      full power for the whole service.
///   2. **Blanking paints the ground, whatever the ground is.** The
///      blank branch below and the normal branch call the same
///      [projectionGroundDecoration]. That is what makes the gradient
///      ground legal: `spotlight` blanks to `spotlight`, not to black,
///      so pressing B changes exactly one thing — whether there is text.
///
/// The four, and why each earns a row in a picker an operator reads in
/// the dark:
///
///   * **[ProjectionGround.seeded]** — the dark surface this page has
///     always painted, from the reader's own theme colour. Default, so
///     an operator who never opens the picker sees no change at all.
///   * **[ProjectionGround.ink]** — the same darkness with the hue taken
///     out. `seeded` is tinted by the READER's accent choice, and at
///     three hundred inches a tint stops being a tint and becomes a
///     coloured wall. That is the same category error the type scale
///     already refuses to make (see `projection_page.dart`: the room's
///     scale is not the reader's), and until now the ground was making
///     it. It is also the ground a projectionist reaches for when pure
///     black rings: on a bright lamp, white type on absolute black
///     haloes, and lifting the ground a few points fixes it.
///   * **[ProjectionGround.black]** — `#000000`, which is what a
///     projector's "off" actually is, and the only ground an OLED or an
///     LED wall can render by switching pixels off rather than by
///     lighting them dark. On those two display types every other ground
///     here is emitted light and this one is not.
///   * **[ProjectionGround.spotlight]** — `seeded` at the centre falling
///     to black at the corners. Its brightest pixel is exactly the
///     default ground, so it adds nothing anywhere, and the falloff buys
///     two things a flat field cannot: the eye is carried to the middle,
///     where the verse is, and a projector that overshoots the screen
///     onto the wall beside it — which is most of them, in most rooms,
///     as [kProjectionSideMargin] already concedes — spills near-black
///     instead of a full-value rectangle.
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
import 'package:yswords/constants/text_patterns.dart'
    show sanitizeForProjection;
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
/// 2026-09-09: this is now the source of the DEFAULT ground rather than
/// of the only one — see [ProjectionGround] and the library doc's ground
/// section. It still supplies every colour the stage draws ON whichever
/// ground is chosen (the type, the reference, the apparatus line), which
/// is why the argument above did not have to be weakened to make room
/// for the other three: all four grounds are dark, so the text colours
/// that were picked against a dark ground still land on one.
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

/// The grounds the operator can put the passage on.
///
/// All four are dark, deliberately and permanently — see the library
/// doc's ground section for the argument and for what each one is for.
/// The order here is the order they appear in the picker and the order
/// [projectionGroundAfter] steps through, so it runs from "what you
/// already had" to "as close to off as this display gets" and then to
/// the one that is doing something.
///
/// Persisted by NAME (`ProjectionGround.name`), never by index, so
/// inserting a fifth ground later cannot silently reassign the choice an
/// operator already made.
enum ProjectionGround { seeded, ink, black, spotlight }

/// Where the passage sits against the measure.
///
/// Centred is the default and is what a projected verse has always
/// been: a short block of scripture reads as a unit, and the room's
/// eyes are already travelling. Start-aligned exists because a LONG
/// passage centred is hard work — every line begins in a different
/// place, and at the back of a hall that costs a beat per line. The
/// name is `start`, not `left`, because a Hebrew passage starts on the
/// right.
enum ProjectionAlign { centre, start }

/// Whether the verses are separate blocks or one paragraph.
///
/// Verse by verse is what a preacher working through a passage wants:
/// each verse is a unit, and the number is beside it. Continuous is
/// what a reading wants — the same words as the printed page has them,
/// with nothing between the sentences.
enum ProjectionFlow { verseByVerse, continuous }

/// Where the reference goes, if anywhere.
///
/// The corner is where it has always been, and it is right for a
/// sermon: the room glances down, finds the place, and looks back up.
/// Under the passage is the devotional setting. Off is for a wall that
/// is not a Bible reading at all — a call to worship, a line the
/// congregation is about to say together.
enum ProjectionReferencePlace { corner, under, off }

ProjectionAlign projectionAlignFromName(String? name) =>
    ProjectionAlign.values.firstWhere((v) => v.name == name,
        orElse: () => ProjectionAlign.centre);

ProjectionFlow projectionFlowFromName(String? name) =>
    ProjectionFlow.values.firstWhere((v) => v.name == name,
        orElse: () => ProjectionFlow.verseByVerse);

ProjectionReferencePlace projectionReferencePlaceFromName(String? name) =>
    ProjectionReferencePlace.values.firstWhere((v) => v.name == name,
        orElse: () => ProjectionReferencePlace.corner);

/// How the wall is set, as opposed to what colour it is.
///
/// Four independent choices rather than a list of named formats. A
/// "devotional mode" switch would have to decide what happens to the
/// operator's other three settings when it is turned off, and every
/// answer to that is wrong for somebody. [devotional] is the
/// combination people mean by the word, offered as a value the settings
/// screen can name — not as a mode that overwrites anything.
///
/// Persisted as its field NAMES, like [ProjectionGround], so a later
/// option cannot silently reassign a choice an operator already made.
@immutable
class ProjectionLayout {
  const ProjectionLayout({
    this.align = ProjectionAlign.centre,
    this.flow = ProjectionFlow.verseByVerse,
    this.numbers = true,
    this.reference = ProjectionReferencePlace.corner,
  });

  final ProjectionAlign align;
  final ProjectionFlow flow;

  /// Whether verse numbers are drawn at all.
  ///
  /// They have never been drawn for a single verse — the reference
  /// already names it — and this does not change that. It governs the
  /// case where there is more than one.
  final bool numbers;

  final ProjectionReferencePlace reference;

  /// The shipped wall: centred, verse by verse, numbered, reference in
  /// the corner.
  static const ProjectionLayout standard = ProjectionLayout();

  /// What people mean by "devotional format": the words as one
  /// paragraph, no numbers in front of them, and the address centred
  /// underneath.
  static const ProjectionLayout devotional = ProjectionLayout(
    flow: ProjectionFlow.continuous,
    numbers: false,
    reference: ProjectionReferencePlace.under,
  );

  bool get isDevotional =>
      flow == devotional.flow &&
      numbers == devotional.numbers &&
      reference == devotional.reference;

  ProjectionLayout copyWith({
    ProjectionAlign? align,
    ProjectionFlow? flow,
    bool? numbers,
    ProjectionReferencePlace? reference,
  }) =>
      ProjectionLayout(
        align: align ?? this.align,
        flow: flow ?? this.flow,
        numbers: numbers ?? this.numbers,
        reference: reference ?? this.reference,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'align': align.name,
        'flow': flow.name,
        'numbers': numbers,
        'reference': reference.name,
      };

  /// Off disk, so every field falls back rather than throws — a blob
  /// written by a build that did not have this at all is valid, and it
  /// means the wall the app shipped with.
  factory ProjectionLayout.fromJson(Object? raw) {
    final m = raw is Map ? raw : const <String, dynamic>{};
    return ProjectionLayout(
      align: projectionAlignFromName(m['align'] as String?),
      flow: projectionFlowFromName(m['flow'] as String?),
      numbers: m['numbers'] is bool ? m['numbers'] as bool : true,
      reference: projectionReferencePlaceFromName(m['reference'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectionLayout &&
      other.align == align &&
      other.flow == flow &&
      other.numbers == numbers &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(align, flow, numbers, reference);
}

/// The neutral dark ground: [ProjectionGround.ink].
///
/// Chosen by the two numbers that matter on a wall and nothing else. It
/// is neutral — R, G and B within two points, so no accent hue survives
/// into a three-hundred-inch field — and it is lifted just far enough
/// off absolute black to stop white type haloing on a bright lamp, while
/// staying an order of magnitude under
/// [kProjectionGroundMaxLuminance].
const Color kProjectionInk = Color(0xFF0F0F11);

/// Absolute black: [ProjectionGround.black]. Spelled out rather than
/// `Colors.black` because what this constant means is the exact value
/// that switches an OLED or LED pixel off, not "the app's black".
const Color kProjectionTrueBlack = Color(0xFF000000);

/// How far out [ProjectionGround.spotlight] reaches before it is fully
/// black, as a share of the shorter viewport axis.
///
/// Larger than 1 on purpose: at 1.0 the corners of a 16:9 frame are far
/// past the end of the gradient and sit in flat black, which reads as a
/// dark rectangle inside a dark rectangle. Reaching past the frame keeps
/// the falloff continuous all the way into the corners.
const double kProjectionSpotlightRadius = 1.15;

/// The ceiling every ground has to stay under.
///
/// Relative luminance, the same 0–1 quantity `Color.computeLuminance`
/// returns. 0.05 is not a perceptual threshold, it is a budget: the
/// default ground sits around 0.006, so this leaves a future ground an
/// order of magnitude of room and still fails anything that could be
/// called light. `projection_setup_test.dart` holds every ground to it,
/// and to the stricter rule that nothing may exceed the default ground.
const double kProjectionGroundMaxLuminance = 0.05;

/// What [ground] paints, given the scheme the rest of the stage is
/// drawn in.
///
/// One function for both the passage's ground and the blank one, which
/// is the mechanism behind the second rule in the library doc: there is
/// no second place for blanking's colour to be decided, so it cannot
/// drift away from the ground the verse was on.
BoxDecoration projectionGroundDecoration(
  ProjectionGround ground,
  ColorScheme scheme,
) {
  switch (ground) {
    case ProjectionGround.seeded:
      return BoxDecoration(color: scheme.surface);
    case ProjectionGround.ink:
      return const BoxDecoration(color: kProjectionInk);
    case ProjectionGround.black:
      return const BoxDecoration(color: kProjectionTrueBlack);
    case ProjectionGround.spotlight:
      return BoxDecoration(
        gradient: RadialGradient(
          radius: kProjectionSpotlightRadius,
          colors: <Color>[scheme.surface, kProjectionTrueBlack],
        ),
      );
  }
}

/// Every colour [ground] can put on the wall.
///
/// Exists so the luminance rule can be checked as a property of the SET
/// rather than restated per ground in a test — a fifth ground added
/// without a matching test still has to pass it.
List<Color> projectionGroundColors(
  ProjectionGround ground,
  ColorScheme scheme,
) {
  final decoration = projectionGroundDecoration(ground, scheme);
  return decoration.gradient?.colors ??
      <Color>[decoration.color ?? kProjectionTrueBlack];
}

/// The ground a stored name means, defaulting to the one that was
/// always there.
///
/// The clamp lives here, at the READ, rather than at the write — the
/// same choice `_kInterlinearVersion` documents in `app_settings.dart`.
/// A name this build does not know (a ground withdrawn, a preset written
/// by a newer version) shows the default rather than an empty wall.
ProjectionGround projectionGroundFromName(String? name) =>
    ProjectionGround.values.firstWhere(
      (g) => g.name == name,
      orElse: () => ProjectionGround.seeded,
    );

/// The next ground round the ring — what the `G` key does.
///
/// A cycle key as well as a picker because the picker is a dialog, and a
/// dialog is a thing the congregation can see and the operator has to
/// aim at. Stepping the ring is one keystroke with the hands where they
/// already are.
ProjectionGround projectionGroundAfter(ProjectionGround ground) =>
    ProjectionGround.values[
        (ground.index + 1) % ProjectionGround.values.length];

/// The picker's label for [ground], in the operator's language.
String projectionGroundLabel(ProjectionGround ground, String locale) =>
    _s('projectionGround_${ground.name}', ground.name, locale);

/// The layout choices, named for the settings screen. Same key shape as
/// the grounds above, so one convention covers every projector choice.
String projectionAlignLabel(ProjectionAlign v, String locale) =>
    _s('projectionAlign_${v.name}', v.name, locale);

String projectionFlowLabel(ProjectionFlow v, String locale) =>
    _s('projectionFlow_${v.name}', v.name, locale);

String projectionReferencePlaceLabel(
        ProjectionReferencePlace v, String locale) =>
    _s('projectionReference_${v.name}', v.name, locale);

/// One projector string, for a caller outside this file — the settings
/// screen's hint under the layout controls. The table is keyed the same
/// way for every projector string; this is the same lookup the labels
/// above do, with the key spelled by the caller.
String projectionString(String key, String fallback, String locale) =>
    _s(key, fallback, locale);

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

/// The wall the type ladder is calibrated against.
///
/// [kProjectionTypeSteps] are absolute logical pixels — 76 px, 184 px —
/// and they only mean anything relative to a screen. Almost every
/// projector and television a church owns is 1080p, so that is the
/// screen they are quoted against.
///
/// This exists for the PREVIEW. A 343 px box showing 76 px type is not
/// showing a small wall, it is showing a wall five times closer, and
/// that is what made the Settings preview unrecognisable: the passage
/// filled half the box where it fills a fifth of the wall.
const double kProjectionReferenceWallWidth = 1920.0;

/// The type size a preview box [boxWidth] wide should draw at to stand
/// in for a wall set at [typeSize].
///
/// Both boxes are 16:9, so matching the width matches everything: the
/// preview becomes the wall, at a distance.
double projectionPreviewTypeSize(double boxWidth, double typeSize) =>
    typeSize * (boxWidth / kProjectionReferenceWallWidth);

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
    required this.verses,
    required this.reference,
    required this.versionCode,
    required this.typeSize,
    required this.blank,
    required this.locale,
    required this.scheme,
    this.ground = ProjectionGround.seeded,
    this.secondOn = false,
    this.secondTexts,
    this.secondCode,
    this.secondLoading = false,
    this.countdownRemaining,
    this.layout = ProjectionLayout.standard,
  });

  /// How the passage is set: centred or start-aligned, verse by verse
  /// or run together, numbered or plain, and where the reference goes.
  /// See [ProjectionLayout] — every field is the operator's, and none
  /// of them is inferred from the passage.
  final ProjectionLayout layout;

  /// The verses on the wall — one, or the block a selection opened.
  /// Empty is the empty state.
  final List<Verse> verses;

  /// Time left before the service starts, or null when no countdown is
  /// running. While it is running it REPLACES the passage: a room that
  /// is filling is being told when to sit down, and a verse behind a
  /// clock is neither.
  ///
  /// `Duration.zero` is a real state — 「就要开始了」 — and not the same
  /// as null. A countdown that vanishes at zero takes the wall back to
  /// whatever was behind it at the exact moment everyone is looking.
  final Duration? countdownRemaining;

  /// Book, chapter and verse as the room reads it — built by the page,
  /// because the reference and the text must name the same edition.
  final String reference;

  final String versionCode;

  /// The size the operator asked for. A ceiling — see the library doc.
  final double typeSize;

  /// The blank key. The wall goes to the ground and stays there: the
  /// passage is not merely hidden, the whole stage is, reference
  /// included. A "blank" screen that still names a verse tells the room
  /// where the sermon is while the preacher is somewhere else.
  ///
  /// "The ground" means [ground] — the one the operator chose, not a
  /// black this widget picks for itself. Both branches of [build] paint
  /// through [projectionGroundDecoration], so blanking can only ever
  /// change whether there is text.
  final bool blank;

  final String locale;

  /// The fixed dark palette — see [projectionDarkScheme]. Passed in
  /// rather than read off `Theme.of(context)` so the stage cannot
  /// accidentally inherit the reader's light theme, and so a test can
  /// render the wall without a `MaterialApp` theme at all.
  final ColorScheme scheme;

  /// Which dark ground the passage sits on. Defaults to the one this
  /// page always had, so a caller that does not care about grounds —
  /// every existing one — is unchanged.
  final ProjectionGround ground;

  final bool secondOn;
  /// The second edition's text per verse in [verses], by position;
  /// null when the block is off or not loaded.
  final List<String?>? secondTexts;
  final String? secondCode;
  final bool secondLoading;

  /// The chosen ground, as one widget, used by BOTH branches of [build].
  ///
  /// A single call site for the blank wall and the lit one is the whole
  /// of rule 2 in the library doc: there is nowhere for a second opinion
  /// about what "blank" looks like to live.
  Widget _ground({Widget? child}) => DecoratedBox(
        decoration: projectionGroundDecoration(ground, scheme),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    if (blank) return _ground(child: const SizedBox.expand());

    final left = countdownRemaining;
    if (left != null) {
      return _ground(
        child: Center(
          // The same scaleDown rule the passage gets: the clock is
          // drawn at the size the operator asked for and shrunk only if
          // the wall is narrower than it needs.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 24, vertical: typeSize * 0.4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatProjectionCountdown(left),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontFamilyFallback: kCjkFontFallback,
                      // Bigger than a verse: it is two or three glyphs
                      // seen from the back of a hall, and it is the only
                      // thing on the wall.
                      fontSize: typeSize * 2.2,
                      height: 1.1,
                      fontWeight: FontWeight.w300,
                      // Digits that do not jostle as the seconds tick.
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(height: typeSize * 0.3),
                  Text(
                    _s(
                        left == Duration.zero
                            ? 'projectionCountdownNow'
                            : 'projectionCountdownSoon',
                        left == Duration.zero
                            ? 'We are beginning'
                            : 'The service begins in',
                        locale),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: _referenceSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _ground(
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth * kProjectionSideMargin;
          final top = box.maxHeight * kProjectionVerticalMargin;
          final usable = math.max(box.maxWidth - side * 2, 1.0);
          final corner = layout.reference == ProjectionReferencePlace.corner &&
              verses.isNotEmpty;
          return Padding(
            // The corner reference keeps the inset it always had. What
            // changed is that it is now a ROW of this column rather
            // than a `Positioned` floating over the passage, so the
            // space it takes is space the passage was never offered.
            padding: EdgeInsets.fromLTRB(
                side, top, side, corner ? top * _kReferenceInsetShare : top),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, room) {
                    if (verses.isEmpty) {
                      return Center(child: _emptyState());
                    }
                    final size = _solvedSize(
                      usable,
                      room.maxHeight,
                      MediaQuery.textScalerOf(context),
                      Directionality.of(context),
                    );
                    return Center(
                      // `scaleDown` is a no-op once the size is solved —
                      // it stays as the last line of defence, so a
                      // measurement that is a pixel out degrades into a
                      // hair of shrinkage rather than a red overflow
                      // band across the wall.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: usable,
                          child: _passage(size),
                        ),
                      ),
                    );
                  }),
                ),
                if (corner) ...[
                  SizedBox(height: top * _kReferenceGapShare),
                  _reference(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// The largest size at or below [typeSize] whose passage fits
  /// [height] when laid out across the full [width].
  ///
  /// The height of a passage falls as its type does, so a bisection
  /// finds the answer in a dozen measurements. Twelve halvings of a
  /// 180 px range settle to under a twentieth of a pixel, which is far
  /// finer than anything the eye or the renderer can act on.
  double _solvedSize(
      double width, double height, TextScaler scaler, TextDirection dir) {
    if (_heightAt(typeSize, width, scaler, dir) <= height) return typeSize;
    if (_heightAt(_kMinPassageSize, width, scaler, dir) > height) {
      // Even the floor does not fit — a very long selection in a very
      // short box. Draw it at the floor and let `scaleDown` above take
      // the rest; below this size the words stop being words.
      return _kMinPassageSize;
    }
    var lo = _kMinPassageSize;
    var hi = typeSize;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      if (_heightAt(mid, width, scaler, dir) <= height) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// What the passage measures at [size], across [width].
  ///
  /// Measured from the SAME pieces the column is built from, so the fit
  /// can never be solved against a block that differs from the one
  /// drawn.
  double _heightAt(
      double size, double width, TextScaler scaler, TextDirection dir) {
    var total = 0.0;
    for (final piece in _pieces(size)) {
      final span = piece.span;
      if (span == null) {
        total += piece.gap;
        continue;
      }
      final painter = TextPainter(
        text: span,
        textAlign: _textAlign,
        textDirection: dir,
        textScaler: scaler,
      )..layout(maxWidth: width);
      total += painter.height;
      painter.dispose();
    }
    return total;
  }

  /// The floor the solver will not go below. Below this the passage is
  /// no longer being read by a room, and shrinking further only makes
  /// the failure quieter.
  static const double _kMinPassageSize = 10.0;

  /// The breathing room between the passage and a corner reference, as
  /// a share of the vertical margin.
  static const double _kReferenceGapShare = 0.5;

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

  Widget _passage(double size) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final piece in _pieces(size))
            if (piece.span == null)
              SizedBox(height: piece.gap)
            else
              piece.toWidget(_textAlign),
        ],
      );

  /// The block, as an ordered list of spans and the gaps between them.
  ///
  /// 2026-09-15. This list exists because the block has to be MEASURED
  /// before it is drawn, and a measurement of a different block than
  /// the one drawn is worse than no measurement at all. Everything the
  /// column puts on the wall comes from here, and so does every number
  /// the solver adds up.
  List<_StagePiece> _pieces(double size) => [
        ..._firstSpans(size),
        if (secondOn) ...[
          _StagePiece.gap(size * _kBlockGapShare),
          ..._secondSpans(size * kProjectionSecondScale),
        ],
        // Under the passage, INSIDE the block the solver sizes — so on
        // a long reading the address comes down with the words it
        // belongs to instead of sitting at full size beneath type that
        // has been wound down to fit.
        if (layout.reference == ProjectionReferencePlace.under &&
            verses.isNotEmpty) ...[
          _StagePiece.gap(size * _kReferenceUnderGapShare),
          _StagePiece(_referenceSpan(_referenceSizeFor(size))),
        ],
      ];

  /// The gap between the passage and a reference set beneath it. Wider
  /// than a line and narrower than the gap between editions: it belongs
  /// to the passage, and it is not part of it.
  static const double _kReferenceUnderGapShare = 0.5;

  /// The first edition — one block per verse, or the whole passage run
  /// together as the printed page has it.
  List<_StagePiece> _firstSpans(double size) {
    if (layout.flow == ProjectionFlow.continuous) {
      return [
        _StagePiece(_runTogetherSpan(
            [for (final v in verses) sanitizeForProjection(v.text)],
            size,
            scheme.onSurface)),
      ];
    }
    return [
      for (var i = 0; i < verses.length; i++)
        _StagePiece(_lineSpan(sanitizeForProjection(verses[i].text),
            verses[i].verseLabel, size, scheme.onSurface)),
    ];
  }

  /// The verses as one paragraph. Numbers, when they are on, sit inline
  /// in front of each verse exactly as a printed Bible sets them —
  /// which is the only way a run-together passage can carry them at all.
  TextSpan _runTogetherSpan(List<String> texts, double size, Color ink) {
    final numbered = layout.numbers && verses.length > 1;
    return TextSpan(
      style: TextStyle(
        color: ink,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: size,
        height: _kLineHeight,
      ),
      children: [
        for (var i = 0; i < texts.length; i++) ...[
          // The separator goes BEFORE the number, not before the text.
          // Put it after and the number closes up against the previous
          // sentence, which no printed Bible does.
          if (i > 0) const TextSpan(text: ' '),
          if (numbered)
            TextSpan(
              text: '${verses[i].verseLabel} ',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: size * kProjectionReferenceScale * 1.6,
              ),
            ),
          TextSpan(text: texts[i]),
        ],
      ],
    );
  }

  /// Centred, or aligned to where the line starts. `TextAlign.start`
  /// rather than `left` — a Hebrew passage starts on the right, and the
  /// setting is about the measure, not about a side of the screen.
  TextAlign get _textAlign => layout.align == ProjectionAlign.start
      ? TextAlign.start
      : TextAlign.center;

  /// One verse of the wall. With more than one verse up, each carries
  /// its number in the margin colour — small, because the room reads
  /// the words and the number is only there so a listener can find
  /// their place in a printed Bible. A single verse carries none; the
  /// reference below already names it.
  TextSpan _lineSpan(String text, String label, double size, Color ink) {
    final numbered = layout.numbers && verses.length > 1;
    return TextSpan(
      style: TextStyle(
        color: ink,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: size,
        height: _kLineHeight,
      ),
      children: [
        if (numbered)
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: size * kProjectionReferenceScale * 1.6,
            ),
          ),
        TextSpan(text: text),
      ],
    );
  }

  /// The second edition, verse for verse under the first — or one line
  /// of apparatus when it has nothing to show, in the apparatus colour
  /// so it cannot be mistaken for scripture.
  List<_StagePiece> _secondSpans(double size) {
    final texts = secondTexts;
    if (secondLoading || texts == null || texts.every((t) => t == null)) {
      return [
        _StagePiece(TextSpan(
          text: _secondBody(null),
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontFamilyFallback: kCjkFontFallback,
            fontSize: size,
            height: _kLineHeight,
          ),
        )),
      ];
    }
    if (layout.flow == ProjectionFlow.continuous) {
      // One paragraph, like the first edition above it. A verse the
      // companion lacks still takes its place in the line — dropping it
      // silently would put two different passages on the wall.
      return [
        _StagePiece(_runTogetherSpan(
            [for (final t in texts) _secondBody(t)],
            size,
            texts.every((t) => t != null)
                ? scheme.onSurface
                : scheme.onSurfaceVariant)),
      ];
    }
    return [
      for (var i = 0; i < verses.length; i++)
        _StagePiece(_lineSpan(
            _secondBody(texts[i]), verses[i].verseLabel, size,
            texts[i] == null ? scheme.onSurfaceVariant : scheme.onSurface)),
    ];
  }

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

  String _secondBody(String? text) {
    if (secondLoading) {
      return _s('projectionSecondVersionLoading',
          'Loading the second edition', locale);
    }
    if (text == null) {
      return _s('projectionSecondVersionMissing',
          'This edition has no text here', locale);
    }
    // The companion edition carries the same markup the first one does,
    // and the same rule applies to it: the room reads scripture, not
    // the apparatus the file stores it with.
    return sanitizeForProjection(text);
  }

  /// The reference, and the edition or editions it belongs to.
  ///
  /// The edition tags are part of the reference and not a separate badge
  /// because the room's question is ONE question — *where is this, and
  /// in what?* — and because a second edition on the wall with no way to
  /// tell which translation is which is worse than one edition.
  Widget _reference() {
    if (verses.isEmpty) return const SizedBox.shrink();
    // The corner reference is chrome, not part of the block: it keeps
    // the size the operator's choice gives it however far the passage
    // has had to come down. Its job — letting a listener find the place
    // in their own Bible — does not get smaller because the verse did.
    return _StagePiece(_referenceSpan(_referenceSize))
        .toWidget(TextAlign.start);
  }

  /// The reference itself, wherever it is being put. One builder, so
  /// the corner and the devotional placement can never start naming
  /// different editions.
  TextSpan _referenceSpan(double size) {
    final tags = <String>[
      shortBibleVersionLabel(versionCode),
      if (secondOn && secondCode != null) shortBibleVersionLabel(secondCode!),
    ];
    return TextSpan(
      text: '$reference · ${tags.join(" · ")}',
      style: TextStyle(
        color: scheme.onSurfaceVariant,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: size,
      ),
    );
  }

  /// The size of a reference set UNDER the passage, at a solved
  /// passage size.
  ///
  /// The ratio and the floor are the corner reference's rules. The
  /// third clause is this placement's own: a reference printed beneath
  /// scripture must never be set larger than the scripture, which the
  /// 26 px floor would otherwise do the moment a long reading pushes
  /// the passage below it.
  double _referenceSizeFor(double size) => math.min(
        math.max(size * kProjectionReferenceScale, kProjectionReferenceFloor),
        size,
      );
}

/// One row of the projected block: a span to draw, or a gap to leave.
///
/// Deliberately not two classes. The solver walks this list adding
/// heights, and a gap that is not in the same list as the spans is a
/// gap the solver forgets — which is exactly how a block that measured
/// as fitting ends up not fitting.
class _StagePiece {
  final TextSpan? span;
  final double gap;
  const _StagePiece(TextSpan this.span) : gap = 0;
  const _StagePiece.gap(this.gap) : span = null;

  /// The span as a widget, with its root style on the `Text` rather
  /// than inside the span.
  ///
  /// Measuring needs the style INSIDE the span — a `TextPainter` has
  /// nowhere else to take it from — while everything that reads the
  /// wall, tests included, asks a `Text` for `style.fontSize`. Splitting
  /// it here is the one place that difference has to be handled, and
  /// the two are the same style either way.
  Widget toWidget(TextAlign align) => Text.rich(
        TextSpan(text: span!.text, children: span!.children),
        style: span!.style,
        textAlign: align,
      );
}

/// `5:00`, `12:34`, `1:02:03` — minutes and seconds, hours only when
/// there are some. Never negative: a countdown that has run out reads
/// `0:00` until the operator takes it down, which is the state the
/// room is actually in.
String formatProjectionCountdown(Duration left) {
  final total = left.isNegative ? 0 : left.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final sec = total % 60;
  final two = sec.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$two';
  return '$m:$two';
}

/// `projectionStrings`, with English as the fallback locale before the
/// caller's own literal — the same `?[locale] ?? ?['en']` idiom every
/// `uiStrings` lookup in this repo uses.
String _s(String key, String fallback, String locale) =>
    projectionStrings[key]?[locale] ??
    projectionStrings[key]?['en'] ??
    fallback;
