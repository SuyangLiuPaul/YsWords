#!/usr/bin/env python3
"""Check WHICH WORD each translator's note is attached to, against the print.

Ours    assets/cuvs-yhwh-tr.json     `…遮羞<note: 原文作眼>的…`
Print   zh.wikisource.org            `…遮羞的{{*|羞原文作眼}}…`

A note in this edition says which original word underlies which Chinese word.
Attached to the wrong word it states something untrue about the text while
reading perfectly plausibly, which is the failure mode this repo cares about
most. Every existing audit compares the RUNNING TEXT and strips notes out
before comparing, so a note that moved has never been checked by anything.

**The two editions place notes by different conventions, and that is not a
defect.** The 1919 print sets its note after the whole phrase and NAMES the
word inside the note — 「遮羞的{{*|羞原文作眼}}」. The digital line ours
descends from drops the name and puts the note straight after the word —
「遮羞<note: 原文作眼>的」. Comparing raw positions therefore reports ~200
differences that are all one convention meeting the other.

So the check is not "is it in the same place" but **"is it on the same
word"**: take the word the printed note names, and require it to sit
immediately before our note. That is the thing a reader can be misled by, and
it is invariant to the convention.

Both sides are folded to Simplified with opencc before comparing, because the
print sets 爲/衞/喫/裏 where our edition sets 為/衛/吃/裡 — orthography, not
attachment.

Notes the print does not name a word for (「或作…」 alone, 「就是…的意思」)
cannot be checked this way and are counted, not judged.

**Adjacency alone is blind to the one case that matters, so there is a second
check.** When the named word occurs TWICE in the verse, "our note follows the
named word" is satisfied by either occurrence, and a note sitting on the wrong
one passes. That is exactly the shape of the only open case in the corpus
(那鴻書 3:4), so scoring it with the adjacency test would be circular. The
second pass compares WHICH OCCURRENCE the note follows on each side. 17 of the
18 such notes agree with the print; the eighteenth is held in UNSETTLED.

Cache of the printed text lives in /tmp/wscuv; delete it to re-fetch. Its
31,102 {{verse}} markers match our verse count exactly, so ids line up.
"""
import json
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = REPO / "assets/cuvs-yhwh-tr.json"
CACHE = Path("/tmp/wscuv")

BOOKS = """創世記 出埃及記 利未記 民數記 申命記 約書亞記 士師記 路得記
撒母耳記上 撒母耳記下 列王紀上 列王紀下 歷代志上 歷代志下 以斯拉記 尼希米記
以斯帖記 約伯記 詩篇 箴言 傳道書 雅歌 以賽亞書 耶利米書 耶利米哀歌 以西結書
但以理書 何西阿書 約珥書 阿摩司書 俄巴底亞書 約拿書 彌迦書 那鴻書 哈巴谷書
西番雅書 哈該書 撒迦利亞書 瑪拉基書 馬太福音 馬可福音 路加福音 約翰福音
使徒行傳 羅馬書 哥林多前書 哥林多後書 加拉太書 以弗所書 腓立比書 歌羅西書
帖撒羅尼迦前書 帖撒羅尼迦後書 提摩太前書 提摩太後書 提多書 腓利門書 希伯來書
雅各書 彼得前書 彼得後書 約翰一書 約翰二書 約翰三書 猶大書 啟示錄""".split()

CJK = re.compile(r"[一-鿿㐀-䶿]")
OUR_NOTE = re.compile(r"<note:([^>]*)>")
PRINT_NOTE = re.compile(r"\{\{\*\|([^}]*)\}\}")
VERSE_LINE = re.compile(r"^\{\{verse\|(\d+)\|(\d+)\}\}(.*)$")

# What separates the named word from the note body. Only the four that
# introduce a gloss OF A WORD. 「就是…的意思」 explains a whole name and
# 「下同」/「見」 are scope and cross-reference, not attachment.
MARKERS = ("原文作", "原文是", "原文用", "或作", "或譯")

