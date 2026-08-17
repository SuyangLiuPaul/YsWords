# YsWords — autonomous work queue

One item per iteration, top of the list first. Mark `[x]` with a one-line
result when done, and add anything discovered along the way rather than
fixing it inline and forgetting it.

**Priority rule set by the user, 2026-08-10:**
> 经文一定要准确,查经的一定要最高 priority 准确

Anything where the app states something untrue about scripture jumps the
queue, whatever position it is in. An interface that looks wrong is
annoying; **an interface that reads plausibly and is wrong gets believed
and quoted.**

---

## P0 — scripture accuracy

- [x] **The Traditional Bible had no 隻 in it — 548 measure words printed
      in the Simplified form.** 以賽亞書 2:16 read 「他施的船只」;
      馬太福音 18:12 read 「一百只羊」; 「兩只眼」, 「那幾只羊」,
      「一只公牛」 all the same. `assets/cuvs-yhwh-tr.json` is a script
      conversion of the Simplified edition, and whatever produced it had
      no mapping for 只 → 隻 **at all**: the file carried **zero** 隻
      across 31,102 verses. In Traditional Chinese 只 is the adverb
      "only" and 隻 is the classifier; they are separate characters in
      both the Taiwan and Hong Kong standards. This is not a variant
      preference, it is a hole.

      Every structural check the repo has passed on it, because they ask
      whether a verse exists, not whether its characters belong to the
      script the edition claims.

      **Not fixed by re-running a converter.** `opencc -c s2t` disagrees
      with our Traditional in 27,361 positions and in the great majority
      **ours is right** — it prefers 爲/“”/着/衆/喫/羣 where this edition
      sets 為/「」/著/眾/吃/群, and it rewrites 海裏 to 海里 and the place
      name 迦斐托 to 迦斐託. Re-converting would trade one defect for
      thousands. opencc was used only as an **oracle for one character**,
      and all 543 of its verdicts were read: 541 genuine, and **2 wrong**
      — 詩篇 17:14 「脫離那只在今生有福分的世人」 and 以賽亞書 29:17
      「不是只有一點點時候嗎」 are the adverb, so applying it unreviewed
      would have introduced two new defects.

      **The refuter earned its keep — it broke the first version of this
      fix.** The repair was staged as 547 substitutions on a rule that a
      classifier always follows a numeral, 每, 那, 幾 or 船. One hides
      with no numeral in front of it: **民數記 15:12 「按著只數都要這樣
      辦理」**, where 隻數 is a head count of animals. 著 is not a cue and
      opencc's phrase table does not carry 隻數 either, so both the rule
      and the oracle missed it. Caught only by comparing the whole corpus
      against another edition, which is the lesson worth keeping: a rule
      that is right 547 times out of 548 still ships a wrong verse.

      **The witness, and where to find it again.** `assets/cuv-tr.json`,
      the plain 和合本 Traditional (耶和華, not 雅偉), was a separately
      imported edition of the same base text; it was dropped from the
      repo at v1.4.5 but is permanently readable as git blob **`7a2dc43`**
      (`git cat-file -p 7a2dc43`, equivalently `69307c7^:assets/cuv-tr.json`).
      It has **548 隻 / 670 只**. After the repair ours is 548 / 671, and
      every verse agrees with it on the 只/隻 sequence except five, all
      explained: 馬可福音 9:43-46, where our edition splits vv.44/46 into
      「有些抄本」 notes and the witness does not, and the note wording at
      路加福音 11:2 (「有古卷只作」, the adverb — which is the one extra
      只). 梁家鏗's independently produced Traditional NT
      (`assets/biblexg-v2-tr.json`) corroborates 17 of the NT verses.

      The diff is character-for-character **only** 只→隻 across 309
      verses — ids, books, chapters, verse numbers and every text length
      unchanged. `tools/repair_tr_classifier.py` (re-runnable);
      `test/traditional_classifier_test.dart` pins the counts, the two
      adverbs and 隻數, and fails on the pre-fix data.

- [x] **The unambiguous nine of the ~1,100 remaining Simplified
      characters are fixed — 1,004 substitutions.** Same converter, same
      defect as 隻 above: **凈 519** (→淨), **墻 234** (→牆), **余 230**
      (→餘), **镕 11** (→鎔), **鸮 3** (→鴞), **飖 3** (→颻), **腌 2**
      (→醃), **珰 1** (→璫), **鹯 1** (→鸇). 尼希米記 4:6 read
      「修造城墻」, 歷代志上 11:8 「其余的是約押修理」, 詩篇 51:7
      「潔凈我」.

      **A partition, which is stronger evidence than a rule.** Before the
      repair our asset held **zero** of all nine Traditional forms, and
      the witness `7a2dc43` holds **zero** of all nine Simplified ones. A
      converter that never once wrote 淨, 牆 or 餘 in 31,102 verses did
      not choose them — it could not produce them, so there is no
      editorial-preference hypothesis left to rule out.

      Still not applied on the strength of the rule, because two of the
      nine are real Traditional characters and the claim is about this
      corpus rather than about the language: **余** is the classical
      pronoun and a surname, **腌** is 腌臢. Every one of the 1,004 was
      confirmed individually against the witness's same-id verse —
      977 with up to 8 characters of context either side, 25 on one side
      only (where the editions legitimately differ: 雅偉/耶和華, 裏/裡,
      胡/鬍, our `<note: …>` against their （…）), and 2 on equal
      per-verse counts alone (哈巴谷書 2:11 「墻裏」 vs 「牆裡」 with the
      glyph first in the verse; 使徒行傳 18:6 inside note markup).
      `tools/repair_tr_leftover_glyphs.py` refuses if even one cannot be
      confirmed. All 230 余 read 其餘/餘剩/有餘/餘民/餘種/餘地/餘怒/
      餘火/餘福/餘力; both 腌 are 鹽醃.

      The two count differences against the witness were read and are
      edition differences, not defects: 民數記 35:33 repeats the word
      inside an inline note here and not there (519 淨 vs 518), and
      耶利米書 9:7 sets 融化 here where the witness sets 鎔化 (11 鎔
      vs 12).

      The refuter ran a full `difflib` alignment of every affected verse
      after substitution and put 1,003 of 1,004 inside an `equal` region;
      the exception is the 民數記 35:33 note, which has no witness
      counterpart at all. `test/traditional_leftover_glyphs_test.dart`
      pins the nine counts and nine reader-visible verses, and fails on
      the pre-fix data.

- [ ] **The one-to-many Simplified leftovers — 25 classes still open, one
      character at a time.** The rest of the same defect. Every enumerated
      class is now done: ~~**幹 319**~~ **DONE — 199 were dry and now read 乾,
      111 were offence or a name and now read 干** (see below, and it is what
      finally made 詩篇 51:7 read 「乾淨」); ~~**發 1375**~~ **DONE — 88 were
      hair and now read 髮**; ~~**谷 244**~~ **DONE — 67 were grain and now
      read 穀**; ~~**松 51**~~ **DONE — 24 were the verb and now read 鬆**;
      ~~**采 3**~~ **DONE — all three were the verb and now read 採**.

      **The "~2,000 to review" estimate this item used to carry was a guess,
      and it has now been measured — 25 classes, ~1,000 positions.** The
      measurement is a character-inventory diff: every character the witness
      `7a2dc43` uses that our asset does not contain **at all**. Each row
      below is the same hole signature every fixed instalment had — ours holds
      **zero** of the Traditional form across 31,102 verses:

      | Traditional | witness has | ours writes | ours has | witness also has |
      |---|---|---|---|---|
      | 制 | 90 | 製 | 157 | 67 |
      | 恆 | 79 | 恒 | 79 | 0 |
      | 託 | 73 | 托 | 82 | 9 |
      | 痲 | 65 | 麻 | 237 | 172 |
      | 慾 | 65 | 欲 | 75 | 10 |
      | 飢 | 58 | 饑 | 157 | 99 |
      | 准 | 54 | 準 | 94 | 40 |
      | 捨 | 53 | 舍 | 317 | 264 |
      | 姦 | 46 | 奸 | 107 | 61 |
      | 卜 | 42 | 蔔 | 42 | 0 |
      | 凌 | 37 | 淩 | 37 | 0 |
      | 凶 | 37 | 兇 | 47 | 11 |
      | 佔 | 30 | 占 | 56 | 26 |
      | 颳 | 26 | 刮 | 34 | 8 |
      | 症 | 26 | 癥 | 26 | 0 |
      | 冑 | 26 | 胄 | 26 | 0 |
      | 樑 | 25 | 梁 | 27 | 2 |
      | 繫 | 24 | 系 | 34 | 4 |
      | 籤 | 24 | 簽 | 26 | 2 |
      | 杆 | 21 | 桿 | 26 | 5 |
      | 閒 | 18 | 閑 | 19 | 1 |
      | 扎 | 17 | 紮 | 21 | 4 |
      | 儘 | 16 | 盡 | 407 | 391 |
      | 併 | 12 | 並 | 2144 | 2133 |
      | 鬨 | 10 | 哄 | 49 | 39 |

      **Take the five exact partitions first — they are the cheapest
      instalments left and need no judgement at all.** 恆/恒 79, 卜/蔔 42,
      凌/淩 37, 症/癥 26 and 冑/胄 26 each have ours-count == witness-count and
      the witness holding **zero** of our form, so they are whole-class 1:1
      replacements rather than a split. 卜 is the most reader-visible: every
      one of the 42 divinations prints 「占蔔」, which is a radish. Then
      症/癥 (癥 is an abdominal mass, not a symptom), 冑/胄 (甲冑 is a helmet,
      胄 is a descendant) and 淩/凌.

      The other 20 are splits and must be done the way every instalment since
      隻 has been done — position by position against the witness, refusing
      the whole run rather than guessing at one. Note **儘/盡 and 併/並** are
      the 發/髮 shape at its most extreme: our form is correct 391 and 2,133
      times respectively, so only 16 and 12 positions move.

      Two rows worth flagging before someone tries a rule on them: 梁 is also
      the surname (and 梁家鏗 is a version name in this app), and 占 is correct
      in 占卜 while 佔 belongs in 佔領 — so 卜 and 佔 interact and should be
      done in the same pass or in that order.

      **幹 is done — 310 substitutions, 2026-08-18.** The only three-way split
      in the whole class, and the largest instalment since the 1,004: Simplified
      干 collapses 干 (offend/concern/name), 乾 (dry) and 幹 (trunk/ability), and
      the converter had two branches where three were needed — 319 幹 + 22 乾 and
      **ZERO 干**. 199 were dry (詩篇 22:15 「我的精力枯幹」, 出埃及記 14:21
      「海就成了幹地」, 以西結書 37:4 「枯幹的骸骨」, 約翰福音 13:10 「全身就幹淨了」)
      and 111 were offence or a name (民數記 5:6 「幹犯雅偉」, 約書亞記 7:1
      「迦米的兒子亞幹」, 使徒行傳 18:6 「與我無幹」). Only 9 were genuine 幹:
      the lampstand shaft (出 25:31, 37:17), the stump (伯 14:8), 枝幹 ×5
      (結 19:11-14) and 才幹 (太 25:15) — all pinned, all cross-voted against KJV
      ("his shaft", "the stock thereof", "strong rods", "ability").

      **The queue was wrong about this one and it is worth saying why.** This
      item used to warn that 亞幹 / 亞多尼幹 / 隱幹寧 / 斯利幹 and 若幹 "must not
      move". They all move — the published Traditional writes 亞干, 隱干寧,
      若干. The warning came from reasoning about the language rather than
      counting the corpus, which is exactly the failure the measure-first rule
      exists to prevent.

      Decided position by position by folding 幹/乾 → 干 on **both** sides and
      reading the witness's unfolded glyph at the aligned position, so nothing
      rests on a cue — and a cue could not work here anyway: 以西結書 19:12
      「東風吹乾其上的果子，堅固的枝幹折斷枯乾」 holds two readings four
      characters apart, and 使徒行傳 18:6 holds 「與我無干」 and the note
      「我卻乾淨」 in one verse. 233 of 310 resolved on the widest 8-character
      two-sided window, 7 on ordinal position, and **one** had no aligned
      witness text at all: 使徒行傳 8:27 干大基 (Candace), where the witness
      transliterates the whole clause differently (衣索匹亞女王甘大基). Settled
      instead by 新譯本 `57c4686`, by 梁家鏗's independent NT and by our own
      Simplified, all three of which spell it 干大基.

      **The matching 341 totals are NOT corroboration** — the refuter caught
      that. They match only because the two edition differences cancel
      (使徒行傳 8:27 is +1 here, 希伯來書 2:2 is −1). The load-bearing evidence
      is the per-verse ordered-sequence check, which the refuter re-ran with a
      ±4-character context window over every occurrence: 60 deltas, every one
      a known edition convention (雅偉/耶和華, 裏/裡, 什麽/甚麼, 約但/約旦).
      `tools/repair_tr_dry_glyph.py` (re-runnable, idempotent) refuses seven
      ways; `test/traditional_dry_glyph_test.dart` fails six ways on the
      pre-fix data and also fails on a blanket substitution in either
      direction.

      **松/鬆 is done — 24 substitutions, 2026-08-17.** The cheapest instalment so
      far, and the only one whose central claim can be checked *without* the
      witness: all 51 occurrences sit in one of ten fixed collocations, the two
      groups are disjoint and exhaustive — pine 松香 1 / 松木 8 / 松類 3 / 松樹 13 /
      杜松 2 = 27, loosen 松緩 1 / 松手 2 / 松開 7 / 輕松 6 / 放松 8 = 24 — and every
      one of the 51 verses holds exactly **one** occurrence, so no verse mixes the
      readings and an offsetting pair inside a verse is arithmetically impossible
      rather than merely unlikely. Ours had 51 松 + 0 鬆; the witness 27 + 24.
      申命記 15:8 read 「總要向他松開手」, 約伯記 27:6 「必不放松」, 以賽亞書 58:6
      「松開兇惡的繩」, 使徒行傳 16:26 「鎖鏈也都松開了」, 歷代志下 10:4 「輕松些」.
      The traps are on the *keep* side and none is a tree name a rule would spot:
      杜松 is the KJV "heath", 松類 the parenthetical gloss on 羅騰樹 ("juniper")
      and 松香 the pitch of the ark. 約伯記 30:11 is the one position with no
      left-hand context — 鬆 opens the verse — so it is pinned in full.
      Corroborated by the 新譯本 `57c4686` (none of the 27 has 鬆, none of the 24
      has 松), by KJV at all 24 (loosed / slack / release / ease / let it go /
      weakeneth / respite) and by 梁家鏗's independent NT at 使徒行傳 27:40
      (「鬆脫錨鏈，同時鬆開舵繩」). Nothing to do on the Simplified or tagged side:
      Simplified 松 is the correct single form for both meanings and the tagged
      corpus is Simplified-only, never offered on the Traditional version.
      `tools/repair_tr_loosen_glyph.py` (re-runnable, idempotent) refuses seven
      ways; `test/traditional_loosen_glyph_test.dart` fails four ways on the
      pre-fix data.

      **The refuter earned its keep again — it found the same hole one asset
      over.** It could not break any of the seven claims, but while checking
      whether some other Traditional asset carried an unfixed 松 it turned up
      `assets/biblexg-v2-tr.json` id `47005010`, a study note on καταλύω
      glossing 「λύω （松開、解開、摧毀、結束）」 — Simplified 松 inside a
      Traditional asset, and the only 松開 in the file against **five** correct
      鬆開 (太 16:19, 18:18, 徒 27:40). The asset's own internal convention
      settles it without any witness. Fixed in the same commit; its remaining
      three 松 are 甘松/甘松香膏 (spikenard) and are correct. **Worth repeating
      on the earlier instalments:** those were all verified against
      `cuvs-yhwh-tr.json` alone, so the other Traditional assets may still
      carry 髮/麵/穀/鬍/鬚 holes nobody has counted — see the new item below.

      **谷/穀 is done — 68 substitutions, 2026-08-17.** The 發/髮 shape again:
      谷 is *correct* 176 times here, so the claim was "these positions are 穀",
      not "谷 is 穀". Ours had 244 谷 + 1 殼 and ZERO 穀; the witness has 177 +
      68, and 245 = 245 exactly. 創世紀 27:28 read 「許多五谷新酒」, 申命記 25:4
      and its two NT citations 「牛在場上踹谷的時候」, 何西阿書 9:1 「在各谷場上」,
      馬可福音 4:28 「地生五谷是出於自然的」. The traps are the names — 亞谷
      (Akkub), 谷歌大 (Gudgodah), 哈巴谷 (Habakkuk), 谷何西 (Colhozeh) carry no
      valley in their English at all, and 詩篇 65:13 「谷中也長滿了五穀」 is the
      only verse in the corpus holding both readings; all are pinned by
      `test/traditional_grain_glyph_test.dart`.
      `tools/repair_tr_grain_glyph.py` (re-runnable, idempotent) refuses six
      ways, and on the refuter's suggestion now compares the ordered **sequence**
      of 谷/穀 against the witness verse by verse, not just the counts — which is
      what makes an offsetting pair inside one verse impossible rather than
      merely unlikely. The refuter also corrected the arithmetic being claimed:
      67 of the substitutions are 谷→穀 and one is 殼→穀, and 3 of the 68 sit at
      a verse boundary so their "two-sided" match was really one-sided.

- [x] **以賽亞書 36:17 promised a land of husks — 「五殼」/「五壳」 in all three
      assets, 2026-08-17.** Not a conversion defect but a plain textual
      corruption, and the only 殼 in the Traditional corpus, the only 壳 in the
      Simplified one and the only 壳 in the tagged corpus. Found because it is
      the one verse where the 谷/穀 arithmetic ran one short.

      **The tagging settles it without leaving the repo:** the run reading
      「就是有五壳」 is tagged **H1715**, דָּגָן, *"properly, increase, i.e.
      grain"* — so the Strong's number attached to the word says it is grain.
      The parallel Rabshakeh speech at 列王紀下 18:32 is the same sentence with
      the same H1715 run and reads 五谷; the witness reads 五穀; KJV "a land of
      corn and wine"; NASB and LEB "a land of grain and new wine". 殼 is needed
      nowhere else in the corpus — the husk and shell passages read 核…皮
      (民 6:4), 新穗子 (王下 4:42), 不結實 (何 8:7), 豆莢 (路 15:16).

      Fixed in `assets/cuvs-yhwh-tr.json`, `assets/cuvs-yhwh.json` **and**
      `assets/tagged/cuvs-yhwh/isaiah.json` — the last because the Originals
      sheet prints the tagged runs *instead of* the verse, so a reader tapping
      the verse would still have been shown 五壳. `tagged_verse_coverage_test`
      caught exactly that: fixing two assets and not the third pushed its
      pinned disagreement 236 → 237.

      **The error is older than this repo:** SeekSparks' separately imported
      `assets/cuvs-plus.json` carries 五壳 at the same verse. That copy may share
      an upstream e-text with ours, so it says where the error is *not* — not
      where it came from. **SeekSparks has the same defect and its own loop
      writes there; this repo must not.**

      **發/髮 is done — 88 substitutions, 2026-08-17.** It was the largest
      one-to-many class by raw count and the smallest by damage: 發 is
      *correct* 1,287 times here, so the claim was never "發 is 髮" but
      "these 88 positions are 髮", and each was decided against the
      witness rather than against a rule. The obvious rule is wrong —
      詩篇 6:2 「我的骨頭發戰」 and 羅馬書 7:8 「在我裏頭發動」 both contain
      the string 頭發 and are the verb; both are now pinned by the test so
      a later blanket substitution cannot pass. In all 80 verses where the
      witness has 髮 our 發 count equalled its 發+髮 count, and the 88
      confirmed positions matched its 88 髮 exactly, with none ambiguous.
      A separate whole-corpus sweep for hair collocations still reading 發
      (白發, 鬚發, 剃發, 發綹, 發辮, 發網, 毫發 …) went 85 → 0.
      `tools/repair_tr_hair_glyph.py` (re-runnable, idempotent);
      `test/traditional_hair_glyph_test.dart` fails four ways on the
      pre-fix data.

      **A third witness exists, and the next iteration should use it.**
      The refuter turned it up while trying to break the 發 claim:
      `assets/cnv-tr.json`, the **新譯本 Traditional**, also 31,102 verses,
      dropped from the repo but permanently readable as git blob
      **`57c4686`** (`git cat-file -p 57c4686`, from commit `6e93fed`).
      It is a *different translation*, so its wording will not context-match
      — but it is a genuinely independent vote on whether a passage is
      about hair, flour or a wall, which is exactly what the remaining
      one-to-many classes need. It carries 髮 93 / 麵 113 / 鬍 22.
      It agreed on all 88: of its twelve 髮 verses outside our 80, every
      one words the phrase without 發 at all (利 19:27 頭的周圍不可剃,
      王上 2:6 白頭, 賽 22:12 頭上光禿, 徒 21:24 剃頭 …).

      `tools/fix_traditional_conversion.py` already carries drafted rules
      and the exclusion lists for all of these, and
      `tools/render_tr_fix_review.py` renders them as a reviewable page
      (the rendered HTML is a regenerable artifact and is not committed).
      **The script has never been applied and carries a banner saying so**
      — its cue rule is the very one that missed 民數記 15:12, so do not
      run `--apply` on it as it stands. Take one character per iteration,
      and follow the shape of `tools/repair_tr_leftover_glyphs.py`: decide
      each occurrence against `7a2dc43` and refuse the whole run rather
      than guess at one. Start with **發/髮**, which is the most
      reader-visible (頭髮, 白髮) and the easiest to bound — the
      Traditional 髮 does not occur in our asset at all, and the witness
      says where it belongs.

      Caution when reading the witness: it is a *different edition*, so
      many differences are not defects — 裏/裡, 麽/麼, 什/甚, 的/地, 那/哪,
      它/牠 and the transliterations 侖/崙, 瑪/馬, 毗/毘 are conventions
      this edition is entitled to, and 雅偉/耶和華 is the whole point of
      ours. Only glyphs with no Traditional existence are safe to take on
      the witness's word alone.

