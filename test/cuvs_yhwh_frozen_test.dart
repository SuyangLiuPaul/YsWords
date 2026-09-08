import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// 和合本雅偉版 is frozen. The publisher declined our corrections
/// (user, 2026-09-02: 「cuvs yhwh这个不用管 因为出版方说这个不要」), so the
/// two assets are read-only from here on.
///
/// This test exists because the queue had **25 open items proposing edits to
/// these files**, several of them with a ready-to-run repair script sitting
/// beside them in `tools/`. Deleting the items removes the instruction; it
/// does not remove the scripts, and it does not stop an audit from finding
/// 0 蹟 / 103 跡 all over again next month and "fixing" it. A hash is the
/// only guard that survives a rediscovery.
///
/// **If this test fails, the answer is almost never to update the hash.**
/// It means something edited a text we do not own. Revert the asset. The
/// hash changes only when the publisher ships us a new module — and then
/// the commit that updates it should say so and nothing else.
///
/// **Before touching this edition at all, read
/// `docs/cuv-yhwh-publisher-notes.md`.** It holds what the publisher has
/// said about their own notation, verbatim. It exists because its absence
/// cost three deletions of correct data: the answer was in the user's
/// inbox and nowhere in the repo, so audits reasoning from the assets
/// alone got it wrong twice, with measurements, confidently.
///
/// ## The one deliberate thaw, 2026-09-02
///
/// The user lifted the freeze for a single change, and it is the exact
/// opposite of the edits this file was written to stop: it RESTORES the
/// publisher's own notation rather than imposing ours.
///
/// This edition marks the referent of 主 three ways — `主[雅偉]` Yahweh,
/// `主#` 基督, `主*` 耶穌. Only two ever reached a reader. The asterisk was
/// deleted from both reading assets on 2025-05-17 (b1dbb96a, "remove
/// 主*", 121 occurrences at once) and the last two on 2026-08-10, both
/// times read as importer noise. It is not noise; it is the third
/// marker, and the user reported its absence at 約翰福音 4:1, which read
/// a bare 主 where the publisher printed `主*`.
///
/// 123 occurrences in 114 verses are back, written as `主[耶穌]` /
/// `主[耶稣]` on the user's call, matching the precedent that already
/// turned `主#` into `主[基督]`. Positions came from git, not from
/// judgement: `tools/restore_cuv_jesus_marker.py` reads them out of the
/// pre-deletion assets and edits today's text in place, so the nineteen
/// months of repair since 2025 survive.
///
/// ## The second thaw, 2026-09-08 — the quotation marks we dropped
///
/// Same shape as the first, and lifted the same way: by the person who
/// imposed the freeze, for characters the publisher wrote and our
/// importer lost, not for a correction of ours.
///
/// The publisher puts quotes inside their own notes and inside quoted
/// speech — 〔就是"得"的意思〕, 〔"我"原文是"雅偉"〕. Our import dropped
/// them, so the app rendered `<note: 就是得的意思>`: a different
/// sentence, not a lighter one. SeekSparks imported the same edition
/// and kept them, which is the first sign the loss was ours.
///
/// 1,140 marks across 495 verses, restored by
/// `tools/restore_cuv_yhwh_inner_quotes.py`. Like the 主* pass, the
/// positions come from a source rather than from judgement — here the
/// publisher's own current text in Yahwehdehua's `app/build/bible.db`,
/// built from `bsapp_bible_cuvs` — and the script only touches a verse
/// where that text is identical to ours apart from the quotes.
///
/// That gate is doing real work, because **our copy is roughly one
/// editorial generation behind the publisher's**. Their edit log,
/// `bsapp_bible_cuvs_edits`, holds a pre-edit `org_text` for all 31,102
/// verses; ours matches that pre-edit state in 23,400 and the current
/// text in 21,953, and they have edited 14,718 verses since. Those
/// edits are theirs — 哪/那, 啊/阿, 掰/擘, 吗/么, 他/她/它 — and none
/// of them may ride in on a punctuation repair. 8,652 verses were
/// skipped for exactly that reason.
///
/// The Traditional edition moves with it: the same 1,140 marks in the
/// same 495 verses, replayed at the same character positions by
/// `tools/mirror_inner_quotes_to_tr.py`. Both files lost these to the
/// same importer, and repairing one alone would lose the quotes again
/// for any reader who switches script.
///
/// Two verses, 士師記 1:16 and 4:11, are skipped in BOTH. They qualify
/// in the Simplified, but the two scripts are not character-aligned
/// there, so the mirror cannot place a mark in the Traditional twin —
/// and `search_synonyms_test` requires the pair to stay the same
/// length. One script ahead of the other is worse than both behind, so
/// the Simplified script refuses them too rather than take the easy
/// 1,144.
///
/// 路加福音 8:45 is the one verse where the quotes went in but the
/// 〔…〕 stayed raw instead of becoming `<note: >`. That is deliberate:
/// `test/ascii_punctuation_test.dart` pins `endsWith('〕')` there, from
/// the 2026-08-23 pass that repaired a stray `)` into 〕. Converting it
/// would be a second, unrelated change riding along on a punctuation
/// repair.
///
/// That the freeze has now been lifted TWICE, both times by the person
/// who imposed it and both times to put back something the publisher
/// wrote, is still not a precedent for lifting it for an edit of OURS.
/// The rule above stands, and the 哪/那 above is the concrete example:
/// it looks exactly like a defect and it is not ours to touch.
///
/// Scope, so nobody over-reads the freeze: the *reading assets* are frozen.
/// The word-tap corpus, the Strong's tagging, the lexicon and every line of
/// rendering code are ours and stay open — including the editorial brackets
/// this app renders around `[雅偉]`, which are a rendering decision about
/// the publisher's own notation, not an edit to it.
void main() {
  const frozen = <String, String>{
    // Re-pinned 2026-09-08 for the second thaw described above. Previous
    // pins, so both thaws are auditable rather than merely asserted:
    //   cuvs-yhwh.json     5e18b8b18d502a8cbfa7bbbcbf79e58921f5a05be6e648…
    //   cuvs-yhwh.json     4735454344b86a11f30ae0f0c48aca46ac585032fb209f…
    //   cuvs-yhwh-tr.json  d28897b6643841067f1ef763a8cf5da3c135b03f6dff09…
    //   cuvs-yhwh-tr.json  2a15f69b35b11a117073df306217567df3682e4e3da667…
    'assets/cuvs-yhwh.json':
        '6c0009bfc14a6a412a5eb1c4ebe94e5147448862761e5aa8f3a96417c5959b45',
    'assets/cuvs-yhwh-tr.json':
        'a18a4ab71153ce52be43d85a19b60eb50190fb2322c4f7a0da264cb282cfd022',
  };

  frozen.forEach((path, expected) {
    test('$path is unchanged since the publisher declined our corrections',
        () {
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: '$path is a shipped reading asset; it should not vanish');
      final actual = sha256.convert(file.readAsBytesSync()).toString();
      expect(actual, expected,
          reason: 'CHANGED. 和合本雅偉版 is not ours to edit — see the '
              'FROZEN block at the top of docs/autonomous-queue.md. '
              'Revert the asset rather than updating this hash, unless '
              'the publisher has sent a new module.');
    });
  });

  test('the frozen assets still parse and still hold 31,102 verses', () {
    // A hash catches an edit; it does not catch a file that was replaced
    // wholesale by something else and then had its hash "fixed". This is
    // the cheap second opinion.
    for (final path in frozen.keys) {
      final verses = json.decode(File(path).readAsStringSync()) as List;
      expect(verses, hasLength(31102), reason: '$path lost or gained verses');
    }
  });
}
