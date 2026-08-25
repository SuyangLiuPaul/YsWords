import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-08-25. `scripts/extract_sermon_refs.py` decides which verses each
/// sermon is filed under, and it is Python — so nothing in `flutter
/// analyze` or the widget suite can see it regress. What ships is
/// `assets/sermons/refs.json`, and a wrong entry there does not look like
/// a bug: it looks like the preacher cited that verse.
///
/// These cases run the REAL script, not a Dart reimplementation of its
/// regex. A reimplementation would only prove Dart agrees with Dart; the
/// pattern being pinned is a 100-line `re` with conditional groups, and
/// every trap below was paid for by a wrong index entry.
List<String> _extractRefs(String text) => _extractAll([text]).single;

List<List<String>> _extractAll(List<String> texts) {
  const driver = r'''
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location(
    "esr", "scripts/extract_sermon_refs.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
json.dump([mod.extract_refs(t) for t in json.loads(sys.argv[1])], sys.stdout)
''';
  // The cases travel as one JSON argv element rather than through a
  // shell, so a quote or a comma in a sermon sentence cannot become
  // syntax. `Process.runSync` has no stdin to write to.
  final process = Process.runSync(
    'python3',
    ['-c', driver, jsonEncode(texts)],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  // Deliberately not skipped when python3 is absent: the runner has it,
  // and a guard that silently opts out is a guard nobody has tested.
  expect(process.exitCode, 0, reason: process.stderr.toString());
  return (jsonDecode(process.stdout as String) as List)
      .map((refs) => (refs as List).cast<String>())
      .toList();
}

void main() {
  test('the extraction script is where the test expects it', () {
    expect(File('scripts/extract_sermon_refs.py').existsSync(), isTrue);
  });

  group('a bare-comma number followed by "and" is a chapter list', () {
    // The defect this group was written for: REF_RE's chapter-list
    // refusal looks for a second COMMA, so "Matthew 5, 6 and 7" walks
    // past it and the adjacency rule makes 6 and 7 a two-verse range.
    test('"Matthew 5, 6 and 7" keeps the chapter and invents no verse', () {
      expect(_extractRefs('Matthew 5, 6 and 7 are the Sermon on the Mount'),
          ['Matthew 5']);
    });

    // What tells a chapter list from a verse range is that the list
    // COUNTS ON from the chapter. These pairs do not, so they are
    // verses — and all six are how the corpus actually writes them.
    test('a pair that does not count on from the chapter stays verses', () {
      expect(_extractAll([
        '2 Peter 2, 7 and 8, where it says of Lot that he was grieved',
        '1 Corinthians 15, 53 and 54: "For this perishable nature"',
        'almost in exactly the same words as in Matthew 5, 29 and 30.',
        // Not in the corpus today, but the shape this preacher uses when
        // he restates a reference he has just read out. A rule keyed on
        // "both numbers are plausible chapters" would lose every one.
        'Matthew 28, 19 and 20 is the Great Commission',
        'Romans 12, 1 and 2 says present your bodies',
        'Genesis 1, 26 and 27, let us make man in our image',
      ]), [
        ['2 Peter 2:7', '2 Peter 2:8'],
        ['1 Corinthians 15:53', '1 Corinthians 15:54'],
        ['Matthew 5:29', 'Matthew 5:30'],
        ['Matthew 28:19', 'Matthew 28:20'],
        ['Romans 12:1', 'Romans 12:2'],
        ['Genesis 1:26', 'Genesis 1:27'],
      ]);
    });

    // Scoped to `and` because that is how a list is spoken. Both these
    // pairs are plausible chapters of their book, so a rule that ignored
    // the separator would cost 015 the Beatitudes and 089 eight verses.
    test('"to" is a range word and is left alone', () {
      expect(_extractAll([
        'Matthew 5, 10 to 12. And this is what we read',
        'in Luke 14, 7 to 14, when you are invited',
      ]), [
        ['Matthew 5:10', 'Matthew 5:11', 'Matthew 5:12'],
        [
          'Luke 14:7', 'Luke 14:8', 'Luke 14:9', 'Luke 14:10',
          'Luke 14:11', 'Luke 14:12', 'Luke 14:13', 'Luke 14:14',
        ],
      ]);
    });
  });

  group('the older list and canon refusals still hold', () {
    test('a spelled-out chapter word makes the bare number a chapter', () {
      expect(_extractRefs('Those are the points made in Romans chapter 8, '
          '1 and 2: that the law of the Spirit of life'), ['Romans 8']);
      expect(_extractRefs('which Jesus already acknowledges in John '
          'chapters 12, 14 and 16. He is saying:'), ['John 12']);
    });

    test('…except past the end of the book, where it can only be a verse',
        () {
      // Hebrews has 13 chapters, so 848's "chapter 2, 14 and 15" has no
      // chapter reading available to it.
      expect(_extractRefs('as I mentioned in Hebrews chapter 2, 14 and 15 '
          'and so on'), ['Hebrews 2:14', 'Hebrews 2:15']);
    });

    test('a third comma-separated number is a list of chapters', () {
      expect(
          _extractRefs('in Romans 6, 7, and 8, we have three distinct '
              'categories'),
          ['Romans 6']);
    });

    test('a bare-comma restatement of one verse still reaches it', () {
      // How this preacher restates a reference he has just read out.
      expect(_extractRefs('Romans 8, 3, says what?'), ['Romans 8:3']);
    });
  });

  test('refs.json is in step with the script that writes it', () {
    // The script is only useful through its output. If someone changes a
    // rule and forgets to regenerate, the app keeps serving the old
    // index — and the change looks shipped when it is not.
    final refs = jsonDecode(File('assets/sermons/refs.json').readAsStringSync())
        as Map<String, dynamic>;
    final byVerse = refs['byVerse'] as Map<String, dynamic>;
    final bySermon = refs['bySermon'] as Map<String, dynamic>;
    expect(byVerse, isNotEmpty);
    expect(bySermon, isNotEmpty);

    // Every verse key must name a sermon that claims it back, and the
    // reverse. A half-regenerated file breaks exactly this.
    for (final entry in byVerse.entries) {
      for (final sid in (entry.value as List).cast<String>()) {
        expect((bySermon[sid] as List?)?.contains(entry.key), isTrue,
            reason: '${entry.key} lists $sid, which does not list it back');
      }
    }
  });
}
