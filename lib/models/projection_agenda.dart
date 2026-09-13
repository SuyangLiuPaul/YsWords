// The order of service: what goes on the wall, in the order it is
// needed, prepared before anyone is in the room.
//
// This is the piece a projector operator actually plans with. Until now
// the projection could only follow the reader — fine for a study, wrong
// for a service, where the passages are decided on Thursday and the
// person driving on Sunday should not be hunting for 以賽亞書 53 while
// the congregation waits. VideoPsalm calls it an agenda; the word here
// is 程序, which is what a Chinese-speaking church prints on the sheet.
//
// An item is a REFERENCE, not a copy of the text. The wall resolves it
// against whatever edition is loaded at the time, so an agenda built in
// 和合本 still works if the operator switches edition on the day, and a
// corpus update is never stale inside somebody's saved order.
//
// Deliberately NOT a slide editor. There is no per-item font, colour or
// background: those are the projection's settings and presets, and a
// service where every passage looks different is a service about the
// projector. See `projection_page.dart`'s "WHAT THIS DELIBERATELY IS
// NOT".

import 'package:flutter/foundation.dart';

/// What one row of the agenda puts on the wall.
enum AgendaKind {
  /// A passage: [AgendaItem.book] / [AgendaItem.chapter] / [AgendaItem.verse],
  /// for [AgendaItem.count] verses.
  passage,

  /// A dark wall, deliberately — between items, or while somebody prays.
  blank,
}

@immutable
class AgendaItem {
  const AgendaItem({
    required this.kind,
    this.book = '',
    this.chapter = 0,
    this.verse = 0,
    this.count = 1,
    this.note = '',
  });

  const AgendaItem.blank({String note = ''})
      : this(kind: AgendaKind.blank, note: note);

  final AgendaKind kind;

  /// The book as the edition that built this names it. Resolved through
  /// `bookNameToEnglish` at use, so an agenda built in one language
  /// still finds its book in another.
  final String book;
  final int chapter;

  /// One-based verse number, as printed — not an index into a chapter.
  /// An index would silently mean a different verse the moment an
  /// edition merges or splits one.
  final int verse;

  /// How many verses from [verse] go up at once.
  final int count;

  /// The operator's own label — 「講道經文」, 「回應詩前」. Shown in the
  /// agenda, never on the wall: the room reads scripture, not our
  /// stage directions.
  final String note;

  /// `以賽亞書 53:4–6`, or the note alone for a blank.
  String get label {
    if (kind == AgendaKind.blank) return note.isEmpty ? '—' : note;
    final ref = count > 1
        ? '$book $chapter:$verse–${verse + count - 1}'
        : '$book $chapter:$verse';
    return note.isEmpty ? ref : '$ref · $note';
  }

  AgendaItem copyWith({String? note}) => AgendaItem(
        kind: kind,
        book: book,
        chapter: chapter,
        verse: verse,
        count: count,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        if (kind == AgendaKind.passage) ...{
          'book': book,
          'chapter': chapter,
          'verse': verse,
          'count': count,
        },
        if (note.isNotEmpty) 'note': note,
      };

  /// Null for anything that is not a usable row. A stored agenda is
  /// read back on every launch, and one bad row must not cost the
  /// operator the rest of their order of service.
  static AgendaItem? fromJson(Map<String, dynamic> m) {
    final note = m['note'] is String ? m['note'] as String : '';
    if (m['kind'] == 'blank') return AgendaItem.blank(note: note);
    if (m['kind'] != 'passage') return null;
    final book = m['book'];
    final chapter = m['chapter'];
    final verse = m['verse'];
    if (book is! String || book.isEmpty) return null;
    if (chapter is! num || verse is! num) return null;
    if (chapter <= 0 || verse <= 0) return null;
    final count = m['count'];
    return AgendaItem(
      kind: AgendaKind.passage,
      book: book,
      chapter: chapter.toInt(),
      verse: verse.toInt(),
      count: count is num && count >= 1 ? count.toInt() : 1,
      note: note,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AgendaItem &&
      other.kind == kind &&
      other.book == book &&
      other.chapter == chapter &&
      other.verse == verse &&
      other.count == count &&
      other.note == note;

  @override
  int get hashCode => Object.hash(kind, book, chapter, verse, count, note);

  @override
  String toString() => 'AgendaItem(${kind.name}, $label)';
}

/// Decode a stored agenda, dropping rows that no longer parse.
List<AgendaItem> decodeAgenda(Object? raw) {
  if (raw is! List) return const [];
  final out = <AgendaItem>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final item = AgendaItem.fromJson(e.cast<String, dynamic>());
    if (item != null) out.add(item);
  }
  return out;
}
