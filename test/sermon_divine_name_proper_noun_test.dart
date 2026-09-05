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
/// attaches this app's own vocabulary to it. Five sermons say it —
/// 004, 065, 140, 225, 237 — and in every one the English body reads
/// "Jehovah's Witness(es)", which is what settles it. Restored
/// 2026-09-05; the T7 source transcripts had it right all along, so
/// this was introduced downstream of them.
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

  test('the organisation keeps its own name in both scripts', () {
    expect(count(simplified, '雅伟见证人'), 0,
        reason: 'the blanket 雅伟 substitution reached an organisation name');
    expect(count(traditional, '雅偉見證人'), 0,
        reason: 'the blanket 雅偉 substitution reached an organisation name');

    // Five sermons, one mention each, in each script.
    expect(count(simplified, '耶和华见证人'), 5);
    expect(count(traditional, '耶和華見證人'), 5);
  });

  test('the English body is what settles it', () {
    // 004, 065, 140 and 225 say "Jehovah's Witnesses"; 237 says
    // "a Jehovah's Witness". Five sermons, five mentions.
    expect(count(english, "Jehovah's Witness"), 5);
  });

  test('the divine name itself is untouched everywhere else', () {
    // Measured after the restoration: the substitution still stands in
    // every other place it was applied. If someone reverts the whole
    // substitution to satisfy the test above, these fail.
    expect(count(simplified, '雅伟'), 340);
    expect(count(traditional, '雅偉'), 340);
    // 340 vs 337 is not a rounding difference: sermon 100's Traditional
    // body is a truncated translation (6 331 chars against the
    // Simplified's 18 304) and loses the name three times with the rest
    // of the text. See docs/OPEN-ITEMS.md — the truncation is in the T7
    // source, not introduced here.
    expect(count(simplified, '耶和华'), 5,
        reason: 'only the organisation, nowhere else');
    expect(count(traditional, '耶和華'), 5,
        reason: 'only the organisation, nowhere else');
  });
}
