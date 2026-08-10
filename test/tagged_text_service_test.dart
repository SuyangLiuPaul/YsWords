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

  test('only the Simplified 雅伟版 claims tagging', () {
    expect(TaggedTextService.supports('cuvs-yhwh'), isTrue);
    // No Traditional tagged set exists. Claiming otherwise would put a
    // gesture on screen that answers nothing.
    expect(TaggedTextService.supports('cuvs-yhwh-tr'), isFalse);
    expect(TaggedTextService.supports('kjv'), isFalse);
    expect(TaggedTextService.supports('nasb'), isFalse);
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
