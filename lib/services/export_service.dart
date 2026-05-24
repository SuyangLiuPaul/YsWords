/// User-data export — generates Markdown / JSON snapshots of the
/// user's highlights, bookmarks, and notes so they can back up
/// their work or move it to another note-taking app.
///
/// 2026-05-24 (v1.3.26): added in response to the "highlights /
/// notes export" priority item. Previously a user's months of
/// study work were trapped in SharedPreferences + Firebase RTDB
/// with no portable copy. Now Settings → Export shows a dialog
/// with a copy-to-clipboard textarea and (on web) a download
/// button.
///
/// Format choices:
///   • **Markdown** — section per data kind, one verse per line
///     with reference + content. Ready to paste into Notion /
///     Obsidian / Roam / Apple Notes / Google Docs.
///   • **JSON** — structured dump (highlights map + bookmarks
///     list + notes map + verse-note titles + timestamps).
///     Designed to be re-importable in a future round.
///
/// Pure functions — no I/O, no platform calls. The Settings dialog
/// is responsible for delivering the resulting strings to the user
/// (clipboard / web download).
library;

import 'dart:convert';

import 'package:yswords/constants/app_version.dart';
import 'package:yswords/providers/main_provider.dart';

class ExportService {
  /// Returns a Markdown document with three sections (Highlights,
  /// Bookmarks, Notes). Verses sorted by canonical Bible order
  /// inside each section. Title metadata at the top includes the
  /// app version + ISO-8601 export time + counts.
  static String toMarkdown(MainProvider mp) {
    final buf = StringBuffer();
    final now = DateTime.now().toUtc().toIso8601String();
    final highlightCount = mp.highlights.length;
    final bookmarkCount = mp.bookmarks.length;
    final noteCount = mp.verseNotes.length;
    buf.writeln('# YsWords export');
    buf.writeln();
    buf.writeln('- Generated: $now');
    buf.writeln('- App version: $kAppVersion');
    buf.writeln(
        '- Counts: $highlightCount highlights · $bookmarkCount bookmarks · $noteCount notes');
    buf.writeln();

    // ── Highlights ────────────────────────────────────────
    buf.writeln('## Highlights');
    buf.writeln();
    if (mp.highlights.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      final sorted = mp.highlights.keys.toList()
        ..sort(_verseIdCompare);
      for (final id in sorted) {
        final colorHex =
            '#${mp.highlights[id]!.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
        buf.writeln('- **${_formatRef(id)}** — colour $colorHex');
      }
    }
    buf.writeln();

    // ── Bookmarks ─────────────────────────────────────────
    buf.writeln('## Bookmarks');
    buf.writeln();
    if (mp.bookmarks.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      final sorted = mp.bookmarks.toList()..sort(_verseIdCompare);
      for (final id in sorted) {
        buf.writeln('- **${_formatRef(id)}**');
      }
    }
    buf.writeln();

    // ── Notes ─────────────────────────────────────────────
    buf.writeln('## Notes');
    buf.writeln();
    if (mp.verseNotes.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      final sorted = mp.verseNotes.keys.toList()..sort(_verseIdCompare);
      for (final id in sorted) {
        final title = mp.verseNoteTitles[id];
        final text = mp.verseNotes[id] ?? '';
        final ts = mp.verseNoteTimestamps[id];
        buf.writeln('### ${_formatRef(id)}'
            '${title != null && title.isNotEmpty ? ' — $title' : ''}');
        if (ts != null) {
          final iso =
              DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true)
                  .toIso8601String();
          buf.writeln();
          // Curly braces around iso so Dart doesn't fold the trailing
          // underscore into the variable name (`$iso_` would be
          // parsed as the identifier `iso_`).
          buf.writeln('_Updated: ${iso}_');
        }
        buf.writeln();
        buf.writeln(text);
        buf.writeln();
      }
    }
    return buf.toString();
  }

  /// Returns a JSON document. Designed to be re-importable later;
  /// the schema is versioned so a future schema bump can be
  /// migrated cleanly.
  static String toJson(MainProvider mp, {bool pretty = true}) {
    final root = <String, dynamic>{
      'schema': 'yswords-export',
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': kAppVersion,
      'counts': {
        'highlights': mp.highlights.length,
        'bookmarks': mp.bookmarks.length,
        'notes': mp.verseNotes.length,
      },
      'highlights': mp.highlights, // verseId -> ARGB int
      'bookmarks': mp.bookmarks.toList()..sort(_verseIdCompare),
      'notes': {
        for (final id in mp.verseNotes.keys)
          id: {
            'text': mp.verseNotes[id],
            if (mp.verseNoteTitles[id] != null &&
                mp.verseNoteTitles[id]!.isNotEmpty)
              'title': mp.verseNoteTitles[id],
            if (mp.verseNoteTimestamps[id] != null)
              'updatedAtMs': mp.verseNoteTimestamps[id],
          },
      },
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(root)
        : jsonEncode(root);
  }

  /// Suggest a filename for the given format. Includes ISO date so
  /// successive exports don't overwrite each other in Downloads.
  static String suggestFilename({required String extension}) {
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'yswords-export-$stamp.$extension';
  }

  // ── Helpers ──────────────────────────────────────────────

  /// Canonical Bible order — used to sort exported lines. Returns
  /// a positive int when [a] should come AFTER [b].
  static int _verseIdCompare(String a, String b) {
    final pa = _parseId(a);
    final pb = _parseId(b);
    final bookCmp = _bookOrder(pa.book).compareTo(_bookOrder(pb.book));
    if (bookCmp != 0) return bookCmp;
    if (pa.chapter != pb.chapter) {
      return pa.chapter.compareTo(pb.chapter);
    }
    // Verse labels can be non-numeric (e.g., "23a"); compare as
    // ints when both parse, otherwise lexicographic.
    final na = int.tryParse(pa.verseLabel);
    final nb = int.tryParse(pb.verseLabel);
    if (na != null && nb != null) return na.compareTo(nb);
    return pa.verseLabel.compareTo(pb.verseLabel);
  }

  static ({String book, int chapter, String verseLabel}) _parseId(
      String id) {
    // Walk from the right: verseLabel is the last `-`-separated
    // segment, chapter is the second-to-last, everything before is
    // the book (which can itself contain `-` for "Song-of-Songs").
    final lastDash = id.lastIndexOf('-');
    if (lastDash < 0) return (book: id, chapter: 0, verseLabel: '0');
    final verseLabel = id.substring(lastDash + 1);
    final rest = id.substring(0, lastDash);
    final chapDash = rest.lastIndexOf('-');
    if (chapDash < 0) return (book: rest, chapter: 0, verseLabel: verseLabel);
    final chapter = int.tryParse(rest.substring(chapDash + 1)) ?? 0;
    final book = rest.substring(0, chapDash);
    return (book: book, chapter: chapter, verseLabel: verseLabel);
  }

  static String _formatRef(String id) {
    final p = _parseId(id);
    return '${p.book} ${p.chapter}:${p.verseLabel}';
  }

  static int _bookOrder(String englishBook) {
    final idx = _kBookOrder.indexOf(englishBook);
    return idx < 0 ? 999 : idx;
  }
}

const List<String> _kBookOrder = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth',
  '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
  '1 Chronicles', '2 Chronicles',
  'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
  'Ecclesiastes', 'Song of Solomon',
  'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
  'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
  'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
  'Matthew', 'Mark', 'Luke', 'John', 'Acts',
  'Romans', '1 Corinthians', '2 Corinthians',
  'Galatians', 'Ephesians', 'Philippians', 'Colossians',
  '1 Thessalonians', '2 Thessalonians',
  '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
  'James', '1 Peter', '2 Peter',
  '1 John', '2 John', '3 John', 'Jude', 'Revelation',
];
