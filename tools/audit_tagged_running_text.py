#!/usr/bin/env python3
"""Diff the reading text against our OWN Strong's-tagged corpus.

Ours     assets/cuvs-yhwh.json         the verse a reader sees
Tagged   assets/tagged/cuvs-yhwh/      the same translation, separately imported,
                                       stored as runs whose `w` fields
                                       concatenate back to the verse

This is a THIRD witness. It is not an uncorrelated one — it shares most of the
digital-CUV transcription errors catalogued in `repair_cuv_typo_corruptions.py`
— but it is a different transcription line from the two external witnesses, and
that is enough. `audit_dropped_characters.py` only reports a loss both of THEM
agree on, at the same position, and it reports NONE of the seven losses this
file found: witness A reads long at one of the seven, witness B at four, and
they never coincide. Two of the seven are short in BOTH witnesses.

Compared on CJK ideographs alone, after stripping note markers — `<note:…>`
on our side, `〔…〕` and `（…）` on the tagged side. Punctuation, quotation
marks and note wording differ freely between two imports and are not
scripture.

WHAT COMES OUT, over 31,102 verses: 335 verses differ, and all but the seven
repaired and the one queued under UNSETTLED are one of

  * an orthographic variant the two imports set differently — 阿/啊, 它/他/她,
    复/覆, 吗/么, 糟/蹧, 做/作, 吧/罢, 喇/啦, 逿/趟;
  * a verse our edition folds into its neighbour and marks 「见上节」;
  * note or parenthesis restructuring;
  * an artifact on the TAGGED side — a duplicated or transposed run
    (「箭箭」, 「未未曾」, 「买的来车」, 「第二十是一何提」). Ours is right
    in every one of those and must not be "repaired" towards the tagged copy.

Only text the tagged corpus has and ours does not is reported, because that is
the direction that can mean a loss in what the reader sees. Text ours has and
the tagged copy does not is the tagged copy's own problem and costs nothing on
screen.
"""
import json
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = REPO / "assets/cuvs-yhwh.json"
TAGGED = REPO / "assets/tagged/cuvs-yhwh"

CJK = re.compile(r"[㐀-鿿]")
NOTE_ANGLE = re.compile(r"<note:[^>]*>")
NOTE_LENTICULAR = re.compile(r"〔[^〕]*〕")
STRIP = (NOTE_ANGLE, NOTE_LENTICULAR)

BOOKS = """genesis exodus leviticus numbers deuteronomy joshua judges ruth
1_samuel 2_samuel 1_kings 2_kings 1_chronicles 2_chronicles ezra nehemiah
esther job psalms proverbs ecclesiastes song_of_solomon isaiah jeremiah
lamentations ezekiel daniel hosea joel amos obadiah jonah micah nahum
habakkuk zephaniah haggai zechariah malachi matthew mark luke john acts
romans 1_corinthians 2_corinthians galatians ephesians philippians
colossians 1_thessalonians 2_thessalonians 1_timothy 2_timothy titus
philemon hebrews james 1_peter 2_peter 1_john 2_john 3_john jude
revelation""".split()

# Text the tagged corpus has and we do not, that has been read individually and
# is NOT a loss on our side. Anything outside this set is new and fails the run.
#
# The seven real losses are absent on purpose: they are repaired
# (`tools/repair_tagged_witness_losses.py`), so if a re-import drops them again
# this should report them as new rather than swallow them as known.
EXPLAINED = {
    # Words the tagged import supplies that the printed 1919 does not have.
    # EVERY ONE OF THESE WAS CHECKED AGAINST THE PRINT, not against the two
    # witnesses. Two entries that were once on this list — 以斯帖記 6:7 and
    # 瑪拉基書 2:3 — turned out to be real losses that BOTH witnesses share,
    # so "the witnesses agree with us" is not grounds for dismissing a hit.
    "007015002": "tagged supplies 我请求; print reads 你可以娶來代替他罷",
    "007015005": "tagged supplies 葡萄园; print reads 並橄欖園盡都燒了",
    "007015018": "tagged supplies 现在; print reads 豈可任我渴死",
    "010021002": "tagged reads 大发热心; print reads 卻爲以色列人和猶大人發熱心",
    # Note and parenthesis restructuring — no character is missing.
    "006019002": "或名示巴 is a note in ours, a parenthesis in the tagged",
    "018014014": "或译：改变 is a note in ours, a parenthesis in the tagged",
    "018020019": "或译：强取房屋… is a note in ours, a parenthesis in the tagged",
    "064001014": "the v.15 marker is a note in ours, a parenthesis in the tagged",
    "019078061": "note marker placement; 手中 vs 中手 is the tagged transposition",
    # Duplicated or transposed runs on the TAGGED side. Ours matches the print.
    "003005007": "tagged 若若",
    "007016017": "tagged 心所藏的中",
    "009001007": "tagged 给哈拿以",
    "009020037": "tagged 箭箭",
    "010020003": "tagged 把王从前",
    "011010029": "tagged 买的来车",
    "011019018": "tagged 未未曾",
    "011021026": "tagged 可憎的恶的事",
    "012010005": "tagged 我们我们",
    "013021017": "tagged carries importer markup <WH的8687>",
    "013025008": "tagged 为的徒",
    "013025028": "tagged 第二十是一何提",
    "013027017": "tagged 管利未人基的是",
    "018031036": "tagged 敌我敌者",
    "024004022": "tagged carries importer markup <WH873我7>",
    "026005009": "tagged 可的事憎",
    "026032020": "tagged 被杀的中人",
    "026036001": "tagged 你要要对",
    "040009028": "tagged 耶稣说说",
    "042023041": "tagged 我们所的受",
    "018010021": "約伯記 10:21 is folded into 10:20 here and marked 见上节",
}

