import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Stray-ASCII / bracket-balance guard for 梁家鏗譯本 (biblexg-v2 / -tr).
///
/// Every other shipping edition has one of these: `kjv`/`nasb`/`leb`/
/// `cuvs-yhwh(-tr)` via `bible_version_integrity_test.dart`'s `forbidden`
/// map, `cuvs-yhwh(-tr)` again via `ascii_punctuation_test.dart` +
/// `stray_punctuation_test.dart` + `orphan_close_bracket_test.dart`, and
/// `csb` via `csb_asset_test.dart`'s markup + bracket-balance checks.
/// `biblexg-v2*` had none — `biblexg_verse_integrity_test.dart` checks
/// references, empties, swallowed verse numbers, chapter gaps, `<note:…>`
/// markup and script purity, but no character-class check at all.
///
/// A census of body text (with `<note:…>` spans stripped) found exactly
/// two stray-ASCII characters, both in the Simplified file. `git log -S`
/// traces both to the original import commit `f1f82de4` and never touched
/// since, which only rules out a LOCAL edit — it does not by itself say
/// whether the import was faithful. Checked directly against the
/// publisher's own `cn-act.json` / `cn-rev.json` (cached at
/// `~/.cache/yswords/ljk-source/`), both verses read character-for-
/// character identical to what we ship. **Both are the publisher's own
/// text, not an import artefact:**
///
///   使徒行传 7:32   opens the quotation with `‘` (U+2018) and closes it
///                  with ASCII `'` (U+0027), right before `<note:参出
///                  3.6。>` — and so does the publisher's own cn-act.json.
///   启示录 1:5      an ASCII `,` where the surrounding text is otherwise
///                  full-width `，` — and so does the publisher's own
///                  cn-rev.json.
///
/// This is a PIN, not a repair, and now there is nothing to repair: the
/// publisher's own file is the thing being pinned. See
/// docs/autonomous-queue.md (P0) for the filed item. If either offender
/// disappears, or a third one appears, this test must fail — it guards
/// both directions, not just a floor.
void main() {
  final pinnedBodyOffenders = <String, Map<String, String>>{
    'assets/biblexg-v2.json': {
      '使徒行传|7|32': "'", // closes a ‘…’ quotation with an ASCII apostrophe
      '启示录|1|5': ',', // ASCII comma amid otherwise full-width punctuation
    },
    'assets/biblexg-v2-tr.json': {},
  };

  const forbidden = r'()[]{}|^~*.,!;:"' "'";

  List<Map<String, dynamic>> load(String path) =>
      (json.decode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  /// Body offenders found in [verses], keyed the same way as
  /// [pinnedBodyOffenders] ('book|chapter|verse' -> the single stray
  /// character). A verse with more than one stray character records
  /// only the first — the pin below is a presence/absence check on
  /// references, not a per-character tally.
  Map<String, String> findBodyOffenders(List<Map<String, dynamic>> verses) {
    final found = <String, String>{};
    for (final v in verses) {
      final stripped =
          (v['text'] as String).replaceAll(RegExp(r'<note:.*?>'), '');
      for (final ch in stripped.split('')) {
        if (forbidden.contains(ch)) {
          found['${v['book']}|${v['chapter']}|${v['verse']}'] = ch;
          break;
        }
      }
    }
    return found;
  }

  for (final path in pinnedBodyOffenders.keys) {
    group('$path punctuation', () {
      late List<Map<String, dynamic>> verses;

      setUpAll(() => verses = load(path));

      test('stray ASCII punctuation in body text is pinned, not open-ended',
          () {
        expect(findBodyOffenders(verses), pinnedBodyOffenders[path]);
      });

      test('a repair of the pinned offender would be caught', () {
        // Prove the pin is two-directional by mutating an in-memory
        // copy: if the asset were fixed today, this check must start
        // failing rather than silently passing forever.
        final expected = pinnedBodyOffenders[path]!;
        if (expected.isEmpty) return;
        final repaired = verses.map((v) => Map<String, dynamic>.from(v))
            .toList();
        for (final v in repaired) {
          final key = '${v['book']}|${v['chapter']}|${v['verse']}';
          if (expected.containsKey(key)) {
            v['text'] = (v['text'] as String)
                .replaceAll(expected[key]!, '');
          }
        }
        expect(findBodyOffenders(repaired), isNot(expected));
      });

      test('a new stray character would be caught', () {
        final expected = pinnedBodyOffenders[path]!;
        final mutated = verses.map((v) => Map<String, dynamic>.from(v))
            .toList();
        mutated[0] = Map<String, dynamic>.from(mutated[0]);
        mutated[0]['text'] = '${mutated[0]['text']}~';
        expect(findBodyOffenders(mutated), isNot(expected));
      });

      test('<note:…> tags stay balanced per verse', () {
        final unbalanced = <String>[];
        for (final v in verses) {
          final text = v['text'] as String;
          if (text.count('<') != text.count('>')) {
            unbalanced.add('${v['book']} ${v['chapter']}:${v['verse']}');
          }
        }
        expect(unbalanced, isEmpty);
      });
    });
  }
}

extension on String {
  int count(String needle) => needle.allMatches(this).length;
}
