import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fifty verses of both reading editions carried half-width ASCII punctuation
/// in their **running text** — 創世紀 6:11 「滿了強暴.。」 with both a period
/// and a 句號, 民數記 24:17 「毀壞擾亂.之子」 mid-phrase, 撒迦利亞書 14:1
/// opening with 「, 雅偉的日子」, 路加福音 18:37 「他們告訴他:「」.
///
/// It is import residue, not a punctuation choice: the corpus sets full-width
/// marks over 108,000 times, and 55 slots disagreed with all of them.
///
/// Four witnesses decided each position — the plain 和合本 Traditional (git
/// blob `7a2dc43`), the Simplified twin, SeekSparks' independent import, and
/// the Wikisource transcription of the printed 1919. Marks whose identity the
/// witnesses confirm were widened (`!`→！ `:`→： `;`→； `,`→， `()`→（）);
/// marks no witness has, in slots no Chinese punctuation can occupy — a comma
/// straight after 「 or ：, a `)` inside 「我為)我的名」 — were deleted.
///
/// **The ASCII double quote is deliberately left alone**, and the last test
/// here is what stops a future sweep from "finishing the job" — one already
/// tried. `"` is this corpus's 原文 apparatus quote: across the 543 notes that
/// cite 原文 it now stands **1,468 to 16** against 「」/“”. Widening them would
/// leave them disagreeing with 1,468 of their own kind. The tempting
/// counter-population — running-text parentheticals, which read 6/6 「」 — is
/// quoted speech and translation glosses, not 原文 notes.
///
/// The publisher has since settled the one case this docstring used to argue
/// about. It read: "the eight in running text sit in the same apparatus, the
/// inline （原文有 "…"）parentheticals of 撒迦利亞書". In the 2026-09-08 sync
/// they moved 撒迦利亞書 1:3, 8:14 and 10:1 out of inline parentheses into
/// 〔…〕 — that is, into notes, which is what this file already said they were
/// in substance. 10:12 is the one they left inline; that inconsistency is
/// theirs and stays.
///
/// The assertions are absolutes rather than counts. Half-width punctuation has
/// no place in Chinese running scripture, so any future import that
/// reintroduces one fails here and gets read against a witness rather than
/// swept. Repair: `tools/repair_ascii_punctuation.py`.
void main() {
  const editions = {
    'Simplified': 'assets/cuvs-yhwh.json',
    'Traditional': 'assets/cuvs-yhwh-tr.json',
  };

  // [雅偉] / [基督] mark where the divine name was restored; `<note: …>` is the
  // translators' apparatus. Neither is running scripture.
  final note = RegExp(r'<note:.*?>');
  final bracket = RegExp(r'\[[^\]]{1,6}\]');
  String running(String text) =>
      text.replaceAll(note, '').replaceAll(bracket, '');

  final loaded = <String, List<Map<String, dynamic>>>{};

  setUpAll(() {
    for (final entry in editions.entries) {
      loaded[entry.key] =
          (json.decode(File(entry.value).readAsStringSync()) as List)
              .cast<Map<String, dynamic>>();
    }
  });

  String textOf(String edition, String id) =>
      loaded[edition]!.firstWhere((v) => v['id'] == id)['text'] as String;

  // Traditional / Simplified readings of the same repaired position.
  const repaired = <String, List<String>>{
    // id            Traditional          Simplified
    '001006011': ['地上滿了強暴。', '地上满了强暴。'],
    '004024017': ['毀壞擾亂之子。', '毁坏扰乱之子。'],
    '029001015': ['哀哉！雅偉的日子', '哀哉！雅伟的日子'],
    '052002013': ['就領受了；不以為', '就领受了；不以为'],
    '042018037': ['他們告訴他：', '他们告诉他：'],
    // 2026-09-08: the publisher re-punctuated this one, 我為我的名暫且忍怒 →
    // 我為我的名，暫且忍怒. What the entry protects is unchanged and is why it
    // is still here: the stray `)` of 「我為)我的名」 is gone, and it was
    // DELETED rather than "improved" into a character. A 、 or a 。 here would
    // still fail. The ideograph count is pinned below as well, so a future
    // substitution cannot hide behind another re-punctuation.
    '023048009': ['我為我的名，暫且忍怒', '我为我的名，暂且忍怒'],
    '038014001': ['雅偉的日子臨近，', '雅伟的日子临近，'],
    '001048007': ['路上（以法他就是伯利恆）', '路上（以法他就是伯利恒）'],
    '038005003': ['凡偷竊的，必按', '凡偷窃的，必按'],
    // 2026-09-08: 「拉比！」 → 「拉比，」. Ours came from widening an ASCII
    // `!` here, and the publisher's current text sets a comma instead —
    // corroborated by SeekSparks, which carries their current text, and by
    // `cuvs-plus.json`, a different 和合本 import altogether, which reads
    // 說：拉比，便與他親嘴。 with no quotes at all. The Eagle's View tagged
    // import still has ！, so the witnesses are split and the publisher is
    // not outvoted. No word moved; the entry keeps proving what it was
    // written to prove, that the half-width `!` is gone — and the first
    // test in this file asserts that absolutely for the whole corpus anyway.
    '041014045': ['「拉比，」', '“拉比，”'],
    // 路 8:12's period stood where the witnesses set 。— widened, not deleted.
    '042008012': ['信了得救。', '信了得救。'],
  };

  for (final edition in editions.keys) {
    group(edition, () {
      test('running scripture holds no half-width punctuation', () {
        final offenders = <String>[];
        for (final v in loaded[edition]!) {
          final text = running(v['text'] as String);
          for (final mark in const ['.', ',', '!', ';', ':', '(', ')']) {
            if (text.contains(mark)) {
              offenders.add(
                  '${v['book']} ${v['chapter']}:${v['verse']} holds $mark');
              break;
            }
          }
        }
        expect(offenders, isEmpty,
            reason: 'Chinese scripture sets 。，！；：（）, never their ASCII '
                'forms. Re-run tools/repair_ascii_punctuation.py — and read '
                'each position against a witness first, because a stray mark '
                'and a degraded one need opposite treatment.');
      });

      test('the repaired positions read as the witnesses do', () {
        final column = edition == 'Traditional' ? 0 : 1;
        repaired.forEach((id, readings) {
          expect(textOf(edition, id), contains(readings[column]), reason: id);
        });
        // 路 8:45 opens 〔有古卷在此有：…〕 and used to close it with `)`.
        expect(textOf(edition, '042008045'), endsWith('〕'));
      });

      test('no ideograph moved in the three positions that tempted otherwise',
          () {
        // A punctuation repair must never touch the text. 路 8:12's period sat
        // where a 句號 would go and 番 1:1's stray `)` sat where the witness
        // sets a comma, so both were the ones most likely to be "improved"
        // into a substitution. Pinned as text, not as punctuation.
        final cjk = RegExp(r'[一-鿿]');
        expect(cjk.allMatches(running(textOf(edition, '042008012'))).length, 34);
        expect(cjk.allMatches(running(textOf(edition, '036001001'))).length, 50);
        // 賽 48:9 joined them on 2026-09-08, when the publisher put a comma
        // into 我為我的名暫且忍怒. A re-punctuation is theirs to make; a
        // character moving under cover of one is not, so the count is pinned.
        expect(cjk.allMatches(running(textOf(edition, '023048009'))).length, 23);
      });
    });
  }

  test('the apparatus keeps its ASCII double quote — do not sweep it', () {
    // Inside <note: …>, plus the one inline （原文是"…"）parenthetical the
    // publisher still has in running text, 撒迦利亞書 10:12. One convention,
    // two placements.
    // Converting the running-text ones to 「」 sets them against the ASCII
    // 原文 notes, which is why a first pass that did exactly that was
    // reverted. Whether the whole convention should be full-width is the
    // user's call, not a sweep's; until then this test fails the sweep.
    //
    // 2026-09-08: this was 336 in notes and 8 in running text for both
    // editions, until the quotes our importer had DROPPED were put back
    // — 1,144 in the Simplified, 1,140 mirrored into the Traditional,
    // every one taken from the publisher's own current text. That is the
    // same direction this test defends: the ASCII quote is the right
    // mark here, and for years most of the convention was simply
    // missing rather than full-width.
    //
    // The number is the same for both editions on purpose: 士師記 1:16
    // and 4:11 could have taken the repair in the Simplified but are not
    // character-aligned between the scripts, so the mirror could not
    // place a mark in their Traditional twins — and they were therefore
    // skipped in BOTH rather than left one script ahead of the other.
    //
    // 2026-09-08, later the same day: 1,474/10 → 2,896/21, from the sync
    // that brought 8,566 verses up to the publisher's current text. Both
    // moves are AWAY from 「」, which is the direction this test defends, so
    // the tripwire is re-pinned rather than loosened. What moved:
    //
    //   * notes 1,474 → 2,896. The publisher quotes far more inside their
    //     own apparatus than our copy did, and three 撒迦利亞書 verses
    //     (1:3, 8:14, 10:1) moved from an inline parenthetical INTO a
    //     note, taking six marks across the bucket line with them.
    //   * running 10 → 21. Not new running-text quotes: nine verses whose
    //     whole body is 〔有古卷在此有："…"〕 — 太 18:11, 太 23:14, 可 7:16,
    //     可 15:28, 路 17:36, 路 23:17, 約 5:4, 徒 8:37, 徒 24:7 — gained the
    //     publisher's quotes, and `unfold()` deliberately leaves an
    //     all-note verse's 〔…〕 raw rather than hiding the entire verse
    //     behind a footnote icon. Raw 〔…〕 is not `<note: …>`, so
    //     `running()` counts it. A classification artifact of that
    //     decision, not scripture that gained a half-width mark.
    //
    // 徒 8:37 is the odd one: it opens “ and closes " inside a single
    // apparatus note, so its count is 1 rather than 2. That asymmetry is
    // the publisher's and is left alone.
    //
    // 2026-09-09: notes 2,896 → 2,880. Sixteen marks left the note
    // bucket, and none of them left the corpus. 馬太福音 17:21 was being
    // half-converted — its outer 〔有古卷在此有21節：…〕 contains a nested
    // 〔或作：…〕, the note regex closed on the inner bracket, and the
    // remainder stood outside as scripture. It is now raw 〔…〕 like its
    // thirteen wholly-editorial siblings, which moves its marks out of
    // `note.allMatches` for exactly the reason the nine verses above
    // moved INTO `running()`. The rest are the note-body rewrites that
    // came with repairing 詩篇 57:8, 馬太福音 25:13 and 希伯來書 8:2.
    // running 21 → 23, and by the same mechanism in the other
    // direction: 馬太福音 17:21's two marks are now inside a raw 〔…〕,
    // which `running()` counts. The verse is unchanged in what it says.
    //
    // Still the direction this test defends: no 「」 turned into a
    // half-width mark anywhere.
    for (final edition in editions.keys) {
      var inNotes = 0;
      var inRunning = 0;
      for (final v in loaded[edition]!) {
        final text = v['text'] as String;
        for (final m in note.allMatches(text)) {
          inNotes += '"'.allMatches(m.group(0)!).length;
        }
        inRunning += '"'.allMatches(running(text)).length;
      }
      expect(inNotes, 2880, reason: edition);
      expect(inRunning, 23, reason: edition);
    }
  });

  test('each script keeps its OWN quotation marks', () {
    // The ASCII `"` above is shared by both scripts. The curly quotes are
    // not: this edition sets “ ” ‘ ’ in the Simplified and 「 」 『 』 in
    // the Traditional, one-to-one, with no counter-example in 31,102
    // verses — 3,410 / 3,087 / 630 / 599 aligned positions before the
    // 2026-09-08 publisher sync, and nothing else opposite any of them.
    //
    // This test exists because that fact was not written down anywhere and
    // `tools/mirror_publisher_sync_to_tr.py` assumed the opposite. It
    // carried a `if not is_han(ch)` shortcut — "punctuation is
    // script-neutral" — inherited from the inner-quote mirror, where it
    // was true because that pass only inserted an ASCII `"`. The publisher
    // roughly doubled the curly quotes, so the shortcut copied 3,155 `“`,
    // 2,871 `”`, 574 `‘` and 570 `’` into a Traditional file that had ZERO
    // of all four, leaving 3,905 verses that open 「 and close ”.
    //
    // Nothing in this suite noticed: the count above tracks the ASCII `"`,
    // which was untouched, and the mirror's own leak check compared
    // against a table that had been filtered to Han pairs, so it printed
    // those four at the top of its "new to the Traditional file" list and
    // then reported "a real leak: 0". A guard derived from the same
    // premise as the code it guards is not a second opinion. This one is
    // derived from the shipped text instead.
    //
    // Absolutes, not counts, so a new import fails here rather than
    // silently re-pinning: see `docs/cuv-yhwh-publisher-notes.md`.
    const simplifiedOnly = ['“', '”', '‘', '’'];
    const traditionalOnly = ['「', '」', '『', '』'];

    int total(String edition, String mark) => loaded[edition]!.fold(
        0, (n, v) => n + mark.allMatches(v['text'] as String).length);

    for (final mark in traditionalOnly) {
      expect(total('Simplified', mark), 0,
          reason: '$mark is the Traditional edition\'s mark');
    }
    for (final mark in simplifiedOnly) {
      expect(total('Traditional', mark), 0,
          reason: '$mark is the Simplified edition\'s mark — a mirror that '
              'copied it across instead of converting it is the known way '
              'this breaks');
    }
    // And the same quotation, so neither script is a mark ahead.
    for (var i = 0; i < simplifiedOnly.length; i++) {
      expect(total('Traditional', traditionalOnly[i]),
          total('Simplified', simplifiedOnly[i]),
          reason: '${simplifiedOnly[i]} / ${traditionalOnly[i]} disagree');
    }
  });
}
