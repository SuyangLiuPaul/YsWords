#!/usr/bin/env python3
"""Find verses where our text is missing characters that BOTH independent
witnesses carry.

Ours            assets/cuvs-yhwh.json          (Simplified, 雅伟 for YHWH)
Witness A       SeekSparks assets/cuvs-plus.json   (independent Simplified import)
Witness B       git blob 7a2dc43 = assets/cuv-tr.json (Traditional, dropped v1.4.5)

Witness B is folded to Simplified with opencc so all three sit in one script.
Only CJK ideographs are compared, so punctuation and spacing never register.
A hit is a deletion the two witnesses agree on, at the same place in our text.
"""
import json
import re
import subprocess
import sys
from difflib import SequenceMatcher
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = REPO / "assets/cuvs-yhwh.json"
WIT_A = Path("/Users/pliu0036/Documents/CodingProject/SeekSparks/assets/cuvs-plus.json")
WIT_B_BLOB = "7a2dc43"

CJK = re.compile(r"[一-鿿㐀-䶿]")

# Hits that have been read individually and are NOT losses. Anything outside
# this set is new drift and fails the run.
EXPLAINED = {
    # Our edition is the printed 1919; witnesses A and B carry a later
    # expansion. Confirmed against the Wikisource transcription of the print,
    # and against the import module's Strong's tagging, which shows no gap
    # (約瑟<WH3130>手下<WH3027>). Do NOT "repair" these.
    "001039022": "1919 reads 交在約瑟手下; witnesses expand to 約瑟的手下",
    "001041030": "1919 reads 甚至埃及地; witnesses expand to 甚至在埃及地",
    "024007014": "1919 reads 稱我為名下; witnesses read 稱為我名下",
    # Verse-boundary placement: the trailing 說 opens the NEXT verse here.
    "005005005": "說 sits at the start of 申命記 5:6 in this edition",
    "005032019": "說 sits at the start of 申命記 32:20 in this edition",
    # Restructured around a <note:…> marker; no character is missing.
    "030006008": "萬軍之神 moved across the note marker",
    # A substitution, not a drop — filed separately in the queue.
    "047013005": "ours 在你們裏面 where the print reads 在你們心裏",
    "034003004": "the 原文是賣 note is attached to the wrong 誘惑",
    # Transpositions: the characters are all present, in the wrong order.
    # Filed as their own queue item; a swap is two edits, not an insertion.
    "001009011": "transposed: 毀壞了地 / 毀壞地了",
    "016008004": "transposed: 站 sits before 瑪他提雅 instead of 站在他的右邊",
    "020022011": "transposed: 嘴的…為上友 / 嘴上的…為友",
    "031001005": "transposed: 若到來 / 若來到",
    "040006002": "transposed: 你面前 / 你前面",
    "040025020": "transposed: 另外五千的來 / 另外的五千來",
    "044024016": "transposed: 因此我自己 / 我因此自己",
    "045004023": "transposed: 算為他的義 / 算為他義的",
}


def load(path):
    return {r["id"]: r for r in json.loads(Path(path).read_text(encoding="utf-8"))}


def load_blob(blob):
    raw = subprocess.run(
        ["git", "cat-file", "-p", blob], cwd=REPO, capture_output=True, check=True
    ).stdout.decode("utf-8")
    return {r["id"]: r for r in json.loads(raw)}


def to_simplified(texts):
    joined = "\n".join(t.replace("\n", " ") for t in texts)
    out = subprocess.run(
        ["opencc", "-c", "t2s"], input=joined.encode("utf-8"),
        capture_output=True, check=True,
    ).stdout.decode("utf-8")
    lines = out.split("\n")
    assert len(lines) == len(texts), (len(lines), len(texts))
    return lines


def han(text):
    return "".join(CJK.findall(text))


def deletions(ours, theirs):
    """Substrings present in `theirs` and absent from `ours`, keyed by the
    position in `ours` where they were dropped."""
    out = []
    for tag, i1, i2, j1, j2 in SequenceMatcher(None, ours, theirs, autojunk=False).get_opcodes():
        if tag == "delete":
            continue
        if tag == "insert":
            out.append((i1, theirs[j1:j2]))
    return out


def main():
    ours = load(OURS)
    a = load(WIT_A)
    b = load_blob(WIT_B_BLOB)

    ids = sorted(ours)
    b_ids = [i for i in ids if i in b]
    b_simp = dict(zip(b_ids, to_simplified([b[i]["text"] for i in b_ids])))

    hits = []
    for vid in ids:
        if vid not in a or vid not in b_simp:
            continue
        mine = han(ours[vid]["text"].replace("雅伟", "耶和华"))
        ta = han(a[vid]["text"])
        tb = han(b_simp[vid])
        if mine == ta and mine == tb:
            continue
        da = deletions(mine, ta)
        db = deletions(mine, tb)
        agreed = sorted(set(da) & set(db))
        if agreed:
            hits.append((vid, agreed))

    fresh = [h for h in hits if h[0] not in EXPLAINED]
    print(f"verses compared: {len(ids)}")
    print(f"both witnesses read more than we do: {len(hits)}")
    print(f"  already read and explained: {len(hits) - len(fresh)} of {len(EXPLAINED)}")
    print(f"  NEW, unexamined: {len(fresh)}")
    for vid, agreed in fresh:
        r = ours[vid]
        missing = " ".join(f"{s!r}@{pos}" for pos, s in agreed)
        print(f"\n{vid}  {r['book']} {r['chapter']}:{r['verse']}   missing {missing}")
        print(f"  ours : {r['text']}")
        print(f"  A    : {a[vid]['text']}")
        print(f"  B    : {b[vid]['text']}")
    return 1 if fresh else 0


if __name__ == "__main__":
    sys.exit(main())
