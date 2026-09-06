import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The divine-name substitution must not rename an organisation.
///
/// The sermon corpus carries a deliberate, corpus-wide substitution: the
/// Chinese bodies say 雅伟 / 雅偉 where an ordinary translation would say
/// 耶和华 / 耶和華. That is wanted — it is the name this app is built
/// around, and it was applied to all 289 sermons in both scripts.
///
/// It was applied as a blanket replacement, and a blanket replacement
/// cannot tell a name from a NAME INSIDE ANOTHER NAME. "Jehovah's
/// Witnesses" is the registered name of an organisation the preacher is
/// arguing AGAINST; rendering it 雅伟见证人 both misnames the group and
/// attaches this app's own vocabulary to it. Restored 2026-09-05; the T7
/// source transcripts had it right all along, so this was introduced
/// downstream of them.
///
/// **The five sermons that say it CHANGED on 2026-09-06 and the count did
/// not, which is exactly the kind of move a bare count cannot see.** It used
/// to be 004, 065, 140, 225 and 237, and the English body of each was what
/// settled the reading. Then 125 of Pastor Eric's messages were merged in
/// from the fuyindiantai staging library and 51 machine-translated Chinese
/// bodies were replaced by that library's human text. 065 was one of the 51,
/// and the library's text of that sermon does not mention the organisation
/// at all — so its Chinese mention left — while fy-bp07, one of the 125 new
/// ones, names 摩門教, 耶和华见证人 and 科学基督会 in a list of groups that
/// quote scripture. Five out, five in, total unchanged. The id SET is
/// therefore pinned below as well as the count, because the count alone
/// would have let this pass unread.
///
/// fy-bp07 has no English body — the library is Chinese-only — so the
/// cross-language check now covers four of the five rather than five of
/// five, and says so rather than quietly weakening.
///
/// Both sides are pinned. The FIX side alone would pass if someone
/// removed the substitution entirely, and the KEEP side alone would
/// pass if someone widened it back over the organisation.
void main() {
  late String simplified;
  late String traditional;
  late String english;

  String readAll(String dir) {
    final buf = StringBuffer();
    final entries = Directory('assets/sermons/$dir').listSync()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in entries) {
      if (f is File && f.path.endsWith('.txt')) buf.write(f.readAsStringSync());
    }
    return buf.toString();
  }

  int count(String haystack, String needle) =>
      haystack.split(needle).length - 1;

  setUpAll(() {
    simplified = readAll('zh-CN');
    traditional = readAll('zh-TW');
    english = readAll('en');
  });

  List<String> idsSaying(String dir, String needle) {
    final hits = <String>[];
    final entries = Directory('assets/sermons/$dir').listSync()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in entries) {
      if (f is File && f.path.endsWith('.txt')) {
        if (f.readAsStringSync().contains(needle)) {
          hits.add(f.uri.pathSegments.last.replaceAll('.txt', ''));
        }
      }
    }
    return hits;
  }

  test('the organisation keeps its own name in both scripts', () {
    expect(count(simplified, '雅伟见证人'), 0,
        reason: 'the blanket 雅伟 substitution reached an organisation name');
    expect(count(traditional, '雅偉見證人'), 0,
        reason: 'the blanket 雅偉 substitution reached an organisation name');

    // Five sermons, one mention each, in each script.
    expect(count(simplified, '耶和华见证人'), 5);
    expect(count(traditional, '耶和華見證人'), 5);
    // And WHICH five, because the set moved on 2026-09-06 while the count
    // stood still. If a merge ever drops one of these and adds another, the
    // list is what fails, not the total.
    expect(idsSaying('zh-CN', '耶和华见证人'),
        ['004', '140', '225', '237', 'fy-bp07']);
    expect(idsSaying('zh-TW', '耶和華見證人'),
        ['004', '140', '225', '237', 'fy-bp07']);
  });

  test('the English body is what settles four of the five', () {
    // 004, 065, 140 and 225 say "Jehovah's Witnesses"; 237 says
    // "a Jehovah's Witness". The English corpus is untouched by the merge,
    // so it still holds all five including 065's — whose CHINESE body no
    // longer mentions the organisation, because that body was replaced.
    expect(count(english, "Jehovah's Witness"), 5);
    expect(idsSaying('en', "Jehovah's Witness"),
        ['004', '065', '140', '225', '237']);
    // The fifth Chinese mention has no English twin at all. Saying so is
    // the point: the library the merge drew on is Chinese-only, so this
    // reading rests on the Chinese sentence — 「無論是摩門教，是耶和华见证
    // 人，是科学基督会」 — rather than on a translation of it.
    expect(File('assets/sermons/en/fy-bp07.txt').existsSync(), isFalse);
  });

  test('the divine name itself is untouched everywhere else', () {
    // Measured after the restoration: the substitution still stands in
    // every other place it was applied. If someone reverts the whole
    // substitution to satisfy the test above, these fail.
    // 340 → 624 on 2026-09-06. This was decomposed before it was changed:
    // 266 of the increase is in the 125 merged files and 18 is the net
    // across the 51 replaced (98 in, 80 out). Almost none of it is this
    // app's doing — the church's own published text already writes 雅伟,
    // 364 times across Pastor Eric's 182 bodied library records, so the
    // substitution below reached only NINE places in the whole merge.
    // 624 → 645 on 2026-09-06 with the 15 transcribed sermons. The check
    // is not the number: it is that the two scripts still agree EXACTLY,
    // which is what catches a Traditional body that was truncated or
    // converted by a different route from its Simplified twin.
    expect(count(simplified, '雅伟'), 645);
    expect(count(traditional, '雅偉'), 645);
    // The two agree exactly, which is the check: sermon 100's Traditional
    // body used to be a truncated translation and lost the name three
    // times with the rest of the text. It was rebuilt on 2026-09-05, and
    // every body the merge wrote is `opencc -c s2t` over its own
    // Simplified twin, so a divergence here would mean a Traditional body
    // that is not a conversion of the Simplified one next to it.
    expect(count(simplified, '耶和华'), 5,
        reason: 'only the organisation, nowhere else');
    expect(count(traditional, '耶和華'), 5,
        reason: 'only the organisation, nowhere else');
  });
}
