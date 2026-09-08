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
/// ## The third thaw, 2026-09-08 — catching up to the publisher
///
/// Same day, same person, and the largest of the three: **8,566 verses
/// brought up to the publisher's CURRENT text**, the same 8,566 in both
/// scripts.
///
/// This is the opposite of what the freeze stops. The freeze exists
/// because the publisher declined OUR corrections; this adopts THEIRS. We
/// were roughly one editorial generation behind — their edit log,
/// `bsapp_bible_cuvs_edits`, keeps a pre-edit `org_text` for all 31,102
/// verses, ours matched that pre-edit state in 23,400 and their current
/// text in 21,953, and they had edited 14,718 verses since. The sibling
/// app already carried the result in 30,834 of 31,102 (99.1%), which is
/// how the gap was found.
///
/// `tools/sync_cuv_yhwh_to_publisher.py` takes their words;
/// `tools/mirror_publisher_sync_to_tr.py` replays the same edits onto the
/// Traditional at the same character positions. Five restraints, each of
/// which cost something:
///
///   * **The three markers on 主 are ours and win.** Their database has
///     202 `主[雅伟]` / 120 `主*` / 18 `主#`; we ship 208 / 123 / 17,
///     because the `主*` set was restored from git history and 使徒行傳
///     9:29 is deliberately excluded. So the publisher's words are taken
///     and our markers re-applied by counting 主 left to right. **11
///     verses where the bare-主 count itself differs are skipped and
///     named** — that is not a mapping a script can make.
///   * **61 verses are skipped because the two scripts are not the same
///     length**, so the Traditional has no position to write into.
///   * **The mirror CONVERTS what it inserts.** The first attempt copied
///     the Simplified's new characters over verbatim — safe for the quote
///     pass, wrong here, because the publisher also changed words
///     (那→哪, 阿→啊, 它/她/他, 嗎→么, 擘→掰). That put 780 Simplified
///     characters into the Traditional file and dropped 說 from 9,539 to
///     9,529. Measured and reverted rather than shipped.
///   * **And that fix was itself half a fix.** The converting mirror kept
///     a `if not is_han(ch)` shortcut that appended punctuation verbatim,
///     on the reasoning that "a quotation mark is not a script". In this
///     edition it is one: the Simplified sets “ ” ‘ ’ where the
///     Traditional sets 「 」 『 』, one-to-one across 7,726 aligned
///     positions with not a single counter-example. The publisher's
///     current text roughly doubles the curly quotes, so mirroring them
///     verbatim put 3,155 `“`, 2,871 `”`, 574 `‘` and 570 `’` into a
///     Traditional file that had **zero of all four** — 3,905 verses left
///     opening 「 and closing ”, e.g. 創世記 30:6, 出埃及記 3:5.
///
///     Nothing caught it. The mirror's own leak check knew only about Han
///     pairs, so it listed those four at the top of "characters new to
///     the Traditional file" and then reported "a real leak: 0"; and
///     `ascii_punctuation_test` counts only the ASCII `"`, which this
///     does not touch. The fix is not a special case for quotes — the Han
///     test is gone and the derived correspondence decides, which is what
///     the rest of the script already did. Put the shortcut back and the
///     mirror now refuses to write, naming all 7,170.
///   * **3 more verses were reverted in BOTH scripts** rather than
///     converted: 以賽亞書 65:3, 使徒行傳 18:6 and 希伯來書 9:16 insert
///     坛, 干 and 须, each of which has more than one Traditional form in
///     this edition's own text. A script does not get to pick between
///     壇/罈, 乾/幹 or 須/鬚 — that is precisely the mistake the
///     Traditional edition is still recovering from.
///
/// The conversion table is not a general 简→繁 map. It is derived from
/// THIS EDITION'S own two scripts at aligned positions, so a character
/// with one Traditional form converts and a character with two is refused.
/// Across all 31,102 verse pairs the only NON-Han characters that ever
/// stand opposite something different are those four quotes — which is
/// what makes dropping the Han test safe rather than reckless. A comma, a
/// 。, an ASCII `"`, a digit and a Latin letter are unattested as
/// differences and still fall through untouched.
///
/// 7,384 characters were converted, 7,170 of them 引號; the guard that no
/// character with a known Traditional form entered the Traditional file
/// reports **0**. The two scripts now carry the same 6,569 / 5,970 /
/// 1,228 / 1,203 opening and closing quotes as each other, and the
/// Traditional carries no `“”‘’` at all.
///
/// That the freeze has now been lifted THREE times, every time by the
/// person who imposed it and every time toward the publisher rather
/// than away from them, is still not a precedent for lifting it for an
/// edit of OURS.
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
    // Re-pinned 2026-09-09 for the FOURTH thaw, which is the third one
    // finishing rather than a new one. The publisher sync of 2026-09-08
    // adopted their current text for 8,566 verses; this pin is that same
    // pass after the repair layer was re-run over the new base and after
    // the defects the repair layer's own tests then caught were fixed
    // against the official 和合本繁體 (git blob 7a2dc43, spot-checked at
    // bible.fhl.net). In order:
    //
    //   * the publisher's WORDS taken, our three 主 markers re-applied,
    //     and 創世記 18:19 / 出埃及記 24:1 / 歷代志下 29:6 kept with the
    //     name INLINE rather than behind a footnote — see
    //     tools/keep_our_divine_name_notation.py, which also restores
    //     以賽亞書 64:3 and 使徒行傳 25:18 to 意料, the owner's own edit
    //     (commit 81db105) that the sync had reverted.
    //   * the Traditional mirrored with CONVERSION, not copying: 7,170
    //     curly quotes and 780 Simplified characters would otherwise
    //     have leaked into it.
    //   * 90 enumeration commas the publisher's text deleted outright
    //     restored, and 90 more 、/， positions settled against the
    //     official edition — 出埃及記 39:24 reads 用藍色、紫色、朱紅色線
    //     again.
    //   * 16 character transpositions undone (詩篇 24:4 手潔心清,
    //     羅馬書 12:3 各人們, 列王紀上 14:5 告訴她 …), the sevenfold
    //     啟示錄 refrain given back its ！, two lost closing quotes
    //     restored at 撒母耳記上 16:11 and 列王紀下 10:13, 13 verses
    //     given back the comma that went with the reverent space, and a
    //     dozen single-verse repairs listed in
    //     tools/repair_by_official_cuv.py.
    //
    // The freeze still means what it says: it is here because the
    // PUBLISHER DECLINED OUR CORRECTIONS, and nothing above is one of
    // ours being re-imposed. Every change is either their own newer
    // text or the official 和合本 against a defect in it.
    //
    // Previous pins, so every thaw is auditable rather than merely
    // asserted:
    //   cuvs-yhwh.json     4c0f4aff45237fdac1ea0a847f35def60fdea04ba0bf9f…
    //   cuvs-yhwh-tr.json  479bbb250c550fac60b57781d72785bcc37a9c5854742d…
    //   cuvs-yhwh.json     5e18b8b18d502a8cbfa7bbbcbf79e58921f5a05be6e648…
    //   cuvs-yhwh.json     4735454344b86a11f30ae0f0c48aca46ac585032fb209f…
    //   cuvs-yhwh-tr.json  d28897b6643841067f1ef763a8cf5da3c135b03f6dff09…
    //   cuvs-yhwh-tr.json  2a15f69b35b11a117073df306217567df3682e4e3da667…
    //   cuvs-yhwh.json     6c0009bfc14a6a412a5eb1c4ebe94e5147448862761e5a…
    //   cuvs-yhwh-tr.json  a18a4ab71153ce52be43d85a19b60eb50190fb2322c4f7…
    //   cuvs-yhwh.json     30ba6271f44648d34c6b3ecfa8b68f5d72bcc6374ee1d1…
    //   cuvs-yhwh-tr.json  8e4e85e0d31858484f18d8f345de30055b9ae0114ff0e6…
    'assets/cuvs-yhwh.json':
        'a02acd5c4c04d025c5499308ee6c54b4796337c39926959a7c67a67f31259735',
    'assets/cuvs-yhwh-tr.json':
        'ea33d4a9333adb5273255b38151c8a7ea015a21bcf22cb3608c2262e2341d735',
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
