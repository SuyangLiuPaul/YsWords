/// 2026-08-03 (v1.4.0): regression tests for ImportService, the
/// reverse of ExportService. Mirrors test/export_service_test.dart's
/// structure — pure-function service, MainProvider() instantiates
/// directly without extra scaffolding.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/export_service.dart';
import 'package:yswords/services/import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportService.parse — schema validation', () {
    test('missing schema field throws FormatException', () {
      expect(() => ImportService.parse('{"schemaVersion": 1}'),
          throwsFormatException);
    });

    test('wrong schema value throws FormatException', () {
      expect(
          () => ImportService.parse(
              '{"schema": "something-else", "schemaVersion": 1}'),
          throwsFormatException);
    });

    test('missing schemaVersion throws FormatException', () {
      expect(() => ImportService.parse('{"schema": "yswords-export"}'),
          throwsFormatException);
    });

    test('unsupported schemaVersion throws FormatException', () {
      expect(
          () => ImportService.parse(
              '{"schema": "yswords-export", "schemaVersion": 2}'),
          throwsFormatException);
    });

    test('malformed JSON propagates FormatException from jsonDecode', () {
      expect(() => ImportService.parse('not json at all'),
          throwsFormatException);
    });

    test('a JSON array (not object) at the top level throws', () {
      expect(() => ImportService.parse('[1,2,3]'), throwsFormatException);
    });
  });

  group('ImportService.parse — round-trip with ExportService', () {
    test('exported highlights/bookmarks/notes parse back identically', () {
      final mp = MainProvider();
      final v1 = const Verse(
          book: 'John', chapter: 3, verse: 16, text: 'For God so loved...');
      final v2 = const Verse(
          book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning');
      mp.setHighlight(verse: v1, color: 0xFFFFFF00);
      mp.toggleBookmark(verse: v1);
      mp.toggleBookmark(verse: v2);
      mp.setVerseNote(verse: v1, text: 'Core gospel verse', title: 'KEY');

      final exported = ExportService.toJson(mp);
      final parsed = ImportService.parse(exported);

      expect(parsed.highlights, {'John-3-16': 0xFFFFFF00});
      expect(parsed.bookmarks.toSet(), {'John-3-16', 'Genesis-1-1'});
      expect(parsed.notes.keys, ['John-3-16']);
      expect(parsed.notes['John-3-16']!.text, 'Core gospel verse');
      expect(parsed.notes['John-3-16']!.title, 'KEY');
      expect(parsed.notes['John-3-16']!.updatedAtMs, isNotNull);
      // 1 highlight + 2 bookmarks + 1 note.
      expect(parsed.totalCount, 4);
    });

    test('empty export round-trips to all-empty ParsedImport', () {
      final mp = MainProvider();
      final parsed = ImportService.parse(ExportService.toJson(mp));
      expect(parsed.highlights, isEmpty);
      expect(parsed.bookmarks, isEmpty);
      expect(parsed.notes, isEmpty);
      expect(parsed.totalCount, 0);
    });

    test('note without a title round-trips with title null', () {
      final mp = MainProvider();
      final v = const Verse(book: 'Psalms', chapter: 23, verse: 1, text: '');
      mp.setVerseNote(verse: v, text: 'The Lord is my shepherd');
      final parsed = ImportService.parse(ExportService.toJson(mp));
      expect(parsed.notes['Psalms-23-1']!.title, isNull);
    });
  });

  group('ImportService.parse — defensive/forgiving entry parsing', () {
    test('malformed individual highlight entries are skipped, not fatal',
        () {
      const json = '{'
          '"schema": "yswords-export", "schemaVersion": 1, '
          '"highlights": {"Genesis-1-1": 100, "John-1-1": "not-a-number"}, '
          '"bookmarks": [], "notes": {}'
          '}';
      final parsed = ImportService.parse(json);
      expect(parsed.highlights, {'Genesis-1-1': 100});
    });

    test('non-string bookmark entries are skipped', () {
      const json = '{'
          '"schema": "yswords-export", "schemaVersion": 1, '
          '"highlights": {}, "bookmarks": ["Genesis-1-1", 42, null], '
          '"notes": {}'
          '}';
      final parsed = ImportService.parse(json);
      expect(parsed.bookmarks, ['Genesis-1-1']);
    });

    test('a note entry missing "text" is skipped', () {
      const json = '{'
          '"schema": "yswords-export", "schemaVersion": 1, '
          '"highlights": {}, "bookmarks": [], '
          '"notes": {"Genesis-1-1": {"title": "no body"}, '
          '"John-1-1": {"text": "has body"}}'
          '}';
      final parsed = ImportService.parse(json);
      expect(parsed.notes.keys, ['John-1-1']);
    });
  });

  group('MainProvider.importMergedData — merge semantics', () {
    test('imported highlight overwrites an existing different color', () {
      final mp = MainProvider();
      final v = const Verse(book: 'Genesis', chapter: 1, verse: 1, text: '');
      mp.setHighlight(verse: v, color: 0xFFFF0000);
      mp.importMergedData(highlights: {'Genesis-1-1': 0xFF00FF00});
      expect(mp.highlights['Genesis-1-1'], 0xFF00FF00);
    });

    test('import adds to existing data without disturbing other verses',
        () {
      final mp = MainProvider();
      final existing =
          const Verse(book: 'John', chapter: 3, verse: 16, text: '');
      mp.toggleBookmark(verse: existing);
      mp.importMergedData(bookmarks: ['Genesis-1-1']);
      expect(mp.bookmarks, {'John-3-16', 'Genesis-1-1'});
    });

    test('imported note overwrites existing text/title for the same verse',
        () {
      final mp = MainProvider();
      final v = const Verse(book: 'Psalms', chapter: 23, verse: 1, text: '');
      mp.setVerseNote(verse: v, text: 'old text', title: 'old title');
      mp.importMergedData(notes: {
        'Psalms-23-1': (text: 'new text', title: 'new title', updatedAtMs: null),
      });
      expect(mp.verseNotes['Psalms-23-1'], 'new text');
      expect(mp.verseNoteTitles['Psalms-23-1'], 'new title');
    });

    test('returns accurate applied counts', () {
      final mp = MainProvider();
      final result = mp.importMergedData(
        highlights: {'Genesis-1-1': 0xFFFF0000},
        bookmarks: ['Genesis-1-1', 'John-3-16'],
        notes: {
          'Genesis-1-1': (text: 'note', title: null, updatedAtMs: null),
        },
      );
      expect(result.highlights, 1);
      expect(result.bookmarks, 2);
      expect(result.notes, 1);
    });

    test('calling with all-empty arguments is a safe no-op', () {
      final mp = MainProvider();
      final v = const Verse(book: 'John', chapter: 3, verse: 16, text: '');
      mp.toggleBookmark(verse: v);
      final result = mp.importMergedData();
      expect(result, (highlights: 0, bookmarks: 0, notes: 0));
      expect(mp.bookmarks, {'John-3-16'});
    });
  });
}
