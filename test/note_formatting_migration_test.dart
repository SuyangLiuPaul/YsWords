// 2026-09-03: notes gained formatting — bold, italic, lists — and the
// only question that could break existing users was the STORAGE format.
//
// The decision: a note stays exactly what it has always been, a plain
// `String` in `MainProvider._verseNotes`, JSON-encoded into
// SharedPreferences and into the RTDB / Firestore snapshot. The only
// change is that the string is now *interpreted* as a small Markdown
// subset when it is rendered. No structured document, no wrapper
// object, no schema version, no migration step — because every note
// ever written is already a valid document in that subset.
//
// This file is the proof. It pins the two properties that make the
// "no migration" claim true:
//
//   1. ROUND TRIP. Loading a stored note into the editor and saving it
//      again, through the real `normalizeNoteReferenceBookNames` +
//      `setVerseNote`'s trim + the real `jsonEncode`/`jsonDecode` the
//      persistence and sync paths use, returns the note unchanged —
//      including notes that happen to contain `*` or `_`.
//
//   2. NO CHARACTER IS EATEN IN THE EDITOR. `NoteMarkdownMode.source`
//      (what the note editor's `TextEditingController` renders) styles
//      the delimiters but never removes them, so the concatenated span
//      text is identical to the controller's text. Flutter asserts on
//      any other shape, and `spliceComposingUnderline` walks these
//      spans by absolute character offset.
//
// It also pins the reason the inline grammar is stricter than
// `ai_markdown.dart`'s: CommonMark flanking rules. `5 * 4 = 20` must
// stay `5 * 4 = 20`, not silently italicise into `5 4 = 20`.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/note_markdown.dart';
import 'package:yswords/utils/note_reference_parser.dart';

/// The complete load → edit → save → persist → sync → load chain a note
/// goes through when the user opens the editor and taps Save without
/// changing anything, built out of the real functions in that path.
///
///   • `showNoteEditor`'s Save handler calls
///     `normalizeNoteReferenceBookNames` (bible_reading_pane.dart).
///   • `MainProvider.setVerseNote` trims before storing.
///   • `MainProvider._saveNotes` does `jsonEncode(_verseNotes)`;
///     `_loadNotes` casts each value straight back to `String`.
///   • `CloudSyncService._mergeSnapshots` / `RealtimeDbSyncService`
///     re-encode the same map — `_parseJsonMap` + `jsonEncode`, no
///     transformation of the value at all.
String _saveRoundTrip(String stored) {
  final normalized = normalizeNoteReferenceBookNames(stored, (c) => c);
  final persisted = normalized.trim();
  final wire = jsonEncode(<String, String>{'Gen.1.1': persisted});
  final decoded = jsonDecode(wire) as Map<String, dynamic>;
  return decoded['Gen.1.1'] as String;
}

/// Concatenated text of the spans `buildNoteSpans` produces — i.e.
/// exactly the characters the user ends up looking at.
String _rendered(String noteText, NoteMarkdownMode mode) {
  final spans = buildNoteSpans(
    noteText: noteText,
    baseStyle: const TextStyle(),
    refColor: const Color(0xFF000000),
    markdown: mode,
  );
  final buf = StringBuffer();
  for (final s in spans) {
    if (s is TextSpan) buf.write(s.text ?? '');
  }
  return buf.toString();
}

/// Notes written before formatting existed. Every one of them is a
/// plain-text note a real user could already have on their device and
/// in the cloud snapshot today.
///
/// All of them are trimmed, because a *stored* note always is —
/// `setVerseNote` has trimmed since long before formatting, and an
/// empty body deletes the note. Untrimmed input is covered separately
/// by the idempotence test.
const _legacyNotes = <String>[
  'Just a note about prayer.',
  'God is love — 1 John 4:8',
  // A CJK note. Its bracketed reference is written in the form the
  // save-time book-name normaliser already produces for this locale —
  // see the `pre-existing rewrites` group below for why that matters.
  '看这里 [John 3:16] 很重要',
  // Asterisks used as arithmetic, separators and emphasis-by-hand.
  '5 * 4 = 20',
  'a * b * c',
  'Priority: * high * urgent * today',
  '*',
  '**',
  '***',
  '****',
  '* unfinished',
  // Underscores used in identifiers and as filler.
  'snake_case_variable',
  '__dunder__ and my_var_name',
  '_',
  '___',
  'fill in the blank: ___________',
  // Things that ARE formatting under the new subset. They must still
  // round trip byte-for-byte — rendering them differently is the
  // feature; storing them differently would be the bug.
  '*italic*',
  '**bold**',
  '***both***',
  '_also italic_',
  '- first\n- second\n- third',
  '1. first\n2. second',
  'A **bold** claim about [John 3:16] worth checking',
  // Mixed scripts and punctuation the reference parser also touches.
  '默想：[Matthew 5:3-10] 八福\n- 虚心的人\n- 哀恸的人',
  'Multi\nline\n\nwith blank lines',
  'trailing bracket ] and [unclosed',
];