- [x] **The last counted converter hole: 麵 — DONE, 107 substitutions
      across 90 verses, 2026-08-17.** All four holes in this item are now
      closed (麵, 鬍, 鬚, 採). They were found 2026-08-17 by the refuter
      while it was attacking the 發/髮 claim.

      Counts, ours against witness `7a2dc43`, verified independently
      before being written here:

      | glyph | ours was | witness | what ours printed instead |
      |---|---|---|---|
      | 麵 flour | **0** | 107 | 面 — 「細面」 for 細麵 all through 利未記 ✅ fixed |
      | 鬍 beard | **0** | 21 | 胡 — 「胡須」 for 鬍鬚 ✅ fixed |
      | 鬚 beard | **0** | 20 | 須 — the other half of 「胡須」 ✅ fixed |
      | 採 gather | **0** | 3 | 采 ✅ fixed |

      Same signature as every previous instalment: our file contains
      **zero** of the Traditional form, so it is a hole and not a
      preference. Order they were done in:

      1. ~~**採**~~ and ~~**鬍/鬚**~~ — **DONE, 44 substitutions across 25
         verses, 2026-08-17** (胡→鬍 21, 須→鬚 20, 采→採 3). The table
         above understates it: 鬚 was a **fourth** hole nobody had counted,
         0 against the witness's 20, so 「胡須」 was wrong in *both*
         characters.

         Neither 胡 nor 須 is a partition — 7 胡 are genuine (基列胡瑣,
         伊胡得, 胡巴, 胡言亂語 ×3, 胡寫亂畫) and 86 須 are 必須/須要 — and
         **撒母耳記上 21:13 carries one of each in the same verse**
         (「在城門的門扇上胡寫亂畫，使唾沫流在鬍子上」), so this could not be
         decided a verse at a time, let alone by a rule. 鬍鬚 also defeats
         the substitute-and-look-for-it method used for 淨/牆/餘, because two
         glyphs under repair sit side by side and neither can be confirmed
         until the other has been. `tools/repair_tr_beard_glyph.py` therefore
         **folds both texts** (鬍→胡, 鬚→須, 採→采), aligns on the widest
         context that matches unambiguously, and reads the *unfolded*
         witness at that position. It refuses the whole run three ways: on
         a per-verse count mismatch, on corpus totals missing the witness's
         21/20/3, and on any beard collocation still reading 胡/須 (21
         before → 0 after, a sweep that does not depend on the witness).

         **A cross-language check settled it independently of any witness:**
         all 19 KJV verses containing "beard" now have 鬍/鬚 on our side,
         and every verse where we now write 鬍/鬚 has "beard" in its KJV
         verse bar three that are explainable (利未記 13:33 "He shall be
         shaven", 歷代志上 19:4 "shaved them", 以賽亞書 50:6 "plucked off
         the hair"). The 新譯本 witness `57c4686` agrees on all 22 verses;
         its three extra are 以西結書 5:2-4, where the CUV simply does not
         repeat the noun. All 3 採 are the verb, matching KJV "cut up
         mallows" / "gathered" / "gather", and 梁家鏗's independent
         Traditional NT draws the same line (採摘/採納 but 興高采烈/風采).
         `test/traditional_beard_glyph_test.dart` pins both sides — a
         blanket substitution and a revert each fail it.

         **Worth knowing for the remaining instalments:** the converter
         *was* one-to-many capable (干 341 → 幹 319 + 乾 22; 后 1289 → 后 51
         + 後 1238), it simply had no entry for these. And it was **not**
         vanilla OpenCC — stock `s2t` produces 鬍鬚 and 採 here, and 沉
         where this edition sets 沈. So it is a custom or older map, which
         is why "the converter could not produce it" keeps holding.
      2. ~~**麵**~~ — **DONE, 107 substitutions across 90 verses,
         2026-08-17.** The big one, and the one most worth getting right:
         「細麵」 (fine flour) is the substance of the grain offering, so
         「一伊法細面」 read as a measure of *face* all through 利未記,
         民數記 and 以西結書; 摶麵盆 (kneadingtrough) read 摶面盆 and
         「一點麵酵能使全團發起來」 read 面酵.

         The 發/髮 shape, not the 淨/牆 shape — 面 is **correct 2,077
         times** here (面前 alone is 1,186), so the claim was never "面 is
         麵" but "these 107 positions are 麵". Each was decided against
         witness `7a2dc43` by substituting and looking for the result
         verbatim: 104 resolved on a two-sided 6–8 character window, 3 on
         the left only, **none ambiguous**, and no verse fell short of the
         witness's count. `tools/repair_tr_flour_glyph.py` (re-runnable,
         idempotent) refuses the whole run four ways, including a
         witness-independent sweep for flour collocations still reading
         面 — 118 before → 0 after.

         **The refuter closed the one hole in that arithmetic.** A false
         convert at a face position plus a miss at a flour position in the
         *same* verse would balance the per-verse count and pass. That
         needs a verse holding both glyphs, and in the whole corpus there
         is exactly **one**: 士師記 6:19 「用一伊法細麵做了無酵餅 … 獻在
         使者面前」. The repair converts 細麵 and leaves 面前. It also
         blind-aligned all 90 verses with 面/麵 masked — 56 byte-identical,
         34 differing only in known orthographic noise (裏/裡, 壇/罈,
         谷/穀 …) — so no 麵 position is unaligned.

         Two independent votes: **KJV** has flour/meal/leaven/dough/bread/
         kneadingtrough/lump/cake/wafer in 83 of the 90, and the other 7
         are still flour on inspection (利 5:13 "the remnant", 申 28:5/17
         摶麵盆 = "thy store", 結 45:24 / 46:5, 7, 11 "a meat offering of an
         ephah"). **新譯本** `57c4686` has 麵 in 86 of the 90; the four it
         lacks word the phrase without the noun at all.
         `test/traditional_flour_glyph_test.dart` pins both directions and
         fails three ways on the pre-fix data.

      Use **both** witnesses now (`7a2dc43` and the 新譯本 `57c4686`).

- [x] **The fifth converter hole: 罈 — DONE, 6 substitutions across 5
      verses, 2026-08-17.** Simplified 坛 collapses 壇 (altar) and 罈 (jar),
      and the converter resolved every one to 壇. So the jar of meal in the
      Elijah narrative was an *altar*: 列王紀上 17:12 read 「壇內只有一把
      麵」 and 17:14, 17:16 「壇內的麵必不減少／果不減少」; 耶利米書 13:12
      filled altars with wine and 48:12 broke Moab's 壇子.

      Same signature as every previous instalment: ours had 613 壇 and
      **ZERO** 罈; the witness `7a2dc43` has 607 壇 and 6 罈, and
      613 = 607 + 6 exactly. Fixed: 列王紀上 17:12, 17:14, 17:16 (KJV "the
      barrel of meal"), 耶利米書 13:12, which holds **two** 「各罈都要盛滿
      了酒」 (KJV "Every bottle shall be filled with wine"), and 耶利米書
      48:12 (KJV "break their bottles"). 607 of the 613 are the genuine
      altar, so this was the 發/髮 shape, not the 淨/牆 shape; each of the
      6 was decided against the witness by `tools/repair_tr_jar_glyph.py`
      (re-runnable, idempotent) and all 6 resolved on a two-sided context
      match, none ambiguous.

      **A cue rule would have desecrated two altars, which is why the
      audit spells its cues out in full.** 「各壇」 occurs four times and
      only the two in 耶利米書 13:12 are jars — 歷代志下 33:15 「所築的各壇
      都拆毀」 and 阿摩司書 2:8 「在各壇旁鋪人所當的衣服」 are altars. Both
      are now pinned by `test/traditional_jar_glyph_test.dart`, which fails
      three ways on the pre-fix data and also fails on a blanket
      substitution.

      **The refuter failed to break it and made the case stronger.** It
      abandoned the KJV word list and ran the complement instead: of all
      613 壇 verses only 77 lack "altar" in KJV *and* NASB *and* LEB, and
      reading all 77 found 71 邱壇 (high place) and 6 pronoun-referenced
      altars — no further jar. A per-`id` diff against the witness shows
      exactly 5 ids differing and all in one direction, so the aggregate
      613 = 607 + 6 cannot be hiding offsetting errors. The three rows the
      two files do not share (ours-only 約翰福音 7:53; witness-only two)
      contain neither glyph. 新譯本 `57c4686` words all five with
      缸/酒瓶/酒缸, and its single 罈 (約翰福音 19:29) is a verse where the
      CUV reads 器皿 and has no 壇 to repair. 希伯來書 9:4's 壇 is a
      footnote gloss for the golden incense altar and is correct.
      The bundled CJK subset `assets/fonts/NotoSansSC-YsWords.otf` already
      covers U+7F48, so 罈 renders rather than tofu.

- [ ] **The Strong's glosses have the same converter hole, and they carry
      their own witness.** Found 2026-08-18 by the refuter attacking the
      幹 instalment, which had claimed no other asset needed the repair —
      that claim was wrong, and this is the better half of what it found.

      `assets/strongs/hebrew.json` and `greek.json` hold BOTH a Simplified
      field and an explicitly Traditional one for every entry (`defZh` /
      `defZhTw`, `glossZh` / `glossZhTw`), so **the Simplified twin is a
      per-string witness sitting in the same file** — no git blob, no second
      edition, no alignment. That makes this the cheapest-to-verify item in
      the whole P0 section.

      Confirmed defects in the `*ZhTw` fields, each with its `*Zh` twin
      showing the intended reading:

      | Strong's | Traditional field reads | should read | twin |
      |---|---|---|---|
      | H374, H1324, H6894 | 幹物 | 乾物 (dry measure) | 干物 |
      | H650, H1308, G5493 | 幹河 / 幹河谷 | 乾河 / 乾河谷 | 干河 |
      | H926 | 被幹擾 | 被干擾 | 被干扰 |
      | H2717 | 幹掉 | 乾掉 | 干掉 |
      | H5405 | 被幹涸 | 被乾涸 | 被干涸 |
      | H467 | 亞多尼幹 | 亞多尼干 | 亚多尼干 |
      | H4445 | 瑪拉幹 | 瑪拉干 | 玛拉干 |
      | H5911 | 亞幹 (Achan) | 亞干 | 亚干 |

      **This is the 發/髮 shape — most 幹 there are correct** (樹幹 H1503,
      H3657, H3661, H6086, H6136; 枝幹 H6056; 幹活 G2038), so do NOT
      blanket-substitute. H5911 is the one to check first: it glosses 亞割谷
      as where 亞干's family was stoned, and the app prints Strong's glosses
      on the Originals sheet, so a reader looking up the name is shown a
      spelling the Bible text itself no longer uses.

      **Scope it for all 17 glyphs, not just 幹.** Nothing has ever counted
      隻/淨/牆/餘/髮/鬍/鬚/採/麵/罈/穀/鬆 in these two files, and the same
      converter signature is likely. The twin-field witness makes a
      whole-sweep script practical in one pass.

- [ ] **17 wrong 幹 in the Traditional sermon assets.** `assets/sermons/zh-TW/`
      holds 142 幹 across 60 files and **the great majority are correct** —
      才幹 (~40), 幹活, 幹什麼, 幹部, 樹幹, 軀幹, 主幹道, 幹掉. The 發/髮 shape
      again. The wrong ones are dryness: 哭幹了眼淚, 排幹了, 水庫幹了,
      溪也幹了, 幹枯, 幹蘿蔔 ×4, 嘴幹, 一把幹沙, 凍幹食品, 幹淨 ×2, plus
      幹擾 ×2 which is 干. Lower priority than the Strong's item — these are
      sermon transcripts, not scripture — but they are reader-visible prose
      and there is no witness for them, so each has to be read.

- [ ] **`丶` stands in for the enumeration comma 、 in 53 places, in BOTH
      editions.** 出埃及記 15:4 reads 「法老的車輛丶軍兵」, 15:25 「定了律例丶
      典章」, 24:1 「你和亞倫丶拿答丶亞比戶」. `丶` is U+4E36, the CJK *stroke
      radical* — a dictionary head component, not punctuation.

      Ours holds 53 in the Traditional asset and 53 in the Simplified one;
      the witness `7a2dc43` holds **zero** and writes 、 at those positions.
      Equal counts on both sides say this is **upstream of the Traditional
      conversion**, not caused by it, so it must be fixed in both assets (and
      the tagged corpus checked). Low risk — 丶 has no legitimate use in
      running text — but count it in the tagged Strong's corpus first, and
      check the bundled CJK subset covers nothing that would change.

- [ ] **出埃及記 25:35 has a doubled comma before a full stop, in both
      editions.** 「有球與枝子接連一塊，，。燈臺出的六個枝子都是如此。」 The
      witness reads 「接連一塊。燈臺出的…」. Found 2026-08-18 by the refuter.
      Same signature as the 丶 item — present identically in
      `cuvs-yhwh-tr.json` and `cuvs-yhwh.json`, so upstream. Worth a
      whole-corpus sweep for other doubled or orphaned punctuation before
      fixing this one verse, per the measure-before-concluding rule.

- [ ] **希伯來書 2:2 may be missing 干犯 — needs the user, or a third
      witness.** Ours reads 「凡犯悖逆的都受了該受的報應」; the witness
      `7a2dc43` and the 新譯本 `57c4686` both read 「凡干犯悖逆的」, which is
      also the standard CUV. **Our own Simplified asset drops it too**, so it
      is upstream of the Traditional conversion and not a glyph defect.

      Not fixed, deliberately: restoring it means *writing a character into
      scripture*, which the standing rule forbids doing on inference. Check
      the tagged Strong's corpus for 希伯來書 2:2 first — if the tagged runs
      carry the word, that settles it from inside the repo the way H1715 did
      for 五穀 at 以賽亞書 36:17.

- [ ] **梁家鏗's Traditional NT has the same classifier defect, smaller.**
      `assets/biblexg-v2-tr.json` has 398 只 against only 50 隻, and at
      least one is certainly wrong: **路加福音 5:7 「把兩只船裝得滿滿的」**
      — a classifier after 兩, which its own 「一隻羊」 elsewhere shows it
      knows how to set. Found while using it as a witness for the CUV fix.
      It is a different pipeline and a much smaller file, so it needs its
      own count before anything is applied. Note it has **none** of the
      凈/墻/余 leftovers, so its converter was not the same one.

      Update 2026-08-17: it did carry **one** 松/鬆 leftover, in a study note
      rather than in the translation — `47005010` glossed λύω as 松開 against
      five correct 鬆開 elsewhere in the file. Fixed with the CUV 松 instalment.
      So its converter was not the same one, but it was not clean either, and
      **the notes are as reader-visible as the verses**.

- [ ] **Audit every OTHER Traditional asset for the eight glyph holes already
      fixed in the CUV.** Every instalment so far (隻, 淨/牆/餘, 髮, 鬍/鬚/採,
      麵, 罈, 穀, 鬆) was counted in `assets/cuvs-yhwh-tr.json` and nowhere
      else, so the same holes may sit unfixed in the other Traditional-bearing
      assets — and the 松 instalment proved the risk is real rather than
      theoretical by turning one up in `biblexg-v2-tr.json`.

      Update 2026-08-18: **two of the candidates are now confirmed, not
      hypothetical** — `assets/strongs/*.json` and `assets/sermons/zh-TW/`
      both carry the 幹 hole (see the two items above, which have the counts).
      The Strong's files have a Simplified twin field per entry, so they can
      be swept for all 17 glyphs in one pass without any external witness;
      do that one first and it will answer most of this item.

      Scope the rest, then fix one asset at a time. Candidates: the exegesis
      notes and `blockNotes` in `biblexg-v2-tr.json`, `book_introductions.json`,
      `section_titles.json`, `misconceptions.json`, `bible_evidence.json`,
      `songs.json`, `daily_verses.json`, `cross_references.json` and the
      Traditional strings in `lib/constants/ui_strings.dart`. **Search
      structurally, not just in `text` fields** — the 松 defect was found in a
      `blockNotes` list, which a `text`-only scan walks straight past. The
      cheap first pass is: for each of the 17 Traditional forms, count it and
      its Simplified counterpart across the whole JSON of each asset; a file
      holding the Simplified form and **zero** of the Traditional one has the
      same hole signature the CUV had. Do NOT blanket-substitute — several of
      these (松/杜松, 谷/山谷, 發/出發, 面/前面, 余/其余) are correct far more
      often than not.

- [x] **20 Bible Evidence cards printed a narrower passage than the one
      they cite.** Found while investigating the 「两个经文只能去一个」
      report below, and it outranks it: that item is about a link you
      cannot follow, this one is about a reference that is wrong on
      screen.

      `localizedReferenceLabel` re-rendered the label from the parsed
      `BibleReference`, and `parseReference` **deliberately narrows** —
      it stops at the first comma and keeps only the opening chapter of
      a range, because its job is to produce ONE navigable target. Right
      for deciding where to jump, wrong for deciding what to print.

      | the entry cites | the card printed |
      |---|---|
      | `2 Kings 19-20; Isaiah 37-39` | 列王纪下 19; 以赛亚书 37 |
      | `Acts 27:27-28:1` | 使徒行传 27:27 |
      | `2 Kings 9:2–10:36` | 列王纪下 9:2 |
      | `Daniel 2, 7, 8, 11` | 但以理书 2 |
      | `Acts 19:11-20, 23-41` | 使徒行传 19:11-20 |
      | `Jude 14-15` | 犹大书 1:14 |

      Jude is the worst of them: a one-chapter book, so `14-15` is
      verses — the label both re-punctuated the citation and dropped
      v15.

      **Counted before concluding, as the rule requires: 25 of 225
      entries rendered differently from their source, of which 20 lost
      cited text.** The other 5 are the canonical rename Psalm → Psalms,
      which is correct and was left.

      Fixed at the shared layer, so all four surfaces that show a
      reference are corrected at once (the evidence list card, the
      detail chip, the share text and the trivia page): the book name is
      now swapped in place and **the cited chapter/verse text is kept
      verbatim**. Navigation is untouched — jumping to the first verse
      of a range is still right; only the claim on screen changed. The
      split point is accepted only once the prefix alone resolves to the
      same book as the whole segment, so `1 Corinthians 13` cannot split
      at the `1` and re-attribute a verse.

      `test/reference_label_citation_test.dart` walks the whole asset in
      three locales and compares the citation tail rather than a list of
      20 references, so it also catches an entry nobody has read yet. It
      fails on the pre-fix code naming all 20.

      **Accepted side effect, worth a look on a phone:** the label is now
      a few characters longer for those 20, and the list cards in
      `evidence_page.dart` render it `maxLines: 1` with an ellipsis, so
      the longest — 「使徒行传 19:11-20, 23-41」 — may cut on a narrow
      card. That is a visibly truncated citation rather than a silently
      narrowed one, which is the right way round, but if it looks bad
      the card should wrap to two lines rather than go back to lying.

- [x] **Switching translation silently fails, and you have to try
      several times — the chip was reading a variable the text does not
      follow, and a failed load had no way of telling anyone.**
      User, 2026-08-16, on macOS AND on the iPhone: "我发现从雅伟版换成梁
      版的时候，为什么没有切换我试多几次就可以了" / "我发现一定要在iphone
      ios version上面换version几次才切换过去".

      Two defects, one visible symptom.

      **1. The chip could not do anything BUT lie.** `currentVersion`
      moves the instant a switch starts — it is the input
      `FetchVerses.execute` reads to pick an asset — while `verses` only
      moves when the decode commits, 1–3 s later or never. The header
      chip, the mini-header and the section-title lookup all read
      `currentVersion`, so for the whole span of a slow switch the app
      named 梁简 over 和合本雅伟版 text. Fixed by adding
      `MainProvider.renderedVersion`, which is written **only** where
      `verses` is written (`setVerses` and `useCachedVersion`), and
      pointing all three readers at it. The label now follows the
      verses by construction, so it cannot lead them again.

      **2. A failed switch threw into the void.** `FetchVerses.execute`
      rethrows once its final attempt fails (added so the loading page's
      Retry button could surface a real error). `onVersionSelected`'s
      `try` had only a `finally` — no `catch` — so the throw jumped past
      the `verses.isEmpty` recovery below it and escaped an un-awaited
      async callback. Result: no snackbar, no revert, and
      `currentVersion` parked on a version whose text never arrived.
      **That is the "try a few more times and it works":** each tap was a
      fresh asset fetch and one of them eventually succeeded. The pane
      now catches, reverts to the version actually on screen, and shows
      the load-error snackbar.

      `test/version_switch_label_test.dart` asserts the invariant — the
      label follows the verses — across the optimistic switch, the throw,
      the warm-cache fast path, the cache miss, and a switch away and
      back. It checks the fast path from **inside** the listener, so no
      observer can ever see a frame where label and verses name different
      translations. Two of the six fail on the pre-fix behaviour.

      If the report recurs after this, the next suspect is
      `_reanchorPageForVersionSwitch` — its post-frame `jumpToPage` runs
      against a PageView whose `itemCount` resizes 1189 ↔ 260 when the
      canon changes (梁家铿 is NT-only).

- [x] **The verse picker offers a different book from the one being
      read — the full-screen picker was seeded once and never told the
      reader had moved.**
      User, 2026-08-16, with a screenshot: the reader is in 列王纪下 3
      while the picker panel is headed 使徒行传 15 and offers verses
      1-41. Picking one would jump somewhere the user did not ask for,
      or silently do nothing.

      Same class as the item above — the interface naming one passage
      while showing another.

      **What seeds the picker, measured rather than guessed.**
      `BookChapterPicker` re-syncs itself in exactly one place —
      `didUpdateWidget` — so it can only learn that the reader moved
      through NEW PROPS. Its two hosts supply those props differently,
      and only one of them was correct:

      | host | props | follows the reader |
      |---|---|---|
      | docked sidebar (`SidebarPanel`) | `mainProvider.currentBook/currentChapter`, read live under `context.watch` | yes |
      | full-screen route (`BooksPage`) | `bookIdx`/`chapterIdx`, **constructor arguments frozen at push time** | no |

      Worse, `BooksPage`'s `providerOverride` path — the one the reading
      pane actually uses — wrapped the page in
      `ChangeNotifierProvider.value` with **no Consumer**, so the page
      did not even rebuild when the provider changed. Nothing underneath
      that route could reach the picker: a web back/forward through
      `url_sync_service_web`, a queued jump, a restore completing.

      Fixed by making the route read where the reader is NOW —
      `mainProvider.currentBook ?? bookIdx` — under a Consumer, so both
      hosts are live and the picker's existing cross-book reset finally
      fires. `test/verse_picker_follows_reader_test.dart` drives the
      real widget through both hosts: tap the book, tap the chapter,
      move the reader, assert the verse grid is gone. The sidebar case
      passes on the pre-fix code, the route case fails on it — which is
      the evidence that the two hosts genuinely differed.

      **Two things deliberately left alone, so the next iteration does
      not "fix" them:**
      1. Drilling into another book and STAYING there is legitimate — a
         user browsing 使徒行传 15 from 列王纪下 3 asked for that, and
         picking a verse now always lands on the reference the grid
         offered (`navigateToChapterVerse` commits book, chapter and
         verse together).
      2. `didUpdateWidget`'s same-book branch makes the grid FOLLOW the
         pane's chapter — see the new item below.

- [ ] **The verse grid can change chapter under the user's finger —
      needs the user's call, because the current behaviour was asked
      for.** Found while fixing the item above.
      `book_chapter_picker.dart` `didUpdateWidget`: while the verse grid
      is open for a chapter of the book being read, any chapter change
      in the pane rewrites the grid's chapter (`_verseStepBook ==
      currentBook && chapterChanged → newVerseStepChapter =
      currentChapter`).

      Deliberate, per the v1.2.76 comment: opening the grid and then
      pressing Prev/Next should slide the grid along rather than bounce
      out to the chapters strip. But it also means a user who opened
      使徒行传 3's grid while the pane sits on 使徒行传 15 loses their
      choice if the pane moves — and then a tap on 「5」 goes to the
      pane's chapter, not the one they were looking at. That is the
      "jumps somewhere the user did not ask for" half of the report,
      and it is the only remaining way to reach it.

      Not fixed unilaterally: the two behaviours are mutually exclusive
      and the existing one is a recorded user preference. Ask which
      wins — the pane leading the grid, or the grid holding what the
      user opened.

- [x] **15 verses of the CUV were blank on screen — the importer had
      filed them as footnotes.** Both editions, so 30 verse instances.
      以賽亞書 23:13, 約書亞記 2:6, 撒母耳記上 5:5 / 21:7, 列王紀上 11:32,
      尼希米記 3:26, 約伯記 15:19 / 31:6 / 31:30 / 31:32, 以賽亞書 32:19,
      耶利米書 15:12 / 29:2 / 48:10 / 50:28.

      The CUV sets some verses entirely in parentheses — narrative
      asides like 「（先是女人領二人上了房頂……）」 — and our importer
      turned every parenthesis into `<note: …>`. A note is not text: the
      reading pane renders it as a tappable book icon, and
      `sanitizeVerseText` drops it, so copy, share, search and the
      Originals sheet's verse line all saw an empty string. Where the
      parenthesis covered the WHOLE verse the reader got a verse number,
      an icon, and **no scripture at all**.

      Every structural check the repo already had passes on this data —
      the reference is unique, the text is non-empty on disk, no stray
      character — because they all read the file rather than what the
      reader sees. The new test sanitises through the app's own
      `sanitizeVerseText` before asserting.

      **Which notes are scripture was decided by evidence, not by
      reading the Chinese.** `assets/tagged/cuvs-yhwh/` is a separate
      import of the same edition and it kept the distinction ours lost:
      `（…）` for parenthetical scripture, `〔…〕` for an editorial or
      variant note. Measured over all 1,290 of our `<note:>` spans it
      brackets 1,134 as editorial, carries 104 as scripture and lacks 52
      entirely — so the great majority of our notes really are notes.
      SeekSparks' separately sourced `cuvs-plus.json` agrees on every one
      of the 15. **Seven whole-verse notes were left exactly as they
      were**, because there the edition itself says the text is not
      there — 馬可福音 7:16 / 9:44 / 9:46, 使徒行傳 8:37 / 15:34
      (「有古卷在此有」), 約翰福音 7:53 (「見下節」), 詩篇 63:6
      (「並入上一節」) — and the witness brackets exactly those seven
      `〔…〕`. Promoting one of them would put a disputed reading on
      screen as scripture.

      No text came from another edition: the restored verse is our own
      note body moved back into the verse inside the parentheses the CUV
      prints. One character was restored — 約書亞記 2:6 read 所擺的麻**中**
      where both independent copies read 所擺的麻**秸**中 — and it is
      named in the tool rather than fixed silently.
      `tools/repair_demoted_parentheticals.py`;
      `test/bible_version_integrity_test.dart` fails on the pre-fix data
      with the right diagnosis.

- [x] **86 more parentheses were demoted the same way, mid-verse — now
      restored, in both editions.** 撒母耳記下 21:12 showed
      「大衛就去……搬了來」 and hid 「（是因非利士人從前在基利波殺掃羅……）」
      behind the icon; 利未記 24:11 hid 「（他母親名叫示羅密……）」. Lower
      harm than a blank verse, but the same defect: a clause of
      scripture the reader cannot see, and which copy, share and search
      never had.

      **All 90 candidates were read before applying, and four were
      refused.** Both witnesses print them inline, and agreeing
      witnesses still do not make a sentence Bible:

      | left alone | why |
      |---|---|
      | 約翰三書 1:14 「15节」 | a versification label, not text — see the new item below |
      | 約書亞記 19:2 「或名示巴」 | speaks about the rendering |
      | 約伯記 14:14 「或译：改变」 | a translator's alternative |
      | 約伯記 20:19 「或译：强取房屋不得再建造」 | a translator's alternative |

      The line drawn: 「基列亞巴就是希伯崙」 says something about the
      world and stands in the Hebrew, so it is scripture; 「或譯：改變」
      says something about the translation and exists only because a
      translator hesitated. Promoting one of those would put a footnote
      on screen as scripture — the exact failure this item warned about
      — while leaving it a note loses nothing, because the verse reads
      whole without it.

      **The verification, not the count, is the evidence.** Splicing the
      note body back in makes our visible verse text
      character-for-character identical to the independently imported
      `assets/tagged/cuvs-yhwh/` in **all 86** — where before the repair
      it matched in **0 of 86**. One orthographic variant is named rather
      than "fixed" (但以理書 6:2, our 回復 vs the witness's 回覆; ours is
      the standard form). SeekSparks' separately sourced `cuvs-plus.json`
      corroborates 80; the other 6 differ only by the divine name
      (雅偉/耶和華), which defeats a substring match.
      `tools/repair_midverse_parentheticals.py`.

      The new test walks the WHOLE corpus against the witness rather
      than a list of 86 references, so it also fails if a future
      re-import demotes a parenthesis nobody has seen yet. It reports 86
      on the pre-fix data and 0 after.

- [ ] **約翰三書 1:14 — does verse 15 deserve its own number?** Found
      while reading the 90 above. Our asset prints 「願你平安。眾位朋友
      都問你安……」 as running text inside verse 14 and demoted only the
      label 「15节」 to a note; the Eagle's View import folds the same
      sentence into 14 as 「（15节： 願你平安……）」. So no scripture is
      missing either way — but the app lists 3 John as having 14 verses
      while most printed editions have 15, and a reader looking up
      3 John 15 will not find it.

      **Not repairable from evidence, because it is not a text
      question.** Splicing 「（15节）」 into the verse would print an
      editorial marker as scripture; splitting the verse changes our
      versification and every id, highlight and note anchored to
      3 John 1:14. The user should decide which edition we follow.

      **Two facts found later that sharpen the decision — the app
      already answers this question BOTH ways.** Measured while adding
      `test/citation_target_in_canon_test.dart`:
      * `assets/nasb.json` and `assets/leb.json` each print 3 John 1:15
        as its own verse (「Peace be to you. The friends greet you…」),
        while `kjv.json` and `cuvs-yhwh.json` end at 14. So a reader who
        looks up 3 John 15 finds it on NASB or LEB and does not on the
        Chinese — the same book, two verse counts, inside one app.
      * `assets/cross_references.json` has a source key `3 John 1:15`
        carrying John 10:3 (「he calleth his own sheep by name」, against
        「Greet the friends by name」). On NASB/LEB that cross-reference
        is reachable; on the CUV editions the sentence is inside verse
        14 and its cross-reference cannot be opened at all.

      So the cost of leaving it is not "3 John 15 is missing" — it is
      that the two halves of the app disagree, and the Chinese reader
      quietly loses one cross-reference. Still the user's call.

- [x] **185 verses printed the importer's own Strong's markers as
      scripture.** Found while measuring the 約伯記 10:20/10:21 item
      below, which asked whether `assets/tagged/` and the reading asset
      agree. The verse keys agree perfectly — 31,102 on each side, 0
      divergence, measured — but the TEXT does not, and the reason
      turned out to be worse than a numbering question.

      The Originals sheet prints the tagged runs **instead of** the
      verse (`originals_sheet.dart` renders `_taggedVerseLine(vo.tagged!)`
      for any verse that has tagging), so `assets/tagged/cuvs-yhwh/` is
      scripture on screen. It carried 207 leftover markers in 185
      verses:

      | reference | printed to the reader |
      |---|---|
      | 詩篇 7:5 | `使<WH7931s>我的荣耀归于灰尘` |
      | 創世記 3:16 | `又对<WH413<女人说` |
      | 列王紀上 21:8 | `送给<WH5612x那些与拿伯同城居住的长老>贵胄` |
      | 路加福音 20:42 | `对我主# 说` |

      The last two are why this is an accuracy defect and not a
      cosmetic one. In 列王紀上 21:8 the marker **swallows twelve
      characters of the verse**, so a reader cannot tell which part is
      scripture; and `主#` stands where the edition prints 主[基督] —
      its own referent gloss, the same bracket the importer kept intact
      for 主[雅伟] two words earlier in the very same verse
      (使徒行傳 2:34). 17 such placeholders in 15 verses.

      **The rule was derived from the data, not guessed.** Every marker
      is `<` or `>` with ASCII glued to it, or a bare `WH853x` that lost
      both brackets (耶利米書 34:8); ASCII appears nowhere else in the
      asset except inside the CUV's own 〔創10:3作"利法"〕 cross-reference
      notes, 59 tokens, none carrying `WH`. `tools/repair_tagged_markup.py`
      strips exactly that and checks **every repaired verse against
      `assets/cuvs-yhwh.json`** — the text the reader is actually
      looking at — refusing any repair that does not move the verse
      closer to it. The `#` becomes `[基督]` only where the reading
      verse has `[基督]`; no character is invented anywhere.

      Proof no scripture moved: 183 verses repaired, 205 runs touched,
      and of those **188 lost ASCII only — the Chinese is byte-identical
      — and 17 gained 基督**, nothing else. Every run's Strong's number,
      grammar codes and implied numbers are untouched. All 66 files
      round-trip byte-identically through the writer, so the diff
      contains nothing but the repair.

      **Two verses are left for a human and must not be guessed at.**
      歷代志上 21:17 stores `行了恶<WH的8687>` and 耶利米書 4:22 stores
      `愚昧无知<WH873我7>的儿女` — each marker ate a Chinese character,
      and the reading asset shows both belong in a different clause
      (「吩咐數點百姓**的**不是我嗎」, 「不認識**我**」). Deleting the marker
      strands the character where it does not belong; moving it is
      reconstruction. `TaggedTextService` now drops any verse whose runs
      still carry a marker, so neither reaches a reader — the tap
      gesture is worth less than the text, and the sheet already falls
      back to the reader's own verse.
      `test/tagged_text_markup_test.dart` pins all of it against the
      real assets and fails on the pre-fix data with the right
      diagnosis.

- [x] **AUDIT EVERY ORIGINAL-LANGUAGE CLAIM THE APP MAKES.** Hebrew side
      done (`e714e31`): the importer kept only `<w>` and lost every marker
      that says "these are not two words" — 784 multi-word lexemes now
      render as one chip, 1,229 ketiv/qere as one word marked 寫作/讀作,
      and the 2,018 genuine repetitions are left alone. Greek done too
      (3 splits: Ἄρειον πάγον ×2, Μαράνα θά) — see the bullet below.
      Asked for directly by the user, 2026-08-11, after finding this on
      創世記 35:18: two visibly different Hebrew words, בֵּן and אוֹנִי,
      shown as two separate chips **both numbered H1126 and both glossed
      「拉结为便雅悯所取的名字」**. Their words:

      > 为什么两个字是同一个编号但是看起来不同，这让我觉得 YsWords
      > 里面 exegesis 其实是不准的

      **That reaction is the correct one and the priority rule applies:
      an interface that reads plausibly and is wrong gets believed and
      quoted.** A reader here would conclude that בֵּן on its own means
      "the name Rachel gave Benjamin". It does not — it means "son".

      The number is not wrong. H1126 is **בֶּן־אוֹנִי**, one compound
      name joined by maqqef (־), and `assets/originals/genesis.json`
      stores it as two tokens that each carry the whole compound's
      number. The lexicon card underneath already renders it correctly
      as בֶּן־אוֹנִי; only the chips are split.

      **The heuristic first written here was wrong and must not be
      restored.** It proposed merging 2,207 runs on the maqqef. The
      maqqef is not the authority: מוֹת־יוּמַת, קֹדֶשׁ־קָדָשִׁים, בֶּן־בְּנוֹ
      and אִישׁ־אִישׁ all carry one and are genuinely two words, while
      בֵּית לָחֶם is one lexeme with no maqqef at all. Merging on it would
      have corrupted roughly 2,000 verses in the name of fixing one.

      What the source actually marks, and what the importer now reads:

      | count | marker in the WLC | example | action taken |
      |---|---|---|---|
      | 784 | `lemma="1035+"` — OSHB's own "non-final member of a multi-word lexeme" | בֶּן־אוֹנִי H1126, בֵּית לָחֶם H1035, מְהֵר שָׁלָל חָשׁ בַּז H4122 | joined into ONE word, maqqef or space as the WLC prints it |
      | 1,229 | `<w type="x-ketiv">` + `<note><rdg type="x-qere">` | `לודיים` / `לוּדִים` H3866 | one word; the other form shown as 寫作/讀作 |
      | 2,018 | nothing — plain repetition | אָכֹל תֹּאכֵל, a name twice in a genealogy | **left alone** |

      Proof no scripture moved: every one of the 298,776 tokens was
      compared as a multiset before and after — 0 words lost, 25
      recovered. The 2,016-token drop is exactly 800 compound joins plus
      1,222 ketiv collapses minus 6 ketivs already being dropped, and all
      180 vanished Strong's numbers only ever appeared on a ketiv.
      `tools/audit_originals_compounds.py` re-derives the classification
      from the source and reports 0 drift;
      `test/originals_word_grouping_test.dart` pins it against the real
      assets (it fails on the pre-fix data in 1,023 places).

      Then keep going: this was found by a user glancing at one verse,
      which means nothing systematic has ever checked this surface.
      Still unaudited —
        • **Strong's number vs lemma.** Does each token's number match
          the word actually printed? Spot-check against `assets/strongs/`
          and report a rate before trusting any of it.
        • **295 runs carry `H0`/`G0`**, which is not a Strong's number;
          a tap on those can answer nothing (already queued in P1 —
          fold it in here).
        • **The tagger/originals convention mismatch.** The Originals
          audit's headline 24,983 "mistagged" runs is mostly the tagger's
          inflected-form numbers (G2258 ἦν) against the originals' lemma
          numbers (G1510). Deliberately not "fixed" — but it has never
          been re-counted since `assets/originals_versification.json`
          landed, and the merge above changed 868 concordance counts and
          removed 51 numbers that only ever appeared on a ketiv, so the
          real figure is now doubly unknown.
        • **Six words are written and, by Masoretic direction, not read
          at all** (ketiv-welo-qere: an empty `<rdg type="x-qere"/>`) —
          路得記 3:12, 列王紀下 5:18, 耶利米書 38:16, 39:12, 51:3,
          以西結書 48:16. They still ship as ordinary words carrying a
          Strong's number, i.e. the app offers a definition for a word
          the tradition says is not part of the read text. Decide whether
          to mark them 「不讀」 or drop them; do not guess.
        • ~~The Greek side has never been classified.~~ **Done — it had
          the same defect in 3 places, now fixed.** The estimate of ~260
          runs was low: there are **364**, and the marker is OpenGNT's
          own `lexeme` field naming several words, the exact counterpart
          of OSHB's `lemma="…+"`. A bare space in that field is NOT the
          marker — it also holds principal-parts lists (`ὅς, ἥ`, 1,409
          tokens) and homograph disambiguators (`ἰός (2)`); requiring
          every part to be Greek letters leaves **3 tokens**, and all
          three were split across two chips:

          | reference | printed | number | each chip claimed |
          |---|---|---|---|
          | 使徒行傳 17:19 | Ἄρειον πάγον | G697 | 「雅典一处多石的高地」 |
          | 使徒行傳 17:22 | Ἀρείου Πάγου | G697 | same |
          | 哥林多前書 16:22 | Μαράνα θά | G3134 | 「来吧, 主啊!」 |

          So tapping πάγον alone was told it means "the Areopagus" (it
          means "hill"), and tapping the syllable θά was told it means
          「来吧,主啊!」. The concordance was wrong the same way — G697
          「Used 4 times」 for a place named twice, G3134 twice for once.

          Proof no scripture moved: **every one of the 138,013 NT tokens
          was re-parsed and every verse renders the identical word
          sequence**; only 3 join points changed, space-for-space as the
          text prints them. All 27 books reproduced byte-for-byte from
          upstream before the change, so the diff contains nothing but
          the repair. The other **361** adjacent same-Strong pairs are
          genuine repetition — ἀμὴν ἀμήν, Κύριε Κύριε, Μάρθα Μάρθα, a
          genealogy naming a man twice — and are **left alone**;
          merging them would be the opposite error.
          `tools/audit_originals_compounds.py --greek` re-derives it and
          reports 0 drift; the Greek group in
          `test/originals_word_grouping_test.dart` checks the invariant
          against the LEXICON (a second source) and fails on the pre-fix
          assets at exactly those three references.

          Also settled while measuring: **`assets/originals/` has 0
          tokens numbered `G0`/`H0`.** The 295 in the P1 item below are
          the TAGGER's alone, so that item is about `assets/tagged/`
          only and does not touch the originals.
        • ~~**The Chinese glosses.**~~ **Done — the merge is sound, and
          the audit found a different defect. See the item below.**

      Report counts before changing data, as everywhere else in this
      queue. A wrong number here is the same class of error as a wrong
      verse — it is quoted in Bible study.

- [x] **Do the Chinese glosses belong to the numbers they are filed
      under? Yes — measured, 91.5% of CBOL's own citations verify. And
      the audit found 18 words answered in English instead.**
      The last unaudited surface of the item above. The glosses come
      from CBOL/bible.fhl.net and nothing had ever checked the merge; a
      gloss under the wrong number is the same class of error as a wrong
      verse, because the Originals sheet prints it as the meaning of the
      word the reader tapped.

      **The check does not read the Chinese, it falsifies it.** 8,536
      entries end their `defZh` with CBOL's own verse citations — H3 אֵב
      carries 「(#伯 8:12; 歌 6:11|)」 — which is a claim about the text:
      the word numbered H3 must stand in Job 8:12. Every one of the
      14,203 citations was resolved against `assets/originals/`, an
      independently sourced dataset (OSHB / OpenGNT) the glosses were
      never derived from, through
      `assets/originals_versification.json` because CBOL numbers verses
      the way the reading text does. **12,994 land on their own number
      (91.5%), and 8,197 of the 8,536 entries (96.0%) verify.**
      `tools/audit_strongs_gloss_refs.py`, one second to run.

      **A misfiled merge would have scored near zero, and the residue is
      not misfiling.** Of the 339 entries where no citation resolves, 21
      are Strong's compound lemmas that OSHB numbers part by part
      (H382 אִישׁ־טוֹב), 15 cite a verse our critical text does not have,
      and the rest are Textus-Receptus-vs-critical variants and
      suppletive lemmatisation — G5414 φόρτος at 使徒行傳 27:10, where
      the TR reads φόρτου and the critical text φορτίου G5413, and
      G183 ἀκατάσχετος at 雅各書 3:8, where ours reads ἀκατάστατον G182.
      Read as evidence: 18 of them resolve one number down and 18 one
      number up, 16 at −2 and 7 at +2. **A systematic offset points one
      way and moves thousands; noise points both ways and moves tens.**
      Ten entries also carry CBOL's own id in their header line
      (`2243 Helias {hay-lee'-as}`) and all ten match their key.

      **What was wrong was ours: 18 words showed English on the Chinese
      exegesis card.** 11 entries have no `glossZh` at all while the
      Chinese sits in `defZh`, and `localizedGloss` fell straight
      through to the English — G2596 κατά (473 occurrences in
      `assets/originals/`), G302 ἄν (166), H7665 שָׁבַר (148), and
      G2243 Ἡλίας, which answered `Helias (i` — the English gloss itself
      truncated by the importer at the first full stop — while our own
      asset held 以利亚 = 「我的神是雅伟」. Writing the invariant as a test
      then found 8 more that reading the data had not: entries glossed
      with the Hebrew stem and nothing else (H874 בָּאַר 「(Piel)」,
      H952 בּוּר 「(Qal)」), where the sense is the next line down. The
      stem is kept — in exegesis the binyan is information — it just
      stops being the whole answer.

      Nothing untrue was ever on screen, which is why no accuracy audit
      caught it: the app was not showing the Chinese it had. Two
      narrower repairs came with it — a line opening with a bare Strong's
      number is etymology, not a meaning (H4092 would have glossed
      itself 「04084 的变异型」), and CBOL's sub-sense numbering
      (`1a)`, `1c1)`) becomes a separator instead of being printed as
      though it were the word.

      Proof nothing else moved: all **14,197** entries were rendered in
      `zh-Hans`, `zh-Hant` and `en` before and after, and **exactly 18
      changed, in Chinese only** — no English gloss anywhere differs.
      `test/strongs_chinese_gloss_test.dart` states the invariant over
      the real assets rather than listing the 18, so a re-import that
      drops a Chinese gloss fails the suite; it fails on the pre-fix code
      with `Actual: 'Helias (i'`.

- [x] **The Originals sheet showed the wrong Hebrew in 1,626 verses.**
      `assets/originals/` and `assets/strongs/concordance.json` are
      numbered the way the Hebrew and Greek editions number themselves;
      the app looked both up by the reading text's numbering. So 詩篇 3:1
      fetched Hebrew 3:1 — the superscription מִזְמוֹר לְדָוִד, which the
      Hebrew counts as a verse and the CUV prints inside verse 1 without
      a number — while the reader was looking at 「雅伟啊，我的敌人何其
      加增」. It named a Hebrew word the verse on screen does not contain,
      and 1,377 concordance references pointed at verses this app has no
      page for at all (「Joel 4:9」, 「Malachi 3:21」, 「Psalms 22:32」).

      Measured, not assumed: `tools/audit_originals_alignment.py` scores
      Strong's-number overlap at offsets −3..+3 and found **91 chapters
      out of 1,189** sitting at a non-zero offset.
      `tools/build_versification_map.py` then aligns each book's two
      verse sequences (banded Needleman-Wunsch on the same overlap) and
      writes `assets/originals_versification.json` — **1,974 verses in
      31 books**. It independently reproduces the differences any
      reference Bible lists (Genesis 31:55 = Hebrew 32:1, Joel 2:28 =
      Hebrew 3:1, Malachi 4:1 = Hebrew 3:19), which is the reason to
      trust the ones nobody has memorised. With the map applied the
      audit reports 0 misaligned chapters and 0 unopenable references.

      **69 reading verses map to a RANGE**, and that matters: 詩篇 51:1
      carries the two-line superscription and the poem's first line,
      which the Hebrew numbers 51:1, 51:2 and 51:3, and 1 Chronicles
      12:4 is Hebrew 12:4 (Ishmaiah the Gibeonite) plus 12:5. Returning
      one of them would silently drop scripture, so the range is
      returned whole. `test/originals_versification_test.dart` pins it.

**The publisher's own text is the authority.** biblexg.com's reader is
`https://mattwhatsup.github.io/ljk-nt-bible-webapp/`, which precaches
its text as `resources/cn-*.json`. There are **no `tr-*` files** — the
publisher ships SIMPLIFIED ONLY, so our Traditional is a conversion and
the Simplified is the side with an authority to check against.

約翰一書 4:16 has now been got wrong in BOTH directions, so read this
before writing up a third: it was first reported as "the Simplified is
missing 神就是愛…", then corrected to "the publisher's own 4:16 is
exactly what our Simplified has, so the Traditional carries text the
translation does not have". **Both were wrong.** The publisher's
Simplified does carry the clause — inside a `comment` node, which is
why a plain text search of the verse missed it — and our Simplified had
lost it. The verse is fixed and the question is out of the letter.

The lesson is not "trust the Simplified" or "trust the Traditional".
It is **open the publisher's own file and look at the node, not at the
rendered verse**. A diff of two rendered texts cannot see scripture
that is sitting in the wrong kind of node on both sides.

One correction to the paragraph above while you are here: the reader
precaches `cn-*` only, but `tw-*` files **do** exist and
`tools/import_ljk2.py` fetches them — our Traditional is sourced, not
converted. That is a third authority worth using; it is what proved
4:16b belongs in the verse.

**Standing rule — keep the publisher letter shippable.** The user is
holding `docs/梁家鏗譯本-請教出版方.md` back until it is complete and
will then pass it to the pastor, so its state has to be legible without
reading this queue. It carries a status box at the top. **Every
iteration that touches the letter updates that box** — the 最後更新
date, and the ⏳/✅ of any section whose numbers moved.

Flip the heading from 草稿，尚未可寄出 to 定稿 only when §四 and §四之二
record a *decision* for every difference — a publisher revision we
adopt, or a defect of ours already fixed — never merely "differs". Say
so in the run summary when you do; that sentence is the user's signal
to send it. The 95 → 86+46 correction is exactly the kind of thing that
must not reach the publisher stale: asking them about 羅馬書 3:10, which
turned out to be our own defect, would waste their time and ours.

It is a letter, not an append-only log. Fold new findings into the
section they belong to, and keep it readable end to end by someone who
has never seen this repo.

- [x] **Character-level proofread of the TRADITIONAL — all five volumes.**
      `tools/proofread_ljk_tr.py` compares our Traditional against the
      printed 註釋本. Whole NT: **7,152 of 7,925 verses match the printed
      edition word for word (90%)**. Of the remaining 734, 307 differ
      only in punctuation and 427 in wording. **44 verses / 45 characters
      were wrong on our side and are fixed**, each one settled by the
      printed text at that verse rather than by a variant table: 托→託
      (29), 啓→啟 (6), 游→遊 (3), 毁→毀 and 内→內 (馬可福音 14:58),
      胄→冑, 审→審, 欲→慾, 话→話, 纪→紀. Three of those were Simplified
      characters that the 繁→簡 conversion let through.
      `test/biblexg_verse_integrity_test.dart` now fails if one returns.

- [x] **羅馬書 16:24 printed an editor's manuscript note as Paul's words.**
      Both editions ended the verse 「…兄弟也問候你們。按 NA28 及 UBS5，
      在此羅馬書完，但有抄本加插下面讚詞：」. Nothing looks broken on
      screen — which is the danger. A reader has no way to tell where
      the apostle stops and the critical apparatus starts, and this is
      the verse where that distinction is the whole point.

      Root cause, and why only this verse: the publisher ships such
      notes as their own `type: "comment"` node, and our importer
      already routes those to `blockNotes` (rendered in a separate card
      below the verse). Counted before fixing rather than after —
      **exactly 3 `noHidden` comment nodes exist in the publisher's
      whole corpus**, and the other two, 馬可福音 16:8 and 約翰福音 7:52,
      were already stored correctly. A corpus-wide scan for apparatus
      language inside a verse body returns **1 verse per edition**. So
      this was the only casualty, the same shape as 羅馬書 3:10.

      Settled by three independent authorities, none of them a guess:
      the publisher's own JSON node type, the printed 註釋本 (which
      prints it as 「24-27節註：」), and re-running our own importer,
      which produces the corrected record byte for byte. **The note was
      moved, not rewritten — no scripture character changed.**
      `test/biblexg_verse_integrity_test.dart` scans every verse body in
      both editions and fails on the pre-fix data with the right
      diagnosis.

      **Worth knowing for the next iteration:** upstream has been
      revised since our import — a fresh fetch differs in 136 verse
      texts and rewrites whole notes (哥林多前書 15:11, 提多書 2:14-15).
      So `python3 tools/import_ljk2.py` must NOT be re-run wholesale: it
      would both revert every hand-fix and silently adopt the publisher
      revision that §四/§四之二 are still asking about.

- [x] **Two half-verses were being read as the editor's notes, not as
      scripture — 約翰福音 12:36b and 約翰一書 4:16b.** The verse simply
      stopped early and the missing sentence appeared in the note card
      below it, in the editor's voice. 12:36b 「耶穌說完了這些話，便離開
      他們，隱藏起來了。」 was gone from both editions; 4:16b 「神就是愛，
      那住在愛裡的…」 from the Simplified only.

      Cause, and it is the mirror image of 羅馬書 16:24: a `comment`
      node's `contents` array mixes plain footnote strings with
      `{lineBreak, content}` dicts, and **the dicts are the preceding
      verse's own body**. `clean_block_comment` read both as footnote —
      its docstring even guessed the dicts were "the comment quoting
      another verse". Counted before fixing, not after: **exactly two
      such nodes exist in the publisher's whole corpus**, and these were
      both of them. `tools/import_ljk2.py` now splits them.

      Three independent authorities, no guesswork: the printed 註釋本
      sets both sentences as body before the next verse number, the `tw`
      source already carries 4:16b in the verse itself, and every
      translation numbers them as 12:36b / 4:16b. **The sentences were
      moved out of the note and back into the verse — not one character
      was written or converted**, and the repair asserted each string
      against the printed volume, the publisher's JSON and the other
      edition before writing.

      **This corrected the letter's own headline question.** §一.2 asked
      the publisher which edition was definitive because "the official
      Simplified does not have 神就是愛… at all". It does — misfiled in
      that comment node. Asking would have wasted their time on our
      defect, exactly like 羅馬書 3:10. Now in §三 as ours, already fixed.

      Found by walking the printed volumes in reading order and looking
      at what sits BETWEEN two verses our proofread had confirmed —
      `tools/proofread_ljk_tr.py` checks by containment, so a verse that
      lost a clause still "matches" and is structurally invisible to it.

- [x] **The 36 "gloss as scripture" verses are the publisher's own
      difference, not ours — measured, and nothing was changed.**
      This was queued as a P0 defect on the strength of a diff between
      our two editions: our Traditional prints 「即葡萄酒，」 inside
      馬太福音 26:29 while our Simplified marks the same words as a note,
      which is exactly the shape of 羅馬書 16:24, where an editor's
      manuscript note really had been flattened into the verse.

      **A diff of our own two editions cannot answer this question.** It
      cannot tell "our importer lost the markup" from "the publisher's
      two editions differ", and those need opposite responses — the first
      is ours to fix, the second is ours to ask about and otherwise leave
      alone. The printed 註釋本 cannot arbitrate it either: `pdftotext`
      renders a footnote inline, indistinguishable from body text, so the
      extracted volumes agree with whatever you already believed.
      **(2026-08-12: that last sentence was wrong and is corrected by the
      typography item below — the limitation was `pdftotext`, not the
      book. Four of these 36 are now settled and repaired.)**

      What settled it: **the publisher ships an official TRADITIONAL
      electronic edition, `tw-*.json`, all 27 books** — the letter said
      「只有簡體，沒有繁體檔案」, which was wrong, because their web
      reader only precaches `cn-*`. With it, `tools/audit_biblexg_notes.py`
      counts every `<cite>` in the publisher's own files against every
      `<note:…>` in ours, both editions, all 15,839 verses:

      | | our Traditional | our Simplified |
      |---|---|---|
      | notes we dropped | **0** | **0** |
      | notes we invented | **0** | **0** |

      The ten raw mismatches are each accounted for in the tool and were
      read individually, never waved through: 4 empty `<cite></cite>`
      the importer discards on purpose, 3 upstream revisions since our
      import (哥林多前書 15:11, and 馬太福音 7:11 / 路加福音 11:9 where
      the publisher moved a cross-reference), and 3 publisher nodes that
      pack several verses under one `verseIndex` — our importer splits
      them, so the note lands on the right verse and the tool looks for
      it on the wrong one.

      So all 36 are the publisher's own two editions disagreeing. Asked
      as **§四之三** of `docs/梁家鏗譯本-請教出版方.md` (✅, the count is
      settled); reconciling them ourselves would be editing scripture on
      a guess. Pinned as a SET, not a count, by
      `test/biblexg_verse_integrity_test.dart` so a future importer
      change that flattens a note appears as a new reference.

      **Two corrections to the letter fell out of this**, both of the
      kind that waste the publisher's time: it listed the materials as
      Simplified-only, and it blamed 彼得前書 3:10-12 / 以弗所書 3:15-16
      on "our own Traditional conversion" when it is their own `tw` file
      that packs those verses into one node.

      Left for a later iteration: this compared note COUNTS, not note
      TEXT. 以弗所書 3:15 is already known to differ — publisher's
      Traditional reads 「參4.6、16」, ours 「參4.6，」, i.e. ours followed
      their Simplified. Counting the text differences is the same
      revision question as the 427 and should be folded into §四之二.

- [x] **Counted the note TEXT differences — 12, and not one is ours.**
      The previous item counted that a note is *there*; this counts what
      it *says*, which is what a reader follows. `audit_biblexg_notes.py`
      gained a second pass: **1,134/1,135 Traditional and 1,133/1,134
      Simplified note strings, 6 chapters per edition differing.**

      **Compare per CHAPTER, not per verse** — that is the one design
      decision here and it is load-bearing. The publisher packs several
      verses into one `verseIndex` in four places and our importer splits
      them, so a verse-keyed comparison skips exactly those verses,
      including 以弗所書 3:15 — the only difference that was already
      known when this was written. Both sides are normalised by
      stripping HTML and whitespace; leaving the markup in reports 33
      differences that are all `<mark class="hebrew">`.

      All 12 settled against a third source, never a diff of our own two
      editions: 4 are upstream revisions since our import (哥林多前書
      15:11's 「福音」 gloss, the 馬太福音 7:11 / 路加福音 11:13
      cross-reference move), 3 per edition are our punctuation against
      upstream's unpunctuated hymn (提摩太前書 3:16, 雅各書 2:8,
      啟示錄 7:17) — the same class as the 307/46 already counted — and
      two were settled by the printed 註釋本:

      • **啟示錄 20:4 — the publisher's own `tw-rev.json` reads 「參啟1.2注」
        with the Simplified 注**, against 註 everywhere else in that same
        file and in the print. Ours reads 註. Measured before concluding:
        our Traditional writes the annotation marker 註 in 109 notes out
        of 109 and our Simplified 注 in 108 of 108, so ours is consistent
        and theirs is the slip. **Do not "fix" ours towards it.**
      • **以弗所書 3:15 — the print reads 「參 4.6，」, which is what we
        ship; their current `tw` adds 「、16」.** An upstream revision
        post-dating the printed volume.

      **This kills the queue's own speculation that our Traditional notes
      are Simplified-sourced.** 3:16 right beside it ships their
      Traditional's 「參2.18註」 against their Simplified's 注. Ours is
      sourced from the Traditional; 3:15 agrees with their Simplified
      only because the print does.

      Both print-settled findings are pinned in
      `test/biblexg_verse_integrity_test.dart`, verified to fail on
      perturbed data. The 注/註 one could not go in the existing
      Simplified-character test — 注 has a real Traditional reading and
      appears 35 times in the Traditional verse bodies — which is why it
      had never been caught. Written up as the 補 subsection of §四之三
      in `docs/梁家鏗譯本-請教出版方.md` (✅).

      **Worth knowing:** at 啟示錄 20:4 our verse body matches the
      printed 2025 二版 word for word (「坐在其上的，神為他們伸張正義。」)
      while the publisher's electronic `tw` differs (「坐在那些寶座上的
      … 他們就是」). So there are **three** states of this text, not two,
      and the 427 item below is wrong to assume the print is uniformly
      newer than our import — the electronic edition has moved on from
      the print as well. Re-read that assumption before acting on it.

