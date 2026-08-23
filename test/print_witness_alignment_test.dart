import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Wikisource transcription of the printed 1919 和合本 is the witness this
/// repo reaches for when the two digital witnesses agree with each other and
/// that is not enough. Verses have been repaired, and proposed repairs
/// refused, on the strength of "the print reads …".
///
/// `tools/audit_print_witness.py` checked for the first time whether its verse
/// ids address the same verses ours do. In 21 of 31,030 they do not, and in
/// every one of those OUR division is the standard one and the transcription
/// is the odd edition out. This test pins the two places, so that nobody
/// reading the print later "corrects" our numbering to match a page that is
/// wrong — which would move real scripture under real verse numbers.
///
/// It also pins the 「見上節」 class, where the danger runs the other way: a
/// sweep that treated the stub as a defect would either delete 70 verse ids or
/// invent text for them.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';

  Map<String, String> load(String path) => {
        for (final r in jsonDecode(File(path).readAsStringSync()) as List)
          r['id'] as String: r['text'] as String,
      };

  final tr = load(traditional);
  final sc = load(simplified);

  int versesIn(Map<String, String> v, String chapter) =>
      v.keys.where((k) => k.startsWith(chapter)).length;

  test('歷代志上 21 ends at verse 30 and 22:1 is 大衛說, not the page shift',
      () {
    // The page numbers our 22:1 as 21:31 and slides 22:2–19 down to 22:1–18.
    // KJV agrees with us: 1 Chr 21 has 30 verses and 22:1 is "Then David
    // said, This is the house of the LORD God".
    expect(versesIn(tr, '013021'), 30);
    expect(versesIn(tr, '013022'), 19);
    expect(tr['013022001'], startsWith('大衛說'));
    expect(tr['013022002'], startsWith('大衛吩咐聚集'));

    final kjv = load('assets/kjv.json');
    expect(versesIn(kjv, '013021'), 30);
    expect(kjv['013022001'], contains('Then David said'));
  });

  test('馬可福音 9:43 keeps the whole sentence and 9:44 stays the variant note',
      () {
    // The page splits our 9:43 in half and gives the remainder the number that
    // belongs to the bracketed 「在那裏蟲是不死的，火是不滅的」.
    expect(tr['041009043'], contains('你缺了肢體進入永生'));
    expect(tr['041009044'], startsWith('<note:'));
    expect(tr['041009044'], contains('第四十四節'));
    expect(tr['041009045'], contains('你瘸腿進入永生'));
    expect(tr['041009046'], startsWith('<note:'));
  });

  test('the 「見上節」 class is exactly 70 verses and the same 70 in both files',
      () {
    final trStubs = tr.entries
        .where((e) => e.value.trim() == '見上節')
        .map((e) => e.key)
        .toSet();
    final scStubs = sc.entries
        .where((e) => e.value.trim() == '见上节')
        .map((e) => e.key)
        .toSet();
    expect(trStubs.length, 70);
    expect(scStubs, trStubs);

    // 69 of the 70 are verses the print does not number separately — the
    // Chinese renders two source verses as one block. 路加福音 21:30 is the
    // one the print does number and give text to; it is held for the user
    // because splitting it is a versification change, not a text repair.
    expect(trStubs, contains('042021030'));
    expect(tr['042021029'], contains('它發芽的時候'));
  });

  test('the three merges that use their own notation are not stubs to sweep',
      () {
    // Outside the 70 「見上節」 the same merge is recorded three other ways.
    // A sweep keyed on the stub string alone would read these as defects.
    expect(tr['043007053'], '<note: 見下節>');
    expect(tr['019063006'], '<note: 合和譯本並入上一節>');
    expect(tr['064001014'], contains('<note: 15節>'));
    expect(tr.containsKey('064001015'), isFalse);
  });

  test('the two notes the queue called missing are on screen, inline', () {
    // Both were filed as printed notes lost from our text. They are carried as
    // parentheticals rather than as `<note:>` markup, which is what the
    // original count was blind to.
    expect(tr['038004007'], contains('（殿：或譯石）'));
    expect(tr['038008023'], contains('（原文是方言）'));
  });
}
