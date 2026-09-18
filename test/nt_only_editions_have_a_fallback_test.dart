// Every edition that is missing a Testament has somewhere to send a
// reader who opens one.
//
// 2026-09-15. 「如果我选的中文是梁简 或繁体 但是选的是旧约 然后就有fallback
// 雅伟简 繁做backup吗」 — it did not, and the way it stopped is the
// reason this file derives the rule from the ASSETS instead of checking
// the table against a list somebody typed.
//
// `bibleVersionFullCanonFallback` is keyed on the edition CODE. On
// 2026-09-14 the 梁家鏗譯本 was re-fetched: `biblexg-v2` was hidden and
// `_kSupersededBy` pointed stored preferences at `biblexg-v3`. Every
// other consumer followed automatically, because they resolve through
// `resolvableVersion`. This table could not — and so the moment the
// row a reader can actually pick became `biblexg-v3`, the lookup
// returned null and a reader on 梁简 who opened 创世记 got nothing. The
// fallback was still standing guard over an edition no one could
// select.
//
// So the assertion below asks the files, not the catalogue: load every
// edition a reader can choose, see which Testaments it actually
// contains, and demand a fallback for the ones it does not — a fallback
// that itself covers the gap.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/bible_versions.dart';

/// A book from each Testament, in the book-name language each edition
/// uses. An edition is judged to carry a Testament if it has ANY of the
/// names for it — the editions spell them in English, Simplified and
/// Traditional.
/// 創世紀 with 紀, not 記: that is the spelling 和合本雅偉版(繁) actually
/// uses, and the first draft of this test failed on it — which is
/// exactly the kind of thing a list somebody types gets wrong and a
/// list derived from the files does not.
const _ot = <String>['Genesis', '创世纪', '創世紀', '創世記', '创世记'];
const _nt = <String>['Matthew', '马太福音', '馬太福音'];

Set<String> _booksOf(String code) {
  final file = File('assets/$code.json');
  if (!file.existsSync()) return <String>{};
  final raw = jsonDecode(file.readAsStringSync());
  if (raw is! List) return <String>{};
  return {
    for (final v in raw)
      if (v is Map && v['book'] is String) v['book'] as String,
  };
}

bool _has(Set<String> books, List<String> names) =>
    names.any(books.contains);

void main() {
  test('an edition missing a Testament has a fallback that covers it', () {
    final gaps = <String>[];

    for (final info in availableVersions) {
      final books = _booksOf(info.value);
      if (books.isEmpty) continue; // not a bundled verse file
      final ot = _has(books, _ot);
      final nt = _has(books, _nt);
      if (ot && nt) continue; // full canon — nothing to fall back to

      final missing = ot ? 'the New Testament' : 'the Old Testament';
      final fallback = bibleVersionFullCanonFallback(info.value);
      if (fallback == null) {
        gaps.add('${info.value} has no $missing and no fallback — a '
            'reader who opens one lands on an empty chapter');
        continue;
      }
      final cover = _booksOf(fallback);
      final covers = ot ? _has(cover, _nt) : _has(cover, _ot);
      if (!covers) {
        gaps.add('${info.value} falls back to $fallback, which is also '
            'missing $missing');
      }
    }

    expect(gaps, isEmpty, reason: gaps.join('\n'));
  });

  test('the two the owner named land on 和合本雅伟版, matching script', () {
    // Named as well as derived. The rule above would be satisfied by a
    // fallback to any full-canon edition — including one in the wrong
    // script, which would put 繁體 in front of a 简体 reader.
    expect(bibleVersionFullCanonFallback('biblexg-v3'), 'cuvs-yhwh');
    expect(bibleVersionFullCanonFallback('biblexg-v3-tr'), 'cuvs-yhwh-tr');
  });

  test('a fallback never crosses script inside the Chinese family', () {
    for (final info in availableVersions) {
      final lang = info.language;
      if (!lang.startsWith('zh')) continue;
      final fallback = bibleVersionFullCanonFallback(info.value);
      if (fallback == null) continue;
      expect(bibleVersionLanguage(fallback), lang,
          reason: '${info.value} is $lang but falls back to $fallback, '
              'which would put the other script in front of the reader');
    }
  });

  test('a full-canon edition is offered no fallback at all', () {
    // The other half: a rule that answered every code would quietly
    // substitute editions that have nothing wrong with them.
    for (final code in ['cuvs-yhwh', 'cuvs-yhwh-tr', 'kjv', 'bsb-yhwh']) {
      expect(bibleVersionFullCanonFallback(code), isNull, reason: code);
    }
  });
}
