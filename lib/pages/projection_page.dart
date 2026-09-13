/// 投影 — the passage on the wall at the front of the room.
///
/// It is not a reading surface. The person driving it is standing at a
/// laptop at the back of a hall with their hands on the arrow keys and
/// their eyes on the congregation, and the people it is FOR are forty
/// feet away and cannot touch it at all. Every decision below falls out
/// of that one sentence.
///
/// ## THE SECOND DISPLAY, AND WHY THIS VERSION IS ONE WINDOW
///
/// The obvious ask is "put the passage on the projector and keep the
/// controls on the laptop", and on the web the obvious answer is a
/// `window.open` popout. It was investigated and declined for this pass.
/// The reasoning matters because HALF of it is inherited and half of it
/// is not, and a future reader deserves to know which half:
///
///   * **The "syncing two windows is a subsystem" argument does NOT
///     hold here, and it should not be repeated as if it did.** That is
///     the argument the same feature was declined on elsewhere, on the
///     grounds that a message protocol, a join handshake and a cursor
///     owner all have to be invented. YsWords has already built both
///     halves of that, for another reason: `url_sync_service_web.dart`
///     serialises the ENTIRE reader position to one canonical string
///     (`#/<book>/<chapter>:<verse>?v=<version>`) on a ~150 ms debounce
///     at a single chokepoint, and `boot_uri.dart`'s captured boot hash
///     is an existing, load-bearing parse-and-apply path for that same
///     grammar. A follower window is "apply the boot hash on every
///     message instead of once". The channel itself is same-origin
///     `BroadcastChannel`, which needs no handle, no auth and no CORS,
///     and would follow the `_stub.dart` / `_web.dart` conditional-
///     import convention this repo already uses in six services. That
///     is a small service, not a subsystem.
///
///   * **The argument that DOES hold is the second engine, and it is
///     worse here than it is anywhere else.** A new browser window is a
///     new document, so it boots its own Flutter engine and its own Dart
///     isolate; nothing in this repo crosses that boundary — not
///     `MainProvider`, not `AppSettings`, not the LRU in
///     `MainProvider._versesCache`. `web/flutter_bootstrap.js` is a
///     deliberately minimal single-view bootstrap whose own comment says
///     it is frozen against changes to Flutter's default, and
///     `multiViewEnabled` appears nowhere. So the popout re-parses 10.3
///     MB of `main.dart.js`, re-initialises CanvasKit, and re-runs
///     `json.decode` over the bundled corpora on the main thread. The
///     measurements are already recorded in `app_version.dart`: a ~4–5 s
///     splash, and ~25–30 s to a fully warm set of versions. The
///     congregation would watch a splash screen.
///
///   * **The browser APIs that sound relevant are not.** The
///     Presentation API addresses a casting receiver, not an attached
///     monitor. Chrome's Window Management API (`getScreenDetails`) can
///     place a window on a chosen screen — the easy half — and does
///     nothing about state, the hard half. Neither appears in this
///     repo.
///
///   * **And the cheap channel is not this page's to build.** Every
///     piece named above lives in `url_sync_service_web.dart`, the boot
///     path and `flutter_bootstrap.js`. A page that reaches into all
///     three is not a page.
///
/// So: **this version is single-window, deliberately, and the door is
/// left open on the record.** The operator drags the YsWords window onto
/// the projector's display and drives it from the laptop keyboard.
/// Keyboard focus stays with that window wherever the window is, so
/// every key below works with the operator looking at the room instead
/// of at the screen. That is why the keyboard is the mechanism here and
/// not a convenience, why the reference sits in a corner instead of in a
/// header the operator would have to lean in to read, and why the blank
/// key exists at all. `projectionOneWindowNote` says this to the
/// operator in one line, because a design decision nobody is told about
/// reads as a missing feature.
///
/// ## THE TYPE SCALE IS THE ROOM'S, NOT THE READER'S
///
/// [kProjectionTypeSteps] is a separate ladder and does not consult
/// `AppSettings.fontSize` at any point. Those are answers to two
/// different questions — "how big do I like my text on this laptop" and
/// "how far away is the back row" — and a reader who studies at 14 pt
/// does not want a 17 px verse on the wall.
///
/// The floor of 40 is not arbitrary, and it is not the floor the same
/// ladder uses in other apps. The reading control in this app clamps to
/// 32 at the top (`settings_page.dart`'s slider is `min: 12, max: 32`,
/// and `bible_reading_pane.dart`'s two stepper buttons both
/// `.clamp(12, 32)`), so the smallest projection size is still a quarter
/// larger than the biggest size the reading setting can produce. The two
/// scales do not merely differ, they DO NOT OVERLAP, which is the whole
/// point of there being two — and `projection_cursor_test.dart` pins
/// that as an arithmetic property so a future widening of the reading
/// slider fails a test instead of silently colliding.
///
/// The chosen step is a CEILING, not a fixed size — see
/// `projection_stage.dart`. A long verse shrinks to fit the wall rather
/// than running off it; clipping a verse in front of a congregation is
/// not a degradation, it is a wrong text.
///
/// ## THE SETUP PERSISTS; THE MOMENT DOES NOT
///
/// 2026-09-09, from the owner: 「projector setting怎么没做好背景也不能set
/// 或者preset两个经文也不能调整这个功能要完整」. Every knob on this page
/// used to be a plain `State` field. The operator who set the hall up on
/// Sunday morning set it up again from scratch the following Sunday
/// morning, from the back of the hall, while people were arriving. For a
/// tool whose entire audience drives it weekly, that is not a missing
/// convenience, it is the feature not being finished, and the owner said
/// so in those words.
///
/// Four things now live in `AppSettings` under their own new keys — the
/// type step, whether the second edition is on, WHICH second edition,
/// and the ground — plus a list of named presets under one more. The
/// keys are all new; none of them reuses a key another feature writes,
/// which is a rule this page had already broken once (see
/// [kSplitSecondaryVersionKey]).
///
/// **`blank` is the one thing that does not persist, and that is a
/// decision rather than an oversight.** An operator who blanked the wall
/// and closed the page does not want to reopen onto a blank wall. They
/// blanked it because something else was happening in the room; that
/// moment is over, and the room is not looking at a stale blank. Every
/// other setting on this page answers a question about the ROOM, which
/// is still true next week. Blanking answers a question about the next
/// ninety seconds. The failure mode of getting this backwards is a
/// service that starts on a black wall with nobody knowing why, which is
/// exactly the class of thing this page exists to prevent.
///
/// ## THE SECOND EDITION IS THE PROJECTOR'S OWN, AFTER ONE LOOK NEXT DOOR
///
/// It used to be split view's, read live from `secondary_version` on
/// every load. That was defensible when the alternative was inventing a
/// rule out of nothing, and it was still wrong in the way an invisible
/// coupling is always wrong: the projection had no picker, so an
/// operator who wanted a different second edition on the wall had to
/// discover that the control was in another feature, on another page,
/// and that changing it there would change the wall. Nothing in the
/// interface said so. The owner's 「两个经文也不能调整」 is that sentence
/// from the outside.
///
/// So the projector keeps its own choice now, and the borrow survives as
/// exactly what it was worth: a SEED. The first time this page needs a
/// second edition it takes split view's answer, resolves it, writes it
/// down as its own, and never looks again. An operator who already had a
/// second column sees the edition they expect on the first run and can
/// then move one without moving the other — which is the whole point,
/// because the two answer different questions. Split view is "what do I
/// want beside my reading"; the wall is "what does this congregation
/// read in".
///
/// ## WHAT THIS DELIBERATELY IS NOT
///
/// Not a slide editor, not a song module, and it stores no presentation
/// state.
///
/// **Hymns were considered and declined for this pass, on the data.**
/// The app carries 628 songs, which is the thing that could have made a
/// lyric slide worth more here than a verse slide. It does not, yet:
/// only 218 of the 628 carry any `lyrics` at all (`assets/songs.json`'s
/// own `_meta.withLyrics`), and `Song.lyrics` is a flat `String?` — the
/// model has no stanza, chorus or repeat type anywhere in its 26 fields.
/// Of those 218, only 45 have blank-line stanza breaks and only 6 carry
/// bracketed section tags; a chorus is an unstructured inline `副歌`
/// line in 113 of them. Worst for a projector specifically, 152 of the
/// 218 have collapsed two-column page layout baked into the text — two
/// sung lines fused onto one string by runs of non-breaking spaces —
/// so projecting the field verbatim would show doubled lines. The
/// remaining 383 songs have only a PDF score (`SongScorePage` renders
/// `pdfrx`, not text), which is not text this page could set at all.
/// Lyric projection is therefore a parsing project over dirty scraped
/// text plus a second navigation model (by stanza, not by verse), and
/// it deserves its own design rather than a corner of this one.
///
/// It is a live view over the passage the reader is already on: it takes
/// its starting reference from `MainProvider` when it opens and gives
/// nothing back when it closes. That is what makes "leaving puts the
/// reader back exactly where they were" a behaviour rather than a hope,
/// and `projection_page_test.dart` asserts it. The operator advancing
/// forty verses on the wall has not moved anybody's study.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/bible_versions.dart'
    show
        availableVersions,
        bibleVersionLanguage,
        fullBibleVersionLabel,
        resolvableVersion,
        shortBibleVersionLabel;
