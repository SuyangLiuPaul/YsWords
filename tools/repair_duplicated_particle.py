#!/usr/bin/env python3
"""Two verses print a word twice: 傳道書 7:1 and 歷代志上 15:3.

    傳道書 7:1    名譽強如美好**的的**膏油
    歷代志上 15:3  大衛招聚以色列**眾人眾人**到耶路撒冷

Neither is a variant reading. 的 is a grammatical particle with no reduplicated
reading, and 招聚以色列眾人 renders ויקהל דויד את־כל־ישראל, which says "all
Israel" once. In both cases the repair only deletes a repetition that is
already there twice — no character is invented, which is the direction this
repo is allowed to move on its own.

**They were found by two different checks, and neither check could see the
other's verse.** That is the part worth remembering:

  傳道書 7:1 came from `tools/audit_inserted_characters.py`, which reports
  where we read more than BOTH external witnesses.

  歷代志上 15:3 is invisible to that audit, because witness A shares the
  defect — it reads 眾人眾人 too. Two imports agreeing means less than it
  looks like when they descend from a common ancestor, which is the same
  lesson 創世記 39:22 and 41:30 taught in the opposite direction. It was
  caught instead by **our own tagged corpus**, a third witness that is
  internal to this repo and that the external audit never consults:
  `assets/tagged/cuvs-yhwh/1_chronicles.json` "15:3" holds a single run
  {"w": "以色列众人", "s": "H3605", "i": ["H853","H3478"]} — 眾人 once, tagged
  H3605 כֹּל. So the tagged corpus needs no repair there; only the two
  running-text files do.

**Which of the two 的 to drop was decided by counting, and the first answer
was wrong.** The tagged corpus writes the genitive 的 at the head of the
following run 20,060 times and at the tail of the preceding one 11,649 — a
63/37 tendency, not a convention, and 以賽亞書 runs the other way (430 / 914).
So the aggregate settles nothing. What settles it is the token itself: of the
14 places the corpus splits a run at 美好, **12 keep 美好的 together** and only
申命記 8:12 and 箴言 13:15 put the particle on the noun. 傳道書 4:9 — same
book, same lemma H2896 — reads {"w":"美好的"},{"w":"果效。"}. Hence the run
that loses the particle is 的膏油, leaving 美好的 + 膏油.

    python3 tools/repair_duplicated_particle.py          # dry run
    python3 tools/repair_duplicated_particle.py --apply
"""
import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SIMPLIFIED = REPO / "assets/cuvs-yhwh.json"
TRADITIONAL = REPO / "assets/cuvs-yhwh-tr.json"

# id, reference, (simplified before, after), (traditional before, after)
REPAIRS = [
    ("021007001", "傳道書 7:1",
     ("美好的的膏油", "美好的膏油"), ("美好的的膏油", "美好的膏油")),
    ("013015003", "歷代志上 15:3",
     ("以色列众人众人到", "以色列众人到"), ("以色列眾人眾人到", "以色列眾人到")),
]

# Only 傳道書 7:1 reaches the tagged corpus; 歷代志上 15:3 is already correct
# there, and that is precisely how it was found.
# slug, reference, run text before, run text after
TAGGED_REPAIRS = [
    ("ecclesiastes", "7:1", "的膏油；", "膏油；"),
]


def repair_running(path, index, apply):
    verses = json.loads(path.read_text(encoding="utf-8"))
    by_id = {v["id"]: v for v in verses}
    changed = 0
    for vid, ref, *forms in REPAIRS:
        before, after = forms[index]
        verse = by_id[vid]
        text = verse["text"]
        if before not in text:
            if after in text:
                print(f"  {ref} already repaired")
                continue
            print(f"  FAIL {ref}: {before!r} not present", file=sys.stderr)
            return None
        if text.count(before) != 1:
            print(f"  FAIL {ref}: {before!r} occurs {text.count(before)}x", file=sys.stderr)
            return None
        new = text.replace(before, after)
        # The only permitted edit is deleting the repetition. Guarding the
        # exact length keeps a mistyped pair from quietly rewriting a verse.
        if len(new) != len(text) - (len(before) - len(after)):
            print(f"  FAIL {ref}: edit is not a pure deletion", file=sys.stderr)
            return None
        print(f"  {ref}: {before} → {after}")
        verse["text"] = new
        changed += 1
    if apply and changed:
        path.write_text(
            json.dumps(verses, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    return changed


def repair_tagged(apply):
    changed = 0
    for slug, ref, before, after in TAGGED_REPAIRS:
        path = REPO / f"assets/tagged/cuvs-yhwh/{slug}.json"
        book = json.loads(path.read_text(encoding="utf-8"))
        runs = book[ref]
        hits = [i for i, r in enumerate(runs) if r.get("w") == before]
        if not hits:
            if any(r.get("w") == after for r in runs):
                print(f"  {slug} {ref} already repaired")
                continue
            print(f"  FAIL {slug} {ref}: no run reads {before!r}", file=sys.stderr)
            return None
        if len(hits) != 1:
            print(f"  FAIL {slug} {ref}: {before!r} matches {len(hits)} runs", file=sys.stderr)
            return None
        # Every other field of the run — Strong's number, the `i` and `g`
        # arrays — survives untouched. Rebuilding a run from scratch is how an
        # earlier repair silently dropped parsing data.
        print(f"  {slug} {ref}: {before} → {after}")
        runs[hits[0]]["w"] = after
        changed += 1
        if apply:
            path.write_text(
                json.dumps(book, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
    return changed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    print("Simplified:")
    s = repair_running(SIMPLIFIED, 0, args.apply)
    print("Traditional:")
    t = repair_running(TRADITIONAL, 1, args.apply)
    print("Tagged:")
    g = repair_tagged(args.apply)
    if None in (s, t, g):
        return 1
    print(f"{s + t + g} edits" if args.apply else "dry run — pass --apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())
