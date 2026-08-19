#!/usr/bin/env python3
"""Restore seven characters the reading text lost, found by our own tagged corpus.

  士師記 9:57    咒詛歸到**們**身上了      → 歸到**他們**身上了
  士師記 12:7    作以色列的士師**年**      → 作以色列的士師**六**年
  撒母耳記下 5:17 非利士**人**就上來        → 非利士**眾**人就上來
  以賽亞書 23:1  因為**羅**變為荒場        → 因為**推羅**變為荒場
  以斯帖記 6:7   王所喜悅尊榮**的，**      → 尊榮的**人**，
  瑪拉基書 2:3   把你們犧牲的糞**抹**你們的臉上 → 糞**抹在**你們的臉上
  以賽亞書 41:16 為喜樂，**以色列**的聖者   → **以以色列**的聖者

WHY THESE WERE STILL HERE. `audit_dropped_characters.py` only reports a loss
the two external witnesses AGREE on, at the same position — and it reports none
of these seven. Witness A carries six of them itself; witness B carries three;
BOTH are short at 以斯帖記 6:7 and 瑪拉基書 2:3. They were invisible to it and
to every structural check the repo runs, because a verse can be present,
correctly numbered and correctly ordered while a character inside it is gone.

FOUR LINES OF EVIDENCE, because restoring is the dangerous direction:

  1. Our own tagged corpus (`assets/tagged/cuvs-yhwh/`) reads long in all seven.
  2. Its Strong's tags name the missing word, and a word cannot be tagged with
     a number it no longer spells: 六 = H8337, 众人 = H3605, 他们身上 = H413,
     推罗变为荒场 = H7703 alongside H6865 (צֹר, Tyre), 人 = H376, 抹在 = H2219
     with 你们的脸上 = H5921, 以以色列的 = H3478.
  3. The Hebrew in `assets/originals/` has the word in every case —
     שֵׁשׁ שָׁנִים (士 12:7), אֲלֵיהֶם (士 9:57), כָל־פְּלִשְׁתִּים (撒下 5:17),
     צֹר … שֻׁדַּד (賽 23:1), אִישׁ (斯 6:7), עַל־פְּנֵיכֶם (瑪 2:3). 賽 41:16 is
     grammatical rather than lexical and is the clearest of the seven: BOTH
     verbs govern a ב-prefixed object — תָּגִ֣יל בַּֽיהוָ֔ה, בִּקְד֥וֹשׁ
     יִשְׂרָאֵ֖ל תִּתְהַלָּֽל — so the Chinese renders 以 twice, 「以雅偉為喜
     樂，以以色列的聖者為誇耀」. One 以 leaves 為誇耀 without its preposition.
  4. The Wikisource transcription of the PRINTED 1919 和合本 reads 「歸到他們身
     上了」, 「作以色列的士師六年」, 「非利士衆人就上來尋索大衞」,
     「因爲推羅變爲荒塲」, 「王所喜悅尊榮的人」, 「抹在你們的臉上」,
     「以耶和華爲喜樂、以以色列的聖者爲誇耀」. That last one is not a scanning
     artifact of the doubled character: 41:14 and 41:20 print the same phrase
     with ONE 以, because there it is not the object of a ב.

Witness B (git blob 7a2dc43) reads long in four of the seven and is a fifth
line there, but it is short at 以斯帖記 6:7, 瑪拉基書 2:3 and 以賽亞書 23:1,
so it is not counted. Witness A is long at 以賽亞書 23:1 alone — the one place
B is short — which is why the pair never coincides and the existing audit sees
nothing. Counted directly, not inferred: A long 1 of 7, B long 4 of 7.

The print is not a formality. 創世記 39:22 and 41:30 looked exactly like these,
two witnesses read longer, and the print agreed with US — the witnesses were
carrying a later revision. It also settled three that look identical and are
NOT losses: 士師記 15:2's 我請求, 15:18's 現在 and 撒母耳記下 21:2's 大發熱心
are supplied by the tagged import alone and are absent from the print.

THE TAGGED CORPUS IS THE WITNESS HERE, NOT A VICTIM, and needs no repair: the
word-tap sheet has been printing 「士師六年」 all along while the verse behind
it read 「士師年」. It is NOT an uncorrelated witness — it shares most of the
digital-CUV transcription errors catalogued in
`tools/repair_cuv_typo_corruptions.py` — but it is a different transcription
line from A and B, which is all that is needed to see a loss both of them made.

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
    ("007009057", "士師記 9:57",     ("咒诅归到们身上", "咒诅归到他们身上"),
                                     ("咒詛歸到們身上", "咒詛歸到他們身上")),
    ("007012007", "士師記 12:7",     ("的士师年", "的士师六年"),
                                     ("的士師年", "的士師六年")),
    ("010005017", "撒母耳記下 5:17", ("非利士人就上来", "非利士众人就上来"),
                                     ("非利士人就上來", "非利士眾人就上來")),
    ("023023001", "以賽亞書 23:1",   ("因为罗变为荒场", "因为推罗变为荒场"),
                                     ("因為羅變為荒場", "因為推羅變為荒場")),
    ("017006007", "以斯帖記 6:7",    ("尊荣的，", "尊荣的人，"),
                                     ("尊榮的，", "尊榮的人，")),
    ("039002003", "瑪拉基書 2:3",    ("的粪抹你们的脸上", "的粪抹在你们的脸上"),
                                     ("的糞抹你們的臉上", "的糞抹在你們的臉上")),
    ("023041016", "以賽亞書 41:16",  ("为喜乐，以色列的", "为喜乐，以以色列的"),
                                     ("為喜樂，以色列的", "為喜樂，以以色列的")),
]


def repair(path, index, apply):
    verses = json.loads(path.read_text(encoding="utf-8"))
    by_id = {v["id"]: v for v in verses}
    changed = 0
    for vid, ref, *forms in REPAIRS:
        before, after = forms[index]
        verse = by_id[vid]
        if after in verse["text"] and before not in verse["text"]:
            print(f"  {ref} already repaired")
            continue
        if verse["text"].count(before) != 1:
            print(f"  FAIL {ref}: {before!r} appears "
                  f"{verse['text'].count(before)} times", file=sys.stderr)
            return None
        verse["text"] = verse["text"].replace(before, after)
        print(f"  {ref}: {before} → {after}")
        changed += 1
    if apply and changed:
        path.write_text(
            json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    return changed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    total = 0
    for path, index in ((SIMPLIFIED, 0), (TRADITIONAL, 1)):
        print(path.name)
        n = repair(path, index, args.apply)
        if n is None:
            return 1
        total += n
    print(f"{total} substitutions{'' if args.apply else ' (dry run)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
