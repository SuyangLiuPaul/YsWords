#!/usr/bin/env python3
"""Restore 干 and 乾 in the Traditional CUV, where the converter wrote 幹.

Ninth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵, 罈, 穀, 鬆 …
or 干. Simplified 干 collapses THREE distinct traditional characters —

    干  to offend, to concern; shield; a name syllable   (干犯, 與我何干, 亞干)
    乾  dry, dried up, clean out                          (枯乾, 乾淨, 乾涸)
    幹  trunk, stalk, shaft; ability; to do               (枝幹, 才幹, 燈臺的幹)

— and this converter resolved 319 of the 341 to 幹 and the other 22 to 乾,
leaving ZERO 干 in the whole Traditional corpus. So 詩篇 22:15 「我的精力枯幹」,
出埃及記 14:21 「使海水成了幹地」, 詩篇 51:7 「我就幹淨」 printed a tree trunk,
and 民數記 5:6 「幹犯雅偉」, 約書亞記 7:1 「迦米的兒子亞幹」, 使徒行傳 18:6
「與我無幹」 printed one too.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Ours has 319 幹 + 22 乾 + ZERO 干 across 31,102 verses. The witness has
  9 幹 + 221 乾 + 111 干. A file that never once wrote 干 in 31,102 verses did
  not choose against it — and 幹 at 319 against the witness's 9 is not a
  preference either, it is the default branch of a map with two entries where
  three were needed.

  Do NOT cite the matching 341 totals as corroboration. They match only
  because the two edition differences below cancel (使徒行傳 8:27 is +1 here,
  希伯來書 2:2 is −1), so the aggregate is an accident of arithmetic. The
  load-bearing evidence is the per-verse ordered-sequence check further down.

THIS IS THE 發/髮 SHAPE, NOT THE 淨/牆 SHAPE
  幹 is a real Traditional character and is CORRECT at 9 positions, so the
  claim is never "幹 is wrong" but "these 309 positions are 乾 or 干". Each was
  decided against the witness by folding 幹/乾 → 干 on BOTH sides, matching the
  widest unambiguous context window, and reading the witness's *unfolded*
  glyph at the aligned position. Nothing here rests on a cue rule, because a
  cue rule cannot work: 以西結書 19:12 「堅固的枝幹折斷枯乾」 holds a genuine
  幹 and a 乾 four characters apart.

THE ONE POSITION THE WITNESS CANNOT SETTLE, and why it is still safe
  使徒行傳 8:27 女王幹大基 — Candace. The witness uses a different
  transliteration for the whole clause (衣索匹亞女王甘大基 against our
  埃提阿伯女王干大基), so it has no aligned position to read. Settled by two
  OTHER independent sources, both of which spell the name with 干:
    * 新譯本 Traditional (git blob 57c4686): 「衣索匹亞女王干大基有權力的太監」
    * 梁家鏗's independently produced Traditional NT
      (`assets/biblexg-v2-tr.json`): 「亞女王干大基」
  It is also the reading our own Simplified asset already carries (干大基),
  and 幹 has no name-syllable use anywhere in the corpus.

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * 新譯本 `57c4686`, a different translation, agrees on every trap: 亞干
    (Achan), 隱．干寧 (En-gannim), 比羅比尼．亞干, 干犯 at 希伯來書 2:2 — and
    on the keeps, 才幹 at 馬太福音 25:15 and 「燈臺的座、幹」 at 出埃及記 25:31.
  * 梁家鏗's Traditional NT has no such hole at all (33 幹 / 22 乾 / 3 干, and
    its 幹 are all 樹幹, 才幹 and the colloquial verb), so it corroborates the
    line rather than the conversion.

TWO VERSES WHERE THE EDITIONS GENUINELY DIFFER — documented, not repaired
  * 使徒行傳 8:27 — the transliteration above; ours holds one folded 干 where
    the witness holds none.
  * 希伯來書 2:2 — ours reads 「凡犯悖逆的」, both witnesses 「凡干犯悖逆的」.
    Ours holds none where the witness holds one. **Our Simplified asset drops
    it too**, so this is an upstream text difference and NOT something this
    conversion repair may invent. Queued separately for the user.
  The two cancel in the corpus totals, which is why the arithmetic below is
  checked per verse as well as in aggregate.

NOTHING TO DO ON THE SIMPLIFIED OR TAGGED SIDE
  Simplified 干 is the correct single form for all three meanings, and both
  `assets/cuvs-yhwh.json` (341 干, 0 幹, 0 乾) and the tagged Strong's corpus
  are Simplified. This instalment touches the Traditional asset only.

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

FORMS = "干幹乾"
FOLD = str.maketrans({"幹": "干", "乾": "干"})

# What the witness holds, asserted rather than derived so a wrong witness
# cannot quietly redefine the target.
EXPECTED = {"干": 111, "乾": 221, "幹": 9}

# The two verses where the editions do not describe the same sentence. Both
# were read in full; see the module docstring.
EDITION_DIFFERS = {
    "044008027": "Candace — 埃提阿伯…干大基 here, 衣索匹亞…甘大基 in the witness",
    "058002002": "ours drops 干犯 (so does our Simplified) — upstream, not conversion",
}

# The single position no aligned witness text exists for, with the reading two
# other independent editions give it. The cue is matched against the FOLDED
# verse, so it identifies the same position before and after the repair.
UNWITNESSED = {("044008027", "干大基"): "干"}

# Witness-independent audit. None of these may still read 幹 afterwards, and
# none of them is how the repair decides anything.
DRY_CUES = ("枯乾", "乾淨", "乾涸", "乾渴", "乾地", "乾草", "乾糧", "乾燥",
            "乾癟", "乾瘦", "乾裂", "乾焦", "乾熱", "乾柴", "乾餅", "乾竭",
            "擦乾", "喝乾", "燒乾", "葡萄乾")
OFFEND_CUES = ("干犯", "何干", "無干", "相干", "干戈", "若干", "干預", "干休",
               "亞干", "干寧", "米母干", "亞多尼干", "亞斯利干")
# The nine the witness keeps as 幹, spelled out so a later blanket
# substitution in either direction fails this script as well as the test.
TRUNK_CUES = ("枝幹", "才幹", "座和幹", "的座和幹", "幹也死在土中")


def resolve(text: str, i: int, witness: str) -> tuple[str, str] | None:
    """(glyph, how) the witness reads at our position `i`, or None.

    Both sides are folded before matching, so the alignment cannot be biased
    by the very characters under repair.
    """
    folded, fwit = text.translate(FOLD), witness.translate(FOLD)
    for w in range(8, 0, -1):
        a, b = max(0, i - w), min(len(folded), i + w + 1)
        pat = folded[a:i] + "干" + folded[i + 1:b]
        hits = [j for j in range(len(fwit)) if fwit.startswith(pat, j)]
        if len(hits) == 1:
            return witness[hits[0] + (i - a)], f"ctx{w}"
    # Ordinal fallback: only legitimate when the two verses hold the same
    # number of the glyph, which is checked per verse before we get here.
    positions = [j for j, c in enumerate(fwit) if c == "干"]
    if len(positions) == folded.count("干"):
        k = folded[:i].count("干")
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
        wit = witness.get(v["id"], "")
        ours_n = text.translate(FOLD).count("干")
        wit_n = wit.translate(FOLD).count("干")
        if ours_n != wit_n and v["id"] not in EDITION_DIFFERS:
            print(f"  ✗ {ref} — ours holds {ours_n} 干/幹/乾, witness {wit_n} "
                  f"— refusing")
            return 1

        out = list(text)
        for i, ch in enumerate(text):
            if ch not in FORMS:
                continue
            fixed = next((g for (vid, cue), g in UNWITNESSED.items()
                          if vid == v["id"]
                          and text.translate(FOLD).startswith(cue, i)), None)
            if fixed is not None:
                want, how = fixed, "unwitnessed"
            else:
                found = resolve(text, i, wit) if ours_n == wit_n else None
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
        print("  ✗ something other than 干/幹/乾 changed — refusing")
        return 1

    got = {g: after.count(g) for g in FORMS}
    if got != EXPECTED:
        print(f"  ✗ result holds {got} against the witness's {EXPECTED} "
              f"— refusing")
        return 1

    # Rules out an offsetting pair inside a single verse: the ordered SEQUENCE
    # of the three forms must match the witness verse for verse, not merely
    # the counts. The two documented edition differences are exempt.
    for v in verses:
        wit = witness.get(v["id"])
        if wit is None or v["id"] in EDITION_DIFFERS:
            continue
        if [c for c in v["text"] if c in FORMS] != [c for c in wit if c in FORMS]:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the 干/幹/乾 "
                  f"sequence disagrees with the witness — refusing")
            return 1

    # Audits that do not depend on the witness at all.
    for cue in DRY_CUES + OFFEND_CUES:
        stale = cue.replace("乾", "幹").replace("干", "幹")
        if stale in after:
            print(f"  ✗ 「{stale}」 still in the corpus — refusing")
            return 1
    for cue in TRUNK_CUES:
        if cue not in after:
            print(f"  ✗ 「{cue}」 is no longer in the corpus — refusing")
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
