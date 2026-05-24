/// 2026-05-24 (v1.3.26): regression tests for ExportService.
///
/// Pure-function service — no I/O, no Flutter widget tree, easy to
/// test. Covers Markdown headings + JSON schema + verse-ID sort
/// order + filename suggestion shape.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExportService.toMarkdown', () {
    test('empty MainProvider → header + empty sections', () {
      final mp = MainProvider();
      final md = ExportService.toMarkdown(mp);
      expect(md, contains('# YsWords export'));
      expect(md, contains('## Highlights'));
      expect(md, contains('## Bookmarks'));
      expect(md, contains('## Notes'));
      expect(md, contains('_(none)_'));
      expect(md, contains('Counts: 0 highlights · 0 bookmarks · 0 notes'));
    });

    test('with one highlight + one bookmark + one note → all 3 sections render', () {
      final mp = MainProvider();
      final v = const Verse(
          book: 'John', chapter: 3, verse: 16, text: 'For God so loved...');
      mp.setHighlight(verse: v, color: 0xFFFFFF00);
      mp.toggleBookmark(verse: v);
      mp.setVerseNote(verse: v, text: 'Core gospel verse', title: 'KEY');

      final md = ExportService.toMarkdown(mp);
      // Highlights section includes the verse + colour
      expect(md, contains('John 3:16'));
      expect(md, contains('colour'));
      // Bookmarks section
      expect(md, matches(RegExp(r'## Bookmarks\s+\n\s*- \*\*John 3:16\*\*')));
      // Notes section: header includes title + body includes text
      expect(md, contains('### John 3:16 — KEY'));
      expect(md, contains('Core gospel verse'));
      // Counts updated
      expect(
          md, contains('Counts: 1 highlights · 1 bookmarks · 1 notes'));
    });

    test('verses sort by canonical Bible order, not insertion order',
        () {
      final mp = MainProvider();
      // Insert in reverse-canonical order: NT then OT.
      final rev = const Verse(
          book: 'Revelation', chapter: 22, verse: 21, text: 'r');
      final gen = const Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'g');
      final psa = const Verse(book: 'Psalms', chapter: 23, verse: 1, text: 'p');
      mp.toggleBookmark(verse: rev);
      mp.toggleBookmark(verse: gen);
      mp.toggleBookmark(verse: psa);

      final md = ExportService.toMarkdown(mp);
      final iGen = md.indexOf('Genesis 1:1');
      final iPsa = md.indexOf('Psalms 23:1');
      final iRev = md.indexOf('Revelation 22:21');
      expect(iGen, greaterThan(0));
      expect(iPsa, greaterThan(iGen));
      expect(iRev, greaterThan(iPsa));
    });
  });

  group('ExportService.toJson', () {
    test('returns valid JSON with the documented schema', () {
      final mp = MainProvider();
      final v = const Verse(book: 'Genesis', chapter: 1, verse: 1, text: '');
      mp.setHighlight(verse: v, color: 0xFFFF0000);
      mp.setVerseNote(verse: v, text: 'In the beginning');

      final out = ExportService.toJson(mp);
      // Parses cleanly
      final parsed = jsonDecode(out) as Map<String, dynamic>;
      expect(parsed['schema'], 'yswords-export');
      expect(parsed['schemaVersion'], 1);
      expect(parsed['generatedAt'], isA<String>());
      expect(parsed['appVersion'], isA<String>());
      expect(parsed['counts'], isA<Map>());
      expect(parsed['counts']['highlights'], 1);
      expect(parsed['highlights'], isA<Map>());
      expect((parsed['highlights'] as Map)['Genesis-1-1'], 0xFFFF0000);
      expect(parsed['notes'], isA<Map>());
      expect(
          (parsed['notes'] as Map)['Genesis-1-1']['text'], 'In the beginning');
    });

    test('pretty=false produces compact single-line JSON', () {
      final mp = MainProvider();
      final out = ExportService.toJson(mp, pretty: false);
      expect(out, isNot(contains('\n  '))); // no indented newlines
      // Still parses.
      expect(jsonDecode(out), isA<Map>());
    });

    test('bookmarks are sorted canonically in the JSON output', () {
      final mp = MainProvider();
      mp.toggleBookmark(
          verse: const Verse(book: 'John', chapter: 1, verse: 1, text: ''));
      mp.toggleBookmark(verse: const Verse(
          book: 'Genesis', chapter: 1, verse: 1, text: ''));
      final parsed = jsonDecode(ExportService.toJson(mp))
          as Map<String, dynamic>;
      final bookmarks = (parsed['bookmarks'] as List).cast<String>();
      expect(bookmarks, ['Genesis-1-1', 'John-1-1']);
    });
  });

  group('ExportService.suggestFilename', () {
    test('contains yswords-export prefix + extension + date stamp', () {
      final md = ExportService.suggestFilename(extension: 'md');
      final json = ExportService.suggestFilename(extension: 'json');
      expect(md, startsWith('yswords-export-'));
      expect(md, endsWith('.md'));
      expect(json, endsWith('.json'));
      // Stamp must be yyyymmdd-hhmm (8 digits, dash, 4 digits).
      final body = md.substring('yswords-export-'.length,
          md.length - '.md'.length);
      expect(body, matches(RegExp(r'^\d{8}-\d{4}$')));
    });
  });
}
