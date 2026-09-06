import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 自已 → 自己 in the four places it survived outside the verse text.
///
/// `test/cuv_typo_corruptions_test.dart` pins the same typo inside the CUV.
/// These four were left out of that instalment because their provenance is
/// different — two sermon transcripts and two Strong's glosses, not scripture —
/// so they needed their own evidence rather than the corpus argument that
/// repaired the Bible text.
///
/// 自已 is not a word: 已 is the adverb "already" and the reflexive pronoun is
/// 自己. The corpus settles it without any outside source — the zh-CN and zh-TW
/// transcripts write 自己 10,875 times, and 021.txt and 029.txt write it 39 and
/// 26 times each while misspelling it once.
///
/// Both glosses are inherited rather than introduced here: the upstream CBOL
/// source carries the identical typo at Greek 03962 and Hebrew 02616.
///
/// The last group is the one worth keeping. A blanket 自已 → 自己 over the same
/// upstream lexicon would corrupt 21 further strings, because CBOL's etymology
/// formula 「源自已不使用的字根」 is 源自 + 已不使用 and entirely correct. None
/// of those fields were imported, so our assets are clean of it — but the
/// substitution has to stay anchored, and 已 next to 自 is not on its own a
/// defect.
void main() {
  const sermons = <String>[
    'assets/sermons/zh-CN/021.txt',
    'assets/sermons/zh-CN/029.txt',
    'assets/sermons/zh-TW/021.txt',
    'assets/sermons/zh-TW/029.txt',
  ];

  /// The ONE reading in which 自已 is correct and must not be repaired.
  ///
  /// 2026-09-06, and it arrived by the merge rather than by a sweep: 125 of
  /// Pastor Eric's messages came in from the fuyindiantai staging library
  /// and fy-nm31 writes 「不能自已地追求不可能達到的目標」. 不能自已 is a
  /// set phrase — "unable to restrain oneself" — in which 已 is the verb
  /// 止, exactly as in 情不自禁. It is not the reflexive pronoun and a
  /// blanket 自已 → 自己 would turn it into 「不能自己地追求」, which means
  /// nothing.
  ///
  /// This is the class the docstring above already named — 「已 next to 自
  /// is not on its own a defect」 — appearing in this repo's own assets for
  /// the first time. It is spelled out as a reading rather than as a file
  /// exemption, so a genuine 自已 anywhere in the same file still fails.
  const permitted = <String, String>{
    'assets/sermons/zh-CN/fy-nm31.txt': '不能自已地追求不可能达到的目标',
    'assets/sermons/zh-TW/fy-nm31.txt': '不能自已地追求不可能達到的目標',
  };

  test('no asset spells the reflexive pronoun 自已', () {
    final offenders = <String>[];
    for (final dir in ['assets/sermons', 'assets/strongs']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File) continue;
        var text = f.readAsStringSync();
        final ok = permitted[f.path];
        if (ok != null && text.contains(ok)) {
          // Remove only the licensed reading, then look again. A second
          // 自已 in the same file still lands in `offenders`.
          text = text.replaceAll(ok, '');
        }
        if (text.contains('自已')) offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('the one correct 自已 is still there and is still the idiom', () {
    // The other half: if a later sweep "finishes the job" over the sermon
    // corpus, this is what fails.
    permitted.forEach((path, reading) {
      expect(File(path).readAsStringSync(), contains(reading),
          reason: '$path lost 不能自已, which was correct Chinese');
    });
  });

  test('the four repaired readings say what they mean', () {
    String read(String p) => File(p).readAsStringSync();

    expect(read(sermons[0]), contains('所以我对自己说'));
    expect(read(sermons[1]), contains('我真的是在对自己说话'));
    expect(read(sermons[2]), contains('所以我對自己說'));
    expect(read(sermons[3]), contains('我真的是在對自己說話'));

    final greek =
        json.decode(read('assets/strongs/greek.json')) as Map<String, dynamic>;
    final father = greek['G3962'] as Map<String, dynamic>;
    expect(father['defZh'], contains('不再害怕自己是罪人'));
    expect(father['defZhTw'], contains('不再害怕自己是罪人'));

    final hebrew =
        json.decode(read('assets/strongs/hebrew.json')) as Map<String, dynamic>;
    final kind = hebrew['H2616'] as Map<String, dynamic>;
    expect(kind['defZh'], contains('(Hithpael) 对自己仁慈'));
    expect(kind['defZhTw'], contains('(Hithpael) 對自己仁慈'));
  });

  test('the substitution stayed anchored — 已 beside 自 is not itself a defect',
      () {
    final greek =
        json.decode(File('assets/strongs/greek.json').readAsStringSync())
            as Map<String, dynamic>;
    final father = greek['G3962'] as Map<String, dynamic>;
    // Same sentence, three characters later: 「是已與自己和好的親愛父親」.
    // 已 here is the adverb and must survive.
    expect(father['defZhTw'], contains('是已'));
    expect(father['defZh'], contains('是已'));
  });

  test('the Chinese transcripts still overwhelmingly write 自己', () {
    var count = 0;
    for (final dir in ['assets/sermons/zh-CN', 'assets/sermons/zh-TW']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File) continue;
        count += '自己'.allMatches(f.readAsStringSync()).length;
      }
    }
    // 10,875 were already spelt correctly before this repair, plus the 4 it
    // fixed. Not pinned exactly: the transcript corpus still grows.
    expect(count, greaterThan(10000));
  });
}
