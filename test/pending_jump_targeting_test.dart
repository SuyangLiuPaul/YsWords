import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/providers/main_provider.dart';

/// 2026-08-23, from the user: "I use AI to search … if I click it won't
/// jump into the words straight away … it won't jump to the correct
/// place."
///
/// Measured in a release build on dev with the reader's own forensic
/// logging turned up. The tap was never the problem — it prepared the
/// jump correctly every time:
///
///     [prepareJumpToVerse] verse=Ezekiel 34:15  relIdx=14
///     *** and then not one further reading-pane build ***
///
/// The search page is a full route, so the reader behind it is not
/// listening when `setPendingJump` notifies, and the `Get.off(HomePage)`
/// that follows does not guarantee a fresh build of that Consumer. One
/// notification, delivered to nobody, and the scroll was never
/// scheduled — the reader opened the right chapter at verse 1.
///
/// The fix re-announces the jump across the navigation. That is only
/// safe if a jump can be refused by a reader showing a different
/// chapter, which is what most of this file pins down.
void main() {
  // setCurrentChapter persists the reading position, so the plugin has
  // to answer before these tests can touch it.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MainProvider mp;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mp = MainProvider();
  });

  group('a jump knows which chapter it was computed for', () {
    test('the right chapter takes it', () {
      mp.setPendingJump(chapterVerseIndex: 14, book: 'Ezekiel', chapter: 34);
      expect(mp.consumePendingJumpFor('Ezekiel', 34), 14);
      expect(mp.hasPendingJump, isFalse);
    });

    test('a different chapter refuses it AND leaves it pending', () {
      // The dangerous case: index 14 means nothing on its own. A reader
      // still showing 1 Chronicles 29 would have scrolled to whatever
      // sat at offset 14 there and highlighted it — a wrong verse
      // presented as the one the user asked for.
      mp.setPendingJump(chapterVerseIndex: 14, book: 'Ezekiel', chapter: 34);
      expect(mp.consumePendingJumpFor('1 Chronicles', 29), isNull);
      expect(mp.hasPendingJump, isTrue,
          reason: 'the reader that CAN honour it must still get its turn');
      expect(mp.consumePendingJumpFor('Ezekiel', 34), 14);
    });

    test('same chapter number in another book is still a refusal', () {
      mp.setPendingJump(chapterVerseIndex: 2, book: 'John', chapter: 3);
      expect(mp.consumePendingJumpFor('1 John', 3), isNull);
      expect(mp.consumePendingJumpFor('John', 3), 2);
    });

    test('a jump recorded without a target is taken by anyone', () {
      // Backwards compatibility: callers that predate targeting behave
      // exactly as they did.
      mp.setPendingJump(chapterVerseIndex: 7);
      expect(mp.consumePendingJumpFor('Anything', 99), 7);
    });
  });

  group('re-announcing is safe to repeat', () {
    test('renotify fires listeners only while a jump is outstanding', () {
      var builds = 0;
      mp.addListener(() => builds++);

      mp.renotifyPendingJump();
      expect(builds, 0, reason: 'nothing pending — must not wake the reader');

      mp.setPendingJump(chapterVerseIndex: 9, book: 'Proverbs', chapter: 18);
      final afterSet = builds;
      mp.renotifyPendingJump();
      mp.renotifyPendingJump();
      expect(builds, afterSet + 2);

      mp.consumePendingJumpFor('Proverbs', 18);
      final afterConsume = builds;
      mp.renotifyPendingJump();
      mp.renotifyPendingJump();
      expect(builds, afterConsume,
          reason: 'once taken, the ladder must go quiet — otherwise every '
              'jump costs four extra rebuilds of the whole reader');
    });
  });

  group('a chapter change does NOT drop a pending jump', () {
    // This was the opposite for one build, and it broke the fix it
    // shipped with. Things call setCurrentChapter DURING the very
    // navigation a jump is waiting on — the route/URL sync on a fresh
    // HomePage, the chapter pager settling — each naming the chapter
    // being left rather than the one being opened. Clearing on any
    // mismatch destroyed the jump before the reader that wanted it had
    // built, and Matthew 12:36 opened at verse 1 exactly as before the
    // fix. Staleness is bounded by the announcement window instead.
    test('the jump survives an unrelated chapter being set', () {
      mp.setPendingJump(chapterVerseIndex: 35, book: 'Matthew', chapter: 12);
      mp.setCurrentChapter(book: '1 John', chapter: 2);
      expect(mp.hasPendingJump, isTrue,
          reason: 'the reader passes through other chapters on its way '
              'to the one the jump is for');
      expect(mp.consumePendingJumpFor('1 John', 2), isNull);
      expect(mp.consumePendingJumpFor('Matthew', 12), 35);
    });

    test('and survives its own chapter being set, which is the real order',
        () {
      mp.setCurrentChapter(book: 'Matthew', chapter: 12);
      mp.setPendingJump(chapterVerseIndex: 35, book: 'Matthew', chapter: 12);
      mp.setCurrentChapter(book: 'Matthew', chapter: 12);
      expect(mp.consumePendingJumpFor('Matthew', 12), 35);
    });
  });
}
