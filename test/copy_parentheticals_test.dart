import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/models/app_settings.dart';

/// 2026-09-13: 「好像这里面有原文（）这个复制粘贴要不要包含应该在setting
/// 有一个option toggle」.
///
/// The CUV sets its translators' notes in full-width parentheses inside
/// the verse — 「健壮的（原文作活泼的）」 — and 1,215 Simplified verses
/// carry one. Whether a copy keeps them is now a setting. These pin the
/// three things that must stay true: the strip is opt-in, it takes only
/// the full-width pair, and the setting survives a restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const exodus1v19 =
      '收生婆对法老说：因为希伯来妇人与埃及妇人不同；希伯来妇人本是健壮的（原文作活泼的），收生婆还没有到，她们已经生产了。';

  group('the sanitiser', () {
    test('keeps the note by default — no copy anyone ever made changes',
        () {
      expect(sanitizeForCopy(exodus1v19), contains('（原文作活泼的）'));
      expect(sanitizeVerseText(exodus1v19), contains('（原文作活泼的）'));
    });

    test('drops the note only when asked, and leaves clean punctuation', () {
      final out = sanitizeForCopy(exodus1v19, stripParentheticals: true);
      expect(out, isNot(contains('原文作')));
      expect(out, contains('健壮的，收生婆'),
          reason: 'the comma that followed the note must survive it');
      expect(sanitizeVerseText(exodus1v19, stripParentheticals: true),
          isNot(contains('（')));
    });

    test('a place-name gloss goes the same way', () {
      const gen14v8 = '和比拉王（比拉就是琐珥）都出来，在西订谷摆阵';
      expect(sanitizeForCopy(gen14v8, stripParentheticals: true),
          '和比拉王都出来，在西订谷摆阵');
    });

    test('ASCII parentheses are scripture in the English editions and stay',
        () {
      // NASB / CSB set real clauses in them; matching both pairs would
      // delete text to remove apparatus.
      const nasb = 'for the Lord (that is, the one who was to come) said';
      expect(sanitizeForCopy(nasb, stripParentheticals: true), nasb);
    });

    test('a note bracketed by the same punctuation does not leave a double',
        () {
      const s = '俄梅戛，（就是首先的），是昔在';
      final out = sanitizeForCopy(s, stripParentheticals: true);
      expect(out, isNot(contains('，，')));
    });
  });

  group('the setting', () {
    test('is off by default and persists once set', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.loadSettings();
      expect(settings.copyStripParentheticals, isFalse);

      await settings.setCopyStripParentheticals(true);
      final again = AppSettings();
      await again.loadSettings();
      expect(again.copyStripParentheticals, isTrue,
          reason: 'a choice made in Settings must be there next week');
    });
  });

  group('every copy path consults it', () {
    // Source assertions rather than widget drives: the paths are
    // scattered across four files and a future one that forgets the
    // flag would leave the toggle half-true, which is worse than
    // missing. The thing being pinned is the WIRING.
    test('the reading pane, the number tap, the popup sheet, the preview',
        () {
      final pane =
          File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
      expect(pane.contains('stripParentheticals: strip'), isTrue,
          reason: 'the three copy formats must pass the setting');
      final spans =
          File('lib/utils/build_verse_content_spans.dart').readAsStringSync();
      expect(spans.contains('stripParentheticals: settings.copyStripParentheticals'),
          isTrue, reason: 'the single-verse number-tap copy');
      final sheet =
          File('lib/widgets/verse_popup_sheet.dart').readAsStringSync();
      expect(sheet.contains('stripParentheticals: strip'), isTrue,
          reason: 'the popup sheet\'s copy-all');
      final page = File('lib/pages/settings_page.dart').readAsStringSync();
      expect(page.contains('stripParentheticals: settings.copyStripParentheticals'),
          isTrue, reason: 'the preview must show what the copy will do');
    });
  });
}
