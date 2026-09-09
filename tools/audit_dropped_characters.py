#!/usr/bin/env python3
"""Find verses where our text is missing characters that BOTH independent
witnesses carry.

Ours            assets/cuvs-yhwh.json          (Simplified, 雅伟 for YHWH)
Witness A       SeekSparks assets/cuvs-plus.json   (independent Simplified import)
Witness B       git blob 7a2dc43 = assets/cuv-tr.json (Traditional, dropped v1.4.5)

Witness B is folded to Simplified with opencc so all three sit in one script.
Only CJK ideographs are compared, so punctuation and spacing never register.
A hit is a deletion the two witnesses agree on, at the same place in our text.

Hits are split in two, mirroring `audit_inserted_characters.py`:

  APPARATUS  the deleted text sits inside this edition's own `<note:…>` /
             `〔…〕` / bracket-gloss / `（原文是…）` apparatus — a note was
             reworded or its anchor moved, not a word lost from the verse.
  RUNNING    the deletion is in the verse itself. These are the ones that
             matter, and each has to be read individually.

A deletion has no character of its own in `ours` — unlike an insertion,
which carries the flag on the character it added — so it is tested by the
apparatus flags of the characters bounding the gap instead of by a flag on
itself; see `gap_is_apparatus`.
"""
import json
import re
import subprocess
import sys
from difflib import SequenceMatcher
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_inserted_characters import apparatus_mask  # noqa: E402

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
    # 030006008 used to be listed here for the same reason as 030006008 in
    # audit_tagged_running_text.py's UNSETTLED — 萬軍之神 read on the wrong
    # side of the oath. The 50dcc102 publisher adoption re-ordered it to
    # match the witnesses and added its own `<note: 原文有"雅伟">`, so the
    # entry is gone rather than updated: nothing is missing here any more,
    # by either witness's count.
    #
    # A substitution, not a drop — filed separately in the queue.
    "047013005": "ours 在你們裏面 where the print reads 在你們心裏",
    # No character is missing; the 原文是賣 note sits on a different 誘惑 than
    # the witnesses use. Read 2026-08-19 and NOT settled either way — the
    # printed 1919 sets the note at the end of the verse, naming the word, so
    # it does not arbitrate. See UNSETTLED in audit_note_placement.py.
    "034003004": "the 原文是賣 note sits on the first 誘惑, witnesses the second",
    # The eight transpositions this file used to list are REPAIRED — see
    # `tools/repair_transposed_characters.py`. They are deliberately not
    # re-listed here: if a re-import scrambles their order again, this run
    # should report them as new drift rather than swallow them as known.
    #
    # ---- 62 apparatus-reformat hits from the 50dcc102 adoption, 2026-09-09 ----
    #
    # The 50dcc102 publisher-text adoption moved a `<note:…>` gloss's anchor
    # relative to the word it annotates in each of these (e.g. 出埃及記
    # 23:21: 「不可惹<note:…>他」 -> 「不可惹他<note:…>」) or reworded a note's
    # own wording. Each was checked individually against
    # `docs/autonomous-queue.md:2451`'s method: the text OUTSIDE the note is
    # byte-identical between `50dcc102^` and HEAD, so nothing was added to or
    # dropped from the verse itself — only where the note sits, or what it
    # says, moved. Listed by id, not by a blanket "multiset unchanged" rule,
    # because that rule is not safe here: six OTHER verses this same pass
    # found (009001007, 043012035, 043016004, 045012003, 049004022,
    # 066002016) are ALSO multiset-unchanged and are genuine word-order
    # corruptions the adoption introduced, not apparatus. They are correctly
    # NOT in this list and must keep failing the run — see :2436.
    "002023021": "出埃及记 23:21  missing '他'@30 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "004032038": "民数记 32:38  missing '西比玛'@5 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "007006026": "士师记 6:26  missing '上'@10 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "009025001": "撒母耳记上 25:1  missing '里'@34 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "010011011": "撒母耳记下 11:11  missing '的'@33 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "010011021": "撒母耳记下 11:21  missing '九章一节'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "011003004": "列王纪上 3:4  missing '的'@23 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "011010015": "列王纪上 10:15  missing '的'@19 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "014004003": "历代志下 4:3  missing '的'@11 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "014030003": "历代志下 30:3  missing '间'@8 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "016003005": "尼希米记 3:5  missing '担'@25 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "016006006": "尼希米记 6:6  missing '二章十九节'@20 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019009014": "诗篇 9:14  missing '的'@23 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019022020": "诗篇 22:20  missing '脱离'@26 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019051010": "诗篇 51:10  missing '的'@25 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019088004": "诗篇 88:4  missing '的人'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019106028": "诗篇 106:28  missing '的'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023014032": "以赛亚书 14:32  missing '的'@13 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023022004": "以赛亚书 22:4  missing '的'@29 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023033004": "以赛亚书 33:4  missing '尽禾稼'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023041009": "以赛亚书 41:9  missing '原文是抓'@8 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023048014": "以赛亚书 48:14  missing '内中'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023049012": "以赛亚书 49:12  missing '国'@28 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023055011": "以赛亚书 55:11  missing '的事上'@45 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024005006": "耶利米书 5:6  missing '的'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024009001": "耶利米书 9:1  missing '中'@32 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024030014": "耶利米书 30:14  missing '你'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024042001": "耶利米书 42:1  missing '四十三章二节'@31 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "025003034": "耶利米哀歌 3:34  missing '在'@14 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026023025": "以西结书 23:25  missing '的人'@41 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026028010": "以西结书 28:10  missing '的人'@26 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026030006": "以西结书 30:6  missing '二十九章十节'@41 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026040003": "以西结书 40:3  missing '如'@20 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026040044": "以西结书 40:44  missing '在南门旁'@31 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026047010": "以西结书 47:10  missing '之处'@30 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "027001017": "但以理书 1:17  missing '上'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "027003004": "但以理书 3:4  missing '的人'@24 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "027008002": "但以理书 8:2  missing '中'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "027010013": "但以理书 10:13  missing '中的'@31 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "033001013": "弥迦书 1:13  missing '的'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "036002014": "西番雅书 2:14  missing '的'@11 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "038008023": "撒迦利亚书 8:23  missing '中'@30 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040016025": "马太福音 16:25  missing '的'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040017027": "马太福音 17:27  missing '他们'@14 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "042004009": "路加福音 4:9  missing '上'@23 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "042009024": "路加福音 9:24  missing '的'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "044008027": "使徒行传 8:27  missing '十八章一节'@23 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "044018024": "使徒行传 18:24  missing '的'@34 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "046011024": "哥林多前书 11:24  missing '的'@25 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "046011030": "哥林多前书 11:30  missing '的'@23 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "047001020": "哥林多后书 1:20  missing '的'@34 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "048003013": "加拉太书 3:13  missing '了'@13 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "049002021": "以弗所书 2:21  missing '房'@6 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "053002002": "帖撒罗尼迦后书 2:2  missing '到了'@32 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "058004001": "希伯来书 4:1  missing '中间'@32 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "058009005": "希伯来书 9:5  missing '座'@23 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "060001012": "彼得前书 1:12  missing '的'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "063001008": "约翰二书 1:8  missing '所做的工'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066002027": "启示录 2:27  missing '他们'@15 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066003002": "启示录 3:2  missing '的'@20 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066019015": "启示录 19:15  missing '他们'@30 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066020008": "启示录 20:8  missing '的'@15 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    # These 11 need BOTH gap neighbours inside apparatus to auto-classify
    # (see gap_is_apparatus), and each has only one — the deletion sits at
    # a note's own boundary. Read individually the same way as the 62 above.
    "013002013": "历代志上 2:13  missing '十六章九节'@25 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019010010": "诗篇 10:10  missing '之下'@26 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019140009": "诗篇 140:9  missing '自己'@30 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023016001": "以赛亚书 16:1  missing '的山'@32 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024030017": "耶利米书 30:17  missing '的'@41 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "030009013": "阿摩司书 9:13  missing '三章十八节'@50 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040004005": "马太福音 4:5  missing '上'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040024008": "马太福音 24:8  missing '的起头'@17 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "042009054": "路加福音 9:54  missing '吗'@55 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "054006018": "提摩太前书 6:18  missing '人'@29 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "058007010": "希伯来书 7:10  missing '中'@31 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
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


