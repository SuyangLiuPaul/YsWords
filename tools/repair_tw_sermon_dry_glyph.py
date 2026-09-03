#!/usr/bin/env python3
"""Restore 乾 (dry) and 干 (to interfere) in the Traditional sermon transcripts,
where the converter wrote 幹.

THIS IS NOT ANOTHER INSTALMENT OF THE CUV CONVERTER HOLE, AND THE DIFFERENCE
MATTERS — the queue says so twice and it is right. `assets/sermons/zh-TW/` was
produced by a **phrase-aware** converter that does not have the hole: it holds
隻 453, 淨 358, 牆 257, 餘 190, 髮 121, 鬆 133, 採 80, and all three of
干 41 / 乾 164 / 幹 142 — plus ZERO of the leftovers 凈, 墻, 余. So none of the
`tools/repair_tr_*.py` scripts applies here, and running one would do damage.
What this corpus has instead is spot errors, and this file fixes one class of
them.

THERE IS NO WITNESS FOR SERMON TEXT, so nothing here rests on an edition.
Every one of the 18 rests on its own sentence, and each sentence is quoted in
the rule table below. That is the only evidence available and it has to be
enough — which is why the rules are anchored strings rather than a pattern.

WHAT THE CORPUS SAYS ABOUT ITSELF — the count that made this cheap
  142 幹 across 60 files, and the great majority are CORRECT: 才幹 ×~45,
  幹什麼 ×12, 幹部 ×7, 幹活 ×6, 樹幹 ×5, 軀幹 ×2, 骨幹, 主幹道, 幹掉, 能幹,
  幹得好, 幹嘛, 幹完, 幹了一整天活, 「我不幹了」. The 發/髮 shape: the claim
  is "these 18 positions are 乾 or 干", never "幹 is wrong".

  The corpus also proves it knows the distinction, which is what licenses the
  repair without an edition: it already writes 乾 164 times and 干 41 times,
  and 393.txt holds BOTH readings eleven characters apart —
  「美麗又幹淨。氣候雖然有點冷，但很乾燥」. So does 359.txt, four characters
  apart: 「我試圖保持試卷乾燥但它就是不幹」.

THE ITEM COUNTED 17. THERE ARE 18.
  The queue's list names 16 readings and its title says 17; the 17th is
  「水庫沒有幹」 at 201.txt, which its list folds into 「水庫幹了」 in the same
  sentence. The 18th is NOT in the item at all: 359.txt 「試卷乾燥但它就是不
  幹」 — a nose running onto an exam paper that will not dry. It was found by
  enumerating all 142 rather than by working the item's list, which is the
  whole argument for counting the corpus instead of trusting the queue.

WHY NO CUE RULE
  幹了 is correct five times (「我不幹了」 ×2 and 097.txt's 「幹了一整天」 ×3) and wrong
  three times (水庫幹了, 溪也幹了, 排幹了). 幹淨 is always wrong, but 幹沙 and
  幹枯 occur once each, so a collocation table would be as long as the list of
  positions. Anchored sentences it is.

NOTHING TO DO ON THE SIMPLIFIED SIDE. `assets/sermons/zh-CN/` writes 干 for
all three senses, which is the correct single Simplified form — 干萝卜, 干净,
水库干了, 哭干了 are all right as they stand. The twins are the reason each
reading above can be read with confidence, but they are not themselves a
defect and this script does not open them.

Dry-run by default; --apply writes. Re-running after --apply is a no-op.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "assets/sermons/zh-TW"

# (file, wrong, right, why). The `wrong` string is long enough to be unique in
# its file, and every one is quoted from the transcript.
RULES = (
    ("089.txt", "你可以說到嘴幹你的信心", "你可以說到嘴乾你的信心",
     "talk your faith until your mouth is dry"),
    ("090.txt", "抓一把幹沙子", "抓一把乾沙子", "a handful of dry sand"),
    ("093.txt", "他們引起太多幹擾", "他們引起太多干擾",
     "they cause too much interference — 干, not 乾"),
    ("093.txt", "我現在多幹淨", "我現在多乾淨", "how clean I am now"),
    ("141.txt", "凍幹食品", "凍乾食品", "freeze-dried food"),
    ("201.txt", "水庫幹了？", "水庫乾了？", "has the reservoir dried up?"),
    ("201.txt", "水庫沒有幹。", "水庫沒有乾。",
     "the reservoir has not dried up — same sentence as the above"),
    ("221.txt", "直到那條溪也幹了", "直到那條溪也乾了",
     "1 Kings 17 — until the brook dried up"),
    ("328.txt", "先知哭幹了眼淚", "先知哭乾了眼淚",
     "Jeremiah wept his eyes dry"),
    ("359.txt", "但它就是不幹", "但它就是不乾",
     "the exam paper would not dry — 乾燥 four characters earlier"),
    ("393.txt", "美麗又幹淨", "美麗又乾淨",
     "beautiful and clean — 很乾燥 eleven characters later"),
    ("401.txt", "你是那麼幹枯", "你是那麼乾枯", "you are so dried up"),
    ("410-1.txt", "因爲禱告被幹擾", "因爲禱告被干擾",
     "prayer being interrupted — 干, not 乾"),
    ("410-1.txt", "然後它排幹了", "然後它排乾了", "then it drained dry"),
    ("751.txt", "這一罐幹蘿蔔", "這一罐乾蘿蔔", "a tin of dried radish"),
    ("751.txt", "地喫，幹蘿蔔還在", "地喫，乾蘿蔔還在", "dried radish"),
    ("751.txt", "這幹蘿蔔什麼時候", "這乾蘿蔔什麼時候", "dried radish"),
    ("751.txt", "我發現喫幹蘿蔔", "我發現喫乾蘿蔔", "dried radish"),
)

# Readings where 幹 is CORRECT. If any of these stops being present, the count
# behind this script is stale and the rules must be re-derived, not re-run.
MUST_SURVIVE = (
    ("367.txt", "才幹的比喻"),      # the parable of the talents
    ("097.txt", "我在田裏幹了一整天活"),     # worked all day — 幹了 is right
    ("359.txt", "我試圖保持試卷乾燥"),       # the corpus knows 乾
    ("393.txt", "但很乾燥"),                 # …in the very sentence repaired
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    texts = {p.name: p.read_text(encoding="utf-8")
             for p in sorted(DIR.glob("*.txt"))}

    for name, reading in MUST_SURVIVE:
        if reading not in texts.get(name, ""):
            print(f"  ✗ {name}: 「{reading}」 is gone — the survey behind "
                  f"these rules no longer matches the corpus — refusing")
            return 1

    total_gan_before = sum(t.count("幹") for t in texts.values())

    pending = [(f, w, r, y) for f, w, r, y in RULES if w in texts.get(f, "")]
    if not pending:
        if all(r in texts.get(f, "") for f, _, r, _ in RULES):
            print("  already applied — nothing to do")
            return 0
        print("  ✗ no rule matches and the repaired readings are not all "
              "present — refusing")
        return 1
    if len(pending) != len(RULES):
        print(f"  ✗ {len(pending)} of {len(RULES)} rules match — the corpus is "
              f"half-repaired — refusing")
        return 1

    changed: dict[str, str] = {}
    for name, wrong, right, why in RULES:
        text = texts[name]
        n = text.count(wrong)
        if n != 1:
            print(f"  ✗ {name}: 「{wrong}」 appears {n} times, expected 1 — "
                  f"refusing")
            return 1
        if len(wrong) != len(right):
            print(f"  ✗ {name}: 「{wrong}」 and 「{right}」 differ in length — "
                  f"this repair is one character for one character — refusing")
            return 1
        texts[name] = text.replace(wrong, right)
        changed[name] = texts[name]
        print(f"  {name:12} 幹 → {right[len(right) - len(wrong) + wrong.index('幹')]}"
              f"   「{wrong}」 → 「{right}」   {why}")

    total_gan_after = sum(t.count("幹") for t in texts.values())
    if total_gan_before - total_gan_after != len(RULES):
        print(f"  ✗ 幹 moved {total_gan_before} → {total_gan_after}, expected "
              f"a fall of {len(RULES)} — refusing")
        return 1

    print(f"\n  {len(RULES)} substitutions across {len(changed)} files")
    print(f"  幹 {total_gan_before} → {total_gan_after}")

    if args.apply:
        for name, text in changed.items():
            (DIR / name).write_text(text, encoding="utf-8")
        print(f"  written → {len(changed)} files under "
              f"{DIR.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