import 'package:yswords/constants/book_names.dart' show bookNameToEnglish;
import 'package:yswords/constants/motion.dart';
import 'package:yswords/constants/projection_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/projection_agenda.dart';
import 'package:yswords/services/projection_broadcast.dart';
import 'package:yswords/models/projection_preset.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/widgets/overflow_hint_scroll.dart';
import 'package:yswords/widgets/projection_stage.dart';

/// The path this page is registered under — see `route_paths.dart`'s
/// `kRegisteredRoutePaths`, `main.dart`'s `_registeredGetPages` and the
/// §3 table in `docs/url-routing-plan.md`, all three of which
/// `url_routing_stage3_sync_test.dart` holds to each other.
///
/// Being addressable is not decoration here, it is currently the ONLY
/// door: the reading pane's own overflow menu is where an "开始投影"
/// item belongs, and that file is owned elsewhere. Until that item
/// exists the operator reaches the projection by typing the path, which
/// is a perfectly good thing for an operator with a laptop at the back
/// of a hall to do, and a bookmarkable one.
const String kProjectionUrlPath = '/project';

/// The SharedPreferences key the split-view secondary pane keeps its
/// chosen edition under.
///
/// **This was the reuse, and as of 2026-09-09 it is only the SEED.**
/// The app already answers "what is the other edition beside the one I
/// am reading", and it answers it in split view: `home_page.dart`'s
/// `_activateSplitView` builds a second
/// `MainProvider(storagePrefix: 'secondary_')`, and that provider
/// persists its edition through `MainProvider._saveState`'s
/// `prefs.setString('${_storagePrefix}version', currentVersion)` and
/// reads it back in `restoreState`. So the operator's own second column
/// — whichever edition they last put beside their reading — is a far
/// better first guess than any rule this page could invent out of
/// nothing, and it is still what a first-time operator gets on the wall.
///
/// What changed is that the projection stops READING it after that. The
/// old arrangement followed this key forever, which made "change the
/// second edition on the wall" an action you performed in a different
/// feature on a different page, with nothing anywhere saying so. See the
/// library doc's section on it. The page now copies the value once into
/// its own `AppSettings.projectionSecondVersion` and answers to that.
/// This key is never WRITTEN by this page, under either arrangement.
///
/// Spelled as a literal because `_storagePrefix` is private to
/// `MainProvider`, which makes this a hand-kept cross-file fact of
/// exactly the kind this repo pins with a source-reading test rather
/// than trusts — `projection_page_test.dart` reads
/// `main_provider.dart` and fails if the key stops being written there.
/// That test earns its keep more now, not less: a seed taken from a key
/// nobody writes any more does not fail loudly, it quietly turns every
/// new operator's second edition into the language fallback.
const String kSplitSecondaryVersionKey = 'secondary_version';

/// The sizes the operator steps through, in logical pixels.
///
/// A ladder rather than a slider: an operator adjusting this is doing it
/// mid-service with a room watching, and "press the key twice more" is a
/// thing you can do without looking.
///
/// The steps are a roughly constant RATIO (1.14–1.20, mean 1.16) rather
/// than a constant increment, because that is what a press being "the
/// same amount bigger" means to an eye. A fixed +8 would run 40→48, a
/// fifth larger and unmistakable, and 176→184, a twentieth and
/// invisible — the same key doing two different jobs at the two ends of
/// its own range.
///
/// On why the floor is 40 and not lower, see the library doc: the
/// reading control tops out at 32, and these two scales are required not
/// to overlap.
const List<double> kProjectionTypeSteps = <double>[
  40,
  48,
  56,
  64,
  76,
  88,
  104,
  120,
  140,
  160,
  184,
];

/// Where a freshly-opened projection starts on [kProjectionTypeSteps].
///
/// Index 4 (76 px), near the middle of the ladder, so the first
/// adjustment the operator makes has room to go either way. Starting at
/// the bottom would make "bigger" the only useful key and cost a press
/// or four every time.
const int kProjectionTypeDefaultStep = 4;

/// How long the on-screen controls linger after the pointer stops.
///
/// The chrome is meant to be gone, and the operator still needs buttons
/// on a tablet where there is no keyboard at all. Both are satisfied by
/// controls that answer the pointer and then get out of the way. Four
/// seconds is long enough to move from one button to the next and short
/// enough that a bar left on the wall is measured in seconds.
/// The countdown lengths offered, in minutes.
///
/// A short list rather than a picker: the operator is choosing before a
/// service, not scheduling, and five values cover what a church
/// actually counts down — the last song, the last few minutes, and the
/// quarter hour a hall takes to fill.
const List<int> kProjectionCountdownMinutes = <int>[1, 3, 5, 10, 15];

const Duration kProjectionControlsLinger = Duration(seconds: 4);

/// One thing the operator can ask the projection to do.
///
/// An enum rather than a set of callbacks so [projectionCommandFor] can
/// be tested without a widget, and so the on-screen buttons and the
/// keyboard dispatch through ONE switch instead of two.
enum ProjectionCommand {
  nextVerse,
  previousVerse,
  nextChapter,
  previousChapter,

  /// Kill the wall without leaving the view.
  blank,

  biggerType,
  smallerType,

  /// Add or drop the second edition.
  toggleSecondVersion,

  /// Step to the next dark ground.
  ///
  /// A ring rather than a picker for the KEY, because the picker is a
  /// dialog and a dialog is a thing the congregation can see and the
  /// operator has to aim at. Four grounds is few enough that pressing
  /// past the one you wanted costs three presses to get back.
  cycleGround,

  /// Ask which edition the second block should be.
  chooseSecondVersion,

  /// Open the saved setups.
  presets,

  /// Start, extend or take down the countdown before the service.
  countdown,

  /// Open (or close) the order of service.
  agenda,

  /// Put the NEXT agenda item on the wall.
  agendaNext,

  /// Put the PREVIOUS agenda item on the wall.
  agendaPrevious,

  /// Open the follower window — `web/stage.html` on a BroadcastChannel.
  /// Web only; the button and the key are absent elsewhere. See
  /// `projection_broadcast.dart`.
  openStage,

  /// Leave, and put the operator back where they were.
  leave,
}

/// The command [key] means, or null when the projection does not answer
/// that key.
///
/// The bindings are the ones a person who has driven ANY presentation
/// tool already has in their fingers — space and the arrows advance,
/// PageUp/PageDown are the wireless clicker's two buttons, `B` blanks
/// (Keynote, PowerPoint and ProPresenter all use it), Esc leaves. Making
/// a room-facing tool invent its own is how an operator ends up reading
/// a cheatsheet during the sermon.
///
/// Deliberately UNMODIFIED keys only. Taking no Ctrl/Cmd chord at all is
/// the simplest way to be sure this handler never fights the browser it
/// is running in — the operator's Cmd+R has to keep working.
///
/// Up and Down are verse keys rather than chapter keys because a
/// clicker's two buttons already are the chapter keys, and because the
/// arrows are what a hand finds without looking: all four should move
/// the same unit, in the direction they point.
ProjectionCommand? projectionCommandFor(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    return ProjectionCommand.nextVerse;
  }
  if (key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.backspace) {
    return ProjectionCommand.previousVerse;
  }
  if (key == LogicalKeyboardKey.pageDown) {
    return ProjectionCommand.nextChapter;
  }
  if (key == LogicalKeyboardKey.pageUp) {
    return ProjectionCommand.previousChapter;
  }
  if (key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.period) {
    return ProjectionCommand.blank;
  }
  // Both faces of the two keys, because a keyboard prints `+` on the key
  // the operator presses and reports `=` unless they are holding Shift,
  // and a numeric keypad reports neither.
  if (key == LogicalKeyboardKey.equal ||
      key == LogicalKeyboardKey.add ||
      key == LogicalKeyboardKey.numpadAdd) {
    return ProjectionCommand.biggerType;
  }
  if (key == LogicalKeyboardKey.minus ||
      key == LogicalKeyboardKey.numpadSubtract) {
    return ProjectionCommand.smallerType;
  }
  if (key == LogicalKeyboardKey.keyP) {
    return ProjectionCommand.toggleSecondVersion;
  }
  // The three setup keys, added 2026-09-09 with the settings they
  // reach. Initials of what they do in English, because that is the
  // only mnemonic that survives an operator who uses this once a week:
  // G for the ground, V for the version beside it, S for the saved
  // setups. All three are unmodified letters like `B` and `P` above,
  // and none of them is a letter any presentation tool binds to
  // something else — so nothing a projectionist already has in their
  // fingers now does the wrong thing.
  if (key == LogicalKeyboardKey.keyG) {
    return ProjectionCommand.cycleGround;
  }
  if (key == LogicalKeyboardKey.keyV) {
    return ProjectionCommand.chooseSecondVersion;
  }
  // C for countdown. Bare, so it never fights Cmd+C — which
  // kBrowserOwnedChords names, and which the modifier guard in _onKey
  // already lets through.
  if (key == LogicalKeyboardKey.keyC) {
    return ProjectionCommand.countdown;
  }
  // The order of service: A opens it, and the two brackets step it —
  // the same pair a presentation tool uses for "previous / next slide"
  // and neither of them a browser chord.
  if (key == LogicalKeyboardKey.keyA) {
    return ProjectionCommand.agenda;
  }
  if (key == LogicalKeyboardKey.bracketRight) {
    return ProjectionCommand.agendaNext;
  }
  if (key == LogicalKeyboardKey.bracketLeft) {
    return ProjectionCommand.agendaPrevious;
  }
  // D for display. Not a browser chord (those are C V X F P S T W N L K
  // R); a bare letter the operator can hit once, at the start, to put
  // the wall up on the second screen.
  if (key == LogicalKeyboardKey.keyD) {
    return ProjectionCommand.openStage;
  }
  if (key == LogicalKeyboardKey.keyS) {
    return ProjectionCommand.presets;
  }
  if (key == LogicalKeyboardKey.escape) {
    return ProjectionCommand.leave;
  }
  return null;
}

