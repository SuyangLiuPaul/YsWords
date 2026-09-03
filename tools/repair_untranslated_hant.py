#!/usr/bin/env python3
"""Convert the `zh-Hant` fields of `assets/bible_evidence.json` that were never
converted at all and still hold wholly SIMPLIFIED prose.

This is the queue item "`assets/bible_evidence.json` has zh-Hant fields holding
wholly SIMPLIFIED text — not a glyph hole, an untranslated field", measured by
`tools/audit_untranslated_hant.py` and re-measured here before every run:
the audit's test reports **951 of 1,575 `zh-Hant` fields (60.4%), across 223 of
the 225 entries**, and **830 of those actually carry Simplified text** — the
other 121 are script-neutral strings its `zh-Hant == zh-Hans` clause
false-positives on (see EXPECT_SCRIPT_NEUTRAL). There is no render-time
converter in `lib/` — the evidence page hands `zh-Hant` straight to the widget
— so those 830 fields print Simplified prose to Traditional readers today.

WHY THIS IS NOT `opencc -c s2twp` OVER THE FILE, WHICH IS WHAT IT LOOKS LIKE
  Scored against the 624 fields of this file that are properly converted AND
  differ from their twin,
  s2twp reproduces 594 (95.19%) and every other configuration scores far
  lower (s2tw 54.01%, s2t 49.68%). So s2twp is provably what made this file,
  and re-running it is the obvious move. **It is the wrong move, and the file
  itself is the evidence.** s2twp carries a vocabulary layer on top of the
  glyph layer, and that layer has already damaged the converted portion:

      伊斯坦布爾 → 伊斯坦布林   ×3, live in the asset today
      保存 → 儲存               ×5, live in the asset today

  The first is Istanbul rewritten by s2twp's 布爾→布林 rule, which exists for
  "Boolean" and destroys the city. The second turns "well preserved" into
  "well stored", which is wrong about every manuscript it describes. Both are
  repaired here (see CORRUPTIONS) — and both are the reason the vocabulary
  layer is refused wholesale. Run over the 830 untranslated fields, that same
  layer would also write 聯繫→聯絡 and 法律文件→法律檔案.

  So this script converts with **`s2tw` — the glyph layer only** — and then
  applies an explicitly enumerated correction table for the places s2tw itself
  gets wrong. Wording is never touched: 公元 stays 公元 and 意大利 stays
  意大利, because those are the Simplified source's own wording and this file
  is already internally mixed on both (公元 525 / 西元 288). Converting a
  glyph is not rewriting; changing a word is.

WHY THE CORRECTION TABLE IS ENUMERATED AND NOT A RULE
  s2tw's own one-to-many decisions were read position by position across the
  830 fields — and 50 are wrong. They are listed below as
  the exact strings observed, with the count each must hit. Nothing is
  pattern-guessed, because the pattern is what breaks: 被發掘 and 頭髮 differ
  only in the sense of 发, and 那裡 and 馬里 only in whether the 里 is a
  container or a transliterated syllable.

  The dangerous direction is the keep side, so it is recorded: 髮 is CORRECT
  in 頭髮 and 髮型; 裡 is CORRECT in 那裡/這裡/城裡/家裡/裡面/時間裡 and 60
  more; 覆 is CORRECT in 反覆/傾覆/覆蓋/覆滅/覆文; 幹 is CORRECT in 樹幹,
  主幹道 and the name 斐勒幹; 隻 is CORRECT in all 9 (船隻, 一隻方舟,
  隻字不提). A rule widened over any of those does damage.

IDEMPOTENCE, AND THE TRAP IN IT
  `opencc -c s2tw` is NOT idempotent on this file's already-Traditional text —
  re-run over the 624 clean fields it would rewrite 台→臺 ×6, 里→裡 ×3,
  卷→捲 ×1, 准→準 ×1. So this script never converts a field it has not first
  judged untranslated, and re-running it is a no-op because a converted field
  no longer meets that test. The guard asserts that directly.

Dry-run by default; --apply writes. --review prints every one-to-many decision
with context, which is what a re-import should be re-read against.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "assets/bible_evidence.json"
OPENCC_CONFIG = "s2tw.json"

# --- pinned measurements -----------------------------------------------------
# A re-import that moves any of these must be re-read by hand, not re-run.
EXPECT_HANT_FIELDS = 1575
# The audit's own test — `zh-Hant == zh-Hans` OR holds a Simplified-only
# character — reports 951, which is the number the queue pinned. 121 of those
# are FALSE POSITIVES of its first clause: strings that are correctly
# identical to their twin because they are script-neutral ("1946–1956",
# 死海古卷, 但以理石碑, 希西家水道 — every character the same in both scripts).
# They need no conversion and opencc is a no-op on them. Counting them as
# untranslated also makes the repair non-idempotent, because they still test
# as untranslated after a successful run. So this script converts the 830 that
# actually carry Simplified text, and reports both numbers.
EXPECT_AUDIT_DEFINITION = 951
EXPECT_UNTRANSLATED = 830
EXPECT_SCRIPT_NEUTRAL = 121
EXPECT_ENTRIES_HIT = 223
EXPECT_ENTRIES = 225
EXPECT_CLEAN = 745  # 624 converted-and-differing + 121 script-neutral
EXPECT_POST_FIXES = 50
EXPECT_CORRUPTIONS = 12

# --- corrections to s2tw's own output ---------------------------------------
# (wrong string s2tw produces, correct string, how many times it must occur)
# Every row was read in context; the counts are the whole audit.
POST_RULES: list[tuple[str, str, int]] = [
    # 里 → 裡 applied to transliterated NAMES. 裡 is a container; these are
    # syllables in Mari, Tell Leilan, Marib, Hurrian, Gabriel, Gurion, Frey,
    # Hattarikka and al-Nuwayri.
    ("馬裡", "馬里", 9),
    ("泰勒裡", "泰勒里", 5),
    ("瑪裡", "瑪里", 4),
    ("胡裡", "胡里", 2),
    ("古裡", "古里", 2),
    ("弗裡", "弗里", 2),
    ("努外裡", "努外里", 2),
    ("加布裡", "加布里", 1),
    ("哈塔裡", "哈塔里", 1),
    # 发 → 髮 (hair) where the sense is 發 (issue//discover/publish). s2tw
    # mis-segments 被发, 亂发 and 括发. 頭髮 and 髮型 are the two real ones.
    ("被髮", "被發", 8),
    ("騷亂髮", "騷亂發", 2),
    ("包括髮", "包括發", 1),
    # 复 → 覆 where the sense is 復 (again/restore). 復活, not 覆活.
    ("覆活", "復活", 3),
    # 干 → 幹 (trunk) where the sense is 乾 (dry). A wadi is a 乾河谷.
    ("特幹河谷", "特乾河谷", 1),
    ("沙漠幹河谷", "沙漠乾河谷", 1),
    # 制 left unconverted where the sense is 製 (manufactured). The file's own
    # converted portion writes 銀製 / 陶製 / 銅製 / 複製品.
    ("石制", "石製", 4),
    # 卷 → 捲 (to roll up) where the sense is 卷 (a scroll). The file's own
    # converted portion writes 卷 ×7 and 捲 ×0.
    ("羊皮捲", "羊皮卷", 1),
    # 灶 is left by s2tw (it is the modern Taiwan standard form) but this
    # repo's own Traditional corpora write 竈 and never 灶 —
    # `assets/cuvs-yhwh-tr.json` 竈 1 / 灶 0, `assets/sermons/zh-TW/` 竈 1 /
    # 灶 0. Matching the repo, and it clears the last Simplified-only
    # character so the guard below can assert zero.
    ("爐灶", "爐竈", 1),
]

# --- corruptions already live in the CONVERTED fields ------------------------
# Not untranslated — these are damage in fields that were otherwise converted
# correctly, left by whatever s2twp pass made this file. Each is confirmed
# against its own zh-Hans twin, which is the witness.
#
#   伊斯坦布林   twin 伊斯坦布尔    — s2twp's 布爾→布林 ("Boolean") rule
#   儲存         twin 抄本保存      — "preserved" turned into "stored"
#   艾茲裡耶     twin 阿尔艾兹里耶  — al-Eizariya (Bethany)
#   馬裡卜       twin 马里卜        — Marib
#   弗裡         twin 弗里
#
# NOTE the 儲存 rule is scoped to the already-converted fields ONLY and must
# stay that way: 儲存 is a perfectly good word, and the newly converted fields
# contain 4 legitimate ones ("罐子是標準量器，用於儲存酒"). A guard run over
# the whole file instead of this scope reports those 4 and is wrong.
CORRUPTIONS: list[tuple[str, str, int]] = [
    ("伊斯坦布林", "伊斯坦布爾", 3),
    ("儲存", "保存", 5),
    ("艾茲裡", "艾茲里", 1),
    ("馬裡卜", "馬里卜", 2),
    ("弗裡", "弗里", 1),
]

# Characters that are legitimate Traditional but that s2tw may reach by a
# one-to-many decision. Every occurrence is printed by --review.
ONE_TO_MANY_OUT = "髮裡幹乾製麵餘穀鬆隻覆複徵鬍鬚採罈臺捲準竈"


def opencc(text: str) -> str:
    r = subprocess.run(["opencc", "-c", OPENCC_CONFIG], input=text,
                       capture_output=True, text=True, check=True)
    out = r.stdout
    if out.endswith("\n") and not text.endswith("\n"):
        out = out[:-1]
    return out


# --- the Simplified-only oracle, shared with the audit -----------------------
def simplified_only() -> set[str]:
    """Re-uses tools/audit_untranslated_hant.py rather than restating its
    character set, so the two can never drift apart."""
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "audit_untranslated_hant", ROOT / "tools/audit_untranslated_hant.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.simplified_only(ROOT)


def locale_objects(node):
    """Every dict that carries a zh-Hant/zh-Hans pair, at any depth."""
    if isinstance(node, dict):
        if isinstance(node.get("zh-Hant"), str) and isinstance(
                node.get("zh-Hans"), str):
            yield node
        for v in node.values():
            yield from locale_objects(v)
    elif isinstance(node, list):
        for v in node:
            yield from locale_objects(v)


def audit_untranslated(obj: dict, bad: set[str]) -> bool:
    """The audit's test, kept so its 951 stays reproducible from here."""
    v = obj["zh-Hant"]
    return bool(v) and (v == obj["zh-Hans"] or any(c in bad for c in v))


