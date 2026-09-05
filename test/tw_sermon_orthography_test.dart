import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/sermons/zh-TW/` follows the printed 和合本, not opencc's default.
///
/// **How the corpus got two spellings of the same word.** The Traditional
/// bodies are `opencc -c s2t` output — calibrated, not assumed: over eight
/// sermons whose Simplified and Traditional bodies are the same length,
/// s2t reproduces the shipped Traditional exactly, 0 mismatches in 91 118
/// characters. On top of that, 35 of 206 such files had been hand-repaired
/// at some point and the other 171 had not, so the corpus carried 爲 23 701
/// times and 為 860 times, 着 6 915 times and 著 454 times. Same corpus,
/// same word, two spellings, split by which file you opened.
///
/// **Which spelling wins is not a preference here.** The owner's ruling was
/// to follow the latest printed Traditional 和合本, and that reference is
/// bundled: `assets/cuvs-yhwh-tr.json` is unanimous on all five —
/// 為 7952:0, 裏 4787:0, 著 2651:0, 才 240:0, 啟 425:0. Note 裏, not 裡:
/// two of the 35 hand-repaired files had been moved the other way, so the
/// partial repair was not merely incomplete, it disagreed with the ruling.
///
/// 32 220 characters were normalised on 2026-09-05, touching all 289 files.
/// Nothing else changed: no punctuation, no wording, no paragraphing —
/// re-punctuating a preacher is not on the table, and a glyph is not
/// punctuation.
///
/// Both sides are pinned. The zero side alone would pass on an empty
/// corpus; the reference side is what says the corpus is still here.
void main() {
  late String sermons;
  late String cuvTraditional;

  setUpAll(() {
    final buf = StringBuffer();
    final files = Directory('assets/sermons/zh-TW').listSync()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      if (f is File && f.path.endsWith('.txt')) buf.write(f.readAsStringSync());
    }
    sermons = buf.toString();
    cuvTraditional = File('assets/cuvs-yhwh-tr.json').readAsStringSync();
  });

  int count(String haystack, String needle) =>
      haystack.split(needle).length - 1;

  test('the reference itself is unanimous — this is what the rule rests on',
      () {
    for (final pair in const [
      ['爲', '為'],
      ['裡', '裏'],
      ['着', '著'],
      ['纔', '才'],
      ['啓', '啟'],
    ]) {
      expect(count(cuvTraditional, pair[0]), 0,
          reason: '和合本 does not use ${pair[0]}');
      expect(count(cuvTraditional, pair[1]), greaterThan(200),
          reason: '和合本 uses ${pair[1]} throughout');
    }
  });

  test('the variant spellings are gone from every sermon', () {
    expect(count(sermons, '爲'), 0);
    expect(count(sermons, '裡'), 0);
    expect(count(sermons, '着'), 0);
    expect(count(sermons, '纔'), 0);
    expect(count(sermons, '啓'), 0);
  });

  test('and the 和合本 spellings carry the whole corpus', () {
    expect(count(sermons, '為'), 24778);
    expect(count(sermons, '裏'), 10772);
    expect(count(sermons, '著'), 7426);
    expect(count(sermons, '才'), 1779);
    expect(count(sermons, '啟'), 512);
  });

  test('the three regenerated bodies are in the corpus and in this rule', () {
    // 100, 369 and 370 shipped with a separate, incomplete Traditional
    // translation — a different voice from the other 286 ("我應當" where
    // the Simplified says 我应该), and truncated: 6 331 characters against
    // a Simplified 18 304. They were rebuilt the way the rest of the
    // corpus was built, `opencc -c s2t` over the Simplified body plus the
    // rules above, so each now matches its Simplified body's length
    // exactly. The counts above include them.
    for (final id in const ['100', '369', '370']) {
      final zhCn = File('assets/sermons/zh-CN/$id.txt').readAsStringSync();
      final zhTw = File('assets/sermons/zh-TW/$id.txt').readAsStringSync();
      expect(zhTw.length, zhCn.length,
          reason: '$id: a Traditional body shorter than its Simplified '
              'source is a truncated translation, not a conversion');
    }
  });

  test('the earlier spot repairs survived the sweep', () {
    // `tools/repair_tw_sermon_*.py` fixed four classes on 2026-09-03 and
    // this sweep must not have undone them. 麪 is the one that would
    // have gone first: opencc's s2t writes 麵 for 面粉/面包, the corpus
    // settled on 麪, and no rule above touches either.
    // 158 from 2026-09-05 — six over-converted 麪 were corrected back to
    // 面 after a refuter pass found them; see tw_sermon_glyph_test.dart.
    expect(count(sermons, '麪'), 158);
    expect(count(sermons, '麵'), 0);
  });
}
