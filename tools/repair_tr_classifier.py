#!/usr/bin/env python3
"""Restore the classifier 隻 to the Traditional CUV, which never had it.

`assets/cuvs-yhwh-tr.json` is a conversion of `assets/cuvs-yhwh.json`, and the
converter that produced it had no mapping for 只 → 隻 at all: the file contains
**zero** occurrences of 隻 in 31,102 verses. So 「他施的船只」 (以賽亞書 2:16),
「一只公牛」, 「兩只眼」 and 「那幾只羊」 all print the simplified adverb where
traditional Chinese writes the classifier. Not a variant preference — a hole.

WHY NOT JUST RE-RUN OPENCC OVER THE WHOLE FILE
  opencc s2t disagrees with our Traditional in 27,361 positions, and in the
  overwhelming majority OURS is right: it prefers 爲/“”/着/衆/喫/羣 where this
  edition sets 為/「」/著/眾/吃/群, and it rewrites 海裏 to 海里 and the place
  name 迦斐托 to 迦斐託. Re-converting would trade one defect for thousands.
  So opencc is used here only as an ORACLE for one character, and every one of
  its 543 verdicts on that character was read before being accepted.

WHAT THE REVIEW FOUND — the reason this is a list and not a regex
  * 541 of opencc's 543 are genuine classifiers, and every one is preceded by a
    numeral, 每, 那, 幾 or 船. That invariant is asserted below.
  * 2 are WRONG and are excluded by reference. Both are the adverb "only":
    詩篇 17:14 「脫離那只在今生有福分的世人」 and
    以賽亞書 29:17 「不是只有一點點時候嗎」.
    Applying opencc unreviewed would have introduced two new defects.
  * 7 classifiers opencc MISSES, because its phrase table has 七百只 but not
    七千只. Listed explicitly, each with the phrase it must match.

THE WITNESS THAT SETTLED IT — and where to find it again
  `assets/cuv-tr.json`, the plain 和合本 Traditional (耶和華, not 雅偉), was a
  separately imported edition of the same base text. It was dropped from the
  repo at v1.4.5, so read it from git:  git cat-file -p 7a2dc43  (equivalently
  `69307c7^:assets/cuv-tr.json`). It keeps the classifier — 548 隻 / 670 只 —
  which is what proves 隻=0 here is a converter hole and not an editorial
  choice. Comparing the 只/隻 sequence of every verse against it leaves exactly
  six disagreements, and all six are explained: four are Mark 9:43-46, where
  this edition splits vv.44/46 into 「有些抄本」 notes and the witness does not;
  one is a note wording at 路加福音 11:2 (「有古卷只作」, an adverb); and the
  sixth was a real miss, below.

  民數記 15:12 「按著只數都要這樣辦理」 — 隻數 is a head count of animals, a
  noun built from the classifier. The cue rule could not catch it because the
  character in front is 著, and opencc's phrase table does not carry 隻數
  either. It is the one place a classifier hides without a numeral in front of
  it, and only a whole-corpus comparison against another edition found it.

Dry-run by default; --apply writes. Re-running after a successful --apply is
safe: substitutions already present are skipped, not refused.
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

# opencc says 隻 and it is wrong — these are the adverb 只.
EXCLUDE = {("詩篇", "17", "14"), ("以賽亞書", "29", "17")}

# opencc says 只 and it is wrong — classifiers its phrase table does not carry.
# (book, chapter, verse, phrase-as-it-stands, phrase-as-it-should-be)
ADD = [
    # Not a numeral in front — 隻數 is a head count. See the docstring.
    ("民數記", "15", "12", "按著只數", "按著隻數"),
    ("民數記", "31", "32", "六十七萬五千只", "六十七萬五千隻"),
    ("撒母耳記上", "17", "28", "那幾只羊", "那幾隻羊"),
    ("歷代志下", "15", "11", "羊七千只獻給", "羊七千隻獻給"),
    ("歷代志下", "30", "24", "羊七千只為祭物", "羊七千隻為祭物"),
    ("歷代志下", "35", "7", "山羊羔三萬只", "山羊羔三萬隻"),
    ("歷代志下", "35", "9", "羊羔五千只", "羊羔五千隻"),
]

# A classifier is always preceded by one of these. Asserted, not assumed.
CUES = set("一二兩三四五六七八九十百千萬幾數每那這船")

# The adverb, which must survive untouched in exactly the same numbers.
ADVERBS = ["只是", "只有", "只要", "只怕", "只因", "只當", "只可", "只等",
           "只求", "只剩", "只用", "只在", "不只", "只隨", "只搭", "只尋"]


def key(v: dict) -> tuple[str, str, str]:
    return (v["book"], str(v["chapter"]), str(v["verse"]))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--report", default="")
    args = ap.parse_args()

    tr = json.loads(TR.read_text(encoding="utf-8"))
    sc = json.loads(SC.read_text(encoding="utf-8"))
    if len(tr) != len(sc):
        print(f"  ✗ {len(tr)} traditional verses vs {len(sc)} simplified — "
              "cannot align, refusing")
        return 1

    before_blob = "".join(v["text"] for v in tr)
    if "隻" in before_blob:
        print("  note: the file already contains 隻 — this tool assumes it does "
              "not, re-read the review before trusting the counts")

    src = [v["text"] for v in sc]
    conv = subprocess.run(["opencc", "-c", "s2t"], input="\n".join(src),
                          capture_output=True, text=True, check=True
                          ).stdout.split("\n")
    if len(conv) != len(src):
        print("  ✗ opencc returned a different number of lines — refusing")
        return 1

    report: list[str] = []
    from_oracle = skipped_len = 0
    for v, c in zip(tr, conv):
        ours = v["text"]
        if key(v) in EXCLUDE:
            continue
        if len(ours) != len(c):
            skipped_len += 1
            continue
        out = []
        for i, (x, y) in enumerate(zip(ours, c)):
            if x == "只" and y == "隻":
                if i == 0 or ours[i - 1] not in CUES:
                    print(f"  ✗ {key(v)}: 只→隻 at a position with no classifier "
                          f"cue — …{ours[max(0, i - 6):i + 6]}… — refusing")
                    return 1
                out.append("隻")
                from_oracle += 1
                report.append(f"{key(v)}\toracle\t…{ours[max(0, i - 8):i + 8]}…")
            else:
                out.append(x)
        v["text"] = "".join(out)

    by_ref = {key(v): v for v in tr}
    added = already = 0
    for book, ch, vs, old, new in ADD:
        v = by_ref.get((book, ch, vs))
        if v is None:
            print(f"  ✗ {book} {ch}:{vs} is not in this file — refusing")
            return 1
        if old not in v["text"]:
            if new in v["text"]:
                already += 1
                continue
            print(f"  ✗ {book} {ch}:{vs} contains neither 「{old}」 nor "
                  f"「{new}」 — refusing")
            return 1
        v["text"] = v["text"].replace(old, new)
        added += 1
        report.append(f"{(book, ch, vs)}\tlisted\t{old} → {new}")

    after_blob = "".join(v["text"] for v in tr)

    # The adverb must be untouched. Counting it is how we know the oracle did
    # not quietly eat 只是 / 只有 somewhere the cue check happened to allow.
    # A cue in front disqualifies the match: 撒母耳記上 6:10「兩只有乳的母牛」
    # contains the substring 只有 and is a classifier, not the adverb.
    def adverbs(blob: str) -> dict[str, int]:
        counts = {}
        for a in ADVERBS:
            n = start = 0
            while (i := blob.find(a, start)) != -1:
                if i == 0 or blob[i - 1] not in CUES:
                    n += 1
                start = i + 1
            counts[a] = n
        return counts

    after_adverbs = adverbs(after_blob)
    for a, b in adverbs(before_blob).items():
        n = after_adverbs[a]
        if b != n:
            print(f"  ✗ 「{a}」 went from {b} to {n} — refusing")
            return 1

    # Nothing but 只→隻 may have changed.
    if before_blob.replace("只", "隻") != after_blob.replace("只", "隻"):
        print("  ✗ something other than 只/隻 changed — refusing")
        return 1

    total = from_oracle + added
    print(f"  只 before: {before_blob.count('只')}   after: "
          f"{after_blob.count('只')}")
    print(f"  隻 after : {after_blob.count('隻')}"
          f"   ({from_oracle} from the oracle + {added} listed)")
    print(f"  excluded as the adverb: {len(EXCLUDE)}"
          f"   verses skipped on length: {skipped_len}"
          f"   already applied: {already}")

    if args.report:
        Path(args.report).write_text("\n".join(report) + "\n", encoding="utf-8")
        print(f"  full diff ({len(report)} lines) → {args.report}")

    if args.apply:
        TR.write_text(json.dumps(tr, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
        print(f"  written → {TR.relative_to(ROOT)}  ({total} substitutions)")
    else:
        print(f"  TOTAL {total} substitutions  (dry run — nothing written)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