def gap_is_apparatus(mask, p):
    """Is the gap before han-index `p` in `ours` inside editorial apparatus?

    `mask` lines up with `han(ours_text)`. There is no character AT the gap
    to test, so this tests the characters bounding it on BOTH sides: only
    if the char before AND the char after are both inside apparatus is the
    deletion attributed to a note being reworded or its anchor moved rather
    than to a loss from the verse.

    A gap at the very start or end of the verse — one side doesn't exist —
    is deliberately NEVER apparatus, even if the one existing side is.
    005005005 is why: the whole verse there is one scriptural parenthetical
    remark, «（那时…没有上山。）», not an editorial note, and it is wrapped in
    the same （） this edition also uses for `（原文是…）` glosses. A gap at
    its closing bracket has an apparatus flag on its one real neighbour for
    a reason with nothing to do with notes; requiring both sides keeps that
    verse (and the boundary case generally) in RUNNING for a human to read,
    instead of silently absorbing it into APPARATUS.
    """
    if not (0 < p < len(mask)):
        return False
    return mask[p - 1] and mask[p]


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
        da = deletions(mine, ta)
        db = deletions(mine, tb)
        agreed = sorted(set(da) & set(db))
        if not agreed:
            continue
        mask = apparatus_mask(ours[vid]["text"].replace("雅伟", "耶和华"))
        if all(gap_is_apparatus(mask, p) for p, s in agreed):
            apparatus.append((vid, agreed))
        else:
            running.append((vid, agreed))

    known = EXPLAINED.keys()
    fresh = [h for h in running if h[0] not in known]
    print(f"verses compared: {len(ids)}")
    print(f"both witnesses read more than we do: {len(apparatus) + len(running)}")
    print(f"  editorial apparatus only: {len(apparatus)}")
    print(f"  in the running text: {len(running)}")
    print(f"    already read and explained: {len(running) - len(fresh)} of {len(EXPLAINED)}")
    print(f"    NEW, unexamined: {len(fresh)}")
    for vid, agreed in fresh:
        r = ours[vid]
        missing = " ".join(f"{s!r}@{pos}" for pos, s in agreed)
        print(f"\n{vid}  {r['book']} {r['chapter']}:{r['verse']}   missing {missing}")
        print(f"  ours : {r['text']}")
        print(f"  A    : {a[vid]['text']}")
        print(f"  B    : {b[vid]['text']}")

    # A known hit that stops appearing is drift too — the text moved under a
    # triage decision that was made by reading it.
    gone = sorted(known - {vid for vid, _ in running})
    for vid in gone:
        print(f"\n{vid} no longer reads short — update EXPLAINED: {EXPLAINED[vid]}")
    return 1 if fresh or gone else 0


if __name__ == "__main__":
    sys.exit(main())
