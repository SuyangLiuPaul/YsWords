#!/usr/bin/env python3
"""Restore 于 in Jushab-hesed's name — 代上 3:20 in the Traditional Bible.

Nineteenth instalment of the converter-hole defect, one substitution wide, and
the second one to reach a proper NAME rather than a common word.

  ours     米書蘭的兒子是哈舒巴、阿黑、比利家、哈撒底、於沙希悉，共五人。
  correct  米書蘭的兒子是哈舒巴、阿黑、比利家、哈撒底、于沙希悉，共五人。

THE MECHANISM, stated correctly — it is NOT opencc
  Simplified merged the preposition 於 into 于, so any s2t step has to expand
  one Simplified character back into two Traditional ones, and this corpus's
  converter did it with a blanket per-character map: our Simplified holds
  1,388 于 and 0 於, our Traditional holds 1,388 於 and 0 于. Unconditional,
  and therefore blind to the one position in 31,102 verses where the syllable
  is a name and not a function word. It is right 1,387 times and wrong once.

  An earlier draft of this docstring blamed opencc and the refuter broke it.
  `tools/fix_traditional_conversion.py` already established that these assets
  were never produced by opencc — it disagrees with them in ~46% of verses
  (喫/吃, 爲/為, quote marks), and it gets 船隻 RIGHT where this corpus got it
  wrong. So `echo 于沙希悉 | opencc -c s2t` printing 於沙希悉 is a useful
  demonstration that a naive expansion makes exactly this mistake, and is NOT
  evidence about what produced our file. The 1,388/1,388 identity is.

WHAT EACH PIECE OF EVIDENCE ACTUALLY PROVES
  The Simplified sources are logically NULL on 于-versus-於, because Simplified
  merged the two and could not distinguish them even in principle. They are
  cited for the one thing they do settle, which is the load-bearing thing:

  * `assets/tagged/cuvs-yhwh/1_chronicles.json` tags the token 「于沙希悉，」
    as H3142 — יוּשַׁב חֶסֶד, "Jushab-Chesed, an Israelite". That is what makes
    this string a NAME rather than a clause containing a preposition, and it
    comes from inside the repo.

  Which Traditional character the name takes rests on the two Traditional
  witnesses, and they should be counted as ONE textual family, not two
  independent lines — both set the 新標點 name separator, 于沙‧希悉, which
  ours does not:

  * git blob 7a2dc43 — `assets/cuv-tr.json`, dropped at v1.4.5. Its single
    于 in 31,103 verses is this name.
  * A published 新標點和合本 (ebible `cmn-cu89t`), counted 2026-08-18 over all
    66 books / 1,189 chapters: again exactly ONE 于 in the whole Bible, here.

  They differ in normalisation (blob 裡/毘 against cu89t 裏/毗), so they are
  not the same file, but the shared ‧ convention means the claim is "no
  published Traditional CUV on this machine spells it 於", not "two unrelated
  editions independently agree".

  That is still decisive, because 於 in modern Traditional is essentially only
  the preposition. Printing 於沙希悉 spells a man's name with a grammatical
  particle — unlike the 蹟/跡 and 鍊/鏈 cases deliberately left alone, where
  our spelling is one a published edition legitimately sets.

THE FIX IS COMPLETE — there is no second position
  A full per-verse 于/於 sequence diff against the blob witness returns exactly
  two disagreements: this one, and 尼 1:2, where our edition reads 「我問他們
  關於那些…和關於耶路撒冷的光景」 against the witness's shorter clause with no
  關於 at all. That is an edition difference in the wording, not a character
  choice, and our Simplified twin has the same 关于 — so nothing to do.

  The name occurs nowhere else: not in `assets/strongs/*.json` (H3142's
  Traditional gloss reads 「所羅巴伯的孫子, 米書蘭的兒子」 and never spells
  it), and not in `assets/biblexg-v2-tr.json`, which is New Testament only.

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
SC = ROOT / "assets/cuvs-yhwh.json"
TAGGED = ROOT / "assets/tagged/cuvs-yhwh/1_chronicles.json"
WITNESS_BLOB = "7a2dc43"

VERSE_ID = "013003020"
WRONG, RIGHT = "於沙希悉", "于沙希悉"
STRONGS = "H3142"


def fail(msg: str) -> int:
    print(f"  ✗ {msg} — refusing")
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    verses = json.loads(TR.read_text(encoding="utf-8"))
    by_id = {v["id"]: v for v in verses}
    if VERSE_ID not in by_id:
        return fail(f"{VERSE_ID} is not in {TR.name}")
    verse = by_id[VERSE_ID]

    # The tagged corpus is what establishes this is a name and not a clause.
    tagged = json.loads(TAGGED.read_text(encoding="utf-8"))
    tokens = [t for t in json.dumps(tagged, ensure_ascii=False).split("{")
              if RIGHT in t]
    if not any(STRONGS in t for t in tokens):
        return fail(f"the tagged corpus no longer tags {RIGHT} as {STRONGS} — "
                    f"the argument that this is a name is gone")

    simplified = {v["id"]: v["text"] for v in json.loads(SC.read_text(encoding="utf-8"))}
    if RIGHT not in simplified.get(VERSE_ID, ""):
        return fail(f"the Simplified twin does not read {RIGHT} at {VERSE_ID}")

    witness = "".join(
        v["text"] for v in json.loads(subprocess.run(
            ["git", "cat-file", "-p", WITNESS_BLOB], cwd=ROOT,
            capture_output=True, text=True, check=True).stdout))
    if witness.count("于") != 1:
        return fail(f"the witness holds {witness.count('于')} 于, expected 1 — "
                    f"the partition this rests on is gone")

    before = "".join(v["text"] for v in verses)
    if before.count("于") == 1 and WRONG not in before:
        print(f"  {TR.name}: nothing to do — already reads {RIGHT}")
        return 0
    if before.count("于") or before.count(WRONG) != 1:
        return fail(f"ours holds {before.count('于')} 于 and "
                    f"{before.count(WRONG)} {WRONG}, expected 0 and 1")

    verse["text"] = verse["text"].replace(WRONG, RIGHT)

    after = "".join(v["text"] for v in verses)
    if len(before) != len(after):
        return fail("the corpus changed length")
    if before.replace(WRONG, RIGHT) != after:
        return fail("something other than the name changed")
    if after.count("于") != 1 or WRONG in after:
        return fail(f"{after.count('于')} 于 after the repair, expected 1")

    print(f"  {verse['book']} {verse['chapter']}:{verse['verse']}  {WRONG} → {RIGHT}")
    if args.apply:
        TR.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
        print(f"  written → {TR.relative_to(ROOT)}")
    else:
        print("  (dry run — pass --apply to write)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
