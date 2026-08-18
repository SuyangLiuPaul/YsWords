#!/usr/bin/env python3
"""Restore 鹼 (lye) and 姪 (nephew) in the Traditional Bible — the two real
candidates in the tail of the character-inventory diff.

Eighteenth instalment of the converter-hole defect. It exists because the
inventory diff that drove instalments 2–17 was read only down to a count of 10,
and the tail below that line was never enumerated. When it finally was (while
fixing 書 10:3), the full diff turned out to be 109 characters rather than the
25 the queue had tabulated — and most of the tail is NOT a defect. 歎/嘆,
祕/秘, 蹟/跡, 鍊/鏈, 甦/蘇 all show the same zero-count signature purely
because both forms are live Traditional characters and two editions chose
differently. The signature is necessary, not sufficient.

These two are different, and each was checked at every position:

  鹼 / 堿, 6 positions   伯 9:30 用堿潔淨我的手      詩 107:34 使肥地變為堿地
                        箴 25:20 又如堿上倒醋       耶 2:22   你雖用堿
                        耶 17:6  無人居住的堿地     瑪 3:2    如漂布之人的堿
  姪 / 侄, 5 positions   創 12:5, 14:12, 14:14, 14:16 亞伯蘭的侄兒羅得 (Lot)
                        代下 22:8 亞哈謝的眾侄子

WHY THESE TWO AND NOT THE OTHER TAIL CHARACTERS
  Both have the exact-partition shape every applied instalment has had — ours
  holds ZERO of the Traditional form across 31,102 verses, the witness holds
  ZERO of ours, and the counts match exactly (6/6, 5/5).

  But the partition ALONE does not separate them from the tail characters left
  alone, and an earlier draft of this docstring got the discriminator wrong
  twice. It claimed 堿 is "a form no Traditional standard sets" — it is not;
  both 堿 and 侄 encode in Big5 and the MOE 異體字字典 lists 堿 under 鹼. And
  it filed 蹟/跡 and 鍊/鏈 as edition preferences, which they are not: ours
  reads 103 跡 / 0 蹟 and 60 鏈 / 0 鍊 where BOTH witnesses read 8/95 and 1/62,
  distinguishing 神蹟 from 痕跡 and 金鍊 from a 鏈. Our corpus collapsed those
  two distinctions exactly as it collapsed these.

  The discriminator that actually holds is narrower, and it is about what a
  reader is shown rather than about the characters in the abstract:

    * 跡 and 鏈 are standard Traditional spellings that read CORRECTLY for the
      words they carry. Restoring the distinction would be an improvement; the
      app is not currently printing anything false, so it is the user's call.
    * 堿 and 侄 are not what any published Traditional 和合本 prints at these
      eleven verses — both witnesses agree, against ours alone. 姪 is the
      Taiwan/HK standard for a sibling's child and 鹼 for lye.

  The converter's fingerprint is different for each, and both are visible from
  inside the repo. Our Simplified source reads 碱 at all six alkali positions,
  so there the converter DID rewrite the character and landed on 堿; it reads
  侄 at all five nephew positions, so there the converter did nothing at all.

TWO INDEPENDENT TRADITIONAL WITNESSES, AND THEY AGREE AT ALL ELEVEN POSITIONS
  * git blob 7a2dc43 — `assets/cuv-tr.json`, the plain 和合本 Traditional
    (耶和華) dropped at v1.4.5, a separately imported edition of the same base
    text. 6 鹼 / 0 堿, 5 姪 / 0 侄, in these eleven verses and no others. It
    is not versified identically to ours (31,103 verses against 31,102) and it
    writes 家裡 where ours and cmn-cu89t write 家裏, which is part of why it
    counts as an independent witness rather than a copy.
  * A published 新標點和合本 Traditional (ebible `cmn-cu89t`), fetched and
    counted 2026-08-18: 6 鹼 / 0 堿 / 0 碱 and 5 姪 / 0 侄, the same eleven
    verses. 「亞伯蘭將他妻子撒萊和姪兒羅得…」, 「我若用雪水洗身，用鹼潔淨我的手」.

  opencc corroborates the alkali independently (`碱` → `鹼` in s2t) but has NO
  opinion on the nephew: it maps neither 侄 → 姪 nor 姪 → 侄, in any of s2t,
  s2twp, t2tw, t2hk or t2s. That is worth stating plainly, because it is the
  one place this instalment is weaker than its predecessors — the nephew rests
  on the two Bible witnesses and on the standard, not on a converter oracle.
  It is also why the repo's own hand-authored Traditional is cited below: it
  writes 姪, and it was never converted by anything.

THE LEXICON MOVES WITH THE TEXT — 21 MORE
  `assets/strongs/*.json` hold a Simplified field and a Traditional one per
  entry, and the Traditional side was produced by opencc, which has no 侄 → 姪
  mapping. So all 21 Traditional 侄 came through untouched, in 14 entries, and
  every one of them is 侄子 or 侄女 — Lot (H3876, G3091), Bethuel (H1328),
  Iscah (H3252), Jonadab (H3082, H3122), Jonathan (H3083). A reader who taps
  羅得 on the Originals sheet would otherwise be shown a spelling the Bible
  text beside it no longer uses. The 崙 instalment set this precedent, editing
  155 verses and 88 lexicon fields together.

  There is no alkali in the lexicon at all (0 堿, 0 鹼, 0 碱), so nothing to do
  there.

WHAT WAS CHECKED AND IS NOT TOUCHED
  * `assets/family_tree.json` was already RIGHT and is the internal witness:
    its zh-Hant summaries write 亞伯拉罕的姪子 (Lot) and 她姪子暗蘭 (Jochebed),
    against 侄子 in the zh-Hans twins. Hand-authored, never converted.
  * `assets/cuvs-yhwh.json` and `assets/tagged/` are Simplified, where 侄 and
    碱 are correct. `assets/biblexg-v2-tr.json` holds none of the four.
  * The sermon assets hold none of the four.

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
LEXICONS = (ROOT / "assets/strongs/hebrew.json", ROOT / "assets/strongs/greek.json")
WITNESS_BLOB = "7a2dc43"

# (ours, correct, how many). Both counts are asserted in both directions, so a
# corpus that had drifted could not be swept on a stale expectation.
CLASSES = (("堿", "鹼", 6), ("侄", "姪", 5))

# Every position this repair is licensed to change, with the reading it must
# produce — read individually against both Traditional witnesses.
EXPECTED = {
    "018009030": "用鹼潔淨我的手",
    "019107034": "使肥地變為鹼地",
    "020025020": "又如鹼上倒醋",
    "024002022": "你雖用鹼、多用肥皂洗濯",
    "024017006": "無人居住的鹼地",
    "039003002": "如漂布之人的鹼",
    "001012005": "撒萊和姪兒羅得",
    "001014012": "亞伯蘭的姪兒羅得",
    "001014014": "亞伯蘭聽見他姪兒",
    "001014016": "連他姪兒羅得",
    "014022008": "亞哈謝的眾姪子",
}

# The lexicon substitution is licensed only where the character is the head of
# 侄子 / 侄女. Nothing else in these files may move.
LEX_SOURCE, LEX_TARGET = "侄", "姪"
LEX_FOLLOWERS = ("子", "女")
LEX_TOTAL = 21


def sequence(text: str, glyphs: str) -> str:
    return "".join(c for c in text if c in glyphs)


def fail(msg: str) -> int:
    print(f"  ✗ {msg} — refusing")
    return 1


def repair_verses(apply: bool) -> int:
    verses = json.loads(TR.read_text(encoding="utf-8"))
    witness = {
        v["id"]: v["text"]
        for v in json.loads(subprocess.run(
            ["git", "cat-file", "-p", WITNESS_BLOB], cwd=ROOT,
            capture_output=True, text=True, check=True).stdout)
    }

    before = "".join(v["text"] for v in verses)
    witness_all = "".join(witness.values())
    glyphs = "".join(a + b for a, b, _ in CLASSES)

    for ours_ch, right_ch, n in CLASSES:
        done = before.count(ours_ch) == 0 and before.count(right_ch) == n
        if not done and (before.count(ours_ch) != n or before.count(right_ch)):
            return fail(f"ours holds {before.count(ours_ch)} {ours_ch} / "
                        f"{before.count(right_ch)} {right_ch}, expected "
                        f"{n}/0 before the repair or 0/{n} after")
        if witness_all.count(right_ch) != n or witness_all.count(ours_ch):
            return fail(f"the witness holds {witness_all.count(right_ch)} "
                        f"{right_ch} / {witness_all.count(ours_ch)} {ours_ch}, "
                        f"expected {n}/0 — the partition this rests on is gone")

    changed: dict[str, str] = {}
    for v in verses:
        ours = sequence(v["text"], glyphs)
        if not ours:
            continue
        wit = witness.get(v["id"])
        if wit is None:
            return fail(f"{v['book']} {v['chapter']}:{v['verse']} has no "
                        f"witness verse to confirm against")
        theirs = sequence(wit, glyphs)
        if len(ours) != len(theirs):
            return fail(f"{v['book']} {v['chapter']}:{v['verse']} holds "
                        f"{len(ours)} of the glyphs against the witness's "
                        f"{len(theirs)}; the positions cannot be aligned")
        if ours == theirs:
            continue
        out, k = [], 0
        for ch in v["text"]:
            if ch in glyphs:
                want = theirs[k]
                pair = next(c for c in CLASSES if ch in c[:2])
                if ch == pair[0] and want == pair[1]:
                    out.append(want)
                elif ch == want:
                    out.append(ch)
                else:
                    return fail(f"{v['book']} {v['chapter']}:{v['verse']} reads "
                                f"{ch} where the witness reads {want}; this "
                                f"script does not decide that direction")
                k += 1
            else:
                out.append(ch)
        v["text"] = "".join(out)
        changed[v["id"]] = f"{v['book']} {v['chapter']}:{v['verse']}"

    if changed and set(changed) != set(EXPECTED):
        return fail(f"licensed for {len(EXPECTED)} positions but wanted to "
                    f"change {sorted(set(changed) ^ set(EXPECTED))}")

    after = "".join(v["text"] for v in verses)
    if len(before) != len(after):
        return fail("the corpus changed length")
    blind = str.maketrans({c: "\0" for c in glyphs})
    if before.translate(blind) != after.translate(blind):
        return fail("something other than the four glyphs changed")
    for ours_ch, right_ch, n in CLASSES:
        if after.count(ours_ch) or after.count(right_ch) != n:
            return fail(f"{after.count(ours_ch)} {ours_ch} / "
                        f"{after.count(right_ch)} {right_ch} after the repair, "
                        f"against the witness's 0/{n}")
    by_id = {v["id"]: v for v in verses}
    for vid, reading in EXPECTED.items():
        if reading not in by_id[vid]["text"]:
            return fail(f"{vid} does not read {reading}")
    for v in verses:
        wit = witness.get(v["id"])
        if wit is not None and sequence(v["text"], glyphs) != sequence(wit, glyphs):
            return fail(f"{v['book']} {v['chapter']}:{v['verse']} still "
                        f"disagrees with the witness")

    if changed:
        for vid, where in sorted(changed.items()):
            print(f"  {where}  {EXPECTED[vid]}")
        print(f"  {len(changed)} verses repaired in {TR.name}")
        if apply:
            TR.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
                          encoding="utf-8")
            print(f"  written → {TR.relative_to(ROOT)}")
    else:
        print(f"  {TR.name}: nothing to do — already 0 堿 / 6 鹼, 0 侄 / 5 姪")
    return 0


def repair_lexicons(apply: bool) -> int:
    total = 0
    for path in LEXICONS:
        raw = path.read_text(encoding="utf-8")
        entries = json.loads(raw)
        moved = 0
        for code, entry in entries.items():
            for field, value in list(entry.items()):
                if not isinstance(value, str) or not field.endswith("ZhTw"):
                    continue
                if LEX_SOURCE not in value:
                    continue
                out = []
                for i, ch in enumerate(value):
                    if ch != LEX_SOURCE:
                        out.append(ch)
                        continue
                    if value[i + 1:i + 2] not in LEX_FOLLOWERS:
                        return fail(f"{path.name} {code}.{field} writes "
                                    f"{LEX_SOURCE} outside "
                                    f"{'/'.join(LEX_SOURCE + f for f in LEX_FOLLOWERS)}"
                                    f" — that is not what this repair argues about")
                    out.append(LEX_TARGET)
                    moved += 1
                entry[field] = "".join(out)
        # The Simplified twin is the per-field witness: it must be untouched and
        # must still carry the same count, or the two sides have come apart.
        simplified = sum(
            v.count(LEX_SOURCE)
            for e in entries.values()
            for k, v in e.items()
            if isinstance(v, str) and k.endswith("Zh"))
        traditional = sum(
            v.count(LEX_TARGET)
            for e in entries.values()
            for k, v in e.items()
            if isinstance(v, str) and k.endswith("ZhTw"))
        if simplified != traditional:
            return fail(f"{path.name} has {simplified} Simplified {LEX_SOURCE} "
                        f"against {traditional} Traditional {LEX_TARGET}")
        if moved:
            after = json.dumps(entries, ensure_ascii=False, indent=2) + "\n"
            if len(after) != len(raw):
                return fail(f"{path.name} changed length")
            if after.replace(LEX_TARGET, LEX_SOURCE) != raw:
                return fail(f"{path.name}: something other than {LEX_SOURCE} "
                            f"changed")
            print(f"  {path.name}: {moved} → {LEX_TARGET}")
            if apply:
                path.write_text(after, encoding="utf-8")
                print(f"  written → {path.relative_to(ROOT)}")
        else:
            print(f"  {path.name}: nothing to do — {traditional} {LEX_TARGET}")
        total += moved
    if total and total != LEX_TOTAL:
        return fail(f"licensed for {LEX_TOTAL} lexicon substitutions, made {total}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    rc = repair_verses(args.apply) or repair_lexicons(args.apply)
    if rc == 0 and not args.apply:
        print("  dry run — nothing written")
    return rc


if __name__ == "__main__":
    sys.exit(main())