void main() {
  group('storage format — an existing plain-text note survives untouched',
      () {
    test('every legacy note round trips byte-for-byte', () {
      for (final note in _legacyNotes) {
        expect(
          _saveRoundTrip(note),
          note,
          reason: 'load/save round trip changed a stored note: '
              '${jsonEncode(note)} became ${jsonEncode(_saveRoundTrip(note))}',
        );
      }
    });

    test('notes containing * or _ specifically round trip unchanged', () {
      const starry = 'Priority: * high * urgent * today — 5 * 4 = 20';
      const underscored = 'my_var_name plus __dunder__ plus ___';
      expect(_saveRoundTrip(starry), starry);
      expect(_saveRoundTrip(underscored), underscored);
    });

    test('the round trip is idempotent for untrimmed input too', () {
      // `setVerseNote` trims, so a *stored* note never has surrounding
      // whitespace; anything the user types converges after one save.
      for (final raw in <String>['  padded  ', '\n\n*x*\n\n', '\t- a\n- b\t']) {
        final once = _saveRoundTrip(raw);
        expect(_saveRoundTrip(once), once,
            reason: 'second save changed the note again: ${jsonEncode(raw)}');
      }
    });

    test('a note is still just a String — no wrapper, no schema version',
        () {
      // If anyone ever swaps the storage for a structured document,
      // this is the assertion that should stop them: the value the
      // sync path carries has to stay assignable to String.
      final decoded =
          jsonDecode(jsonEncode(<String, String>{'Gen.1.1': '**bold**'}));
      final value = (decoded as Map<String, dynamic>)['Gen.1.1'];
      expect(value, isA<String>());
      expect(value, '**bold**');
    });
  });

  group('pre-existing rewrites, and their independence from formatting', () {
    // The save path is not a pure identity and never was: since
    // 2026-08-02 it rewrites each valid `[Book Ch:V]` reference's book
    // name into the current locale's form, so a quick English
    // abbreviation typed into a Chinese note stops disagreeing with the
    // ref-chip strip below it. That is deliberate, it is covered by
    // note_editor_live_localize_ref_test.dart, and it predates
    // formatting. What matters here is that it is the ONLY rewrite —
    // that adding formatting did not add a second one.
    test('book names inside brackets are localized at save (as before)', () {
      expect(
        normalizeNoteReferenceBookNames('看这里 [约翰福音 3:16] 很重要',
            (canonical) => canonical),
        '看这里 [John 3:16] 很重要',
      );
    });

    test('the rewrite never touches a formatting character', () {
      const note =
          '**bold** and *italic* and _under_ and 5 * 4\n- a\n- b [John 3:16]';
      // Same book name in, same book name out: everything except the
      // bracket contents must come through byte-for-byte.
      expect(normalizeNoteReferenceBookNames(note, (c) => c), note);
    });

    test('a note with no reference is untouched by the save rewrite', () {
      for (final note in _legacyNotes) {
        final out = normalizeNoteReferenceBookNames(note, (c) => c);
        expect(out.length, note.length,
            reason: 'save rewrite changed the length of ${jsonEncode(note)}');
      }
    });
  });

  group('editor rendering never eats a character', () {
    test('source mode reproduces the note text exactly', () {
      for (final note in _legacyNotes) {
        expect(
          _rendered(note, NoteMarkdownMode.source),
          note,
          reason: 'source-mode spans did not concatenate back to the note: '
              '${jsonEncode(note)}',
        );
      }
    });

    test('off mode reproduces the note text exactly', () {
      for (final note in _legacyNotes) {
        expect(_rendered(note, NoteMarkdownMode.off), note);
      }
    });
  });

  group('render mode hides delimiters only where they are formatting', () {
    test('emphasis delimiters are dropped', () {
      expect(_rendered('*italic*', NoteMarkdownMode.render), 'italic');
      expect(_rendered('**bold**', NoteMarkdownMode.render), 'bold');
      expect(_rendered('***both***', NoteMarkdownMode.render), 'both');
      expect(_rendered('_also italic_', NoteMarkdownMode.render), 'also italic');
    });

    test('asterisks that are not formatting stay on screen', () {
      // The whole point of the flanking rules. A legacy note must not
      // lose characters just because it happens to contain `*`.
      expect(_rendered('5 * 4 = 20', NoteMarkdownMode.render), '5 * 4 = 20');
      expect(_rendered('a * b * c', NoteMarkdownMode.render), 'a * b * c');
      expect(
        _rendered('Priority: * high * urgent * today', NoteMarkdownMode.render),
        'Priority: * high * urgent * today',
      );
      expect(_rendered('****', NoteMarkdownMode.render), '****');
      expect(_rendered('*', NoteMarkdownMode.render), '*');
    });

    test('intraword underscores stay on screen', () {
      expect(
        _rendered('snake_case_variable', NoteMarkdownMode.render),
        'snake_case_variable',
      );
      expect(
        _rendered('fill in the blank: ___________', NoteMarkdownMode.render),
        'fill in the blank: ___________',
      );
    });

    test('list markers become bullets, ordered markers stay as typed', () {
      expect(
        _rendered('- first\n- second', NoteMarkdownMode.render),
        '• first\n• second',
      );
      expect(
        _rendered('1. first\n2. second', NoteMarkdownMode.render),
        '1. first\n2. second',
      );
    });

    test('render is the DEFAULT, so a new display site is formatted', () {
      // This is the structural half of "a formatted note must display
      // formatted everywhere a note is shown". Anyone adding a note
      // display site gets formatting without knowing to ask for it;
      // the only caller that opts out is the editor's controller, and
      // it says so explicitly. If this default is ever flipped, the
      // guarantee quietly becomes a convention.
      final spans = buildNoteSpans(
        noteText: '**bold**',
        baseStyle: const TextStyle(),
        refColor: const Color(0xFF000000),
      );
      final text = spans
          .whereType<TextSpan>()
          .map((s) => s.text ?? '')
          .join();
      expect(text, 'bold');
      expect(
        spans.whereType<TextSpan>().any(
            (s) => s.text == 'bold' && s.style?.fontWeight == FontWeight.w700),
        isTrue,
        reason: 'the default render mode must actually apply bold',
      );
    });

    test('a reference inside emphasis keeps its own text', () {
      expect(
        _rendered('A **bold** claim about [John 3:16]',
            NoteMarkdownMode.render),
        'A bold claim about [John 3:16]',
      );
    });
  });
}
