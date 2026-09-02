import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';

/// The "Pick a verse" grid draws one chip per verse NUMBER.
///
/// Reported by the user with a screenshot, 2026-09-02: 路加福音 23 showed
/// two chips both reading "34", because 梁家鏗譯本 carries the verse as two
/// rows (`34a` and `34`) and the grid drew one chip per row. Both chips
/// jumped to the same place, so the duplicate could only confuse.
///
/// This mirrors the dedupe in `book_chapter_picker.dart` so the rule can
/// be tested without pumping a widget that needs a MainProvider, a
/// loaded Bible and a LayoutBuilder.
List<Verse> pickerChips(List<Verse> chapterRows) {
  final rows = [...chapterRows]..sort((a, b) {
      if (a.verse != b.verse) return a.verse.compareTo(b.verse);
      return a.subVerseOrder.compareTo(b.subVerseOrder);
    });
  final out = <Verse>[];
  for (final v in rows) {
    if (out.isEmpty || out.last.verse != v.verse) out.add(v);
  }
  return out;
}

void main() {
  test('the split verse yields ONE chip, and it is the first half', () {
    final rows = [
      Verse(book: '路加福音', chapter: 23, verse: 33, text: ''),
      Verse(
          book: '路加福音',
          chapter: 23,
          verse: 34,
          verseLabel: '34',
          subVerseOrder: 1,
          text: '然后，他们抓阄分了耶稣的衣袍。'),
      Verse(
          book: '路加福音',
          chapter: 23,
          verse: 34,
          verseLabel: '34a',
          subVerseOrder: 0,
          text: '耶稣说…'),
      Verse(book: '路加福音', chapter: 23, verse: 35, text: ''),
    ];
    final chips = pickerChips(rows);
    expect(chips.map((v) => v.verse), [33, 34, 35]);
    // Sorted by subVerseOrder first, so the surviving 34 is 34a — a tap
    // lands at the START of the verse, not in the middle of it.
    expect(chips[1].verseLabel, '34a');
  });

  test('reversed input order changes nothing', () {
    // The rows arrive in whatever order the asset holds them, and
    // Dart's sort is unstable for equal keys — which is exactly the
    // case here, since both halves share `verse`.
    final a = Verse(
        book: '路加福音',
        chapter: 23,
        verse: 34,
        verseLabel: '34a',
        subVerseOrder: 0,
        text: '');
    final b = Verse(
        book: '路加福音',
        chapter: 23,
        verse: 34,
        verseLabel: '34',
        subVerseOrder: 1,
        text: '');
    expect(pickerChips([a, b]).single.verseLabel, '34a');
    expect(pickerChips([b, a]).single.verseLabel, '34a');
  });

  test('an ordinary chapter is untouched', () {
    final rows = [
      for (var i = 1; i <= 10; i++)
        Verse(book: 'John', chapter: 1, verse: i, text: '')
    ];
    expect(pickerChips(rows).length, 10);
  });

  test('路加 23 draws 56 chips in every edition we ship', () {
    // The point of not lettering the chips: the grid must not change
    // shape when the reader switches version. 梁家鏗 has 57 ROWS for
    // Luke 23 and every other edition has 56; all of them must draw 56.
    const assets = [
      'assets/biblexg-v2.json',
      'assets/biblexg-v2-tr.json',
      'assets/cuvs-yhwh.json',
      'assets/kjv.json',
    ];
    for (final f in assets) {
      final all = json.decode(File(f).readAsStringSync()) as List;
      final rows = <Verse>[];
      for (final r in all.cast<Map<String, dynamic>>()) {
        final book = '${r['book']}';
        if (book != '路加福音' && book != 'Luke') continue;
        if ('${r['chapter']}' != '23') continue;
        rows.add(Verse.fromJson(r));
      }
      expect(rows, isNotEmpty, reason: '$f has no Luke 23 at all');
      expect(pickerChips(rows).length, 56, reason: f);
    }
  });
}