- [x] **71 verses showed only half their Hebrew or Greek, because the
      CUV prints two numbered verses as one.** 民数记 1:21 is not a verse
      in this translation — its text reads 「见上节」, and the census total
      it should carry, 「共有四万六千五百名」, is printed at the end of 1:20.
      So the Originals sheet on 1:20 showed the Hebrew of 1:20 alone,
      without שִׁשָּׁה וְאַרְבָּעִים אֶלֶף וַחֲמֵשׁ מֵאוֹת. Nothing untrue was on
      screen; the reader was simply shown half the verse they were
      looking at, which is the same shape as the LEB superscriptions.

      Found by finishing the P1 tagging audit below rather than by
      looking for it: the numbers H705 / H2568 / H3967 kept appearing as
      "tagged in a verse whose original does not contain them", and they
      are in the original — the next one.

      **Counted before changing anything, and the marker is the
      translation's own, never our judgement:** 70 verses read exactly
      「见上节」, 詩篇 63:6 says the same thing longer
      (「合和译本并入上一节」), and 約翰福音 7:53 is folded FORWARDS into
      8:1 (「见下节」) — 72 in all, in 27 books, identical in the
      Simplified and the Traditional. 詩篇 8:6 absorbs two of them.
      A verse whose whole text is some other note — 「<note: 有古卷在此
      有…>」 — is not a merge and was left alone.

      **This could not go in `assets/originals_versification.json`.**
      That map is applied to every version, and the KJV, NASB and LEB
      all print 民数记 1:21 as a verse of their own with text in it, so
      widening it would have fixed the CUV by showing KJV readers a
      Hebrew clause their verse 20 does not contain — precisely the
      defect that map exists to remove. Hence
      `assets/originals_versification_merged.json`, keyed by version,
      and `originalRefs(..., version:)`. Written by
      `tools/build_merged_verse_map.py` from the reading text itself.

      Checked, not assumed: every target exists in the originals asset,
      and the absorbing verse's own tagging accounts for a mean 79% of
      the absorbed verse's Strong's numbers. The one low score is
      約伯記 10:20 (12%) and it is explained — `assets/tagged/` divides
      10:20/10:21 where `assets/cuvs-yhwh.json` merges them, and the
      reading verse does contain the clause (verified by containment).
      `test/merged_verse_originals_test.dart` re-derives the 72 from
      `assets/cuvs-yhwh.json` in Dart rather than trusting the tool, and
      fails on the pre-fix data at all 72.

