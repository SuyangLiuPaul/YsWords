import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-09-05. `docs/autonomous-queue.md` (P3, EC018/EC019 item): both files
/// have a tape-side boundary where Phase-1 ASR stopped emitting punctuation.
/// `assets/sermons/en/EC019.txt` paragraph 49/130 is 18,205 chars with 1
/// period and 2 commas, and ends mid-sentence; paragraph 51 re-states the
/// same sentence, properly punctuated, as the opening of Part 2. EC018 has
/// the same defect at a smaller scale. T7 was checked
/// (`/Volumes/T7/.../P.Eric Sermon/Spiritual Vision/`) and the shipped
/// English text is byte-identical to the T7 pipeline's `.formatted.txt` —
/// there is no better transcript to swap in. The only real fix is
/// re-transcribing from the T7 MP3s, which is out of scope for an
/// unattended iteration (see the queue entry) — this test only pins the
/// defect so a future import cannot silently add a third file to it.
///
/// Length alone is not the right signal for `en`: EC014 has an 8780-char
/// paragraph too, but with 97 sentence-terminators in it (a long, normally
/// -punctuated paragraph, not a silent-ASR one). What actually separates
/// the offenders is chars-per-terminator — EC019/EC018's three long
/// paragraphs run 2451-4551 chars/terminator; EC014's runs 91. So `en`
/// gates on **both** length (>5000) and density (>500 chars/terminator);
/// zh-CN/zh-TW need length alone (EC019 6046, EC018 3494, next-worst EC016
/// is 867 — no long-but-punctuated zh paragraph exists to confuse it).
/// (There is also a smaller, same-shaped case at `C174.txt`, en: 2006
/// chars, 1 terminator — below the 5000 gate, so outside this test's
/// claim, but worth knowing about if the gate ever moves.)
void main() {
  const allowlist = {'EC018.txt', 'EC019.txt'};
  final terminator = RegExp(r'[.!?。！？]');

  Map<String, String> loadLocale(String locale) {
    final files = <String, String>{};
    for (final f in Directory('assets/sermons/$locale').listSync()) {
      if (f is File && f.path.endsWith('.txt')) {
        files[f.uri.pathSegments.last] = f.readAsStringSync();
      }
    }
    return files;
  }

  /// True if any non-heading, non-blank paragraph (split the way the
  /// sermon reader paginates: blank-line-separated blocks) is longer than
  /// [minLength] AND runs more than [minRatio] chars per sentence
  /// -terminator — i.e. it is long because punctuation stopped, not just
  /// because it is a long normal paragraph.
  bool hasUnpunctuatedLongParagraph(String text, int minLength, int minRatio) {
    for (final para in text.split('\n\n')) {
      final p = para.trim();
      if (p.isEmpty || p.startsWith('#') || p.length <= minLength) continue;
      final terms = terminator.allMatches(p).length;
      final ratio = p.length / (terms == 0 ? 1 : terms);
      if (ratio > minRatio) return true;
    }
    return false;
  }

  void checkLocale(String locale, int minLength, int minRatio) {
    final files = loadLocale(locale);
    expect(files.length, greaterThan(200),
        reason: 'sanity: assets/sermons/$locale did not load');

    final offenders = <String>{
      for (final entry in files.entries)
        if (hasUnpunctuatedLongParagraph(entry.value, minLength, minRatio))
          entry.key,
    };

    for (final name in offenders.difference(allowlist)) {
      fail('$locale/$name has an unpunctuated paragraph over $minLength '
          'chars ($minRatio+ chars/terminator) but is not EC018/EC019 — '
          'either a new ASR-punctuation defect landed, or the allowlist '
          'above needs updating with a T7 source check first.');
    }
    for (final name in allowlist) {
      expect(offenders.contains(name), isTrue,
          reason: '$locale/$name no longer has an unpunctuated oversize '
              'paragraph — the EC018/EC019 exception in this test is stale '
              'and should be narrowed or removed.');
    }
  }

  test('en: only EC018/EC019 have an unpunctuated 5000+ char paragraph', () {
    checkLocale('en', 5000, 500);
  });

  test('zh-CN: only EC018/EC019 have an unpunctuated 2000+ char paragraph',
      () {
    checkLocale('zh-CN', 2000, 0);
  });

  test('zh-TW: only EC018/EC019 have an unpunctuated 2000+ char paragraph',
      () {
    checkLocale('zh-TW', 2000, 0);
  });

  test('EC019 paragraph 49/130 is the pinned defect, not a regression risk',
      () {
    final text = loadLocale('en')['EC019.txt']!;
    final paras = text.split('\n\n');
    expect(paras.length, 130);
    final p49 = paras[49].trim();
    expect(p49.length, 18205);
    expect('.'.allMatches(p49).length, 1);
    expect(','.allMatches(p49).length, 2);
    expect(p49.endsWith('the more you I'), isTrue);

    // Part 2 restates the same sentence, properly punctuated — proof the
    // defect is a transcription gap, not lost content.
    final part2 = paras[51].trim();
    expect(part2.startsWith('The more you do God\'s will, the more you '
        'experience Him.'), isTrue);
  });
}
