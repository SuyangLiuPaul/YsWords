#!/usr/bin/env python3
"""Measure the OTHER Traditional defect: `zh-Hant` fields that were never
converted at all and still hold wholly SIMPLIFIED prose.

This is the queue item "`assets/bible_evidence.json` has zh-Hant fields holding
wholly SIMPLIFIED text — not a glyph hole, an untranslated field", and it asks
for exactly one thing before anything is touched: **count how many entries have
`zh-Hant == zh-Hans`, or are Simplified by character inventory, before
deciding.** That is all this script does. It is read-only.

WHY IT IS NOT THE SAME DEFECT AS THE GLYPH HOLES
  Every `tools/repair_tr_*.py` is a single-character substitution justified by
  a witness edition. There is no witness for apologetics copy, and sweeping one
  character here would "fix" 恒→恆 inside a paragraph that is Simplified from
  end to end — making the real defect harder to see rather than fixing it.
  So the two audits are kept apart: `tools/audit_traditional_glyph_holes.py`
  answers "is the wrong Traditional character used here", this one answers "was
  any conversion run here at all".

HOW A FIELD IS JUDGED — two independent tests, reported separately

  1. **identical** — the `zh-Hant` string is character-for-character its
     `zh-Hans` twin. Decisive on its own: no conversion ran. Needs no oracle.

  2. **Simplified-only characters** — the string contains a character that is
     Simplified and has no Traditional use.

     The character set for (2) is DERIVED FROM opencc rather than hand-listed,
     because a hand-listed one is wrong in ways nobody notices: an early draft
     of this file listed 恒, 谷 and 里 as Simplified-only and all three are live
     Traditional characters. Every CJK code point is pushed through
     `opencc -c s2t`, and a character counts as Simplified when the conversion
     changes it — MINUS the one-to-many class below.

  The one-to-many class has to come out, and that is the whole subtlety here.
  opencc rewrites 只→隻, 面→麵, 谷→穀, 干→幹, 余→餘, 里→裏 … but every one of
  those inputs is ALSO a correct Traditional character in its own right, so
  their presence proves nothing about whether a field was converted. They are
  the glyph audit's business, not this one's. The list is the ambiguous class
  the queue already enumerated for the Strong's sweep, plus the pairs the CUV
  instalments worked through.

Read-only. Writes nothing.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Characters opencc's s2t would rewrite that are nevertheless perfectly good
# Traditional characters, so their presence says nothing about conversion.
#
# Sources, so this is auditable rather than asserted:
#   * the 24 pairs the queue enumerated when it scoped the Strong's lexicon —
#     谷/穀 发/髮 里/裏 松/鬆 系/係/繫 台/臺 只/隻 斗/鬥 扎/紮 占/佔 云/雲
#     岳/嶽 征/徵 游/遊 布/佈 范/範 咸/鹹 困/睏 折/摺 钟/鐘 术/術 虫/蟲
#     向/嚮 丑/醜
#   * every "wrong form" of the twenty applied CUV glyph instalments —
#     只 面 发 余 制 松 愈 壇 采 干 恒 谷 胡 须 侄 侖
#   * the splits the queue names as real choices rather than defects —
#     幹/乾/干 發/髮 醜/丑 後/后 里/裡 復/覆 徵/征 雲/云
AMBIGUOUS = set(
    "只面发發余制松愈坛壇采採干幹乾谷穀胡鬍须須侄姪仑侖崙里裏裡后後"
    "云雲征徵丑醜复復覆系係繫台臺斗鬥扎紮占佔岳嶽游遊布佈范範咸鹹困睏"
    "折摺钟鐘术術虫蟲向嚮尽儘盡并併並划劃帘簾冲衝板闆恒恆志誌"
)


# The repo's own established Traditional corpora. Any character that occurs in
# these at least LIVE_THRESHOLD times is Traditional as far as this repo is
# concerned, whatever opencc would prefer to write instead.
#
# This second oracle is not optional. opencc's s2t rewrites 秘→祕, 峰→峯,
# 群→羣, 辟→闢, 吃→喫, 托→託, 岩→巖, 准→準, 为→爲, 着→著 — none of which is a
# Simplified character; they are OpenCC's own standard-Traditional preferences,
# and they are the subject of a whole separate open queue item (the lexicon and
# the Bible set in two different Traditional orthographies, 2,816 positions).
# Without this filter this audit reported 秘密, 高峰, 群眾, 辟拉, 吃, 摩托車,
# 岩石 and 准許 — every one of them correct Traditional — as untranslated.
TRADITIONAL_CORPORA = [
    "assets/cuvs-yhwh-tr.json",     # frozen, but read here as evidence only
    "assets/biblexg-v2-tr.json",
    "assets/sermons/zh-TW",
]
LIVE_THRESHOLD = 3


def _corpus_chars(root: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    for entry in TRADITIONAL_CORPORA:
        p = root / entry
        files = sorted(p.glob("*.txt")) if p.is_dir() else [p]
        for f in files:
            if not f.exists():
                continue
            for ch in f.read_text(encoding="utf-8"):
                counts[ch] = counts.get(ch, 0) + 1
    return counts


def simplified_only(root: Path) -> set[str]:
    """Characters that are Simplified here: opencc s2t rewrites them, they are
    not in the ambiguous one-to-many class, and this repo's own Traditional
    corpora do not use them."""
    block = "".join(chr(c) for c in range(0x4E00, 0xA000))
    out = subprocess.run(["opencc", "-c", "s2t.json"], input=block,
                         capture_output=True, text=True, check=True).stdout
    if len(out) != len(block):
        # s2t is normally 1:1 per character; if a build of opencc ever breaks
        # that, refuse rather than silently mis-aligning the whole set.
        raise SystemExit("opencc s2t was not length-preserving on the probe; "
                         "this audit cannot align characters — investigate "
                         "before trusting any number it would print.")
    changed = {a for a, b in zip(block, out) if a != b}
    live = {c for c, n in _corpus_chars(root).items() if n >= LIVE_THRESHOLD}
    return changed - AMBIGUOUS - live


HANT_KEYS = {"zh-Hant": "zh-Hans", "zh-TW": "zh-CN",
             "zh_Hant": "zh_Hans", "cuv-tr": "cuv"}
HANT_SUFFIX = re.compile(r"(ZhHant|ZhTw)$")


def walk(node, path="$"):
    if isinstance(node, dict):
        yield path, node
        for k, v in node.items():
            yield from walk(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, f"{path}[{i}]")


def hant_fields(obj: dict):
    """(key, twin key or None, value, twin value or None) for each hant field."""
    for key, value in obj.items():
        if not isinstance(value, str) or not value:
            continue
        if key in HANT_KEYS:
            twin = HANT_KEYS[key]
        elif HANT_SUFFIX.search(key):
            twin = HANT_SUFFIX.sub(
                lambda m: "ZhHans" if m.group(1) == "ZhHant" else "ZhCn", key)
        else:
            continue
        yield key, twin, value, obj.get(twin)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("assets", nargs="*")
    ap.add_argument("--show", type=int, default=0,
                    help="print this many offending fields per asset")
    args = ap.parse_args()

    bad_chars = simplified_only(ROOT)

    paths = ([ROOT / a for a in args.assets] if args.assets
             else sorted((ROOT / "assets").rglob("*.json")))

    grand = [0, 0, 0]
    for path in paths:
        if not path.exists():
            continue
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        total = identical = simplified = 0
        examples = []
        for jpath, obj in walk(doc):
            for key, twin, value, twin_value in hant_fields(obj):
                total += 1
                if twin_value == value:
                    identical += 1
                hits = {c for c in value if c in bad_chars}
                if hits:
                    simplified += 1
                    if len(examples) < args.show:
                        examples.append((f"{jpath}.{key}",
                                         "".join(sorted(hits))[:14],
                                         value[:70]))
        if not total:
            continue
        rel = path.relative_to(ROOT).as_posix()
        print(f"{rel}")
        print(f"    zh-Hant fields           {total}")
        print(f"    identical to zh-Hans     {identical}")
        print(f"    hold Simplified-only     {simplified}")
        for jp, chars, snippet in examples:
            print(f"        {jp}  [{chars}]")
            print(f"            {snippet}")
        grand[0] += total
        grand[1] += identical
        grand[2] += simplified
    print(f"\nTOTAL zh-Hant fields {grand[0]}, identical to their twin "
          f"{grand[1]}, holding Simplified-only characters {grand[2]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
