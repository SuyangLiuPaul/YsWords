#!/usr/bin/env python3
"""Restore 罈 (jar) in the Traditional CUV, where the converter wrote 壇.

Sixth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵 … or 罈. Simplified
坛 collapses two distinct traditional characters — 壇 (altar, platform) and 罈
(an earthenware jar) — and the converter resolved every one of them to 壇. So the
widow's jar of meal in the Elijah narrative is an *altar*: 列王紀上 17:12 reads
「壇內只有一把麵」, and 17:14 / 17:16 「壇內的麵必不減少／果不減少」. 耶利米書
13:12 turns 「各罈都要盛滿了酒」 into altars filled with wine, and 48:12 breaks
Moab's 壇子 rather than its 罈子.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Ours has 613 壇 and ZERO 罈 across 31,102 verses. The witness has 607 壇 and 6
  罈, and 613 = 607 + 6 exactly. The corpus arithmetic partitions on its own: a
  file that never once wrote the character did not choose against it.

WHY THIS IS STILL NOT A BLANKET SUBSTITUTION
  607 of the 613 are the genuine altar — 築壇, 祭壇, 香壇, 燔祭壇, 邱壇, 燒在壇上.
  This is the 發/髮 shape, not the 淨/牆 shape: the claim is not "壇 is 罈" but
  "these 6 positions are 罈", and each is decided against the witness on its own.

  A cue rule would have been wrong here too, which is the reason the check below
  spells its cues out in full. 「各壇」 occurs 4 times; only the two in 耶利米書
  13:12 are jars — 歷代志下 33:15 「所築的各壇都拆毀」 and 阿摩司書 2:8
  「在各壇旁鋪人所當的衣服」 are altars, and a repair keyed on 各壇 would have
  desecrated both.

THE SWAP THAT CANNOT HIDE HERE
  For 麵 the per-verse count check could in principle be balanced by converting a
  face position and missing a flour one in the same verse, so the one verse
  holding both had to be read. That case does not exist here at all: none of the
  five verses contains a genuine altar, so every 壇 in them is a jar and there is
  nothing for a swap to trade against.

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * KJV: 王上 17:12, 17:14, 17:16 "the barrel of meal"; 耶 13:12 "Every bottle
    shall be filled with wine" (twice); 耶 48:12 "break their bottles". Sweeping
    the whole KJV for barrel / bottle / cruse / pitcher / jar turns up exactly
    one further verse whose CUV counterpart holds a 壇 — 王上 18:33, where Elijah
    fills four 桶 with water and pours them on an altar that really is an altar.
    So the witness has not missed a jar.
  * 新譯本 Traditional (git blob 57c4686), a different translation: it words all
    five without the noun (缸裡 / 酒瓶 / 酒缸), which is an independent vote that
    the passages are about vessels rather than altars. Its single 罈 is
    約翰福音 19:29, where the CUV reads 器皿 and has no 壇 to repair.

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

SIMP, TRAD = "壇", "罈"

# Readings in which 壇 can only be a jar. Written out at full phrase length
# because the short forms fire on genuine altars (see the note above about 各壇).
# Used to audit the result, never to decide it.
JAR_CUES = ("壇內只有", "壇內的麵", "各壇都要盛滿", "的壇子")


def confirm(text: str, i: int, ch: str, witness: str) -> str | None:
    """Strongest witness evidence for reading position `i` as `ch`, or None."""
    for w in (8, 6, 4, 3, 2, 1):
        if text[max(0, i - w):i] + ch + text[i + 1:i + 1 + w] in witness:
            return f"ctx{w}"
    for w in (4, 3, 2, 1):
        if i >= w and text[i - w:i] + ch in witness:
            return f"left{w}"
        if len(text) >= i + 1 + w and ch + text[i + 1:i + 1 + w] in witness:
            return f"right{w}"
    return None


def jar_cue_hits(corpus: str) -> list[str]:
    hits = []
    for cue in JAR_CUES:
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
    expected = sum(t.count(TRAD) for t in witness.values())
    tiers: collections.Counter[str] = collections.Counter()
    report: list[str] = []
    changed = 0

    for v in verses:
        text = v["text"]
        wit = witness.get(v["id"], "")
        if TRAD not in wit:
            continue
        # The two editions must agree on how many of the word this verse holds,
        # otherwise the witness is not talking about the same sentence. Counted
        # over both forms so the check still holds once the repair is applied.
        if (text.count(SIMP) + text.count(TRAD)
                != wit.count(SIMP) + wit.count(TRAD)):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — ours has "
                  f"{text.count(SIMP)} 壇 + {text.count(TRAD)} 罈, witness "
                  f"{wit.count(SIMP)} 壇 + {wit.count(TRAD)} 罈 — refusing")
            return 1
        out = list(text)
        here = 0
        for i, ch in enumerate(text):
            if ch != SIMP:
                continue
            jar = confirm(text, i, TRAD, wit)
            altar = confirm(text, i, SIMP, wit)
            if jar and altar:
                print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the "
                      f"witness reads 「{text[max(0, i - 8):i + 8]}」 both ways "
                      f"— refusing")
                return 1
            if not jar:
                continue
            out[i] = TRAD
            here += 1
            changed += 1
            tiers[jar[:3]] += 1
            report.append(f"{v['book']} {v['chapter']}:{v['verse']}\t{jar}\t"
                          f"…{text[max(0, i - 8):i + 8]}…")
        if here + text.count(TRAD) != wit.count(TRAD):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — confirmed "
                  f"{here + text.count(TRAD)} jars, witness has "
                  f"{wit.count(TRAD)} — refusing")
            return 1
        v["text"] = "".join(out)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({SIMP: "\0", TRAD: "\0"})
    if before.translate(blind) != after.translate(blind):
        print("  ✗ something other than 壇/罈 changed — refusing")
        return 1
    if after.count(SIMP) != before.count(SIMP) - changed:
        print("  ✗ the 壇 count did not fall by exactly the number of "
              "substitutions — refusing")
        return 1
    if changed + before.count(TRAD) != expected:
        print(f"  ✗ {changed + before.count(TRAD)} 罈 against {expected} in "
              f"the witness — refusing")
        return 1
    leftover = jar_cue_hits(after)
    if leftover:
        print(f"  ✗ {len(leftover)} jar readings still set 壇 — refusing")
        for s in leftover[:10]:
            print(f"      …{s}…")
        return 1

    print(f"  {changed} substitutions 壇→罈 "
          f"(witness has {expected} 罈; before: {before.count(SIMP)} 壇, "
          f"{before.count(TRAD)} 罈 → after: {after.count(SIMP)} 壇, "
          f"{after.count(TRAD)} 罈)")
    print(f"  confirmation: {dict(sorted(tiers.items()))}")
    print(f"  jar readings still setting 壇: "
          f"{len(jar_cue_hits(before))} before → {len(leftover)} after")

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
