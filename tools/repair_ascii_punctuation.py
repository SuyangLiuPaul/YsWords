#!/usr/bin/env python3
"""Replace or remove the 55 half-width ASCII punctuation marks in running scripture.

Both reading editions carry ASCII marks in the running text of 50 verses, where
the corpus sets full-width CJK punctuation 108,000 times over. They are import
residue, not a punctuation choice: 創世紀 6:11 reads 「滿了強暴.。」 with the
period AND the 句號; 民數記 24:17 reads 「毀壞擾亂.之子」 mid-phrase; 撒迦利亞書
14:1 opens with 「, 雅偉的日子」.

Nothing here changes a CJK character — the run asserts that the ideograph
stream of every verse is byte-identical before and after, which is what keeps a
punctuation repair from ever becoming a claim about the text.

Two witnesses were read for every position: the plain 和合本 Traditional
(git blob 7a2dc43) and the Wikisource transcription of the printed 1919
(/tmp/wscuv, built by tools/audit_note_placement.py).

**SeekSparks' import is not a third witness here, though it is one elsewhere.**
It carries this same defect: 222 of its verses hold ASCII marks in running
text, and of the 26 verses it shares with our 50, 25 hold a byte-identical
mark sequence. It descends from whatever produced the artifact, so on this
class it is a copy of the accused, not testimony. It is still used at 西番雅書
1:1, which is one of the positions it does *not* share.

Four actions, and which one applies was decided per position, never by rule:

  * **Width** — the mark is right and only its width is wrong. `!`→！ `:`→：
    `;`→； `,`→， `()`→（）. Every one is confirmed by the witness carrying the
    full-width mark in the same slot, or by our own edition's habit where the
    witness punctuates differently (約伯記 6:8 ends `!` where the witness sets
    ；— ours is an edition choice and stays, at the right width).
  * **Stray** — no witness has any mark there and the position is one no
    Chinese punctuation can occupy: a period between 擾亂 and 之子, a comma
    directly after 「 or after ：, a `)` with no opener inside 「我為)我的名」.
    Deleted.
  * **Degraded** — the mark stands exactly where a full-width one belongs and
    the witnesses read it there. One position only: 路加福音 8:12, below.
  * **Bracket** — 路加福音 8:45 opens 〔有古卷在此有：…〕 and closes it with
    `)`. All eleven other 〔…〕 spans in the corpus close with 〕.

**The eight ASCII double quotes are deliberately NOT touched, after a first
pass converted them and had to be undone.** They sit in the running-text
parentheticals of 撒迦利亞書 1:3, 8:14, 10:1 and 10:12 — `（原文有 "萬軍之雅偉說"）`
— and the case for widening them was that the running-text parentheticals read
6/6 「」. That population was drawn wrong. Those six are quoted speech and
translation glosses (「以馬內利」翻出來就是…); the eight are the 原文 apparatus,
and *its* convention is ASCII by 157 to 7 across the 528 notes that carry it.
Widening the eight would make them disagree with 157 of their own kind. The
count that looked decisive — `"` byte-identical at 344 in both editions —
decides nothing either: a 1:1 Simplified/Traditional map preserves every count,
which is why 「 and “ also stand at 3,439 apiece. Whether this corpus should
speak 原文 apparatus in ASCII at all is a real question, and it belongs to the
user, not to a punctuation sweep. Filed in the queue.

Re-runnable. Refuses on any drift: every mark must be the character the table
says it is, in the order the table gives, or nothing is written.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
EDITIONS = ("assets/cuvs-yhwh-tr.json", "assets/cuvs-yhwh.json")

NOTE = re.compile(r"<note:.*?>")
BRACKET = re.compile(r"\[[^\]]{1,6}\]")   # [雅偉] / [基督] — a deliberate convention
CJK = re.compile(r"[一-鿿㐀-䶿]")
MARKS = ".,!;:()"   # `"` is the apparatus quote — see the docstring, and leave it

# Actions, per verse, in the order the marks appear in the running text.
KEEP, EAT_AFTER = 0, 1   # what to do with the space after the mark
D = ("", KEEP)           # delete
DS = ("", EAT_AFTER)     # delete, and the space after it

TABLE = {
    # ---- stray ASCII period: no witness has a mark at any of these ----
    "001006011": [(".", D)],    # 創 6:11  滿了強暴.。
    "004024017": [(".", D)],    # 民 24:17 毀壞擾亂.之子
    "004025015": [(".", D)],    # 民 25:15 這蘇珥是米甸.一個宗族
    "004030004": [(".", D)],    # 民 30:4  就都要為定.。
    "010008004": [(".", D)],    # 撒下 8:4 留下一百輛車.的馬
    "010019008": [(".", D)],    # 撒下 19:8 各回各家.去了
    "013002008": [(".", D)],    # 代上 2:8 是亞撒利雅.。
    "017009026": [(".", D)],    # 斯 9:26  照著普珥.的名字
    "018032007": [(".", D)],    # 伯 32:7  當以智慧.教訓人
    "019069025": [(".", D)],    # 詩 69:25 住處變為.荒場
    "020004007": [(".", D)],    # 箴 4:7   必得聰明.<note: …>
    "020013009": [(".", D)],    # 箴 13:9  的燈要熄滅.。
    "020031011": [(".", D)],    # 箴 31:11 不缺少利益.；
    "026042017": [(".", D)],    # 結 42:17 北面五百肘，.
    "040024030": [(".", D)],    # 太 24:30 有大榮耀.，駕著
    "041015016": [(".", D)],    # 可 15:16 全營的兵.。
    "044005012": [(".", D)],    # 徒 5:12  所羅門的廊下.。
    "066016020": [(".", D)],    # 啟 16:20 眾山也不見了.。

    # ---- degraded 句號: the witnesses set 。 in this exact slot ----
    "042008012": [(".", ("。", KEEP))],   # 路 8:12  信了得救.  (see NOTE below)

    # ---- half-width mark, right mark, wrong width ----
    "001043014": [("!", ("！", KEEP))],   # 創 43:14 就喪了吧!」
    "001043029": [("!", ("！", KEEP))],   # 創 43:29 願神賜恩給你!」
    "001044010": [("!", ("！", KEEP))],   # 創 44:10 照你們的話行吧!在
    "001044017": [("!", ("！", KEEP))],   # 創 44:17 我斷不能這樣行!在
    "018006008": [("!", ("！", KEEP))],   # 伯 6:8   賜我所切望的!
    "018039025": [("!", ("！", KEEP))],   # 伯 39:25 它說『阿哈!』
    "029001015": [("!", ("！", KEEP))],   # 珥 1:15  哀哉!雅偉的日子
    "041014045": [("!", ("！", KEEP))],   # 可 14:45 說：「拉比!」
    "052001001": [("!", ("！", KEEP))],   # 帖前 1:1 平安歸與你們!

    "042018037": [(":", ("：", KEEP))],   # 路 18:37 他們告訴他:「
    "044001024": [(":", ("：", KEEP))],   # 徒 1:24  眾人就禱告說:「
    "045004018": [(":", ("：", KEEP))],   # 羅 4:18  正如先前所說:「

    "052002013": [(";", ("；", KEEP))],   # 帖前 2:13 就領受了;不以為

    "029001011": [(",", ("，", KEEP))],   # 珥 1:11  你們要慚愧,修理
    "040012033": [(",", ("，", KEEP))],   # 太 12:33 或以為樹,好
    "040026049": [(",", ("，", KEEP))],   # 太 26:49 「請拉比安」,就
    "041001005": [(",", ("，", KEEP)),    # 可 1:5   耶路撒冷的人,都出去
                  (",", ("，", KEEP)),    #          到約翰那裏,承認
                  (",", ("，", KEEP))],   #          他們的罪,在約但河
    "044027016": [(",", ("，", KEEP))],   # 徒 27:16 那島名叫高大,在那裏
    "048001020": [(",", ("，", KEEP))],   # 加 1:20  我寫給你們的,不是謊話
    "038002004": [(",", ("，", EAT_AFTER))],    # 亞 2:4   告訴那少年人, 說
    "038005003": [(",", ("，", EAT_AFTER)),     # 亞 5:3   凡偷竊的, 必按
                  (",", ("，", EAT_AFTER))],    #          凡起假誓的, 必按

    "001048007": [("(", ("（", KEEP)),    # 創 48:7  路上(以法他就是伯利恆)
                  (")", ("）", KEEP))],
    "018031018": [("(", ("（", KEEP)),    # 伯 31:18 (從幼年時…寡婦。)
                  (")", ("）", KEEP))],

    # ---- stray comma, in a slot no Chinese punctuation can occupy ----
    "038003009": [(",", DS)],   # 亞 3:9   萬軍之雅偉說：, 我要   — after ：
    "038012002": [(",", DS)],   # 亞 12:2  「, 我必使耶路撒冷      — after 「
    "038014001": [(",", DS)],   # 亞 14:1  , 雅偉的日子臨近        — verse-initial

    # ---- stray closing paren with no opener ----
    "023048009": [(")", D)],    # 賽 48:9  我為)我的名暫且忍怒
    "023056004": [(")", D)],    # 賽 56:4  那些)謹守我的安息日
    "036001001": [(")", D)],    # 番 1:1   亞瑪利雅的曾孫)基大利   (see NOTE below)
    "041015013": [(")", D)],    # 可 15:13 )他們又喊著說           — verse-initial

    # ---- wrong bracket for an opener the verse itself sets ----
    "042008045": [(")", ("〕", KEEP))],   # 路 8:45  〔有古卷在此有：…?)
}

# NOTE 路加福音 8:12 is the one position where "degraded" beats "stray", and it
# was nearly deleted with the other eighteen. What separates it is not that a 。
# would look right there — it is that both witnesses put one there, ending the
# verse 得救。at that exact offset. The eighteen deletions have no such backing:
# they land mid-phrase, or immediately before a 。 the verse already sets. The
# "the corpus ends verses bare elsewhere" argument does not rescue deletion
# either — of the 106 bare endings, 70 are 見上節 placeholders, and the
# witnesses terminate 22 of the 36 that remain.
#
# NOTE 西番雅書 1:1. Deleting leaves 「亞瑪利雅的曾孫基大利的孫子」. Witness
# 7a2dc43 sets ，there, and our own verse sets ，after the neighbouring links of
# the same genealogy, so ，has a real case. Two things decide for bare: the
# printed 1919 punctuates the whole chain bare, and SeekSparks — which does
# *not* carry the stray `)` at this verse, so it is testimony here — reads
# 曾孫基大利 too. But deleting a `)` and adding a ，are separate acts, and only
# the first is a punctuation repair. The ，is filed in the queue for the user.


def running(text):
    """The text a reader sees as scripture, with apparatus markup removed."""
    return BRACKET.sub("", NOTE.sub("", text))


def repair(text, actions):
    """Apply `actions` to the running-text ASCII marks of `text`, in order."""
    out = []
    i = 0
    pending = list(actions)
    while i < len(text):
        skip = NOTE.match(text, i) or BRACKET.match(text, i)
        if skip:
            out.append(skip.group(0))
            i = skip.end()
            continue
        ch = text[i]
        if ch in MARKS:
            if not pending:
                raise SystemExit(f"more marks than the table lists: …{text[i - 8:i + 8]}…")
            want, (repl, eat) = pending.pop(0)
            if ch != want:
                raise SystemExit(f"expected {want!r}, found {ch!r}: …{text[i - 8:i + 8]}…")
            out.append(repl)
            i += 1
            if eat == EAT_AFTER:
                if i >= len(text) or text[i] != " ":
                    raise SystemExit(f"no space to absorb after {want!r}")
                i += 1
            continue
        out.append(ch)
        i += 1
    if pending:
        raise SystemExit(f"table lists {len(pending)} marks the verse does not have")
    return "".join(out)


def main():
    total = 0
    for rel in EDITIONS:
        path = REPO / rel
        verses = json.loads(path.read_text(encoding="utf-8"))
        changed = 0
        for v in verses:
            actions = TABLE.get(v["id"])
            if not actions:
                continue
            before = v["text"]
            if not any(c in MARKS for c in running(before)):
                continue                      # already repaired — idempotent
            after = repair(before, actions)
            if "".join(CJK.findall(before)) != "".join(CJK.findall(after)):
                raise SystemExit(f"{v['id']} would change an ideograph — refusing")
            v["text"] = after
            changed += 1

        left = [v["id"] for v in verses if any(c in MARKS for c in running(v["text"]))]
        if left:
            raise SystemExit(f"{rel}: {len(left)} verses still hold ASCII marks: {left[:5]}")

        if changed:
            path.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
                            encoding="utf-8")
        print(f"{rel}: {changed} verses repaired")
        total += changed
    if not total:
        print("nothing to do — both editions are already clean")


if __name__ == "__main__":
    sys.exit(main())
