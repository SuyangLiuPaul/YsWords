#!/usr/bin/env python3
"""Fix wrong one-to-many expansions in the Traditional Strong's lexicon.

A DIFFERENT DEFECT FROM THE VERSE ASSET, THOUGH IT LOOKS THE SAME
  Every fix so far has been a converter HOLE in `assets/cuvs-yhwh-tr.json` — a
  Traditional form the converter could not write at all (隻, 淨, 牆, 餘, 癒 …),
  found by "our asset holds zero of it". `assets/strongs/{hebrew,greek}.json`
  has no holes: `glossZhTw`/`defZhTw` are `opencc -c s2t` of `glossZh`/`defZh`,
  character for character, in 28,276 of the 28,377 field pairs. Remeasured
  2026-08-23 by `tools/audit_lexicon_provenance.py`, which also rules out
  s2tw/s2twp/s2hk — each matches only ~89%, so the configuration is pinned and
  not merely the tool.

  CORRECTION, 2026-08-23. This paragraph used to end "with ZERO manual edits in
  all 28,377 field pairs (verified by re-converting every Simplified field and
  comparing)", and that was already false when it was written. 109 characters
  in 101 fields disagree with opencc: 88 侖 → 崙 (cf0782d, 14:03) and 21
  侄 → 姪 (ca09531), both of which landed hours before this file did at 14:15
  the same afternoon. Nothing was damaged, because none of the rules below
  touches either character — but a later pass reasoning "the lexicon has never
  been hand-edited, so reconverting it is safe" would spell Hebron 希伯侖 again.
  The audit enumerates the exceptions instead of assuming there are none.

  So the exposure here runs the other way. opencc never fails to convert; it
  fails by picking the WRONG expansion when one Simplified character maps to
  several Traditional ones, and apart from those two repairs the file has never
  been hand-edited, so every one of those mistakes is still in it. An inventory diff cannot see this —
  the character it wrote is a perfectly good Traditional character, just not
  the right one.

WHAT IT ACTUALLY PRINTS TODAY
  Names first, because a study tool that misspells a Bible name is the worst
  case. 亞干 (Achan, 書 7) is printed THREE different ways across the file —
  亞乾, 亞幹 and never 亞干 — and 亞多尼干, 雅干, 瑪拉干 are all mangled too.
  Our own `assets/cuvs-yhwh-tr.json` spells all four with 干 (亞干 ×17,
  亞多尼干 ×3, 雅干 ×1, 瑪拉干 ×1) and holds ZERO of the 乾/幹 forms, so the
  app currently contradicts itself between the reader and the lexicon.

  Then plain wrong words: 幹物 for a dry measure (乾), 幹河谷 for a wadi (乾),
  變幹/幹掉 for drying up (乾), 被幹擾 for being dismayed (干), 被髮出 for
  being sent out (發 — 髮 is hair), 徵服 for conquest (征), 裏海 for the
  Caspian Sea and 莫丘裏 for Mercurius (both 里, a name, not the locative 裏),
  and 睏倦/疲睏 for weariness (困 — 睏 is drowsiness).

HOW EACH POSITION WAS DECIDED — FROM THE SIMPLIFIED SOURCE, NOT FROM A RULE
  All 193 source positions of 干 were enumerated and classified against the
  Simplified text that produced them, which is unambiguous about the sense:
  乾 dry ×146, 干 to interfere / a name ×20, 幹 trunk or to do ×17 (樹幹, 枝幹,
  主幹, 幹活 — all correct already and left alone). 29 of the 193 were wrong.
  The remaining 14 corrections are single readings, each read in full context.

  Every ambiguous class opencc touched in these two files was surveyed the
  same way, not just 干 — 谷/穀, 发/髮, 里/裏, 松/鬆, 系/係/繫, 台/臺, 只/隻,
  斗/鬥, 扎/紮, 占/佔, 云/雲, 岳/嶽, 征/徵, 游/遊, 布/佈, 范/範, 咸/鹹,
  困/睏, 折/摺, 钟/鐘, 术/術, 虫/蟲, 向/嚮, 丑/醜. 岳父/岳母 (×38) and
  掙扎 are correctly left alone by opencc; 谷→穀 is right in all 78 (every one
  is grain, every valley stayed 谷). Only the readings below came out wrong.

CORROBORATION FOR THE HOUSE ORTHOGRAPHY
  `assets/cuvs-yhwh-tr.json`, which earlier instalments verified position by
  position against an independent edition, is the app's own Traditional
  standard: it writes 困倦 ×9 and ZERO 睏, 發出 ×106 and ZERO 髮出, and the four
  names with 干. It contains no 里 at all (和合本 has no 公里/里海), so it
  cannot speak to 里海 or 莫丘里 — those rest on 里 being the standard modern
  rendering of Caspian/Mercurius in both scripts, and on 裏 being the locative
  "inside", which neither is.

SCOPE
  Traditional fields only. The Simplified `glossZh`/`defZh` are the source of
  truth for the sense and this script refuses if it touches them. Every
  substitution is one character for one character, so no field changes length.

STATUS: APPLIED 2026-09-03 — 89 substitutions across 84 fields.
  It was written on 2026-08-18 alongside the 崙 instalment and committed
  UNAPPLIED so that one defect shipped at a time. Before applying it, all 39
  substitutions of that first survey were re-verified one at a time against
  their Simplified twin — the twin is printed beside every reading, and all 39
  agree. The queue item's second list ("found and NOT yet fixed") was verified
  the same way and folded in as the 2026-09-03 block below, 50 more.
  `test/strongs_traditional_ambiguous_test.dart` pins the result in both
  directions, so a re-import cannot silently undo it.

  Re-running is a no-op: with every rule at zero matches and every repaired
  reading present, the script prints "already applied" and exits 0. A file that
  is half-repaired is still refused, because that is a real problem.

TWO OF THE QUEUE ITEM'S PROPOSALS WERE REFUTED HERE and are NOT applied:
  * 複合 → 復合 as a blanket rule. 複合字 (a COMPOUND WORD) at H1767, H3050,
    H8478, G4452 and G4863 is correct and stays; only G604's 和好, 複合
    (reconciliation) moves, and its twin reads 和好, 复合 while theirs read
    复合字. Five of the seven would have been corrupted.
  * 回覆 → 回復 as a blanket rule. G611, G612 and G627 keep 回覆 because their
    SIMPLIFIED fields also read 回覆 — the source itself wrote the Traditional
    character, so opencc never chose it and there is nothing to repair. Only
    the three whose twin reads 回复 move. Six of the ten would have been wrong.
  Both traps have the same shape and it is the shape this whole item turns on:
  **the twin is the witness, and a rule about the language is not.**

ONE CANDIDATE IS DELIBERATELY LEFT ALONE: H6867 「傷愈的疤」. It belongs to the
愈/癒 spin-off item, which is filed separately; repairing it here would close
that item as a side effect of this one.

ONE RULE IN THE FIRST DRAFT WAS WRONG AND IS NOW DISARMED, recorded because
the reasoning was seductive: 裏海 → 里海 ×4, on the theory that 裏 is only the
locative "inside" and a sea's name should take 里. False. 裏海/裡海 IS the
standard Traditional name for the Caspian — literally the "inner sea" — this
file already sets 裏 273 times, and G3934 already reads 里海, so if anything
the edit runs the other way. It is commented out below rather than deleted, so
that a later pass does not rediscover it and re-add it.

Dry-run by default; --apply writes. Re-running after --apply is safe.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = (ROOT / "assets/strongs/hebrew.json", ROOT / "assets/strongs/greek.json")
TW_FIELDS = ("glossZhTw", "defZhTw")

# (wrong, right, expected count, why). Counted across both files together.
# Order matters only in that no rule's output feeds another's input; checked.
RULES = (
    # --- proper names: 干 is a name syllable, never 乾 (dry) or 幹 (trunk) ---
    ("亞多尼幹", "亞多尼干", 1, "Adonikam — 拉 2:13"),
    ("亞多尼乾", "亞多尼干", 2, "Adonikam — 拉 8:13"),
    ("亞乾", "亞干", 3, "Achan — 書 7:1"),
    ("亞幹", "亞干", 1, "Achan — 書 7:24 (亞割谷)"),
    ("瑪拉幹", "瑪拉干", 3, "Malcam — 代上 8:9"),
    ("雅幹", "雅干", 1, "Jaakan — 代上 7:34"),
    ("伯・哈幹", "伯・哈干", 1, "Beth-haggan — 王下 9:27, transliterated gan"),
    # --- 乾 is dry; 幹 is a trunk or to do ---
    ("幹物", "乾物", 6, "dry measure — ephah, bath, homer, cab"),
    ("幹河", "乾河", 5, "wadi / winter torrent — H650, H1308, G5493"),
    ("變幹", "變乾", 2, "H2717 חָרֵב to become dry"),
    ("幹掉", "乾掉", 2, "H2717 חָרֵב to dry up"),
    ("被幹涸", "被乾涸", 1, "H5405 — 賽 19:5"),
    # --- 干 is to interfere; 幹 is not ---
    ("被幹擾", "被干擾", 1, "H926 בָּהַל to be dismayed"),
    # --- 發 is to send forth; 髮 is hair ---
    ("被髮出", "被發出", 1, "H7972 שְׁלַח to be sent"),
    # --- 征 is to campaign; 徵 is to levy or a sign ---
    ("徵服", "征服", 1, "H8478 — conquest"),
    # --- 里 in a name; 裏 is the locative "inside" ---
    # REFUTED, DO NOT RE-ADD: ("裏海", "里海", 4, "the Caspian Sea") — 裏海/裡海
    # is the standard Traditional name for the Caspian, the "inner sea". See the
    # docstring. Deliberately left visible rather than deleted.
    ("莫丘裏", "莫丘里", 2, "Mercurius — G2060, 徒 14:12"),
    # --- 困 is weariness; 睏 is drowsiness ---
    ("睏倦", "困倦", 4, "H3288, G2872"),
    ("疲睏", "疲困", 2, "G2577 — 來 12:3"),

    # === SECOND INSTALMENT, 2026-09-03 =====================================
    # The rules above were surveyed on 2026-08-18 and left unapplied. The queue
    # item listed a further batch as "found and NOT yet fixed"; each was
    # re-verified here against its Simplified twin, position by position, in
    # the same way, and they are folded in so that the lexicon takes ONE pass
    # rather than two. Nothing above changed.
    #
    # --- 辟 in a name; 闢 is to open up ---
    ("闢拉", "辟拉", 7, "Bilhah — twin 辟拉; cuvs-yhwh-tr spells 辟拉 ×11, 闢拉 ×0"),
    # --- 並 is "and / also"; 併 is to merge. The negative lookbehind is the
    #     whole point: 合併爲 ×2 at G2957 (Crete merged into one province) is
    #     a genuine 併 and must not move. Its twin reads 合并为.
    (r"(?<!合)併爲", "並爲", 19, "and/also — twin reads 并为 in all 19"),
    ("併成爲", "並成爲", 1, "H4353 — twin 并成为"),
    # --- 復 is to return / restore; 覆 is to reply or to cover ---
    #     Only where the TWIN reads 回复. G611, G612 and G627 keep 回覆 because
    #     their Simplified fields ALSO read 回覆 — the source itself wrote the
    #     Traditional character there, so opencc never chose it and there is
    #     nothing to repair. Longer literals are used instead of a bare 回覆 so
    #     the rule cannot reach them.
    ("漸漸回覆", "漸漸回復", 1, "H5025 — twin 渐渐回复, land reverting"),
    ("一年的回覆", "一年的回復", 1, "H8666 — twin 一年的回复, spring"),
    ("回覆與先前", "回復與先前", 2, "G330 — twin 回复与先前"),
    ("被複興", "被復興", 1, "H7725 — twin 被复兴"),
    ("和好, 複合", "和好, 復合", 2, "G604 — twin 和好, 复合. KEEP 複合字 "
                                  "(compound word) at H1767/H3050/H8478/"
                                  "G4452/G4863, which is a different word"),
    # --- 參 is to join; 蔘 is ginseng ---
    ("蔘加", "參加", 1, "H4918 — twin 参加"),
    # --- 麪 is flour. This file's house form is 麪 (55) and it holds ZERO 麵,
    #     so 細麪 rather than the CUV's 細麵. Internal convention wins, as it
    #     did for the 松開 leftover in biblexg-v2-tr.
    ("細面", "細麪", 2, "H5560 fine flour — twin 细面"),
    # --- 穀 is grain; 谷 is a valley ---
    ("新谷", "新穀", 1, "H1061 — bread of firstfruits made from new grain"),
    # --- 鬚 is a tendril or a beard; 須 is "must". opencc has a phrase rule
    #     for 卷须→卷鬚 but not for these, so it wrote the default 須.
    ("葡萄藤的須", "葡萄藤的鬚", 2, "H5189 — twin 葡萄藤的须, beside 卷鬚"),
    ("帶須的兀鷹", "帶鬚的兀鷹", 1, "H6538 — the bearded vulture"),
    # --- 裏 is the locative "inside"; 里 is a distance unit or a name.
    #     These are the UNDER-conversions: opencc left the Simplified locative
    #     里 alone. Every other 里 in the file is 底格里斯 / 克里特 / 西西里 /
    #     暗妃波里 / 西里西亞 / 一里 / 二十五里 / 萬里晴空 and is correct.
    ("谷里的", "谷裏的", 2, "H2574 — Orontes valley"),
    ("文本里", "文本裏", 1, "G4270"),
    ("公會里", "公會裏", 2, "G4245, G2491"),
    ("聖經里", "聖經裏", 1, "G4245"),
    ("抄本里", "抄本裏", 2, "G962"),
    ("丟入海里", "丟入海裏", 1, "G4067 — into the sea, not a nautical mile"),
)

EXPECTED_TOTAL = sum(r[2] for r in RULES)

# Readings where the character this script removes is CORRECT and must survive.
# If any of these stops being present the survey behind the rules is stale.
#
# The second block is the keep list of the 2026-09-03 instalment, and it is the
# dangerous half: every one of these is a near-miss for a rule directly above
# it, so if a later widening of a pattern starts eating them this list is what
# says so.
MUST_SURVIVE = ("樹幹", "枝幹", "主幹", "幹活", "岳父", "岳母", "掙扎",
                "打穀場", "頭髮", "船隻", "關係", "介係詞", "紮營", "佔領",
                # 2026-09-03
                "合併爲",      # G2957 — Crete merged into one province: 併
                "複合字",      # compound WORD — a different word from 復合
                "回覆, 答覆",  # G612 — its Simplified twin also reads 回覆
                "底格里斯",    # a name, so 里 and never 裏
                "克里特",      # likewise
                "卷鬚",        # H5189 — opencc got this one right
                "萬里晴空")    # a distance idiom, so 里


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    docs = {p: json.loads(p.read_text(encoding="utf-8")) for p in FILES}
    simplified_before = {
        p: [(k, f, e[f]) for k, e in d.items() for f in ("glossZh", "defZh")
            if f in e]
        for p, d in docs.items()
    }
    joined_before = "".join(
        e[f] for d in docs.values() for e in d.values()
        for f in TW_FIELDS if f in e)

    for reading in MUST_SURVIVE:
        if reading not in joined_before:
            print(f"  ✗ {reading} is absent — the survey behind these rules no "
                  f"longer matches the data — refusing")
            return 1

    # `wrong` is a regular expression, so that 併爲 can exclude 合併爲 with a
    # lookbehind. Every other rule is a plain literal, which is its own regex.
    patterns = [(re.compile(w), w, r, n, why) for w, r, n, why in RULES]

    # Idempotence. A second --apply must be a no-op rather than a refusal:
    # zero matches left AND the repaired reading present at least as often as
    # the rule expected means this ran already. Anything in between is a
    # half-applied file and IS refused, because that is a real problem.
    live = [(w, rx, r, n) for rx, w, r, n, _ in patterns
            if len(rx.findall(joined_before)) != 0]
    if not live:
        settled = all(joined_before.count(r) >= n for _, _, r, n, _ in patterns)
        if settled:
            print("  already applied — nothing to do")
            return 0
        print("  ✗ every rule matches zero times but the repaired readings "
              "are not all present — refusing")
        return 1

    for rx, wrong, right, expected, _ in patterns:
        n = len(rx.findall(joined_before))
        if n != expected:
            print(f"  ✗ {wrong} appears {n} times, expected {expected} — the "
                  f"data has moved under this script — refusing")
            return 1

    changed = 0
    report: list[str] = []
    for p, d in docs.items():
        for sid, entry in d.items():
            for field in TW_FIELDS:
                text = entry.get(field)
                if not text:
                    continue
                original = text
                for rx, wrong, right, _, _ in patterns:
                    while True:
                        m = rx.search(text)
                        if not m:
                            break
                        i = m.start()
                        report.append(
                            f"{p.name}\t{sid}\t{field}\t{m.group(0)}→{right}\t"
                            f"…{text[max(0, i - 10):m.end() + 8]}…"
                            .replace("\n", "/"))
                        text = text[:i] + right + text[m.end():]
                if text != original:
                    changed += 1
                    if len(text) != len(original):
                        print(f"  ✗ {sid} {field} changed length — refusing")
                        return 1
                    entry[field] = text

    joined_after = "".join(
        e[f] for d in docs.values() for e in d.values()
        for f in TW_FIELDS if f in e)

    if len(joined_before) != len(joined_after):
        print("  ✗ the Traditional text changed length — refusing")
        return 1
    if len(report) != EXPECTED_TOTAL:
        print(f"  ✗ {len(report)} substitutions against {EXPECTED_TOTAL} "
              f"expected — refusing")
        return 1
    for rx, wrong, _, _, _ in patterns:
        if rx.search(joined_after):
            print(f"  ✗ {wrong} survives the repair — refusing")
            return 1
    for p, d in docs.items():
        now = [(k, f, e[f]) for k, e in d.items() for f in ("glossZh", "defZh")
               if f in e]
        if now != simplified_before[p]:
            print(f"  ✗ {p.name}: a Simplified field changed — refusing")
            return 1

    print(f"  {len(report)} substitutions across {changed} fields "
          f"in {len(FILES)} files")
    for wrong, right, expected, why in RULES:
        print(f"    {wrong} → {right}   \u00d7{expected:<2}  {why}")

    if args.apply:
        for p, d in docs.items():
            p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n",
                         encoding="utf-8")
            print(f"  written → {p.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
