#!/usr/bin/env python3
"""Restore 制 in the Traditional CUV, where the converter wrote 製 for both.

Twentieth instalment of the converter-hole defect, and the first of the
one-to-many SPLITS after the five exact partitions (隻, 恆, 卜, 淩, 症, 癒) were
cleared. Simplified merged 製 onto 制, so one Simplified character stands for
two independent Traditional 正字 —

    制  system, statute, to restrain, to subdue   (制度, 節制, 轄制, 制伏)
    製  to manufacture, to tailor                 (製造, 製作)

— and the map that produced `assets/cuvs-yhwh-tr.json` expanded 制 → 製
unconditionally. So a Traditional Bible printed 加拉太書 5:23 「溫柔、節製」,
羅馬書 6:9 …「死不再作他的主」… 創世紀 3:16 「他必管轄你」 — and 33 轄製,
30 製伏, 9 壓製, 8 節製, 6 克製, 1 挾製, 1 製度 and 2 按製子 besides. None of
those eight is a word in any Chinese script.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Ours holds 157 製 and ZERO 制 across 31,102 verses; our own Simplified twin
  `assets/cuvs-yhwh.json` holds 157 制 and ZERO 製 in the same places. An
  unconditional 1:1 map, right 67 times and wrong 90 times — the same shape as
  於/于 (`repair_tr_jushab_hesed.py`), only here the minority branch is 90
  positions rather than one.

  This is NOT the 蹟/跡 shape, where both readings are legitimate Traditional
  spellings and two editions simply chose differently. 製 cannot stand for 制
  in any orthography: 節製 and 轄製 are not variants, they are non-words.

THIS IS A SPLIT, SO NOTHING RESTS ON A CUE RULE
  製 is correct at 67 positions (62 製造 + 5 製作) and the claim is never
  "製 is wrong" but "these 90 positions are 制". Each is decided by folding
  制 → 製 on BOTH sides, matching the widest unambiguous context window, and
  reading the witness's *unfolded* glyph at the aligned position.

  Worth recording because it makes the alignment easy: no verse in the corpus
  holds both readings, so the two senses never have to be told apart inside one
  sentence (unlike 幹, where 以西結書 19:12 sets a genuine 幹 four characters
  from a 乾). The cue audit at the end of this script is therefore a check on
  the result, not the method.

THE WITNESSES
  * git blob 7a2dc43 (`assets/cuv-tr.json` as it stood before v1.4.5) —
    90 制 / 67 製, and every one of the 31,102 verses holds the same number of
    the folded character as ours, with no exceptions to document at all.
  * published 新標點和合本, ebible `cmn-cu89t` — 90 制 / 66 製, the same 制
    count and the same readings. It is the same textual family as the blob
    (both set 新標點 punctuation), so it is corroboration, not a second line.
  * 梁家鏗's independently translated Traditional NT
    (`assets/biblexg-v2-tr.json`) IS a separate line, and it distinguishes the
    pair exactly: 60 制 (節制, 壓制, 制伏, 制服, 控制, 制度) against 6 製
    (製作, 製品, 製成). It writes 節制, never 節製.

SCOPE — the verse asset only
  * `assets/cuvs-yhwh.json` and the tagged Strong's corpus are Simplified,
    where 制 is the correct single form for both senses. Nothing to do.
  * `assets/strongs/*.json` already distinguish the pair in their `*ZhTw`
    fields (製造/製作/銅製的 against 節制/限制/抑制/轄制), so they were NOT
    produced by this map and must not be swept.
  * `assets/maps_index.json` sets zh-Hant 「編製的應許之地地圖」, which is the
    correct Traditional word for compiling — left alone deliberately.

Dry-run by default; --apply writes. Re-running after --apply is safe.
"""
from __future__ import annotations

import argparse
import collections
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TR = ROOT / "assets/cuvs-yhwh-tr.json"
WITNESS_BLOB = "7a2dc43"

FORMS = "制製"
FOLD = str.maketrans({"制": "製"})

# What the witness holds, asserted rather than derived so a wrong witness
# cannot quietly redefine the target.
EXPECTED = {"制": 90, "製": 67}

# Readings that must NOT survive the repair. Every one of the 90 falls under
# one of these, and none of them is a word with 製.
RESTRAINT_CUES = ("轄制", "制伏", "節制", "壓制", "克制", "剋制", "挾制",
                  "制度", "按制子", "制服", "抑制", "限制", "控制")
# The 67 that stay, spelled out so a blanket substitution in either direction
# fails this script as well as the test.
MANUFACTURE_CUES = ("製造", "製作")
EXPECTED_KEEPS = {"製造": 62, "製作": 5}


