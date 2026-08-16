import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/utils/reference_parser.dart';

/// Every reference the app offers as a tap target must point at
/// scripture that exists.
///
/// Nothing in the app checks this. `parseReference` and `splitCitation`
/// resolve a book name and read numbers off the string; neither has any
/// idea how long a chapter is, and `splitCitation` additionally INHERITS
/// a bookless part from the part before it — so `John 18:31-33, 45`
/// would put a live tap target on John 18:45 in a chapter with 40
/// verses. The jump itself fails safe (`resolveAndPrepareJump` reports
/// failure rather than landing somewhere plausible), so the cost of such
/// an entry today is a snackbar; but the card would still be PRINTING a
/// reference that is not scripture, and a reference that reads
/// plausibly and is wrong gets believed.
///
/// Bounds-checking inside the parser would mean compiling a canon table
/// into the app — 1,189 numbers that can themselves be wrong, spent
/// defending against data that does not exist. This is the cheaper
/// guard, and the same one the unresolvable-citation work settled on:
/// check the DATA, and fail with the offending id if an import ever adds
/// a citation the reader cannot reach.
///
/// **The ruler is the union of the three English Bibles we ship, and it
/// has to be — one version alone is the wrong ruler.** All three carry
/// the same 66 books and the same 1,189 chapters, but they disagree on
/// where five of those chapters END, and the disagreement runs both
/// ways:
///
/// | chapter | KJV | NASB | LEB |
/// |---|---|---|---|
/// | 3 John 1 | 14 | 15 | 15 |
/// | Revelation 12 | 17 | 17 | 18 |
/// | 2 Corinthians 13 | 14 | 14 | 13 |
/// | Acts 19 | 41 | 41 | 40 |
/// | Romans 16 | 27 | 27 | 24 |
///
/// Only the first two run PAST the KJV, and they are why the ruler is a
/// union: checking against `assets/kjv.json` alone reports `3 John 1:15`
/// — a real cross-reference source key, and a verse a NASB or LEB reader
/// really can open — as out of canon. The three that run short do not
/// widen anything, so a citation is reachable when ANY shipped version
/// has it, which is the question the reader is actually asking.
///
/// **Known blind spot, left deliberately:** `_buildRef` drops the end of
/// a range in a single-chapter book, so `Jude 14-15` resolves to
/// Jude 1:14 and this check never sees the 15. Both `bible_evidence` and
/// `family_tree` cite it. Carrying the range through is a change to
/// navigation behaviour, not to a test — queued rather than smuggled in
/// here.
void main() {
  final lastChapter = <String, int>{};
  final lastVerse = <String, int>{};

  setUpAll(() {
    for (final asset in const [
      'assets/kjv.json',
      'assets/nasb.json',
      'assets/leb.json',
    ]) {
      final rows =
          jsonDecode(File(asset).readAsStringSync()) as List<dynamic>;
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final chapter = int.tryParse('${row['chapter']}');
        // LEB numbers Psalm superscriptions `title`; they are not a
        // verse anyone can cite, so they do not widen the ruler.
        final verse = int.tryParse('${row['verse']}');
        if (chapter == null || verse == null) continue;
        final book = row['book'] as String;
        if (chapter > (lastChapter[book] ?? 0)) lastChapter[book] = chapter;
        final key = '$book|$chapter';
        if (verse > (lastVerse[key] ?? 0)) lastVerse[key] = verse;
      }
    }
    expect(lastChapter.length, 66);
    expect(lastVerse.length, 1189);
    // Pin the ruler itself. A witness that quietly lost a chapter would
    // turn this whole file into a test that passes by knowing nothing.
    expect(lastVerse['John|18'], 40, reason: 'the case this test exists for');
    expect(lastChapter['Daniel'], 12);
    expect(lastVerse['3 John|1'], 15, reason: 'NASB and LEB split verse 15');
    expect(lastVerse['Revelation|12'], 18,
        reason: 'LEB alone; KJV and NASB carry the clause into 13:1');
  });

  /// The complaint a reference earns, or null when it is in range.
  String? outOfCanon(BibleReference ref) {
    final chapters = lastChapter[ref.englishBook];
    if (chapters == null) return 'unknown book ${ref.englishBook}';
    if (ref.chapter > chapters) {
      return '${ref.englishBook} has $chapters chapters, cites ${ref.chapter}';
    }
    final verses = lastVerse['${ref.englishBook}|${ref.chapter}'] ?? 0;
    for (final v in <int>[
      if (ref.verseStart != null) ref.verseStart!,
      if (ref.verseEnd != null) ref.verseEnd!,
      ...ref.verses,
    ]) {
      if (v > verses) {
        return '${ref.englishBook} ${ref.chapter} has $verses verses, '
            'cites $v';
      }
    }
    return null;
  }

  test('the check has teeth — the inherited-verse shape is caught', () {
    // `John 18:31-33, 45` is the shape the parser cannot defend against
    // on its own: `45` carries the book AND the chapter of the part
    // before it, so it resolves to a verse nobody typed.
    final inherited = splitCitation('John 18:31-33, 45');
    expect(inherited.last.text, '45');
    expect(inherited.last.target.toString(), 'John 18:45');
    expect(outOfCanon(inherited.last.target!),
        'John 18 has 40 verses, cites 45');

    // …and it must not fire on the citation the comma rule exists for.
    for (final seg in splitCitation('Daniel 2, 7, 8, 11')) {
      expect(outOfCanon(seg.target!), isNull, reason: seg.text);
    }
    for (final seg in splitCitation('Acts 19:11-20, 23-41')) {
      expect(outOfCanon(seg.target!), isNull, reason: seg.text);
    }

    // The blind spot, pinned rather than described: a range in a
    // single-chapter book loses its end, so nothing downstream — this
    // check included — can see the 15 of `Jude 14-15`. If that is ever
    // fixed, this expectation fails and the range must be bounded here.
    final jude = parseReference('Jude 14-15')!;
    expect(jude.verseStart, 14);
    expect(jude.verseEnd, isNull);
  });

  test('every evidence citation resolves inside the canon', () {
    final raw = File('assets/bible_evidence.json').readAsStringSync();
    final entries =
        (jsonDecode(raw) as Map<String, dynamic>)['evidences'] as List;
    expect(entries.length, 225);

    // Every segment of every citation, not a sample — including the
    // parts that inherit their book or chapter, which are the only ones
    // that can go out of range without anyone typing them.
    final bad = <String>[];
    var targets = 0;
    for (final e in entries.cast<Map<String, dynamic>>()) {
      final ref = e['scriptureReference'] as String? ?? '';
      for (final seg in splitCitation(ref)) {
        final target = seg.target;
        if (target == null) continue;
        targets++;
        final complaint = outOfCanon(target);
        if (complaint != null) {
          bad.add('${e['id']}: "$ref" → ${seg.text} → $complaint');
        }
      }
    }
    expect(bad, isEmpty);
    expect(targets, 250, reason: 'the walk reached every cited passage');
  });

  test('the timeline and the family tree cite inside the canon too', () {
    // asset → (refs, resolved targets). Targets exceed refs because of
    // the comma spans below.
    for (final file in const {
      'assets/bible_timeline.json': (123, 124),
      'assets/family_tree.json': (665, 667),
    }.entries) {
      final refs = <String>[];
      void walk(dynamic node) {
        if (node is Map) {
          node.forEach((k, v) {
            if (k == 'refs' && v is List) refs.addAll(v.cast<String>());
            walk(v);
          });
        } else if (node is List) {
          node.forEach(walk);
        }
      }

      walk(jsonDecode(File(file.key).readAsStringSync()));
      expect(refs.length, file.value.$1, reason: file.key);

      // `splitCitation`, not `parseReference`: the latter truncates at
      // the first comma, and these two assets really do cite
      // `Luke 1:5-25, 57-80` and `Genesis 4:19, 22` — the second span is
      // the inheriting shape this whole file exists to bound, so
      // checking only the first would have skipped every live instance
      // of it.
      final bad = <String>[];
      var targets = 0;
      for (final r in refs) {
        for (final seg in splitCitation(r)) {
          final target = seg.target;
          if (target == null) continue;
          targets++;
          final complaint = outOfCanon(target);
          if (complaint != null) bad.add('$r → ${seg.text} → $complaint');
        }
      }
      expect(bad, isEmpty, reason: file.key);
      expect(targets, file.value.$2,
          reason: '${file.key} — the comma spans were reached');
    }
  });

  test('every cross-reference — source and target — is real scripture', () {
    // The largest citation corpus in the app by two orders of magnitude,
    // and the one with the most direct claim on a reader: the sheet says
    // "this verse relates to that one" and offers the jump. It had no
    // bounds check at all.
    final raw = File('assets/cross_references.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final badSources = <String>[];
    final badTargets = <String>[];
    final unparsed = <String>[];
    var sources = 0;
    var targets = 0;
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) continue; // _meta
      sources++;
      final source = parseReference(entry.key);
      if (source == null) {
        unparsed.add(entry.key);
      } else {
        final complaint = outOfCanon(source);
        if (complaint != null) badSources.add('${entry.key} → $complaint');
      }
      for (final s in (entry.value as List).cast<String>()) {
        targets++;
        // Exactly the call `CrossReferenceService._load` makes, so a
        // string this rejects is a cross-reference the reader silently
        // never sees.
        final target = parseReference(s);
        if (target == null) {
          unparsed.add('${entry.key} → $s');
          continue;
        }
        final complaint = outOfCanon(target);
        if (complaint != null) badTargets.add('${entry.key} → $s → $complaint');
      }
    }

    expect(sources, 29318);
    expect(targets, 250279);
    expect(unparsed, isEmpty);
    expect(badSources, isEmpty);
    expect(badTargets, isEmpty);
  });
}
