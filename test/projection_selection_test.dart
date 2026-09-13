import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/projection_page.dart';

/// 2026-09-13: 「按了verse之后有一个按键for projector 可以按一个或者多个
/// 然后就project」, and the Settings pairing 「如果中文…英文翻译用哪个版本
/// 英文那个中文译本」.
///
/// The projection used to open only on the reader's position, one verse
/// at a time, with a second edition borrowed from split view. Now a
/// selection in the reader opens it on that block, and the companion
/// edition is chosen per language, once, in Settings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Verse v(int n, {String book = '创世纪', int chapter = 1}) => Verse.fromJson({
        'book': book,
        'chapter': chapter,
        'verse': n,
        'text': 'verse $n',
      });

  group('a selection becomes a block on the wall', () {
    int? chapterOf(String book, int chapter) => chapter - 1;
    int indexOf(int chapterIndex, Verse verse) => verse.verse - 1;

    test('one verse is a block of one', () {
      final c = projectionCursorFromSelection([v(5)],
          chapterIndexOf: chapterOf, verseIndexOf: indexOf);
      expect(c, const ProjectionCursor(0, 4));
      expect(c!.count, 1);
    });

    test('a contiguous run is one block, whatever order it was tapped in',
        () {
      final c = projectionCursorFromSelection([v(7), v(5), v(6)],
          chapterIndexOf: chapterOf, verseIndexOf: indexOf);
      expect(c, const ProjectionCursor(0, 4, count: 3));
    });

    test('a gap ends the block; what follows is the next key press', () {
      final c = projectionCursorFromSelection([v(5), v(6), v(9)],
          chapterIndexOf: chapterOf, verseIndexOf: indexOf);
      expect(c, const ProjectionCursor(0, 4, count: 2),
          reason: 'verse 9 is not lost, it is simply not on the wall yet');
    });

    test('a second chapter ends the block too', () {
      final c = projectionCursorFromSelection(
          [v(31), v(1, chapter: 2)],
          chapterIndexOf: chapterOf, verseIndexOf: indexOf);
      expect(c!.count, 1);
    });

    test('next continues from the END of the block, as a single verse', () {
      const block = ProjectionCursor(0, 4, count: 3);
      final next = projectionVerseStep(block.tail, 1,
          chapterCount: 50, versesIn: (_) => 31);
      expect(next, const ProjectionCursor(0, 7),
          reason: 'the selection was what the operator wanted shown; '
              'after it comes ordinary reading');
    });

    test('a selection the corpus cannot place opens on the reader instead',
        () {
      final c = projectionCursorFromSelection([v(5)],
          chapterIndexOf: (_, __) => null, verseIndexOf: indexOf);
      expect(c, isNull);
    });
  });

  group('the companion edition is chosen by the passage\'s language', () {
    test('is unset by default, persists per language, and survives a restart',
        () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.loadSettings();
      expect(s.projectionCompanionFor('zh-Hans'), isNull);

      await s.setProjectionCompanion('zh-Hans', 'nasb');
      await s.setProjectionCompanion('en', 'cuvs-yhwh');

      final again = AppSettings();
      await again.loadSettings();
      expect(again.projectionCompanionFor('zh-Hans'), 'nasb');
      expect(again.projectionCompanionFor('en'), 'cuvs-yhwh');
      expect(again.projectionCompanionFor('zh-Hant'), isNull,
          reason: 'each language is its own choice');
    });

    test('a corrupt stored blob yields no pairings, not a crash', () {
      expect(decodeProjectionCompanions('not json'), isEmpty);
      expect(decodeProjectionCompanions('[1,2]'), isEmpty);
      expect(decodeProjectionCompanions('{"en": 3}'), isEmpty);
      expect(decodeProjectionCompanions('{"en": "cuvs"}'), {'en': 'cuvs'});
    });
  });

  group('the wiring', () {
    test('the selection bar has the button and the page takes the verses',
        () {
      final pane =
          File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
      expect(pane.contains("uiStrings['projectSelection']"), isTrue,
          reason: 'the Project button on the selection bar');
      expect(pane.contains('ProjectionPage(\n'), isTrue);
      expect(
          RegExp(r'verses:\s*mainProvider\.selectedVerses\.toList\(\)')
              .hasMatch(pane),
          isTrue,
          reason: 'the button opens the projection ON the selection');
      final page = File('lib/pages/projection_page.dart').readAsStringSync();
      expect(page.contains('projectionVerseStep(from.tail, 1,'), isTrue,
          reason: 'next steps from the end of the block');
    });
  });
}
