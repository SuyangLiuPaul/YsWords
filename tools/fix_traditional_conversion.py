#!/usr/bin/env python3
"""Repair simplified→traditional conversion misses in the -tr Bible assets.

  ⚠  DRAFT — NEVER APPLIED. DO NOT RUN --apply AS IT STANDS.

  Only the 只 → 隻 class has been carried through to the assets, and it was
  done by tools/repair_tr_classifier.py, not by this script, because the rules
  below were not good enough. The cue rule here is the same one that missed
  民數記 15:12 「按著只數」 — a classifier with no numeral in front of it — and
  it would still miss it today.

  Before applying ANY rule below, verify that class occurrence-by-occurrence
  against the independently imported 和合本 Traditional kept in git as blob
  7a2dc43  (`git cat-file -p 7a2dc43`, i.e. 69307c7^:assets/cuv-tr.json).
  That comparison is what found the miss; a rule that looks right on 547 of
  548 still puts a wrong character in a Bible. See docs/autonomous-queue.md
  for which of these classes are unambiguous and which are one-to-many.

Reported 2026-08-17 by a reader: 賽 2:16 read 「他施的船只」 where traditional
Chinese wants 「船隻」. The simplified source is correct (船只 IS right in
simplified) and an independent CUV import agrees, so the defect is purely in the
conversion step that produced the -tr files.

WHY THIS IS NOT "just re-run opencc":
  Both `opencc -c s2t` and `-c s2twp` render 船隻 correctly, which tells us the
  -tr assets were never produced with opencc at all — some naive per-character
  map made them. But re-converting wholesale would CHANGE 36% of all verses,
  because opencc also rewrites conventions this edition deliberately uses and
  that are correct as they stand:
      裏 → 裡   4714 verses
      「」 → “”  6528
      藉 → 借    199
  Trading one set of errors for a larger set is not a fix. So this script
  repairs only the specific classes verified as genuine errors, by phrase and
  in context — never by blanket character substitution on an ambiguous glyph.

The ambiguous glyphs and why each rule is shaped the way it is:

  只   Classifier (→隻) vs the adverb "only" (stays 只). Converted only after a
       number or in 船只/那只/這只/每只, and NOT when what follows makes it an
       adverb. Note 為 and 好 are deliberately NOT guards: 「一只為燔祭」 and
       「七只好母牛」 are classifiers and must convert.
  幹   THREE-way: 乾 (dry), 干 (offend/concern), and the proper names
       亞幹 / 亞多尼幹 / 隱幹寧 / 斯利幹 which must not be touched at all.
       Hence explicit phrases, never a bare 幹 rule.
  谷   Grain (→穀) vs valley/place name (stays 谷: 山谷, 以拉谷, 音谷…).
  松   鬆 (loosen) vs the pine tree (stays 松: 松木, 松樹, 松香, 杜松).
  凈 墻 余  No competing traditional sense in this corpus — every occurrence was
       inspected (519 / 234 / 230) and all are 淨 / 牆 / 餘. Blanket is safe here.

Dry-run by default; --apply writes. Always read the emitted report first.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGETS = ["assets/cuvs-yhwh-tr.json", "assets/biblexg-v2-tr.json"]

NUM = "一二兩三四五六七八九十百千萬幾數"
# Only these make a following 只 adverbial. 為/好 are NOT here on purpose.
ADV = "有是要怕管得能會恐"

# (label, compiled pattern, replacement). Order matters: 凈→淨 runs before the
# 幹淨→乾淨 phrase so the latter matches the already-corrected form.
RULES: list[tuple[str, re.Pattern, str]] = [
    ("只 → 隻 (量詞)", re.compile(rf"(?<=[{NUM}])只(?![{ADV}])"), "隻"),
    # 船/每 need no guard: 「船只有…」 does not occur here, and 「每只要獻伊法…」
    # (民 28:21) is a classifier — guarding on 要 wrongly protected it.
    ("只 → 隻 (船隻/每隻)", re.compile(r"(?<=[船每])只"), "隻"),
    # 那/這 DO need one — 「那只是」/「這只是」 are adverbial.
    ("只 → 隻 (那隻/這隻)", re.compile(rf"(?<=[那這])只(?![{ADV}])"), "隻"),
    ("凈 → 淨", re.compile(r"凈"), "淨"),
    ("墻 → 牆", re.compile(r"墻"), "牆"),
    ("余 → 餘", re.compile(r"余"), "餘"),
    ("谷 → 穀 (穀物，非山谷)", re.compile(r"(?<=[五])谷|(?<=踹)谷|谷物|谷種"), "穀"),
    # 干 MUST precede 乾: 「與你無幹了」 is 無干了, not 無乾了, and the 乾 rule's
    # 了-guard would otherwise claim it first.
    ("幹 → 干 (干犯/干預/干戈)", re.compile(
        r"(?<=[何無相])幹|幹(?=[犯預休戈])|(?<=不)幹(?=己)|(?<=致)幹"), "干"),
    # These MUST stay 幹 and are the reason there is no bare 幹 rule:
    #   座和幹 (出 25:31) lampstand shaft · 枝幹 (結 19:11) boughs ·
    #   才幹 (太 25:15) ability · 若幹 (可 12:41) a certain amount ·
    #   「幹也死在土中」 (伯 14:8) tree trunk · and the names 亞幹/約幹/雅幹/
    #   瑪拉幹/米母幹/幹尼/幹大基/弗勒幹/哈撒哈提幹.
    ("幹 → 乾 (乾燥)", re.compile(
        r"幹(?=[地旱涸瘦癟熱了渴草燥餅糧柴焦裂竭死])"
        r"|(?<=[枯踏燒流發喝吹擦])幹"
        r"|(?<=未)幹|幹淨|(?<=是)幹(?=的)|(?<=葡萄)幹|(?<=乳)幹|(?<=泉源必)幹"), "乾"),
    ("松 → 鬆 (放鬆，非松樹)", re.compile(
        r"(?<=[放輕])松|松(?=[手開緩])"), "鬆"),
    # 髮 (hair) never appears in the file at all — the converter simply never
    # produced it, so every 頭髮/白髮 came out as 發. Only hair compounds here;
    # 發 (issue/send) is overwhelmingly the common sense and must not move.
    ("發 → 髮 (頭髮)", re.compile(
        r"(?<=[頭白毛黑鬍胡])發|發(?=[綹辮])"), "髮"),
    ("采 → 採 (採集)", re.compile(r"采(?=[鹹了百集摘])"), "採"),
    ("腌 → 醃", re.compile(r"腌"), "醃"),
    # Five glyphs with no traditional use at all — pure simplified leftovers.
    ("镕 → 鎔", re.compile(r"镕"), "鎔"),
    ("鸮 → 鴞", re.compile(r"鸮"), "鴞"),
    ("飖 → 颻", re.compile(r"飖"), "颻"),
    ("珰 → 璫", re.compile(r"珰"), "璫"),
    ("鹯 → 鸇", re.compile(r"鹯"), "鸇"),
]

# Phrases that must survive untouched — asserted after the rewrite.
MUST_KEEP = ["亞幹", "多尼幹", "隱幹寧", "斯利幹",
             "松木", "松樹", "松香", "杜松",
             "山谷", "音谷", "只有", "只是", "只要", "不只"]


def repair(text: str) -> tuple[str, list[tuple[str, str, str]]]:
    """Return (new_text, [(label, before_window, after_window), …])."""
    out, changes = text, []
    for label, pat, rep in RULES:
        def _sub(m: re.Match) -> str:
            i = m.start()
            changes.append((label,
                            out[max(0, i - 8):i + 9],
                            (out[max(0, i - 8):i] + rep + out[m.end():m.end() + 8])))
            return rep
        out = pat.sub(_sub, out)
    return out, changes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write the files")
    ap.add_argument("--report", default="", help="write the full diff here")
    args = ap.parse_args()

    report: list[str] = []
    grand = 0
    for rel in TARGETS:
        path = ROOT / rel
        if not path.exists():
            print(f"  skip (missing): {rel}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        # Snapshot which protected names this file actually contains. Asserting
        # on the whole list would fail on the NT file, which has no 亞幹 to lose.
        before_blob = "".join(v["text"] for v in data)
        present = [k for k in MUST_KEEP if k in before_blob]
        per_class: dict[str, int] = {}
        touched = 0
        for v in data:
            new, changes = repair(v["text"])
            if not changes:
                continue
            touched += 1
            for label, before, after in changes:
                per_class[label] = per_class.get(label, 0) + 1
                report.append(
                    f"{rel}\t{v.get('book')} {v.get('chapter')}:{v.get('verse')}\t"
                    f"{label}\t…{before}…\t→\t…{after}…")
            v["text"] = new

        # Safety net: a rule that ate a name or a pine tree is a bug, not a fix.
        # Only phrases this file HAD before the rewrite are asserted.
        blob = "".join(v["text"] for v in data)
        for keep in present:
            if keep not in blob:
                print(f"  ⚠ {rel}: '{keep}' disappeared — refusing to write")
                return 1

        total = sum(per_class.values())
        grand += total
        print(f"  ══ {rel}: {total} substitutions in {touched} verses")
        for label, n in sorted(per_class.items(), key=lambda kv: -kv[1]):
            print(f"       {label:<28} {n:>4}")

        if args.apply:
            path.write_text(
                json.dumps(data, ensure_ascii=False, indent=None,
                           separators=(",", ":")) + "\n", encoding="utf-8")
            print(f"       written → {rel}")

    if args.report:
        Path(args.report).write_text("\n".join(report) + "\n", encoding="utf-8")
        print(f"\n  full diff ({len(report)} lines) → {args.report}")
    print(f"\n  TOTAL: {grand} substitutions"
          f"{'' if args.apply else '  (dry run — nothing written)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
