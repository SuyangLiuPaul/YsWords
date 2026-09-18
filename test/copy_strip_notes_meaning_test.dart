// What the "leave out translators' notes" switch actually governs.
//
// 2026-09-15. The owner turned it on, copied 出埃及记 19:21, and asked
// 「这个开了为什么复制后还是这样没有原文是」 — then 「还是我弄错地方 你给我
// 个example」.
//
// Nothing was wrong with the switch. Two different things had been
// conflated, by a hint that named a third:
//
//   • `<note: …>` — the ① ② ③ markers the 雅伟版 carries, drawn under
//     the verse and NEVER copied, whatever this switch says. 出埃及记
//     19:21 has three of them and no parentheses, so it was the one
//     verse in the chapter that could not show a difference.
//   • `（…）` — full-width parentheses INSIDE the verse, which is what
//     the switch removes. 82 of this edition's 343 are 「（细拉）」 and
//     the psalm superscriptions.
//   • 「（原文作…）」 — what the hint named, and what this edition
//     contains exactly none of.
//
// This file pins all three, so the hint can never drift back into
// describing something the reader cannot find.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/text_patterns.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';

late List<Map<String, dynamic>> _cuv;

String _text(String book, int chapter, int verse) => _cuv
    .firstWhere((v) =>
        v['book'] == book &&
        v['chapter'] == '$chapter' &&
        v['verse'] == '$verse')['text'] as String;

void main() {
  setUpAll(() {
    _cuv = (jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();
  });

  test('the verse the owner tested could not have shown a difference', () {
    // 出埃及记 19:21 — three `<note:>` notes, no parentheses.
    final raw = _text('出埃及记', 19, 21);
    expect(raw, contains('<note:'));
    expect(parentheticalNotePattern.hasMatch(raw), isFalse);
    expect(
      sanitizeForCopy(raw, stripParentheticals: true),
      sanitizeForCopy(raw, stripParentheticals: false),
      reason: 'if these ever differ the diagnosis above is wrong',
    );
  });

  test('the ① notes are left out whether the switch is on or off', () {
    final copied = sanitizeForCopy(_text('出埃及记', 19, 21));
    expect(copied, isNot(contains('原文是')));
    expect(copied, isNot(contains('<note')));
    expect(copied, contains('恐怕他们有多人死亡'),
        reason: 'stripping the note must not take the verse with it');
  });

  test('the reference the hint names is a verse the switch changes', () {
    // 出埃及记 30:13 — the example the hint sends the reader to. If this
    // verse ever loses its parenthetical, the hint is pointing at
    // nothing and has to be repointed.
    final raw = _text('出埃及记', 30, 13);
    final kept = sanitizeForCopy(raw, stripParentheticals: false);
    final stripped = sanitizeForCopy(raw, stripParentheticals: true);
    expect(kept, contains('一舍客勒是二十季拉'));
    expect(stripped, isNot(contains('一舍客勒是二十季拉')));
    expect(stripped, contains('这半舍客勒是奉给雅伟的礼物。'),
        reason: 'the sentence has to close cleanly once the aside is '
            'gone — a dangling 「，。」 is what the collapse pass is for');
  });

  test('the hint names a form the edition actually contains', () {
    final hint = uiStrings['copyStripNotesHint']!['zh-Hans']!;
    final parentheticals = <String>[
      for (final v in _cuv)
        ...parentheticalNotePattern.allMatches(v['text'] as String).map(
              (m) => m.group(0)!,
            ),
    ];
    expect(parentheticals, isNotEmpty);
    // The old hint said 「（原文作…）」. There is not one in the book.
    expect(parentheticals.any((p) => p.contains('原文作')), isFalse,
        reason: 'if this edition gains 「（原文作…）」 the old hint was '
            'right after all and this test should say so');
    expect(hint, isNot(contains('原文作')),
        reason: 'the hint is naming a form no reader can find');
    expect(hint, contains('细拉'),
        reason: 'the hint should name the form the reader will actually '
            'meet — 「（细拉）」 is the commonest of the 343');
  });

  test('the chapter the hint points at is not a chapter the card calls '
      'empty', () {
    // 2026-09-15, the same reader, an hour later, over 出埃及记 30:
    // 「这个toggled on但是却没有包含」 — the card printed 「这一章没有这类
    // 括号说明」 on the very chapter whose verse 13 the hint above sends
    // people to.
    //
    // The cause was scope: the card tested the THREE VERSES THE PREVIEW
    // SAMPLES and printed a claim about the whole chapter, and 出 30:13
    // sits eleven verses below the three it shows. So this asserts the
    // shape of the trap rather than the wording of the fix: a chapter
    // whose parenthetical is outside the first three verses.
    final chapter = [
      for (final v in _cuv)
        if (v['book'] == '出埃及记' && v['chapter'] == '30') v,
    ];
    expect(chapter, isNotEmpty, reason: 'the fixture chapter is missing');

    bool hasNote(Map<String, dynamic> v) =>
        parentheticalNotePattern.hasMatch(v['text'] as String);

    final firstThree = chapter.take(3).where(hasNote);
    final anywhere = chapter.where(hasNote);
    expect(firstThree, isEmpty,
        reason: 'the preview samples three verses and this chapter must '
            'still be one whose parenthetical is out of shot — otherwise '
            'this test no longer exercises the bug');
    expect(anywhere, isNotEmpty,
        reason: 'a card that reads only the sample would call this '
            'chapter empty, which is what was reported');
    expect((anywhere.first['verse'] as String), '13',
        reason: 'the hint names 出埃及记 30:13 by number; if the first '
            'parenthetical in the chapter moves, the hint has to move '
            'with it');
  });

  test('every locale says the same thing about the ① notes', () {
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      final hint = uiStrings['copyStripNotesHint']![locale]!;
      expect(hint, contains('①'),
          reason: 'the $locale hint does not say that the numbered notes '
              'are outside this switch, which is the confusion it exists '
              'to prevent');
    }
  });
}
