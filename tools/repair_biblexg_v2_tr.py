#!/usr/bin/env python3
"""Repair the 30 characters `assets/biblexg-v2-tr.json` converted wrong.

This edition ships in BOTH scripts — `biblexg-v2.json` (Simplified) and
`biblexg-v2-tr.json` (Traditional) — and the Traditional one was made
from the Simplified one. That is what makes it checkable without an
outside source: **the conversion's own decisions are the witness against
itself.** Align the two files verse by verse and every position where
they differ is a decision the converter made; where it made the same
decision 1,993 times and the opposite one 4 times, the 4 are the defect.

Every rule below is a NAMED SITE — a verse id plus a context string —
never a character sweep. `assets/cuvs-yhwh-tr.json` was damaged by a
conversion that resolved each character once instead of per word, and a
blanket `opencc -c s2t` over THAT file invents a defect at 以賽亞書 29:17
(「不是只有一點點時候嗎？」 becomes 隻有). So this script converts nothing
by default and asserts it recognised every occurrence it changed.

FOUR CLASSES, and they are not the same kind of error:

  A. A Simplified character SURVIVED the conversion (12 sites). The file
     converts 稣→穌 1,123×, 话→話 468×, 满→滿 167× … and missed one each.

  B. The conversion picked the wrong Traditional word (1 site).
     馬可福音 1:23 「在他們的會堂里有」 wants 裡. The file's other 45 里
     are all correct — 公里, 里拉琴, and proper names (提比里亞, 克里特,
     吉里吉亞, 貝里亞, 亞里達古, 堅革里, 以利里古) — so 里 itself is not
     the problem and must not be swept.

  C. The conversion went TOO FAR (4 sites), which the usual
     "Simplified survivor" screen structurally cannot see:
       准許 → 準許 ×3. 准 is to permit; 準 is accurate/standard. The
       file itself writes 准許 6×, and all 9 sources read 准许.
       蒙住 → 矇住 ×1. The source reads 蒙住; 矇 is for eyes and
       deception, and a covered face is 蒙. cuvs-yhwh-tr: 蒙住 3, 矇住 0.

  D. 舊字形 glyph stragglers (12 sites). Not meaning errors — 説 and 說
     are the same character — but a SEARCH defect: a reader who types
     開啟 finds 1 of this file's 4, and 他說過 misses 馬可福音 14:58.

Plus one the file settles against itself: 使徒行傳 7:32 「渾身顫斗」.
颤斗 is an upstream typo present in BOTH editions, but this same file
already writes 顫抖 at 馬可福音 16:8 from the identical Simplified
string, so it is repaired on the file's own precedent. The Simplified
edition is NOT touched — correcting the translator's text there is the
owner's call, and is reported instead.

WHAT IS DELIBERATELY LEFT ALONE, because the rule is "repair only what
the corpus witnesses" and these have no witness:
  一台戲 (1 Cor 4:9) — 台 is a valid classifier; the file's single 台 IS
    this site, so its own 29 臺 are not independent evidence.
  游手好閒 ×4, 包紥 ×1 — the standard forms 遊手好閒 and 包紮 appear
    ZERO times in this file and zero times in cuvs-yhwh-tr.
  托付 28 / 託付 2, 凶惡 2 / 兇惡 1, 一伙 6 / 一夥 3, 了解 13 / 瞭解 1,
  污 56 / 汙 1, 嘗 15 / 嚐 1 — both forms are attested Traditional.

Idempotent: the outputs match no input rule, so a second run is a no-op
and says so with exit 0.
"""

import argparse
import json
import sys

PATH = "assets/biblexg-v2-tr.json"

# (verse id, class, context BEFORE, context AFTER)
RULES = [
    # A — a Simplified character survived
    ("41014058", "A", "我要拆毁這座", "我要拆毀這座"),
    ("41014058", "A", "三天之内，另起", "三天之內，另起"),
    ("44018016", "A", "從审判臺前趕", "從審判臺前趕"),
    ("44020032", "A", "已經分别為聖", "已經分別為聖"),
    ("45010008", "A", "？這话就在眼前", "？這話就在眼前"),
    ("46014014", "A", "大腦是没有運作", "大腦是沒有運作"),
    ("51001009", "A", "旨意充满深刻", "旨意充滿深刻"),
    ("51003009", "A", "你們已經脱掉了", "你們已經脫掉了"),
    ("51004006", "A", "常常要温和", "常常要溫和"),
    ("56002003", "A", "上了年纪的婦女", "上了年紀的婦女"),
    ("56003015", "A", "在信仰内愛我們", "在信仰內愛我們"),
    ("66001001", "A", "<note:指耶稣基督>", "<note:指耶穌基督>"),
    # B — the wrong Traditional word
    ("41001023", "B", "在他們的會堂里有一個", "在他們的會堂裡有一個"),
    # C — the conversion went too far
    ("41005013", "C", "耶穌準許了他們", "耶穌准許了他們"),
    ("41008030", "C", "不準許他們告訴", "不准許他們告訴"),
    ("41010004", "C", "摩西準許，寫休書", "摩西准許，寫休書"),
    ("41014065", "C", "吐唾沫，矇住他的臉", "吐唾沫，蒙住他的臉"),
    # D — 舊字形 stragglers
    ("41014058", "D", "我們聽見他説過", "我們聽見他說過"),
    ("42007031", "D", "耶穌又説：", "耶穌又說："),
    ("44001010", "D", "站在旁邊説：", "站在旁邊說："),
    ("44018012", "D", "拉到審判臺前説：", "拉到審判臺前說："),
    ("46015003", "D", "所記，爲我們的罪", "所記，為我們的罪"),
    ("43008046", "D", "誰能指証我有罪", "誰能指證我有罪"),
    ("42024032", "D", "給我們開啓的時候", "給我們開啟的時候"),
    ("44014027", "D", "為外族開啓了", "為外族開啟了"),
    ("44017003", "D", "將經文逐一開啓，", "將經文逐一開啟，"),
    ("44020006", "D", "由腓立比啓航", "由腓立比啟航"),
    ("44021002", "D", "便上船啓程。", "便上船啟程。"),
    ("46016011", "D", "送他平安啓程", "送他平安啟程"),
    # E — the file already decided this one, one book earlier
    ("44007032", "E", "摩西渾身顫斗，", "摩西渾身顫抖，"),
]


