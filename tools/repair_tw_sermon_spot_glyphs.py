#!/usr/bin/env python3
"""The Traditional sermon transcripts' spot glyph errors — 恆, 採, 斗 and 麪.

READ THE ITEM BEFORE THE CODE. `assets/sermons/zh-TW/` is **not** another
instalment of the CUV converter hole and must not be treated as one: it was
produced by a phrase-aware converter that holds 隻 453, 淨 358, 牆 257, 餘 190,
髮 121, 鬆 133, 採 80 and ZERO of the leftovers 凈 / 墻 / 余. None of the
`tools/repair_tr_*.py` scripts applies here and running one would do damage.
What it has instead is spot errors, and the queue asked for a measured pass
over them rather than a sweep. This is that pass. `幹` was the separate,
larger class and is done in `tools/repair_tw_sermon_dry_glyph.py`.

THERE IS NO WITNESS EDITION FOR SERMON TEXT. Every substitution below rests on
one of two things and nothing else:

  1. **The corpus's own convention**, which is decisive where it is lopsided:
     恆 276 / 恒 2, 採取 54 / 采取 3, 採納 3 / 采納 1, 麪包 41 / 面包 8,
     麪粉 16 / 面粉 0. A corpus that spells a word one way 54 times and another
     way 3 times is not making an editorial choice.
  2. **The sentence**, quoted in full in the rule table for every anchored
     rule.

NEVER the preacher's wording. Not one word changes; every rule is one
character for one character and the script refuses if any string changes
length.

WHAT WAS FOUND, AND TWO CLASSES THE QUEUE DID NOT KNOW ABOUT

  恆 (2) — the two the item already named: 156.txt 「背景中恒常存在的」,
  327.txt 「永恒生命」. `test/traditional_constancy_glyph_test.dart` pinned
  these at 276/2 precisely so that fixing them would have to be deliberate;
  that test is updated in the same commit, which is what "deliberate" means.

  採 (4) — NEW. 采取 ×3 (017, 364, C175) and 采納 ×1 (079) against 採取 54 and
  採納 3. The keeps are the interesting half and none is a rule a pattern would
  find: 風采 (018), 興高采烈 (167) and **尼采 ×4** — Nietzsche, a name (174,
  398 ×3).

  斗 (12) — NEW, and the most serious thing in this file, because it is
  **scripture quoted with the wrong glyph**. 斗 (a measuring bowl) was expanded
  to 鬥 (to fight), so Matthew 5:15 reads 「放在鬥底下」 ×8 and 「藏在鬥底下」
  ×1 — the lamp is put under a *fight* — and Matthew 13:33 reads 「藏在三鬥面
  裏」 ×2. The corpus holds 231 鬥 and only 4 斗, so a bare inventory count says
  nothing; every other 鬥 is 戰鬥 / 爭鬥 / 搏鬥 / 打鬥 / 奮鬥 / 好鬥 and is
  right. The 4 surviving 斗 are 斗篷 ×3 (a cloak, 360.txt) and 「用十足的升斗」
  (371.txt, 路 6:38) — the last of which proves the corpus can spell the
  measure when its phrase table happens to carry the collocation.

  麪 (92) — NEW, and the largest class here. The house form in this corpus is
  麪, not 麵: 麪 71, 麵 0. 079.txt is a whole sermon on the parable of the
  leaven and it writes BOTH — 麪粉 and 麪包 21 times, and 面 for the same word
  61 times, including the quotation of 馬太福音 13:33 itself. The asset's own
  internal convention settles it with no witness, exactly as it did for the
  松開 leftover in `biblexg-v2-tr.json`.

    * four corpus-wide collocations — 面酵 63, 面包 8, 麥面 3, 團面 2. 面酵 was
      checked for a word boundary at every one of the 63 (no 裏面酵 / 外面酵)
      and 面包 needs a negative lookbehind, because 073.txt 「它裏面包含了極大
      的真理」 is 裏面 + 包含 and would have been corrupted.
    * fifteen anchored positions in 079.txt where 面 stands alone for the
      dough — 「神的國好像面」, 「放在面裏」, 「無酵的面」, 「面是由什麼做的？
      麥子」. These cannot be a collocation rule and each is quoted below.

  Everything else the audit flagged in this corpus is a FALSE POSITIVE and is
  listed here so it is not re-investigated: 我不幹了 (098, 236 — quitting, not
  drying), 必須根據 (196-1, 342 — 必須 + 根據, not a beard), 那只適用 (371 —
  the adverb), 裏面包含 (073).

Dry-run by default; --apply writes. Re-running after --apply is a no-op.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "assets/sermons/zh-TW"

# (scope, wrong, right, expected, why)
#   scope: a file name, or None for the whole corpus
#   wrong: a regular expression; right: a literal of the SAME length
# Ordered. 三鬥面 must run before the 面酵 collocation so that the two
# characters it owns are not claimed twice.
RULES = (
    # --- 斗 is a measuring bowl; 鬥 is to fight -------------------------------
    ("079.txt", "藏在三鬥面裏", "藏在三斗麪裏", 2,
     "馬太福音 13:33 — three measures of flour, not three fights"),
    (None, "放在鬥底下", "放在斗底下", 8,
     "馬太福音 5:15 — a lamp under a bowl, not under a fight"),
    (None, "藏在鬥底下", "藏在斗底下", 1, "馬太福音 5:15, the other wording"),
    # Found by the test, not by the survey, and worth recording why: the first
    # draft matched on 「放在鬥底下」/「藏在鬥底下」 because that is how the
    # sermons quote 馬太福音 5:15. 075.txt quotes 路加福音 8:16 instead —
    # 「放在牀底下或鬥底下或器皿底下」 — where the offending 鬥 is preceded by
    # 或. A cue drawn from one verse does not cover a parallel passage.
    (None, "或鬥底下", "或斗底下", 1, "路加福音 8:16 — 075.txt"),

    # --- 麪 is flour; 面 is a face, a side, an aspect -------------------------
    (None, "面酵", "麪酵", 63, "leaven — checked for a word boundary at all 63"),
    (None, r"(?<![裏裡外上下前後])面包", "麪包", 8,
     "bread — the lookbehind protects 073.txt 「裏面包含了極大的真理」"),
    (None, "麥面", "麥麪", 3, "wheat flour — 079.txt"),
    (None, "團面", "團麪", 2, "a lump of dough — 401.txt"),
    # …and the fifteen positions in 079.txt where 面 stands alone for dough.
    ("079.txt", "麪酵是神的工作，面是這個世界", "麪酵是神的工作，麪是這個世界", 1,
     "the leaven is God's work, the DOUGH is the world"),
    ("079.txt", "在世界——面——裏面運行", "在世界——麪——裏面運行", 1,
     "the church as leaven in the world — the world being the dough"),
    ("079.txt", "放在麪包裏，放在面裏", "放在麪包裏，放在麪裏", 1, "into the dough"),
    ("079.txt", "神的國好像面，有婦人", "神的國好像麪，有婦人", 1,
     "the kingdom is like DOUGH, a woman took it"),
    ("079.txt", "拿來放進面裏的情形", "拿來放進麪裏的情形", 1, "into the dough"),
    ("079.txt", "你們既是無酵的面", "你們既是無酵的麪", 1,
     "哥林多前書 5:7 — unleavened dough"),
    ("079.txt", "不應該發酵的面", "不應該發酵的麪", 1, "dough that should not rise"),
    ("079.txt", "另一個問題：面指的是什麼", "另一個問題：麪指的是什麼", 1,
     "what does the DOUGH stand for?"),
    ("079.txt", "聖經中關於面的教導", "聖經中關於麪的教導", 1,
     "the Bible's teaching about dough"),
    ("079.txt", "一件事。面總是，並且", "一件事。麪總是，並且", 1,
     "dough always, without exception"),
    ("079.txt", "一個要點。面是由什麼做的", "一個要點。麪是由什麼做的", 1,
     "what is dough made of? wheat"),
    ("079.txt", "翻譯爲\"面\"或\"麪粉\"", "翻譯爲\"麪\"或\"麪粉\"", 1,
     "the Greek word translated 'dough' or 'flour' — the sentence sets both"),
    ("079.txt", "麪酵在面中做什麼", "麪酵在麪中做什麼", 1, "in the dough"),
    ("079.txt", "它對面有什麼貢獻", "它對麪有什麼貢獻", 1, "to the dough"),
    ("079.txt", "它對面沒有任何貢獻", "它對麪沒有任何貢獻", 1, "to the dough"),

    # --- 採 is to pick or adopt; 采 is 風采 / 神采 / 尼采 ----------------------
    (None, "采取", "採取", 3, "against 採取 ×54 in the same corpus"),
    (None, "采納", "採納", 1, "against 採納 ×3"),

    # --- 恆 is constant; 恒 is its Simplified form ----------------------------
    ("156.txt", "背景中恒常存在的", "背景中恆常存在的", 1, "against 恆 ×276"),
    ("327.txt", "看到永恒生命", "看到永恆生命", 1, "against 恆 ×276"),
)

# Readings the rules must NOT reach. Every one is a near-miss for a rule
# directly above it — this is the half that catches a widened pattern.
MUST_SURVIVE = (
    ("073.txt", "它裏面包含了極大的真理"),   # 裏面 + 包含, not bread
    ("174.txt", "像尼采一樣"),               # Nietzsche
    ("018.txt", "特別的風采"),               # bearing, not picking
    ("167.txt", "興高采烈"),
    ("360.txt", "皇家的斗篷"),               # a cloak — already 斗
    ("371.txt", "用十足的升斗"),             # 路 6:38 — already 斗
    ("098.txt", "我不幹了"),                 # quitting, not drying
    ("196-1.txt", "你必須根據需要"),         # 必須 + 根據, not a beard
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    texts = {p.name: p.read_text(encoding="utf-8")
             for p in sorted(DIR.glob("*.txt"))}

    for name, reading in MUST_SURVIVE:
        if reading not in texts.get(name, ""):
            print(f"  ✗ {name}: 「{reading}」 is gone — the survey behind these "
                  f"rules no longer matches the corpus — refusing")
            return 1

    def scope(rule_file):
        return [rule_file] if rule_file else list(texts)

    def total(rx):
        return sum(len(rx.findall(t)) for t in texts.values())

    compiled = [(f, re.compile(w), w, r, n, why) for f, w, r, n, why in RULES]

    # Rules are ORDERED and several later ones only exist once an earlier one
    # has run — 「麪酵是神的工作，面是這個世界」 does not appear in the corpus
    # until 面酵 → 麪酵 has fired. So idempotence is decided rule by rule at
    # its own turn, not by a pre-pass over the original text: a rule that
    # matches zero times but whose repaired reading is already present has
    # run before. Anything else refuses.

    before = {ch: sum(t.count(ch) for t in texts.values())
              for ch in "恆恒採采斗鬥麪麵面"}

    substitutions = 0
    already = 0
    touched: set[str] = set()
    for rule_file, rx, wrong, right, expected, why in compiled:
        names = scope(rule_file)
        n = sum(len(rx.findall(texts[name])) for name in names)
        # `any`, not `all`: a corpus-wide rule is scoped to all 289 files and
        # its repaired reading only ever appears in the handful that had the
        # defect. `all` here made a re-run refuse instead of no-op.
        if n == 0 and any(right in texts[name] for name in names):
            already += 1
            continue
        if n != expected:
            print(f"  \u2717 {wrong} matches {n} times, expected {expected} — "
                  f"the corpus has moved under this script — refusing")
            return 1
        for name in names:
            new, k = rx.subn(right, texts[name])
            if not k:
                continue
            if len(new) != len(texts[name]):
                print(f"  \u2717 {name}: \u300c{wrong}\u300d changed the "
                      f"length of the transcript — this repair is one "
                      f"character for one character and never a rewording — "
                      f"refusing")
                return 1
            texts[name] = new
            touched.add(name)
        substitutions += n
        where = rule_file or "corpus"
        print(f"  {where:12} {wrong} → {right}   ×{expected:<3} {why}")

    if already == len(compiled):
        print("  already applied — nothing to do")
        return 0
    if already:
        print(f"  \u2717 {already} of {len(compiled)} rules had already run — "
              f"the corpus is half-repaired — refusing")
        return 1

    for rule_file, rx, wrong, *_ in compiled:
        for name in scope(rule_file):
            if rx.search(texts[name]):
                print(f"  ✗ {wrong} survives in {name} — refusing")
                return 1

    after = {ch: sum(t.count(ch) for t in texts.values())
             for ch in "恆恒採采斗鬥麪麵面"}
    print(f"\n  {substitutions} substitutions across {len(touched)} files")
    for ch in "恆恒採采斗鬥麪麵面":
        if before[ch] != after[ch]:
            print(f"    {ch}  {before[ch]:>5} → {after[ch]:<5}")
    if after["恒"] != 0:
        print(f"  ✗ {after['恒']} 恒 survive — refusing")
        return 1

    if args.apply:
        for name in sorted(touched):
            (DIR / name).write_text(texts[name], encoding="utf-8")
        print(f"  written → {len(touched)} files under "
              f"{DIR.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
