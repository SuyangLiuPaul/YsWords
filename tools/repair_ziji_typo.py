#!/usr/bin/env python3
"""Repair 自已 → 自己 in the four places it survives OUTSIDE the verse text.

The verse assets were cleaned by tools/repair_cuv_typo_corruptions.py, which
deliberately left these queued: their provenance is different. Two are sermon
transcripts, two are Strong's glosses, and neither is scripture — so the
argument that repairs them is not the one that repaired the CUV.

WHAT IS BEING FIXED, all four in full
  assets/sermons/zh-CN/021.txt  「所以我對自已說，不，我要追求榮譽」
  assets/sermons/zh-CN/029.txt  「我真的是在對自已說話」
  assets/strongs/greek.json   G3962 「並且不再害怕自已是罪人」
  assets/strongs/hebrew.json  H2616 「(Hithpael) 對自已仁慈」
  …and the zh-TW twin of each sermon, and the defZhTw twin of each gloss.
  Eight string positions, four readings, six files.

WHY THIS IS A REPAIR AND NOT AN EDIT
  自已 is not a word. 已 is the adverb "already"; the reflexive pronoun is 自己
  with 己. Nothing in Chinese takes 自已 as a unit, so there is no reading of
  「對自已說」 or 「對自已仁慈」 to preserve.

  The corpus ratio settles it without any outside source: the zh-CN and zh-TW
  transcripts write 自己 10,875 times against these 4, and the same two
  transcripts write it 39 and 26 times each. greek.json is 210:2 and
  hebrew.json is 454:2.

  Both glosses are inherited, not introduced here: the upstream CBOL source
  (`.cache/originals/cbol-greek.json` entry 03962, `cbol-hebrew.json` entry
  02616) carries the identical typo. We are restoring what the lexicon means,
  not overruling it.

THE TRAP, AND WHY THIS SCRIPT IS ANCHORED RATHER THAN GLOBAL
  A blanket 自已 → 自己 over the same upstream source would corrupt 21 further
  strings. CBOL's etymology formula is 「源自已不使用的字根」 — "derived from a
  root no longer in use" — which is 源自 + 已不使用 and entirely correct. It
  runs 4 times in cbol-greek.json (3 as 已不使用, once as 已廢棄不用) and 17
  times in cbol-hebrew.json. Neither file's etymology field was imported into
  our assets — `assets/strongs/*.json` hold zero 源自已 and, just as important,
  zero over-corrected 源自己 — so our files are clean of it today. The next
  person to run a regex over the lexicon will meet it.

  So every substitution below is anchored to its full surrounding phrase and
  must match exactly once. The script refuses on any drift.

Idempotent: re-running after a successful pass is a no-op.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# (path, bad phrase, good phrase) — Simplified and Traditional spelt out in
# full rather than derived, so a converter change cannot silently widen this.
SERMON_EDITS = [
    ("assets/sermons/zh-CN/021.txt", "所以我对自已说", "所以我对自己说"),
    ("assets/sermons/zh-TW/021.txt", "所以我對自已說", "所以我對自己說"),
    ("assets/sermons/zh-CN/029.txt", "我真的是在对自已说话", "我真的是在对自己说话"),
    ("assets/sermons/zh-TW/029.txt", "我真的是在對自已說話", "我真的是在對自己說話"),
]

# (path, strong's id, fields, bad phrase, good phrase). Substitution is done on
# the raw JSON text so the file's formatting is untouched — re-serialising a
# 4.6 MB lexicon to change eight characters would bury the fix in a whole-file
# diff. The parse afterwards proves the phrase sat where we said it did.
STRONGS_EDITS = [
    (
        "assets/strongs/greek.json",
        "G3962",
        ("defZh", "defZhTw"),
        "不再害怕自已是罪人",
        "不再害怕自己是罪人",
    ),
    (
        "assets/strongs/hebrew.json",
        "H2616",
        ("defZh",),
        "对自已仁慈",
        "对自己仁慈",
    ),
    (
        "assets/strongs/hebrew.json",
        "H2616",
        ("defZhTw",),
        "對自已仁慈",
        "對自己仁慈",
    ),
]


def fail(msg):
    print(f"REFUSING: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    changed = 0
    already = 0

    for rel, bad, good in SERMON_EDITS:
        path = ROOT / rel
        text = path.read_text(encoding="utf-8")
        if bad not in text:
            if good in text:
                already += 1
                continue
            fail(f"{rel} holds neither {bad!r} nor {good!r}")
        if text.count(bad) != 1:
            fail(f"{rel} holds {text.count(bad)} copies of {bad!r}, expected 1")
        text = text.replace(bad, good)
        if "自已" in text:
            fail(f"{rel} still holds 自已 after the anchored substitution")
        path.write_text(text, encoding="utf-8")
        changed += 1

    for rel, sid, fields, bad, good in STRONGS_EDITS:
        path = ROOT / rel
        raw = path.read_text(encoding="utf-8")
        data = json.loads(raw)
        entry = data.get(sid)
        if entry is None:
            fail(f"{rel} has no entry {sid}")

        pending = [f for f in fields if bad in (entry.get(f) or "")]
        if not pending:
            if all(good in (entry.get(f) or "") for f in fields):
                already += len(fields)
                continue
            fail(f"{rel} {sid} holds neither {bad!r} nor {good!r} in {fields}")
        if len(pending) != len(fields):
            fail(f"{rel} {sid}: only {pending} of {fields} hold {bad!r}")
        if raw.count(bad) != len(fields):
            fail(
                f"{rel} holds {raw.count(bad)} copies of {bad!r} but only "
                f"{len(fields)} belong to {sid} — an unanchored replace would "
                f"touch something else"
            )

        raw = raw.replace(bad, good)
        after = json.loads(raw)
        for f in fields:
            if bad in after[sid][f] or good not in after[sid][f]:
                fail(f"{rel} {sid}.{f} did not take the substitution")
        path.write_text(raw, encoding="utf-8")
        changed += len(fields)

    for rel in {e[0] for e in SERMON_EDITS} | {e[0] for e in STRONGS_EDITS}:
        remaining = (ROOT / rel).read_text(encoding="utf-8").count("自已")
        if remaining:
            fail(f"{rel} still holds {remaining} 自已")

    print(f"{changed} substitutions, {already} already correct")


if __name__ == "__main__":
    main()