def _defective_chars(old: str, new: str) -> set:
    """The characters this rule exists to remove.

    Both contexts are the same length in every rule here (each is a
    one-for-one character substitution inside identical surroundings),
    so the positions where they differ name the defect exactly.
    """
    if len(old) != len(new):
        return set(old) - set(new)
    return {a for a, b in zip(old, new) if a != b}


def main() -> int:
    # `--code biblexg-v3` points the same 30 named sites at the newer
    # fetch of the same translation. They are named by verse id and by
    # the exact string they expect to find, so a site that moved or that
    # the publisher has since corrected upstream FAILS LOUDLY rather
    # than being silently skipped — which is the reason the rules are
    # written this way and not as a character sweep.
    #
    # This step was missing from the v3 pipeline's first run, and the
    # 30 defects came straight back: 「在他們的會堂里」, 「耶穌準許」,
    # 「渾身顫斗」. `traditional_forms_test.dart` caught all five classes.
    ap = argparse.ArgumentParser()
    ap.add_argument("--code", default="biblexg-v2-tr",
                    help="traditional-script asset to repair, without "
                         "assets/ or .json")
    # 2026-09-18: the publisher started fixing these sites himself —
    # 梁牧師 ruled on 會堂裡 and the three 准許 and corrected his own
    # files — so a FRESH import can arrive with some sites already
    # right. Without this flag that mix still reads as a half-finished
    # run of this tool and refuses, which is the right answer for a file
    # this tool has touched. With it, the caller is asserting the file
    # came straight from `import_ljk2.py`, so a site already carrying the
    # corrected reading was corrected upstream: it is reported and
    # retired, and the rest are applied.
    ap.add_argument("--fresh-import", action="store_true",
                    help="the asset was just re-imported from the "
                         "publisher; already-correct sites are the "
                         "publisher's own fixes")
    args = ap.parse_args()
    path = f"assets/{args.code}.json"

    data = json.load(open(path, encoding="utf-8"))
    by_id = {r["id"]: r for r in data}

    todo, done, upstream = [], 0, []
    for vid, cls, old, new in RULES:
        rec = by_id.get(vid)
        if rec is None:
            print(f"FAIL: no verse {vid}", file=sys.stderr)
            return 1
        n = rec["text"].count(old)
        if n == 1:
            todo.append((vid, cls, old, new, rec))
        elif rec["text"].count(new) == 1:
            done += 1
            if args.fresh_import:
                upstream.append((vid, cls, old, new))
        elif not (_defective_chars(old, new) & set(rec["text"])):
            # Neither context matches AND the character this rule exists
            # to remove is nowhere in the verse.
            #
            # 2026-09-14, first seen on the v3 fetch: the publisher had
            # REWRITTEN 哥林多前書 15:3 — 「我領受了的，第一重要的就是：
            # 基督按照聖經所記」 became 「我領受的，第一重要的是：正如
            # 聖經所記，基督」 — and in doing so wrote 為 where the older
            # file had the 舊字形 爲. The site is correct; there is
            # nothing to repair and nothing has gone wrong.
            #
            # This is the ONLY safe way to retire a named site
            # automatically, and the condition is deliberately narrow:
            # if 爲 still stood anywhere in that verse the branch below
            # would fail instead, because then the rewrite would have
            # moved the defect rather than removed it.
            upstream.append((vid, cls, old, new))
        else:
            print(f"FAIL: {vid} matches neither rule nor result, and the "
                  f"character it targets is still in the verse: {old!r}",
                  file=sys.stderr)
            print(f"      verse now reads: {rec['text']}", file=sys.stderr)
            return 1

    for vid, cls, old, new in upstream:
        print(f"  class {cls} {vid}: fixed upstream, rule retired for this "
              f"edition ({old!r} -> {new!r})")

    if not todo:
        print(f"already repaired — all {done} sites carry the corrected reading, nothing to do")
        return 0
    if done and not args.fresh_import:
        print(f"FAIL: {done} sites already repaired but {len(todo)} are not; "
              "the file is half-converted, refusing to guess", file=sys.stderr)
        return 1

    counts = {}
    for vid, cls, old, new, rec in todo:
        rec["text"] = rec["text"].replace(old, new, 1)
        counts[cls] = counts.get(cls, 0) + 1

    # Byte-exact round trip: this asset ships as compact JSON with no
    # trailing newline. Reformatting it would bury 30 real edits inside a
    # whole-file diff.
    out = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    open(path, "w", encoding="utf-8").write(out)

    for cls in sorted(counts):
        print(f"  class {cls}: {counts[cls]} sites")
    print(f"repaired {len(todo)} sites in {len({t[0] for t in todo})} verses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