/// Where the projection is pointing: a chapter, by its index in
/// `MainProvider.chapterList`, and a verse by its index within that
/// chapter.
///
/// Indices rather than a `(book, chapter, verse)` triple because the
/// question the movement keys ask is "what comes next", and only the
/// corpus's own order can answer it — Malachi is followed by Matthew and
/// no arithmetic on a chapter number knows that.
@immutable
class ProjectionCursor {
  const ProjectionCursor(this.chapter, this.verse, {this.count = 1})
      : assert(count >= 1);

  final int chapter;
  final int verse;

  /// How many verses, from [verse], are on the wall at once. One for
  /// everything the keys do; more when the projection was opened from a
  /// selection in the reader — 「可以按一个或者多个 然后就project」. A
  /// key press then moves on from the END of the block as a single
  /// verse: the selection was what the operator wanted shown, and what
  /// follows it is ordinary reading.
  final int count;

  /// The last verse of the block — where "next" continues from.
  ProjectionCursor get tail => ProjectionCursor(chapter, verse + count - 1);

  @override
  bool operator ==(Object other) =>
      other is ProjectionCursor &&
      other.chapter == chapter &&
      other.verse == verse &&
      other.count == count;

  @override
  int get hashCode => Object.hash(chapter, verse, count);

  @override
  String toString() => 'ProjectionCursor($chapter, $verse, count: $count)';
}

/// Where a projection opened from a SELECTION starts: the first selected
/// verse, and as many verses after it as are selected contiguously in
/// the same chapter. Verses in other chapters, or after a gap, are not
/// lost — they are simply where the next key press goes, one at a time.
///
/// Pure, so the tests can drive it without a corpus. [chapterIndexOf]
/// and [verseIndexOf] are the two lookups the page has and a test can
/// fake.
ProjectionCursor? projectionCursorFromSelection(
  List<Verse> selected, {
  required int? Function(String book, int chapter) chapterIndexOf,
  required int Function(int chapterIndex, Verse verse) verseIndexOf,
}) {
  if (selected.isEmpty) return null;
  final sorted = [...selected]..sort((a, b) {
      if (a.book != b.book) return 0;
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verse.compareTo(b.verse);
    });
  final first = sorted.first;
  final chapter = chapterIndexOf(first.book, first.chapter);
  if (chapter == null) return null;
  final start = verseIndexOf(chapter, first);
  if (start < 0) return null;
  var count = 1;
  for (var i = 1; i < sorted.length; i++) {
    final v = sorted[i];
    if (v.book != first.book || v.chapter != first.chapter) break;
    if (v.verse != sorted[i - 1].verse + 1) break;
    count++;
  }
  return ProjectionCursor(chapter, start, count: count);
}

/// The cursor one verse either side of [from], rolling over the chapter
/// boundary.
///
/// [delta] is +1 or -1. [versesIn] answers how many verses a chapter
/// index holds; it is a callback rather than a list so a caller with
/// 1,189 chapters pays for the two it actually asks about, and so a test
/// can describe a three-chapter corpus in one line.
///
/// Returns [from] unchanged at either end of the corpus. Refusing to
/// move is the right answer to "next verse" at Revelation 22:21 — the
/// alternative is wrapping round to Genesis 1:1 in front of a
/// congregation, which looks like a crash.
///
/// Empty chapters are stepped OVER rather than landed on. This is not
/// hypothetical in YsWords: several bundled editions ship one Testament
/// only (the LJK2 editions are New Testament, because the translator's
/// Old Testament work is not published), so a corpus whose chapter list
/// runs ahead of its verse data is the normal case here, not a defect. A
/// cursor resting on a chapter with no verse to draw is a blank wall the
/// operator cannot get off by pressing the same key again.
ProjectionCursor projectionVerseStep(
  ProjectionCursor from,
  int delta, {
  required int chapterCount,
  required int Function(int chapterIndex) versesIn,
}) {
  assert(delta == 1 || delta == -1, 'a verse key moves exactly one verse');
  final next = from.verse + delta;
  if (next >= 0 && next < versesIn(from.chapter)) {
    return ProjectionCursor(from.chapter, next);
  }
  var chapter = from.chapter + delta;
  while (chapter >= 0 && chapter < chapterCount) {
    final count = versesIn(chapter);
    if (count > 0) {
      return ProjectionCursor(chapter, delta > 0 ? 0 : count - 1);
    }
    chapter += delta;
  }
  return from;
}

/// The head of the chapter [delta] away from [from].
///
/// Both directions land on the chapter's FIRST verse, including
/// backwards. "Previous chapter" from Genesis 2:14 means Genesis 1:1 and
/// not Genesis 1:31: the operator is moving to a passage, and a passage
/// starts at the top. (Pressing the verse key backwards from Genesis 2:1
/// still lands on Genesis 1:31, which is the other question, asked with
/// the other key.)
ProjectionCursor projectionChapterStep(
  ProjectionCursor from,
  int delta, {
  required int chapterCount,
  required int Function(int chapterIndex) versesIn,
}) {
  assert(delta == 1 || delta == -1, 'a chapter key moves exactly one chapter');
  var chapter = from.chapter + delta;
  while (chapter >= 0 && chapter < chapterCount) {
    if (versesIn(chapter) > 0) return ProjectionCursor(chapter, 0);
    chapter += delta;
  }
  return from;
}

/// The step index [current] moves to for [delta], clamped to the ladder.
int projectionTypeStep(int current, int delta) =>
    (current + delta).clamp(0, kProjectionTypeSteps.length - 1);

/// The edition the second block shows when the operator has never opened
/// split view, and therefore has no stored second column to inherit.
///
/// The first available edition in a DIFFERENT language family from
/// [primaryVersion], by `bibleVersionLanguage`. A bilingual congregation
/// is exactly this page's audience, so the useful default beside a
/// Chinese reading is an English one and vice versa; two Chinese
/// editions differing by a few characters is a comparison for a desk,
/// not a wall. Falls back to [primaryVersion] itself when there is no
/// other family available, which the caller reads as "nothing to add".
String projectionFallbackSecondVersion(String primaryVersion) {
  final primaryLanguage = bibleVersionLanguage(primaryVersion);
  for (final v in availableVersions) {
    if (bibleVersionLanguage(v.value) != primaryLanguage) return v.value;
  }
  return primaryVersion;
}

/// The edition the second block will actually show, given whatever is
/// [stored] for it and the [primaryVersion] on the wall above it.
///
/// The single rule, in one place, because there are now three callers
/// that must agree: the loader, the picker, and applying a preset. A
/// preset saved on a phone that ships the LEB and recalled on a web
/// build that strips it has to land somewhere, and "wherever a stale
/// preference lands" is the answer that was already correct — the
/// alternative is an empty wall in front of a congregation, which is
/// how `resolvableVersion` came to exist in the first place (see its
/// own doc: hiding an edition from a picker was never enough).
///
/// Three cases collapse into one expression:
///
///   * nothing stored — a first-time operator, or a preset that carried
///     no second edition;
///   * the same edition as the one being read, which would put the same
///     words on the wall twice;
///   * an edition this build cannot load.
///
/// The first two go to [projectionFallbackSecondVersion], which picks a
/// different language family. The third is `resolvableVersion`'s job,
/// and it runs over the result of the first two as well so a fallback
/// that is itself unavailable cannot slip through.
String projectionSecondVersionFrom(String? stored, String primaryVersion) =>
    resolvableVersion(
      stored == null || stored.isEmpty || stored == primaryVersion
          ? projectionFallbackSecondVersion(primaryVersion)
          : stored,
    );


/// The language family of an edition code, for the companion pairing —
/// `zh-Hans` for anything the catalogue does not know, the same fallback
/// the picker uses, so the wall never asks for a companion of nothing.
String projectionLanguageOf(String code) => bibleVersionLanguage(code);

/// The edition the second block should be showing for [primary]: the
/// companion the operator set in Settings for the passage's language,
/// else the last edition chosen on this page, else nothing (the caller
/// falls back to the seed and the language default).
String? projectionCompanionPick(AppSettings settings, String primary) {
  final byLanguage =
      settings.projectionCompanionFor(projectionLanguageOf(primary));
  if (byLanguage != null && byLanguage.isNotEmpty) return byLanguage;
  final last = settings.projectionSecondVersion;
  return last.isEmpty ? null : last;
}

class ProjectionPage extends StatefulWidget {
  const ProjectionPage({super.key, this.verses});