# Verses read individually where our attachment differs from the print and is
# NOT wrong. Anything outside this set fails the run.
EXPLAINED = {}

# Read, argued both ways, and NOT settled by the data. Held here so the run
# stays green while nobody is entitled to change the verse on the strength of
# a count. Not the same thing as EXPLAINED: this is a recorded disagreement.
UNSETTLED = {
    # 那鴻書 3:4. 誘惑 occurs twice; ours attaches the note to the first, and
    # three external digital witnesses attach it to the second. The print
    # cannot arbitrate: it sets 「誘惑原文作賣」 at the END of the verse,
    # naming the word rather than pointing at an occurrence. Neither reading
    # is FALSE — the Hebrew has one gapped הַמֹּכֶרֶת governing both objects,
    # so both Chinese 誘惑 render the same verb. Our own tagged corpus is a
    # fourth line and agrees with us, but weakly: it carries the note inside
    # the run it tags, so its segmentation inherited the placement. Against
    # us: in the three OTHER verse-final printed notes naming a repeated word
    # (結 33:6, 結 33:8, 林後 3:6) our edition attaches to the LAST
    # occurrence, so this verse breaks our own habit. See the queue.
    "034003004": "誘惑 occurs twice; witnesses split and the print's note is "
                 "verse-final, so nothing arbitrates the occurrence",
}


def fetch(book):
    CACHE.mkdir(exist_ok=True)
    path = CACHE / f"{book}.txt"
    if path.exists() and path.stat().st_size > 500:
        return path.read_text(encoding="utf-8")
    title = urllib.parse.quote(f"聖經 (和合本)/{book}")
    url = f"https://zh.wikisource.org/w/index.php?title={title}&action=raw"
    req = urllib.request.Request(url, headers={"User-Agent": "yswords-audit"})
    raw = urllib.request.urlopen(req, timeout=60).read().decode("utf-8")
    path.write_text(raw, encoding="utf-8")
    time.sleep(0.3)
    return raw


def unwrap(text):
    """Drop wiki markup that is not scripture, keeping the words it wraps."""
    text = re.sub(r"\{\{udots\|([^}]*)\}\}", r"\1", text)   # 1919 side-dots
    text = re.sub(r"\{\{[Aa]nchor\|[^}]*\}\}", "", text)
    text = re.sub(r"-\{([^}]*)\}-", r"\1", text)            # no-convert marks
    return text.replace("{{!}}", "|").replace("{{-}}", "")


def fold(texts):
    """Traditional orthography differs between the two editions; fold it out."""
    joined = "\n".join(t.replace("\n", " ") for t in texts)
    out = subprocess.run(["opencc", "-c", "t2s"], input=joined.encode("utf-8"),
                         capture_output=True, check=True).stdout.decode("utf-8")
    lines = out.split("\n")
    assert len(lines) == len(texts), (len(lines), len(texts))
    return lines


def named_word(note):
    """The word a printed note glosses, or '' when it names none."""
    cut = min((note.find(m) for m in MARKERS if note.find(m) > 0), default=-1)
    return note[:cut] if cut > 0 else ""


def preceding(text, end, n):
    return "".join(CJK.findall(text[:end]))[-n:] if n else ""


def occurrence(text, note_re, note_start, word):
    """Which occurrence of `word` this note follows, counting from 1.

    Measured in the CJK-only stream of the note-STRIPPED verse, so note
    wording — which differs between the two editions — cannot move the count.
    A verse-final note follows the last occurrence, which is why a verse-final
    printed note says nothing about which one it means.
    """
    stripped = note_re.sub("", text)
    before = len(CJK.findall(note_re.sub("", text[:note_start])))
    pure = "".join(CJK.findall(stripped))
    hits = [i for i in range(len(pure)) if pure.startswith(word, i)]
    return sum(1 for i in hits if i + len(word) <= before), len(hits)


