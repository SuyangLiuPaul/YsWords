import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/strongs.dart';
import 'package:yswords/services/tagged_text_service.dart';
import 'package:yswords/widgets/implied_coverage_line.dart';

/// The secondary line that finally reads `TaggedRun.implied`.
///
/// The thing worth protecting here is not that a line appears — it is
/// that the line never claims more than `i` supports. `i` says the
/// stretch of original this Chinese covers ALSO contains those words;
/// it does not say the tapped word means them. So these tests pin the
/// wording, the cases the line must stay silent on, and the fact that
/// it can never print the run's own `s` back as one of the "other"
/// words.
StrongsEntry _entry(String number, String lemma, String gloss) => StrongsEntry(
      number: number,
      lemma: lemma,
      translit: '',
      pronunciation: '',
      gloss: gloss,
      definition: gloss,
      glossZh: '$gloss（中）',
      glossZhTw: '$gloss（繁）',
    );

final _lexicon = <String, StrongsEntry?>{
  'H853': _entry('H853', 'אֵת', 'untranslated object marker'),
  'H3605': _entry('H3605', 'כֹּל', 'all'),
  'H430': _entry('H430', 'אֱלֹהִים', 'God'),
  'G3588': _entry('G3588', 'ὁ', 'the'),
  // Present as a key, resolving to nothing — the shape a number takes
  // when the lexicon has no entry for it.
  'H9999': null,
};

Future<void> _pump(
  WidgetTester tester,
  TaggedRun run, {
  String locale = 'en',
  void Function(String)? onTapNumber,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ImpliedCoverageLine(
        run: run,
        lexicon: _lexicon,
        locale: locale,
        onTapNumber: onTapNumber,
      ),
    ),
  ));
}

void main() {
  group('the line appears exactly where `i` has something to say', () {
    testWidgets('a populated `i` prints one chip per number', (tester) async {
      // 創世記 1:1 「天」, as the corpus holds it.
      await _pump(
        tester,
        const TaggedRun(text: '天', strongs: 'H8064', implied: ['H853']),
      );
      expect(find.textContaining('“天” also covers'), findsOneWidget);
      expect(find.text('H853'), findsOneWidget);
      expect(find.text('אֵת'), findsOneWidget);
    });

    testWidgets('an empty `i` prints nothing at all', (tester) async {
      // 創世記 1:1 「起初，」 — no `i`, so no line, not an empty heading.
      await _pump(
        tester,
        const TaggedRun(text: '起初，', strongs: 'H7225'),
      );
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(ImpliedCoverageLine)), Size.zero);
    });

    testWidgets('several `i` entries print several chips', (tester) async {
      await _pump(
        tester,
        const TaggedRun(
            text: '的国。', strongs: 'G932', implied: ['G3588', 'H853', 'H3605']),
      );
      expect(find.text('G3588'), findsOneWidget);
      expect(find.text('H853'), findsOneWidget);
      expect(find.text('H3605'), findsOneWidget);
    });
  });

  group('it never outranks `s`', () {
    testWidgets('a number equal to the run\'s own `s` is dropped',
        (tester) async {
      // 約翰福音 3:5 「我实实在在的」 really ships as s=G281, i=["G281"].
      // Printing it under "other original words" would tell the reader
      // the span covers ἀμήν twice.
      await _pump(
        tester,
        const TaggedRun(text: '我实实在在的', strongs: 'H430', implied: ['H430']),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('the primary survives when only some of `i` is its own `s`',
        (tester) async {
      await _pump(
        tester,
        const TaggedRun(text: '神', strongs: 'H430', implied: ['H430', 'H853']),
      );
      expect(find.text('H430'), findsNothing);
      expect(find.text('H853'), findsOneWidget);
    });

    testWidgets('every part of the line is smaller than the verse it sits under',
        (tester) async {
      await _pump(
        tester,
        const TaggedRun(text: '天', strongs: 'H8064', implied: ['H853']),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final size = text.style?.fontSize;
        expect(size, isNotNull, reason: '"${text.data}" has no explicit size, '
            'so it inherits the body size and stops being subordinate');
        expect(size, lessThan(kTaggedVerseFontSize),
            reason: '"${text.data}" is $size against the verse line\'s '
                '$kTaggedVerseFontSize');
      }
    });
  });

  group('a number the lexicon cannot answer is omitted, not shown dead', () {
    testWidgets('the unresolvable one is dropped and the rest stay',
        (tester) async {
      await _pump(
        tester,
        const TaggedRun(
            text: '天', strongs: 'H8064', implied: ['H9999', 'H853']),
      );
      expect(find.text('H9999'), findsNothing);
      expect(find.text('H853'), findsOneWidget);
    });

    testWidgets('a number absent from the lexicon map entirely is dropped',
        (tester) async {
      await _pump(
        tester,
        const TaggedRun(text: '天', strongs: 'H8064', implied: ['H8888']),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('when nothing resolves there is no heading either',
        (tester) async {
      await _pump(
        tester,
        const TaggedRun(
            text: '天', strongs: 'H8064', implied: ['H9999', 'H8888']),
      );
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(ImpliedCoverageLine)), Size.zero);
    });

    testWidgets('the supplied marker H0 / G0 is not a number to show',
        (tester) async {
      await _pump(
        tester,
        const TaggedRun(text: '雅伟', strongs: 'H3068', implied: ['H0', 'G0']),
      );
      expect(find.byType(Text), findsNothing);
    });
  });

  group('the wording claims coverage and nothing more', () {
    testWidgets('all three locales name OTHER words, and disclaim identity',
        (tester) async {
      const cases = {
        'zh-Hans': ['「天」这段译文一并涵盖的其他原文词', '这不是所点词本身的编号'],
        'zh-Hant': ['「天」這段譯文一併涵蓋的其他原文詞', '這不是所點詞本身的編號'],
        'en': ['Other original words “天” also covers',
            'They are not the tapped word\'s own number.'],
      };
      for (final entry in cases.entries) {
        await _pump(
          tester,
          const TaggedRun(text: '天', strongs: 'H8064', implied: ['H853']),
          locale: entry.key,
        );
        for (final phrase in entry.value) {
          expect(find.textContaining(phrase), findsOneWidget,
              reason: '${entry.key} is missing "$phrase"');
        }
        // Nothing in any locale may say the tapped word MEANS these.
        expect(find.textContaining('or '), findsNothing);
        expect(find.textContaining('也就是'), findsNothing);
      }
    });

    testWidgets('a long run text is elided rather than pushing the chips down',
        (tester) async {
      expect(ImpliedCoverageLine.labelText('天'), '天');
      expect(ImpliedCoverageLine.labelText('〔或译："外族人"〕必住在'),
          '〔或译："外族人"〕必住…');
    });
  });

  testWidgets('a chip reaches the entry it names', (tester) async {
    final tapped = <String>[];
    await _pump(
      tester,
      const TaggedRun(text: '天', strongs: 'H8064', implied: ['H853']),
      onTapNumber: tapped.add,
    );
    await tester.tap(find.text('אֵת'));
    await tester.pump();
    expect(tapped, ['H853']);
  });

  test('visibleNumbers is the single rule the census can reuse', () {
    expect(
      ImpliedCoverageLine.visibleNumbers(
        const TaggedRun(
          text: '天',
          strongs: 'H853',
          implied: ['H853', 'H0', 'H9999', 'H3605', 'H3605'],
        ),
        _lexicon,
      ),
      ['H3605'],
      reason: 'own `s`, supplied marker, unresolvable and duplicate all go',
    );
  });
}