  /// Verses to open ON, from the reader's selection bar. Null or empty
  /// means the reader's current position, as before. See
  /// [projectionCursorFromSelection] for what a multi-verse selection
  /// becomes.
  final List<Verse>? verses;

  @override
  State<ProjectionPage> createState() => _ProjectionPageState();
}

class _ProjectionPageState extends State<ProjectionPage> {
  final FocusNode _focus = FocusNode(debugLabel: 'projection');

  /// Where the operator has driven the projection to, or null while it
  /// is still sitting on the reference the reader was already at.
  ///
  /// Null is a real state and the reason the reader's own position is
  /// never written back: until the first key is pressed the projection
  /// simply RENDERS `MainProvider`'s reference, and after it there is a
  /// cursor of its own that nothing else reads. Neither branch touches
  /// the reader, which is what makes leaving a no-op.
  ProjectionCursor? _cursor;

  /// The curtain. **The one piece of operator state that is not
  /// persisted** — see the library doc's section on it. A field here and
  /// not in `AppSettings` is the whole implementation of that decision,
  /// so it is worth saying at the field: reopening onto a wall the
  /// operator blanked last Sunday is the failure this prevents.
  bool _blank = false;

  bool _controlsVisible = true;
  Timer? _controlsTimer;

  /// The second edition's code once resolved, and its text indexed as
  /// `'<English book>|<chapter>'` → verse number → text.
  ///
  /// Indexed at load rather than scanned at paint: the raw list is
  /// ~31,000 verses and the alternative is a linear scan of a whole
  /// Bible on every frame the wall draws.
  String? _secondCode;
  Map<String, Map<int, String>>? _secondIndex;
  bool _secondLoading = false;

  /// Monotonic id of the newest second-edition load. A load that
  /// resumes after its awaits and finds a newer id has been superseded —
  /// the operator changed the edition while it was fetching — and must
  /// commit nothing. See [_loadSecond].
  int _secondRequest = 0;

  // ── the persisted setup, read back ────────────────────────────────
  //
  // Getters rather than fields: `AppSettings` is the storage AND the
  // live value, and `build` already watches it, so a copy on this State
  // would be a second source of truth that has to be kept in step. The
  // page reads through, and writes through.

  /// `context.read`, not `watch` — every caller below is inside `build`
  /// (which watches already) or inside a handler, where a subscription
  /// would be meaningless.
  AppSettings get _settings => context.read<AppSettings>();

  /// The step in force, clamped to the ladder HERE rather than on the
  /// way to disk. A stored index from a longer ladder resolves to the
  /// biggest step this build has instead of throwing on a wall.
  int get _typeStep =>
      _settings.projectionTypeStep.clamp(0, kProjectionTypeSteps.length - 1);

  bool get _second => _settings.projectionSecondOn;

  ProjectionGround get _ground =>
      projectionGroundFromName(_settings.projectionGround);

  @override
  void initState() {
    super.initState();
    _restartControlsTimer();
    // A persisted "second edition on" has a corpus to fetch before the
    // wall can honour it. After the first frame, not during initState:
    // `_loadSecond` calls `setState`, and the load is a file read the
    // first frame should not wait on — the passage itself is already on
    // the wall and the second block says it is loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_settings.projectionSecondOn) return;
      _loadSecond(context.read<MainProvider>());
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _countdownTicker?.cancel();
    ProjectionBroadcast.close();
    _focus.dispose();
    super.dispose();
  }

  // ── the cursor ────────────────────────────────────────────────────

  /// The reference the reader is on, as a cursor, or null when the
  /// corpus has not finished loading.
  ///
  /// Recomputed on every build while [_cursor] is null, which is exactly
  /// the window in which it can change: a cold load straight onto
  /// `/project` genuinely has no corpus for the first frames, and the
  /// reference arrives later.
  ProjectionCursor? _readerCursor(MainProvider mp) {
    final selected = widget.verses;
    if (selected != null && selected.isNotEmpty) {
      final seeded = projectionCursorFromSelection(
        selected,
        chapterIndexOf: (book, chapter) => mp.findChapterIndex(book, chapter),
        verseIndexOf: (chapterIndex, v) => _versesAt(mp, chapterIndex)
            .indexWhere((x) => x.verse == v.verse),
      );
      if (seeded != null) return seeded;
    }
    final chapter = mp.findChapterIndex(mp.currentBook, mp.currentChapter);
    if (chapter == null) return null;
    final verses = _versesAt(mp, chapter);
    if (verses.isEmpty) return null;
    final at = mp.currentVerse;
    // Book as well as chapter and verse: `currentVerse` can be left
    // behind in another book entirely, and `Genesis 3:16` matching
    // `John 3:16` by number would open the projection on a verse nobody
    // chose.
    final index = at == null
        ? 0
        : verses.indexWhere((v) =>
            v.book == at.book &&
            v.chapter == at.chapter &&
            v.verse == at.verse);
    return ProjectionCursor(chapter, index < 0 ? 0 : index);
  }

  List<Verse> _versesAt(MainProvider mp, int chapterIndex) {
    final list = mp.chapterList;
    if (chapterIndex < 0 || chapterIndex >= list.length) return const [];
    final at = list[chapterIndex];
    return mp.versesInChapter(at.book, at.chapter);
  }

  void _move(ProjectionCommand command, MainProvider mp) {
    final from = _cursor ?? _readerCursor(mp);
    if (from == null) return;
    final chapterCount = mp.chapterList.length;
    int versesIn(int i) => _versesAt(mp, i).length;
    final to = switch (command) {
      ProjectionCommand.nextVerse => projectionVerseStep(from.tail, 1,
          chapterCount: chapterCount, versesIn: versesIn),
      ProjectionCommand.previousVerse => projectionVerseStep(from, -1,
          chapterCount: chapterCount, versesIn: versesIn),
      ProjectionCommand.nextChapter => projectionChapterStep(from, 1,
          chapterCount: chapterCount, versesIn: versesIn),
      ProjectionCommand.previousChapter => projectionChapterStep(from, -1,
          chapterCount: chapterCount, versesIn: versesIn),
      _ => from,
    };
    setState(() => _cursor = to);
  }

  // ── the commands ──────────────────────────────────────────────────

  /// Carry out one command, from a key or from a button.
  ///
  /// One switch for both, so the bar and the keyboard cannot drift
  /// apart.
  ///
  /// Every command wakes the controls first. A key press is the operator
  /// saying they are here, and the bar they are about to want should
  /// already be on screen rather than one press behind.
  void _run(ProjectionCommand command, MainProvider mp) {
    _wakeControls();
    switch (command) {
      case ProjectionCommand.nextVerse:
      case ProjectionCommand.previousVerse:
      case ProjectionCommand.nextChapter:
      case ProjectionCommand.previousChapter:
        _move(command, mp);
      case ProjectionCommand.blank:
        setState(() => _blank = !_blank);
      // The four settings commands have no `setState` of their own: the
      // write goes to `AppSettings`, which notifies, and `build` watches
      // it. Calling both would rebuild twice for one press.
      case ProjectionCommand.biggerType:
        _settings.setProjectionTypeStep(projectionTypeStep(_typeStep, 1));
      case ProjectionCommand.smallerType:
        _settings.setProjectionTypeStep(projectionTypeStep(_typeStep, -1));
      case ProjectionCommand.toggleSecondVersion:
        _toggleSecondVersion(mp);
      case ProjectionCommand.cycleGround:
        _settings.setProjectionGround(projectionGroundAfter(_ground).name);
      case ProjectionCommand.chooseSecondVersion:
        _chooseSecondVersion(mp);
      case ProjectionCommand.presets:
        _showPresets(mp);
      case ProjectionCommand.countdown:
        _showCountdown();
      case ProjectionCommand.agenda:
        _showAgenda(mp);
      case ProjectionCommand.agendaNext:
        _stepAgenda(mp, 1);
      case ProjectionCommand.agendaPrevious:
        _stepAgenda(mp, -1);
      case ProjectionCommand.openStage:
        if (ProjectionBroadcast.isSupported) ProjectionBroadcast.openStage();
      case ProjectionCommand.leave:
        Navigator.of(context).maybePop();
    }
  }

