#!/usr/bin/env python3
"""Restore 崙 in the Traditional data, where the converter wrote 侖.

Sixteenth instalment of the same defect, and the first one to reach a NAME.
`assets/cuvs-yhwh-tr.json` is a script conversion of the Simplified edition and
the converter that produced it had holes: it never once wrote 隻, 淨, 牆, 餘,
髮, 穀, 乾, 恆, 卜, 凌, 症, 癒 … or 崙. So the Traditional Bible misspells
**希伯崙 — Hebron — in 69 verses**, and fifteen more names with it. The full
enumeration, by longest match so no name is counted inside another:

    希伯崙 69   希斯崙 17   伯和崙 15   以弗崙 13   沙崙 9   亞雅崙 9
    伸崙 7      耶書崙 4    米崙 2      米磯崙 2    拉沙崙 1
    西斐崙 1    基撒崙 1    施基崙 1    哈崙 1      何崙 1   希崙 1
    義伯崙 1                                            —— 155 in all

  (拉沙崙, 書 12:18, is listed separately because 沙崙 is a substring of it; a
  naive count of 沙崙 returns 10 and double-counts that verse. 義伯崙, 書 19:28,
  is easy to miss and is the reason this list is derived by tokenising the 155
  positions rather than by summing a hand-written list of names.)

Every one of the 155 is a proper name.

WHY THIS ONE MATTERS MORE THAN THE FIFTEEN BEFORE IT
  The earlier instalments fixed common nouns — a船只 that should be 船隻, a
  痊愈 that should be 痊癒. A reader who saw those knew what the word meant.
  This one prints the wrong NAME for Abraham's burial place and David's first
  capital, on a screen people quote from. The app was already contradicting
  itself out loud: `assets/section_titles.json` heads 撒母耳記下 2 with
  「大衛在希伯崙作猶大王」 and the verse underneath it read 希伯侖.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Before this repair ours held 155 侖 and ZERO 崙 across 31,102 verses; the
  witness holds 155 崙 and ZERO 侖. A file that never once wrote 崙 in 31,102
  verses did not choose against it.

  That argument had to be made carefully, because `docs/autonomous-queue.md`
  had already cautioned — correctly, on the evidence available then — that
  「侖/崙, 瑪/馬, 毗/毘 are transliteration conventions this edition is entitled
  to」, i.e. a witness difference here need not be a defect. 瑪利亞/馬利亞 IS a
  real editorial variant: published editions differ, and each is consistent
  with itself. This is not that, and the converter leaves a fingerprint that
  says so:

      $ echo 希伯仑 亚雅仑 耶书仑 希斯仑 沙仑 加仑 昆仑 | opencc -c s2t
        希伯侖 亞雅侖 耶書侖 希斯崙 沙崙 加侖 崑崙

  Simplified merges 侖 and 崙 onto 仑, and opencc's default single-character
  mapping for 仑 is 侖. Its phrase table happens to know 希斯崙 and 沙崙 and
  does not know 希伯崙, so it writes two names right and three wrong IN THE
  SAME SENTENCE. `assets/strongs/hebrew.json` reproduced that split exactly —
  希斯崙 ×35 and 沙崙 correct, 希伯侖 ×63 wrong. No editor produces that. A
  phrase-table converter produces precisely that, every time.

  The verse asset shows the same hand with no phrase table at all: 155 侖,
  0 崙 — the default mapping applied uniformly. Meanwhile five Traditional
  assets in this repo that were NOT machine-converted write 崙 and no name-侖.
  The disagreement is between our converted files and our authored files, which
  is a defect, not a convention.

WHY THE CLASS MOVES WHOLE — CHECKED, NOT ASSUMED
  侖 is a live Traditional character: 加侖 is a gallon and 崑崙 is a mountain
  range, and a blind sweep of a corpus containing either would corrupt it. This
  corpus contains neither, and every one of the 155 is a proper name that the
  witness spells with 崙. The script refuses if a gallon ever appears, if the
  witness ever holds a 侖, or if any verse's 侖 count stops matching the
  witness's 崙 count — which it does today on all 31,102 verses, with no
  witness verse carrying 崙 missing from ours, so an offsetting pair cannot
  hide. Afterwards the ordered sequence must match the witness verse for verse.

WHAT THE WITNESS IS, AND WHY COUNTS ALONE WOULD NOT HAVE BEEN ENOUGH
  The witness is a SEPARATE EDITION, not a copy of ours: it punctuates names
  with interpuncts, sets 裡 where we set 裏, spells out （原文是他） where we
  carry `<note:>` markup, and holds 31,103 verses to our 31,102. 65 of the 137
  verses that carry the glyph differ textually somewhere. So "agrees character
  for character" would be an over-claim, and — more to the point — matching
  COUNTS per verse cannot exclude an offsetting error: a verse holding two
  names could have them transposed and still count two.

  So the script also runs a positional identity check. For every 侖 in ours and
  every 崙 in the witness, in order, it compares the three characters to the
  left after stripping interpuncts and `<note: …>` markup. All 155 agree today,
  which is what actually establishes that our 侖 and its 崙 are the same name in
  the same place rather than two sequences that happen to be the same length.

INDEPENDENT CORROBORATION
  * A published 新標點和合本 Traditional (ebible `cmn-cu89t`) reads 158 崙 and
    ZERO 侖 — 希伯崙 ×69, exactly our count. The gap of 3 was read and is an
    edition difference, not a defect: 和合本 itself spells the name 希斯倫 at
    創 46:12 and 民 26:21 (×2) and 亞雅倫 at 士 1:35, where 新標點 normalises
    to 崙, and conversely 新標點 sets 希斯倫 at 出 6:14 where 和合本 has 崙.
    Ours and the witness carry 倫 at exactly the same five places, so the base
    text's own inconsistency is preserved and is NOT touched here.
  * FOUR separately produced Traditional assets in this repo write 崙 and no
    name-侖 at all: `section_titles.json` (希伯崙 ×3, 沙崙), `maps_index.json`
    (希伯崙), `family_tree.json` (希斯崙, 伸崙) and `songs.json` (沙崙).
    梁家鏗's independent Traditional NT `biblexg-v2-tr.json` is deliberately
    NOT counted among them, though an earlier draft did: it writes 崙 three
    times (希斯崙 ×2, 沙崙) but also one 希斯侖, at 路 3:33 in the genealogy.
    It is a witness against itself, so it corroborates only weakly — and since
    it is a shipped, user-selectable version, that one 侖 is still on screen
    today. His text, his call, queued rather than swept, exactly as the 愈/癒
    instalment decided about his 治愈.
  * The defective lexicon corroborates itself: opencc's phrase table happened
    to know 希斯崙 (×35) and 沙崙, so those two names are already right in
    `assets/strongs/hebrew.json` while 希伯崙 is not. Same file, same
    convention, one converter that only knew half the names.

THE LEXICON IS A SPLIT, NOT A PARTITION, AND IS FIXED POSITION BY POSITION
  `assets/strongs/hebrew.json` holds 90 侖 and 35 崙; `greek.json` holds 6 侖,
  and all six are 加侖 — a gallon, where 侖 is CORRECT. So the lexicon cannot
  be swept. Only the seven readings below are substituted, each one a name our
  own Traditional Bible and the witness both spell with 崙.

  One reading is deliberately left as 侖: 加侖 (hebrew ×2, greek ×6) — a
  gallon, where 侖 is correct.

  西伯侖 (×3 — H5555 twice, H6814 once) IS repaired, and the reasoning took two
  wrong turns before it settled. Both are recorded because the second would
  have generalised into later instalments.

  The first pass left it alone as "not a 和合本 name, nothing to confirm it
  against". Wrong: it is Hebron under a 西/希 typo. H6814 (Zoan) reads
  「在西伯侖之後7年建立」; 民數記 13:22 in our own Bible reads 「希伯崙城被建造
  比埃及的鎖安城早七年」 — the same fact in the same words.

  The second pass then argued "whichever name is meant, the last character is
  崙 and never 侖". ALSO WRONG, and more dangerous, because it was stated as a
  rule. 希伯倫 — the Kohathite clan, the Hebronites — is spelt with 倫 twelve
  times in our own Bible (出 6:18, 民 3:19, 3:27, 26:58, 代上 6:2, 6:18, 23:12,
  23:19, 24:23, 26:23, 26:30, 26:31), and this very lexicon carries one of
  them: H2811 (Hashabiah) reads 「可能就是西伯倫族的哈沙比雅 (#代上 26:30|)」 —
  the same 西/希 typo, spelt 倫. So 西伯? had a live third reading and the
  disjunction was never closed. (The ratio quoted alongside it, 「希伯 63
  against 西伯 3」, was miscounted too: it is 希伯 105 against 西伯 4.)

  What settles it is the Simplified twin — the witness this file carries inside
  itself. Simplified distinguishes 仑 from 伦 perfectly well, and all three of
  these read 西伯仑, not the 西伯伦 the clan would have required. So 崙 is right
  at these three positions for a reason that does not depend on identifying the
  name at all: the source says 仑, and 仑 here is 崙.

  The 西/希 typo itself is NOT touched. It lives in the Simplified
  `glossZh`/`defZh` too, so correcting it is an editorial change to the source
  rather than a conversion repair. Queued, with H2811 noted alongside.

SCOPE — AND ONE NAME-侖 KNOWINGLY LEFT ON SCREEN
  梁家鏗's `biblexg-v2-tr.json` has one 希斯侖 (路 3:33, the genealogy) against
  its own two 希斯崙 and one 沙崙. That is his translation's internal
  inconsistency, not ours to normalise — the same call the 愈/癒 instalment made
  about his 治愈. It is queued, not swept. Note honestly that this version IS
  shipped and user-selectable (`pubspec.yaml`, `lib/constants/bible_versions.dart`),
  so it is not true that the app now shows no name-侖 anywhere; it is true of
  every asset that is ours to edit.

Dry-run by default; --apply writes. Re-running after --apply is safe.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TR = ROOT / "assets/cuvs-yhwh-tr.json"
LEX = ROOT / "assets/strongs/hebrew.json"
WITNESS_BLOB = "7a2dc43"

TRAD = "崙"
SOURCE = "侖"

# Readings in which 侖 is CORRECT Traditional. If any appears in the verse asset
# the class no longer moves whole and this script is the wrong tool. Each is
# checked in BOTH spellings: after --apply the corpus holds 崙, so testing only
# the 侖 form would make this guard vacuous on every re-run — a corrupted 加崙
# would then pass silently. (Found by the refuter, 2026-08-18.)
CORRECT_READINGS = ("加侖", "崑侖", "侖敦", "美學侖")

# The lexicon is a split. Only these readings move, and only by this much.
LEX_NAMES = (
    ("希伯侖", 63),   # Hebron
    ("伯和侖", 6),    # Beth-horon
    ("伸侖", 7),      # Shimron
    ("米侖", 5),      # Merom / Meronothite
    ("何侖", 2),      # Holon
    ("以弗侖", 1),    # Ephron
    ("亞雅侖", 1),    # Aijalon
    ("西伯侖", 3),    # Hebron under a 西/希 typo — see the docstring
)
# What must survive untouched in the lexicon, and how many.
LEX_KEEP = (("加侖", 2),)

# The witness is a different edition. Three ways it differs are normalised away
# before the positional check, so that an editorial difference is not read as a
# different name: it words the translator's notes in （）where we mark them
# <note:>, it punctuates compound names with an interpunct, and it prints the
# Tetragrammaton 耶和華 where this edition prints 雅偉. Anything else that
# differs SHOULD make the check fail — that is the point of the check.
NOTE_SPANS = (re.compile(r"<note:[^>]*>"), re.compile(r"（[^）]*）"))
HAN = re.compile(r"[一-鿿]")
DIVINE_NAME = ("耶和華", "雅偉")
CONTEXT = 3


def name_contexts(text: str) -> list[str]:
    """The CONTEXT Han characters to the left of each ridge glyph, in order.

    Both forms are folded together so the check still holds once applied. A
    note span is dropped only when it carries no ridge glyph itself — 創 23:19
    「（幔利就是希伯崙）」 and 民 13:22 are notes that CONTAIN the name, and
    deleting those would hide the very positions this is checking.
    """
    t = text.replace(*DIVINE_NAME)
    for pattern in NOTE_SPANS:
        t = pattern.sub(lambda m: "" if TRAD not in m.group() and
                        SOURCE not in m.group() else m.group(), t)
    t = "".join(HAN.findall(t)).replace(SOURCE, TRAD)
    return [t[max(0, i - CONTEXT):i] for i, ch in enumerate(t) if ch == TRAD]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--report", default="")
    args = ap.parse_args()

    verses = json.loads(TR.read_text(encoding="utf-8"))
    witness = {
        v["id"]: v["text"]
        for v in json.loads(subprocess.run(
            ["git", "cat-file", "-p", WITNESS_BLOB], cwd=ROOT,
            capture_output=True, text=True, check=True).stdout)
    }

    before = "".join(v["text"] for v in verses)
    expected = sum(t.count(TRAD) for t in witness.values())

    witness_all = "".join(witness.values())
    if witness_all.count(SOURCE) != 0:
        print(f"  ✗ the witness holds {witness_all.count(SOURCE)} {SOURCE} — "
              f"this is a split, not a partition — refusing")
        return 1

    for reading in CORRECT_READINGS:
        for spelling in (reading, reading.replace(SOURCE, TRAD)):
            if spelling in before:
                print(f"  ✗ the corpus contains {spelling} — {reading} is a "
                      f"reading where {SOURCE} is correct, so the class does "
                      f"not move whole — refusing")
                return 1

    ids = {v["id"] for v in verses}
    for vid, text in witness.items():
        if (SOURCE in text or TRAD in text) and vid not in ids:
            print(f"  ✗ witness verse {vid} carries the glyph and is missing "
                  f"from ours — refusing")
            return 1

    # Counts alone cannot exclude a transposition. Confirm that our 侖 and the
    # witness's 崙 stand after the same characters, name for name.
    for v in verses:
        wit = witness.get(v["id"])
        if wit is None or (SOURCE not in v["text"] and TRAD not in v["text"]):
            continue
        ours, theirs = name_contexts(v["text"]), name_contexts(wit)
        if ours != theirs:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the name "
                  f"before the glyph disagrees with the witness: {ours} vs "
                  f"{theirs} — refusing")
            return 1

    report: list[str] = []
    changed = 0
    for v in verses:
        text = v["text"]
        if SOURCE not in text and TRAD not in text:
            continue
        wit = witness.get(v["id"])
        if wit is None:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — no witness "
                  f"verse to confirm against — refusing")
            return 1
        if text.count(SOURCE) + text.count(TRAD) != wit.count(TRAD):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — ours holds "
                  f"{text.count(SOURCE)} {SOURCE} + {text.count(TRAD)} {TRAD}, "
                  f"witness {wit.count(TRAD)} {TRAD} — refusing")
            return 1
        for i, ch in enumerate(text):
            if ch != SOURCE:
                continue
            changed += 1
            report.append(f"{v['book']} {v['chapter']}:{v['verse']}\t"
                          f"…{text[max(0, i - 8):i + 8]}…")
        v["text"] = text.replace(SOURCE, TRAD)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({TRAD: "\0", SOURCE: "\0"})
    if before.translate(blind) != after.translate(blind):
        print(f"  ✗ something other than {TRAD}/{SOURCE} changed — refusing")
        return 1
    if after.count(SOURCE) != 0:
        print(f"  ✗ {after.count(SOURCE)} {SOURCE} survive — refusing")
        return 1
    if after.count(TRAD) != expected:
        print(f"  ✗ {after.count(TRAD)} {TRAD} against {expected} in the "
              f"witness — refusing")
        return 1
    for v in verses:
        wit = witness.get(v["id"])
        if wit is None:
            continue
        keep = TRAD + SOURCE
        if [c for c in v["text"] if c in keep] != [c for c in wit if c in keep]:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the "
                  f"{TRAD}/{SOURCE} sequence disagrees with the witness — "
                  f"refusing")
            return 1

    print(f"  {changed} substitutions →{TRAD} in {TR.name} "
          f"(witness has {expected} {TRAD} and 0 {SOURCE}; before: "
          f"{before.count(SOURCE)} {SOURCE}, {before.count(TRAD)} {TRAD} → "
          f"after: {after.count(SOURCE)} {SOURCE}, {after.count(TRAD)} {TRAD})")

    # ---- the lexicon, position by position -------------------------------
    lex = json.loads(LEX.read_text(encoding="utf-8"))
    simplified = [(k, f, e[f]) for k, e in lex.items()
                  for f in ("glossZh", "defZh") if f in e]
    lex_before = "".join(e[f] for e in lex.values()
                         for f in ("glossZhTw", "defZhTw") if f in e)
    for reading, n in LEX_NAMES:
        # Counted over both forms so the guard still holds once applied.
        seen = (lex_before.count(reading)
                + lex_before.count(reading.replace(SOURCE, TRAD)))
        if seen != n:
            print(f"  ✗ {LEX.name}: {reading} appears {seen} times, expected "
                  f"{n} — the data has moved under this script — refusing")
            return 1
    for reading, n in LEX_KEEP:
        if lex_before.count(reading) != n:
            print(f"  ✗ {LEX.name}: {reading} appears "
                  f"{lex_before.count(reading)} times, expected {n} — the data "
                  f"has moved under this script — refusing")
            return 1
    lex_changed = 0
    for sid, entry in lex.items():
        for field in ("glossZhTw", "defZhTw"):
            text = entry.get(field)
            if not text or SOURCE not in text:
                continue
            original = text
            for reading, _ in LEX_NAMES:
                while reading in text:
                    i = text.index(reading)
                    report.append(f"{LEX.name} {sid} {field}\t"
                                  f"…{text[max(0, i - 8):i + 10]}…"
                                  .replace("\n", "/"))
                    text = text.replace(reading,
                                        reading.replace(SOURCE, TRAD), 1)
                    lex_changed += 1
            if text != original:
                if len(text) != len(original):
                    print(f"  ✗ {sid} {field} changed length — refusing")
                    return 1
                entry[field] = text

    lex_after = "".join(e[f] for e in lex.values()
                        for f in ("glossZhTw", "defZhTw") if f in e)
    if len(lex_before) != len(lex_after):
        print(f"  ✗ {LEX.name} changed length — refusing")
        return 1
    already = sum(lex_before.count(r.replace(SOURCE, TRAD))
                  for r, _ in LEX_NAMES)
    if lex_changed + already != sum(n for _, n in LEX_NAMES):
        print(f"  ✗ {lex_changed} lexicon substitutions against "
              f"{sum(n for _, n in LEX_NAMES) - already} expected — refusing")
        return 1
    for reading, _ in LEX_NAMES:
        if reading in lex_after:
            print(f"  ✗ {reading} survives in {LEX.name} — refusing")
            return 1
    for reading, n in LEX_KEEP:
        if lex_after.count(reading) != n:
            print(f"  ✗ {reading} should have been left alone in {LEX.name} — "
                  f"refusing")
            return 1
    if lex_after.count(SOURCE) != sum(n for _, n in LEX_KEEP):
        print(f"  ✗ {lex_after.count(SOURCE)} {SOURCE} left in {LEX.name}, "
              f"expected only 加侖 — refusing")
        return 1
    now = [(k, f, e[f]) for k, e in lex.items()
           for f in ("glossZh", "defZh") if f in e]
    if now != simplified:
        print(f"  ✗ {LEX.name}: a Simplified field changed — refusing")
        return 1

    print(f"  {lex_changed} substitutions →{TRAD} in {LEX.name} "
          f"({lex_before.count(SOURCE)} {SOURCE} → {lex_after.count(SOURCE)}, "
          f"left as {SOURCE}: 加侖 ×2)")

    if args.report:
        Path(args.report).write_text("\n".join(report) + "\n", encoding="utf-8")
        print(f"  full diff ({len(report)} lines) → {args.report}")

    if args.apply:
        TR.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
        LEX.write_text(json.dumps(lex, ensure_ascii=False, indent=2) + "\n",
                       encoding="utf-8")
        print(f"  written → {TR.relative_to(ROOT)}, {LEX.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
