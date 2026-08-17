#!/usr/bin/env python3
"""Restore 髮 (hair) in the Traditional CUV, where the converter wrote 發.

Third instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘 … or 髮. Simplified 发 collapses two
distinct traditional characters — 發 (to issue, send, break out) and 髮 (hair) —
and the converter resolved every one of them to 發. So the file reads
「你們的頭發也都被數過了」, 「白發是榮耀的冠冕」, 「他的頭發厚密累垂」.

WHY THIS IS NOT A BLANKET SUBSTITUTION, and could not be
  Unlike 淨/牆/餘, 發 is overwhelmingly CORRECT here: 1,375 occurrences of which
  only 88 are hair. 發怒, 打發, 所發的, 發芽, 一言不發 must not move. The claim
  is therefore not "發 is 髮" but "these 88 positions are 髮", and each has to be
  decided on its own evidence.

  A cue rule does not work either, and the trap is the same one that caught the
  classifier repair at 民數記 15:12. 頭發 looks decisive until you meet
  「我的骨頭發戰」 (詩篇 6:2) and 「在我裏頭發動」 (羅馬書 7:8) — 頭 ending the
  previous word, 發 starting the next. So the cue list is used only as an
  independent AUDIT of the result, never as the thing that decides.

THE WITNESS
  `assets/cuv-tr.json`, the plain 和合本 Traditional (耶和華, not 雅偉), a
  separately imported edition of the same base text, dropped from the repo at
  v1.4.5 and permanently readable as git blob 7a2dc43. It shares verse ids with
  ours and holds 88 髮 / 1,304 發 against our 0 / 1,375.

  The partition is what makes this a converter hole and not an editorial
  choice: ours has ZERO 髮 across 31,102 verses. A file that never once wrote
  the character did not decide against it.

  In all 80 verses where the witness has 髮, our count of 發 equals its count of
  發 plus 髮 — so the two editions agree on how many of the word there are, and
  only on the script differ. That per-verse equality is asserted below.

HOW EACH OCCURRENCE IS DECIDED
  Substitute 髮 into the surrounding context and look for it verbatim in the
  witness's verse; then do the same leaving 發 in place. An occurrence is taken
  as hair ONLY if the first matches and the second does not, so any position the
  witness cannot separate is refused rather than guessed. All 88 resolve —
  86 on a context window of 6–8 characters either side, 2 on the right side only
  (啟示錄 1:14 「頭與髮皆白」 and 9:8 「頭髮像女人的頭髮」, where the left
  context is the very ambiguity being resolved).

THE AUDIT THAT WOULD CATCH A MISSED ONE
  The witness can only vote on verses it shares wording with. So after
  substitution the whole corpus is swept for hair collocations that still read
  發 — 白發, 鬚發, 剃發, 發綹, 發辮, 發網, 毫發, 散發, 編發, 頭發 … — and the
  run is refused if any survives. Before the repair that sweep finds 88; after
  it, none.

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

SIMP, TRAD = "發", "髮"

# Collocations in which 發 can only be hair. Used to audit the result, never to
# decide it. 頭發 is deliberately absent: 骨頭發戰 / 裏頭發動 are the verb.
HAIR_CUES = (
    "白發", "鬚發", "剃發", "剪發", "散發", "編發", "辮頭發", "毫發", "美發",
    "發綹", "發辮", "發網", "發蒼", "發斑", "頭發", "毛發", "發頂", "發厚",
)
# …and the verb readings that make two of those cues fire anyway.
CUE_EXCEPTIONS = ("骨頭發", "裏頭發", "裡頭發")


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


def hair_cue_hits(corpus: str) -> list[str]:
    hits = []
    for cue in HAIR_CUES:
        start = 0
        while (j := corpus.find(cue, start)) != -1:
            start = j + 1
            window = corpus[max(0, j - 3):j + len(cue)]
            if any(x in window for x in CUE_EXCEPTIONS):
                continue
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
                  f"{text.count(SIMP)} 發 + {text.count(TRAD)} 髮, witness "
                  f"{wit.count(SIMP)} 發 + {wit.count(TRAD)} 髮 — refusing")
            return 1
        out = list(text)
        here = 0
        for i, ch in enumerate(text):
            if ch != SIMP:
                continue
            hair = confirm(text, i, TRAD, wit)
            verb = confirm(text, i, SIMP, wit)
            if hair and verb:
                print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the "
                      f"witness reads 「{text[max(0, i - 8):i + 8]}」 both ways "
                      f"— refusing")
                return 1
            if not hair:
                continue
            out[i] = TRAD
            here += 1
            changed += 1
            tiers[hair[:3]] += 1
            report.append(f"{v['book']} {v['chapter']}:{v['verse']}\t{hair}\t"
                          f"…{text[max(0, i - 8):i + 8]}…")
        if here + text.count(TRAD) != wit.count(TRAD):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — confirmed "
                  f"{here + text.count(TRAD)} hair, witness has "
                  f"{wit.count(TRAD)} — refusing")
            return 1
        v["text"] = "".join(out)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({SIMP: "\0", TRAD: "\0"})
    if before.translate(blind) != after.translate(blind):
        print("  ✗ something other than 發/髮 changed — refusing")
        return 1
    if after.count(SIMP) != before.count(SIMP) - changed:
        print("  ✗ the 發 count did not fall by exactly the number of "
              "substitutions — refusing")
        return 1
    if changed + before.count(TRAD) != expected:
        print(f"  ✗ {changed + before.count(TRAD)} 髮 against {expected} in "
              f"the witness — refusing")
        return 1
    leftover = hair_cue_hits(after)
    if leftover:
        print(f"  ✗ {len(leftover)} hair collocations still read 發 — refusing")
        for s in leftover[:10]:
            print(f"      …{s}…")
        return 1

    print(f"  {changed} substitutions 發→髮 "
          f"(witness has {expected} 髮; before: {before.count(SIMP)} 發, "
          f"{before.count(TRAD)} 髮 → after: {after.count(SIMP)} 發, "
          f"{after.count(TRAD)} 髮)")
    print(f"  confirmation: {dict(sorted(tiers.items()))}")
    print(f"  hair collocations still reading 發: "
          f"{len(hair_cue_hits(before))} before → {len(leftover)} after")

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