  KeyEventResult _onKey(KeyEvent event, MainProvider mp) {
    // Key-up would fire a second time for every press, and a held key
    // legitimately repeats — an operator scrolling back through a psalm
    // holds the left arrow.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // A chord is never ours. The map below is of BARE keys, and the
    // page's own doc says so — "deliberately unmodified keys only" — but
    // the map cannot see a modifier, so `V` matched Cmd+V and `R`
    // matched Cmd+R, and because this handler answers `handled` (which
    // on the web is `preventDefault`) the operator lost paste and reload
    // to a picker. Shift is allowed through: nothing binds a shifted
    // letter today, and a range-extending Shift+arrow is the obvious
    // next binding.
    final hk = HardwareKeyboard.instance;
    if (hk.isMetaPressed || hk.isControlPressed || hk.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final command = projectionCommandFor(event.logicalKey);
    // Ignored, not handled: a key this page has no use for stays the
    // browser's and the framework's. Consuming everything would be the
    // easy way to stop the passage scrolling under a space bar, and it
    // would also swallow the operator's Cmd+R.
    if (command == null) return KeyEventResult.ignored;
    _run(command, mp);
    return KeyEventResult.handled;
  }

  // ── the second edition ────────────────────────────────────────────

  /// Load the projector's own second edition.
  ///
  /// The list is fetched through `FetchVerses.loadVerseList`, which
  /// returns a parsed list and touches nothing — deliberately NOT
  /// `MainProvider.preloadVersion`, which would write into the reader's
  /// own LRU. The rule that this view never writes reader state is
  /// easier to keep if it is kept literally.
  ///
  /// Superseded rather than guarded. The first version of this method
  /// began `if (_secondLoading) return;`, which made a change of edition
  /// DURING a load vanish: `_reloadSecond` cleared the cache and asked
  /// again, the guard dropped the ask, and the load already in flight
  /// then committed the edition it had been started with — so the wall
  /// showed KJV under a KJV tag while the setting said LEB, and nothing
  /// ever corrected it, because the stale index was non-null and the
  /// toggle only reloads an empty one. The window is seconds (a
  /// rootBundle read and a main-thread decode of ~8 MB), and both ways
  /// into it are the ordinary flow: press P, then V; or reopen with the
  /// second edition persisted and press V while it is still loading.
  ///
  /// So every call takes a fresh id, and a call that comes back to find
  /// a newer one discards its result. Two overlapping loads can no
  /// longer race to be last either — only the newest may write.
  Future<void> _loadSecond(MainProvider mp) async {
    final request = ++_secondRequest;
    setState(() => _secondLoading = true);
    final code = await _secondVersion(mp);
    final list = await FetchVerses.loadVerseList(code);
    if (!mounted || request != _secondRequest) return;
    setState(() {
      _secondLoading = false;
      _secondCode = code;
      _secondIndex = list == null ? null : _indexVerses(list);
    });
  }

  /// The edition the second block should be showing, seeding the
  /// projector's own stored choice from split view's the first time and
  /// only the first time.
  ///
  /// See [kSplitSecondaryVersionKey] and the library doc for why the
  /// borrow became a seed. The write-back is what makes it once: after
  /// it, `projectionSecondVersion` is non-empty forever and this method
  /// never reads `SharedPreferences` again.
  ///
  /// Async because the seed lives in `SharedPreferences` and nothing has
  /// read it into memory. That cost is paid at most once per install,
  /// on a path that is already awaiting a corpus.
  Future<String> _secondVersion(MainProvider mp) async {
    final settings = _settings;
    // Settings' per-language companion first, then this page's last
    // choice, then the split-view seed — see `projectionCompanionPick`.
    final pick = projectionCompanionPick(settings, mp.currentVersion);
    if (pick != null) {
      return projectionSecondVersionFrom(pick, mp.currentVersion);
    }
    final prefs = await SharedPreferences.getInstance();
    final seeded = projectionSecondVersionFrom(
      prefs.getString(kSplitSecondaryVersionKey),
      mp.currentVersion,
    );
    if (!mounted) return seeded;
    await settings.setProjectionSecondVersion(seeded);
    return seeded;
  }

  /// Drop the cached corpus and fetch again — for when the CHOSEN
  /// edition changed rather than the verse.
  ///
  /// When the second block is off there is nothing to fetch, but the
  /// cache still has to go: leaving it would show the old edition the
  /// next time the operator pressed `P`, having picked a new one in
  /// between.
  void _reloadSecond(MainProvider mp) {
    setState(() {
      _secondCode = null;
      _secondIndex = null;
    });
    if (_second) _loadSecond(mp);
  }

  static Map<String, Map<int, String>> _indexVerses(List<Verse> verses) {
    final out = <String, Map<int, String>>{};
    for (final v in verses) {
      // Keyed on the ENGLISH book name, the same normalisation
      // `Verse.id` uses, because the two editions on the wall are
      // routinely in different languages — that is the whole point of a
      // second edition here — and `马太福音` must find `Matthew`.
      final book = bookNameToEnglish[v.book] ?? v.book;
      (out['$book|${v.chapter}'] ??= <int, String>{})[v.verse] = v.text;
    }
    return out;
  }

  void _toggleSecondVersion(MainProvider mp) {
    final on = !_second;
    _settings.setProjectionSecondOn(on);
    if (on && _secondIndex == null && !_secondLoading) _loadSecond(mp);
  }

  /// The second edition's text for the verse on screen, or null when the
  /// second block is off, still loading, or has nothing to say here.
  /// The second edition's text for each verse on the wall, aligned by
  /// position; null when the block is off or the corpus is not here.
  List<String?>? _secondTextsFor(List<Verse> verses) {
    if (!_second || verses.isEmpty) return null;
    final index = _secondIndex;
    if (index == null) return null;
    return [
      for (final v in verses)
        index['${bookNameToEnglish[v.book] ?? v.book}|${v.chapter}']?[v.verse],
    ];
  }

  /// The corner reference, in the reading edition's own book-name
  /// language — `Verse.book` already carries it, so nothing has to be
  /// translated back and forth and the reference cannot end up naming a
  /// book in a language the text beside it is not in.
  ///
  /// `verseLabel` rather than `verse`, because that is the number the
  /// EDITION prints: where a publisher merges two references into one
  /// block it reads `1-2`, and a room told `1` would be looking for a
  /// verse that is not separately printed in front of them.
  // ── the countdown ─────────────────────────────────────────────────

  /// Start a countdown of [minutes], or take one down.
  ///
  /// The ticker only exists to repaint: the number itself is computed
  /// from [_countdownEnd] on every build, so a dropped tick or a
  /// throttled timer shows a stale frame at worst and never a wrong
  /// time. It stops itself once the clock reaches zero — the wall keeps
  /// saying 「就要开始了」 until the operator takes it down, which is the
  /// state the room is actually in.
  void _startCountdown(int minutes) {
    _countdownTicker?.cancel();
    setState(() {
      _blank = false;
      _countdownEnd = DateTime.now().add(Duration(minutes: minutes));
    });
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdownLeft == Duration.zero) t.cancel();
      setState(() {});
    });
  }

  void _stopCountdown() {
    _countdownTicker?.cancel();
    _countdownTicker = null;
    setState(() => _countdownEnd = null);
  }

  Future<void> _showCountdown() async {
    // A countdown that is already up: the button takes it down rather
    // than asking how long again. One key, both directions — which is
    // what an operator with their eyes on the room needs.
    if (_countdownEnd != null) {
      _stopCountdown();
      return;
    }
    final settings = _settings;
    final locale = settings.locale;
    final scheme = projectionDarkScheme(settings.primaryColor);
    await _wallDialog<void>(
      scheme: scheme,
      locale: locale,
      title: _s('projectionCountdown', 'Countdown', locale),
      body: (dialogContext, _) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _s('projectionCountdownHint',
                'The wall shows the time left, and nothing else.', locale),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        for (final m in kProjectionCountdownMinutes)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.timer_outlined, color: scheme.onSurfaceVariant),
            title: Text(
              (_s('projectionCountdownMinutes', '{n} minutes', locale))
                  .replaceAll('{n}', '$m'),
              style: TextStyle(color: scheme.onSurface),
            ),
            onTap: () {
              Navigator.of(dialogContext).pop();
              _startCountdown(m);
            },
          ),
      ],
    );
  }

  // ── the order of service ──────────────────────────────────────────
  //
  // A list of references prepared before the room fills, stepped with
  // `[` and `]`. See `projection_agenda.dart` for why the rows are
  // references and not copies of the text, and why there is no per-item
  // styling.

  /// When the countdown runs out, or null when none is running. An
  /// END TIME rather than a remaining duration: a timer that ticks a
  /// number down drifts, and one that is paused by a suspended tab
  /// comes back wrong. Wall-clock arithmetic on every frame cannot.
  DateTime? _countdownEnd;
  Timer? _countdownTicker;

  /// Time left, floored at zero, or null when nothing is counting.
  Duration? get _countdownLeft {
    final end = _countdownEnd;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Where in the agenda the wall is, or null when it is simply
  /// following the reader. Not persisted: an order of service survives
  /// the week, but the place you had reached in it is this morning's.
  int? _agendaAt;

  /// Put agenda row [index] on the wall.
  ///
  /// A row whose book the loaded edition does not have — an agenda
  /// built in 和合本 opened under an English-only edition, say — moves
  /// the cursor nowhere and leaves the wall as it was. Silently: the
  /// operator is mid-service and an error dialog on the projector is
  /// worse than a passage that did not change.
  void _showAgendaItem(MainProvider mp, int index) {
    final items = _settings.projectionAgenda;
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    setState(() => _agendaAt = index);
    if (item.kind == AgendaKind.blank) {
      setState(() => _blank = true);
      return;
    }
    final chapter = mp.findChapterIndex(item.book, item.chapter);
    if (chapter == null) return;
    final verses = _versesAt(mp, chapter);
    // By printed number, not by position: an edition that merges 4-5
    // into one row would otherwise put a different verse on the wall
    // than the one the agenda names.
    final at = verses.indexWhere((v) => v.verse == item.verse);
    if (at < 0) return;
    setState(() {
      _blank = false;
      _cursor = ProjectionCursor(chapter, at, count: item.count);
    });
  }

  /// `]` and `[`. From nowhere, `]` starts at the top — which is what an
  /// operator pressing it at the start of a service means.
  void _stepAgenda(MainProvider mp, int delta) {
    final items = _settings.projectionAgenda;
    if (items.isEmpty) return;
    final at = _agendaAt;
    final next = at == null ? (delta > 0 ? 0 : items.length - 1) : at + delta;
    if (next < 0 || next >= items.length) return;
    _showAgendaItem(mp, next);
  }

  /// The passage on the wall right now, as an agenda row.
  AgendaItem? _currentAsAgendaItem(MainProvider mp) {
    final cursor = _cursor ?? _readerCursor(mp);
    if (cursor == null) return null;
    final verses = _versesAt(mp, cursor.chapter);
    if (cursor.verse >= verses.length) return null;
    final v = verses[cursor.verse];
    return AgendaItem(
      kind: AgendaKind.passage,
      book: v.book,
      chapter: v.chapter,
      verse: v.verse,
      count: cursor.count,
    );
  }

  Future<void> _showAgenda(MainProvider mp) async {
    final settings = _settings;
    final locale = settings.locale;
    final scheme = projectionDarkScheme(settings.primaryColor);
    await _wallDialog<void>(
      scheme: scheme,
      locale: locale,
      title: _s('projectionAgenda', 'Order of service', locale),
      body: (dialogContext, setDialogState) {
        final items = [...settings.projectionAgenda];
        Future<void> commit(List<AgendaItem> next) async {
          await settings.setProjectionAgenda(next);
          setDialogState(() {});
        }

        return [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _s('projectionAgendaEmpty',
                    'Add the passage on the wall, in the order you need it.',
                    locale),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (var i = 0; i < items.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text('${i + 1}',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              title: Text(items[i].label,
                  style: TextStyle(
                      color: i == _agendaAt ? scheme.primary : scheme.onSurface,
                      fontWeight:
                          i == _agendaAt ? FontWeight.w700 : FontWeight.w400)),
              onTap: () {
                Navigator.of(dialogContext).pop();
                _showAgendaItem(mp, i);
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _s('projectionAgendaUp', 'Move up', locale),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: i == 0
                        ? null
                        : () {
                            final next = [...items];
                            next.insert(i - 1, next.removeAt(i));
                            if (_agendaAt == i) _agendaAt = i - 1;
                            commit(next);
                          },
                  ),
                  IconButton(
                    tooltip: _s('projectionAgendaRemove', 'Remove', locale),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      final next = [...items]..removeAt(i);
                      // The place in the list moves with the list, or
                      // goes away with it.
                      if (_agendaAt != null) {
                        if (_agendaAt == i) {
                          _agendaAt = null;
                        } else if (_agendaAt! > i) {
                          _agendaAt = _agendaAt! - 1;
                        }
                      }
                      commit(next);
                    },
                  ),
                ],
              ),
            ),
          const Divider(),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(_s('projectionAgendaAddCurrent',
                'Add what is on the wall', locale)),
            onPressed: () {
              final item = _currentAsAgendaItem(mp);
              if (item == null) return;
              commit([...items, item]);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.visibility_off_outlined, size: 18),
            label: Text(_s('projectionAgendaAddBlank', 'Add a blank', locale)),
            onPressed: () => commit([...items, const AgendaItem.blank()]),
          ),
          if (items.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(
                  _s('projectionAgendaClear', 'Clear the order', locale)),
              onPressed: () {
                _agendaAt = null;
                commit(const []);
              },
            ),
        ];
      },
    );
  }

  /// What the follower window paints — the same things the stage does,
  /// already resolved, so the follower needs no corpus and no Flutter.
  ProjectionFrame _frame(MainProvider mp, AppSettings settings,
      ColorScheme scheme, ProjectionGround ground, List<Verse> shown) {
    String hex(Color c) =>
        '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final texts = _secondTextsFor(shown);
    final secondOn = _second && shown.isNotEmpty;
    String? note;
    if (secondOn) {
      if (_secondLoading) {
        note = _s('projectionSecondVersionLoading',
            'Loading the second edition', settings.locale);
      } else if (texts == null || texts.every((t) => t == null)) {
        note = _s('projectionSecondVersionMissing',
            'This edition has no text here', settings.locale);
      }
    }
    final left = _countdownLeft;
    return ProjectionFrame(
      blank: _blank,
      countdown: left == null ? null : formatProjectionCountdown(left),
      countdownLabel: left == null
          ? null
          : _s(
              left == Duration.zero
                  ? 'projectionCountdownNow'
                  : 'projectionCountdownSoon',
              left == Duration.zero ? 'We are beginning' : 'The service begins in',
              settings.locale),
      typeSize: kProjectionTypeSteps[_typeStep],
      reference: _referenceFor(shown),
      tags: [
        shortBibleVersionLabel(mp.currentVersion),
        if (secondOn && _secondCode != null)
          shortBibleVersionLabel(_secondCode!),
      ],
      verses: [
        for (final v in shown) {'label': v.verseLabel, 'text': v.text},
      ],
      second: secondOn && note == null && texts != null
          ? [
              for (var i = 0; i < shown.length; i++)
                {'label': shown[i].verseLabel, 'text': texts[i]},
            ]
          : null,
      secondNote: note,
      groundColors: [
        for (final c in projectionGroundColors(ground, scheme)) hex(c),
      ],
      radial: ground == ProjectionGround.spotlight,
      ink: hex(scheme.onSurface),
      muted: hex(scheme.onSurfaceVariant),
    );
  }

  /// `创世纪 1:1`, or `创世纪 1:1–3` for a block. The range is spelled
  /// with the labels, not the numbers, so a merged verse keeps its
  /// `4-5` and the reference cannot claim a verse the wall is not
  /// showing.
  String _referenceFor(List<Verse> verses) {
    if (verses.isEmpty) return '';
    final first = verses.first;
    final head = '${first.book} ${first.chapter}:${first.verseLabel}';
    return verses.length == 1 ? head : '$head–${verses.last.verseLabel}';
  }

  // ── the pickers ───────────────────────────────────────────────────
  //
  // Three things the keyboard alone cannot ask — which ground, which
  // edition, which saved setup — and one shell they all use.
  //
  // Dialogs rather than menus anchored to their buttons, because the
  // control strip fades after four seconds and takes its anchor with
  // it. A menu whose owner has vanished is a menu in mid-air.

  /// A dialog dressed in the WALL's palette, not the reader's.
  ///
  /// `showDialog` inherits the app theme, which follows
  /// `settings.themeMode` and on most installs is light half the time.
  /// A light dialog opened from this page is a white rectangle thrown
  /// across a dark wall in front of a congregation — precisely the flash
  /// `projection_stage.dart`'s ground rules exist to prevent, arriving
  /// through the one surface those rules do not reach.
  ///
  /// A whole `ThemeData` rather than the
  /// `Theme.of(context).copyWith(colorScheme: ...)` the control strip
  /// uses a few lines below. The two want different things: the strip
  /// needs the app's own `cardTheme` to survive, and a dialog has no
  /// Card in it and does need the app theme's light-derived text and
  /// dialog colours replaced rather than kept.
  ///
  /// [body] is handed a [StateSetter] because the presets dialog edits
  /// the list it is displaying; the other two ignore it.
  Future<T?> _wallDialog<T>({
    required ColorScheme scheme,
    required String locale,
    required String title,
    required List<Widget> Function(BuildContext, StateSetter) body,
  }) async {
    final result = await showDialog<T>(
      context: context,
      builder: (dialogContext) => Theme(
        data: ThemeData(useMaterial3: true, colorScheme: scheme),
        child: StatefulBuilder(
          builder: (innerContext, setDialogState) => AlertDialog(
            backgroundColor: scheme.surfaceContainerHigh,
            title: Text(title, style: TextStyle(color: scheme.onSurface)),
            // A fixed width so three dialogs holding lists of different
            // lengths are the same shape on the wall, and scrollable so
            // a long edition list cannot push the actions off a laptop
            // screen.
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: body(innerContext, setDialogState),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_s('projectionClose', 'Close', locale)),
              ),
            ],
          ),
        ),
      ),
    );
    // Keyboard focus went to the dialog's route and does not come back
    // on its own. Without this the arrow keys are dead after any picker
    // — which is the moment the operator most needs them.
    if (mounted) {
      _focus.requestFocus();
      _wakeControls();
    }
    return result;
  }

  /// One row of a picker: a label, a mark showing whether it is what is
  /// in force, and an optional trailing control.
  Widget _pickerRow(
    ColorScheme scheme, {
    required String label,
    String? detail,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
  }) =>
      ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(label, style: TextStyle(color: scheme.onSurface)),
        subtitle: detail == null
            ? null
            : Text(detail,
                style: TextStyle(color: scheme.onSurfaceVariant)),
        trailing: trailing,
      );

  Future<void> _chooseGround() async {
    final settings = _settings;
    final scheme = projectionDarkScheme(settings.primaryColor);
    final locale = settings.locale;
    final current = _ground;
    await _wallDialog<void>(
      scheme: scheme,
      locale: locale,
      title: _s('projectionGround', 'Background', locale),
      body: (dialogContext, _) => [
        for (final ground in ProjectionGround.values)
          _pickerRow(
            scheme,
            label: projectionGroundLabel(ground, locale),
            selected: ground == current,
            onTap: () {
              settings.setProjectionGround(ground.name);
              Navigator.of(dialogContext).pop();
            },
          ),
      ],
    );
  }

  /// Which edition goes under the first one.
  ///
  /// Picking one also turns the second block ON. Choosing an edition and
  /// then having to find the toggle is two steps for one intention, and
  /// the operator who opened this picker has already said what they
  /// want.
  Future<void> _chooseSecondVersion(MainProvider mp) async {
    final settings = _settings;
    final scheme = projectionDarkScheme(settings.primaryColor);
    final locale = settings.locale;
    // Resolves — and, on a first run, seeds — so the picker marks the
    // edition that is actually in force rather than an empty row.
    final current = await _secondVersion(mp);
    if (!mounted) return;
    await _wallDialog<void>(
      scheme: scheme,
      locale: locale,
      title: _s('projectionSecondVersionChoose', 'Choose the second edition',
          locale),
      body: (dialogContext, _) => [
        // The edition already on top is left out. It is not a second
        // edition, it is the same words twice, and
        // `projectionSecondVersionFrom` would replace it with the
        // language fallback anyway — so offering it would be offering a
        // row that does something else when tapped.
        for (final version
            in availableVersions.where((v) => v.value != mp.currentVersion))
          _pickerRow(
            scheme,
            label: fullBibleVersionLabel(version.value),
            detail: shortBibleVersionLabel(version.value),
            selected: version.value == current,
            onTap: () {
              Navigator.of(dialogContext).pop();
              settings.setProjectionSecondVersion(version.value);
              // And as the companion for THIS language, so the choice
              // made at the wall is the one Settings shows, and holds
              // the next time a passage in this language goes up.
              settings.setProjectionCompanion(
                  projectionLanguageOf(mp.currentVersion), version.value);
              settings.setProjectionSecondOn(true);
              _reloadSecond(mp);
            },
          ),
      ],
    );
  }

  // ── the presets ───────────────────────────────────────────────────

  /// This page's live setup, under [name].
  ProjectionPreset _currentSetup(String name) => ProjectionPreset(
        name: name,
        typeStep: _typeStep,
        secondOn: _second,
        // The STORED code, not the resolved one: a preset saved on a
        // build that has the edition should still name it when the same
        // profile is opened on a build that does not, so it comes back
        // when the reader returns to the first device.
        secondVersion: _settings.projectionSecondVersion,
        groundName: _ground.name,
      );

  /// A preset in one line, for the list: size, ground, second edition.
  String _presetSummary(ProjectionPreset preset, String locale,
      MainProvider mp) {
    final step =
        preset.typeStep.clamp(0, kProjectionTypeSteps.length - 1);
    final ground =
        projectionGroundLabel(projectionGroundFromName(preset.groundName),
            locale);
    final second = preset.secondOn
        // Resolved for DISPLAY only — this is the edition the preset
        // would actually put on the wall on this device, which is the
        // thing the operator is choosing between.
        ? shortBibleVersionLabel(
            projectionSecondVersionFrom(preset.secondVersion,
                mp.currentVersion))
        : _s('projectionSecondVersionHide', 'One edition only', locale);
    return '${kProjectionTypeSteps[step].round()} px · $ground · $second';
  }

  /// Put a saved setup back on the wall.
  ///
  /// The order matters: the edition is settled BEFORE the block is
  /// switched on, so a preset that turns the second edition on never has
  /// a frame in which the block is on and still pointing at the previous
  /// edition's corpus.
  Future<void> _applyPreset(ProjectionPreset preset, MainProvider mp) async {
    final settings = _settings;
    await settings.setProjectionTypeStep(
        preset.typeStep.clamp(0, kProjectionTypeSteps.length - 1));
    await settings
        .setProjectionGround(projectionGroundFromName(preset.groundName).name);
    // Through the same resolver the loader uses, so a preset naming an
    // edition this build cannot load lands on a real one instead of on
    // an empty wall. See `projectionSecondVersionFrom`.
    await settings.setProjectionSecondVersion(
        projectionSecondVersionFrom(preset.secondVersion, mp.currentVersion));
    await settings.setProjectionSecondOn(preset.secondOn);
    if (!mounted) return;
    _reloadSecond(mp);
  }

  Future<void> _showPresets(MainProvider mp) async {
    final settings = _settings;
    final scheme = projectionDarkScheme(settings.primaryColor);
    final locale = settings.locale;
    await _wallDialog<void>(
      scheme: scheme,
      locale: locale,
      title: _s('projectionPresets', 'Presets', locale),
      body: (dialogContext, setDialogState) => [
        if (settings.projectionPresets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _s('projectionPresetsEmpty', 'Nothing saved yet', locale),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final preset in settings.projectionPresets)
          _pickerRow(
            scheme,
            label: preset.name,
            detail: _presetSummary(preset, locale, mp),
            // Nothing is "the current preset": applying one does not
            // make the live setup that preset, it copies it, and the
            // next `+` press makes them differ. Marking one would be a
            // claim the page cannot keep.
            selected: false,
            onTap: () {
              Navigator.of(dialogContext).pop();
              _applyPreset(preset, mp);
            },
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
              tooltip: _s('projectionPresetDelete', 'Delete preset', locale),
              onPressed: () async {
                await settings.deleteProjectionPreset(preset.name);
                // The dialog holds its own copy of the list through this
                // builder, so it has to be told; the page behind it is
                // watching AppSettings and does not.
                setDialogState(() {});
              },
            ),
          ),
        const Divider(),
        // Saving is at the BOTTOM, under the list. The common action in
        // this dialog is recalling a setup, not making one — an operator
        // opens it on Sunday to get last Sunday back.
        _PresetSaveField(
          scheme: scheme,
          locale: locale,
          onSave: (name) async {
            await settings.saveProjectionPreset(_currentSetup(name));
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  // ── the controls, and their way out of the way ────────────────────

  void _wakeControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _restartControlsTimer();
  }

  void _restartControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(kProjectionControlsLinger, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MainProvider>();
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = projectionDarkScheme(settings.primaryColor);
    final ground = _ground;
    final cursor = _cursor ?? _readerCursor(mp);
    final verses =
        cursor == null ? const <Verse>[] : _versesAt(mp, cursor.chapter);
    final shown = cursor == null || cursor.verse >= verses.length
        ? const <Verse>[]
        : verses.sublist(
            cursor.verse,
            (cursor.verse + cursor.count).clamp(0, verses.length),
          );

    // The companion can change UNDER the page — Settings is a route
    // away and this page watches the same AppSettings. When the resident
    // corpus is no longer the edition the pairing now names, fetch the
    // right one; compared against the RESOLVED code, so an alias that
    // resolves to what is already loaded does not loop.
    if (_second && !_secondLoading && _secondCode != null) {
      final want = projectionCompanionPick(settings, mp.currentVersion);
      if (want != null &&
          projectionSecondVersionFrom(want, mp.currentVersion) != _secondCode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reloadSecond(mp);
        });
      }
    }

    if (ProjectionBroadcast.isSupported) {
      final frame = _frame(mp, settings, scheme, ground, shown);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ProjectionBroadcast.post(frame);
      });
    }

    return Scaffold(
      // The Scaffold under the stage carries the chosen ground's own
      // darkest value rather than `scheme.surface`, so the one frame
      // between a ground change and the stage's repaint — and any pixel
      // the stage does not cover — is never brighter than the ground the
      // operator asked for.
      backgroundColor: projectionGroundColors(ground, scheme).last,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (node, event) => _onKey(event, mp),
        child: MouseRegion(
          onHover: (_) => _wakeControls(),
          child: Listener(
            onPointerDown: (_) => _wakeControls(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ProjectionStage(
                    verses: shown,
                    reference: _referenceFor(shown),
                    versionCode: mp.currentVersion,
                    typeSize: kProjectionTypeSteps[_typeStep],
                    blank: _blank,
                    locale: locale,
                    scheme: scheme,
                    ground: ground,
                    secondOn: _second,
                    secondTexts: _secondTextsFor(shown),
                    secondCode: _secondCode,
                    secondLoading: _secondLoading,
                    countdownRemaining: _countdownLeft,
                  ),
                ),
                // THE CONTROLS SIT AT THE TOP, AND THE REFERENCE AT THE
                // BOTTOM, so the two can never occupy the same pixels.
                // The bar comes and goes; the reference is what the room
                // is following along by and must be legible in every
                // frame it is meant to be in. A bar that occludes it
                // four seconds at a time is a reference that is missing
                // exactly when the operator is doing something.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: AppMotion.fast,
                      curve: _controlsVisible
                          ? AppMotion.enter
                          : AppMotion.exit,
                      child: _controls(locale, scheme, mp),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The operator's buttons, for the configurations where the keyboard
  /// is not the answer — a mirrored laptop display, or a tablet, where
  /// there is no key to press.
  ///
  /// Sized off fixed chrome numbers rather than `settings.fontSize`,
  /// which is the reader's SCRIPTURE size and has no business setting an
  /// icon button. That split is the whole type story of this page in one
  /// line: the stage above is sized off the ROOM, and the chrome is
  /// sized off nothing at all because it is not meant to be read from
  /// the back row.
  Widget _controls(String locale, ColorScheme scheme, MainProvider mp) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        // TWELVE buttons and five dividers is wider than a phone, and a
        // projection driven from a phone or a narrow window is a real if
        // unusual configuration. The alternative to handling it is a
        // RenderFlex overflow, which is a yellow-and-black stripe on a
        // church wall.
        //
        // This was a `FittedBox(fit: scaleDown)` until 2026-09-09, and
        // that stopped being the right answer when the setup controls
        // arrived. `scaleDown` handles overflow by shrinking the WHOLE
        // bar, and the bar is now 621 px wide against the 328 a 360-px
        // window leaves inside the card — 53%, which draws every 20-px
        // glyph at 10.6. Those are measured numbers, not remembered
        // ones: `projection_setup_test.dart` takes them off the live
        // tree and fails if the bar ever shrinks back to a width where
        // scaling would have been fine. A ten-pixel target is not a
        // control an operator can hit from the back of a hall with their
        // eyes on the congregation, it is a picture of one.
        //
        // `OverflowHintScroll` keeps every button at full size and says
        // there is more, with a fade into the bar's own colour and a
        // tappable chevron on whichever edge has something behind it —
        // built for this exact problem in the selection bar, after the
        // owner's 「下面几乎满了 不往右划根本不知道」. Its scroll view
        // hugs its child when the child fits, so on the laptop this page
        // is really for, nothing changes: no fade, no chevron, and the
        // bar is the same pill it always was.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          // A Card so the corner radius comes from the app's own
          // `cardTheme` rather than a number invented here.
          child: Card(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              // The scroller reads `Theme.of(context).colorScheme` for
              // its chevron, and the ambient theme here is the READER's
              // — which is light on half the installs, putting a
              // near-black chevron on a dark bar. `copyWith` rather than
              // a fresh ThemeData so the Card above keeps the app's own
              // radius, which is the whole reason it is a Card.
              child: Theme(
                data: Theme.of(context).copyWith(colorScheme: scheme),
                child: OverflowHintScroll(
                  fadeColor: scheme.surfaceContainerHigh,
                  moreLabel:
                      _s('projectionMoreControls', 'More controls', locale),
                  backLabel: _s(
                      'projectionBackControls', 'Previous controls', locale),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _button(
                          scheme,
                          Icons.first_page,
                          'projectionPreviousChapter',
                          'Previous chapter',
                          locale,
                          ProjectionCommand.previousChapter,
                          mp),
                      _button(
                          scheme,
                          Icons.chevron_left,
                          'projectionPreviousVerse',
                          'Previous verse',
                          locale,
                          ProjectionCommand.previousVerse,
                          mp),
                      _button(
                          scheme,
                          Icons.chevron_right,
                          'projectionNextVerse',
                          'Next verse',
                          locale,
                          ProjectionCommand.nextVerse,
                          mp),
                      _button(
                          scheme,
                          Icons.last_page,
                          'projectionNextChapter',
                          'Next chapter',
                          locale,
                          ProjectionCommand.nextChapter,
                          mp),
                      _divider(scheme),
                      _button(
                          scheme,
                          _blank ? Icons.visibility : Icons.visibility_off,
                          _blank ? 'projectionUnblank' : 'projectionBlank',
                          _blank ? 'Show the passage' : 'Black out',
                          locale,
                          ProjectionCommand.blank,
                          mp),
                      _divider(scheme),
                      _button(
                          scheme,
                          Icons.text_decrease,
                          'projectionTypeSmaller',
                          'Smaller type',
                          locale,
                          ProjectionCommand.smallerType,
                          mp),
                      _button(
                          scheme,
                          Icons.text_increase,
                          'projectionTypeBigger',
                          'Larger type',
                          locale,
                          ProjectionCommand.biggerType,
                          mp),
                      _divider(scheme),
                      // The second edition's two controls sit together:
                      // whether there is one, and which one it is. They
                      // were a toggle and a preference in another
                      // feature until 2026-09-09 — see the library doc.
                      _button(
                          scheme,
                          _second ? Icons.layers_clear : Icons.layers,
                          _second
                              ? 'projectionSecondVersionHide'
                              : 'projectionSecondVersionShow',
                          _second
                              ? 'One edition only'
                              : 'Add a second edition',
                          locale,
                          ProjectionCommand.toggleSecondVersion,
                          mp),
                      _button(
                          scheme,
                          Icons.translate,
                          'projectionSecondVersionChoose',
                          'Choose the second edition',
                          locale,
                          ProjectionCommand.chooseSecondVersion,
                          mp),
                      _divider(scheme),
                      _button(
                          scheme,
                          Icons.gradient,
                          'projectionGround',
                          'Background',
                          locale,
                          ProjectionCommand.cycleGround,
                          mp,
                          // The BUTTON opens the picker while the KEY
                          // steps the ring. Same intention, two
                          // instruments: a hand already on the screen
                          // can pick the ground it wants by name, and a
                          // hand on the keyboard would rather step a
                          // ring than aim at a dialog. The command is
                          // still what the tooltip and the key say it
                          // is, so nothing about the ring is hidden.
                          instead: _chooseGround),
                      _button(
                          scheme,
                          Icons.bookmarks_outlined,
                          'projectionPresets',
                          'Presets',
                          locale,
                          ProjectionCommand.presets,
                          mp),
                      _button(
                          scheme,
                          _countdownEnd == null
                              ? Icons.timer_outlined
                              : Icons.timer_off_outlined,
                          'projectionCountdown',
                          'Countdown',
                          locale,
                          ProjectionCommand.countdown,
                          mp),
                      _button(
                          scheme,
                          Icons.list_alt_outlined,
                          'projectionAgenda',
                          'Order of service',
                          locale,
                          ProjectionCommand.agenda,
                          mp),
                      if (ProjectionBroadcast.isSupported)
                        _button(
                            scheme,
                            Icons.open_in_new,
                            'projectionOpenStage',
                            'Open the projector window',
                            locale,
                            ProjectionCommand.openStage,
                            mp),
                      _divider(scheme),
                      _button(
                          scheme,
                          Icons.close,
                          'projectionLeave',
                          'Leave projection',
                          locale,
                          ProjectionCommand.leave,
                          mp),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Both lines are for the operator and both fade with the bar.
        // The keys line is how a mirrored setup learns the bindings; the
        // one-window line is the answer to the question the operator is
        // about to ask, said before they ask it rather than in a release
        // note nobody reads.
        _hint(scheme, _s('projectionKeysHint', 'Arrows change verse', locale)),
        _hint(
            scheme,
            _s('projectionOneWindowNote',
                'One window: put this window on the projector display.',
                locale)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _hint(ColorScheme scheme, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      );

  Widget _divider(ColorScheme scheme) => Container(
        width: 1,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: scheme.outlineVariant,
      );

  /// One control-strip button.
  ///
  /// [instead] is the one seam between a button and its key: the ground
  /// control's key steps the ring and its button opens the picker (see
  /// the call site). Everything else leaves it null and the button runs
  /// [command], which is what keeps the bar and the keyboard from
  /// drifting apart. [command] is still carried in both cases, because
  /// it is what the tooltip is describing.
  Widget _button(ColorScheme scheme, IconData icon, String labelKey,
      String fallback, String locale, ProjectionCommand command,
      MainProvider mp, {VoidCallback? instead}) {
    final label = _s(labelKey, fallback, locale);
    return IconButton(
      icon: Icon(icon, color: scheme.onSurface),
      iconSize: 20,
      tooltip: label,
      onPressed: () {
        if (instead == null) {
          _run(command, mp);
          return;
        }
        _wakeControls();
        instead();
      },
    );
  }
}

/// The name field and its save button, in the presets dialog.
///
/// A widget of its own for ONE reason, and it is a real one rather than
/// tidiness: a `TextEditingController` created beside `showDialog` and
/// disposed when it returns is disposed too early. The route's exit
/// animation is still running at that point and the `TextField` is still
/// mounted, so the next frame rebuilds it against a dead controller and
/// throws "A TextEditingController was used after being disposed". A
/// controller owned by the widget that uses it cannot outlive or
/// predecease that widget.
class _PresetSaveField extends StatefulWidget {
  const _PresetSaveField({
    required this.scheme,
    required this.locale,
    required this.onSave,
  });

  final ColorScheme scheme;
  final String locale;
  final Future<void> Function(String name) onSave;

  @override
  State<_PresetSaveField> createState() => _PresetSaveFieldState();
}

class _PresetSaveFieldState extends State<_PresetSaveField> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    // An unnamed preset cannot be told from another unnamed preset in a
    // list, so the button does nothing rather than inventing
    // "Preset 3" — a name the operator would then have to remember the
    // meaning of.
    if (name.isEmpty) return;
    await widget.onSave(name);
    if (mounted) _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          style: TextStyle(color: scheme.onSurface),
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText:
                _s('projectionPresetName', 'Preset name', widget.locale),
            hintText: _s('projectionPresetNameHint', 'e.g. Morning service',
                widget.locale),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: Text(_s('projectionPresetSave', 'Save the current setup',
                widget.locale)),
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}

/// `projectionStrings`, with English as the fallback locale before the
/// caller's own literal — the same idiom every `uiStrings` lookup uses.
String _s(String key, String fallback, String locale) =>
    projectionStrings[key]?[locale] ??
    projectionStrings[key]?['en'] ??
    fallback;
