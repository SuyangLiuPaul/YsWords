import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/utils/cbol_references.dart';
import 'package:yswords/utils/reference_parser.dart';

/// The CBOL citation notation, measured over the assets that ship.
///
/// Every number below was counted in this tree on 2026-09-08. The test
/// exists so that a re-import cannot quietly widen the hole: a count of
/// unreadable sites moving DOWN is an improvement and should be pinned
/// to its new value, and one moving UP means new markup reached the
/// reader.
void main() {
  /// Every string in an entry that a reader can end up looking at, in
  /// either lexicon's shape — `glossZh`/`defZh` and their Traditional
  /// twins for the Strong's files, `l`/`t`/`e`/`u`/`s` for the BDB and
  /// Thayer articles.
  Iterable<String> userFacing(Map<String, dynamic> entry) sync* {
    for (final key in const [
      'glossZh', 'defZh', 'glossZhTw', 'defZhTw',
      'l', 't', 'e', 'u',
    ]) {
      final v = entry[key];
      if (v is String && v.isNotEmpty) yield v;
    }
    for (final v in (entry['s'] as List?) ?? const []) {
      if (v is String && v.isNotEmpty) yield v;
    }
  }

  Map<String, dynamic> load(String name) =>
      json.decode(File('assets/strongs/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  const allAssets = ['greek', 'hebrew', 'bdb_zh', 'thayer_zh'];

  test('the lexicon\'s citations are readable and resolvable', () {
    var entries = 0;
    var withMarkup = 0;
    var sites = 0;
    var citations = 0;
    var unreadable = 0;
    final unreadableEntries = <String>{};

    for (final name in allAssets) {
      for (final e in load(name).entries) {
        entries++;
        var any = false;
        for (final s in userFacing(e.value as Map<String, dynamic>)) {
          if (!s.contains('#') && !s.contains('|')) continue;
          any = true;
          sites += '#'.allMatches(s).length;
          final runs = parseCbolRuns(s);
          citations +=
              runs.where((r) => r.kind == CbolRunKind.reference).length;
          final left = runs
              .where((r) => r.kind == CbolRunKind.text)
              .fold<int>(0, (n, r) => n + '#'.allMatches(r.text).length);
          if (left > 0) {
            unreadable += left;
            unreadableEntries.add('$name/${e.key}');
          }
        }
        if (any) withMarkup++;
      }
    }

    expect(entries, 28893);
    expect(withMarkup, 11359,
        reason: 'entries whose Chinese text carries CBOL markup');
    expect(sites, 39596);

    // 46,693 citations resolve to a book, chapter and verse the reader
    // can navigate to. 2,635 of those are reachable only because
    // `_traditionalBookChars` retries a Traditional book token in
    // Simplified; without it the Traditional half of the Strong's
    // lexicon linked almost nothing. The 46,693rd arrived on
    // 2026-09-08, when `约伯` was added to `_chineseShortAliases`:
    // 約伯記 10:22, the one citation the missing alias had been costing,
    // which `cbol_references_test.dart` had been pinning as a known gap.
    expect(citations, 46693);

    // 68 `#` sites do not parse — 34 entries, and most of those are the
    // same defect appearing twice because it sits in both the
    // Simplified and the Traditional column. They are defects in the
    // source: a missing book token (`#119:128`), a chapter and verse
    // run together (`#徒 2713`), a stray colon (`#结:26:9`), prose
    // behind the hash (`#喻意用法`), an empty block (`(#)`), a doubled
    // book token (`#徒 徒 12:23`), or an abbreviation that is genuinely
    // ambiguous between two books (`代`, `撒`). Each is passed through
    // verbatim rather than guessed at.
    //
    // It was 69 sites in 35 entries until 2026-09-08. The one that left
    // was not a source defect at all — `#约伯10:22` is well-formed and
    // we simply had no alias for 约伯 — and it was the only unreadable
    // site in its entry, so the entry count fell with it.
    expect(unreadable, 68);
    expect(unreadableEntries.length, 34);
  });

  test('nothing readable reaches the reader still wearing its delimiters',
      () {
    final leaked = <String>[];
    for (final name in allAssets) {
      for (final e in load(name).entries) {
        for (final s in userFacing(e.value as Map<String, dynamic>)) {
          if (!s.contains('#') && !s.contains('|')) continue;
          final plain = cbolPlainText(s);
          // A `|` may only survive where the `#` before it did — i.e.
          // inside one of the sites the parser refuses to read.
          if (!plain.contains('#') && plain.contains('|')) {
            leaked.add('$name/${e.key}: $s');
          }
        }
      }
    }
    // The one exception is bdb_zh/H2066 `(代下36,37|)`, which lost its
    // opening `#` in the source. `_restoreLostOpeners` declines to put
    // one back because the second item, chapter 37, is past the end of
    // 2 Chronicles — so the bracket is not a clean citation list and
    // promoting it would invent a chapter the book does not have.
    expect(leaked, hasLength(1), reason: leaked.join('\n'));
    expect(leaked.single, startsWith('bdb_zh/H2066'));
  });

  test('a citation dropped from a gloss is still reachable from the body',
      () {
    // This is what licenses `StrongsEntry.localizedGloss` to delete the
    // citation block outright instead of flattening it: the one-line
    // gloss loses nothing the reader cannot reach one line further
    // down, where `localizedDefinition` keeps every reference.
    var glossCitations = 0;
    var alsoInBody = 0;
    for (final name in const ['greek', 'hebrew']) {
      for (final e in load(name).entries) {
        final entry = e.value as Map<String, dynamic>;
        for (final pair in const [
          ('glossZh', 'defZh'),
          ('glossZhTw', 'defZhTw'),
        ]) {
          final g = entry[pair.$1];
          final b = entry[pair.$2];
          if (g is! String || g.isEmpty || b is! String) continue;
          final inBody = parseCbolRuns(b)
              .where((r) => r.kind == CbolRunKind.reference)
              .map((r) => r.reference)
              .toSet();
          for (final r in parseCbolRuns(g)
              .where((r) => r.kind == CbolRunKind.reference)) {
            glossCitations++;
            if (inBody.contains(r.reference)) alsoInBody++;
          }
        }
      }
    }
    expect(glossCitations, 15274);
    expect(alsoInBody, glossCitations,
        reason: 'a gloss citation that is NOT in the body would be lost '
            'outright when localizedGloss strips it');
  });

  test('the book-token map is complete and minimal for these assets', () {
    // Complete: after the retry, the only tokens the parser still
    // cannot read are the two genuinely ambiguous abbreviations — `代`
    // (代上/代下) and `撒` (撒上/撒下), which name two books each and are
    // not resolvable without a chapter range nobody supplies. `约伯`
    // was the third until 2026-09-08, and it was a different kind of
    // miss: an alias simply absent from `reference_parser.dart`. It is
    // there now, so it belongs in `resolvedTokens` below rather than
    // here.
    //
    // Minimal: every character in the map is one the corpus actually
    // uses in a book position. A key that stopped earning its place
    // would be an unaudited orthography rule sitting in the parser, so
    // the second half of this test is as load-bearing as the first.
    final unresolved = <String, int>{};
    final resolvedTokens = <String>{};
    final token = RegExp(r'#[ 　]*([㐀-鿿]{1,5})[ 　]*(?=\d)');
    for (final name in allAssets) {
      for (final e in load(name).entries) {
        for (final s in userFacing(e.value as Map<String, dynamic>)) {
          for (final m in token.allMatches(s)) {
            final t = m.group(1)!;
            if (parseCbolRuns('#$t 1:1|').any(
                (r) => r.kind == CbolRunKind.reference)) {
              resolvedTokens.add(t);
            } else {
              unresolved[t] = (unresolved[t] ?? 0) + 1;
            }
          }
        }
      }
    }
    expect(unresolved, {'代': 8, '撒': 1});
    expect(resolvedTokens, contains('约伯'));

    // Each mapped script character is used by at least one token that
    // needed the retry to resolve — i.e. one `resolveBookName` refuses
    // on its own.
    for (final ch in const ['創', '啓', '約', '後', '傳', '壹', '參', '参']) {
      final users = resolvedTokens.where((t) => t.contains(ch));
      expect(users, isNotEmpty, reason: '$ch is in the map but unused');
      expect(users.where((t) => resolveBookName(t) == null), isNotEmpty,
          reason: '$ch: every token using it already resolved without '
              'the retry, so the mapping is dead weight');
    }

    // 貳/贰/叁 are the map's one deliberate exception — unused by these
    // assets, kept so that a set of three numerals cannot half-work.
    // Pinned by behaviour rather than by use, so that removing them is
    // a decision someone makes rather than an omission.
    for (final tok in const ['約貳', '约贰', '约叁']) {
      expect(resolveBookName(tok), isNull, reason: '$tok needs the retry');
      expect(
          parseCbolRuns('#$tok 1:1|')
              .where((r) => r.kind == CbolRunKind.reference)
              .single
              .reference,
          tok.contains('貳') || tok.contains('贰')
              ? '2 John 1:1'
              : '3 John 1:1');
    }
  });

  test('no Strong\'s surface prints a delimiter it could have removed', () {
    // The six surfaces named in the defect — the originals sheet, the
    // Strong's entry page, search results, the distribution table, the
    // statistics page and the implied-coverage line — all read their
    // text through these five accessors, so checking the accessors
    // checks the surfaces.
    final leaked = <String>[];
    for (final name in const ['greek', 'hebrew']) {
      for (final e in load(name).entries) {
        final entry =
            StrongsEntry.fromJson(e.key, e.value as Map<String, dynamic>);
        for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
          for (final text in [
            entry.localizedGloss(locale),
            entry.localizedDefinition(locale),
            entry.cleanChineseDefinition(locale),
            entry.complementaryGloss(locale),
            entry.complementaryDefinition(locale),
          ]) {
            // A `#` that survived is one of the unreadable sites above;
            // a `|` that survived without one is a delimiter we failed
            // to take off.
            if (!text.contains('#') && text.contains('|')) {
              leaked.add('${e.key} $locale: $text');
            }
          }
        }
      }
    }
    expect(leaked, isEmpty, reason: leaked.take(5).join('\n'));
  });
}