- [x] **554 concordance references opened a 「见上节」 verse — fixed.**
      The other direction of the same defect. `VersificationService
      .readingRef` sent a concordance hit on Hebrew 民数记 1:21 to
      reading 1:21, whose entire text is 「见上节」 — so the concordance
      said the word occurs there and the verse shown contained nothing.
      The word is in 1:20.

      Counted before changing anything: **554**, not the 551 estimated
      here — the estimate missed the two note-only markers (詩篇 63:6's
      「合和译本并入上一节」 and 約翰福音 7:53's 「见下节」). Worst hit are
      民数记 (120), 申命記 (78) and 詩篇 (35), across 70 distinct verses.
      Only `cuvs-yhwh` and `cuvs-yhwh-tr` carry such markers; the KJV,
      NASB, LEB and both 梁家鏗 editions have none, so the fix must not
      touch them — `readingRef` now takes a `version` and consults the
      per-version merged overlay before the shared map, the mirror of
      what `originalRefs` already did.

      Threaded through `ConcordanceService.lookup(number, version:)` to
      the Originals sheet, the Strong's entry page and boolean Strong's
      search. The Strong's entry page reloads on a version switch
      (`didChangeDependencies`) — without that its list would keep the
      numbering of whatever version was current when the page opened.

      `_buildInverse` also sorted its keys as strings, so '10:1' beat
      '9:1' for "the earlier reading verse wins"; it now compares
      numerically. No reference actually changed as a result — measured,
      0 of them — so this is a latent trap closed, not a defect fixed.

      The new sweep in `test/merged_verse_originals_test.dart` walks
      every concordance reference through the real service and fails on
      the pre-fix behaviour at all 554.

- [x] **`assets/tagged/` and `assets/cuvs-yhwh.json` disagree about
      約伯記 10:20/10:21 — measured across the whole corpus.** The risk
      this item named, that the two assets have different verse keys,
      **does not exist**: 31,102 keys on each side, 0 in one and not the
      other, all 66 books. The disagreement is in the TEXT, and counting
      it is what turned up the 185 markup verses fixed above.

      After that repair, **13 verses remain where the tagged text loses
      words the reader's verse has** — and because the Originals sheet
      prints the tagged runs instead of the verse, those words are
      missing from the sheet:

      | reference | missing from the sheet |
      |---|---|
      | 約伯記 10:20 | 「叫我在往而不返之先…可以稍得畅快」 — a whole clause |
      | 列王紀上 21:8 | *(was 12 characters; repaired above)* |
      | 士師記 15:7 | 非利士人 (tagged reads 他们) |
      | 士師記 15:13 | 以坦 |
      | 尼希米記 1:2 | 关于 ×2 |
      | 以西結書 10:1 | 之中 |
      | 阿摩司書 6:8 | 万军之神 (word order differs) |
      | 箴言 4:6 | 她 (tagged reads 它) |
      | 撒母耳記下 21:8 | 姊姊 (tagged reads 姐姐) |
      | 士師記 20:6 | 扔菏 (tagged reads 凶淫) |
      | 尼希米記 2:19, 3:3, 歷代志上 15:3 | 你们 / 他们 / 众人 |

      **These are not damage — they are two different imports of the
      same translation**, and the wording differences read as edition
      variants (姊姊/姐姐, 她/它, 回覆/回复). Do not "fix" them by
      copying one into the other; that is choosing a reading. 約伯記
      10:20/10:21 is the one structural case: the reading asset folds
      both into 10:20 and marks 10:21 「见上节」 while the tagged asset
      divides them, so the sheet shows the first half only. Two honest
      options, and the second needs no data change:
      (a) join the tagged 10:21 runs into 10:20 — the concatenation
      reproduces reading 10:20 exactly, so it is evidence-based, or
      (b) have the sheet fall back to the reader's own verse text
      whenever the tagged runs would lose words, which covers all 13
      at the cost of the tap gesture on them.
      Queued below as its own item rather than decided here.

- [x] **Took option (b): the Originals sheet now falls back to the
      reader's own verse whenever the tagged runs would lose text.**
      No data change — the two imports are both honest and choosing
      between their wordings would be choosing a reading. What changed
      is which of the two the sheet is allowed to print AS the verse:
      `TaggedTextService.coversVerse` requires the tagged runs to carry
      every ideograph of the reader's verse, in order, and the sheet
      renders the plain line when they do not.

      **Re-measured before deciding, and the earlier count of 13 was
      low.** Comparing ideographs only — punctuation and the 〔…〕 the
      tagged import prints around a note are not scripture — **238 of
      31,102 verses lose at least one character**, of which 236 reach
      the sheet (two are already dropped for importer markup). 183 lose
      a single character to an orthographic or pronoun variant
      (吗/么, 她/它); the rest lose real text, worst of all 約伯記 10:20
      at 28 characters. The check is one-directional on purpose: 1,165
      verses where the tagged import prints MORE than the reader's
      verse keep the gesture, because nothing is missing there.

      Cost: the word-tap gesture on 0.76% of verses. The text outranks
      the gesture. `test/tagged_verse_coverage_test.dart` pins the 236
      so a re-import that starts dropping clauses turns the suite red,
      and asserts 約伯記 10:20 is in the set.

- [ ] **Decide the 427 wording differences with the publisher.**
      Not ours to change. They cluster in 路加福音 (178) and 馬可福音 (89)
      and read as one consistent later revision — the 2025 印刷版 replaces
      pronouns with names (馬可福音 9:20「帶到耶穌面前」where we have
      「帶到他面前」), tightens phrasing (使人不潔 / 使人成為不潔) and
      prints 身分 where we print 身份. Same question as the 95 Simplified
      verses, and it should get the same answer. Written up as §四之二 of
      `docs/梁家鏗譯本-請教出版方.md`. **Until the publisher answers,
      change nothing** — adopting a revision by guess is rewriting
      scripture.

- [x] **The printed 註釋本 DOES distinguish the editor's voice from
      scripture — it is in the type size. 4 verses repaired, 27 asked.**
      Two places in this repo said the print could not arbitrate
      footnote-vs-body: the item above, and a comment in
      `test/biblexg_verse_integrity_test.dart`. Both were describing a
      limitation of `pdftotext`, which flattens a page to characters.
      `pdftohtml -xml` keeps every run's font size, and the 2025 二版 sets
      four of them: **18pt chapter headings, 17pt scripture (16pt on pages
      the typesetter tightened), 12pt the editor's voice — inline supplied
      words AND the footnote blocks — 8pt verse numbers.**

      It is per-OCCURRENCE, not per-word, which is how you know it is
      deliberate: 加拉太書 3:7 and 3:9 set 稱義 at 12pt while 3:8 and 3:11
      set the same two characters at 17pt. The publisher's electronic
      editions lost that distinction and we inherited the loss.

      `tools/audit_printed_typography.py` parses all five volumes per
      VERSE (the 8pt numbers make that possible, which is what
      `proofread_ljk_tr.py` gave up on) and measured the whole corpus:
      **7,810 printed verses, 7,049 of ours character-identical to the
      printed BODY, and 31 spans in ~28 verses that we print as scripture
      and the book sets at 12pt.**

      **Only 4 were repaired**, and `--apply` refuses unless three
      independent authorities agree: the print sets it at 12pt, the
      printed body does not contain it, and the publisher's own Simplified
      already marks it as a note. 路加福音 9:5「作為警告。」,
      約翰福音 12:25「保留」, 加拉太書 3:7 and 3:9「稱義」 — each moved
      into a `<note:…>`; not one character was written, converted or
      reordered, and the diff is 4 lines. That takes
      `knownNoteDifferences` in the integrity test from 36 to 32; it fails
      on the old data.

      **The other 27 were left alone.** They are translator-supplied
      words in the manner of the KJV's italics (馬太福音 9:18 會堂的,
      使徒行傳 20:28 兒子, 加拉太書 3:23 的準則, 哥林多前書 15:50 的身體)
      and **both** electronic editions print them as text — only the book
      differs, so it is a question for the publisher, now §四之三之二 of
      `docs/梁家鏗譯本-請教出版方.md`, not a defect of ours to repair on
      one witness.

      Two traps worth keeping. **16pt is body**: reading `>= 17` as
      scripture reports six whole verses of 使徒行傳 7:56-8:1 as glosses,
      because that page was dropped a point to fit. And **footnote blocks
      are not always at the foot** — page 26 of volume 2 has one between
      verses 12 and 13 — so an inline gloss is identified by sharing a
      LINE with body text, not by its position on the page.

      One rule had to be tightened before it was trusted. A gloss the two
      editions word DIFFERENTLY cannot be found by matching the span —
      路加福音 9:5 trails 「作為警告。」 where the print and the Simplified
      both say 「意即警告。」 — so the tool also admits the shape "our
      visible text is the printed body plus a tail". A looser first draft
      (any extra span in a verse that happens to carry a footnote) found
      ten, and **nine were ordinary wording differences sitting beside an
      unrelated footnote** (馬可福音 15:21 揹耶穌/背他, 腓立比書 2:1 甚麼/
      任何, 羅馬書 12:6 照著信心的程度去做/應與信心成比例). Those belong
      to the 427; marking them as notes would have hidden translated words
      as an editor's. Nine wrong out of ten is what a loose rule costs.

      Also found: 使徒行傳 4:1 is followed in the print by a 17pt body
      sentence 「撒都該人否認復活。」 that neither electronic edition has.
      Reported to the publisher; **not inserted** — writing a verse on one
      witness is the thing this queue must never do.

