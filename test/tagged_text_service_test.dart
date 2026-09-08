import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/tagged_text_service.dart';

/// The join that makes "tap a word to see the original" possible.
///
/// Run against the real `assets/tagged/cuvs-yhwh/`, because the thing
/// most likely to go wrong is not the Dart — it is the asset not being
/// registered in pubspec, or the book-name mapping missing a file, and
/// a fixture would hide both.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('four editions claim tagging, and the untagged ones do not', () {
    // 2026-09-08: this test read "only the Simplified 雅伟版 claims
    // tagging", and said of `cuvs-yhwh-tr` that "no Traditional tagged
    // set exists. Claiming otherwise would put a gesture on screen that
    // answers nothing." The claim was true when it was written and the
    // reasoning behind it was not: the set did not exist because nobody
    // had derived one, and deriving one needs no converter — the
    // edition's own Traditional text is shipped beside its Simplified
    // one and is character-aligned with it. See
    // `tools/derive_tagged_traditional.py` and
    // `test/tagged_traditional_derived_test.dart`.
    expect(TaggedTextService.supports('cuvs-yhwh'), isTrue);
    expect(TaggedTextService.supports('cuvs-yhwh-tr'), isTrue);
    expect(TaggedTextService.supports('bsb-yhwh'), isTrue);
    expect(TaggedTextService.supports('asv-yhwh'), isTrue);
    // Still nothing on screen that answers nothing: an edition with no
    // layer must not claim one.
    expect(TaggedTextService.supports('kjv'), isFalse);
    expect(TaggedTextService.supports('leb'), isFalse);
    expect(TaggedTextService.supports('csb'), isFalse);
    expect(TaggedTextService.supports('biblexg-v2'), isFalse);
    expect(TaggedTextService.supports('biblexg-v2-tr'), isFalse);
    // The Greek original. An interlinear of the original against itself
    // is a different feature from this one.
    expect(TaggedTextService.supports('wh'), isFalse);
    expect(TaggedTextService.supports('nasb'), isFalse);
  });

  test('the Traditional layer answers in the Traditional script', () async {
    final runs = await TaggedTextService.forVerse(
      version: 'cuvs-yhwh-tr',
      englishBook: 'Genesis',
      chapter: 1,
      verse: 1,
    );
    expect(runs, isNotNull,
        reason: 'assets/tagged/cuvs-yhwh-tr/ must be registered in '
            'pubspec.yaml and shipped');
    final joined = runs!.map((r) => r.text).join();
    expect(joined, '起初，神創造天地。');
    expect(runs.firstWhere((r) => r.text.contains('創造')).strongs, 'H1254');
  });

  test('the English layers answer too', () async {
    for (final (version, word, number) in [
      ('bsb-yhwh', 'created', 'H1254'),
      ('asv-yhwh', 'created', 'H1254'),
    ]) {
      final runs = await TaggedTextService.forVerse(
        version: version,
        englishBook: 'Genesis',
        chapter: 1,
        verse: 1,
      );
      expect(runs, isNotNull, reason: '$version has no Genesis 1:1');
      final hit = runs!.where((r) => r.text.contains(word));
      expect(hit, isNotEmpty, reason: '$version 1:1 does not print "$word"');
      expect(hit.first.strongs, number);
    }
  });

  test('Genesis 1:1 resolves word by word', () async {
    final runs = await TaggedTextService.forVerse(
      version: 'cuvs-yhwh',
      englishBook: 'Genesis',
      chapter: 1,
      verse: 1,
    );
    expect(runs, isNotNull, reason: 'assets/tagged/cuvs-yhwh/ must be '
        'registered in pubspec.yaml and shipped');
    expect(runs!, isNotEmpty);

    final joined = runs.map((r) => r.text).join();
    expect(joined, contains('起初'));
    expect(joined, contains('创造'));

    // The whole point: a specific word carries a specific number.
    final created = runs.firstWhere((r) => r.text.contains('创造'));
    expect(created.strongs, 'H1254');
    expect(created.isTagged, isTrue);
    final god = runs.firstWhere((r) => r.text.contains('神'));
    expect(god.strongs, 'H430');
  });

  test('a New Testament book loads too', () async {
    final runs = await TaggedTextService.forVerse(
      version: 'cuvs-yhwh',
      englishBook: 'John',
      chapter: 3,
      verse: 16,
    );
    expect(runs, isNotNull);
    expect(runs!.any((r) => r.isTagged), isTrue);
  });

  test('an untagged version costs nothing and returns null', () async {
    final runs = await TaggedTextService.forVerse(
      version: 'kjv',
      englishBook: 'Genesis',
      chapter: 1,
      verse: 1,
    );
    expect(runs, isNull);
  });

  test('a two-word book name maps to its file', () async {
    final runs = await TaggedTextService.forVerse(
      version: 'cuvs-yhwh',
      englishBook: '1 Corinthians',
      chapter: 13,
      verse: 1,
    );
    expect(runs, isNotNull,
        reason: '"1 Corinthians" must resolve to 1_corinthians.json');
  });

  group('referent glosses stay with the word they name', () {
    // The tagger walked the text word by word and treated 主[雅伟] as
    // ordinary prose, so the gloss straddled a run boundary: the half
    // carrying 雅伟] inherited the Strong's of whatever followed it.
    // Hovering 雅伟 then answered "angel". 雅伟 renders no Greek word
    // at all — it names the word printed in front of it.
    test('reunites a split gloss onto the opening run', () {
      final runs = TaggedTextService.reuniteGlossRuns(const [
        TaggedRun(text: '主 [', strongs: 'G2962'),
        TaggedRun(text: '雅伟] 的使者', strongs: 'G32'),
      ]);
      expect(runs, hasLength(2));
      expect(runs[0].text, '主[雅伟]');
      expect(runs[0].strongs, 'G2962',
          reason: 'the gloss belongs to the word it names');
      expect(runs[1].text, '的使者');
      expect(runs[1].strongs, 'G32');
    });

    test('leaves a supplied word alone', () {
      // [is] is inserted prose, not a pointer at its neighbour, and
      // every word inside such a bracket has a number of its own.
      final runs = TaggedTextService.reuniteGlossRuns(const [
        TaggedRun(text: 'the earth [', strongs: 'H776'),
        TaggedRun(text: 'was] formless', strongs: 'H1961'),
      ]);
      expect(runs[0].text, 'the earth [');
      expect(runs[1].text, 'was] formless');
    });

    test('text with no bracket is returned untouched', () {
      const input = [
        TaggedRun(text: '起初，', strongs: 'H7225'),
        TaggedRun(text: '神', strongs: 'H430'),
      ];
      expect(TaggedTextService.reuniteGlossRuns(input), same(input));
    });
  });
}
