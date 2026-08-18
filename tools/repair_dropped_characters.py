#!/usr/bin/env python3
"""Restore 15 characters that dropped out of the CUV text, one per verse.

士師記 12:13 read 「作以色的士師」 — Israel, one character short of its own
name. 出埃及記 15:7 「像燒碎一樣」; 詩篇 78:44 「江河並河的水」;
撒迦利亞書 11:15 「愚昧人所用的器具」 where the器具 belong to a shepherd.
Nothing marked the loss: the verses read as ordinary Chinese and every
structural check the repo has passes on them, because they ask whether a
verse exists, not whether it is whole.

The loss is upstream of the Traditional conversion — both
`assets/cuvs-yhwh.json` and `assets/cuvs-yhwh-tr.json` are short at all 15
positions — and upstream of this repo: it is already in the MySword module
the corpus was imported from.

WHY THIS IS SAFE TO WRITE, WHICH IS THE QUESTION THAT MATTERS
  Restoring is the dangerous direction. Four independent lines agree at
  every one of the 15:

  1. `SeekSparks/assets/cuvs-plus.json`, a separate Simplified import.
  2. `assets/cuv-tr.json`, a separately imported plain 和合本 Traditional
     (耶和華, not 雅偉), dropped from the repo at v1.4.5 but permanently
     readable as git blob 7a2dc43 (`git cat-file -p 7a2dc43`). Witnesses
     1 and 2 disagree with EACH OTHER in 5,338 of 31,101 verses, so their
     agreeing here is worth something.
  3. The Wikisource transcription of the PRINTED 1919 text.
  4. The import module's own Strong's tags, which survived the lost
     characters and point straight at them:
       以色<WH3478>         H3478 = ישראל, Israel — tagged onto a fragment
       燒碎<WH7179>         H7179 = קַשׁ, stubble  — 碎秸
       愚昧人<WH7462x><WH8802x>  H7462 participle = shepherd — 牧人
     A word cannot be tagged with a Strong's number it no longer spells.

TWO THAT LOOKED IDENTICAL AND ARE NOT — do not "fix" these
  創世記 39:22 「都交在約瑟手下」  (witnesses 1,2 read 約瑟的手下)
  創世記 41:30 「甚至埃及地都忘了」 (witnesses 1,2 read 甚至在埃及地)
  Both were on the repair list until the printed 1919 text was checked: it
  reads exactly as ours, and the module's tagging shows no gap
  (約瑟<WH3130>手下<WH3027>). Witnesses 1 and 2 carry a later expansion.
  Two witnesses agreeing is not proof when both descend from the same
  revision, which is why the third and fourth lines were worth getting.

Run with --apply to write; without it, reports and changes nothing.
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
    ("001045001", "創世紀 45:1",    ("弟兄相认", "弟兄们相认"),       ("弟兄相認", "弟兄們相認")),
    ("001045015", "創世紀 45:15",   ("他弟兄就和他说话", "他弟兄们就和他说话"),
                                    ("他弟兄就和他說話", "他弟兄們就和他說話")),
    ("001050011", "創世紀 50:11",   ("一场大的哀哭", "一场极大的哀哭"), ("一場大的哀哭", "一場極大的哀哭")),
    ("002015007", "出埃及記 15:7",  ("像烧碎一样", "像烧碎秸一样"),    ("像燒碎一樣", "像燒碎秸一樣")),
    ("007012013", "士師記 12:13",   ("作以色的士师", "作以色列的士师"), ("作以色的士師", "作以色列的士師")),
    ("019059012", "詩篇 59:12",     ("他们口中的罪", "因他们口中的罪"), ("他們口中的罪", "因他們口中的罪")),
    ("019078044", "詩篇 78:44",     ("并河的水", "并河汊的水"),        ("並河的水", "並河汊的水")),
    ("019102026", "詩篇 102:26",    ("天地就改变了", "天地就都改变了"), ("天地就改變了", "天地就都改變了")),
    ("038011015", "撒迦利亞書 11:15", ("愚昧人所用", "愚昧牧人所用"),  ("愚昧人所用", "愚昧牧人所用")),
    ("041011017", "馬可福音 11:17", ("便教训说", "便教训他们说"),      ("便教訓說", "便教訓他們說")),
    ("044026029", "使徒行傳 26:29", ("是少是多劝", "是少劝是多劝"),    ("是少是多勸", "是少勸是多勸")),
    ("044027044", "使徒行傳 27:44", ("船上的东西", "船上的零碎东西"),  ("船上的東西", "船上的零碎東西")),
    ("047010009", "哥林多後書 10:9", ("免得以为", "免得你们以为"),     ("免得以為", "免得你們以為")),
    ("047012017", "哥林多後書 12:17", ("他一个人", "他们一个人"),      ("他一個人", "他們一個人")),
    ("058002002", "希伯來書 2:2",   ("凡犯悖逆", "凡干犯悖逆"),        ("凡犯悖逆", "凡干犯悖逆")),
]


# The same 15 losses are in the tagged corpus behind the word-tap sheet, which
# renders its own copy of the verse — so the short reading was visible there
# too. Here the Strong's tag says exactly which word the character belongs to,
# which is better placement evidence than the running text: 作以色 is tagged
# H3478 (Israel), 像烧碎 H7179 (stubble), the bare 人 H7462 (a shepherd).
# slug, reference, run text before, run text after
TAGGED_REPAIRS = [
    ("genesis", "45:1", "弟兄", "弟兄们"),              # H251  brothers
    ("genesis", "45:15", "他弟兄", "他弟兄们"),          # H251
    ("genesis", "50:11", "一场大的", "一场极大的"),       # H3515 grievous
    ("exodus", "15:7", "像烧碎", "像烧碎秸"),            # H7179 stubble
    ("judges", "12:13", "作以色", "作以色列"),           # H3478 Israel
    ("psalms", "59:12", "他们口中", "因他们口中"),        # supplied conjunction
    ("psalms", "78:44", "并河", "并河汊"),              # H5140 flowing streams
    ("psalms", "102:26", "天地就改变", "天地就都改变"),
    ("zechariah", "11:15", "人", "牧人"),               # H7462 shepherd
    ("mark", "11:17", "教训", "教训他们"),               # G846  αὐτοῖς
    ("acts", "26:29", "是少", "是少劝"),                 # parallels 是多劝
    ("acts", "27:44", "的东西", "的零碎东西"),            # G5100 τι
    ("2_corinthians", "10:9", "以为", "你们以为"),
    ("2_corinthians", "12:17", "他", "他们"),            # G846  αὐτῶν, plural
    ("hebrews", "2:2", "犯", "干犯"),                   # G3847 παράβασις
]


def repair_tagged(apply):
    changed = 0
    for slug, ref, before, after in TAGGED_REPAIRS:
        path = REPO / f"assets/tagged/cuvs-yhwh/{slug}.json"
        book = json.loads(path.read_text(encoding="utf-8"))
        runs = book[ref]
        hits = [i for i, r in enumerate(runs) if r.get("w") == before]
        if not hits and any(r.get("w") == after for r in runs):
            print(f"  {slug} {ref} already repaired")
            continue
        if len(hits) != 1:
            print(f"  FAIL {slug} {ref}: {before!r} matches {len(hits)} runs",
                  file=sys.stderr)
            return None
        print(f"  {slug} {ref}: {before} → {after}")
        runs[hits[0]]["w"] = after
        changed += 1
        if apply:
            path.write_text(
                json.dumps(book, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
    return changed


def repair(path, index, apply):
    verses = json.loads(path.read_text(encoding="utf-8"))
    by_id = {v["id"]: v for v in verses}
    changed = 0
    for vid, ref, *forms in REPAIRS:
        before, after = forms[index]
        verse = by_id[vid]
        text = verse["text"]
        # `before` can survive as a substring of `after` (詩篇 59:12 prefixes
        # 因 to 他们口中的罪), so presence of `after` is what marks it done.
        if after in text:
            print(f"  {ref} already repaired")
            continue
        if text.count(before) != 1:
            print(f"  FAIL {ref}: {before!r} occurs {text.count(before)}x", file=sys.stderr)
            return None
        new = text.replace(before, after)
        # The only permitted edit is an insertion: the old text must remain a
        # subsequence of the new one, and nothing may be replaced or dropped.
        if len(new) != len(text) + len(after) - len(before) or not is_subsequence(text, new):
            print(f"  FAIL {ref}: edit is not a pure insertion", file=sys.stderr)
            return None
        print(f"  {ref}: {before} → {after}")
        verse["text"] = new
        changed += 1
    if apply and changed:
        path.write_text(
            json.dumps(verses, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    return changed


def is_subsequence(small, big):
    it = iter(big)
    return all(c in it for c in small)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    total = 0
    for path, index in ((SIMPLIFIED, 0), (TRADITIONAL, 1)):
        print(f"{path.name}:")
        n = repair(path, index, args.apply)
        if n is None:
            return 1
        total += n
    print("tagged/cuvs-yhwh:")
    n = repair_tagged(args.apply)
    if n is None:
        return 1
    total += n
    print(f"\n{total} verses {'repaired' if args.apply else 'to repair'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