def main():
    ours = {r["id"]: r["text"]
            for r in json.loads(OURS.read_text(encoding="utf-8"))}

    printed = {}
    for n, book in enumerate(BOOKS, start=1):
        for line in fetch(book).splitlines():
            m = VERSE_LINE.match(line)
            if m:
                printed[f"{n:03d}{int(m.group(1)):03d}{int(m.group(2)):03d}"] = \
                    unwrap(m.group(3))

    shared = sorted(set(ours) & set(printed))
    print(f"{len(shared)} verses in both; {len(set(ours) - set(printed))} of "
          f"ours have no printed counterpart")

    # One opencc call for everything, in a fixed order.
    folded = dict(zip(shared, fold([ours[v] for v in shared])))
    folded_p = dict(zip(shared, fold([printed[v] for v in shared])))

    n_print = named = checked = repeated = 0
    unnamed, absent, wrong, split = 0, [], [], []
    for vid in shared:
        p_notes = list(PRINT_NOTE.finditer(folded_p[vid]))
        o_notes = list(OUR_NOTE.finditer(folded[vid]))
        n_print += len(p_notes)
        for m in p_notes:
            word = named_word(m.group(1).strip())
            if not word or len(word) > 4 or word not in folded[vid]:
                unnamed += 1
                continue
            named += 1
            if not o_notes:
                absent.append((vid, m.group(1).strip()))
                continue
            # If our note names the word itself, it points at its own referent
            # and cannot be read off the wrong one.
            if any(word in o.group(1) for o in o_notes):
                continue
            checked += 1
            # The print's own note follows the word plus whatever particle
            # closes the phrase — 「抱在懷中{{*|懷原文作手}}」 names 懷 and
            # sits after 懷中. Two characters of slack covers that and still
            # rejects a note sitting on a different occurrence of the word.
            window = len(word) + 2
            hits = [o for o in o_notes
                    if word in preceding(folded[vid], o.start(), window)]
            if not hits:
                wrong.append((vid, m.group(1).strip(), word,
                              [(o.group(1).strip(),
                                preceding(folded[vid], o.start(), 6))
                               for o in o_notes]))
                continue

            # Adjacency cannot tell two occurrences of the same word apart.
            p_occ, _ = occurrence(folded_p[vid], PRINT_NOTE, m.start(), word)
            o_occ, total = occurrence(folded[vid], OUR_NOTE, hits[0].start(),
                                      word)
            if total > 1:
                repeated += 1
                if p_occ != o_occ:
                    split.append((vid, m.group(1).strip(), word, p_occ, o_occ,
                                  total))

    print(f"printed notes {n_print}: {named} name a word, {unnamed} do not")
    print(f"checkable {checked}   ATTACHED ELSEWHERE {len(wrong)}   "
          f"we carry no note in that verse {len(absent)}")
    print(f"of the checkable, {repeated} name a word the verse uses more than "
          f"once   DIFFERENT OCCURRENCE {len(split)}")

    for vid, note in absent:
        print(f"   ABSENT {vid} print has {note!r}, we carry no note here")
    for vid, note, word, mine in wrong:
        flag = "   " if vid in EXPLAINED else "!! "
        print(f"{flag}{vid} print names {word!r} in {note!r}")
        for text, before in mine:
            print(f"        ours {text!r} after {before!r}")
    for vid, note, word, p_occ, o_occ, total in split:
        flag = "   " if vid in UNSETTLED else "!! "
        print(f"{flag}{vid} {note!r}: {word!r} occurs {total}x — print after "
              f"#{p_occ}, ours after #{o_occ}")

    fails = ([v for v, *_ in wrong if v not in EXPLAINED]
             + [v for v, *_ in split if v not in UNSETTLED])
    if fails:
        print(f"\n{len(fails)} notes are attached differently from the print. "
              f"Read each one against it before writing anything.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
