import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Traditional CUV is a script conversion of the Simplified one, and the
/// converter that produced it had no mapping for the classifier 只 → 隻: the
/// file carried **zero** 隻 across 31,102 verses. So 以賽亞書 2:16 printed
/// 「他施的船只」, and 548 measure words — 「一只公牛」, 「兩只眼」,
/// 「那幾只羊」 — stood in the simplified form in a Traditional Bible.
///
/// Every structural check this repo already had passed on that data, because
/// they ask whether a verse exists, not whether its characters belong to the
/// script the edition claims. This one asks the script question.
///
/// The counts below are not arbitrary. They were settled against a separately
/// imported edition of the same base text — `assets/cuv-tr.json`, the plain
/// 和合本 Traditional, dropped from the repo at v1.4.5 but readable from git
/// as blob `7a2dc43` (`git cat-file -p 7a2dc43`). It has 548 隻, and after the
/// repair every verse agrees with it on the 只/隻 sequence except five that
/// are explained: 馬可福音 9:43-46, where this edition splits vv.44/46 into
/// 「有些抄本」 notes, and a note wording at 路加福音 11:2 (「有古卷只作」,
/// which is the adverb). That is why 只 is 671 here and 670 there.
void main() {
  const path = 'assets/cuvs-yhwh-tr.json';

  /// A classifier is nearly always preceded by one of these.
  const cues = '一二兩三四五六七八九十百千萬幾數每那這船';

  /// The one place a cue is followed by the ADVERB rather than a classifier:
  /// 「脫離那只在今生有福分的世人」 — those whose portion is only in this
  /// life. opencc converts it and is wrong; 以賽亞書 29:17「不是只有一點點
  /// 時候嗎」 is the other adverb opencc gets wrong, but 不 is not a cue so it
  /// never reaches this check.
  const adverbAfterCue = '那只在今生';

  late List<Map<String, dynamic>> verses;

  setUpAll(() => verses = (json.decode(File(path).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>());

  test('no classifier is left in its simplified form', () {
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (var i = 1; i < text.length; i++) {
        if (text[i] != '只' || !cues.contains(text[i - 1])) continue;
        if (text.startsWith(adverbAfterCue, i - 1)) continue;
        final window = text.substring(
            (i - 3).clamp(0, text.length), (i + 3).clamp(0, text.length));
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $window');
      }
    }
    expect(offenders, isEmpty,
        reason: 'these read as 「一只羊」 in a Traditional edition; the '
            'classifier is 隻. Re-run tools/repair_tr_classifier.py.');
  });

  test('a classifier with no numeral in front is still converted', () {
    // 民數記 15:12「按著隻數都要這樣辦理」 — 隻數 is a head count of animals,
    // a noun built from the classifier. The cue rule above cannot see it (the
    // character in front is 著) and opencc's phrase table does not carry it
    // either; only the whole-corpus comparison against cuv-tr.json found it.
    // It escaped the first pass of this repair, so it is pinned by reference.
    final blob = verses.map((v) => v['text'] as String).join();
    expect(blob.contains('只數'), isFalse, reason: '隻數 is a head count');
    expect(blob.contains('隻數'), isTrue);
  });

  test('the classifier is present at all, and the adverb survived', () {
    final blob = verses.map((v) => v['text'] as String).join();
    // Zero 隻 is the signature of the broken converter coming back.
    expect(blob.split('隻').length - 1, 548);
    // Over-converting would eat 只是 / 只有 / 只要, which are correct as 只.
    expect(blob.split('只').length - 1, 671);
    for (final adverb in ['只是', '只有', '只要', '只怕', '只因']) {
      expect(blob.contains(adverb), isTrue, reason: '$adverb must stay 只');
    }
  });

  test('the two verses opencc converts wrongly still read 只', () {
    String textOf(String book, String chapter, String verse) => verses
        .firstWhere((v) =>
            v['book'] == book &&
            '${v['chapter']}' == chapter &&
            '${v['verse']}' == verse)['text'] as String;

    expect(textOf('詩篇', '17', '14'), contains('脫離那只在今生'));
    expect(textOf('以賽亞書', '29', '17'), contains('不是只有一點點'));
    expect(textOf('以賽亞書', '2', '16'), contains('他施的船隻'));
    expect(textOf('民數記', '15', '12'), contains('按著隻數'));
  });
}
