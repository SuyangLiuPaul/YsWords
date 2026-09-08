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
        resolvableVersion;
import 'package:yswords/constants/book_names.dart' show bookNameToEnglish;
import 'package:yswords/constants/motion.dart';
import 'package:yswords/constants/projection_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_verses.dart';
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
/// **This is the reuse.** The app already answers "what is the other
/// edition beside the one I am reading", and it answers it in split
/// view: `home_page.dart`'s `_activateSplitView` builds a second
/// `MainProvider(storagePrefix: 'secondary_')`, and that provider
/// persists its edition through `MainProvider._saveState`'s
/// `prefs.setString('${_storagePrefix}version', currentVersion)` and
/// reads it back in `restoreState`. So the operator's own second column
/// — whichever edition they last put beside their reading — is what
/// lands on the wall. A projection that resolved the second edition by
/// some rule of its own would put a translation up that the operator's
/// screen does not have open.
///
/// Spelled as a literal because `_storagePrefix` is private to
/// `MainProvider`, which makes this a hand-kept cross-file fact of
/// exactly the kind this repo pins with a source-reading test rather
/// than trusts — `projection_page_test.dart` reads
/// `main_provider.dart` and fails if the key stops being written there.
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
  const ProjectionCursor(this.chapter, this.verse);

  final int chapter;
  final int verse;

  @override
  bool operator ==(Object other) =>
      other is ProjectionCursor &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(chapter, verse);

  @override
  String toString() => 'ProjectionCursor($chapter, $verse)';
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

class ProjectionPage extends StatefulWidget {
  const ProjectionPage({super.key});

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

  int _typeStep = kProjectionTypeDefaultStep;
  bool _blank = false;
  bool _second = false;
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

  @override
  void initState() {
    super.initState();
    _restartControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
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
      ProjectionCommand.nextVerse => projectionVerseStep(from, 1,
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
      case ProjectionCommand.biggerType:
        setState(() => _typeStep = projectionTypeStep(_typeStep, 1));
      case ProjectionCommand.smallerType:
        setState(() => _typeStep = projectionTypeStep(_typeStep, -1));
      case ProjectionCommand.toggleSecondVersion:
        _toggleSecondVersion(mp);
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

  /// Load whichever edition split view's second column is set to.
  ///
  /// See [kSplitSecondaryVersionKey] for why that is the right source.
  /// The list is fetched through `FetchVerses.loadVerseList`, which
  /// returns a parsed list and touches nothing — deliberately NOT
  /// `MainProvider.preloadVersion`, which would write into the reader's
  /// own LRU. The rule that this view never writes reader state is
  /// easier to keep if it is kept literally.
  Future<void> _loadSecond(MainProvider mp) async {
    setState(() => _secondLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kSplitSecondaryVersionKey);
    final code = resolvableVersion(
      stored == null || stored.isEmpty || stored == mp.currentVersion
          ? projectionFallbackSecondVersion(mp.currentVersion)
          : stored,
    );
    final list = await FetchVerses.loadVerseList(code);
    if (!mounted) return;
    setState(() {
      _secondLoading = false;
      _secondCode = code;
      _secondIndex = list == null ? null : _indexVerses(list);
    });
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
    setState(() => _second = on);
    if (on && _secondIndex == null && !_secondLoading) _loadSecond(mp);
  }

  /// The second edition's text for the verse on screen, or null when the
  /// second block is off, still loading, or has nothing to say here.
  String? _secondTextFor(Verse? verse) {
    if (!_second || verse == null) return null;
    final index = _secondIndex;
    if (index == null) return null;
    final book = bookNameToEnglish[verse.book] ?? verse.book;
    return index['$book|${verse.chapter}']?[verse.verse];
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
  String _referenceFor(Verse? verse) =>
      verse == null ? '' : '${verse.book} ${verse.chapter}:${verse.verseLabel}';

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
    final cursor = _cursor ?? _readerCursor(mp);
    final verses =
        cursor == null ? const <Verse>[] : _versesAt(mp, cursor.chapter);
    final verse = cursor != null && cursor.verse < verses.length
        ? verses[cursor.verse]
        : null;

    return Scaffold(
      backgroundColor: scheme.surface,
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
                    verse: verse,
                    reference: _referenceFor(verse),
                    versionCode: mp.currentVersion,
                    typeSize: kProjectionTypeSteps[_typeStep],
                    blank: _blank,
                    locale: locale,
                    scheme: scheme,
                    secondOn: _second,
                    secondText: _secondTextFor(verse),
                    secondCode: _secondCode,
                    secondLoading: _secondLoading,
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
        // Ten buttons is wider than a phone, and a projection driven
        // from a phone is a real if unusual configuration — the
        // alternative to shrinking here is a RenderFlex overflow, which
        // is a yellow-and-black stripe on a church wall. `scaleDown`
        // only ever shrinks, so on the laptop this is meant for, the bar
        // is drawn at exactly the size below.
        FittedBox(
          fit: BoxFit.scaleDown,
          // A Card so the corner radius comes from the app's own
          // `cardTheme` rather than a number invented here.
          child: Card(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _button(scheme, Icons.first_page, 'projectionPreviousChapter',
                      'Previous chapter', locale,
                      ProjectionCommand.previousChapter, mp),
                  _button(scheme, Icons.chevron_left, 'projectionPreviousVerse',
                      'Previous verse', locale,
                      ProjectionCommand.previousVerse, mp),
                  _button(scheme, Icons.chevron_right, 'projectionNextVerse',
                      'Next verse', locale, ProjectionCommand.nextVerse, mp),
                  _button(scheme, Icons.last_page, 'projectionNextChapter',
                      'Next chapter', locale, ProjectionCommand.nextChapter,
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
                  _button(scheme, Icons.text_decrease, 'projectionTypeSmaller',
                      'Smaller type', locale, ProjectionCommand.smallerType,
                      mp),
                  _button(scheme, Icons.text_increase, 'projectionTypeBigger',
                      'Larger type', locale, ProjectionCommand.biggerType, mp),
                  _divider(scheme),
                  _button(
                      scheme,
                      _second ? Icons.layers_clear : Icons.layers,
                      _second
                          ? 'projectionSecondVersionHide'
                          : 'projectionSecondVersionShow',
                      _second ? 'One edition only' : 'Add a second edition',
                      locale,
                      ProjectionCommand.toggleSecondVersion,
                      mp),
                  _divider(scheme),
                  _button(scheme, Icons.close, 'projectionLeave',
                      'Leave projection', locale, ProjectionCommand.leave, mp),
                ],
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

  Widget _button(ColorScheme scheme, IconData icon, String labelKey,
      String fallback, String locale, ProjectionCommand command,
      MainProvider mp) {
    final label = _s(labelKey, fallback, locale);
    return IconButton(
      icon: Icon(icon, color: scheme.onSurface),
      iconSize: 20,
      tooltip: label,
      onPressed: () => _run(command, mp),
    );
  }
}

/// `projectionStrings`, with English as the fallback locale before the
/// caller's own literal — the same idiom every `uiStrings` lookup uses.
String _s(String key, String fallback, String locale) =>
    projectionStrings[key]?[locale] ??
    projectionStrings[key]?['en'] ??
    fallback;
