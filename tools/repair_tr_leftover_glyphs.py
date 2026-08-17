#!/usr/bin/env python3
"""Replace nine simplified-only glyphs the converter left in the Traditional CUV.

`assets/cuvs-yhwh-tr.json` is a script conversion of the Simplified edition, and
the converter that produced it had holes. The first one found was the classifier
隻 (tools/repair_tr_classifier.py). Comparing the whole corpus against an
independent Traditional edition turned up ~1,100 more simplified characters, of
which these nine have NO competing traditional sense anywhere in this corpus:

    凈 519 → 淨    墻 234 → 牆    余 230 → 餘    镕 11 → 鎔
    鸮 3 → 鴞      飖 3 → 颻      腌 2 → 醃      珰 1 → 璫    鹯 1 → 鸇

The remaining classes are deliberately NOT here, because one simplified glyph
maps to several traditional ones and each needs its own evidence: 幹 (乾 dry /
干 offend / the names 亞幹, 亞多尼幹…), 發 (發 issue / 髮 hair), 谷 (穀 grain /
谷 valley), 松 (鬆 loosen / 松 pine), 采. See docs/autonomous-queue.md.

WHY THIS IS NOT A BLANKET SUBSTITUTION even though the rules read like one
  余 is a real traditional character — the classical pronoun "I" and a surname —
  and 腌 is a real one too (腌臢, filthy); 凈 exists as a traditional variant.
  So "余 is always 餘" is a claim about THIS corpus, not about the language, and
  a claim about a corpus has to be checked against the corpus. Nothing here is
  applied on the strength of the rule: every one of the 1,004 occurrences is
  confirmed individually against a witness before it is touched, and the script
  REFUSES if even one cannot be confirmed. (All 230 余 read 其餘/餘剩/有餘/餘民/
  餘種/餘地/餘怒/餘火/餘福/餘力; both 腌 are 鹽醃, pickling.)

  The cleanest evidence is a partition: before this repair our asset contained
  ZERO of all nine traditional forms and the witness contained ZERO of all nine
  simplified ones. A converter that never once produced 淨, 牆 or 餘 in 31,102
  verses did not choose them — it could not write them, which leaves no
  editorial-preference hypothesis to rule out.

THE WITNESS
  `assets/cuv-tr.json`, the plain 和合本 Traditional (耶和華, not 雅偉), was a
  separately imported edition of the same base text, dropped from the repo at
  v1.4.5 and permanently readable as git blob 7a2dc43. It shares verse ids with
  ours. It carries 淨 518 / 牆 234 / 餘 230 / 鎔 12 / 鴞 3 / 颻 3 / 醃 2 / 璫 1 /
  鸇 1 and ZERO of the nine simplified forms — which is what makes ours a
  converter hole rather than an editorial choice.

  The two count differences are edition differences, not defects, and were read:
    * 民數記 35:33 — ours repeats the word inside an inline note
      「潔淨<note: 潔淨原文作贖>」 where the witness sets 「（原文是贖）」, so
      ours has one more 淨.
    * 耶利米書 9:7 — ours writes 融化 where the witness writes 鎔化. Both are
      traditional; nothing to fix.

HOW AN OCCURRENCE IS CONFIRMED, in descending order of strength
  ctx   the surrounding characters, with the traditional form substituted in,
        appear verbatim in the witness's verse (977 of 1,004, most with an
        8-character window either side)
  left / right
        only one side matches, because the other side is a place the two
        editions legitimately differ — 雅偉/耶和華, 裏/裡, 胡/鬍, our inline
        <note: …> markup against the witness's （…）, or our own still-unfixed
        幹凈 against the witness's 乾淨 (25)
  count the verse holds the same number of them as the witness holds of the
        traditional form, but no context survives at all (2: 哈巴谷書 2:11
        「墻裏」 vs 「牆裡」 with the glyph first in the verse, and 使徒行傳
        18:6 where ours is inside note markup)

Dry-run by default; --apply writes. Re-running after --apply is safe: with the
simplified forms gone there is nothing left to confirm and nothing to do.
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

PAIRS = {
    "凈": "淨", "墻": "牆", "余": "餘", "镕": "鎔", "鸮": "鴞",
    "飖": "颻", "腌": "醃", "珰": "璫", "鹯": "鸇",
}


def confirm(text: str, i: int, trad: str, witness: str):
    """Strongest witness evidence for the occurrence at `i`, or None."""
    for w in (8, 6, 4, 3, 2, 1):
        if text[max(0, i - w):i] + trad + text[i + 1:i + 1 + w] in witness:
            return f"ctx{w}"
    for w in (4, 3, 2, 1):
        if i >= w and text[i - w:i] + trad in witness:
            return f"left{w}"
        if len(text) >= i + 1 + w and trad + text[i + 1:i + 1 + w] in witness:
            return f"right{w}"
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

    before = "".join(v["text"] for v in verses)
    tiers: collections.Counter[str] = collections.Counter()
    report: list[str] = []
    changed = 0

    for v in verses:
        text = v["text"]
        wit = witness.get(v["id"])
        if wit is None and any(s in text for s in PAIRS):
            print(f"  ✗ {v['id']} has no witness verse — refusing")
            return 1
        out = list(text)
        for i, ch in enumerate(text):
            trad = PAIRS.get(ch)
            if trad is None:
                continue
            how = confirm(text, i, trad, wit)
            if how is None:
                # Last resort: the verse holds as many of ours as the witness
                # holds of the traditional form, so the mapping is still 1:1
                # even though no context survived the edition differences.
                if text.count(ch) == wit.count(trad) > 0:
                    how = "count"
                else:
                    print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — "
                          f"{ch}→{trad} in 「{text[max(0, i - 8):i + 8]}」 is not "
                          f"confirmed by the witness — refusing")
                    return 1
            out[i] = trad
            tiers[how[:3] if how != "count" else how] += 1
            changed += 1
            report.append(f"{v['book']} {v['chapter']}:{v['verse']}\t{how}\t"
                          f"{ch}→{trad}\t…{text[max(0, i - 8):i + 8]}…")
        v["text"] = "".join(out)

    after = "".join(v["text"] for v in verses)

    # Nothing but these nine substitutions may have happened, and the text must
    # be exactly as long as it was: these are all one character for one.
    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    if before.translate(str.maketrans(PAIRS)) != after:
        print("  ✗ something other than the nine glyphs changed — refusing")
        return 1

    print(f"  {changed} substitutions across {len(PAIRS)} glyphs")
    for s, t in PAIRS.items():
        print(f"    {s}→{t}  {before.count(s):>4}  "
              f"(witness has {sum(w.count(t) for w in witness.values()):>4} {t})")
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