def is_untranslated(obj: dict, bad: set[str]) -> bool:
    """Fields this script will actually convert. Same as the audit's test,
    minus the script-neutral strings its `==` clause false-positives on: a
    field identical to its twin is only untranslated if converting it would
    in fact change it."""
    v = obj["zh-Hant"]
    if not v:
        return False
    if any(c in bad for c in v):
        return True
    return v == obj["zh-Hans"] and opencc(v) != v


def review(doc, bad: set[str]) -> None:
    """Print every one-to-many decision s2tw makes, with context. This is what
    a re-import has to be re-read against — the correction table above is only
    valid for the text it was read over."""
    for obj in locale_objects(doc):
        if not is_untranslated(obj, bad):
            continue
        src = obj["zh-Hant"]
        got = opencc(src)
        if len(got) != len(src):
            print(f"  LENGTH CHANGE  {src[:40]!r}")
            continue
        for i, (a, b) in enumerate(zip(src, got)):
            if b in ONE_TO_MANY_OUT and a != b:
                print(f"  {a}->{b}  {got[max(0, i - 8):i + 9]!r}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write the asset")
    ap.add_argument("--review", action="store_true",
                    help="print every one-to-many decision and exit")
    args = ap.parse_args()

    raw = TARGET.read_text(encoding="utf-8")
    doc = json.loads(raw)
    bad = simplified_only()

    if args.review:
        review(doc, bad)
        return 0

    objs = [o for o in locale_objects(doc) if o["zh-Hant"]]
    untranslated = [o for o in objs if is_untranslated(o, bad)]
    clean = [o for o in objs if not is_untranslated(o, bad)]
    by_audit = [o for o in objs if audit_untranslated(o, bad)]
    neutral = len(by_audit) - len(untranslated)

    entries = doc["evidences"]
    hit = sum(1 for e in entries
              if any(audit_untranslated(o, bad)
                     for o in locale_objects(e) if o["zh-Hant"]))

    print(f"zh-Hant fields          {len(objs)}")
    print(f"audit's test reports    {len(by_audit)}")
    print(f"  of which script-neutral {neutral} (correctly identical, no-op)")
    print(f"  actually untranslated   {len(untranslated)}")
    print(f"already converted       {len(clean)}")
    print(f"entries with >=1        {hit} of {len(entries)}")

    already_done = (len(untranslated) == 0)
    if already_done:
        print("\nnothing untranslated — already converted. No-op.")

    # ---- refuse on any drift from the pinned measurement ----
    if not already_done:
        for label, got, want in [
                ("zh-Hant fields", len(objs), EXPECT_HANT_FIELDS),
                ("audit's test", len(by_audit), EXPECT_AUDIT_DEFINITION),
                ("script-neutral", neutral, EXPECT_SCRIPT_NEUTRAL),
                ("untranslated", len(untranslated), EXPECT_UNTRANSLATED),
                ("already converted", len(clean), EXPECT_CLEAN),
                ("entries hit", hit, EXPECT_ENTRIES_HIT),
                ("entries", len(entries), EXPECT_ENTRIES)]:
            if got != want:
                print(f"\nREFUSING: {label} is {got}, pinned at {want}. The "
                      f"asset has been re-imported or edited; the correction "
                      f"table below was read over the old text and is not "
                      f"valid for the new. Re-run with --review and read the "
                      f"one-to-many decisions again before touching this.",
                      file=sys.stderr)
                return 2

    # ---- convert ----
    converted = 0
    for obj in untranslated:
        obj["zh-Hant"] = opencc(obj["zh-Hant"])
        converted += 1

    # ---- correct s2tw's own mistakes, with counts asserted ----
    def apply_table(table, scope, label):
        total = 0
        for wrong, right, want in table:
            n = sum(o["zh-Hant"].count(wrong) for o in scope)
            if n != want:
                print(f"\nREFUSING: {label} rule {wrong!r} -> {right!r} "
                      f"matched {n} times, pinned at {want}. Every row of "
                      f"this table was read in context; a changed count means "
                      f"the text changed and the row must be re-read, not "
                      f"re-run.", file=sys.stderr)
                sys.exit(2)
            for o in scope:
                o["zh-Hant"] = o["zh-Hant"].replace(wrong, right)
            total += n
        return total

    fixes = corr = 0
    if not already_done:
        fixes = apply_table(POST_RULES, untranslated, "post")
        corr = apply_table(CORRUPTIONS, clean, "corruption")
        if fixes != EXPECT_POST_FIXES or corr != EXPECT_CORRUPTIONS:
            print(f"\nREFUSING: {fixes} post-fixes / {corr} corruption fixes, "
                  f"pinned at {EXPECT_POST_FIXES} / {EXPECT_CORRUPTIONS}.",
                  file=sys.stderr)
            return 2
        print(f"\nconverted               {converted} fields "
              f"(opencc -c {OPENCC_CONFIG}, glyph layer only)")
        print(f"corrections to opencc   {fixes}")
        print(f"s2twp corruptions fixed {corr} (in already-converted fields)")

    # ---- guards ----
    problems = []
    for obj in objs:
        v = obj["zh-Hant"]
        if not v:
            problems.append("a zh-Hant field became empty")
        residual = {c for c in v if c in bad}
        if residual:
            problems.append(
                f"Simplified-only {''.join(sorted(residual))} left in "
                f"{v[:36]!r}")
    # Each rule is re-checked only in the scope it was applied to, and only on
    # a run that applied it. Both halves are load-bearing and both were caught
    # being wrong: 儲存 is damage in the already-converted fields and a correct
    # word in the newly converted ones ("用於儲存酒"), so a guard run over the
    # whole file reports 4 false positives — and once the repair has landed
    # every field is "already converted", so running this guard on a no-op
    # re-run reports all 9.
    if not already_done:
        for scope, table in ((untranslated, POST_RULES), (clean, CORRUPTIONS)):
            for wrong, _right, _n in table:
                left = sum(o["zh-Hant"].count(wrong) for o in scope)
                if left:
                    problems.append(
                        f"{wrong!r} still present {left}x after repair")
    if problems:
        print("\nREFUSING — guards failed:", file=sys.stderr)
        for p in problems[:20]:
            print("   ", p, file=sys.stderr)
        return 2
    print("\nguards: no Simplified-only characters remain in any zh-Hant "
          "field; no corrected string survives; no field emptied.")

    if not args.apply:
        print("\nDRY RUN — nothing written. Re-run with --apply.")
        return 0
    if already_done:
        return 0

    TARGET.write_text(
        json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\nwrote {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