def resolve(text: str, i: int, witness: str) -> tuple[str, str] | None:
    """(glyph, how) the witness reads at our position `i`, or None.

    Both sides are folded before matching, so the alignment cannot be biased
    by the very characters under repair.
    """
    folded, fwit = text.translate(FOLD), witness.translate(FOLD)
    for w in range(8, 0, -1):
        a, b = max(0, i - w), min(len(folded), i + w + 1)
        pat = folded[a:i] + "製" + folded[i + 1:b]
        hits = [j for j in range(len(fwit)) if fwit.startswith(pat, j)]
        if len(hits) == 1:
            return witness[hits[0] + (i - a)], f"ctx{w}"
    # Ordinal fallback: only legitimate when the two verses hold the same
    # number of the glyph, which is checked per verse before we get here.
    positions = [j for j, c in enumerate(fwit) if c == "製"]
    if len(positions) == folded.count("製"):
        k = folded[:i].count("製")
        if k < len(positions):
            return witness[positions[k]], "ordinal"
    return None


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

    have = collections.Counter()
    for text in witness.values():
        for g in FORMS:
            have[g] += text.count(g)
    if dict(have) != EXPECTED:
        print(f"  ✗ witness holds {dict(have)}, expected {EXPECTED} — refusing")
        return 1

    before = "".join(v["text"] for v in verses)
    tiers: collections.Counter[str] = collections.Counter()
    moves: collections.Counter[str] = collections.Counter()
    report: list[str] = []
    changed = 0

    for v in verses:
        text = v["text"]
        if not any(g in text for g in FORMS):
            continue
        ref = f"{v['book']} {v['chapter']}:{v['verse']}"
        wit = witness.get(v["id"])
        if wit is None:
            print(f"  ✗ {ref} — no witness verse for this id — refusing")
            return 1
        ours_n = text.translate(FOLD).count("製")
        wit_n = wit.translate(FOLD).count("製")
        if ours_n != wit_n:
            print(f"  ✗ {ref} — ours holds {ours_n} 制/製, witness {wit_n} "
                  f"— refusing")
            return 1

        out = list(text)
        for i, ch in enumerate(text):
            if ch not in FORMS:
                continue
            found = resolve(text, i, wit)
            if found is None:
                print(f"  ✗ {ref} — no witness reading for "
                      f"「{text[max(0, i - 6):i + 7]}」 — refusing")
                return 1
            want, how = found
            if want not in FORMS:
                print(f"  ✗ {ref} — witness reads 「{want}」 at "
                      f"「{text[max(0, i - 6):i + 7]}」 — refusing")
                return 1
            tiers[how] += 1
            if want == ch:
                continue
            out[i] = want
            moves[f"{ch}→{want}"] += 1
            changed += 1
            report.append(f"{ref}\t{ch}→{want}\t{how}\t"
                          f"…{text[max(0, i - 8):i + 8]}…")
        v["text"] = "".join(out)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({g: "\0" for g in FORMS})
    if before.translate(blind) != after.translate(blind):
        print("  ✗ something other than 制/製 changed — refusing")
        return 1

    got = {g: after.count(g) for g in FORMS}
    if got != EXPECTED:
        print(f"  ✗ result holds {got} against the witness's {EXPECTED} "
              f"— refusing")
        return 1

    # Rules out an offsetting pair inside a single verse: the ordered SEQUENCE
    # of the two forms must match the witness verse for verse, not merely the
    # counts.
    for v in verses:
        wit = witness.get(v["id"])
        if wit is None:
            continue
        if [c for c in v["text"] if c in FORMS] != [c for c in wit
                                                    if c in FORMS]:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the 制/製 "
                  f"sequence disagrees with the witness — refusing")
            return 1

    # Audits that do not depend on the witness at all.
    for cue in RESTRAINT_CUES:
        stale = cue.replace("制", "製")
        if stale in after:
            print(f"  ✗ 「{stale}」 still in the corpus — refusing")
            return 1
    for cue, n in EXPECTED_KEEPS.items():
        if after.count(cue) != n:
            print(f"  ✗ 「{cue}」 appears {after.count(cue)} times, "
                  f"expected {n} — refusing")
            return 1

    print(f"  {changed} substitutions: {dict(sorted(moves.items()))}")
    print(f"  before: { {g: before.count(g) for g in FORMS} } → after: {got} "
          f"(witness {EXPECTED})")
    print(f"  confirmation: {dict(sorted(tiers.items()))}")

    if args.report:
        Path(args.report).write_text("\n".join(report) + "\n", encoding="utf-8")
        print(f"  full diff ({len(report)} lines) → {args.report}")

    if args.apply:
        TR.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
        print(f"  written → {TR.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
