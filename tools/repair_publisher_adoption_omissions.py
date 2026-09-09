#!/usr/bin/env python3
"""Restore words the `50dcc102` publisher-text adoption (2026-09-08) dropped
from 8 verses, confirmed by BOTH independent witnesses
(SeekSparks `cuvs-plus.json` and git blob `7a2dc43` = `assets/cuv-tr.json`)
AND the official 和合本 to be genuine omissions rather than the publisher's
own editorial choice.

This is the narrow "omitted verse text" carve-out from the P0 tier order,
not a general re-adoption of the pre-sync text. `50dcc102^` is one editorial
generation behind the publisher on ~14,718 verses (see
docs/cuv-yhwh-publisher-notes.md), so most of its differences from HEAD are
the publisher's own later edits and must NOT be reverted. Restoring wholesale
would undo those. Instead, for each of these 9 verses only, `difflib`'s
opcodes between HEAD and `50dcc102^` are read, and only the `insert` hunks
(words present pre-adoption and absent from HEAD) are spliced back in;
`delete` hunks (e.g. the quotation marks the 2026-09-08 punctuation thaw
added, which `50dcc102^` does not have) and `replace` hunks (e.g. 吗→么
character modernization) are left as HEAD has them.

Selection: of the 105 verses `tools/audit_publisher_adoption_drift.py`
classifies as genuine (non-cosmetic) drift, most are apparatus-notation
reformatting (a `<note:...>` becoming a `〔有古卷在此有...〕` wrapper with the
same words inside) or the publisher's own word ADDITIONS (葡萄园 at 士師記
15:5, 現在 at 15:18, 我請求 at 15:2, 大 at 撒母耳記下 21:2) — those are a
different accuracy question (extra words, not missing ones) and are filed
back to the queue rather than "fixed" here by deleting them, since this
hour's mandate is the missing-text carve-out specifically. These 8 are the
ones where HEAD is verifiably SHORTER than the pre-adoption text at a
position both witnesses corroborate:

  003008014 利未記  8:14   +上   (贖罪祭公牛的頭 → 頭上)
  007015013 士師記 15:13   +以坦 (將他從磐帶上去 → 從以坦磐帶上去)
  011015031 列王紀上 15:31  +上   (以色列諸王記 → 諸王記上)
  012013010 列王紀下 13:10  +王   (作以色列十六年 → 以色列王十六年)
  014018018 歷代志下 18:18  +上   (寶座 → 寶座上)
  024011002 耶利米書 11:2   +的   (這約話 → 這約的話)
  026010001 以西結書 10:1   +之中 (穹蒼 → 穹蒼之中)
  041015012 馬可福音 15:12  +樣   (那麼 → 那麼樣)

Confirmed against the official 和合本 via bible.fhl.net's public JSON API
(`/json/qb.php?chineses=<書>&chap=<n>&sec=<v>&version=unv&gb=1` — the
`read.php` HTML endpoint used by earlier passes is login-walled, but this
JSON endpoint is not) as well as both witnesses: every restored word above
matches the official text exactly.

**約伯記 10:20 (`018010020`) was excluded after a refuter caught a real
bug in an earlier draft of this list.** HEAD is not missing the second
half of that verse — the publisher's adoption *fixed a stale versification
split*: `50dcc102^` (and both witnesses, which are stale here) carries the
whole two-sentence verse in 10:20 and a placeholder `見上節`/`见上节`
("see previous verse") in 10:21; HEAD correctly holds the first sentence in
10:20 and the second sentence, on its own, in 10:21. Restoring the "missing"
half into 10:20 would have duplicated it, since 10:21 already has it. The
tell was the size of the diff (30 characters, an order of magnitude above
the other 8's 1-3) — checked here by reading the sibling verse id in both
`50dcc102^` and HEAD, not by fhl.net, which could not have caught this: the
defect was a wrong verse *boundary* in the old data, not a wrong reading in
either source.
"""
import json
import subprocess
import sys
from difflib import SequenceMatcher
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PRE_ADOPTION_REV = "50dcc102^"

VERSE_IDS = [
    "003008014",
    "007015013",
    "011015031",
    "012013010",
    "014018018",
    "024011002",
    "026010001",
    "041015012",
]


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_from_git(rev, path):
    raw = subprocess.run(
        ["git", "show", f"{rev}:{path}"], cwd=REPO, capture_output=True, check=True
    ).stdout.decode("utf-8")
    return json.loads(raw)


def restore_insertions(new_text, old_text):
    """Splice back substrings present in `old_text` and absent from
    `new_text`, leaving every other difference (things `new_text` has that
    `old_text` does not — added quotes, modernized characters) exactly as
    `new_text` has it. Opcodes partition both strings fully and in order, so
    each one contributes exactly the side that should survive."""
    sm = SequenceMatcher(None, new_text, old_text, autojunk=False)
    out = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "insert":
            out.append(old_text[j1:j2])
        else:
            out.append(new_text[i1:i2])
    return "".join(out)


def repair_file(asset_path):
    verses = load(asset_path)
    old_by_id = {r["id"]: r for r in load_from_git(PRE_ADOPTION_REV, f"assets/{asset_path.name}")}
    changed = []
    for v in verses:
        if v["id"] not in VERSE_IDS:
            continue
        old_text = old_by_id[v["id"]]["text"]
        fixed = restore_insertions(v["text"], old_text)
        if fixed != v["text"]:
            changed.append((v["id"], v["text"], fixed))
            v["text"] = fixed
    with open(asset_path, "w", encoding="utf-8") as f:
        # indent=2 + a trailing newline reproduces the asset byte for byte
        # everywhere except the lines actually repaired.
        json.dump(verses, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return changed


def main():
    for name in ("cuvs-yhwh.json", "cuvs-yhwh-tr.json"):
        path = REPO / "assets" / name
        changed = repair_file(path)
        print(f"=== {name}: {len(changed)} verses repaired ===")
        for vid, before, after in changed:
            print(f"{vid}")
            print(f"  before: {before}")
            print(f"  after : {after}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
