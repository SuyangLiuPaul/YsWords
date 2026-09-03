#!/usr/bin/env python3
"""梁家鏗's Traditional NT — the classifier 隻, and three more one-to-many slips.

THE ITEM ASKED FOR A COUNT BEFORE ANYTHING WAS APPLIED, AND THE COUNT IS THE
NEWS. `assets/biblexg-v2-tr.json` holds 445 只 against 51 隻 in its Traditional
text, which reads like the CUV's classifier hole at a quarter scale. It is not.
Every one of the 51 隻 is already a correct classifier (一隻鴿子, 一百隻羊,
五隻麻雀, 船隻, 六隻翅膀) and **443 of the 445 只 are the adverb "only"**. The
defect is TWO positions, not four hundred:

  40010029  馬太福音 10:29   兩只麻雀   →  兩隻麻雀
  42005007  路加福音 5:7     兩只船     →  兩隻船

馬太福音 10:29 is the one that settles itself: the SAME VERSE goes on to read
「牠們一隻也不會掉在地上」, so the file contradicts itself inside one verse. Its
parallel at 路加福音 12:6 reads 「五隻麻雀」. 路加福音 5:7 was the reading the
queue item named, and the CUV Traditional has it verbatim — 「把魚裝滿了兩隻
船」. The third candidate an automated scan turns up, 哥林多前書 6:20's study
note 「但這只適用於與法律有關的事情」, is the adverb and is correct.

WHOSE ORTHOGRAPHY — the user ruled on this file specifically
  「关于繁体字 你可以参考和合本最新版本的繁体版看那边怎么写的然后用他们的」
  (user, 2026-09-02). That ruling was aimed at `cuvs-yhwh-tr`, which the
  publisher then froze, so `docs/user-decisions-p0.md` records that it now
  applies **here** — this file is our own conversion and the publisher is in
  conversation with us rather than declining. Three of the four classes below
  are settled by the CUV Traditional at the aligned verse; the fourth has no
  aligned CUV text and is settled by this file's own internal convention, in
  the way the 松開 leftover in this same file was.

THE OTHER THREE CLASSES

  崙 ×1 — 路加福音 3:33 spells Hezron 希斯侖. This is the CUV's own ridge
  instalment turning up one asset over: 侖 is the wheel-spoke character and the
  name takes 崙. The CUV's own 路加福音 3:33 reads 希斯崙 twice, `cuvs-yhwh-tr`
  writes 希斯崙 ×17 and 希斯侖 ×0, and this file already writes 崙 ×3 elsewhere.

  穀 ×3 — 哥林多前書 9:9 and 提摩太前書 5:18 both quote 申命記 25:4 as 「使牛
  踹谷」, treading a VALLEY. The CUV Traditional reads 踹穀 at all three
  references — the CUV's own grain instalment names 申命記 25:4 「and its two NT
  citations」 explicitly. 使徒行傳 7:12's 「埃及仍有谷糧」 has no aligned CUV
  text (the CUV reads 「在埃及有糧」), and rests instead on this file writing
  穀倉, 揚穀鏟 and 五穀 and on 谷糧 not being a word. Every other 谷 here is a
  valley or 哈巴谷 (Habakkuk) and is right.

  癒 ×4 — 治愈 ×2 and 愈合 ×2, against 痊癒 / 治癒 / 病癒 ×26 in the same file,
  including 「耶穌治癒的人越多」 and 「藉神蹟而得以治癒的人」. Internal
  convention, decisive on its own; the CUV has no aligned reading (啟示錄 13:3
  is 「醫好了」, 路加福音 8:2 「已經治好的」).

  One of the two 治愈 is in 路加福音 8:3's `blockNotes`, quoting 8:2's verse
  text back at the reader. They have to move together or the note misquotes the
  verse it annotates — and this is exactly the class the item flagged when it
  said the notes are as reader-visible as the verses.

WHAT IS **NOT** REPAIRED HERE, AND WHY — three signatures that look identical
to a hole and are not. Recording them so the audit does not report them as news
next month:

  * 鬚 0 / 須 158. All 158 are 必須 / 無須 / 須知 / 才須 — "must". No beard.
  * 罈 0 / 壇 37. All 37 are 祭壇 / 香壇 / 聖壇 — altars. No jar.
  * 鬍 0 / 胡 1. 「希律的管家胡乍的妻子」 — Chuza, 路 8:3. A name syllable.

  Also left alone deliberately, because `docs/user-decisions-p0.md` already
  measured them and ruled them not worth a sweep before the publisher answers:
  8 stray 着 against 1058 著, and 兇 8 / 凶 8 splitting the same words.

Dry-run by default; --apply writes. Re-running after --apply is a no-op.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "assets/biblexg-v2-tr.json"

# (row id, wrong, right, why). The `wrong` string is long enough to be unique
# inside its row, and every one is quoted from the asset.
RULES = (
    ("40010029", "兩只麻雀", "兩隻麻雀",
     "馬太福音 10:29 — the same verse already reads 牠們一隻也不會"),
    ("42005007", "把兩只船裝得滿滿的", "把兩隻船裝得滿滿的",
     "路加福音 5:7 — CUV: 把魚裝滿了兩隻船"),
    ("42003033", "希斯侖", "希斯崙",
     "路加福音 3:33, Hezron — the aligned CUV verse reads 希斯崙 twice "
     "(cuvs-yhwh-tr: 希斯崙 ×17, 希斯侖 ×0)"),
    ("46009009", "使牛踹谷", "使牛踹穀",
     "哥林多前書 9:9 quoting 申命記 25:4 — CUV: 牛在場上踹穀"),
    ("54005018", "使牛踹谷", "使牛踹穀", "提摩太前書 5:18, the same quotation"),
    ("44007012", "仍有谷糧", "仍有穀糧",
     "使徒行傳 7:12 — grain, not a valley; cf. 穀倉, 揚穀鏟, 五穀 here"),
    ("42008002", "疾病得到治愈的", "疾病得到治癒的",
     "路加福音 8:2 — against 治癒 ×6 elsewhere in this file"),
    ("42008003", "疾病得到治愈的", "疾病得到治癒的",
     "路加福音 8:3 blockNotes, which QUOTES 8:2 — the two have to move "
     "together or the note misquotes the verse it annotates. This is the "
     "class the queue flagged: the notes are as reader-visible as the verses"),
    ("66013003", "那致命傷又愈合了", "那致命傷又癒合了", "啟示錄 13:3"),
    ("66013012", "那致命傷已得愈合的獸", "那致命傷已得癒合的獸", "啟示錄 13:12"),
)

# Readings the rules must NOT reach.
MUST_SURVIVE = (
    "但這只適用於",     # 林前 6:20 note — the adverb "only"
    "五隻麻雀",          # 路 12:6 — the file's own parallel
    "希律的管家胡乍",    # Chuza, a name
    "哈巴谷",            # Habakkuk, a name
    "約旦河谷",          # a valley
    "穀倉",              # already correct
    "痊癒",              # already correct
    "祭壇",              # an altar, not a jar
    "必須",              # "must", not a beard
)


def strings(node):
    if isinstance(node, str):
        yield node
    elif isinstance(node, list):
        for x in node:
            yield from strings(x)
    elif isinstance(node, dict):
        for x in node.values():
            yield from strings(x)


def replace_in(node, wrong, right):
    """Substitute inside every string of a row, at any depth. Deliberately not
    restricted to `text`: this file's one previously-found glyph defect lived
    in a `blockNotes` list, which a text-only pass walks straight past."""
    if isinstance(node, str):
        return node.replace(wrong, right), node.count(wrong)
    if isinstance(node, list):
        out, n = [], 0
        for x in node:
            v, k = replace_in(x, wrong, right)
            out.append(v)
            n += k
        return out, n
    if isinstance(node, dict):
        out, n = {}, 0
        for key, x in node.items():
            v, k = replace_in(x, wrong, right)
            out[key] = v
            n += k
        return out, n
    return node, 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    rows = json.loads(ASSET.read_text(encoding="utf-8"))
    by_id = {r["id"]: i for i, r in enumerate(rows)}
    blob = "".join(s for r in rows for s in strings(r))

    for reading in MUST_SURVIVE:
        if reading not in blob:
            print(f"  ✗ 「{reading}」 is gone — the survey behind these rules "
                  f"no longer matches the asset — refusing")
            return 1

    pending = []
    for rid, wrong, right, why in RULES:
        if rid not in by_id:
            print(f"  ✗ row {rid} is missing from the asset — refusing")
            return 1
        row = rows[by_id[rid]]
        n = sum(s.count(wrong) for s in strings(row))
        if n:
            pending.append((rid, wrong, right, why, n))

    if not pending:
        if all(any(right in s for s in strings(rows[by_id[rid]]))
               for rid, _, right, _ in RULES):
            print("  already applied — nothing to do")
            return 0
        print("  ✗ no rule matches and the repaired readings are not all "
              "present — refusing")
        return 1
    if len(pending) != len(RULES):
        print(f"  ✗ {len(pending)} of {len(RULES)} rules match — the asset is "
              f"half-repaired — refusing")
        return 1

    total = 0
    for rid, wrong, right, why, n in pending:
        if len(wrong) != len(right):
            print(f"  ✗ {rid}: 「{wrong}」 and 「{right}」 differ in length — "
                  f"this repair is one character for one character — refusing")
            return 1
        i = by_id[rid]
        rows[i], k = replace_in(rows[i], wrong, right)
        total += k
        print(f"  {rid}  {wrong} → {right}   ×{k}   {why}")

    after = "".join(s for r in rows for s in strings(r))
    if len(after) != len(blob):
        print("  ✗ the asset changed length — refusing")
        return 1
    for _, wrong, _, _, _ in pending:
        if wrong in after:
            print(f"  ✗ 「{wrong}」 survives the repair — refusing")
            return 1

    print(f"\n  {total} substitutions across {len(pending)} rows")
    for ch in "隻只崙侖穀谷癒愈":
        print(f"    {ch}  {blob.count(ch):>5} → {after.count(ch)}")

    if args.apply:
        # indent=1 + a trailing newline is this asset's existing formatting;
        # verified by round-tripping before any edit, so the diff is the
        # substitutions and nothing else.
        ASSET.write_text(json.dumps(rows, ensure_ascii=False, indent=1) + "\n",
                         encoding="utf-8")
        print(f"  written → {ASSET.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
