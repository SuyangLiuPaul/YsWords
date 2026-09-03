import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Three verses of the word-tap corpus closed a quotation they never opened.
///
/// `assets/tagged/cuvs-yhwh/` holds 6,435 `“` against 5,840 `”`, and almost
/// none of that surplus is a defect: this edition routinely opens a quotation
/// in one verse and closes it in another, or never. Counting per book, with
/// the corpus's `〔…〕` note markup stripped, **604 opens are still on the
/// stack at the end of their book** — 申命記 115, 利未記 90, 路加福音 83,
/// 以西結書 70, 出埃及記 60 — and the frozen reading asset punctuates half of
/// the affected verses in exactly the same way. It is house style, not loss.
///
/// The tractable cut is the other direction: a `”` that arrives with nothing
/// open. There were **nine** such events. Four are marks the FROZEN reading
/// asset carries identically (出 3:5, 得 1:17, 可 5:34, 西 1:23) and cannot be
/// repaired here without making the word-tap sheet disagree with the pane
/// behind it. Five lived in three verses the reading asset does not punctuate
/// at all, and `tools/repair_tagged_orphan_close_quote.py` fixed those.
///
/// The invariant worth holding is not the count. It is that **every orphan
/// closer left in the corpus is one the frozen edition also carries** — the
/// last test below asserts exactly that, so a newly-imported orphan fails even
/// if some other one is fixed on the same day and the total stays at four.
void main() {
  const books = <String>[
    'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
    'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
    '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
    'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
    'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
    'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah', 'haggai',
    'zechariah', 'malachi', 'matthew', 'mark', 'luke', 'john', 'acts',
    'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
    'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
    '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews', 'james',
    '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude', 'revelation',
  ];

  const open = '“';
  const close = '”';
  final taggedNote = RegExp('〔[^〕]*〕');
  final ourNote = RegExp(r'<note:[^>]*>');

  Map<String, dynamic> book(String slug) => json.decode(
        File('assets/tagged/cuvs-yhwh/$slug.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  String line(String slug, String ref) =>
      ((book(slug)[ref] as List).cast<Map>())
          .map((r) => r['w'] as String)
          .join();

  /// Verse keys of one book in canonical order.
  List<String> refs(Map<String, dynamic> decoded) {
    final keys = decoded.keys.toList();
    int chapter(String k) => int.parse(k.split(':')[0]);
    int verse(String k) => int.parse(k.split(':')[1]);
    keys.sort((a, b) => chapter(a) == chapter(b)
        ? verse(a).compareTo(verse(b))
        : chapter(a).compareTo(chapter(b)));
    return keys;
  }

  /// `(orphan closers, opens left on the stack)` for one book.
  (List<String>, int) walk(String slug) {
    final decoded = book(slug);
    final orphans = <String>[];
    var depth = 0;
    for (final ref in refs(decoded)) {
      final text = (decoded[ref] as List)
          .cast<Map>()
          .map((r) => r['w'] as String)
          .join()
          .replaceAll(taggedNote, '');
      for (final ch in text.split('')) {
        if (ch == open) {
          depth++;
        } else if (ch == close) {
          if (depth > 0) {
            depth--;
          } else {
            orphans.add('$slug $ref');
          }
        }
      }
    }
    return (orphans, depth);
  }

  test('the three repaired verses set an opening mark, not a closing one', () {
    // `：”` cannot stand at a speech colon: there is nothing open for it to
    // close. It occurred exactly twice in the corpus against 5,096 `：“`.
    expect(line('1_samuel', '23:7'),
        contains('扫罗说：$open他进了'));
    expect(line('amos', '9:13'),
        contains('雅伟说：$open日子将到'));
    // 以西結書 3:4 lost its opener; 3:9 still carries the closer for it.
    expect(line('ezekiel', '3:4'),
        startsWith('他对我说：$open人'));
    expect(line('ezekiel', '3:9'), endsWith('惊惶。$close'));
  });

  test('no speech colon in the corpus is followed by a closing mark', () {
    // The whole class, not the two instances. Before the repair the corpus
    // held 5,096 `：“` and TWO `：”`; the reading assets hold zero `：”` in
    // either script. After it, 5,099 and none — the two substitutions plus
    // 以西結書 3:4's restored opener.
    final colonThenClose = RegExp('：[$close’]');
    var openers = 0;
    final hits = <String>[];
    for (final slug in books) {
      final decoded = book(slug);
      for (final entry in decoded.entries) {
        final text = (entry.value as List)
            .cast<Map>()
            .map((r) => r['w'] as String)
            .join();
        openers += '：$open'.allMatches(text).length;
        if (colonThenClose.hasMatch(text)) hits.add('$slug ${entry.key}');
      }
    }
    expect(hits, isEmpty);
    expect(openers, 5099);
  });

  test('the repairs moved punctuation only', () {
    // The ideograph stream of all three verses is unchanged, which is what
    // keeps a punctuation repair from becoming a claim about the text.
    String ideographs(String s) => String.fromCharCodes(
        s.codeUnits.where((u) => u >= 0x3400 && u <= 0x9fff));
    expect(
        ideographs(line('ezekiel', '3:4')),
        '他对我说人子啊你往以色'
        '列家那里去将我的话对他'
        '们讲说');
    // 以西結書 3:4 keeps its H559 and its H8799 on the run the mark joined.
    final run = ((book('ezekiel')['3:4'] as List).cast<Map>()).first;
    expect(run['s'], 'H559');
    expect(run['g'], <String>['H8799']);
  });

  test('撒母耳記上 and 阿摩司書 now reconcile over the whole book', () {
    for (final slug in <String>['1_samuel', 'amos']) {
      final (orphans, depth) = walk(slug);
      expect(orphans, isEmpty, reason: '$slug still closes what it never opens');
      expect(depth, 0, reason: '$slug still leaves a quotation open');
    }
  });

  test('the census figures the triage was built on', () {
    var orphans = 0;
    var unclosed = 0;
    var unreconciled = 0;
    final perBook = <String, int>{};
    for (final slug in books) {
      final (hits, depth) = walk(slug);
      orphans += hits.length;
      unclosed += depth;
      perBook[slug] = depth;
      if (hits.isNotEmpty || depth != 0) unreconciled++;
    }
    // Nine before the repair, four after.
    expect(orphans, 4);
    // 35 before, 33 after: 撒母耳記上 and 阿摩司書 are whole now. The rest is
    // this edition's house style and is not a defect to chase.
    expect(unreconciled, 33);
    expect(unclosed, 604);
    expect(perBook['deuteronomy'], 115);
    expect(perBook['leviticus'], 90);
    expect(perBook['luke'], 83);
    expect(perBook['ezekiel'], 70);
    expect(perBook['exodus'], 60);
  });

  test('every orphan closer left is one the FROZEN reading asset also carries',
      () {
    // The real invariant. A count can stay at four while one orphan is fixed
    // and a new one imported; this cannot. Anything the reading asset does not
    // corroborate is ours and has to be looked at.
    final ours = <String, String>{};
    for (final row
        in (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>()) {
      ours[row['id'] as String] = row['text'] as String;
    }
    final uncorroborated = <String>[];
    for (var n = 0; n < books.length; n++) {
      final (hits, _) = walk(books[n]);
      for (final hit in hits) {
        final ref = hit.split(' ').last;
        final parts = ref.split(':');
        final id = '${(n + 1).toString().padLeft(3, '0')}'
            '${parts[0].padLeft(3, '0')}${parts[1].padLeft(3, '0')}';
        final theirs = (ours[id] ?? '').replaceAll(ourNote, '');
        final mine =
            line(books[n], ref).replaceAll(taggedNote, '');
        if (open.allMatches(theirs).length != open.allMatches(mine).length ||
            close.allMatches(theirs).length != close.allMatches(mine).length) {
          uncorroborated.add(hit);
        }
      }
    }
    expect(uncorroborated, isEmpty);
  });

  test('詩篇 11:1 is left exactly as imported', () {
    // The one verse in 2,488 where the two imports punctuate the SAME verse
    // differently, and it is a disagreement about scope rather than a lost
    // mark: the frozen edition closes the taunt at the end of 11:1, the tagged
    // corpus runs it to 11:3, and both are complete quotations. Blob 7a2dc43
    // punctuates Psalm 11 not at all, so there is no third line to break the
    // tie. Held under the 使徒行傳 9:29 rule in
    // docs/cuv-yhwh-publisher-notes.md — ask the publisher, do not guess.
    expect(line('psalms', '11:1'), endsWith('你的山去。'));
    expect(line('psalms', '11:1'), contains('说：$open'));
    expect(line('psalms', '11:3'), endsWith('呢？$close'));
  });
}
