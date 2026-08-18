#!/usr/bin/env python3
"""Restore 咸 in the Traditional Bible at 書 10:3, where the converter salted a
Canaanite king.

Seventeenth instalment of the converter-hole defect, and the SMALLEST — one
character, one verse. It is here at all because of the standing rule: a common
noun printed in the wrong script is a blemish, a proper NAME printed wrong is
the app stating something untrue about scripture.

    約書亞記 10:3  「…去見希伯崙王何鹹、耶末王毗蘭…」
                    Hoham, king of Hebron, spelt "salty".

WHAT THE CONVERTER DID
  Simplified merges 鹹 (salty) onto 咸, which in Traditional is a separate,
  live character meaning "all / universally" (咸信, 咸豐). opencc's default
  single-character mapping runs the merge backwards, unconditionally:

      $ echo 何咸 咸海 咸信 鹹水 | opencc -c s2t
        何鹹 鹹海 咸信 鹹水

  Its phrase table knows 咸信 and so keeps that one; it does not know the name
  何咸, so it salted it. Our Simplified source `assets/cuvs-yhwh.json` reads
  「希伯仑王何咸」 — correct, because Simplified is where the two characters are
  one — and the Traditional edition converted from it reads 何鹹.

WHY THIS IS A SPLIT AND NOT A PARTITION — SO IT IS DECIDED AT ONE POSITION
  The fifteen sweeping instalments before this one rested on a partition: ours
  held ZERO of the Traditional form across 31,102 verses, so no editorial
  hypothesis survived and the class could move whole. That argument is NOT
  available here in the direction that matters. Ours holds 7 鹹 and 0 咸; the
  witness holds 6 鹹 and 1 咸. Six of our seven are genuine salt and MUST
  survive:

      約伯記 30:4   採鹹草          約伯記 39:6   使鹹地當它的居所
      馬太福音 5:13 叫它再鹹呢      馬可福音 9:50 叫它再鹹呢
      路加福音 14:34 叫它再鹹呢     雅各書 3:12   鹹水裏也不能發出甜水來

  So this script sweeps nothing. It aligns our 咸/鹹 sequence against the
  witness's verse by verse and substitutes only where the witness disagrees,
  which today is exactly one position.

  It is also the one instalment where the Simplified twin CANNOT confirm the
  fix — the check that the 崙 instalment leaned on hardest. 仑/伦 are distinct
  in Simplified, so that defect could be caught from inside the repo forever;
  咸 is not, because the merge is on the Simplified side. The evidence has to
  come from outside, and it does:

    * `assets/cuv-tr.json` as git blob 7a2dc43 — the plain 和合本 Traditional
      dropped at v1.4.5, a separately imported edition of the same base text.
      1 咸 / 6 鹹, and its 咸 is 何咸 at 書 10:3.
    * A published 新標點和合本 Traditional (ebible `cmn-cu89t`): 1 咸 / 6 鹹,
      the same seven verses, the same split.
      「所以耶路撒冷王亞多尼‧洗德打發人去見希伯崙王何咸、耶末王毗蘭…」

  Two independently produced Traditional editions agree with each other and
  with the Simplified source, against ours alone.

WHAT WAS CHECKED AND FOUND CLEAN, SO IT IS NOT TOUCHED
  * `assets/strongs/hebrew.json` and `greek.json` came through a different
    pipeline and are already RIGHT on both readings — H3458 keeps 咸信
    ("generally believed"), H4420 reads 鹹性 and G252 讀 鹹的. The lexicon has
    no 咸/鹹 defect and is deliberately left alone; a sweep here would have
    broken H3458.
  * H1944, Hoham's own lexicon entry, carries no Chinese spelling of the name
    at all — 「征服迦南時期的希伯崙王 #書 10:3|」 — so there is nothing to fix.
  * `assets/sermons/zh-TW/018.txt` matches 何鹹 on a grep and is a FALSE
    POSITIVE: 「不再有任何鹹味」 — 任何 + 鹹味. Its 32 鹹 are all salt, in a
    sermon on Matthew 5:13.
  * The Strong's-tagged corpus is Simplified only (see tagged_text_service.dart)
    and there is no runtime s2t map in lib/, so 書 10:3 has exactly one
    Traditional spelling in this repo and it is the one repaired here.

Dry-run by default; --apply writes. Re-running after --apply is safe.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TR = ROOT / "assets/cuvs-yhwh-tr.json"
WITNESS_BLOB = "7a2dc43"

NAME = "咸"   # the name character, and 咸 = "all" in 咸信
SALT = "鹹"   # salty

# What the witness must look like for this script to be the right tool. If the
# witness ever stops holding exactly one 咸 the alignment below is answering a
# different question and the reasoning has to be redone by hand.
WITNESS_NAME_COUNT = 1
WITNESS_SALT_COUNT = 6

# The single position this repair is licensed to change, and the reading it
# must produce. Derived from the witness alignment, then asserted — so a
# witness that drifted could not quietly widen the repair.
EXPECTED = {"006010003": "何咸"}

# The six genuine salts, which must read 鹹 before and after.
SALT_IDS = {
    "018030004", "018039006", "040005013",
    "041009050", "042014034", "059003012",
}


def sequence(text: str) -> str:
    """The 咸/鹹 characters of a verse, in order — its glyph fingerprint."""
    return "".join(c for c in text if c in (NAME, SALT))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    verses = json.loads(TR.read_text(encoding="utf-8"))
    witness = {
        v["id"]: v["text"]
        for v in json.loads(subprocess.run(
            ["git", "cat-file", "-p", WITNESS_BLOB], cwd=ROOT,
            capture_output=True, text=True, check=True).stdout)
    }

    before = "".join(v["text"] for v in verses)
    witness_all = "".join(witness.values())

    if (witness_all.count(NAME) != WITNESS_NAME_COUNT
            or witness_all.count(SALT) != WITNESS_SALT_COUNT):
        print(f"  ✗ the witness holds {witness_all.count(NAME)} {NAME} / "
              f"{witness_all.count(SALT)} {SALT}, expected "
              f"{WITNESS_NAME_COUNT}/{WITNESS_SALT_COUNT} — refusing")
        return 1

    for vid, text in witness.items():
        if sequence(text) and vid not in {v["id"] for v in verses}:
            print(f"  ✗ witness verse {vid} carries the glyph and is missing "
                  f"from ours — refusing")
            return 1

    changed: dict[str, str] = {}
    for v in verses:
        text = v["text"]
        ours = sequence(text)
        if not ours:
            continue
        wit = witness.get(v["id"])
        if wit is None:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — no witness "
                  f"verse to confirm against — refusing")
            return 1
        theirs = sequence(wit)
        if len(ours) != len(theirs):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — ours holds "
                  f"{len(ours)} of the glyph, the witness {len(theirs)} — the "
                  f"positions cannot be aligned — refusing")
            return 1
        if ours == theirs:
            continue
        # Rewrite the disagreeing positions, in order, from the witness.
        out, k = [], 0
        for ch in text:
            if ch in (NAME, SALT):
                if ch == SALT and theirs[k] == NAME:
                    out.append(NAME)
                elif ch == NAME and theirs[k] == SALT:
                    # Ours reads the name where the witness reads salt. That is
                    # the opposite defect and is NOT what this script argues
                    # about — stop rather than guess.
                    print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — ours "
                          f"reads {NAME} where the witness reads {SALT}; this "
                          f"script does not decide that direction — refusing")
                    return 1
                else:
                    out.append(ch)
                k += 1
            else:
                out.append(ch)
        v["text"] = "".join(out)
        changed[v["id"]] = f"{v['book']} {v['chapter']}:{v['verse']}"

    applied_ids = set(changed) if changed else set()
    already = {vid for vid in EXPECTED
               if EXPECTED[vid] in next(v["text"] for v in verses
                                        if v["id"] == vid)}
    if applied_ids and applied_ids != set(EXPECTED):
        print(f"  ✗ this repair is licensed for {sorted(EXPECTED)} but wanted "
              f"to change {sorted(applied_ids)} — refusing")
        return 1

    after = "".join(v["text"] for v in verses)
    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({NAME: "\0", SALT: "\0"})
    if before.translate(blind) != after.translate(blind):
        print(f"  ✗ something other than {NAME}/{SALT} changed — refusing")
        return 1
    if after.count(NAME) != WITNESS_NAME_COUNT or \
            after.count(SALT) != WITNESS_SALT_COUNT:
        print(f"  ✗ {after.count(NAME)} {NAME} / {after.count(SALT)} {SALT} "
              f"against the witness's {WITNESS_NAME_COUNT}/"
              f"{WITNESS_SALT_COUNT} — refusing")
        return 1
    by_id = {v["id"]: v for v in verses}
    for vid, reading in EXPECTED.items():
        if reading not in by_id[vid]["text"]:
            print(f"  ✗ {vid} does not read {reading} — refusing")
            return 1
    for vid in SALT_IDS:
        if SALT not in by_id[vid]["text"] or NAME in by_id[vid]["text"]:
            print(f"  ✗ {vid} is a genuine salt and no longer reads {SALT} "
                  f"alone — refusing")
            return 1
    for v in verses:
        wit = witness.get(v["id"])
        if wit is not None and sequence(v["text"]) != sequence(wit):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the "
                  f"{NAME}/{SALT} sequence still disagrees with the witness — "
                  f"refusing")
            return 1

    if changed:
        for vid, where in changed.items():
            print(f"  {where}  …{by_id[vid]['text'][20:40]}…")
        print(f"  {len(changed)} substitution →{NAME} in {TR.name} "
              f"(before: {before.count(NAME)} {NAME}, {before.count(SALT)} "
              f"{SALT} → after: {after.count(NAME)} {NAME}, "
              f"{after.count(SALT)} {SALT})")
    else:
        print(f"  nothing to do — already {after.count(NAME)} {NAME} / "
              f"{after.count(SALT)} {SALT}, matching the witness "
              f"({len(already)} expected reading(s) already present)")

    if args.apply and changed:
        TR.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
        print(f"  written → {TR.relative_to(ROOT)}")
    elif not args.apply:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
