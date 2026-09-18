// A verse's notes: one numbered block, folded, with the control at the
// end of the text rather than on a row of its own.
//
// 2026-09-14. This replaces TWO tests written earlier the same day —
// `note_expands_in_place_test.dart`, for a design where tapping a
// marker opened that one note inside the sentence, and
// `block_note_collapses_test.dart`, for a chevron row. Both were
// answers to 「当注释很多可以expand close这样」 and both were wrong
// about how. The owner opened the 雅偉的話 app and said so:
//
//   「yahwehdehua app apk的 close和expand连在一起的其实设计得非常合理
//    而sword 看到的是根本不行的 要用adopt yahwehdehua这个设计」
//
// and named three separate faults with what this app had:
//
//   「根本看不清」        the notes had no structure
//   「para mode不好按」   the tap target was an icon a few px wide
//   「你就截开几段用起来很难受」  opening one cut the verse into pieces
//
// So the assertions below are those three complaints, one test each,
// plus the detail the owner singled out — the label is IN the paragraph,
// immediately after the truncated text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/widgets/verse_notes_block.dart';

const _short = '參4.6、16';
const _long = '26-27节注：“灵也在我们的软弱中帮助我们……但灵亲自替我们代求'
    '……明了灵强烈的诉求”。其中“灵”皆译自 τὸ πνεῦμα，原文并无“圣”字，'
    '和合本加插了“圣”字来指圣灵。当原文只写 πνεῦμα 一个字而没有明指'
    '“圣灵”时，本译本一律译作“灵”。参上文2节注。';
const _second = '在新约圣经中，和合本将“灵”译作了“圣灵”的所有经文列举如下：'
    '约14.17，15.26，16.13，罗8.4-6、11、13、16、23、26-27。';

Widget _host(List<String> notes, AppSettings settings, {int? preview}) =>
    MaterialApp(
      home: Scaffold(
        // Scrollable, because every real caller is: six long notes fully
        // open are taller than a phone, which is the whole reason the
        // pill exists.
        body: SingleChildScrollView(
          child: SizedBox(
          width: 360,
          child: VerseNotesBlock(
            notes: notes,
            settings: settings,
            locale: 'zh-Hans',
            preview: preview ?? kNotePreviewChars,
          ),
          ),
        ),
      ),
    );

/// The notes themselves, as plain characters — not the pill's label.
/// Each note is its own Text beside its own number, so this joins them
/// the way the block reads. Empty when shut, which is itself an
/// assertion several of these tests make.
String _rendered(WidgetTester tester) {
  final out = <String>[];
  var number = '';
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final s = t.data ?? t.textSpan?.toPlainText() ?? '';
    if (s.isEmpty || s.contains('译者注')) continue;
    if (isNoteMarkerText(s)) {
      number = s;
      continue;
    }
    out.add('$number\u00A0$s');
    number = '';
  }
  return out.join('\n');
}