- [ ] **Proofread the TRADITIONAL against the printed 註釋本, book by book.**
      Wording only; the characters are now done (see above), and the
      正文/註釋 distinction is now settled by type size (see the
      typography item above — run `tools/audit_printed_typography.py`
      before assuming the print agrees with our text). The user supplied
      the publisher's own Traditional PDFs — 《新約聖經 梁家鏗譯本
      （註釋本）》2025 第二版, 5 volumes — and they have a clean text
      layer. Extracted copies live in `/tmp/ljk_tr/*.txt`; re-extract
      with `pdftotext -enc UTF-8` from the user's Downloads if missing.
      This is the first authority we have had for the Traditional side.

      Work one volume at a time and **conform to the printed text, not
      to good Chinese.** A first pass "corrected" 會堂里→會堂裡,
      谷糧→穀糧 and 踹谷→踹穀 — every one of those reasonable, and every
      one WRONG, because the 註釋本 prints 里, 谷 and 谷 in exactly those
      places. Where the printed edition looks odd, it goes in
      `docs/梁家鏗譯本-請教出版方.md` for the publisher; it does not get
      edited here.

      Known to settle this way: our 一台戲 was wrong (printed: 一臺戲) and
      is fixed; the ~117 swallowed verse numbers, the 7 missing verses
      and 約翰一書 4:16 all need checking against the volumes.

      **Structure and characters are now done**; what
      remains is the WORDING, volume by volume. Our Traditional reads
      like a conversion of an older Simplified revision than the one the
      2025 印刷版 carries — 路加福音 23:32 prints 「和他一同處決」 where we
      have 「和耶穌一同處決」, and 23:33 prints 「將他釘上了十字架」 where we
      have 「將耶穌釘上了十字架」. Same sense, different wording, so it is
      the 95-verse revision question again rather than damage. Take one
      volume per iteration and count before changing anything.

