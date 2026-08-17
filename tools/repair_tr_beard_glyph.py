#!/usr/bin/env python3
"""Restore 鬍鬚 (beard) and 採 (to pick) in the Traditional CUV.

Fourth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮 … or 鬍, or 鬚, or 採. So the file
reads 「男人胡須上有災病」 (利未記 13:29), 「將大衛臣僕的胡須剃去一半」
(撒母耳記下 10:4), 「拔了頭髮和胡須」 (以斯拉記 9:3). In modern Traditional 胡
is 胡亂/胡言, a surname and a transliteration syllable; 須 is 必須, "must". The
beard is 鬍鬚, and neither character of it existed anywhere in this file.

THREE GLYPHS, TWO DIFFERENT SHAPES, ONE PIECE OF EVIDENCE
  采 → 採 is a true partition: ours has 3 采 and 0 採, the witness 0 采 and 3 採,
  and all three are the verb (約伯記 30:4 採鹹草, 雅歌 5:1 採了我的沒藥, 雅歌
  6:2 採百合花). Nothing competes for those positions.

  胡 → 鬍 and 須 → 鬚 are NOT. 7 of our 28 胡 are genuine and must not move: the
  places 基列胡瑣 (民數記 22:39) and 伊胡得 (約書亞記 19:45), the priestly name
  胡巴 (歷代志上 24:13), and 胡言亂語 / 胡寫亂畫 (撒母耳記上 18:10, 21:13,
  路加福音 24:11, 使徒行傳 17:18). 86 of our 106 須 are 必須 / 須要 and must not
  move either. 撒母耳記上 21:13 holds one 胡 of each kind in the same verse —
  「在城門的門扇上胡寫亂畫，使唾沫流在胡子上」 — so this cannot be decided a
  verse at a time, let alone by a rule.

  All three are therefore settled the same way: per occurrence, against a
  witness that is asked what IT reads at that position.

THE WITNESS
  `assets/cuv-tr.json`, the plain 和合本 Traditional (耶和華, not 雅偉), a
  separately imported edition of the same base text, dropped from the repo at
  v1.4.5 and permanently readable as git blob 7a2dc43. It carries 鬍 21 / 胡 7,
  鬚 20 / 須 86 and 採 3 / 采 0, against our 鬍 0 / 胡 28, 鬚 0 / 須 106 and
  採 0 / 采 3.

  The partition is what makes this a converter hole rather than an editorial
  choice: ours has ZERO 鬍, ZERO 鬚 and ZERO 採 across 31,102 verses. A file that
  never once wrote the character did not decide against it. Note also that the
  witness's 須 count is exactly ours minus its 鬚 count, and its 胡 count exactly
  ours minus its 鬍 count — the two editions hold the same words, and differ only
  on which script they are written in.

HOW EACH OCCURRENCE IS DECIDED
  Not by substituting a guess and looking for it — that fails on 鬍鬚, where two
  glyphs under repair sit side by side and neither can be confirmed until the
  other has been. Instead both texts are FOLDED (鬍→胡, 鬚→須, 採→采), the
  surrounding context is located in the folded witness, and the witness is then
  read at the aligned position to see which character it actually has there.

  The widest context that matches wins, and a window is only accepted if every
  place it matches gives the SAME answer, so an ambiguous alignment is refused
  rather than guessed. An occurrence with no evidence at all is left alone; the
  per-verse count assertion below is what stops that from hiding a miss.

WHAT WOULD CATCH A MISSED ONE
  Three things, any of which refuses the whole run:
    * per verse, the number of the traditional form we end up with must equal
      the witness's — so a beard the alignment failed to find is fatal, not
      silent;
    * the corpus totals must land exactly on the witness's 21 / 20 / 3;
    * the whole corpus is swept afterwards for beard collocations still reading
      the simplified form (胡須, 鬍須, 胡鬚, 胡子, 剃胡, 拔胡, 頭髮和胡 …), which
      finds 21 before the repair and must find none after. That sweep does not
      depend on the witness, so it also covers verses the witness words
      differently.

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

PAIRS = {"胡": "鬍", "須": "鬚", "采": "採"}
FOLD = str.maketrans({t: s for s, t in PAIRS.items()})

# Collocations in which the simplified form can only be a beard. Used to audit
# the result, never to decide it.
BEARD_CUES = ("胡須", "鬍須", "胡鬚", "胡子", "剃胡", "拔胡", "刮胡", "剪胡",
              "髮和胡", "鬚和胡")


def read_witness(text: str, i: int, witness: str) -> tuple[str, str] | None:
    """What the witness has at our position `i`, and how strongly aligned.

    Both sides are folded so that a glyph still awaiting repair cannot break the
    match; the answer is then read from the UNfolded witness. Returns None when
    no window aligns, and refuses (also None) any window whose matches disagree.
    """
    folded = witness.translate(FOLD)
    ours = text.translate(FOLD)

    def lookup(window: str, offset: int) -> str | None:
        found = {witness[j + offset]
                 for j in range(len(folded))
                 if folded.startswith(window, j)}
        return found.pop() if len(found) == 1 else None

    for w in (8, 6, 4, 3, 2, 1):
        lo = max(0, i - w)
        got = lookup(ours[lo:i + 1 + w], i - lo)
        if got is not None:
            return got, f"ctx{w}"
    for w in (4, 3, 2, 1):
        if i >= w and (got := lookup(ours[i - w:i + 1], w)) is not None:
            return got, f"left{w}"
        if len(ours) >= i + 1 + w and (got := lookup(ours[i:i + 1 + w], 0)) is not None:
            return got, f"right{w}"
    return None


def beard_cue_hits(corpus: str) -> list[str]:
    hits = []
    for cue in BEARD_CUES:
        start = 0
        while (j := corpus.find(cue, start)) != -1:
            start = j + 1
            hits.append(corpus[max(0, j - 8):j + len(cue) + 6])
    return hits


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
    expected = {t: sum(w.count(t) for w in witness.values())
                for t in PAIRS.values()}
    tiers: collections.Counter[str] = collections.Counter()
    kept: collections.Counter[str] = collections.Counter()
    report: list[str] = []
    changed = 0

    for v in verses:
        text = v["text"]
        if not any(s in text or t in text for s, t in PAIRS.items()):
            continue
        wit = witness.get(v["id"])
        if wit is None:
            print(f"  ✗ {v['id']} has no witness verse — refusing")
            return 1
        where = f"{v['book']} {v['chapter']}:{v['verse']}"

        # The two editions must agree on how many of the word this verse holds,
        # otherwise the witness is not talking about the same sentence. Counted
        # over both forms so the check still holds once the repair is applied.
        for simp, trad in PAIRS.items():
            ours_n = text.count(simp) + text.count(trad)
            wit_n = wit.count(simp) + wit.count(trad)
            if ours_n != wit_n:
                print(f"  ✗ {where} — ours has {ours_n} {simp}/{trad}, the "
                      f"witness {wit_n} — refusing")
                return 1

        out = list(text)
        moved: collections.Counter[str] = collections.Counter()
        for i, ch in enumerate(text):
            trad = PAIRS.get(ch)
            if trad is None:
                continue
            evidence = read_witness(text, i, wit)
            if evidence is None:
                continue
            got, how = evidence
            if got == ch:
                kept[ch] += 1
                report.append(f"{where}\tkeep {ch}\t{how}\t"
                              f"…{text[max(0, i - 8):i + 8]}…")
                continue
            out[i] = trad
            moved[trad] += 1
            changed += 1
            tiers[how[:3]] += 1
            report.append(f"{where}\t{ch}→{trad}\t{how}\t"
                          f"…{text[max(0, i - 8):i + 8]}…")

        # Anything the alignment failed to decide has been left alone above.
        # This is where that stops being safe silently.
        for simp, trad in PAIRS.items():
            if moved[trad] + text.count(trad) != wit.count(trad):
                print(f"  ✗ {where} — confirmed "
                      f"{moved[trad] + text.count(trad)} {trad}, the witness "
                      f"has {wit.count(trad)} — refusing")
                return 1
        v["text"] = "".join(out)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({c: "\0" for c in "胡鬍須鬚采採"})
    if before.translate(blind) != after.translate(blind):
        print("  ✗ something other than 胡/鬍, 須/鬚, 采/採 changed — refusing")
        return 1
    for simp, trad in PAIRS.items():
        if after.count(trad) != expected[trad]:
            print(f"  ✗ {after.count(trad)} {trad} against {expected[trad]} in "
                  f"the witness — refusing")
            return 1
        if (after.count(simp) + after.count(trad)
                != before.count(simp) + before.count(trad)):
            print(f"  ✗ the {simp}/{trad} total moved — refusing")
            return 1
    leftover = beard_cue_hits(after)
    if leftover:
        print(f"  ✗ {len(leftover)} beard collocations still read 胡/須 — "
              f"refusing")
        for s in leftover[:10]:
            print(f"      …{s}…")
        return 1

    print(f"  {changed} substitutions")
    for simp, trad in PAIRS.items():
        print(f"    {simp}→{trad}  {before.count(simp)} {simp} → "
              f"{after.count(simp)} {simp} + {after.count(trad)} {trad} "
              f"(witness: {sum(w.count(simp) for w in witness.values())} {simp}"
              f" + {expected[trad]} {trad})")
    print(f"  confirmation: {dict(sorted(tiers.items()))}")
    print(f"  read as itself by the witness and left alone: {dict(kept)}")
    print(f"  beard collocations still reading 胡/須: "
          f"{len(beard_cue_hits(before))} before → {len(leftover)} after")

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