void main() {
  late AppSettings settings;

  setUp(() => settings = AppSettings());

  testWidgets('「根本看不清」 — every note is numbered, one to a line',
      (tester) async {
    await tester.pumpWidget(_host([_short, _second], settings));
    final text = _rendered(tester);
    expect(text, startsWith('①'), reason: 'the first note is numbered ①');
    expect(text, contains('\n②'),
        reason: 'the second starts a line of its own, numbered ② — run '
            'together they are a wall with nothing to say where one ends');
  });

  testWidgets('the numbers are CIRCLED, and keep counting past nine',
      (tester) async {
    // 2026-09-15: 「这个看起来很confuse 你可能右上角 圈圈数字」. A bare
    // superscript was the wrong glyph: the verse numbers in this reader
    // are also small raised numbers, so a run of note markers sitting
    // before a verse number was two numbering systems in one string
    // with nothing to tell them apart.
    await tester.pumpWidget(_host(
        [for (var i = 1; i <= 12; i++) 'note $i'], settings));
    expect(_rendered(tester), contains('⑫'));
    // 26 is 梁家鏗's worst verse; the circled range reaches 50, and
    // past that it falls back rather than printing a box.
    expect(superscriptNumber(26), '㉖');
    expect(superscriptNumber(50), '㊿');
    expect(superscriptNumber(51), '⁵¹');
  });

  testWidgets('「不好按」 — the control is a pill, and it is the only one',
      (tester) async {
    await tester.pumpWidget(_host([_long, _second], settings));
    // 2026-09-14, second pass: the owner circled the 雅偉的話 WEB
    // reader's control, which is a bordered pill reading 「译者注 ▾」.
    // The first pass had an underlined run of words at the end of the
    // truncated text; a pill reads as pressable before it is pressed.
    expect(find.text('译者注 ▾'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    // Shut means shut: no half-note behind the pill.
    expect(find.textContaining('26-27节注'), findsNothing);
  });

  testWidgets('the pill fills and flips its triangle when open',
      (tester) async {
    await tester.pumpWidget(_host([_long, _second], settings));
    await tester.tap(find.text('译者注 ▾'));
    await tester.pumpAndSettle();
    expect(find.text('译者注 ▴'), findsOneWidget);
    expect(find.text('译者注 ▾'), findsNothing);
  });

  testWidgets('open shows ALL of the notes, not a truncated head',
      (tester) async {
    // The other half of the second pass. A note cut off at 160
    // characters and ending in `…` is not something anyone wanted to
    // read; the reader either wants the apparatus or does not.
    await tester.pumpWidget(_host([_long, _second], settings));
    await tester.tap(find.text('译者注 ▾'));
    await tester.pumpAndSettle();
    final text = _rendered(tester);
    expect(text, contains(_long));
    expect(text, contains(_second));
    // The last note ends where the note ends. `…` appears INSIDE these
    // notes (it is Chinese punctuation), so the assertion is that the
    // block is not cut, not that the character is absent.
    expect(text, endsWith(_second));
  });

  testWidgets('folded by default, and folded means shorter', (tester) async {
    // Six notes, not two: the ratio is the assertion, and 梁家鏗's real
    // verses carry six and twenty-six. With two the fold saves a third
    // of the height and the test could pass on a block that barely
    // folded at all.
    await tester.pumpWidget(
        _host([_long, _second, _long, _second, _long, _second], settings));
    final folded = tester.getSize(find.byType(VerseNotesBlock)).height;

    await tester.tap(find.text('译者注 ▾'));
    await tester.pumpAndSettle();
    final open = tester.getSize(find.byType(VerseNotesBlock)).height;

    expect(open, greaterThan(folded * 2),
        reason: 'folded $folded px, open $open px — if these are close, '
            'nothing was actually folded');
    expect(_rendered(tester), contains(_second),
        reason: 'the second note is only reachable once open');
  });

  testWidgets('a note short enough to read whole is never folded',
      (tester) async {
    // The preview is 160 characters precisely so that the common case —
    // a cross-reference, a one-line gloss — is simply shown. A block
    // that folded everything would make the reader work for 參4.6、16.
    await tester.pumpWidget(_host([_short], settings));
    final text = _rendered(tester);
    expect(text, '① $_short');
    expect(text, isNot(contains('展开')));
  });

  testWidgets('no notes, no block — a caller can place it unconditionally',
      (tester) async {
    await tester.pumpWidget(_host(const [], settings));
    expect(find.byType(Text), findsNothing);
    // Zero HEIGHT: the width is whatever the caller's column gives it.
    expect(tester.getSize(find.byType(VerseNotesBlock)).height, 0);
  });

  testWidgets('a different verse in the same slot folds again',
      (tester) async {
    await tester.pumpWidget(_host([_long, _second], settings));
    await tester.tap(find.text('译者注 ▾'));
    await tester.pumpAndSettle();
    expect(find.text('译者注 ▴'), findsOneWidget);

    await tester.pumpWidget(_host([_second, _long], settings));
    await tester.pumpAndSettle();
    expect(find.text('译者注 ▾'), findsOneWidget,
        reason: 'scrolling to another verse must not inherit the last '
            'one\'s open state');
  });
}
