/// User-data import — the reverse of [ExportService]: parses a
/// previously-exported JSON string back into structured
/// highlights/bookmarks/notes data, ready for
/// `MainProvider.importMergedData`.
///
/// 2026-08-03 (v1.4.0): added in response to "export exists, but there's
/// no way to bring that data back in." Only the JSON format is
/// importable — `ExportService`'s own doc comment already says Markdown
/// is prose for pasting into other apps, not reliably re-parseable;
/// JSON is the one "designed to be re-importable" format.
///
/// Pure function — no I/O, no platform calls, no Flutter dependency.
/// Parsing is deliberately forgiving at the entry level (an individual
/// malformed highlight/bookmark/note is skipped, not fatal) but strict
/// at the schema level (wrong `schema`/`schemaVersion` throws) — a
/// stray unrelated JSON file should be rejected outright, but a mostly-
/// good export with one corrupted entry should still import the rest.
library;

import 'dart:convert';

/// Result of a successful [ImportService.parse] call. Field shapes
/// mirror [ExportService.toJson]'s output exactly, so a value produced
/// here can be passed straight into `MainProvider.importMergedData`.
class ParsedImport {
  final Map<String, int> highlights;
  final List<String> bookmarks;
  final Map<String, ({String text, String? title, int? updatedAtMs})> notes;

  const ParsedImport({
    required this.highlights,
    required this.bookmarks,
    required this.notes,
  });

  int get totalCount => highlights.length + bookmarks.length + notes.length;
}

class ImportService {
  static const _schema = 'yswords-export';
  static const _schemaVersion = 1;

  /// Parses [raw] as a YsWords export JSON string.
  ///
  /// Throws [FormatException] when:
  ///   - [raw] isn't valid JSON at all (propagated from `jsonDecode`).
  ///   - the decoded value isn't a JSON object.
  ///   - `schema` isn't `"yswords-export"` — this isn't one of our
  ///     export files at all.
  ///   - `schemaVersion` isn't a version this app understands. Only `1`
  ///     exists today; a future bump would add a migration branch here
  ///     rather than widen this check.
  static ParsedImport parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // 2026-08-03: only JSON round-trips — Markdown export is prose
      // for pasting into OTHER apps (Notion/Obsidian/etc.), not
      // structured data, so there's nothing here to parse it back
      // into. The two formats share a recognizable header
      // ("# YsWords export" — see ExportService.toMarkdown), so catch
      // this specific mix-up with a helpful message instead of a bare
      // JSON-syntax error that would leave a user wondering why their
      // own export doesn't import.
      if (raw.trimLeft().startsWith('# YsWords export')) {
        throw const FormatException(
            'This looks like a Markdown export. Import only supports '
            'the JSON format — switch to JSON in the Export dialog and '
            'paste that instead.');
      }
      rethrow;
    }
    if (decoded is! Map) {
      throw const FormatException('Not a YsWords export file.');
    }
    if (decoded['schema'] != _schema) {
      throw const FormatException('Not a YsWords export file.');
    }
    final version = decoded['schemaVersion'];
    if (version != _schemaVersion) {
      throw FormatException('Unsupported export version: $version');
    }

    final highlights = <String, int>{};
    final rawHighlights = decoded['highlights'];
    if (rawHighlights is Map) {
      for (final entry in rawHighlights.entries) {
        final value = entry.value;
        if (value is num) {
          highlights[entry.key.toString()] = value.toInt();
        }
      }
    }

    final bookmarks = <String>[];
    final rawBookmarks = decoded['bookmarks'];
    if (rawBookmarks is List) {
      for (final v in rawBookmarks) {
        if (v is String) bookmarks.add(v);
      }
    }

    final notes = <String, ({String text, String? title, int? updatedAtMs})>{};
    final rawNotes = decoded['notes'];
    if (rawNotes is Map) {
      for (final entry in rawNotes.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final text = value['text'];
        if (text is! String) continue;
        final title = value['title'];
        final updatedAtMs = value['updatedAtMs'];
        notes[entry.key.toString()] = (
          text: text,
          title: title is String ? title : null,
          updatedAtMs: updatedAtMs is num ? updatedAtMs.toInt() : null,
        );
      }
    }

    return ParsedImport(
      highlights: highlights,
      bookmarks: bookmarks,
      notes: notes,
    );
  }
}