# Not a loss — the characters match as a multiset — but the ORDER differs from
# the print, and that is not something an unattended run should decide.
#
# 阿摩司書 6:8. We read 「主雅偉指着自己起誓，萬軍之神〈原文有雅偉〉說」. The
# print, witness A, witness B and the tagged corpus all read 「主耶和華萬軍之
# 神指着自己起誓說」, with 萬軍之神 BEFORE the oath and no note.
#
# It is filed here rather than repaired because the evidence points at a
# deliberate choice by this edition, not a corruption: the Hebrew is
# נִשְׁבַּע אֲדֹנָי יְהוִה בְּנַפְשׁוֹ נְאֻם יְהוָה אֱלֹהֵי צְבָאוֹת, where
# "YHWH God of hosts" follows "by himself" and attaches to נְאֻם — our order,
# not the print's. The note 「原文有雅偉」 marks exactly the second יְהוָה that
# the print renders as 神 alone. Reordering it would undo the divine-name
# restoration this whole edition exists to make. Queued for the user.
UNSETTLED = {
    "030006008": "萬軍之神 precedes the oath in the print and follows it here",
}


def load_tagged():
    out = {}
    for n, slug in enumerate(BOOKS, 1):
        book = json.loads((TAGGED / f"{slug}.json").read_text(encoding="utf-8"))
        for key, runs in book.items():
            chapter, verse = key.split(":")
            vid = f"{n:03d}{int(chapter):03d}{int(verse):03d}"
            out[vid] = "".join(r.get("w", "") for r in runs)
    return out


def han(text, *strip):
    for pattern in strip:
        text = pattern.sub("", text)
    return "".join(CJK.findall(text))


def main():
    ours = json.loads(OURS.read_text(encoding="utf-8"))
    tagged = load_tagged()

    differ = 0
    hits = []
    for row in ours:
        vid = row["id"]
        if vid not in tagged:
            continue
        mine = han(row["text"], *STRIP)
        theirs = han(tagged[vid], *STRIP)
        if mine == theirs:
            continue
        differ += 1
        extra = [
            theirs[j1:j2]
            for tag, i1, i2, j1, j2 in SequenceMatcher(
                None, mine, theirs, autojunk=False
            ).get_opcodes()
            if tag == "insert" or (tag == "replace" and j2 - j1 > i2 - i1)
        ]
        if extra:
            hits.append((vid, extra, row))

    known = EXPLAINED.keys() | UNSETTLED.keys()
    fresh = [h for h in hits if h[0] not in known]
    print(f"verses compared: {len(tagged)}")
    print(f"differ on ideographs: {differ}")
    print(f"  tagged reads MORE than we do: {len(hits)}")
    print(f"    read and explained: {sum(1 for h in hits if h[0] in EXPLAINED)}"
          f" of {len(EXPLAINED)}")
    print(f"    order differs, queued for the user: "
          f"{sum(1 for h in hits if h[0] in UNSETTLED)} of {len(UNSETTLED)}")
    print(f"    NEW, unexamined: {len(fresh)}")
    for vid, extra, row in fresh:
        print(f"\n{vid}  {row['book']} {row['chapter']}:{row['verse']}   "
              f"tagged adds {' '.join(repr(s) for s in extra)}")
        print(f"  ours  : {row['text']}")
        print(f"  tagged: {tagged[vid]}")

    # A triage note whose verse stops reading long is drift too: the text moved
    # under a decision that was made by reading it, and a stale entry can go on
    # to swallow a real hit at the same id.
    gone = sorted(known - {vid for vid, _, _ in hits})
    for vid in gone:
        print(f"\n{vid} no longer reads long — update EXPLAINED/UNSETTLED: "
              f"{EXPLAINED.get(vid) or UNSETTLED[vid]}")
    return 1 if fresh or gone else 0


if __name__ == "__main__":
    sys.exit(main())
