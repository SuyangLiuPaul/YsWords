// The arithmetic half of 投影 (`lib/pages/projection_page.dart`): the
// cursor, the key table and the type ladder, none of which need a widget
// to be wrong.
//
// `projection_page_test.dart` holds the other half — the behaviours that
// only exist once the page is actually on screen.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/pages/projection_page.dart';

/// A three-chapter corpus: 2 verses, then 3, then 2.
///
/// Small enough to reason about by hand and big enough to have an
/// interior boundary (chapter 0→1) as well as both ends.
int _versesIn(int chapter) => const [2, 3, 2][chapter];
const int _chapterCount = 3;

ProjectionCursor _verseStep(ProjectionCursor from, int delta) =>
    projectionVerseStep(from, delta,
        chapterCount: _chapterCount, versesIn: _versesIn);

ProjectionCursor _chapterStep(ProjectionCursor from, int delta) =>
    projectionChapterStep(from, delta,
        chapterCount: _chapterCount, versesIn: _versesIn);

void main() {
  group('the verse keys', () {
    test('advance within a chapter', () {
      expect(_verseStep(const ProjectionCursor(1, 0), 1),
          const ProjectionCursor(1, 1));
    });

    test('roll forward over a chapter boundary onto the next first verse',
        () {
      expect(_verseStep(const ProjectionCursor(0, 1), 1),
          const ProjectionCursor(1, 0));
    });

    test('roll backward over a chapter boundary onto the previous LAST verse',
        () {
      // Not verse 0: stepping back one verse from the top of a chapter
      // means the verse immediately before it, which is the end of the
      // chapter before. That is the question the verse key asks; the
      // chapter key asks the other one.
      expect(_verseStep(const ProjectionCursor(1, 0), -1),
          const ProjectionCursor(0, 1));
    });

    test('refuse to move at the end of the corpus rather than wrap to the '
        'beginning', () {
      const last = ProjectionCursor(2, 1);
      expect(_verseStep(last, 1), last);
    });

    test('refuse to move at the beginning of the corpus', () {
      const first = ProjectionCursor(0, 0);
      expect(_verseStep(first, -1), first);
    });

    test('step over an empty chapter rather than land on it', () {
      // A New-Testament-only edition is the normal case in this app, so
      // a chapter list that runs ahead of the verse data is not a
      // defect. Landing on chapter 1 here would put a blank wall up
      // that pressing the same key again cannot clear.
      int versesIn(int c) => const [1, 0, 1][c];
      expect(
        projectionVerseStep(const ProjectionCursor(0, 0), 1,
            chapterCount: 3, versesIn: versesIn),
        const ProjectionCursor(2, 0),
      );
    });
  });

  group('the chapter keys', () {
    test('land on the first verse going forward', () {
      expect(_chapterStep(const ProjectionCursor(0, 1), 1),
          const ProjectionCursor(1, 0));
    });

    test('land on the first verse going BACKWARD too', () {
      // "Previous chapter" from the middle of chapter 1 means the top of
      // chapter 0, not its last verse: the operator is moving to a
      // passage, and a passage starts at the top.
      expect(_chapterStep(const ProjectionCursor(1, 2), -1),
          const ProjectionCursor(0, 0));
    });

    test('refuse to move past either end of the corpus', () {
      const last = ProjectionCursor(2, 0);
      const first = ProjectionCursor(0, 0);
      expect(_chapterStep(last, 1), last);
      expect(_chapterStep(first, -1), first);
    });

    test('skip an empty chapter rather than land on it', () {
      int versesIn(int c) => const [1, 0, 1][c];
      expect(
        projectionChapterStep(const ProjectionCursor(0, 0), 1,
            chapterCount: 3, versesIn: versesIn),
        const ProjectionCursor(2, 0),
      );
    });
  });

  group('the key table', () {
    test('all four arrows, space and enter move by verse in the direction '
        'they point', () {
      for (final key in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
      ]) {
        expect(projectionCommandFor(key), ProjectionCommand.nextVerse,
            reason: '$key should advance one verse');
      }
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.backspace,
      ]) {
        expect(projectionCommandFor(key), ProjectionCommand.previousVerse,
            reason: '$key should retreat one verse');
      }
    });

    test('a clicker\'s two buttons move by chapter', () {
      expect(projectionCommandFor(LogicalKeyboardKey.pageDown),
          ProjectionCommand.nextChapter);
      expect(projectionCommandFor(LogicalKeyboardKey.pageUp),
          ProjectionCommand.previousChapter);
    });

    test('B blanks, the way it does in every other presentation tool', () {
      expect(projectionCommandFor(LogicalKeyboardKey.keyB),
          ProjectionCommand.blank);
    });

    test('both faces of the resize keys are answered', () {
      // A keyboard prints `+` on the key the operator presses and
      // reports `=` unless Shift is down; a numeric keypad reports
      // neither. An operator who presses the key with the plus on it
      // must get a bigger verse.
      for (final key in [
        LogicalKeyboardKey.equal,
        LogicalKeyboardKey.add,
        LogicalKeyboardKey.numpadAdd,
      ]) {
        expect(projectionCommandFor(key), ProjectionCommand.biggerType,
            reason: '$key should enlarge');
      }
      for (final key in [
        LogicalKeyboardKey.minus,
        LogicalKeyboardKey.numpadSubtract,
      ]) {
        expect(projectionCommandFor(key), ProjectionCommand.smallerType,
            reason: '$key should shrink');
      }
    });

    test('Esc leaves', () {
      expect(projectionCommandFor(LogicalKeyboardKey.escape),
          ProjectionCommand.leave);
    });

    test('a key the projection has no use for is left to the browser', () {
      // Ignored rather than swallowed: consuming everything is how an
      // operator loses Cmd+R in the middle of a service.
      expect(projectionCommandFor(LogicalKeyboardKey.keyZ), isNull);
      expect(projectionCommandFor(LogicalKeyboardKey.f5), isNull);
      expect(projectionCommandFor(LogicalKeyboardKey.tab), isNull);
    });
  });

  group('the type ladder', () {
    test('does not overlap the reading font scale at all', () {
      // The property, not a restatement of the numbers: the reading
      // control in this app clamps to 32 (settings_page.dart's slider is
      // `min: 12, max: 32`, and bible_reading_pane.dart's two steppers
      // both `.clamp(12, 32)`). If someone widens that slider, this
      // fails — which is the point. Two scales that can produce the same
      // size are one scale with a confusing name.
      const readingFontSizeMax = 32.0;
      expect(kProjectionTypeSteps.first, greaterThan(readingFontSizeMax),
          reason: 'the smallest size the room can be shown must still be '
              'larger than the biggest size the reader can set for their '
              'own screen');
    });

    test('every step is larger than the one below it', () {
      for (var i = 1; i < kProjectionTypeSteps.length; i++) {
        expect(kProjectionTypeSteps[i],
            greaterThan(kProjectionTypeSteps[i - 1]));
      }
    });

    test('each press is roughly the same proportional jump, not the same '
        'number of pixels', () {
      // A fixed increment makes one key do two different jobs at the two
      // ends of its own range. Every ratio should sit in a narrow band.
      for (var i = 1; i < kProjectionTypeSteps.length; i++) {
        final ratio = kProjectionTypeSteps[i] / kProjectionTypeSteps[i - 1];
        expect(ratio, inInclusiveRange(1.10, 1.25),
            reason: 'step $i (${kProjectionTypeSteps[i - 1]} → '
                '${kProjectionTypeSteps[i]}) is a ${ratio}x jump, which is '
                'outside the band the rest of the ladder uses');
      }
    });

    test('clamps at both ends instead of running off the array', () {
      expect(projectionTypeStep(0, -1), 0);
      final top = kProjectionTypeSteps.length - 1;
      expect(projectionTypeStep(top, 1), top);
    });

    test('opens near the middle so the first adjustment can go either way',
        () {
      expect(kProjectionTypeDefaultStep, greaterThan(0));
      expect(kProjectionTypeDefaultStep,
          lessThan(kProjectionTypeSteps.length - 1));
    });
  });

  group('the fallback second edition', () {
    test('is in a different language from the one being read', () {
      // A bilingual congregation is this page's audience, so the useful
      // default beside a Chinese reading is an English one. Two Chinese
      // editions differing by a few characters is a comparison for a
      // desk, not for a wall.
      final second = projectionFallbackSecondVersion('cuvs-yhwh');
      expect(second, isNot('cuvs-yhwh'));
    });
  });
}
