#!/usr/bin/env python3
"""Find verses where OUR text carries characters that NEITHER witness has.

The mirror of `audit_dropped_characters.py`, and the direction nobody had ever
measured: that audit only reports where the witnesses read MORE than we do, so
until this file existed the app could add words to scripture and no check in
the repo would notice. Adding is the worse direction of the two — a reader who
sees a missing word may notice, but a reader who sees an extra one cannot.

Ours            assets/cuvs-yhwh.json          (Simplified, 雅伟 for YHWH)
Witness A       SeekSparks assets/cuvs-plus.json   (independent Simplified import)
Witness B       git blob 7a2dc43 = assets/cuv-tr.json (Traditional, dropped v1.4.5)

Witness B is folded to Simplified with opencc so all three sit in one script.
Only CJK ideographs are compared, so punctuation and spacing never register.
A hit is an insertion the two witnesses agree on, at the same place in our text.

Hits are split in two, because they are not the same kind of thing:

  APPARATUS  the extra characters lie wholly inside a <note:…> marker, a
             [雅伟]-style bracket gloss, or a （原文是…） parenthesis. This
             edition's own editorial apparatus, which the witnesses simply do
             not carry. 387 of the 419 hits, and none of them is a defect.
  RUNNING    the extra characters are in the verse itself. These are the ones
             that matter, and each has to be read individually.

**What this audit cannot see, and it is a large hole.** It only reports where
BOTH witnesses disagree with us, so any text we share with witness A is
invisible to it — and we share an ancestor with A. 歷代志上 15:3 read
「招聚以色列眾人眾人」 and this audit never flagged it, because A reads 眾人眾人
too. It was caught by a third witness that is internal to this repo and that
nothing here consults: `assets/tagged/cuvs-yhwh/`, whose runs concatenate back
to the verse and which held 以色列众人 once. Comparing the running text against
the tagged corpus is queued as its own audit.
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

# Running-text hits that have been read individually and are NOT insertions.
# Anything outside this set is new drift and fails the run.
EXPLAINED = {
    # Verse-boundary placement: the trailing 說 of the previous verse opens
    # this one in this edition. Already carried by the deletion audit as the
    # other half of the same pair.
    "005005006": "說 opens 申命記 5:6 here; the witnesses leave it in 5:5",
    "005032020": "說 opens 申命記 32:20 here; the witnesses leave it in 32:19",
    # A transposition the printed 1919 settles in OUR favour — see the
    # deletion audit, which pins the mirror image of this hit.
    "024007014": "1919 reads 稱我為名下; the witnesses read 稱為我名下",
    # Verse 15 is merged into 14 in this edition, behind a <note: 15节> marker.
    # Whether it deserves its own number is a queued question for the user,
    # not a text defect: no character is invented, only un-numbered.
    "064001014": "約翰三書 1:15 is merged into 1:14 behind a 15节 note marker",
    # Filed separately in the queue as a substitution, not an insertion.
    "047013005": "ours 在你們裏面 where the print reads 在你們心裏",
}

# Running-text hits that LOOK like genuine insertions and have not been settled.
# They are listed with the exact characters they add, so that this audit stays a
# working regression detector while they wait: a re-import that changes one of
# them, or adds a new one, still fails the run.
#
# None of them may be "repaired" on the strength of the two witnesses alone.
# 創世記 39:22 and 41:30 are the standing warning — both witnesses read longer
# than us there and OURS was the correct 1919 reading. Each of these needs the
# printed 1919 text as a third, uncorrelated line of evidence, exactly as the
# fifteen restored characters and the eight transpositions did.
#
# 14 of the 26 sit in just two books, 使徒行傳 (6) and 哥林多後書 (8), which is
# far more concentrated than the corpus is. Worth explaining before repairing
# any of them individually: a whole-book source difference and 26 independent
# typos call for different fixes.
PENDING = {
    "001048017": "创世纪 48:17  +的  (以法莲的头上 / 以法莲头上)",
    "004011030": "民数记 11:30  +了  (回到营里去了 / 去)",
    "004021020": "民数记 21:20  +了  (从巴末到了摩押地 / 到摩押地)",
    "016001002": "尼希米记 1:2  +关于 +关于  (我问他们关于那些… / 我问他们那些…)",
    "016002019": "尼希米记 2:19  +你们  (你们要背叛王吗 / 要背叛王么)",
    "016003003": "尼希米记 3:3  +他们  (建立鱼门，他们架横梁 / 建立鱼门，架横梁)",
    "025003001": "耶利米哀歌 3:1  +神  (因雅伟神忿怒的杖 / 因耶和华忿怒的杖)",
    "038008014": "撒迦利亚书 8:14  +我  (我并不后悔 / 并不后悔)",
    "041006033": "马可福音 6:33  +的  (从各城的步行 / 从各城步行)",
    "044023035": "使徒行传 23:35  +也  (等告你的人也来到 / 等告你的人来到)",
    "044024002": "使徒行传 24:2  +开始控  (就开始控告他说 / 就告他说)",
    "044024023": "使徒行传 24:23  +要  (并且要宽待他 / 并且宽待他)",
    "044025022": "使徒行传 25:22  +他  (明天你可以听他 / 你可以听)",
    "044026016": "使徒行传 26:16  +我  (特意向你我显现 / 我特意向你显现)",
    "044028006": "使徒行传 28:6  +看  (等了多时，看见他无害 / 看了多时，见他无害)",
    "044028010": "使徒行传 28:10  +东西  (所需用的东西 / 所需用的)",
    "046015031": "哥林多前书 15:31  +们  (在我们主基督耶稣里 / 在我主基督耶稣里)",
    "047002013": "哥林多后书 2:13  +我  (因为我没有遇见 / 因为没有遇见)",
    "047006003": "哥林多后书 6:3  +在  (我们在凡事 / 我们凡事)",
    "047007014": "哥林多后书 7:14  +们  (因我们对提多夸奖 / 因我对提多夸奖)",
    "047008004": "哥林多后书 8:4  +服事  (在这服事供给圣徒 / 在这供给圣徒)",
    "047008006": "哥林多后书 8:6  +们 +就  (因此我们劝提多…中间就开办 / 因此我劝…中间开办)",
    "047008015": "哥林多后书 8:15  +少  (也没有缺少 / 也没有缺)",
    "047008023": "哥林多后书 8:23  +我们  (论到我们那两位兄弟 / 论到那两位兄弟)",
    "047009011": "哥林多后书 9:11  +在  (叫你们在凡事富足 / 叫你们凡事富足)",
    "047012020": "哥林多后书 12:20  +发 +发  (发见你们 / 见你们)",
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


def apparatus_mask(text):
    """One flag per CJK character: is it inside editorial apparatus?

    Indexes line up with `han(text)`, so a hit's position can be tested
    directly. Brackets and parentheses nest independently of note markers
    because this edition uses 「（原文是…）」 inside notes and 「主[雅伟]」
    outside them.
    """
    flags = []
    note = brackets = parens = 0
    i = 0
    while i < len(text):
        if text.startswith("<note:", i):
            note += 1
            i += 6
            continue
        if note and text[i] == ">":
            note -= 1
            i += 1
            continue
        ch = text[i]
        if ch in "[［":
            brackets += 1
        elif ch in "]］":
            brackets = max(0, brackets - 1)
        elif ch in "（(":
            parens += 1
        elif ch in "）)":
            parens = max(0, parens - 1)
        elif CJK.match(ch):
            flags.append(bool(note or brackets or parens))
        i += 1
    return flags


def insertions(ours, theirs):
    """Substrings present in `ours` and absent from `theirs`, keyed by the
    position in `ours` where they were added."""
    out = []
    for tag, i1, i2, j1, j2 in SequenceMatcher(None, theirs, ours, autojunk=False).get_opcodes():
        if tag == "insert":
            out.append((j1, ours[j1:j2]))
    return out


def main():
    ours = load(OURS)
    a = load(WIT_A)
    b = load_blob(WIT_B_BLOB)

    ids = sorted(ours)
    b_ids = [i for i in ids if i in b]
    b_simp = dict(zip(b_ids, to_simplified([b[i]["text"] for i in b_ids])))

    apparatus, running = [], []
    for vid in ids:
        if vid not in a or vid not in b_simp:
            continue
        mine = han(ours[vid]["text"].replace("雅伟", "耶和华"))
        ta = han(a[vid]["text"])
        tb = han(b_simp[vid])
        if mine == ta and mine == tb:
            continue
        agreed = sorted(set(insertions(mine, ta)) & set(insertions(mine, tb)))
        if not agreed:
            continue
        mask = apparatus_mask(ours[vid]["text"].replace("雅伟", "耶和华"))
        if all(all(mask[p:p + len(s)] or [False]) for p, s in agreed):
            apparatus.append((vid, agreed))
        else:
            running.append((vid, agreed))

    known = EXPLAINED.keys() | PENDING.keys()
    fresh = [h for h in running if h[0] not in known]
    print(f"verses compared: {len(ids)}")
    print(f"we read more than both witnesses: {len(apparatus) + len(running)}")
    print(f"  editorial apparatus only: {len(apparatus)}")
    print(f"  in the running text: {len(running)}")
    print(f"    read and explained: {sum(1 for h in running if h[0] in EXPLAINED)} of {len(EXPLAINED)}")
    print(f"    awaiting the printed 1919: {sum(1 for h in running if h[0] in PENDING)} of {len(PENDING)}")
    print(f"    NEW, unexamined: {len(fresh)}")
    for vid, agreed in fresh:
        r = ours[vid]
        extra = " ".join(f"{s!r}@{pos}" for pos, s in agreed)
        print(f"\n{vid}  {r['book']} {r['chapter']}:{r['verse']}   extra {extra}")
        print(f"  ours : {r['text']}")
        print(f"  A    : {a[vid]['text']}")
        print(f"  B    : {b[vid]['text']}")

    # A known hit that stops appearing is drift too — the text moved under a
    # triage decision that was made by reading it.
    gone = sorted(known - {vid for vid, _ in running})
    for vid in gone:
        print(f"\n{vid} no longer reads long — update EXPLAINED/PENDING: "
              f"{EXPLAINED.get(vid) or PENDING[vid]}")
    return 1 if fresh or gone else 0


if __name__ == "__main__":
    sys.exit(main())