- [x] **Count the swallowed verse numbers properly — it was 5, not 117.**
      The old figure counted digits inside `<note:>` citations
      (馬太福音 15:12's note is 「參11.6，13.57」). Stripping markup first
      leaves 5 verses hiding 7. Root cause found: the publisher marks
      textually doubtful passages `<span class="affix"><sup>43</sup>…`
      and our importer flattened the superscript into body text — three
      such spans in the whole NT, all in Luke. 路加福音 22:43, 22:44,
      23:17 (both editions) and 彼得前書 3:11, 3:12, 以弗所書 3:16
      (Traditional) are now addressable verses, per the printed 註釋本.
      `test/biblexg_verse_integrity_test.dart` fails on the old data.

- [ ] **路加福音 23:34a needs a sub-verse label — the user's call.**
      The last of the five. The printed 註釋本 prints 34a / 34b; the
      publisher's Simplified keeps the second half as plain 34. Our
      verse id is `<book>-<chapter>-<verseLabel>` and highlights key off
      it ACROSS versions, so labelling ours 34a / 34b would desync a
      highlight on Luke 23:34 from every other translation, and Dart's
      unstable sort would not even keep 34a before 34 without a
      tiebreak. Two honest options, both needing a decision:
      (a) label them 34a / 34b and accept the one-verse highlight
      desync, or (b) add a `sortKey` and keep the id at 34.

- [ ] **馬可福音 6:8-11 is missing from the publisher's own Simplified.**
      Found by the chapter-gap audit. `cn-mk.json` has no 6:8-11 at all
      and truncates 6:7 mid-sentence at 「并授予他们权能」, dropping
      「制服不洁的灵」. The printed Traditional has all five verses in
      full and our Traditional matches it word for word, so the loss is
      upstream and Simplified-only. These are not variant readings —
      every manuscript has them. **Do not 繁→简 convert our Traditional
      to fill it**; that is writing scripture. Asked in
      `docs/梁家鏗譯本-請教出版方.md`; pinned as a known hole in the
      integrity test so it cannot quietly grow.

- [ ] **Ask the publisher about the two official editions disagreeing.**
      Drafted in `docs/梁家鏗譯本-請教出版方.md` — the user is passing it
      to the pastor. Two items, both the publisher's own text: 馬可福音
      6:7-11, and **提摩太後書 3:15, where the official Simplified drops
      the opening clause** 「而且你自幼便明白神聖的經典，」 that the
      printed 註釋本 has and every translation carries. Verified in
      `cn-2ti.json` itself, not inferred from a diff. Same shape as
      馬可福音 6:8-11, and not ours to fill by conversion.

      **約翰一書 4:16 used to be the headline here and is no longer a
      question at all** — the official Simplified does carry the clause,
      and we were the ones misreading it. See the fixed item above.

- [x] **The Simplified proofread was silently checking only 22 of 27
      books — and 羅馬書 3:10 had lost the scripture it quotes.**
      `CODE2BOOK` guessed SBL-style file codes (`mat`, `mar`, `luk`,
      `php`, `jam`); the publisher's files are `cn-mt`, `cn-mk`,
      `cn-lk`, `cn-phi`, `cn-jas`. An unmapped file was skipped with a
      bare `continue`, so the tool reported "4,826 comparable verses,
      98% identical" while never opening Matthew, Mark, Luke,
      Philippians or James — **3,112 verses, 39% of the NT**, including
      the three Gospels where most of the differences live. `official()`
      now RAISES on an unmapped file.

      With all 27 books: **7,920 comparable, 7,788 identical, 46
      differing only in punctuation, 86 in wording, 0 absent.** The
      punctuation split is new and matters — 腓立比書 2:6-11 is set as an
      unpunctuated hymn upstream and as prose by us, which is not a
      textual difference and was inflating the count.

      One was damage on our side and is **fixed**: 羅馬書 3:10 read
      「正如经上所记：」 and stopped — the quotation it introduces,
      「没有义人，一个也没有，」, never reached a reader. The publisher sets
      it as a poetry node with an EMPTY `verseIndex` and our importer
      kept only numbered nodes. Counted before concluding: exactly one
      such node exists in the publisher's whole corpus, so this verse
      was the only casualty. Settled against the publisher's own file
      AND the printed 註釋本 (「10 正如經上所記：／沒有義人，／一個也沒有，」),
      and our own Traditional already had it — restored from their
      characters, not written by hand.
      `test/biblexg_verse_integrity_test.dart` fails on the old data.

- [ ] **Decide the remaining 86 Simplified wording differences.**
      `python3 tools/proofread_biblexg.py --book <code>` — aliases mean
      `--book mat` still finds Matthew. They read as a later publisher
      revision rather than as damage (以弗所書 2:4 upstream "神富有愛憐，
      出於他愛我們的大愛" against our "神滿有憐憫，因著他愛我們的大愛"),
      which makes this the **same question as the 427 Traditional ones
      and the 路加福音 23:34a call — all three are waiting on the
      publisher.** Do not adopt any of them by guess.
      Concentrated in 馬太福音 12, 啟示錄 12, 哥林多前書 11, 馬可福音 8,
      以弗所書 8, 路加福音 6. Take one book per iteration once the
      publisher answers, and copy their wording exactly — never
      paraphrasing, never merging the two.
      **The letter's §四 is now correct** (2026-08-11): re-measured at
      7,920 comparable / 7,788 identical / 46 punctuation / 86 wording /
      0 absent, with the old 95 figure explained rather than quietly
      replaced, the per-book distribution listed, and 羅馬書 3:10 moved
      to §三 as our own defect. §四 is ticked ✅ in the status box;
      **§四之二 is the only ⏳ left**, so the Traditional 427 is now the
      one thing standing between this letter and being sendable.

- [ ] **Then rebuild the Traditional from the corrected Simplified.**
      Only after the Simplified matches the publisher. Our Traditional
      is a conversion, and it currently disagrees with the Simplified in
      ~117 places where it swallowed the next verse's number, plus
      whole verses it lacks. Rebuilding from a known-good Simplified
      fixes the cause rather than the symptoms — but it needs a 简→繁
      converter this repo does not have. Report what is needed rather
      than hand-converting: hand-converting scripture is guessing.

- [x] **Make the audit a permanent test — done for 梁家鏗譯本.**
      `test/biblexg_verse_integrity_test.dart` fails on duplicate
      references, empty verses, a verse carrying the next verse's
      number, and any chapter gap that is not on an explicit list of
      accounted-for ones (the publisher's own textual omissions,
      combined labels like Luke 1:"1-4", and the 馬可福音 6:8-11 hole).
      Verified by running it against the pre-fix data, where it fails
      with the right diagnosis.

- [x] **Extend that audit to the other five versions — done.**
      (This and "Audit the remaining versions the same way" were the
      same task listed twice.) kjv / nasb / leb / cuvs-yhwh /
      cuvs-yhwh-tr: **0 duplicate references, 0 empty verses, 0 stranded
      verse numbers**, and every book name resolves through
      `bookNameToEnglish`, so cross-version highlights align.

      **16 verses carried a character that is not in scripture** and are
      fixed: ten stray `|` in the KJV — two of them splitting a word
      (`hide nothing from m|e`, `he that c|alleth`) — and a stray `{`
      (申命記 15:15) plus two stray `*` (馬太福音 9:28, 路加福音 24:34)
      in each CUV edition. Every one settled against an independent
      import of the same translation (SeekSparks' `kjvs.json` and
      `cuvs-plus.json`, both different sources from ours), never by
      writing the verse. Also fixed: all 1,764 verses of 歷代志上/下 in
      the Traditional CUV carried id prefix `000` and collided with each
      other — dormant, because the app computes its own id, but wrong.

      Left alone as publisher convention, not damage: the NASB's `[...]`
      round disputed passages and `*` for the historical present, the
      LEB's `[...]`/`{...}`, and the CUV editions' `[雅伟]`/`[基督]`.
      Verse-count differences from the KJV are versification (the
      critical text's omissions and merges), enumerated in the test.
      `test/bible_version_integrity_test.dart` pins all of it and fails
      with the right diagnosis on the pre-fix data.

- [x] **The LEB's 116 Psalm superscriptions never rendered — fixed.**
      `assets/leb.json` ships them as rows with `verse: "title"` and a
      null id — legitimately, they are part of the text but not
      numbered verses — and the decoder's "drop any non-numeric verse"
      rule threw away all 116. Nothing untrue was on screen, which is
      why no audit caught it; the app was simply showing less scripture
      than it had.

      The model decision, made rather than deferred: a superscription
      is **not** a verse, so it gets neither a number nor an id. It
      rides on verse 1 as `Verse.superscription` and renders above it
      via `SuperscriptionLine`, outside the verse's InkWell so it can
      never be selected or highlighted as though it were part of verse
      1. Numbering it would invent a verse the LEB does not have; an id
      (`Psalms-3-title`) would be a place no other translation has, so
      a highlight there could never follow the reader across versions.
      Verified against the asset: 116 unique chapters, every one with a
      verse 1, the title row always ahead of it.
      `test/leb_superscription_test.dart` runs the real asset through
      the real decoder and fails on the pre-fix code.

## P1 — Bible study correctness

- [x] **A stale cache outlived every upgrade — fixed in v1.4.39.**
      The user's screenshot showed 283 CDC songs with a language badge
      where the play button belongs, while CGDC rows beside them played.
      The data was never wrong: both the live dataset and the bundled
      snapshot carry 282/283 with audio. `RemoteDataService._firstLoad`
      returned the SharedPreferences cache whenever one existed and
      never compared it to the bundle — and **SharedPreferences survives
      an app upgrade**, so a cache written during the bad-CDC publish
      shadowed every corrected release and a reinstall would not have
      cleared it. Now only a strictly newer bundle displaces the cache,
      via the `generatedAt` hook that was already there.
      `test/stale_cache_guard_test.dart` rebuilds the exact bad edition
      and fails on the pre-fix code.

      **This is worth remembering beyond songs:** the same three-tier
      loader backs every dataset in the app, so any bad publish used to
      be permanent for whoever cached it.

- [ ] **Reconcile our Matthew sermons against the church's own 124.**
      The user, 2026-08-10: Bentley has put up Pastor Eric's 124
      messages on Matthew as a 9-volume work, at
      `https://www.christiandiscipleschurch.org/content/124-messages`.
      Compare ours to it and match the correct ones.

      **The site was unreachable when this was queued, and that is the
      only reason it is not done.** Retry the fetch first each
      iteration; everything below is already established, so do not
      re-derive it. Retried 2026-08-10 (second iteration): still
      `connect=0.000000`, no TCP connect at all. Retried again
      2026-08-10 (third iteration): still no TCP connect, and the
      Wayback CDX question is now **settled** — the API answers (it
      returns snapshots of the domain root going back to 2001) and it
      has **no snapshot of `/content/124-messages` or of any
      `/content*` page**. So the archive is not a way round this; the
      host has to come back up.

      What was checked on 2026-08-10:
      - `christiandiscipleschurch.org`, `christiandc.org` and
        `christiandc.net` are all one host, `149.248.15.146`. None of
        the three completes a TCP connect (`connect=0.000000s`), and
        Anthropic's server-side fetcher gets ECONNREFUSED from the same
        IP — so it is the server, not our network and not a block on
        this machine. General egress was verified working in the same
        minute (example.com, archive.org, netlify all 200).
      - The Wayback CDX API returned 503 on that attempt, so "no
        snapshot" was never actually established. **Re-check the
        archive** before concluding anything: `http://web.archive.org/
        cdx/search/cdx?url=christiandiscipleschurch.org/content/
        124-messages&output=json`.
      - Retried 2026-08-10 (fourth and fifth iterations) and again
        2026-08-11 (sixth), 2026-08-12 (seventh through twelfth),
        2026-08-16 (thirteenth) and 2026-08-17 (fourteenth through
        seventeenth): still
        `connect=0.000000`, curl times out with no TCP connect.
        Unchanged across seventeen consecutive iterations, while cgdc.hk and
        cahayapengharapan.org answered 200 in the same probe — so it is
        that host, not the probe. **Tell the user** — they can probably reach Bentley
        faster than the server will come back, and nothing else about
        this task can move until it does.
      - Related pages found via search, useful once the host is up:
        `/content/ehhc_sermons_public`, `/content/mtparablesvol1`,
        `/contents/matthew_parables_front_matter`.

      What our data looks like, so the comparison starts from facts:
      - `assets/sermons/index.json` holds **289** sermons.
      - **102** have a passage beginning `Mt`; 30 `Lk`, 9 `Mk`, 6 `Jn`.
      - **124 have an EMPTY passage — this is a coincidence, not the
        Matthew set.** They are topical (34 Regeneration and Renewal,
        17 Spiritual Direction, 12 The Antichrist …). Do not "match"
        them to the church's 124 on the strength of the number; that
        trap is why it is written down here.
      - The Matthew material sits under four topics: *Matthew and
        parallels in Luke and Mark* (69), *The Parables of Jesus* (34),
        *Sermon on the Mount* (18), *The Beatitudes* (10) — 131 in
        total, against the church's 124. The overlap is what needs
        establishing.

      Match on passage + title, never on ordinal position. Report the
      counts — ours only, theirs only, and title/passage disagreements
      — **before** editing `assets/sermons/`. A sermon we attribute to
      the wrong Matthew passage is the same class of error as a wrong
      verse: it reads plausibly and gets believed.

- [x] **Verify the Strong's tagging against the originals.** Done —
      the honest figure is **1,996 runs, 0.55% of tagged runs**, and
      nothing read in that tail is data to change.
      `tools/audit_strongs_tagging.py` counts the whole corpus (66
      books, 367,589 runs, 360,946 tagged) rather than spot-checking,
      because one wrong number looks exactly like a right one on screen.

      The tool's own first headline — "24,983 carrying a number that is
      not in that verse's original" — was worthless, and the rewrite now
      says so in its docstring. Two things inflated it:

        * **The two verse numberings differ.** Applying
          `assets/originals_versification.json` and the new
          `assets/originals_versification_merged.json` takes the raw
          25,137 down to **9,765**; the rest of that gap was the audit
          comparing the wrong two verses. `--no-versification`
          reproduces the old figure for anyone who wants to see it.
        * **The two datasets use different Strong's conventions.** The
          tagger numbers the inflected form (G2076 ἐστί, G2258 ἦν,
          G5213 ὑμῖν) where the originals number the lemma (G1510 εἰμί,
          G5210 ὑμεῖς). 5,587 resolve that way, and 2,182 more have the
          lexicon's own headword printed in the verse verbatim. Every
          one of them reaches the right lexicon entry, so "fixing" them
          would make the app less accurate, not more.

      The convention difference is factored out **by the lexicon's own
      `deriv` field**, never by a table typed into the tool — a
      hand-written equivalence list is just a second dataset that can be
      wrong. "a derivative of" and "from" are deliberately not counted
      as inflection: G697 Ἄρειος Πάγος derives from G4078 πήγνυμι and is
      not the same word.

      **What the remaining 1,996 (683 distinct numbers) actually are,
      read verse by verse:** `H0`/`G0` (295, its own item below);
      suppletive lemmatisation, where the two datasets legitimately file
      one verb under different headwords (λέγω/εἶπον, ὁράω/εἴδω,
      הלך/ילך, ἐλαία/ἐλαιών); **Textus-Receptus-vs-critical-text
      variants** — the CUV was translated from the TR and
      `assets/originals/` is a critical text, so 1 Cor 10:9
      (κύριος / Χριστόν) and 1 John 5:7 surface as orphans and are
      *correct*; and CUV translational additions with no Greek
      counterpart at all (2 Peter 3:3). Run `--tail 100` and read the
      verse before concluding any of them is a defect.

- [x] **295 tagged runs carried `H0` / `G0`, which is not a Strong's
      number — now untagged.** 253 Hebrew, 42 Greek; neither is a key in
      `assets/strongs/`, so the Originals sheet drew the dotted
      underline, took the tap and answered 「Lexicon entry not found for
      H0」. The guess written here — the Hebrew direct-object particle —
      **was wrong.** The words carrying it are the divine name: 152 bare
      雅伟, 28 主, and they are the words a reader is most likely to tap.

      **What the marker means was settled against `assets/originals/`,
      not from its shape. 178 of the 295 sit in a verse whose original
      has no divine name at all**: 歷代志上 2:3 「雅伟就使他死了」 renders
      וַיְמִיתֵהוּ, one verb with its subject in the inflection, and
      帖撒羅尼迦前書 1:7 「信主之人」 renders τοῖς πιστεύουσιν with no
      κύριος anywhere in the verse. The other 117 are the CUV printing
      the name twice where the Hebrew prints it once — 歷代志上 21:26
      「求告雅伟。雅伟就应允他」 for one וַיִּקְרָא אֶל־יְהוָה וַיַּעֲנֵהוּ —
      and there the single Hebrew word is already tagged on the other
      run. So `H0` means "the translation supplies this; no original
      word stands behind it", the opposite of a Strong's number.

      **Numbering them H3068 / G2962 was the tempting fix and would have
      been a false claim** — it tells a reader the Hebrew carries a word
      it does not, on the divine name, in a panel that looks like it is
      quoting the original. Untagged is what the tagger meant: the
      scripture still prints, the promise goes away. One line in
      `TaggedRun.fromJson`, no asset touched.

      Measured first, as everywhere here: those two are the **only**
      unresolvable numbers in the whole tagged corpus — 367,589 runs,
      360,946 tagged, 0 other primary numbers and 0 implied numbers
      missing from the lexicon. `test/tagged_supplied_words_test.dart`
      pins that against the real assets and fails on the pre-fix code
      with the right diagnosis (`{'H0': 253, 'G0': 42}`).

- [ ] **Commentary import (public domain).** One module first — Matthew
      Henry or JFB — via the published `.cmt.mybible` SQLite file, never
      scraped. Credit the source on the About page even though the
      copyright has expired. 20-60 MB, so lazy per-book loading.

## P2 — features the user asked for

- [ ] **Only the Bible reader has a URL. Every other page is
      unshareable, and Back does the wrong thing.**
      Reported 2026-08-17 by a reader of the CN site, forwarded by the
      user: reading sermon #019「你们是世上的光」the address bar still
      read `.../#/micah/2:1?v=cuvs-yhwh`, so forwarding that link sends
      someone to Micah 2:1. Also: "用浏览器的 forward/backward 的时候
      体验不对".

      **Not CN-specific** — both sites are the same build; `CHINA_MODE`
      changes data hosts, not routing.

      **Cause.** `lib/services/url_sync_service_web.dart` syncs the URL
      to `MainProvider`'s book / chapter / verse / version and to
      nothing else. Every other page — 72 `pushPage` call sites —
      goes through GetX `Get.to`, which pushes a Flutter route but does
      not write the address bar. `main.dart` sets only `home:`, with no
      `routes` or `onGenerateRoute`, so Flutter web has nothing to
      derive a URL from.

      That single fact explains both symptoms, and the second one is
      the worse of the two: `popstate` is wired to apply URL → Bible
      state. Pressing Back inside a sermon therefore does not pop the
      sermon — it jumps the reader to a passage. There are two
      histories, the browser's (Bible positions only) and Flutter's
      (pages), and they are not the same stack.

      **This is a design change, not a patch.** Making 72 pages
      addressable means adopting a real router — `go_router` or
      Navigator 2.0 — and moving the hand-rolled hash sync into it.
      Do NOT bolt `pushState` calls onto `pushPage`: that would put
      entries in the browser history that the app cannot pop correctly,
      which is the current bug with more URLs.

      Sequence worth following:
      1. **Decide the URL scheme first**, on paper, for every
         destination — sermon, song, evidence entry, misconception,
         playlist, Strong's number. A scheme invented per-page while
         converting will not be stable enough to share.
      2. Keep the existing Bible URLs working exactly as they are.
         They are the ones already in circulation; breaking a shared
         `/#/john/3:16` link to fix sharing would be a poor trade.
      3. Convert pages in batches with a test per batch: a cold load of
         the URL lands on the page, and Back returns to where the user
         actually was.

      **Approved to start, 2026-08-17** ("loop加进去吧"). The user has
      agreed to the timing as well as the goal, so do not ask again —
      but do it in the staged order above, and land each stage on its
      own so a bad stage can be reverted without taking the scheme with
      it.

      **Do not fan out on this one.** Every stage touches navigation,
      which every other queue item also touches; four agents converting
      different pages in parallel would each rewrite the same router.
      One agent, one stage per iteration.

      **Stop and report rather than half-convert.** If a stage cannot
      reach green, revert that stage and write what blocked it into
      this item. A build where some pages are addressable and others
      silently are not is harder to reason about than today's, where
      the rule is at least consistent.

- [ ] **Songs stop instead of advancing to the next track.**
      User, 2026-08-16: "为什么一首歌完了下首歌没有继续播放而是停住了是不是
      loading问题". Auto-advance exists (`_onTrackFinished`), so the
      question is why the NEXT track never starts. Their guess — a load
      problem — is plausible: the stall watchdog added in v1.4.64 fails
      a track that produces no audio in 20s, and `_skipPastFailure`
      then advances, but if the next track also stalls the queue can
      walk itself into silence. Reproduce with a CDC/fydt song first,
      since those hosts are the slow ones, and check whether the
      handler stops because every remaining track is marked failed.

      **Read the code 2026-08-17 without being able to reproduce** —
      cdc and fydt are both unreachable from this machine, so nothing
      below is confirmed against a running player and none of it was
      changed. Two things in `song_audio_handler.dart` are worth
      checking first, because both end in silence rather than in the
      next song:

      1. **One dead track can trigger TWO advances.** A web failure
         arrives twice — as an `onError` event (line 57, which calls
         `_skipPastFailure`) and as the rejection of `_el.play()`
         (line 484's `catch`, which also calls `_skipPastFailure`). The
         second advance runs while the first's `_playCurrent` is still
         in flight and re-assigns the element's `src`, which aborts it;
         an aborted play leaves `_el.error` null, so the engine reports
         it as `PlaybackBlockedException` — and that branch deliberately
         **stops without advancing** (line 470). So: one bad link,
         one song skipped unheard, and playback parked. That shape
         matches the report exactly, which is a reason to look, not
         evidence that it is the cause.
      2. **`_failed` is never written on the `onError` path**, so the
         `playable == 0` guard that exists to stop the queue spinning
         cannot fire for a failure reported that way, and
         `_failed.remove` at line 469 clears the flag whenever `play()`
         merely *returns* — which on web means nothing, since the
         element accepts any src and reports the failure later. A
         track is alive when it produces audio, not when play() returns;
         that is already the signal `_cancelStallWatchdog` uses.

      Do not "fix" either one blind. The engine is a compile-time
      conditional export with no seam to inject a fake, so there is no
      way to test a change to this path today — which is itself the
      first thing to fix if this item is taken.

      **Read the handler on 2026-08-16 without being able to reproduce
      it — no device, and a widget test has no audio plugin. Three
      leads, none yet proven to be the cause:**

      1. `_player.onError.listen` in `song_audio_handler.dart` calls
         `_skipPastFailure()` but never adds the song to `_failed`, and
         calls `notifyUi()` rather than `_broadcast()`. So the
         loop-guard that set exists for cannot arm from this path — and
         on NATIVE this is the only path an error takes, because
         `SongPlaybackEngine._guard` swallows the throw into `onError`,
         which makes the `_failed.add` in `_playCurrent`'s `catch` dead
         code off the web. With repeat on, a queue of dead links would
         walk itself instead of stopping.
      2. `_guard` reports a failed `stop()`, `pause()` or `seek()` on
         the same `onError` stream, so a failure of any of those starts
         the NEXT track — the user stops and the music moves on.
      3. `toggle()` builds a ONE-SONG queue, so a song started from the
         detail sheet's mix chips legitimately stops at the end with
         nothing to advance to. The list rows already use `playQueue`
         (`songs_page.dart:333`), so this is not the list case — but it
         may be what the user was doing. Worth asking where they tapped.

      The engine is a `final` field constructed in place, so none of
      this is testable without a seam. Adding one is a production change
      for a symptom nobody has reproduced yet; ask the user which
      surface they played from first.

- [x] **Two references, only one is reachable — each cited passage now
      has its own tap target.** v1.4.79.
      User, 2026-08-16: "那个经文其实是两个，但是按了好像只能去一个，另个去
      不了". The evidence card's 经文对应 chip is now one flowing
      paragraph (v1.4.59) but is still a SINGLE tap target that jumps
      to the first reference. Make each reference its own tap target —
      `TapGestureRecognizer` per TextSpan, or separate chips — so
      「以赛亚书 44:28; 以斯拉记 1:1-4」 offers both.

      Done with separate chips, as the note below recommended: the 208
      one-reference entries keep the flowing paragraph untouched and
      only two-or-more switches to a `Wrap` of chips. `splitCitation`
      (new, in `reference_parser.dart`) resolves each `;` part;
      `parseReference` itself still truncates at the first `;`, which is
      right for "where does ONE tap go" and is why the multi case needed
      its own function. A part that resolves to nothing renders as plain
      text, so there is no tap target that can only answer "couldn't
      parse". **Verified against the pre-fix code**: tapping 「10:26」
      landed on chapter 9.

      **An adversarial pass before committing broke two of the claims
      this was written on, and both mattered.**

      1. *"The digit guard means inheritance cannot misattribute."*
         False. The first draft carried the last SUCCESSFUL book forward
         indefinitely, so `Exodus 14:21-22; Ecclesiasticus (Sirach)
         44:1; 45:1` handed `45:1` to **Exodus** — a chapter Exodus does
         not have, offered as the cited verse. `Ecclesiasticus (Sirach)
         39:1` is a real reference value in the asset (`cairo_genizah`),
         so the shape is not hypothetical. Fixed: the book carries only
         from the part IMMEDIATELY before, pinned by a test.
      2. *"`peter_raises_tabitha_joppa` is the only bookless segment."*
         True only of `;`. Four entries do it with a COMMA — see the new
         item below.

      Acts 10:5-6 as the inherited reading of `10:5-6` was checked
      against the text, not assumed: it is Cornelius sending to Joppa
      for Simon Peter lodging with Simon the tanner, the same narrative
      as 9:36-43.

- [x] **Four more citations are read on screen and cannot be opened —
      the comma case. Fixed; all four now open.** v1.4.80.
      `rylands_papyrus` cites `John 18:31-33, 37-38`,
      `daniel_prophecies_accuracy` `Daniel 2, 7, 8, 11`,
      `ephesus_artemis_burning_books` `Acts 19:11-20, 23-41`,
      `khirbet_qeiyafa_fortress` `1 Samuel 17:1-3, 52`. Since v1.4.78 the
      card printed all of it correctly; `parseReference` truncates at the
      first comma, so `37-38`, `7, 8, 11`, `23-41` and `52` were cited
      and unreachable. Exactly 4 of 225 entries, counted, not sampled.

      **The rule is structural, and it had to be.** A bare comma part is
      read against what the part IMMEDIATELY before it resolved to: a
      preceding part that named a verse makes it a verse of that same
      chapter, a chapter-only one makes it a chapter. So `37-38` is
      John 18:37-38 and `7, 8, 11` are Daniel's chapters. A part that
      spells its own `chapter:verse`, or carries its own book, inherits
      nothing but the book. `;` is unchanged — it starts a new passage,
      so it never inherits a chapter.

      **The adversarial pass refuted the justification this was first
      written on, and the correction is the useful part.** The claim was
      "existence cannot disambiguate, because in `Acts 19:11-20, 23-41`
      the wrong reading Acts 23 is a real chapter". False: the chapter
      reading of `23-41` is the RANGE Acts 23–41 and Acts has 28
      chapters, so a range-aware canon check does reject it. The case
      that genuinely cannot be decided by existence is **Daniel** —
      12 chapters AND 49 verses in chapter 2, so chapters 7/8/11 and
      verses 2:7/2:8/2:11 are all real scripture, and a rule preferring
      verses would land a reader on Daniel 2:7: real, plausible on
      arrival, and not what the card cites. That example is now the one
      in the code and in the test.

      All four readings were checked against `assets/kjv.json` and the
      entries' own text — P52's recto/verso are 18:31-33 and 18:37-38 and
      the entry says so; the Ephesus summary opens "Acts 19:23-41 records
      a riot"; the Daniel summary says "chapters 2, 7, 8, 11". The
      citation is chipped **verbatim** (「52」, 「37-38」), never expanded,
      so the card goes on citing what the entry cites.
      `test/evidence_multi_reference_tap_test.dart`, 13 cases including
      the four asset entries and the counts. 21 of 225 entries now chip,
      204 keep the single flowing chip — asserted, not estimated.

- [x] **An inherited verse is not bounds-checked, so a bad citation
      would offer a verse that does not exist — closed with a standing
      data check, and it now covers the whole app, not just evidence.**
      `_inheritReference` builds `Book Ch:n` from the preceding part with
      no idea how long that chapter is, so `John 18:31-33, 45` puts a
      live tap target on John 18:45 in a chapter with 40 verses.

      **Not fixed in the parser, deliberately.** Bounds-checking there
      needs a canon table compiled into the app — 1,189 numbers that can
      themselves be wrong — spent defending against data that does not
      exist. That is the same trade the timeline/family-tree chip item
      below refused, and it is refused the same way here:
      `test/citation_target_in_canon_test.dart` checks the DATA and
      fails with the offending id.

      **Measured over every citation corpus in the app, not just the one
      this item was about — 251,320 tap targets, 0 outside the canon:**

      | asset | citations | resolved targets | out of canon |
      |---|---|---|---|
      | `bible_evidence.json` | 225 entries | 250 | 0 |
      | `bible_timeline.json` | 123 refs | 124 | 0 |
      | `family_tree.json` | 665 refs | 667 | 0 |
      | `cross_references.json` | 29,318 sources | 250,279 | 0 |

      `cross_references.json` is the find worth recording: 4.4 MB, two
      orders of magnitude larger than anything else, the surface that
      tells a reader 「this verse relates to that one」 — and it had no
      bounds check at all. Every target is parsed with the same
      `parseReference` call `CrossReferenceService._load` makes, so the
      test also proves 0 of the 250,279 are silently dropped.

      **A refuter broke the first version of this and both corrections
      are in the file.** (1) The claim "KJV and NASB/LEB disagree on
      exactly two chapter ends" was wrong — there are five, and
      Revelation 12:18 is LEB alone, not NASB. (2) The timeline and
      family-tree walk used `parseReference`, which truncates at the
      first comma, so `Luke 1:5-25, 57-80` and `Genesis 4:19, 22` had
      their second span unchecked — live instances of the very shape the
      item is about. Both now go through `splitCitation`.

      **The ruler is the union of KJV + NASB + LEB and has to be.**
      Against `kjv.json` alone the check reports one false alarm,
      `3 John 1:15` — see the next note on that item.

- [ ] **A cited range in a single-chapter book loses its end: `Jude
      14-15` resolves to Jude 1:14 with no `verseEnd`.** Found by the
      refuter on the item above, and pinned by an expectation in
      `test/citation_target_in_canon_test.dart` so it cannot be fixed
      without this being noticed.

      `_buildRef`'s single-chapter branch re-reads `Jude 14-15` as
      chapter 1 verse 14 and passes `verseEnd: verseStart`, which is
      null on that path — the 15 is dropped at parse time. Same class as
      the label defect already fixed at the top of this file (**shows a
      narrower passage than the one cited**), but one layer lower, so it
      reaches every surface that renders the RANGE rather than the
      citation text: `passage_localizer`, the verse popup's
      `verseStart..verseEnd` span, `version_mapper`, the search cards.
      `Jude 14-15` is cited in both `bible_evidence.json` and
      `family_tree.json`, so this is live, not hypothetical.

      Not fixed in this iteration because it changes navigation and
      highlighting behaviour, not a test, and one item at a time. When
      taken: carry the range through, then widen the canon check, which
      cannot currently see the dropped end.

- [x] **A citation that cannot be parsed still gets a 「→ 阅读经文」
      chip that can only apologise — fixed on BOTH evidence surfaces.**
      `cairo_genizah` cites `Ecclesiasticus (Sirach) 39:1` and
      `strabo_geography` cites `Various NT references`; both go down the
      single-reference path, which wired `onTap` unconditionally and
      answered "Couldn't parse reference" in a snackbar. Nothing is wrong
      with the data — those are honest citations of things the app does
      not contain — so it was the affordance that lied.

      **The list card had the same defect and this item did not know it.**
      The queue described only the detail-page chip; `evidence_page.dart`
      draws the reference row with a dotted underline, a trailing arrow
      and an `InkWell` that calls its own `_openReferenceFromCard`, and
      that path also ended in the snackbar. The list is the surface every
      reader scrolls, so it was the more visible of the two.

      Fixed the same way on both: an unresolvable citation keeps its book
      icon and its text and loses the underline, the arrow, the 「→ 阅读
      经文」 and the ink response. The card row now derives its affordance
      from `cardJumpTarget()` — **the same call the tap uses** — so the
      row cannot offer a jump the tap will refuse. A `;` citation whose
      first part fails and whose second resolves stays tappable, which is
      the behaviour this must not narrow.

      **Counted before concluding: exactly 2 of 225 entries, 0 empty.**
      The test asserts the two by name rather than the number alone, so a
      future import that adds a third fails with its id.

      **A refuter took all four claims and could not break any of them**
      — it re-derived the 225/2 with its own harness compiling the repo's
      real parser, confirmed all 7 shipped versions are 66/27-book with no
      Sirach anywhere, and read the pre-fix code out of `git show HEAD:`
      to confirm neither surface could navigate. It did correct one piece
      of wording, and the correction is the item below.

- [ ] **The timeline and person-detail reference chips have the same
      unconditional `onTap` — safe only because their data resolves.**
      Raised by the refuter on the item above, which had claimed the
      defect "does not exist" there. It does exist in the code:
      `_RefChip` in `bible_timeline_page.dart` and `_refChip` in
      `person_detail_sheet.dart` wire their tap exactly as the pre-fix
      evidence chip did, and both end in the same
      「Couldn't parse reference」 snackbar. What is true is that it is
      **not reachable from today's data** — measured, 123 refs in
      `bible_timeline.json` and 665 in `family_tree.json`, 0 unresolvable
      on either.

      Not fixed, deliberately: defending against data that does not exist
      adds dead UI code. The cheaper guard is the standing data check now
      in `test/evidence_unresolvable_citation_test.dart`, which fails if a
      future import hands either surface a citation it cannot open. If
      that test ever goes red, fix the chip the way the evidence chip was
      fixed rather than repairing the reference by guess.

- [ ] **Bounded scroll boxes are everywhere, not just the AI panel.**
      User, 2026-08-16: "很多时候这些框框都是上下滑动很多地方都是这样是不是
      全部要找出来fix". Supersedes the narrower AI-panel item: when
      that was queued I searched only `maxHeight` + scroll view and
      found one. The user is seeing more, so the search was too narrow
      — check `SizedBox(height:` and `Expanded` inside sheets too, and
      list what is found before fixing.

- [ ] **Pull-to-refresh does nothing useful, and the spinner is
      unnatural.**
      User, 2026-08-16: "往下滑的时候，感觉并没有用，而且那个转转的也并不
      自然，你这方面考虑了吗，好好想想". Two questions to answer before
      touching it: what SHOULD a dashboard refresh do (re-fetch remote
      data? recompute the daily verse? nothing?), and if the honest
      answer is "nothing the user can perceive", remove the gesture
      rather than animate it. A refresh control that always appears to
      do nothing teaches people the app is unresponsive.

- [ ] **The book-picker blocks look wrong — redesign.**
      User, 2026-08-16: "我怎么看左边那个blocks其实看起来很奇怪设计能够更好
      些吗，好好思考". The 66 uniform rounded squares of 1-2 characters
      read as a keypad rather than a table of contents, and the
      grid/list toggle does not help. Think about what a reader
      actually scans for — Old/New, the five divisions, book length —
      before moving pixels.

- [ ] **macOS: `No Overlay widget found` on the Songs page.**
      v1.4.75, 800x600, from `_OverlayPortalState.build`. An
      OverlayPortal is being built outside any Overlay — most likely a
      tooltip or a menu anchored above `MaterialApp`'s navigator.
      Reproducible on a small macOS window, so size it down to find it.

- [ ] **Notes need formatting.**
      User, 2026-08-16: "notes要加format之类的可以做？在chapter里面做笔记的
      时候". Scope it before building: bold/italic/lists is a different
      job from a full rich-text editor, and the notes are synced, so
      the storage format decides whether old notes survive.

- [ ] **The profile photo: should it be tappable?**
      User, 2026-08-16, asking for an opinion as much as a feature.
      Local photos can already be changed; a Google-signed-in photo
      comes from the account. Suggested answer: make it tappable
      everywhere and open the profile — for a Google photo, say where
      it comes from and link out rather than pretending it can be
      edited in-app. A control that looks editable and is not is worse
      than one that explains itself.

- [x] **Enabled the 47 Cahaya songs — and the SoundCloud link they now
      lead to was opening a 401 error page.**
      User, 2026-08-16: "还是enable吧", pointing at
      `https://cahayapengharapan.org/pujian/` and
      `.../pujian/video-pujian/`.

      **Why they were hidden, as the item asked:** recorded in
      `song_service.dart` — none of the 47 has a stream the player can
      open (the audio is on SoundCloud or YouTube), so every row showed
      a language badge where the rest of the catalogue shows a play
      button, and the user had asked for them out. Un-hiding alone would
      have restored exactly that complaint, so the row's leading slot
      now **opens the off-site source** instead of sitting inert, using
      the same glyphs the detail sheet's link chips use.

      **The data was re-derived from the live site before trusting it:**
      `fetch_cahaya()` run against cahayapengharapan.org today returns
      the same 47 ids as the bundled snapshot, 0 added and 0 removed,
      with no field differences. All 47 are non-playable and all 47
      carry a SoundCloud id (27) or a YouTube id (36), so no row is a
      dead end. Exactly one other song in the 609 has no playable audio
      — `fydt:94` — and it has sheet music rather than either, so it
      keeps the badge.

      **A refuter broke the claim that mattered, before it shipped.**
      `Song.soundcloudUrl` built `https://api.soundcloud.com/tracks/<id>`
      — the address the id is *scraped from*, which is an API endpoint,
      not a page. Checked live against all 27 ids: **27 of 27 answer 401
      with JSON.** The detail sheet's SoundCloud chip has been sending
      users there all along; this change would have added 27 list rows
      pointing at the same error. Now the widget player, verified on the
      same 27: 200 `text/html`, each carrying the canonical
      `soundcloud.com/<user>/<slug>` for the right song. The canonical
      is not derivable from the id without asking SoundCloud, so it is
      not guessed at.

      `test/cahaya_songs_enabled_test.dart` — three data checks (the
      rows load, no streamless row is a dead end, every Cahaya row has
      audio or video off-site) plus a widget test that searches the real
      catalogue and asserts the row's control is a real button. It fails
      on the pre-fix widget with the right diagnosis: the row is
      present, the tappable control is not. `song_model_test.dart` pins
      the URL form and asserts it is *not* the api.soundcloud.com one.

- [ ] **Now Playing: four things from the phone, 2026-08-12.**
      All four reported together with a screenshot and a crash report.
      Take them in this order — the second is a functional defect, the
      first is only awkward.

      1. ~~**The seek bar fights your finger.**~~ **Fixed (v1.4.76).**
         "我发现拖动的时候很难不顺". `onChanged: (v) => player.seek(...)`
         seeked on EVERY drag frame. Each seek made the position stream
         emit, which rebuilt the Slider from the ENGINE's position
         rather than the finger's, so the thumb was dragged backwards
         while you held it. `_Scrubber` is now stateful: `onChanged`
         only records where the finger is, and the seek happens once in
         `onChangeEnd`.

         **The release needed handling too, and the original note did
         not say so.** `SongPlayerService.position` is fed *only* by the
         engine's ~200ms `onPosition` stream — `seek()` does not update
         it synchronously (`song_audio_handler.dart:46`) — so
         `_dragValue ?? position` alone still shows the OLD position for
         a frame or two after you let go, which reads as the drag
         snapping back. The released value stays pinned until the engine
         reports within 1s of it, with a 3s give-up timer so a seek that
         never lands cannot leave the thumb lying about the position.
         The elapsed-time label reads the same pinned value, since a
         number disagreeing with the thumb is the same complaint moved
         one line down.

         `test/now_playing_scrubber_test.dart` drags the real Slider on
         the real page. The engine's position never leaves zero in a
         widget test, which is what makes it sharp: any non-zero value
         under the finger proves the thumb is following the drag. It
         fails on the pre-fix code at that assertion.

      2. ~~**Choosing Accompaniment keeps playing the vocal until you
         tap it a second time.**~~ **Two defects found and fixed
         (v1.4.75); the report is only PARTLY explained — see the last
         paragraph.** "我播放按了中间accom那个但是还在唱歌，按对一次才有的".

         **You were thrown back to track one.** The song you are
         listening to usually has no accompaniment — 108 of 609 songs
         publish one, 208 an instrumental, and both only on two of the
         four sources — so `TrackFallback.skip` drops it, which is the
         whole point of that fallback. `withPreference` then asked
         `fromSongs` for the old song by id, and when it was not found
         the index was left at its default of **0**. Asking for
         accompaniment on song 300 of "all songs" restarted the queue at
         song 1, and `setTrackPreference` carried the position across,
         seeking that unrelated song to where you had been in the other.
         Now the index is counted by POSITION (the survivors before you
         are the ones before your replacement), so you go FORWARD to the
         next song that has the mix, and the position carries across the
         same song only.

         **And on some queues the chip could not work at all.** CGDC and
         Cahaya record neither alternate mix, so a queue filtered to them
         offered an Accompaniment chip whose only effect was `no-tracks`
         on the strip. `SongQueue.hasMix` answers that from the queue and
         the picker now greys the chip out rather than taking the tap.

         **What is still not explained is "还在唱歌".** Both defects above
         change the audio (to the wrong song, or not at all); neither
         leaves the sung take playing with the chip selected. If it
         happens again, ask which source the song was from and whether
         the title changed — the remaining suspect is `_playCurrent`
         failing on a blocked host (fydt.org and CDC accept no connection
         from that network, and they are the only two sources with
         accompaniments) while the old audio keeps running.

      3. **The sleep timer needs a custom duration.** "sleep can you
         have customized time". Today it is a fixed 30-minute preset.
         Offer a few presets (15 / 30 / 45 / 60) plus a custom picker,
         and the one most music apps have and this app would use in a
         car: "end of this song".

      4. **Artwork can hang for 75 seconds and be reported as a crash.**
         `SocketException: Operation timed out (errno = 60)` on
         /NowPlayingPage, from `NetworkImage._loadAsync`. The song was a
         FYDT one, so the artwork host is fydt.org.

         **`NetworkImage` has no timeout knob** — this is why it took
         the OS default. `RemoteImage` already keeps a per-URL failure
         memo, but the first attempt still costs 75s and still reports.
         Options, in increasing order of work: widen the memo from URL
         to HOST so one failure spares every other row from that host;
         or back the provider with an http client that has a timeout,
         which is the only way to actually bound the first attempt.
         Whichever ships, an unreachable artwork host must not produce
         a crash report — it is an expected condition on a filtered
         network, and burying real crashes under it is the second cost.

- [ ] **Turn the featured video into a SERIES section — "Standing at
      the Cross / 在十字架下, A 10-Part Journey / 人生十堂课".**
      User, 2026-08-12: "那个featured video现有的删掉变成这里面的video，
      放成一个系列。暂时只有英语广东话… 因为以后可能更多板块，好好设计一下".
      Supersedes the plain rename item above — do that rename as part of
      this, not separately.

      **What is missing is one level.** `assets/onegod.json` already
      models `episodes[] → tracks[]`, where a track is one language's
      recording of the same teaching, and paths are already numbered
      (`/onegod/01/en.mp4`). What it cannot express is a SERIES: a
      titled, ordered collection of 10 parts. Add that level rather
      than starting over —

          series[] → episodes[] → tracks[]

      with `series` carrying localised title AND subtitle lines, since
      this one has four ("Standing at the Cross" / 在十字架下 /
      "A 10-Part Journey" / 人生十堂课). Two series must be able to
      differ in language coverage: this one is English + Cantonese only,
      while 獨一真神 has Mandarin too, so language buttons have to come
      from the episode, never from a fixed list.

      **ASK BEFORE DELETING 獨一真神.** The user said "现有的删掉", but
      the structure they are asking for makes deletion unnecessary — it
      becomes one series beside the new one. Deleting it discards 238 MB
      of hosted video and, less replaceably, the subtitle work: five VTT
      files whose timings came from Whisper and whose words came from
      the church's own .docx via `scripts/align_subtitles.py`. That is
      not a re-run, it is a rebuild. Put both series in, show the user,
      and let them delete it afterwards if they still want to.

      **UNBLOCKED 2026-08-17. Both open questions are answered.**

      *Hosting:* YouTube. User: "featured video从YouTube那里拿". So
      `videoBase` and the 238 MB media site are NOT the answer for this
      series.

      *Source:* `https://yahwehdehua.net/assets/page/easter/`, whose
      own `<title>` is exactly the series name — "Standing at the Cross
      : A 10-Part Journey / 在十字架下 : 人生十堂课". **It 403s without
      a browser User-Agent**; curl with one returns 200.

      27 embeds on that page, read 2026-08-17. Ten parts, each in two
      languages, numbered on the page itself:

      | # | English | Chinese |
      |---|---------|---------|
      | 1 | h7hE0XB3SWs | Voc7M_I1YJw |
      | 2 | 4WladhGvkAM | omzJLl83zIo |
      | 3 | GgUiSRBMgj4 | Xee1AhOkiDY |
      | 4 | xXC3IYb128Q | -JgvZGZ8zmc |
      | 5 | zCyNjjWhkMg | kuZ8qcAm7UI |
      | 6 | 483CYa3BjXg | ZzXZmSmMtWs |
      | 7 | OPzyLFP-TMA | Slng6u-YMsM |
      | 8 | SjQCm4m-rmk | 5Z1upfO2Ff0 |
      | 9 | OSKe5G6BW8c | bIJXg7dew2g |
      | 10 | CincIrfTfDs | J8bBBHIuxjI |

      Also on the page and NOT part of the ten: `1OIZE4HnheE` (sits at
      the top, next to "Videos / 视频" and "Songs / 诗歌" — probably an
      intro), `xrHR1ybo1J0` (a teaching clip), and three songs
      (`s3-qcRZrfZk`, `YTp0Z_TYOns`, `4GBO6CWR6go`). `QXU-gazdgN0` and
      `4ImxTDU5J0k` also carry part-10 captions and may be alternate
      cuts — **check before including them; do not guess.**

      **Verify the pairing against the page rather than trusting this
      table.** It was built by reading the nearest labels before each
      embed, which is a heuristic. Re-derive it, and if any row
      disagrees, the page wins.

      **One thing to confirm with the user:** they said the series is
      "英语广东话", but the page labels the second track only as
      Chinese — it does not say whether it is Cantonese or Mandarin.
      Do not label it 廣東話 on the strength of an assumption; ask.

      **The consequences of YouTube, which the design has to absorb:**
      * `video_player` **cannot play a YouTube URL.** A different
        package is needed (`youtube_player_iframe` or a webview). That
        is a real dependency decision — check bundle size and whether
        it works on all six targets before committing to one.
      * Subtitles come from YouTube, not from us. The
        `scripts/align_subtitles.py` pipeline and the `.vtt` files
        under `assets/subtitles/` apply to 獨一真神 only.
      * There is no offline download for a YouTube video. If the
        Songs-style "download for offline" affordance appears anywhere
        near this section, it must not be offered here.
      * The position-preserving language switch still matters and is
        still possible — ask the embed for its current time before
        swapping, the same idea as today, different API.

      **Design notes worth keeping:** the section label becomes the
      series list, not a single video; a series with one episode should
      not render a list of one; and the existing position-preserving
      language switch is the feature most worth carrying over — it is
      why tracks live under an episode rather than beside it.

- [x] **Rename 獨一真神 to "Featured video"** — folded into the series
      item above, 2026-08-12; doing it alone would be work thrown away.
      The rename itself is step 1 there: give the SECTION its own key
      rather than editing `oneGodTitle` (used at 4 sites) in place, since
      the video's actual title is still 獨一真神. Step 2 — the content
      becoming YouTube links — stays untouched until the user says so.

- [x] **An interactive Bible chronology chart** — REASSIGNED to the
      SeekSparks session, 2026-08-16, at the user's request ("这个先不
      做，交给seeksparks那个session做"). Do not start it here. The
      original write-up, including the copyright and Ussher-chronology
      constraints, is kept below because whoever picks it up needs it.

<details><summary>original</summary>

- [ ] **An interactive Bible chronology chart — LOW priority, several
      iterations.**
      User, 2026-08-12, with a reference PDF (staged at
      `docs/reference/364673272-World-History-Chart-Bible-Chronology.pdf`):
      "我要你参考这个图，你做一个可以iteractive的放在一个板块里面…而且是
      featured，但是这个会更费时间". They said explicitly it is not high
      priority and expected it to span several iterations.

      **The reference is Adams' "World History Chart in Accordance with
      Bible Chronology": a fan/spiral of parallel nation-streams from
      creation to 2000 AD, colour-coded by descent — Semitic, Hamitic,
      Japhetic, Cain's line, and the Christian church.

      **Two constraints that decide the whole design.**

      1. **It is under copyright.** The sheet itself reads "Copyright
         2012, All Rights Reserved. Published by Bible Charts and Maps,
         LLC. ISBN 978-0-9787327-2-3". The PDF is a REFERENCE for the
         idea — parallel lifelines, descent colouring, a readable
         spiral — and must not be traced, re-typeset, or have its data
         transcribed. Build from `assets/bible_timeline.json` (98
         events, already trilingual with refs and personIds) and from
         the genealogies in our own Bible text.

      2. **Its dates are Ussher, and Ussher is one chronology among
         several.** The chart puts creation at 4004 BC. The Masoretic,
         Septuagint and Samaritan genealogies of Genesis 5 and 11
         disagree by roughly 1,500 years, and that is a real scholarly
         division, not an error to pick a side in. Under the user's own
         standing rule — 经文一定要准确 — a chart that prints "4004 BC"
         as a fact is exactly the kind of thing that "reads plausibly
         and is wrong and gets quoted". Either show the ranges, or
         label the scheme being used on the chart itself. The
         misconceptions module already sets the tone for how this app
         handles a genuinely divided question.

      **Do not start it as a new page.** `lib/pages/bible_timeline_page.dart`
      (620 lines) and `assets/bible_timeline.json` already exist and are
      already linked from Explore more. Decide first whether this is a
      new VIEW on that data or a replacement for that page; shipping a
      second, prettier timeline beside the existing one is the outcome
      to avoid.

      Suggested first iteration, before any drawing: extend the data
      model with what a lifeline chart needs and cannot currently
      express — birth/death years per person, parent links, and the
      chronology scheme each date belongs to — and write the test that
      every year is sourced. The rendering is the easy half.

- [x] **The AI exegesis panel cannot be scrolled — fixed by deleting the
      inner scroll view.** The transcript now flows into the sheet's own
      `ListView` and scrolls with everything else; the direction chips
      sit below it, one swipe away. The 320pt cap and its `Scrollbar` are
      gone.

      **The queue's own claim that this was the only instance of the
      shape was wrong, and counting said so.** There are 14 bounded
      scroll views in `lib/`, not one. Thirteen are fine and were left
      alone: they cap at a FRACTION of the viewport
      (`MediaQuery.of(context).size.height * 0.35`) because that is how
      every sheet and dialog here is sized, and the scroll view under
      them is that sheet's only scrollable — `_PassageFilterSheet` was
      read in full to confirm the body is a `mainAxisSize.min` Column,
      not a scrollable. What broke was the one cap in fixed POINTS:
      that says "clip this region and scroll it by itself", which only
      holds while nothing around it scrolls in the same axis, and in a
      sheet something always does.

      `test/nested_scrollable_test.dart` checks the shape rather than
      this panel — a widget test would pump one panel in one state and
      miss the next one nested. It flags a fixed-point `maxHeight` whose
      direct child is a vertical scroll view, and verified: 1 offender
      on the pre-fix source, 0 after. Deliberately out of scope: the
      onboarding dialog's 240pt `PageView` of independently scrolling
      slides, which scrolls across the parent's axis rather than
      against it.

<details><summary>original</summary>

</details>

- [ ] **The AI exegesis panel cannot be scrolled — a nested scroll view
      inside the sheet.**
      User, 2026-08-12, with a screenshot of 創世紀 36:3: the AI answer
      is visibly cut mid-sentence ("也削弱了名字本身所承载的家族谱") and
      "I realize I cannot scroll down".

      **Cause** (`lib/widgets/originals_sheet.dart:1607`): the answer is
      wrapped in `ConstrainedBox(maxHeight: 320)` → `Scrollbar` →
      `SingleChildScrollView`, and that whole thing sits inside the
      sheet's own outer `ListView` (line 666). Two scrollables stacked
      in the same axis: a drag started inside the inner box is
      ambiguous, and in practice the sheet takes it, so the inner region
      never moves. The scrollbar renders — which is why it looks like it
      should work — and the content underneath stays put.

      **Preferred fix: delete the inner scroll view.** Let the text flow
      into the outer list and scroll with everything else. The cap
      exists so the direction buttons (本章 / 本書卷 / 深度釋經) stay
      reachable without scrolling past a long answer, but that is a
      weaker goal than being able to read the answer at all, and the
      buttons are only a swipe away once the panel scrolls normally.

      If the cap is kept instead, the inner view needs its own
      `ScrollController` plus a `NotificationListener`/`ScrollPhysics`
      arrangement that hands the gesture back to the sheet only at the
      inner extent — worth doing only if someone first confirms the
      buttons genuinely become hard to reach without it.

      **Check the same shape elsewhere while in there.** The user also
      asked whether the sermon block is the same problem. It is a
      different item (see "Sermon reading" below — that one is about
      paragraph rhythm, not scrolling), but any OTHER bounded-height
      scrollable nested in a scrollable has this defect by
      construction. Already searched: of the 20 `maxHeight` uses in
      `lib/`, this is the **only** one wrapping a scroll view, so
      fixing it fixes the whole class. Do not go hunting again.

</details>

- [x] **The web app is letterboxed on Android tablets: the manifest
      locked portrait — fixed in `34dd0ce`,** shipped in v1.4.72. The
      code landed but the item was never ticked; ticking it here on
      2026-08-12 after re-reading `web/manifest.json` — the key is
      DROPPED rather than set to `"any"`, which is the same thing to a
      browser — and `test/web_manifest_test.dart`, which pins its
      absence along with the fields an install depends on.
      Still needs the tablet check below, which only the user can do.

<details><summary>original</summary>

- [ ] **The web app is letterboxed on Android tablets: the manifest
      locks portrait.**
      User, 2026-08-12, from a Xiaomi Pad: "webapp打开两边是黑的不能像
      ipad webapp一样吗".

      **Cause, read off the deployed manifest** (`curl
      https://yswords-dev.netlify.app/manifest.json`):

          display      "standalone"
          orientation  "portrait-primary"

      Android honours that lock for an installed PWA, so a tablet held
      in landscape gets a portrait-shaped window with black bars either
      side. **iOS and iPadOS ignore the manifest `orientation` field
      entirely** — Safari does not implement it — which is exactly why
      the same build fills the screen on the iPad and does not on the
      Android tablet. One manifest, two platforms, and the difference
      is this single line.

      **This is not a layout problem.** The app is already responsive
      across 375–1280 and `test/responsive_all_pages_smoke_test.dart`
      holds it there. The manifest is refusing landscape before any
      Flutter code runs.

      **Fix:** in `web/manifest.json`, `"orientation": "any"`, or drop
      the key. Check whether the file is generated or hand-maintained
      before editing — `flutter build web` will overwrite a generated
      one.

      **Verifying needs an uninstall.** Android caches the manifest in
      the WebAPK, so an already-installed PWA keeps the old orientation
      until it is removed and re-added. A tester who skips that step
      will report the fix as not working.

</details>

- [ ] **Re-probe the blocked hosts EVERY iteration, and take the work
      the moment they answer.**
      User, 2026-08-11: "api之前没拿到的是不是可以拿到了也加入iteration".
      The point is that this should not depend on anyone remembering to
      try.

      `bash tools/check_media_hosts.sh` — a few seconds, exit 0 when all
      four answer, and it names each host either way so a caller can
      decide per host rather than all-or-nothing. Run it at the START of
      an iteration whenever the next queue item needs one of them.

      **When `fydt.org` answers**, these become possible and should be
      taken in this order:
      * the 578 fydt songs' artwork and the source-cover fallback,
      * re-running the songs sync against the fydt API.

      **When `www.christiandiscipleschurch.org` answers:**
      * reconcile our Matthew sermons against the church's own 124
        (five consecutive attempts have failed to get a TCP connection),
      * the 402 CDC songs' artwork.

      **Do not** treat a failure as a reason to retry in a loop, and do
      not look for a way around it: from the maintainer's Mac the block
      is a managed-device policy (GlobalProtect + CrowdStrike Falcon +
      Jamf) and no amount of retrying will change it there. The probe
      exists so the answer can change by itself when the same work is
      run somewhere else, or when the policy does.

- [ ] **Native should fall back to the Netlify media proxy when a host
      is unreachable. — DECIDED NOT TO SHIP YET, 2026-08-11.**
      The user chose "先不做，写进队列" after being shown the bandwidth
      cost. **Do not implement this without asking them again.** What
      follows is the finished investigation so the decision can be
      picked up cold.

      **The finding.** `netlify.toml` already proxies all four media
      hosts (`/song-media/fydt/* → https://fydt.org/:splat`, and the
      same for cdc / cahaya / cgdc). Only the WEB build uses it —
      `SongPlayerService.resolvePlaybackUrl` opens with
      `if (!kIsWeb) return url;`, so every native platform streams,
      downloads and fetches PDFs straight from the church servers.

      **Measured from this Mac, which cannot reach fydt.org at all:**
      ```
      direct https://fydt.org/…/S03_006.mp3   no TCP connection
      via    /song-media/fydt/…/S03_006.mp3   HTTP 206, 86ms, real bytes
      ```
      Netlify reaches the upstream fine. So a proxy fallback fixes every
      restricted device at once — the user's iPad and Xiaomi Pad, and
      any user behind a filtered network — without diagnosing each one.

      **Why it was not shipped.** It moves media bandwidth onto the
      user's Netlify account. One "download everything" is 2.1 GB
      against a 100 GB/month free tier, so a handful of users doing it
      would blow through the plan. That is their call, not ours.

      **The shape they picked, for when they say yes:**
      * Direct first, proxy only after the direct attempt fails, and
        remember the verdict per HOST for the session — otherwise every
        song pays the 15s timeout again.
      * Origin: **the dev site**, `https://yswords-dev.netlify.app`
        (their choice when asked). Note the consequence they accepted:
        a production build then depends on the dev site staying up.
      * Four call sites need it, not one: playback
        (`resolvePlaybackUrl`), downloads (`song_download_io.dart`),
        artwork (`RemoteImage`) and the score viewer.

- [ ] **Tap-the-status-bar-to-scroll-to-top: 24 pages still lack it.**
      User, 2026-08-11: "我以为所有的page按了top iPhone是会自动划上去的但是
      Sermon这个就不是，也全部检查一下". Sermons is fixed; the audit they
      asked for, run over `lib/pages/*.dart`:

      **Have it (2):** songs_page (5 scroll views), sermons_page (3).

      **Missing (24 pages, 59 scroll views):** stats_page (14),
      search_page (9), bible_trivia_page (4), evidence_page (3),
      family_tree_page (3), library_page (3), dashboard_page (2),
      evidence_detail_page (2), highlights_page (2),
      misconceptions_page (2), now_playing_page (2), and 13 pages with
      one each — about, bible_timeline, feedback, map_viewer,
      one_god, profile_edit, profiles, sermon_detail, settings,
      song_downloads, song_playlist_detail, song_playlists,
      strongs_entry.

      Mechanical work: wrap the scroll view in `ScrollToTopOnStatusBarTap`
      and give it the controller. Two things to watch — a page with
      SEVERAL scroll views needs the one the user is looking at, not the
      first one found (stats_page and search_page are the hard cases,
      and tabs make the answer depend on the selected tab), and the
      widget already guards on `ModalRoute.isCurrent` so a page behind a
      sheet does not steal the tap.

- [ ] **Sermon reading: "每个段落一个block也不好experience".**
      User, 2026-08-11. This is a follow-up on the v1.4.x paragraph work
      (`lib/pages/sermon_detail_page.dart:749`), which added a line
      measure, a 1.75 line height and 22pt between paragraphs. That
      fixed the wall-of-text complaint; the user is now saying the
      result reads as a series of separate blocks instead of continuous
      prose.

      **Reproduce before changing anything, and get the exact sermon.**
      The current code draws no card, border or background per
      paragraph — only `Padding(bottom: 22)` — so "block" is the user's
      description of how it READS, not a literal container, or else it
      is a sermon whose transcript is split differently from the ones
      that were measured. Open a real sermon at 402pt and at desktop
      width before forming a theory, and ask the user which sermon if
      it is not obvious.

      Levers, in order of how safe they are:
      1. The 22pt gap is large relative to a 1.75 line height — the
         space between paragraphs is close to the space inside them,
         which is exactly what makes text read as separate blocks
         rather than a flowing argument. Try a first-line indent with a
         much smaller gap, which is what printed prose does.
      2. The measure is `fontSize * 34` (30 for CJK). On a phone that
         is wider than the screen and has no effect; the blockiness is
         therefore a phone-specific complaint about vertical rhythm,
         not line length.

      **The standing rule still applies: nothing may re-paragraph a
      sermon.** Inserting or removing breaks in another man's preaching
      is an expressive decision he did not make. Only typography moves.

- [x] **The splash no longer loads a single version — the pre-load now
      waits for it to go.** The line the user objected to is gone,
      because the work it described is off the boot path entirely.

      **The recorded diagnosis below was half wrong, and the wrong half
      mattered.** It says the splash "walks 7 versions before the splash
      dismisses". It does not — v1.3.4 already made the pre-load
      fire-and-forget, and the splash dismisses on its own 3 s advance
      timer (`loading_page.dart:317`) regardless. So the progress line
      was reporting background work **nobody was waiting for**: it was
      left over from v1.2.25, when the loop really did block the splash.

      That does not make it harmless. Each version is a `json.decode` of
      a 2–9 MB string on the main thread, six of them, started
      immediately after bootstrap — so they ran *underneath* the splash,
      janking its animation and delaying the very Timer that dismisses
      it. The user was seeing a screen that said it was loading Bible
      versions while their phone had every one of them in the bundle,
      and the claim was slowing down the screen that made it.

      **Fix, in the shape the item asked for — off the boot path, not
      deleted.** `MainProvider.splashDismissed` is a Completer that
      `_RootRouter._advance()` completes at the moment the splash hands
      over; the loop (now `lib/services/version_preloader.dart`, lifted
      out of `_MainAppState` so its ordering is testable at all) awaits
      it before the first decode. The user's v1.2.25 choice is intact —
      every version still lands in the LRU, just after the splash rather
      than under it.

      The splash's version-progress subtitle, its determinate progress
      bar, `versionPreloadCount`/`Total` and the `loadingVersionsProgress`
      ui-string are all deleted rather than hidden: with the pre-load
      deferred, nothing could ever set them, and a splash that can paint
      "Loading versions: 3/6" over bundled assets is the exact claim the
      user says is untrue. The verse-fetch retry subtitle stays — that
      one is a real wait.

      `test/splash_version_preload_test.dart` asserts no version is
      touched before `markSplashDismissed()`, and fails on the pre-fix
      ordering with `Actual: ['kjv', 'nasb', 'leb', …]`; a widget test
      pins that a healthy splash paints no progress line in any of the
      three locales. **Not yet confirmed on the user's iPhone** — the
      acceptance test is their own sentence, and only they can run it.

      Original report, kept for the record —
      user, 2026-08-11, from the iPhone: "为什么每一次加载的时候都会加载
      中译本，但是iPhone不应该全部已经有了吗，不应该有加载中这个界面",
      and again on 2026-08-12: "the loading
      page in iphone still have loading bible version which I feel no
      need right because it is iphone so it will be loaded in phone".

      **Still true and still unmeasured:** every version really is
      re-decoded at every launch — `MainProvider.preloadVersion` short-
      circuits only on `_versesCache`, an in-memory LRU that dies with
      the process — and nobody has ever timed a decode on real hardware.
      The `~1 s` in the code is an estimate. That cost has simply moved
      out from under the splash; if the user reports jank on the
      dashboard in the first seconds after boot, the next step is to
      measure on the device, and after that a pre-parsed binary form the
      OS can mmap rather than a faster decode.

> **Host reachability, re-measured 2026-08-11 from the Mac with
> Tailscale stopped and the sandbox disabled — this corrects what the
> items below assumed.** `cgdc.hk` (200, 104ms) and
> `cahayapengharapan.org` (200, 341ms) are UP. `fydt.org` (578 songs)
> and `www.christiandiscipleschurch.org` (402) resolve — Vultr IPs,
> 45.77.28.58 and 149.248.15.146 — but accept **no TCP connection at
> all** from this network, and take the identical route out `en0` as
> the two that work. Not DNS, not the sandbox, not Tailscale, and no
> VPN route is installed. Confirmed independently on the user's iPad:
> of 559 songs only 63 downloaded, and all 63 are the cgdc.hk ones.
>
> **Cause found.** This Mac is a managed Monash device: GlobalProtect
> (portal `vpn.gp.monash.edu`, `PanGPS` running), CrowdStrike Falcon as
> an endpoint-security system extension, and Jamf MDM. A macOS Network
> Extension filters at the socket layer, not the routing layer, which
> is exactly why DNS, `route get` and the interface list all looked
> clean while no SYN ever got a reply. **This is the employer's policy
> on their own device — do not attempt to work around it.**
>
> So work needing cgdc.hk IS actionable from this machine; work needing
> fydt.org or the church site is NOT, and never will be from here — it
> needs a different machine, not a retry. The user reports their phone
> reaches both hosts on the same WiFi, while their iPad and Xiaomi Pad
> do not; those two are unexplained and do not need explaining if the
> proxy-fallback item above is ever taken.

- [ ] **Per-source cover fallback for the 393 songs with no artwork.**
      User, 2026-08-11: "没有封面的你可以用他们来源的封面做为歌曲的吗？
      我相信网站都有相应的网站特有的封面图". They are right — every one of
      these WordPress sites publishes a 180×180 `apple-touch-icon`,
      which is the correct asset for this:

        cgdc.hk      /wp-content/uploads/2026/05/cropped-cgdc_hk_website_icon-180x180.jpg
        cahaya       /wp-content/uploads/2022/03/cropped-cpm-ico-180x180.jpg
        fydt.org     UNKNOWN — host down all of 2026-08-10/11
        cdc          UNKNOWN — host down all of 2026-08-10/11

      **Do not start until fydt.org and christiandiscipleschurch.org are
      both reachable, and do NOT guess their icon URLs.** The reason is
      arithmetic: of the 393 songs with no artwork, **283 are CDC** and
      47 are cahaya. cgdc now has real per-album art, and fydt is only 14
      short. So building this while CDC is down reaches 47 songs and
      leaves the actual problem untouched — a half-fed mechanism that
      looks finished.

      When both are up: read each site's `apple-touch-icon` (fall back to
      `og:image`, then `rel=icon`), **bundle the four files as assets**
      rather than hot-linking them. Hot-linking would put four more
      remote images behind every list row, and a down host is exactly the
      failure that produced the `errno = 60` crash report — bundled
      assets cannot hang.

      Wire it as a fallback INSIDE `RemoteImage`'s `fallback:` on the
      song row, so precedence stays: real artwork → source icon → the
      plain play button. Keep it visibly a source mark, not a fake cover:
      it says where the song came from, and every row claiming bespoke
      album art it does not have would be its own small lie.


- [ ] **`RemoteImage` for the other image sites — LOW priority, and the
      earlier note here overstated it.** Corrected 2026-08-11 after
      actually reading them: the other 14 `Image.network` calls already
      carry `errorBuilder`, a `cacheWidth`/`cacheHeight` decode cap, and
      `webHtmlElementStrategy: prefer`. They are **not** in the state the
      song list was in.

      What made the song list a crash was the combination, not any one
      part: 199 rows against a single unreachable host, no decode cap,
      and no memory of the failure — so the 60s socket wait (NetworkImage
      has no timeout knob) was paid per row and again on every scroll
      back. The others are one image per screen with the caps already on.

      So the only thing they gain is the failure memo, which is worth
      having but is not a crash fix. **If converting, carry
      `webHtmlElementStrategy` across** — several of these hosts send no
      CORS headers, and dropping it looks like nothing on native while
      silently blanking the image on web. `RemoteImage` now takes the
      parameter for exactly that reason.

- [ ] **CGDC publishes album art we never look for.** 393 of 606 songs
      have no `artworkUrl` — CDC, CGDC and Cahaya publish none, and the
      sync only ever reads it from fydt's WordPress API
      (`sync_songs.py:547`). But a CGDC song page carries a per-album
      image (`Sail-logo.png` for 2026 SAIL 乘風破浪) and its player has a
      per-track `poster` field served over `admin-ajax`. Album-level art
      for all 63 CGDC songs is a small scraper change; per-track needs
      the AJAX endpoint. Re-check CDC when the host is reachable — it
      was down for this whole investigation, so "CDC has no images" is
      unverified rather than established.


**All four done in v1.4.39** (2026-08-11, at the user's request to
finish the Songs module in one night). Left ticked rather than deleted
so the bundle-size answer stays on the record.

- [x] **In-app score (PDF) and video.** `SongScorePage` (pdfrx) and
      `SongVideoPage` (video_player). The real count was **579** songs
      with a score, not 554; 82 with an mp4. Scores prefer the
      downloaded copy, then the web cache, then the network through the
      **same same-origin proxy the audio uses** — pdfrx fetches by XHR
      and no church server sends `Access-Control-Allow-Origin`, so a
      direct load never gets a byte. Video is mp4-only; YouTube and
      SoundCloud still open externally, and Windows/Linux keep the
      link-out because `video_player` has no implementation there and
      would throw at runtime.

      **Bundle cost, measured before committing to the dependency:**
      `main.dart.js` gzipped went 1,944,117 → 1,945,132 (**+1,015 B,
      +0.05%**) because pdfium ships as a separate 5.23 MB wasm asset
      that is fetched only when a score is opened — never on first
      paint. Verified served from dev as `application/wasm`; a wrong
      MIME there breaks `instantiateStreaming` outright.

- [x] **Downloads include the score.** Fetched after the audio is
      committed, failure swallowed — a 404 on sheet music must not turn
      a downloaded song red or put it in the Retry batch. Checked for a
      `%PDF-` magic number first: the churches' sites answer a missing
      file with an HTML error page and HTTP 200.
- [x] Search box on the Downloads page — appears at 8+ downloads,
      narrows the list only, leaves the space total honest.
- [x] Artwork thumbnails in song list rows — behind the play button, so
      the 407 songs without artwork are not left with a hole.

- [x] **`release_web.sh` could report success when a site did not deploy
      — the site is now asked, and it decides.** 2026-08-17.

      The old `deploy_sites` ran each `netlify deploy` with `&` and then
      a bare `wait`, which returns 0 whatever the jobs did (verified on
      this machine's bash 3.2: `set -e; (exit 7) & wait; echo $?` → 0),
      so `set -e` could never fire.

      **Waiting per PID was NOT enough on its own, and an adversarial
      pass is what established that.** "Deploy canceled" is a state
      Netlify can set *after* the upload finishes and the CLI has already
      exited 0 — no exit code carries it. So exit codes now only drive a
      one-shot sequential retry of a failed site, and success is decided
      by **re-fetching from the site**: `version.json` must be this
      version, and the served `flutter_bootstrap.js` must be
      byte-identical to the `build/web` copy that was just uploaded.

      **The bundle check is a hash comparison, which needs no assumption
      about what is inside the file.** Measured: Netlify serves that file
      byte-for-byte as it is on disk, cn-dev and cn-qat both matching the
      local artifact while dev and qat carry a different hash. This is
      the check that catches the recorded recovery hazard — build/web
      holds the CHINA bundle once the second build starts, so a redeploy
      after a failure can ship CHINA_MODE to an international site.
      Its blind spot is written into the code: the two bootstraps differ
      only because `--no-web-resources-cdn` goes to the China build
      alone, so giving that flag to both (or neither) would leave the
      check passing and blind.

      Verified against the LIVE sites with the netlify CLI stubbed, so
      nothing was deployed: a matching bundle passes both cn sites; the
      international sites abort while build/web holds the China bundle;
      a version the sites do not serve aborts; and a CLI failure is
      retried alone and then verified. The same failure run on the
      pre-fix code (`git show HEAD:`) prints 「✓ deployed」 and exits 0,
      which is the evidence that this was real and not theoretical.
      Also added: a refusal to deploy at all when `build/web/main.dart.js`
      is missing.

      Two corrections this turned up, both worth more than the fix:

      1. **The recovery advice recorded below was wrong.** It said to
         「check `flutter_bootstrap.js` mentions `gstatic.com/flutter-canvaskit`
         to tell the two apart」. Both bundles mention it — it sits in the
         engine loader on every build. The real marker is
         `"useLocalCanvasKit":true`, present only on the China build.
         Following the old advice during a recovery would have identified
         the bundles backwards.
      2. **A query string does not bust Netlify's edge cache.** A fresh
         random `?v=` returns the same edge object with the same `age`
         and `etag`. Freshness after a deploy comes from Netlify
         invalidating on deploy, not from a cache-buster, and the first
         draft of this fix carried a comment claiming otherwise.

      Left alone deliberately: `curl` has no `-L`, so if the prod
      hostnames ever move behind a redirecting custom domain, an
      `--include-prod` run would abort. Both answer 200 directly today.

<details><summary>original report</summary>

- [ ] **`release_web.sh` can report success when a site did not deploy.**
      Hit on 2026-08-11 during the v1.4.61 release: `deploy_sites` runs
      each `netlify deploy` with `&` and then a bare `wait`, which
      returns 0 whatever the jobs did — so `set -e` never fires. The run
      printed 「✓ v1.4.61 deployed」 while **yswords-qat was still serving
      v1.4.60 and the pre-fix Greek asset**. Caught only because this
      iteration checks `version.json` on all four sites afterwards; a run
      that trusted the script's own ✓ would have left one site behind.
      Fix is small — collect the background PIDs and `wait "$pid" ||
      fail` each one — but it changes the release path, so measure the
      failure rate first (re-running with `--no-bump` deployed all four
      cleanly, so it looks transient rather than a broken site config).
      **Until it is fixed, always verify all four `version.json` after a
      release.**
      **Second occurrence, 2026-08-11, v1.4.65 — same site, same
      shape.** The script printed 「✓ v1.4.65 deployed」 and exited 0
      while yswords-qat still served v1.4.64. This time the cause is on
      record: `netlify api listSiteDeploys` for
      `2bcb6644-2a3a-4050-b6dc-5b059bbe96d3` returns
      `state: error, title: "v1.4.65 qat", error_message: "Deploy
      canceled"` — so the CLI *did* fail, and the bare `wait` threw the
      status away. Two for two on the same site suggests the parallel
      `&` fan-out is what gets one deploy canceled, not chance.
      Recovering it is not just `netlify deploy` again: by the time you
      notice, `build/web` holds the **China** bundle (it is built
      second, in place), so redeploying it to an international site
      would ship CHINA_MODE to yswords-qat. The international bundle has
      to be rebuilt first — check `flutter_bootstrap.js` mentions
      `gstatic.com/flutter-canvaskit` to tell the two apart, since the
      China build passes `--no-web-resources-cdn` and the intl one does
      not.
      Worth fixing now rather than measuring further, and worth fetching
      one repaired asset (not only `version.json`) to confirm a deploy
      truly landed.

</details>

## P3 — known but blocked or deferred

- [ ] EC018 / EC019 sermon transcripts are raw speech recognition —
      EC019 has one period and no commas in an 18,205-character
      paragraph. Look for better transcripts on the T7 drive before
      anything else; never re-punctuate a preacher's words.
- [ ] Sermon audio hosting — **deprioritised by the user.** Inventory is
      done (289/289 have audio, 661 parts, 5.46 GB, do not re-encode:
      already 32 kbps mono). The service is written and dormant; set
      `SERMON_AUDIO_BASE` when a host is chosen.
- [ ] NASB divine-pronoun capitalisation (#173-176) — tied to the
      unresolved NASB licensing question. Ask before investing.

## Blocked on the user — do not attempt

- **prod deploy.** Every prod push needs explicit permission in the
  moment; it does not carry over. prod is on v1.4.11 and still serves
  the broken LEB and the wrong sermon attribution.
- **NASB licensing** — `assets/nasb.json` is 7.2 MB and publicly
  fetchable from both prod sites. The user's stated position is that
  NASB needs permission; nothing has been done about it. Ask before
  investing in anything NASB-shaped (including #173-176).

## Unblocked 2026-08-10 — no longer an excuse to skip native work

- **Xcode signing works again.** It failed for weeks with "No Accounts:
  Add a new account in Accounts settings", which is why
  `com.yswords.ios-reinstall` shows `runs=7, exit=1`. The user signed
  in; verified by a real build, not by checking for an account record:
  `flutter build ios --release` now reports "Automatically signing iOS
  for device deployment … team YC5JZD3DY7" and produces
  `build/ios/iphoneos/Runner.app`.

  Two things still gate an actual install, and neither is yours to fix:
  the iPhone must be unlocked and on the same network as the Mac, and
  the certificate is a **free** Apple ID one that expires every 7 days,
  so the app dies on the phone weekly until someone reinstalls. Do not
  treat a reinstall failure as a code defect without reading
  `/tmp/yswords-ios-reinstall.log` first.

- **梁家鏗's source is obtained.** Both editions: the publisher's
  Simplified JSON at `~/.cache/yswords/ljk-source/`, and the printed
  Traditional 註釋本 PDFs the user supplied (extract with `pdftotext
  -enc UTF-8`). The Traditional is the authority for the Traditional
  side — conform to it, do not "correct" it.
