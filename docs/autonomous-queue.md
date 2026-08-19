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

> ### ▶ DO THE FEATURED-VIDEO SERIES FIRST — user, 2026-08-19
>
> **Before anything in P0.** The user has asked about it three times
> and it has not been started; meanwhile P0 keeps growing faster than
> it is cleared (52 → 62 open, P0 22 → 32 in a day), so "after P0" was
> becoming "never".
>
> The item is in P2: **"Turn the featured video into a SERIES section"**.
> Take it now, in the staged way that item describes.
>
> **What is ready:** the model change (series → episodes → tracks),
> 獨一真神 staying as one series, and Standing at the Cross with all 20
> YouTube IDs already recorded in the item.
>
> **What is not:** the Shema series' IDs — that host refuses datacenter
> IPs and the user has to supply them. **Ship without Shema rather than
> waiting for it**; the section is built to hold N series, so adding a
> third later is data, not code.
>
> The user accepted the trade explicitly: the P0 text defects are real,
> but they have been wrong in shipped versions for years, and two more
> days will not make them worse.
>
> **When the series section is shipped and deployed, this banner is
> spent — delete it and go back to the order below.**

> ### ⏸ THE TRADITIONAL GLYPH WORK IS DEFERRED TO LAST — user, 2026-08-18
>
> "fantizi 放在最后 do others first".
>
> **Do not take another 繁體 one-to-many / converter-hole item until
> every other actionable item in this file is done** — the rest of P0,
> then P1, then P2. When nothing else is actionable, come back here and
> resume where it left off.
>
> **This overrides the standing "scripture accuracy first" rule for
> this class only, at the request of the person who set that rule.**
> Everything else keeps its priority: a verse that renders blank, a
> citation that opens the wrong passage, an interface naming one
> translation while showing another — those are still P0 and still lead.
>
> **Why they asked, and it is a fair call.** The class has not been
> converging: P0 went from 12 items to 22 in a day, because each glyph
> fixed reveals two more, and nobody — including this loop — can say
> how many classes remain. It is real work on real defects, but it was
> crowding out everything the user actually reports from their phone.
>
> **What is already done stays done.** 隻 髮 恆 凌 症 卜 干/乾 崙 鹹
> 姪 鹼 and the rest are shipped and pinned by tests; this is a pause on
> continuing, not a revert.
>
> **Resume trigger:** the user says so, or the queue has nothing else
> actionable. If you reach the second case, say so plainly in the
> report rather than quietly restarting the glyph work.

- [x] **Characters were silently MISSING from verses — 士師記 12:13 read
      「作以色的士師」 for 以色列. 15 verses restored, in all three assets.**
      Found 2026-08-19 by the refuter while it was trying to break the `??`
      claim below, which is the best possible provenance for it: it went
      looking for evidence that this corpus loses characters, and found some.

      **Measured before concluding, as the standing rule says.** Every verse
      aligned against both witnesses on CJK ideographs only, so punctuation
      and spacing never register: 31,102 verses, **31** where both witnesses
      read more than we do. Not the 14 the refuter guessed, and it was right
      not to be quoted. Reading all 31 individually split them three ways —
      **15 real losses, 9 transpositions** (the characters are all there, in
      the wrong order — filed as its own item below), **7 explained**
      (verse-boundary placement of a trailing 說, note-marker restructuring,
      and two edition variants). `tools/audit_dropped_characters.py` carries
      the triage and now fails only on hits it has never seen.

      **The 15, each one or two characters short in BOTH editions:**
      創 45:1 弟兄**們** · 創 45:15 弟兄**們** · 創 50:11 一場**極**大的哀哭 ·
      出 15:7 像燒碎**秸** · 士 12:13 以色**列** · 詩 59:12 **因**他們口中 ·
      詩 78:44 河**汊** · 詩 102:26 就**都**改變了 · 亞 11:15 愚昧**牧**人 ·
      可 11:17 教訓**他們**說 · 徒 26:29 是少**勸**是多勸 · 徒 27:44
      **零碎**東西 · 林後 10:9 免得**你們**以為 · 林後 12:17 他**們**一個人 ·
      來 2:2 **干**犯悖逆.

      **Restoring is the dangerous direction, so it took four lines of
      evidence, not two.** The two witnesses (blob `7a2dc43` and the
      independent Simplified import) disagree with EACH OTHER in 5,338 of
      31,101 verses, so their agreeing means something — but not enough. The
      refuter added the **Wikisource transcription of the printed 1919 text**
      and the **import module's own Strong's tags**, which outlived the
      characters they were attached to and point straight at the gaps:
      以色`<WH3478>` is tagged *Israel*, 燒碎`<WH7179>` *stubble*,
      愚昧人`<WH7462x>` *shepherd*. A word cannot be tagged with a Strong's
      number it no longer spells.

      **The refuter earned its keep again — it broke 2 of the 17 proposed.**
      創 39:22「都交在約瑟手下」 and 創 41:30「甚至埃及地都忘了」 look
      identical to the rest, and both witnesses read longer (約瑟**的**手下,
      甚至**在**埃及地). The printed 1919 reads exactly as ours, and the
      module's tagging shows no gap (約瑟`<WH3130>`手下`<WH3027>`). Both
      witnesses descend from a later revision at those two points. **Two
      witnesses agreeing is not proof when they share an ancestor** — that is
      the lesson, and it is why the third and fourth lines were worth
      getting. Both are pinned in the test as verses that must stay SHORT.

      **The word-tap corpus had the same 15 losses** and renders its own copy
      of the verse, so 「作以色」 was on screen there too. Repaired in the same
      pass, which put `tagged_verse_coverage_test` back to 236 instead of
      forcing its bound up to 241. There, the Strong's tag decided where each
      character goes — better placement evidence than the running text.

      Not part of the deferred 繁體 glyph class: the loss is upstream of the
      Traditional conversion and of this repo — it is already in the MySword
      module the corpus was imported from. `tools/repair_dropped_characters.py`
      (re-runnable, idempotent); `test/dropped_characters_test.dart` fails on
      the pre-fix data. 干 counts in `traditional_dry_glyph_test` moved 111 →
      112 because 來 2:2 got its 干犯 back.

- [x] **Nine verses have the right characters in the WRONG ORDER — eight were
      real and are now reordered.** Done 2026-08-19. 箴言 22:11 no longer reads
      「王必與他為上友」, 尼希米記 8:4 no longer strands 站 in front of a list of
      names, and 馬太福音 25:20 now reads the same way in all three of our
      files instead of three different ways.

      **The printed 1919 text decided two the witnesses could not.** 馬太福音
      6:2 and 使徒行傳 24:16 are both ordinary Chinese in either order, and our
      own corpus argued for keeping ours: 26 of the 42 tagged runs carrying
      ἔμπροσθεν spell it 面前 against 2 for 前面, and 因此我 outnumbers 我因此
      25 to 1. The print reads 「不可在你前面吹號」 and 「我因此自己勉勵」.
      Neither would have been safe on the two witnesses alone.

      **Internal evidence turned out to be the strongest line for three of
      them**, because it is independent of all three external witnesses:
      俄巴底亞書 1:5's parallel 耶利米書 49:9 already reads 「若來到」 in our own
      asset; our Traditional file already had 馬太福音 25:20 right while the
      Simplified read 五千的 and the tagged corpus read 五的千 — one clause,
      three of our files, three orders; and 尼希米記 8:4's own second half
      reads 「和米書蘭站在他的左邊」.

      **The refuter broke the first version of the fix, on a defect that would
      never have shown on screen.** The repair rebuilt tagged runs from text
      and Strong's number alone, so four verses came out with the right
      characters and their parsing data silently gone — 創世記 9:11 lost the
      infinitive-construct code off its verb, 馬太福音 25:20 lost τάλαντον,
      使徒行傳 24:16 lost τούτῳ, 俄巴底亞書 1:5 lost a perfect-tense code. The
      tool now inherits every field from the input run and refuses to split a
      run that carries `i`/`g`, which would claim the original has a word
      twice. `tools/repair_transposed_characters.py`;
      `test/transposed_characters_test.dart` fails on the pre-fix data.

      | ref | was | now reads |
      |---|---|---|
      | 創 9:11 | 毀壞**了地** | 毀壞**地了** |
      | 尼 8:4 | 木臺上。**站**瑪他提雅…和瑪西雅**在**他的右邊 | 瑪他提雅…和瑪西雅**站在**他的右邊 |
      | 箴 22:11 | 因他嘴的恩言，王必與他為**上**友 | 因他嘴**上**的恩言，王必與他為友 |
      | 俄 1:5 | 摘葡萄的若**到來**你那裏 | 若**來到**你那裏 |
      | 太 6:2 | 不可在你**面前**吹號 | 在你**前面**吹號 |
      | 太 25:20 | 那另外**五千的**來 | 那另外**的五千**來 |
      | 徒 24:16 | **因此我**自己勉勵 | **我因此**自己勉勵 |
      | 羅 4:23 | 「算為他**的義**」這句話 | 「算為他**義**」**的**這句話 |

      **耶利米書 7:14 was the ninth and stayed as it was.** Ours reads
      稱**我為**名下 where both witnesses read 稱**為我**名下, and the printed
      1919 sides with **ours**. Do not "fix" it; it is recorded in
      `audit_dropped_characters.py` with the other explained hits. The eight
      that were fixed are struck from that list on purpose — if a re-import
      scrambles them again, the run should report them as new drift.

      **The print is a witness, not an oracle.** The refuter found the
      Wikisource transcription has defects of its own where all three other
      sources agree against it — it drops 的隱密處 at 俄巴底亞書 1:6 and 金 at
      箴言 1:9. It was decisive here because its errors are uncorrelated with
      the two imports', not because it is always right.

- [x] **NOTHING HAD EVER CHECKED FOR TEXT WE ADD — now something does, and it
      found two verses printing a word twice.** Done 2026-08-19.
      `tools/audit_inserted_characters.py` is the mirror of the deletion audit
      and the direction that puts words INTO scripture rather than taking them
      out. **419 of 31,102 verses read longer than both witnesses.**

      **387 of the 419 are this edition's own editorial apparatus** — `<note:…>`
      markers, `主[雅偉]` bracket glosses, `（原文是…）` parentheses — which the
      witnesses simply do not carry. The audit separates them mechanically by
      masking apparatus regions, so they never have to be read again. **32 are in
      the running text**, and every one was read individually.

      **傳道書 7:1 read 「名譽強如美好的的膏油」** — the particle written twice.
      Repaired in all three assets. It is the only doubled particle in the
      corpus: all 1,749 immediate single-character repetitions across 206
      distinct characters were counted, and every other one is real
      reduplication (大大, 實實在在, 戰戰兢兢) or a name straddling the pair
      (加利利 → 利利, 各各他 → 各各).

      **The refuter earned its keep twice over.** It broke the claim that 的的
      was the only one: **歷代志上 15:3 read 「招聚以色列眾人眾人到耶路撒冷」**,
      a duplicated two-character WORD that a single-character scan cannot see.
      More important than the verse is *why this audit could never have found
      it* — witness A reads 眾人眾人 as well, so the two-witness test is blind to
      anything we inherited from our shared ancestor. It was caught by a third
      witness that is **internal to this repo**: our own tagged corpus holds one
      run `{"w":"以色列众人","s":"H3605"}`, and ויקהל דויד את־כל־ישראל says "all
      Israel" once. Filed below as its own audit.

      It also broke the reasoning for **which** 的 to drop. The claim was that
      the corpus writes the genitive 的 at the head of the following run; that is
      a 20,060/11,649 tendency, not a convention, and 以賽亞書 runs the other way
      (430/914). The token settles it instead: of the 14 places the corpus splits
      a run at 美好, **12 keep 美好的 together**, including 傳道書 4:9 — same
      book, same lemma H2896. So 的膏油 lost the particle, the opposite of the
      first attempt. `tools/repair_duplicated_particle.py`;
      `test/duplicated_word_test.dart` fails on the pre-fix data.

      **The remaining 26 are NOT repaired and must not be** on the strength of
      two witnesses — 創世記 39:22 and 41:30 are the standing warning. They are
      listed with their exact characters in the audit's `PENDING` dict so it
      stays a working regression detector while they wait, and are filed as the
      item below.

- [ ] **26 running-text insertions await the printed 1919 — including
      尼希米記 1:2's 「我問他們關於…和關於耶路撒冷」.** Enumerated in the
      `PENDING` dict of `tools/audit_inserted_characters.py`, each with the
      exact characters we add and the witnesses' reading.

      **Do not fix them one at a time until the clustering is explained.**
      14 of the 26 sit in just two books — 使徒行傳 (6) and 哥林多後書 (8) —
      which is far more concentrated than 31,102 verses spread over 66 books
      would give by chance. Several also look like a systematically *later*
      revision rather than a slip: 「就開始控告他說」 for 「就告他說」,
      「所需用的東西」 for 「所需用的」, 「發見你們」 for 「見你們」,
      「也沒有缺少」 for 「也沒有缺」. A whole-book source difference and 26
      independent typos need different fixes, and guessing wrong writes into
      scripture. Settle the source question first, then the printed 1919 per
      verse.

- [ ] **Audit the running text against our OWN tagged corpus — a third witness
      nothing has ever consulted.** `assets/tagged/cuvs-yhwh/` stores each verse
      as runs whose `w` fields concatenate back to the verse, so it is an
      independent copy of the text sitting inside this repo — and it is
      independent in exactly the way the external witnesses are not, because it
      does not share their ancestor.

      This is not speculative: it is the only thing that caught 歷代志上 15:3,
      where witness A carries the same defect we do. A first pass by the refuter
      on 2026-08-19, normalising punctuation and note markers, found **exactly
      one** repetition-shaped disagreement (15:3, now repaired) — but it was
      looking only for repetitions. The general diff has never been run.

      Expect noise: the tagged corpus omits some punctuation and restructures
      around note markers, so the comparison needs the same normalisation the
      other audits use before any hit means anything.

- [ ] **那鴻書 3:4 attaches the 「原文是賣」 note to the wrong 誘惑.** Ours
      prints 「藉淫行誘惑\<note: 原文是賣\>列國，用邪術誘惑多族」; both
      witnesses and the print put the note on the SECOND one, 「用邪術誘惑
      （原文是賣）多族」. The note is telling the reader which Hebrew word
      underlies which Chinese word, so on the wrong verb it states something
      untrue about the text. Found 2026-08-19 in the dropped-character pass.

- [ ] **哥林多後書 13:5 reads 在你們裏面 where the print reads 在你們心裏.**
      Not a dropped character — a substitution, which is why it was kept out
      of the restoration above. Both witnesses and the printed 1919 read
      心裏. Small, but it is the difference between "among you" and "in your
      hearts". Found 2026-08-19; needs the same four-witness check the 15 got
      before anything is written.

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

- [x] **The Traditional Bible misspelt Hebron in 69 verses — 崙 was written 侖
      in all 155 places a NAME needed it. DONE 2026-08-18, 243 substitutions
      (155 verses + 88 lexicon).** The sixteenth converter hole, and the first
      one to reach a proper name rather than a common noun.

      `assets/section_titles.json` headed 撒母耳記下 2 with 「大衛在希伯崙作
      猶大王」 and the verse under it read 希伯侖. Same screen, two spellings.

      The enumeration, by longest match — 希伯崙 69, 希斯崙 17, 伯和崙 15,
      以弗崙 13, 沙崙 9 standalone + 拉沙崙 1, 亞雅崙 9, 伸崙 7, 耶書崙 4,
      米崙 2, 米磯崙 2, and one each of 西斐崙, 基撒崙, 施基崙, 哈崙, 何崙,
      希崙, 義伯崙 = **155**. Derive this by tokenising the positions, never by
      summing a list of names: the first pass missed 義伯崙 (書 19:28) entirely
      and double-counted 拉沙崙 (書 12:18) inside 沙崙, two errors that
      cancelled to the right total and hid each other.

      **This item had to overturn a caution already in this file.** Line ~695
      warns that 「侖/崙, 瑪/馬, 毗/毘 are transliteration conventions this
      edition is entitled to」 — a witness difference here need not be a defect.
      That is right about 瑪利亞/馬利亞, where published editions genuinely
      differ and each is consistent with itself. It is wrong here, and opencc
      says why in one line:

          $ echo 希伯仑 亚雅仑 耶书仑 希斯仑 沙仑 加仑 昆仑 | opencc -c s2t
            希伯侖 亞雅侖 耶書侖 希斯崙 沙崙 加侖 崑崙

      Simplified merges 侖 and 崙 onto 仑; opencc's default single-char mapping
      is 侖 and its phrase table knows 希斯崙 and 沙崙 but not 希伯崙. So it
      writes two names right and three wrong in one sentence — and
      `assets/strongs/hebrew.json` reproduced that split exactly (希斯崙 ×35
      right, 希伯侖 ×63 wrong). No editor produces that; a phrase-table
      converter produces it every time. The verse asset shows the same hand
      with no phrase table at all: 155 侖, 0 崙. **The disagreement is between
      our machine-converted assets and our authored ones, which is a defect.**
      Generalise the test, not the verdict: for any 侖/崙-shaped pair, ask
      whether the two forms are inconsistent WITHIN our own converted file.

      Four independent lines of evidence, all agreeing:
      * Witness `7a2dc43`: 155 崙, 0 侖. Counts match verse by verse — but
        counts cannot exclude a transposition, so the tool also compares the
        three Han characters left of each glyph in order, after normalising
        three known edition differences (note spans, interpuncts, 耶和華/雅偉).
        All 155 agree. Proved to have teeth: it rejects a transposition of
        伸崙/米崙 at 書 12:20 and rejects 希伯崙→希弗崙.
      * Published 新標點和合本 (ebible `cmn-cu89t`): 158 崙, **0** 侖,
        希伯崙 ×69 — our count exactly. The gap of 3 was read verse by verse
        and is edition normalisation, not a defect (below).
      * **Four** authored Traditional assets — `section_titles.json`,
        `maps_index.json`, `family_tree.json`, `songs.json` — 崙 throughout,
        no name-侖. An earlier draft said five and counted 梁家鏗's
        `biblexg-v2-tr.json`; the refuter broke that. It writes 崙 ×3 but also
        one 希斯**侖** (路 3:33), so it is a witness against itself and
        corroborates only weakly. **It is also shipped and user-selectable**
        (`pubspec.yaml`, `lib/constants/bible_versions.dart`), so the app does
        NOT now show zero name-侖 — that is true only of the assets that are
        ours to edit. See the 愈/癒 spin-off item for the same call.
      * **The best one, and the only one that survives the witness blob being
        dropped from the tree:** the Simplified source `assets/cuvs-yhwh.json`
        distinguishes 仑 from 伦 perfectly (155 仑 / 853 伦), and after the fix
        its per-verse 仑/伦 counts match the Traditional's 崙/倫 on **all
        31,102 verses, zero mismatches**. Prefer this shape of check in future
        instalments — it needs no external file.

      **The base text's own inconsistency is preserved, NOT normalised.**
      和合本 itself spells 希斯倫 at 創 46:12 and 民 26:21 and 亞雅倫 at
      士 1:35, where 新標點 sets 崙 — and conversely 新標點 has 希斯倫 at
      出 6:14 where 和合本 has 崙. Ours agrees with witness `7a2dc43` at all of
      them and still holds 853 倫. Fixing a converter hole is not a licence to
      edit the base text.

      Scope notes: `assets/strongs/greek.json` was a false alarm and received
      **no change** — all six of its 侖 are 加侖, a gallon, and it already spelt
      希斯崙 right. `hebrew.json` is a split, not a partition, so it was fixed
      by named reading with the 2 gallons pinned as must-survive.

      `tools/repair_tr_ridge_glyph.py` (idempotent, refuses on any drift),
      `test/traditional_ridge_glyph_test.dart` (8 tests, 6 of which fail on the
      pre-fix data).

- [x] **書 10:3 spelt Hoham 何鹹 — "salty" — where every witness reads 何咸.
      DONE 2026-08-18, 1 substitution.** The seventeenth converter hole, the
      smallest so far, and the second to reach a proper NAME. opencc's default
      mapping is 咸 → 鹹 (`echo 何咸 咸信 | opencc -c s2t` → 何鹹 咸信 — its
      phrase table knows the word 咸信 and does not know the name), and 咸 in a
      name must stay 咸, so the converter salted a Canaanite king.

      Ours was 7 鹹 / **0** 咸. Witness `7a2dc43`: 6 鹹 / **1** 咸 — and the one
      咸 is 何咸 at 書 10:3. Published `cmn-cu89t` agrees exactly, same seven
      verses: 「希伯崙王何咸、耶末王毗蘭」. The other six are genuine salt and
      all six survive — 採鹹草, 使鹹地, 叫它再鹹呢 ×3, 鹹水.

      **A split, not a partition** (the witness holds both forms), so it was
      decided at the one position, not swept — and it is the one instalment
      where **the Simplified twin cannot arbitrate**. The 崙 fix leaned hardest
      on that check because 仑/伦 stay distinct in Simplified; 咸 is the
      opposite case — the merge is on the Simplified side, so our source reads
      咸 at all seven positions and cannot tell them apart. Evidence had to be
      external, and two independently produced Traditional editions supplied it.

      Checked and deliberately NOT touched: `assets/strongs/hebrew.json` and
      `greek.json` came through a different pipeline and are **already right on
      both readings** (H3458 咸信, H4420 鹹性, G252 鹹的) — a sweep would have
      broken 咸信. H1944, Hoham's own entry, never spells his name in Chinese.
      `assets/sermons/zh-TW/018.txt` greps as 何鹹 and is a **false positive**:
      「不再有任何鹹味」, 任何 + 鹹味.

      `tools/repair_tr_salt_glyph.py` (idempotent, refuses on any drift),
      `test/traditional_salt_glyph_test.dart` (6 tests, 2 of which fail on the
      pre-fix data; the last one pins the Simplified merge so the reason the
      internal check is unavailable stays recorded in code).

- [ ] **The inventory diff has a TAIL the table below never enumerated — it was
      cut off at 10 occurrences, and 咸 was hiding under it.** The two
      candidates below are **DONE 2026-08-18** (11 verses + 21 lexicon fields),
      and **the reverse sweep at the end of this entry is now DONE too
      (2026-08-18)** — see the entry immediately below, which is what it found.
      What is left open here is only the 蹟/鍊 correction. Measured
      2026-08-18 while fixing 書 10:3. The full diff — every character the
      witness `7a2dc43` uses that our asset holds **zero** of — is **109
      characters**, not the 25 the table lists. 咸 sat at the very bottom with a
      count of 1, which is exactly why it was found by hand rather than by the
      sweep.

      **Most of the tail is NOT a defect, and an earlier draft of this entry got
      that wrong** — it listed 蹟 95, 鍊 62, 歎 52, 祕 51, 甦 7 as "certainly
      holes" on the strength of the zero-count signature alone, and checking
      them broke that. The signature is necessary, not sufficient: it fires just
      as loudly when **both forms are valid Traditional and the two editions
      simply chose differently**, which is what these are —

      | | ours | witness | verdict |
      |---|---|---|---|
      | 歎/嘆 | 0 歎, 53 嘆 | 52 歎, 0 嘆 | both valid; 嘆 is the Taiwan standard |
      | 祕/秘 | 0 祕, 51 秘 | 51 祕, 0 秘 | both valid — and cmn-cu89t itself MIXES (48 祕 + 3 秘), which settles it |
      | ~~蹟/跡~~ | 0 蹟, 103 跡 | 95 蹟, 8 跡 | **this verdict was WRONG — see below** |
      | ~~鍊/鏈~~ | 0 鍊, 60 鏈 | 62 鍊, 1 鏈 | **this verdict was WRONG — see below** |
      | 甦/蘇 | 0 甦, 44 蘇 | 7 甦, 37 蘇 | both valid |
      | 裡/裏, 麼/麽, 牠/它, 毘/毗 | | | long-settled conventions, already known |

      **蹟/跡 and 鍊/鏈 are NOT edition preferences — the refuter broke that on
      2026-08-18, and the corrected reading matters.** BOTH witnesses (blob
      `7a2dc43` and the published cmn-cu89t) read 95 蹟 / 8 跡 and 62 鍊 / 1 鏈,
      i.e. they actively DISTINGUISH 神蹟 from 痕跡/蹤跡/筆跡, and 金鍊/鐵鍊/
      鎖鍊 from a 鏈. Ours reads 103 跡 / 0 蹟 and 60 鏈 / 0 鍊 — **the same
      one-to-many collapse as every fixed instalment**, not two editions
      choosing differently.

      They are still deliberately NOT swept, but for a narrower reason than the
      table gave: 跡 and 鏈 are standard Traditional spellings that read
      correctly, so nothing false is printed today. Restoring the distinction is
      an improvement to ask the user for (~165 positions), not a scripture
      defect to fix unattended. `test/traditional_tail_glyphs_test.dart` pins
      all four counts so a later sweep cannot do it silently.

      **Two in the tail WERE candidates, and both are now DONE (2026-08-18 —
      11 verses + 21 lexicon fields, `tools/repair_tr_tail_glyphs.py`,
      `test/traditional_tail_glyphs_test.dart`).** Eighteenth instalment:

      * ~~**鹼/堿, 6 positions.**~~ **DONE.** Ours read 堿 at 伯 9:30
        「用堿潔淨我的手」, 詩 107:34 「使肥地變為堿地」, 箴 25:20 「如堿上倒醋」,
        耶 2:22, 耶 17:6, 瑪 3:2.
      * ~~**姪/侄, 5 positions.**~~ **DONE** — 創 12:5, 14:12, 14:14, 14:16
        (「亞伯蘭的姪兒羅得」 — Lot) and 代下 22:8 — **plus 21 more in the
        Strong's lexicon**, 19 in `hebrew.json` and 2 in `greek.json`, every one
        侄子/侄女 (Lot H3876/G3091, Bethuel H1328, Iscah H3252, Jonadab H3082/
        H3122, Jonathan H3083). Left alone, a reader tapping 羅得 on the
        Originals sheet would have been shown a spelling the verse beside it no
        longer uses.

      **The discriminator this instalment had to get right**, because the
      partition alone does NOT separate these two from 蹟/鍊 above: no published
      Traditional 和合本 sets 堿 or 侄 at these eleven verses — two independent
      Traditional editions agree against ours alone — whereas 跡 and 鏈 are what
      other published editions legitimately set. And the thing NOT to claim:
      **堿 and 侄 are not Simplified-only glyphs.** Both encode in Big5 and the
      MOE 異體字字典 lists 堿 under 鹼. An earlier draft of the fix asserted "a
      form no Traditional standard sets" and that assertion was itself wrong.

      Also newly recorded: the converter's fingerprint differs between the two.
      Our Simplified reads 碱 at all six alkali positions, so there it DID
      rewrite the character (碱 → 堿); it reads 侄 at all five nephew positions,
      so there it did nothing at all — opencc has no 侄↔姪 mapping in any
      direction (s2t, s2twp, t2tw, t2hk, t2s, tw2s all checked). The nephew is
      therefore the first instalment with **no converter oracle**, resting on
      the two Bible witnesses plus the repo's own hand-authored
      `assets/family_tree.json`, which has always written 姪子.

      And the harder half: the 癒 lesson says a merged pair only shows in this
      diff when the surviving form is the one we lack. **咸 was the mirror
      case, caught only because a name looked wrong.** The sweep in the other
      direction — characters the *witness* holds zero of — **was run
      2026-08-18** and found a defect family nobody suspected. See below.

- [x] **The reverse inventory sweep found a SECOND defect family: 16
      transcription errors that are wrong in the Simplified asset too. DONE
      2026-08-18.** Eighteen instalments had all been converter holes, so every
      one of them used the Simplified twin as the oracle. That method is blind
      by construction to a defect the converter did not cause — and there were
      sixteen sitting in the base e-text the whole time.

      The reverse diff (characters WE hold that the witness holds zero of)
      returns 70 characters. Most is edition preference: ours keeps the older
      和合本 spellings — 豫備, 儆醒, 沈睡, 擡, 誌, 禦, 輥, 號啕 — where the
      witness modernises them. Those are correct and were left alone. But at
      counts of one and two it surfaced characters that are not a variant of
      anything: **恉, 犰, 菏, 菇, 饃**.

      | ref | printed | should read |
      |---|---|---|
      | 士 4:18 | 雅**憶**用被將他遮蓋 | 雅**億** — Jael, and the same verse's first clause already said 雅億 |
      | 士 15:16 | 我用驢**恉**骨殺人成堆，用驢**腮**骨殺了一千人 | 腮骨 — the right word and a non-word for the same jawbone, one sentence apart |
      | 士 15:17 | 那**恉**骨 | 那腮骨 |
      | 士 20:6 | 行了**扔菏**醜惡的事 | 兇淫醜惡 |
      | 撒下 14:25 | 毫無**暇**疵 | 毫無瑕疵 |
      | 王上 2:1 | 就囑**吩**他兒子所羅門 | 囑咐 |
      | 王上 14:5 | 你當**此此**如此告訴她 | 如此如此 |
      | 代上 11:12 | 亞合人**犰**多 | 朵多 — Dodo |
      | 詩 80:15, 80:17 | 你為自**已**所堅固的 | 自己 |
      | 耶 12:14 | 所承**巡菇**業的 | 所承受產業 |
      | 可 15:25 | 是**已**初的時候 | 巳初 |
      | 路 2:24 | 一對**班**鳩 | 斑鳩 |
      | 徒 24:1, 24:2 | 辯士帖**士**羅 | 帖土羅 — Tertullus, wrong at both his occurrences |
      | 林前 13:12 | **饃**糊不清 | 模糊不清 |

      Plus one that exists only in the tagged corpus: **王上 14:5 read
      「告她诉」** there, a transposition the verse asset never had.

      **The provenance claim in the first draft was WRONG and the refuter broke
      it.** It said our asset alone carried these. BibleHub's published CUV
      reproduces thirteen verbatim. They are transcription errors in the shared
      *digital* CUV lineage that most Chinese Bible software imported, not
      readings of the printed 和合本 — which is what makes fixing them a
      restoration rather than an emendation, and is the version of the story
      that should be repeated.

      What actually carries the weight is the **corpus ratio**, which needs no
      outside source: our own text spells every one of these words correctly
      elsewhere — 囑咐 74:1, 自己 1509:2, 斑鳩 14:1, 雅億 11:1, 如此如此 17:1,
      瑕疵 9:1, 朵多 4:1, 腮骨 4:2, 巳初 2:1.

      Two things the refuter corrected that are worth not re-learning: the
      Strong's-tagged corpus is **not** an independent witness (it shares 13 of
      the 16 and has one error of its own), and neither is `cuvs-plus.json` —
      it is a *partially repaired* branch of the same lineage, right at 13,
      still wrong at 雅忆, 馍糊 and 帖士罗 at 徒 24:2 while having fixed 24:1.

      `tools/repair_cuv_typo_corruptions.py` (idempotent, refuses on drift and
      refuses any tagged replacement that would span tokens and move the
      Strong's alignment), `test/cuv_typo_corruptions_test.dart` (13 tests, 8
      of which fail on the pre-fix data).

- [ ] **創 45:10 「你和你我兒子孫子」 — needs the user, do NOT fix unattended.**
      It was in the first draft of the instalment above and was pulled out.
      Both witnesses read 你**的**兒子, and 你我 is ungrammatical — but the
      refuter found that Wikisource's transcription of the printed 1919 和合本
      reads 你我 there as well. If the printed text says it, changing it is an
      emendation of the CUV, which is the user's call and not ours. Pinned by
      the test so it cannot be swept by accident.

- [ ] **Our Traditional corpus holds 47 兇 and zero 凶, where the printed CUV
      uses 凶 — a likely systematic over-conversion, ~47 positions.** Found by
      the refuter while checking 士 20:6. The Traditional witness splits 11 兇
      / 37 凶, and Wikisource's CUV books show 凶 25× and 兇 0×. Nothing false
      is printed — 兇 is a legitimate Traditional character and reads correctly
      — so this is an edition-consistency improvement, not a scripture defect,
      and 士 20:6 was written 兇淫 to stay consistent with the corpus we
      actually have. Ask the user before flipping 47 positions.

- [x] **代上 3:20 spelt Jushab-hesed 於沙希悉; it now reads 于沙希悉. The
      nineteenth converter hole, and the second one to reach a NAME. DONE
      2026-08-18, one substitution** (`tools/repair_tr_jushab_hesed.py`,
      `test/traditional_jushab_hesed_test.dart` — 3 tests fail on the pre-fix
      data). Found alongside the transcription-error instalment above but
      deliberately not mixed into it: different family, different mechanism.

      **The mechanism as first written was WRONG, and the refuter broke it.**
      This entry used to say "opencc rewrote that 于 to 於". These assets were
      never produced by opencc — `tools/fix_traditional_conversion.py` had
      already established that (opencc disagrees with them in ~46% of verses,
      and gets 船隻 *right* where this corpus got it wrong). `echo 于沙希悉 |
      opencc -c s2t` printing 於沙希悉 shows only that a naive expansion makes
      this mistake; it is not evidence of provenance. What is: **our Simplified
      holds 1,388 于 / 0 於 and our Traditional held 1,388 於 / 0 于** — an
      unconditional 1:1 map, blind by construction to the one position in
      31,102 verses where the syllable is a name. Right 1,387 times, wrong once.

      **What each witness actually proves**, because the first draft over-claimed
      here too. The Simplified sources are logically NULL on 于-versus-於 —
      Simplified merged the two and cannot distinguish them. They are cited for
      the thing they do settle, which is the load-bearing one: the tagged corpus
      tags 「于沙希悉，」 as **H3142**, יוּשַׁב חֶסֶד, so the string is a NAME and
      not a clause containing a preposition. Which Traditional character it takes
      rests on the two Traditional witnesses — blob `7a2dc43` and published
      `cmn-cu89t`, each holding **exactly one 于 in the whole Bible, this name** —
      and those two are **one textual family, not two independent lines**: both
      set the 新標點 separator 于沙‧希悉, which ours does not. So the honest claim
      is "no published Traditional CUV available here spells it 於", not "two
      unrelated editions agree".

      Still decisive, because 於 in modern Traditional is essentially only the
      preposition: 於沙希悉 spells a man's name with a grammatical particle. That
      is exactly the distinction that keeps 蹟/跡 and 鍊/鏈 unswept above — there
      our spelling is one a published edition legitimately sets; here it is not.

      **The fix is complete.** A full per-verse 于/於 sequence diff against the
      witness returns two disagreements: this one, and 尼 1:2, where our edition
      reads 「關於那些…和關於耶路撒冷」 against the witness's shorter clause with
      no 關於 at all — a wording difference, not a character choice, and our own
      Simplified twin reads 关于 in both places. Pinned by the test so a later 于
      sweep cannot mistake it for a second instance.

- [ ] **"The Traditional side was produced by opencc" is asserted about the
      STRONG'S LEXICON and has never been checked.** Found 2026-08-18 by the
      refuter while it was breaking the same claim about the verse assets.
      `tools/repair_tr_tail_glyphs.py:72` states it as fact, and the 姪 lexicon
      repair reasoned from it ("opencc has no 侄 → 姪 mapping, so all 21 came
      through untouched"). For the VERSE assets the claim is now known false —
      they were made by a naive per-character map — but `assets/strongs/*.json`
      are different files with possibly different provenance, so the lexicon
      claim is neither confirmed nor refuted.

      It is cheap to settle with the same method that settled the verses: run
      `opencc -c s2t` over every `*Zh` field and measure what fraction of the
      `*ZhTw` fields it reproduces exactly. ~46% disagreement means a naive map;
      near-total agreement means opencc. **Nothing false is printed either way**
      — the 姪 repair was confirmed field-by-field against the Simplified twin,
      not on the provenance argument — so this is about not reasoning from an
      unverified premise in the NEXT lexicon instalment.

      **Partial evidence arrived 2026-08-18 from the 制/製 instalment, and it
      points away from "same map as the verses".** Where the verse asset held
      157 製 / ZERO 制, the lexicon's `*ZhTw` fields already distinguish the
      pair correctly — 製造/製作/銅製的/皮製的/木製品 against 節制/限制/抑制/
      轄制/受制於/壓制. A file produced by the map that broke the verses could
      not have written a single 制. So the lexicon was made by something else,
      and whatever that was, it is not hole-free either: its Traditional fields
      are internally inconsistent in the *other* direction (金制飾, 麻制的,
      布制的, 毛制的 sit beside 銅製的 and 皮製的). Still does not settle
      whether that something was opencc; the measurement described above is
      still the way to find out.

- [ ] **Eleven word-level differences where our reading is a real word — needs
      a third witness or the user.** Both witnesses disagree with us and
      nothing false is printed today, so these were not swept: 意料/**逆料**
      (賽 64:3, 徒 25:18 — the refuter confirmed the printed CUV reads 逆料, so
      these two are the most likely to be genuine), 留/等 (徒 27:31),
      消息/信息 (徒 28:15), **異象/顯現** (林後 12:1 — theologically loaded),
      銷滅/消滅 (帖前 5:19), 開始/下手 (林後 8:10), 對/愛 (林後 7:15), 在/了
      (林後 5:19), 歸到/歸他 (創 49:33), and 徒 28:6 and 28:17 where our whole
      clause differs from both witnesses. The measurement is reproducible: a
      three-way diff of `cuvs-yhwh-tr.json` against blob `7a2dc43` and
      SeekSparks' `cuvs-plus.json` yields 53 substitution pairs, of which the
      high-count ones are conventions and the tail is this list.

- [x] **自已 → 自己 outside the Bible text — DONE 2026-08-18, 8 substitutions
      across 6 files, and nothing under `assets/` spells 自已 any more.**
      `assets/sermons/zh-CN/021.txt` 「所以我對自已說」 and `029.txt`
      「我真的是在對自已說話」 (+ their zh-TW twins), `assets/strongs/greek.json`
      G3962 「不再害怕自已是罪人」 and `hebrew.json` H2616 「(Hithpael) 對自已仁慈」
      (each in both `defZh` and `defZhTw`). Left out of the instalment above
      because the provenance is different — transcripts and glosses, not
      scripture — so it needed its own evidence rather than that one's.

      **The corpus settles it with no outside source.** 自已 is not a word: 已 is
      the adverb "already", the reflexive pronoun is 自己. The zh-CN/zh-TW
      transcripts write 自己 correctly 10,875 times against these 4, the two
      offending files 39 and 26 times each; `greek.json` is 210:2 and
      `hebrew.json` 454:2. Both glosses are **inherited, not introduced here** —
      the upstream CBOL source carries the identical typo at Greek 03962 and
      Hebrew 02616.

      **The trap, and why the script is anchored rather than global.** A blanket
      自已 → 自己 over that same upstream lexicon would corrupt **21** correct
      strings: CBOL's etymology formula 「源自已不使用的字根」 is 源自 + 已不使用
      and entirely right (4 in `cbol-greek.json`, 17 in `cbol-hebrew.json`).
      Those fields were never imported — our `assets/strongs/*.json` hold zero
      源自已 **and** zero over-corrected 源自己 — but the next regex over the
      lexicon will meet them.

      **The refuter broke a number and corrected another**, both fixed before
      commit: the ratio was stated as "the sermon corpus" when 10,875 is the
      zh-CN + zh-TW subtotal (the glob also picks up 58 in `assets/sermons/en/`),
      and one of the 4 Greek etymology hits is 源自已**廢棄不用** rather than the
      quoted 已不使用. It also re-ran the sibling scan independently: 己经/知已/
      而己/律已/正已/利已/舍已/修已/為已 and the 9 巳 are all boundary false
      positives (自己经历, 誰知已經, 假先知已經, 希律已經, 巳初), so this family
      is now closed in `assets/`.

      `tools/repair_ziji_typo.py` (idempotent, refuses on any drift);
      `test/ziji_typo_test.dart` pins zero 自已 anywhere under `assets/sermons`
      and `assets/strongs`, the four repaired readings, and — the guard that
      matters — that 「是已與自己和好」 three characters later in the SAME gloss
      still reads 已. Verified to fail on the pre-fix data.

      Noted while measuring, not a task: `build-cn/` and `build-wasm/` still
      hold pre-repair copies of `cuvs-yhwh*.json` and `tagged/cuvs-yhwh/psalms.json`
      carrying this and the earlier typo family. Gitignored build output, so a
      rebuild clears them — but never deploy from a stale one.

- [ ] **SeekSparks' copy of `cuvs-yhwh-tr.json` still carries this whole defect
      family.** Noted by the refuter 2026-08-18: that repo's asset still reads
      何鹹 *and* 希伯侖, i.e. it is the pre-repair converted file. It is
      **read-only from here** (it has its own hourly loop, writing collides), so
      this is a note, not a task: either that loop replays the same seventeen
      instalments, or someone copies the repaired assets across once. Worth
      raising with the user rather than deciding unilaterally.

- [ ] **Two 愈/癒 spin-offs the refuter found, deliberately NOT swept with the
      verse asset on 2026-08-18 — neither is converter-backed.** Small, and each
      needs a judgement the 35-substitution instalment did not.

      1. `assets/strongs/hebrew.json` **H6867** — `glossZhTw` and `defZhTw` read
         「痂, 傷愈的疤」 where the Traditional should be 傷癒. The evidence is
         internal inconsistency: the same file's Traditional fields write 治癒 for
         a different entry. **But opencc does NOT convert 傷愈 → 傷癒** (verified),
         so unlike the verse asset there is no converter oracle behind it and it is
         an editorial call on 2 fields. `greek.json`, `maps_index.json` and the
         tagged corpus are clean; this is the only Traditional 愈 in `hebrew.json`.
      2. `assets/biblexg-v2-tr.json` — 4 Traditional-facing 愈 that are **not**
         痊愈: 治愈 ×2 (路 8:2, in the text and in a note) and 愈合 ×2 (啟 13:3,
         13:12). opencc converts both, and the same file writes 癒 26 times, so it
         is internally inconsistent by the same argument as H6867 — but this is
         **梁家鏗's own translation**, not ours to normalise. The same 4 strings are
         duplicated in `ljk-nt-bible-webapp/public/resources/tw-lk.json` and
         `tw-rev.json`.
      3. Added 2026-08-18, same call, same file: `assets/biblexg-v2-tr.json`
         spells 希斯**侖** once (路 3:33, the genealogy) against its own two
         希斯**崙** (太 1:3) and one 沙崙. Internally inconsistent by exactly
         the argument used for H6867 — and, again, his text and his call, so it
         was left alone when our own 155 were repaired.

      Also recorded: `build-cn/` and `build-wasm/` still hold a stale
      `biblexg-tr.json` (23 愈 / 0 癒) with no source counterpart — gitignored build
      output, so it needs a rebuild rather than an edit, but do not mistake it for a
      live asset.

- [ ] **The one-to-many Simplified leftovers — 24 classes still open, one
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
      | ~~制~~ | ~~90~~ | ~~製~~ | ~~157~~ | ~~67~~ | **DONE 2026-08-18** |
      | ~~恆~~ | ~~79~~ | ~~恒~~ | ~~79~~ | ~~0~~ | **DONE 2026-08-18** |
      | 託 | 73 | 托 | 82 | 9 |
      | 痲 | 65 | 麻 | 237 | 172 |
      | 慾 | 65 | 欲 | 75 | 10 |
      | 飢 | 58 | 饑 | 157 | 99 |
      | 准 | 54 | 準 | 94 | 40 |
      | 捨 | 53 | 舍 | 317 | 264 |
      | 姦 | 46 | 奸 | 107 | 61 |
      | ~~卜~~ | ~~42~~ | ~~蔔~~ | ~~42~~ | ~~0~~ | **DONE 2026-08-18** |
      | ~~凌~~ | ~~37~~ | ~~淩~~ | ~~37~~ | ~~0~~ | **DONE 2026-08-18** |
      | 凶 | 37 | 兇 | 47 | 11 |
      | 佔 | 30 | 占 | 56 | 26 |
      | 颳 | 26 | 刮 | 34 | 8 |
      | ~~症~~ | ~~26~~ | ~~癥~~ | ~~26~~ | ~~0~~ | **DONE 2026-08-18** |
      | ~~冑~~ | ~~26~~ | ~~胄~~ | ~~26~~ | ~~0~~ | **NOT A DEFECT 2026-08-18 — needs the user** |
      | 樑 | 25 | 梁 | 27 | 2 |
      | 繫 | 24 | 系 | 34 | 4 |
      | 籤 | 24 | 簽 | 26 | 2 |
      | 杆 | 21 | 桿 | 26 | 5 |
      | 閒 | 18 | 閑 | 19 | 1 |
      | 扎 | 17 | 紮 | 21 | 4 |
      | 儘 | 16 | 盡 | 407 | 391 |
      | 併 | 12 | 並 | 2144 | 2133 |
      | 鬨 | 10 | 哄 | 49 | 39 |

      **Take the exact partitions first — they are the cheapest instalments
      left and need no judgement at all.** ~~恆/恒 79~~ **DONE**, ~~卜/蔔 42~~ **DONE**,
      ~~凌/淩 37~~ **DONE**, ~~症/癥 26~~ **DONE**, and ~~冑/胄 26~~ each have
      ours-count == witness-count and the witness holding **zero** of our form, so
      they are whole-class 1:1 replacements rather than a split. ~~Next up: 冑/胄 26
      (甲冑 is a helmet, 胄 is a descendant)~~ — **冑/胄 turned out NOT to be a
      converter hole at all; see the block below, it is now the user's call.**
      ~~Next up: 愈/癒 35~~ **DONE 2026-08-18 — see the block below.** A fifth
      partition the refuter turned up that the inventory table above missed, because
      愈 is a real Traditional character in 愈來愈 and so is not a hole by the
      "ours holds zero" test.

      **制/製 is done — 90 substitutions, 2026-08-18. The FIRST of the splits,
      and the widest reader surface of any instalment so far.** Every one of the
      90 was printing a non-word: 加拉太書 5:23 「溫柔、節製」, 彼得後書 1:6
      「加上節製；有了節製」, 創世紀 4:7 「你卻要製伏它」, 出埃及記 1:11
      「派督工的轄製他們」, 加拉太書 5:1 「奴僕的軛挾製」, 彼得前書 2:13
      「人的一切製度」. Simplified merged 製 (manufacture — 製造/製作) onto 制
      (system, statute, restrain, subdue — 制度/節制/轄制/制伏), and the map
      expanded it back unconditionally: ours held 157 製 and **ZERO** 制, our
      Simplified twin 157 制 and **ZERO** 製 in the same places. Right 67 times,
      wrong 90.

      **Not the 蹟/跡 shape.** There both forms are legitimate Traditional
      spellings and two editions merely chose differently, which is why those
      stay unswept. Here 節製 and 轄製 are not variants of anything — no
      orthography and no published edition sets them.

      The 90 are 轄制 33, 制伏 30, 壓制 9, 節制 8, 克制 6, 按制子 2, 挾制 1,
      制度 1; the 67 keeps are exactly 62 製造 + 5 製作 and nothing else.
      **No verse in the corpus holds both readings**, so the two senses never
      had to be told apart inside one sentence (unlike 幹, where 以西結書 19:12
      sets a genuine 幹 four characters from a 乾).

      **The refuter did not break it and made the evidence stronger.** It ran a
      full per-verse join on {book, chapter, verse} across all 31,101 shared
      verses and found **zero** count mismatches on either character — so the
      alignment never had to guess anywhere, and the 7 positions that fell back
      to ordinal matching (民 32:22, 士 16:5/16:6/16:19, 伯 35:9, 哀 1:13,
      但 2:40 — all blocked by *neighbouring* edition differences: 雅偉/耶和華,
      克/剋, `<note: …>`/（…）) are exact rather than merely probable. All 7 were
      also confirmed one by one in the published 新標點 `cmn-cu89t`. It corrected
      one thing worth keeping: **`cmn-cu89t` is not a clean second witness** —
      its 66 製 differs from ours by book (賽 8 vs 6, 何 2 vs 3), all on the
      67-keep side and never among the 90. The load-bearing witness is blob
      `7a2dc43`; the genuinely independent line is 梁家鏗's Traditional NT,
      which distinguishes the pair the same way (60 制 / 6 製, 節制 never 節製).

      **Scope — the verse asset only, and two files deliberately left alone.**
      `assets/strongs/*.json` already distinguish the pair in their `*ZhTw`
      fields (製造/製作/銅製的/皮製的 against 節制/限制/抑制/轄制/受制於), so
      they were **not** produced by this map — which is direct evidence for the
      open provenance question above. `assets/maps_index.json` sets zh-Hant
      「編製的應許之地地圖」, the correct Traditional word for compiling, and
      already writes 制伏 correctly. Both pinned by the test.
      `tools/repair_tr_restraint_glyph.py` (re-runnable, idempotent);
      `test/traditional_restraint_glyph_test.dart` fails four ways on the
      pre-fix data.

      **愈/癒 is done — 35 substitutions, 2026-08-18.** The fifth true partition,
      and every healing in the Traditional Bible was misspelt: 約翰福音 5:6 read
      「你要痊愈嗎？」, 馬可福音 5:34 「你的災病痊愈了」, 利未記 15:13
      「患漏症的人痊愈了」. 癒 is the healing (痊癒/治癒/癒合); the mainland
      standard merged it onto 愈, which in Traditional is only the comparative
      (愈來愈, 愈加, 每況愈下).

      **The lesson is about how it was FOUND, not how it was fixed.** The inventory
      diff that generated the table above lists characters our asset holds **zero**
      of — and 愈/癒 never appeared in it, because we hold 35 愈. The hole ran the
      other way: we held zero 癒. **A merged Simplified pair only shows up in that
      diff when the surviving form is the one we lack.** When the enumerated rows
      run out, the remaining exposure is exactly this shape, so the next sweep
      should diff on characters the *witness* holds zero of as well.

      Ours held 35 愈 and **ZERO** 癒; the witness 35 癒 and **ZERO** 愈, agreeing
      count-for-count on all 31,102 verses with **zero** mismatches, swept in both
      directions. But "the witness holds none of our form" was **not sufficient
      here**, unlike 症 or 凌: 愈 is a live Traditional character, so one 愈來愈
      among the 35 would have made this a split and a blind replace would have
      printed 愈來癒. It isn't — all 35 are preceded by 痊 and by nothing else, and
      the corpus contains no 愈來愈/愈加/愈發/每況愈下 at all. Both facts are
      enforced by the tool and pinned by the test.

      Corroborated by a **published** 新標點和合本 Traditional (ebible `cmn-cu89t`):
      34 癒, **zero** 愈, every one 痊癒, reconciling book for book with our 35 —
      the single difference is 約翰福音 5:4, the bracketed angel-troubling-the-water
      verse, which we carry in 〔〕 and that edition omits. 梁家鏗's independent
      Traditional NT writes 痊癒 in all 26 of its healings. opencc s2t/s2tw/s2twp
      render 痊愈 → 痊癒 while correctly keeping 愈來愈. No published Traditional
      和合本 printing 痊愈 could be found, so unlike 冑/胄 there is no split and no
      question for the user. `tools/repair_tr_recovery_glyph.py` (re-runnable,
      idempotent); `test/traditional_recovery_glyph_test.dart` fails three ways on
      the pre-fix data.

      **The refuter broke two of my claims and both corrections are worth keeping.**
      (1) I was going to write that 新譯本 (blob `57c4686`, 37 痊愈 / zero 癒) is a
      defective conversion to be explained away. It is a conversion, but **新譯本
      genuinely prints 痊愈** in published Traditional e-texts (信望愛 `ncv`,
      cnbible CNV) — it is a different translation with a different house style, and
      it is evidence neither for nor against 和合本. Do not cite it either way.
      (2) My scope claim was too wide — see the two spin-off items below. It also
      noted that `cmn-cu89t` words the comparative 越發 and never 愈發, so its
      zero-愈 does **not** independently prove it would preserve an adverbial 愈;
      that weight rests on our own recount, not on that edition.

      **Scope was narrower than the fix wanted to be.** 愈 is correct elsewhere and a
      sweep would have corrupted it: `assets/misconceptions.json` sets zh-Hant
      「強者愈強、弱者愈弱」 and the zh-TW sermons have 每況愈下 in `CP18.txt`. Both
      are now pinned by the test.

      **冑/胄 is NOT a converter hole — 26 substitutions NOT applied, and the
      decision belongs to the user. 2026-08-18.** The first row of this table to
      fail on inspection, and worth reading before the next instalment, because the
      "ours holds **zero** of the Traditional form" signature fired here for an
      entirely benign reason and would have printed 26 wrong characters.

      All 26 take one reading, **貴胄** — a noble scion. Nothing is a helmet. That
      is the whole of it: 胄 (U+80C4, 肉/月 radical) is the descendant, 冑 (U+5191,
      冂 radical) is the helmet, and **和合本 never says 甲冑** — it renders helmet
      as 盔 (15), 頭盔 (4), 盔甲, 鎧甲 (6) and 頂盔貫甲, with **zero** 甲冑 and zero
      甲胄 in 31,102 verses. So our asset holds no 冑 because the sense that needs
      one never occurs, not because a converter could not produce it. Every other
      row in this table has a hole to undo; this one has nothing to undo.

      **A correct converter agrees with us.** `opencc -c s2t` renders 贵胄 → 貴胄
      and 甲胄 → 甲冑 — it distinguishes the two senses and keeps 胄 for the scion.
      `s2tw` and `s2twp` do the same. Taiwan 教育部《重編國語辭典》heads the entry
      **貴胄**, and 教育部《異體字字典》lists 胄 (35895) and 冑 (3002) as two
      independent 正字, neither a variant of the other, so there is no
      one-to-many expansion here to get wrong. Our Simplified twin writes 胄 26
      times, which is also the only mainland-standard form.

      **But the print tradition is split, and that is why this is not ours to
      settle.** The witness `7a2dc43` sets 貴冑 in all 26, and the refuter
      downloaded an independent published 新標點和合本 (ebible `cmn-cu89t`) which
      also reads **26 冑 / 0 胄**, the same verses — joined by 信望愛 `unv` and
      catholicgallery CUVT. So 貴冑 is a mainstream printed CUV reading and the
      witness is reproducing its edition faithfully, not corrupting it. It is not
      unanimous either: the refuter found Wikisource 和合本 and cnbible's CUV
      setting 貴胄, and 新譯本 `57c4686` is internally inconsistent — 4 貴胄
      (士 5:13, 王上 21:8, 21:11, 尼 2:16) against 1 貴冑 (傳 10:17). 梁家鏗's
      Traditional NT sets 貴冑 at 路 19:12 where its own Simplified sets 贵胄.
      Even 康熙字典 concedes the confusion under 冑: 「冑與胄子之胄不同，經典多混，
      傳寫譌也」.

      **The refuter's real contribution was not breaking the character analysis —
      that survived every attack — but catching that the analysis answers a
      different question than the previous five instalments did.** In 隻, 恆, 卜,
      凌 and 症 the witness, the orthographic standard, opencc and every other
      edition all pointed the same way, so "match the witness" and "match the
      standard" never had to be told apart. Here they diverge for the first time,
      and choosing between them is choosing a contract:

        * **fidelity to the printed 和合本** → apply the 26, print 貴冑;
        * **modern Traditional orthography** → change nothing, ours is right.

      **Do not apply it on an autonomous iteration either way.** Nothing here is
      untrue about scripture — same word, same sound, same meaning, no verse or
      reference affected — so it does not carry the P0 override, and the repo
      already treats edition-fidelity questions as the user's (see "Proofread the
      TRADITIONAL against the printed 註釋本" and the 427 wording differences).
      **The question for the user is in "Blocked on the user".**

      **The lesson generalises, so check the next one:** an inventory diff finds
      characters we lack, and "we lack it" has two causes — the converter could not
      write it, or scripture never needed it. Only the first is a defect. 冑 was the
      last remaining row whose "witness also has" column is 0, so the exposure is
      bounded; the open rows below are all splits, where the witness holding both
      forms already proves the character is in play. For **愈/癒 35**, the next
      instalment, both tests do agree: opencc renders 痊愈 → 痊癒 under s2t, s2tw
      and s2twp, and the queue's own count has the witness at 35 癒 / 0 愈 — so
      unlike 冑 it is a genuine hole. Still cross-check it against a published
      edition before applying, which is the habit this row should leave behind.

      **症/癥 is done — 26 substitutions, 2026-08-18.** The fourth true partition,
      and the same converter accident as 蔔 for 卜: 症 and 癥 are two different
      words sharing one Simplified form, and the table picked the rarer expansion
      everywhere. 症 is the illness (病症, 漏症); 癥 is zhēng, an abdominal mass,
      surviving in modern Traditional essentially only in 癥結 — which scripture
      never says. So the whole of 利未記 15, the chapter on 漏症, read 「人若身患漏癥」,
      and 馬太福音 4:23 had Jesus healing 各樣的病癥.

      Ours held 26 癥 and **ZERO** 症; the witness 26 症 and **ZERO** 癥, agreeing
      count-for-count on all 31,102 verses with **zero** mismatches — the refuter
      swept it in **both** directions (witness→ours as well as ours→witness) so an
      offsetting pair could not hide in a verse ours lacks. The four readings are
      漏癥 ×20 (利未記 ×18, 民數記 5:2, 撒母耳記下 3:29), 病癥 ×4 (申 7:15,
      太 4:23, 9:35, 10:1), 火癥 ×1 (申 28:22), 熱癥 ×1 (哈 3:5). All 26 confirmed
      two-sided against the witness's same-id verse, none one-sided — but the window
      is narrow in seven places and the figure is worthless without it: 19 at ≥3
      characters each side, four 利未記 at 2, and three at **1** (太 4:23, 9:35,
      10:1 all end 各樣的病癥。 so there is nothing to the right but the stop).
      Corroborated by 新譯本 `57c4686` (39 症, zero 癥) and by our own Simplified
      asset and the tagged Strong's corpus, both already 26 症 / zero 癥.
      梁家鏗's Traditional NT gives **no** corroboration and is not claimed as any:
      it holds neither character, wording 各樣的病症 as 各種疾病.
      `tools/repair_tr_ailment_glyph.py` (re-runnable, idempotent) refuses eight
      ways, including refusing outright if the corpus ever contains 癥結;
      `test/traditional_ailment_glyph_test.dart` fails four ways on the pre-fix data.

      **Scope was the interesting part, and the refuter broke my first version of
      it.** Unlike 淩 or 蔔, 癥 is CORRECT elsewhere in this repo:
      `assets/sermons/zh-TW/105.txt` reads 「真正的癥結」 — one 癥 against 171 症 in
      that corpus — so a repo-wide sweep would have corrupted it. I had also written
      that no other tracked file carries the character; `HANDOFF.md` and this queue
      both do, in our own notes about the pair. Now pinned by the test.
      SeekSparks' tracked copy of `cuvs-yhwh-tr.json` carries the identical 26 癥;
      **its own loop writes there and this repo must not**, as with 五壳 above.

      **凌/淩 is done — 37 substitutions, 2026-08-18.** The third true partition,
      and the one that shows most clearly that this class is a converter defect
      rather than an editorial preference: **凌 is the correct form in BOTH
      scripts.** Taiwan 教育部, the Hong Kong list and the mainland standard all
      set 凌 in 凌辱/欺凌/凌遲; 淩 is a rare variant used essentially only as a
      surname and in water senses, and it appears in no name in scripture. So
      unlike 隻, 淨 or 恆 there was no simplification to undo here — the converter
      mangled a character that needed no conversion at all, and our own
      Simplified asset writes the correct 凌 in the same 37 places.

      Ours held 37 淩 and **ZERO** 凌; the witness 37 凌 and **ZERO** 淩, agreeing
      count-for-count on all 31,102 verses with **zero** mismatches. All 37 take
      exactly three readings — 凌辱 ×32, 欺凌 ×3 (代下 28:20, 詩 69:19, 箴 26:18)
      and 凌遲 ×2 (但 2:5, 3:29) — and all 37 were confirmed position by position
      against the witness's same-id verse on a **two-sided** context window, the
      first instalment with no one-sided or bare-count confirmations at all.
      士師記 19:25 read 「終夜淩辱她」, 撒母耳記上 31:4 「淩辱我」, 詩篇 44:15
      「我的淩辱終日在我面前」, 路加福音 6:28 「淩辱你們的，要為他禱告」.
      Corroborated by 梁家鏗's independent Traditional NT (10 凌 in verse text,
      zero 淩) and 新譯本 `57c4686` (30 凌, zero 淩).

      **The narrowest scope of any instalment so far:** 淩 occurs in no other
      text file tracked in the repo — the sermons (23 凌), `section_titles.json`
      and `bible_evidence.json` already write it correctly — so nothing outside
      the verse asset needed touching.
      `tools/repair_tr_insult_glyph.py` (re-runnable, idempotent) refuses seven
      ways; `test/traditional_insult_glyph_test.dart` fails four ways on the
      pre-fix data. The test also caught a miscount of my own before it was
      committed: 梁家鏗's file holds 15 凌, not 10, because five sit in
      `blockNotes` (凌晨, the Roman watches) which a `text`-field count skips.

      **The refuter confirmed all four load-bearing claims** — including that it
      could find no position among the 37 where 淩 could legitimately stand, no
      name and no genealogy — and independently recounted the biblexg number the
      test had already caught. It added one piece of scope worth keeping: the
      **retired LJK1 `assets/biblexg-tr.json` carries the same hole** (10 淩,
      zero 凌). It is deleted from the tree and dropped from the bundle as of
      v1.4.5 (commit `69307c7`), so nothing ships it and there is nothing to fix
      — but **if that version is ever revived it is unrepaired**, and it will
      need this instalment and probably every other one in the class. The same
      goes for any other retired Traditional asset brought back from history.

      **恆/恒 is done — 79 substitutions, 2026-08-18.** The second true partition
      and the one with the widest reader surface: **54 of the 79 are Bethlehem**,
      so a Traditional Bible spelt the nativity 伯利恒 at 彌迦書 5:2
      「伯利恒、以法他啊」, 路加福音 2:4, 馬太福音 2:1 and every reference in Ruth.
      The other 25 are 恒久 ×8, 恒心 ×8, 恒切 ×4, 恒常, 恒守, 恒忍, the name
      雅叔比利恒 (代上 4:22, Jashubi-lehem) and 詩篇 89:36 「如日之恒一般」, where
      the character stands alone. 箴言 11:19 「恒心為義的」, 哥林多前書 13:4
      「愛是恒久忍耐」, 使徒行傳 1:14 「恒切禱告」.

      Ours held 79 恒 and **ZERO** 恆; the witness 79 恆 and **ZERO** 恒, agreeing
      count-for-count on all 31,102 verses with **zero** mismatches — so no
      offsetting pair could hide. Easier than 卜/蔔 in one respect: 恆 and 恒 are
      the same word rather than two words sharing a Simplified form (恒 is the
      mainland standard, 恆 the Taiwan 教育部 and Hong Kong form), so there was no
      meaning to decide anywhere. All 79 still confirmed position by position
      against the witness's same-id verse: 74 on a two-sided window of up to 8
      characters, 5 on one side only — 箴言 11:19 and 箴言 25:15 are verse-initial
      so there is no left context (and 25:15 also loses its right window, the
      witness dropping two commas), 彌迦書 5:2 reads 「伯利恒、以法他」 against the
      witness's 「伯利恆的以法他」, 使徒行傳 1:14 「的恒切」 against 「地恆切」, and
      創世紀 48:7 brackets its gloss `(以法他就是伯利恒)` where the witness sets
      〈…〉. Corroborated by 梁家鏗's independent Traditional NT (32 恆, zero 恒,
      all 伯利恆) and by 新譯本 `57c4686` (zero 恒). Nothing to do on the
      Simplified side or in the tagged corpus — both already write 恒, the
      correct single Simplified form.
      `tools/repair_tr_constancy_glyph.py` (re-runnable, idempotent) refuses
      seven ways, including refusing outright if the witness holds even one 恒;
      `test/traditional_constancy_glyph_test.dart` fails four ways on the
      pre-fix data.

      **The refuter could not break the fix but broke three things I wrote about
      it, which is why the description above is not the one I first drafted.**
      It independently recounted all seven claims and confirmed them, then found
      (a) I had called 彌迦書 5:2 verse-initial — it is not, the glyph sits at
      index 2 of 伯利恒 and its *right* side differs, a 、/的 variant; only the two
      Proverbs are verse-initial; (b) the tool's cue audit reached **78 of 79**,
      because 伯利恒 is not a substring of 雅叔比利恒 — the cue is now 利恒, and
      the same off-by-one was about to go into the test; (c) 創世紀 48:7 uses
      ASCII parentheses, not fullwidth. It also confirmed the scope: it swept
      every tracked file and found every other 恒 sitting in a `zh-Hans` key or
      Simplified prose, with `section_titles.json` cleanly split (cuv 8 恒 / 0 恆
      against cuv-tr 0 恒 / 8 恆).

      **卜/蔔 is done — 42 substitutions, 2026-08-18.** The first true partition
      of the whole class and the cheapest instalment yet: 蔔 is correct in
      exactly one word in the language, 蘿蔔, and no radish occurs in scripture,
      so unlike 發/髮 or 谷/穀 there was no correct-in-our-form side to protect.
      Ours held 42 蔔 and **ZERO** 卜; the witness 42 卜 and **ZERO** 蔔, agreeing
      count-for-count on all 31,102 verses with **zero** mismatches — so no
      offsetting pair could hide, because no verse holds both readings.
      申命記 18:10 read 「不可有占蔔的、觀兆的」, 以西結書 13:6 「是謊詐的占蔔」,
      彌迦書 3:11 「先知為銀錢行占蔔」. The positions a divination-only rule would
      have missed are the transliterations — 別西蔔/巴力西蔔 ×8 (Beelzebub /
      Baal-zebub), 巴蔔 ×2 (Bakbuk), 押蔔 (Azbuk) and 蔔士 (亞 10:2, the diviners)
      — and they need no rule here because the class moves whole.
      梁家鏗's independently translated Traditional NT corroborates: 別西卜 ×8,
      占卜 at 使徒行傳 16:16, zero 蔔. Nothing to do on the Simplified side or in
      the tagged corpus — both already write 卜, which is the correct single
      Simplified form. **占 was deliberately left alone** (56 here, of which the
      witness says 30 should be 佔): 占 is correct inside 占卜, so 卜 had to be
      settled first and 佔/占 is now unblocked.
      `tools/repair_tr_divination_glyph.py` (re-runnable, idempotent) refuses
      seven ways, including refusing outright if the witness holds even one 蔔 —
      because that would mean this is a split and not a partition;
      `test/traditional_divination_glyph_test.dart` fails three ways on the
      pre-fix data and pins 占/佔 so the next instalment cannot silently
      overshoot into this one.

      **The refuter earned its keep again, and this time on scope.** It could
      not break the claim — it confirmed zero 蘿/萝/菔 anywhere in the corpus
      (民數記 11:5's produce list is 黃瓜、西瓜、韭菜、蔥、蒜, no radish), matched
      all 42 on a ±2-character window, and added two witnesses nobody had used:
      新譯本 `57c4686` (44 卜 / 0 蔔) and the sermon corpus below. But it caught
      that **"no 蔔 belongs in this repo" is false** — `assets/sermons/zh-TW/`
      holds **seven correct 蔔**, all 蘿蔔/胡蘿蔔, which a repo-wide sweep would
      have printed as 蘿卜. The claim is true of scripture and had to be scoped
      to the verse asset. Now pinned by the test.

- [ ] **克/剋 is a new hole the inventory table never listed — ours holds ZERO 剋.**
      Found 2026-08-18 by the refuter while it was checking 制/製. Both witnesses
      write 剋制 at five of our six 克制 (士 16:5, 16:6, 16:19, 哀 1:13,
      但 2:40); the sixth, 克制肉體, is 克 in all three. Simplified merged
      克/剋, so it is the same class of converter defect.

      **It did not show in the "characters the witness has and we hold zero of"
      table because that table was cut off at 10 occurrences** — the same reason
      咸 hid. But it is **weaker than 製/制 and must not be swept on that
      analogy**: 克制 is itself a standard Traditional word in the Taiwan MOE
      dictionary, so nothing false is printed today and this is
      edition-consistency, not a scripture defect. Measure the full 克 inventory
      before deciding, and ask the user — it belongs with 兇/凶 and 蹟/鍊 above,
      not with the instalments.

- [ ] **`assets/bible_evidence.json` has zh-Hant fields holding wholly SIMPLIFIED
      prose — not a glyph hole, an untranslated field.** Found 2026-08-18 while
      scoping 恆/恒, and confirmed independently by the refuter: the 42 恒 in
      `zh-Hant` values mirror the 44 in `zh-Hans` field for field, because for
      those entries the zh-Hant value *is* the zh-Hans value. Evidence 24 reads
      「古代伯利恒泥印」 and 「这枚直径约1.5厘米的小型黏土泥印，是2012年以色列文物
      管理局…」 under `zh-Hant` — 这/圣经/约旦 and all.

      **Deliberately NOT fixed as part of the 恆/恒 instalment**, and the reason
      matters: every repair tool in `tools/` is a single-character substitution
      justified by a witness edition, and there is no witness for this — fixing
      it means converting whole paragraphs, which is a different kind of change
      needing a different kind of evidence. Sweeping 恒→恆 here would have
      "fixed" one character in a paragraph that is Simplified from end to end and
      made the defect harder to see.

      **Measure first:** count how many of the entries have `zh-Hant == zh-Hans`
      (or are Simplified by character inventory) before deciding — it may be a
      handful of entries or most of the file. This is apologetics copy, not
      scripture, so it ranks below the verse assets; but it is reader-visible in
      Traditional mode. Check `songs.json` and `section_titles.json` in the same
      pass: both hold untagged Simplified-only strings (14 and 8 恒), and it is
      not yet established whether those are converted at render time or shown
      as-is to Traditional readers — `section_titles.json` at least has a proper
      `cuv` / `cuv-tr` split, so it is probably fine.

- [ ] **`assets/sermons/zh-TW/` is a DIFFERENT and much smaller defect — do not
      treat it as another instalment of the converter hole.** Found 2026-08-18
      while scoping 卜/蔔. 289 files. It was produced by a **phrase-aware**
      converter that does **not** have the hole at all: it holds 隻 453, 淨 358,
      牆 257, 餘 190, 髮 121, 穀 17, 鬆 133, 佔 148 and all three of
      干 41 / 乾 164 / 幹 142 — and **zero** of the Simplified forms 凈, 墻, 余.
      So none of the repair tools in `tools/` applies here and running one would
      do damage.

      What it has instead is **spot errors**, and only a handful are known so
      far: `751.txt` reads 「幹蘿蔔」 four times where it means 乾蘿蔔 (dried
      radish), and two stray 恒 against 276 correct 恆 — `156.txt`
      「背景中恒常存在的」 and `327.txt` 「永恒生命」 (found 2026-08-18 while doing
      恆/恒; left alone deliberately, and now pinned at 276/2 by
      `test/traditional_constancy_glyph_test.dart`, so fixing them has to be a
      deliberate act rather than a side effect of some later sweep).
      Needs its own measured pass — count first, and there is no
      witness edition for sermon text, so each has to rest on the sentence.
      Lower priority than the verse assets: this is a preacher's illustration,
      not scripture, so a wrong glyph here is not quoted as the text of the
      Bible.

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
      它/牠 and the transliterations 瑪/馬, 毗/毘 are conventions
      this edition is entitled to, and 雅偉/耶和華 is the whole point of
      ours. Only glyphs with no Traditional existence are safe to take on
      the witness's word alone.

      **Correction, 2026-08-18: 侖/崙 was listed here and it did not
      belong.** It is not a convention but a converter hole, and it was
      misspelling Hebron in 69 verses while this line said to leave it be.
      The test that separates the two cases: a genuine convention is
      consistent WITHIN each edition, whereas our own converted files
      spelt 希斯崙 right and 希伯侖 wrong in the same document — the
      signature of opencc's phrase table, not of an editor. See the
      completed 崙 item near the top of this file for the full argument.
      Apply that test before dismissing any other pair listed here.

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

      ---
      **SCOPED AND MEASURED 2026-08-18 (while doing 崙). Read this before
      starting — it changes what the item is.**

      These two files have **no holes at all.** Every `glossZhTw`/`defZhTw` is
      `opencc -c s2t` of its Simplified twin, character for character, with
      **ZERO manual edits across all 28,377 field pairs** — verified by
      re-converting every Simplified field and comparing both directions. So
      the exposure runs the other way from the verse asset: opencc never fails
      to convert, it fails by picking the **wrong one-to-many expansion**, and
      because nobody ever hand-edited the file every such mistake is still in
      it. **An inventory diff can never find these** — the character written is
      a perfectly good Traditional character, just not the right one. Do not
      look for "we hold zero of X" here; look for wrong expansions.

      All 193 source positions of 干 were enumerated and classified against the
      Simplified twin (乾 dry 146, 干 interfere/name 20, 幹 trunk/do 17 — the
      17 already correct). Every ambiguous class opencc touched in these files
      was surveyed the same way: 谷/穀, 发/髮, 里/裏, 松/鬆, 系/係/繫, 台/臺,
      只/隻, 斗/鬥, 扎/紮, 占/佔, 云/雲, 岳/嶽, 征/徵, 游/遊, 布/佈, 范/範,
      咸/鹹, 困/睏, 折/摺, 钟/鐘, 术/術, 虫/蟲, 向/嚮, 丑/醜. 岳父/岳母 (×38)
      and 掙扎 are correctly left alone by opencc, and 谷→穀 is right in all 78.
      **18 rules covering 39 substitutions across 37 fields came out wrong**, and
      `tools/repair_strongs_tw_ambiguous.py` is committed unapplied (dry-run
      verified, guards + MUST_SURVIVE list) with the full rule table: the eight
      rows above plus 亞多尼乾 ×2, 亞乾 ×3,
      伯・哈幹 ×1, 雅幹 ×1, 變幹 ×2, 被髮出 ×1 (H7972 — 髮 is hair), 徵服 ×1
      (H8478), 莫丘裏 ×2 (G2060, Mercurius — a name, so 里), 睏倦 ×4 and
      疲睏 ×2 (睏 is drowsiness, 困 is weariness).

      **A nineteenth rule was REFUTED and is now commented out in the script,
      not deleted:** 裏海 → 里海 ×4. 裏海/裡海 IS the standard Traditional name
      for the Caspian, the "inner sea"; the file already sets 裏 273 times and
      G3934 already reads 里海, so if anything the edit runs the other way. It
      stays visible so a later pass does not rediscover and re-add it.
      **43 substitutions in the first draft, minus those 4, = 39.**

      Also found and NOT yet fixed: 闢拉→辟拉 ×7, 併爲→並爲 ×21 + 併成 ×1
      (but keep 合併 ×3 at H6775/G2957), 回覆→回復 at H5025/H8666/G330×2 (keep
      G611/612/627), 被複興→被復興 (H7725), 複合→復合 (G604), 蔘加→參加
      (H4918), ~9 under-converted 里→裏 (G4245, G2491, G4270, G962×2, G4067,
      H2574), 須→鬚 (H5189, H6538).

      Two more, both separate calls:
      * **H6867 「傷愈的疤」** — the 愈/癒 spin-off already queued above.
      * **The 西/希 typo — 4 entries, and it comes in both 崙 and 倫.**
        H5555 (×2) and H6814 (×1) read 西伯崙 where the name is Hebron the
        city: H6814 says 「在西伯崙之後7年建立」, which is 民 13:22 「希伯崙城
        被建造比埃及的鎖安城早七年」 verbatim. **H2811** reads 「可能就是西伯
        倫族的哈沙比雅 (#代上 26:30|)」 — the same typo, but the Kohathite
        clan, which our Bible spells 希伯**倫** 12 times. The file writes 希伯
        105 times against 西伯 4.

        The 崙/倫 glyphs are all correct as they stand (the Simplified twins
        read 西伯仑 and 西伯伦 respectively, and Simplified distinguishes the
        two perfectly) — **only the 西/希 letter is wrong**, and it is in the
        Simplified `glossZh`/`defZh` too, so changing it is an editorial
        correction to the source rather than a conversion repair. Needs the
        user, or a third edition of the lexicon.

        **Lesson worth keeping from how this was nearly botched:** the 2026-08-18
        pass first justified fixing 西伯侖→西伯崙 with the rule 「whichever name
        is meant, the last character is 崙 and never 侖」. That rule is FALSE —
        H2811 is the counter-example sitting in the same file. The substitutions
        were right, but for the wrong reason; what actually licenses them is the
        Simplified twin reading 仑 rather than 伦. Prefer the twin over a rule
        about names, always.

- [ ] **17 wrong 幹 in the Traditional sermon assets.** `assets/sermons/zh-TW/`
      holds 142 幹 across 60 files and **the great majority are correct** —
      才幹 (~40), 幹活, 幹什麼, 幹部, 樹幹, 軀幹, 主幹道, 幹掉. The 發/髮 shape
      again. The wrong ones are dryness: 哭幹了眼淚, 排幹了, 水庫幹了,
      溪也幹了, 幹枯, 幹蘿蔔 ×4, 嘴幹, 一把幹沙, 凍幹食品, 幹淨 ×2, plus
      幹擾 ×2 which is 干. Lower priority than the Strong's item — these are
      sermon transcripts, not scripture — but they are reader-visible prose
      and there is no witness for them, so each has to be read.

- [x] **`丶` stood in for the enumeration comma 、 in 53 places, in BOTH
      editions. DONE 2026-08-19 — 150 substitutions across 30 verses per
      edition plus 44 in the tagged corpus.** 出埃及記 15:4 read 「法老的車輛丶
      軍兵」, 詩篇 146:6 「雅偉造天丶地丶海」, 尼希米記 9:5 seven of them in one
      verse. `丶` is U+4E36, the CJK *stroke radical* — a dictionary head
      component, not punctuation.

      Equal counts on both sides (53 / 53) said this was **upstream of the
      Traditional conversion**, not caused by it, so it is not part of the
      deferred glyph class. Two independent witnesses agreed: `7a2dc43` reads
      、 at all 53 positions, and the tagged Strong's corpus — a separately
      punctuated edition that uses 〔〕 and “” — reads 、 or ， at the ones it
      covers and 丶 nowhere. The refuter tried the one objection worth trying,
      that 丶 might be a name separator like the witness's 伯‧毘珥 (U+2027),
      and it fails: our corpus holds zero U+2027, writes 伯毗珥 unseparated,
      and the 丶 in 申命記 34:6 sits at 「摩押地丶伯毗珥」, a list comma.

- [x] **Eight verses carried an orphaned punctuation mark, in both editions —
      not the one the entry originally recorded. DONE 2026-08-19.** This was
      filed as a single doubled comma at 出埃及記 25:35 「接連一塊，，。」.
      Measuring first turned it into eight, all identical in both editions and
      all confirmed against the witness, and every repair a **deletion** — no
      character was written into scripture:

      | | ours | witness |
      |---|---|---|
      | 出埃及記 25:35 | 接連一塊**，，**。 | 接連一塊。 |
      | 民數記 26:32 | 有希弗族**；**。 | 有希弗族。 |
      | 耶利米哀歌 4:15 | 喊著說：**！**不潔淨的 | 喊著說：不潔淨的 |
      | 撒迦利亞書 3:8 | 作預兆的）。**，**我必使 | 作預兆的。）我必使 |
      | 阿摩司書 6:10 | 又說：**，**不要作聲 | 又說：「不要作聲 |
      | 阿摩司書 6:14 | 神說：**，**以色列家啊 | 神說：以色列家啊 |
      | 希伯來書 13:3 | 同受捆綁；**，**也要 | 同受捆綁；也要 |
      | 創世紀 21:7 | 一個兒子。**「」** | 一個兒子。」 |

      **The eighth was found by the test, not by the sweep, and that is the
      lesson.** The adjacency table showed 「：，」 with a count of **2** and the
      reader took both to be 阿摩司書 6:10; 6:14 was only repaired once the
      assertion ran over the whole corpus. A count read off a summary table is
      not the same as a position checked in the data — the table tells you how
      many there are, not where.

      `tools/repair_stray_punctuation.py` (re-runnable, refuses on mismatch)
      does both this and the 丶 item; `test/stray_punctuation_test.dart` pins
      zero 丶, the 、 count at 6324, zero adjacent punctuation pairs anywhere
      in either edition, and the eight repaired verses by reference.

- [ ] **72 stray or half-width ASCII punctuation marks in running scripture,
      in BOTH editions — and one sub-class may be LOST TEXT rather than a
      stray.** Found 2026-08-19 by the refuter, which correctly broke the
      claim that the CJK adjacency sweep above was a complete enumeration of
      this defect class: that sweep only looked at CJK marks, and it cannot
      see a stray that has no punctuation neighbour at all. Counts are for the
      Traditional asset outside `<note: …>` markup and outside the deliberate
      `[雅偉]` convention (229 occurrences, which is NOT a defect — it marks
      where the divine name was substituted, and must be left alone):

      | mark | n | example | class |
      |---|---|---|---|
      | `.` | 19 | 創世紀 6:11 「滿了強暴**.**。」, 民數記 24:17 「毀壞擾亂**.**之子」 | stray |
      | `,` | 14 | 約珥書 1:11 「你們要慚愧**,**修理葡萄園的」 | half-width 、/， |
      | `!` | 9 | 創世紀 43:14 「就喪了吧**!**」」 | half-width ！ |
      | ~~`?`~~ | ~~9~~ | 士師記 6:33 「在耶斯列**??**平原安營」 | **DONE 2026-08-19 — stray, not lost text** |
      | `"` | 8 | 撒迦利亞書 1:3 「（原文有 **"**萬軍之雅偉說**"**）」 | half-width 「」 |
      | `(` `)` | 9 | 創世紀 48:7 「路上**(**以法他就是伯利恆**)**」 | half-width （） |
      | `:` | 3 | 路加福音 18:37 「他們告訴他**:**「是拿撒勒人耶穌」 | half-width ： |
      | `;` | 1 | 帖前 2:13 「就領受了**;**不以為是人的道」 | half-width ； |

      **The `?` row is DONE, 2026-08-19 — and the fear behind it was
      unfounded, which took three witnesses to establish.** All nine are
      strays; nothing was lost. The five verses are 士 6:33, 王上 2:5, 結 16:4,
      結 16:43 and 結 20:9 (the earlier note said 王下 2:5 and 11:2 — wrong
      references, read off the table rather than the data). Deleted in both
      editions plus 結 16:43 in the tagged corpus, and 伯 15:12/15:16 in the
      tagged corpus had a half-width `?` closing a clause where the verse sets
      ，and ！. `tools/repair_question_mark_artifacts.py`;
      `test/question_mark_artifacts_test.dart` now asserts **no ASCII `?`
      anywhere** in either edition or the tagged corpus, and fails on the
      pre-fix data.

      What settled it: **our own tagged Strong's corpus is a third witness and
      it is the same 雅偉 edition** — it carries four of the five verses with
      no character at the slot, so this is not a place where the publisher
      departs from the CUV. The other two witnesses agree, the Hebrew leaves
      no room for a word, and 結 20:9 carries an *odd* number of marks, which
      no double-byte pairing produces. The refuter's parting shot is the entry
      now at the top of P0: characters ARE dropped in this corpus, but silently
      and with no marker, so `??` was never the signature to look for.

      The half-width classes are lower risk but are **substitutions, not
      deletions**, so they need the same per-position confirmation the 余/腌
      pass used. Verify the bundled CJK font subset covers each full-width
      replacement before shipping.

      **Two non-scripture assets have the same half-width habit** and were
      left alone: `maps_index.json` 1123 (a 路 18 description, 2 marks, and it
      uses half-width `,` throughout) and `onegod.json` episode titles
      (「誰是獨一的真神?」). Reader-visible but not scripture, so they belong
      with the half-width sweep rather than ahead of it.

- [ ] **`說；「` opens a quotation with a semicolon in 5 verses — a
      substitution, so deliberately not swept with the deletions above.**
      列王紀上 22:13, 路加福音 13:2, 約翰福音 7:45, 約翰福音 9:9 and
      希伯來書 3:11 all read 「說；」 where a quotation opens; the witness reads
      「說：」 at every one, and this corpus sets 「：「」 2,692 times and 「：『」
      547 times against these 5.

      **10 of the 15 「說；」 in the corpus are correct** and must not be
      touched — 約伯記 28:27 「而且述說；他堅定」, 士師記 8:8, 加拉太書 2:2 and
      the rest are a clause ending in 說 followed by a legitimate semicolon.
      So this cannot be a blanket substitution; it is 5 confirmed positions.
      約翰福音 9:9 has a second defect in the same verse — ours 「是他；」」 for
      the witness's 「是他」；」 — so fix that one by reading, not by rule.

- [ ] **創世紀 21:7 has a displaced closing 』 the 2026-08-19 repair did not
      touch.** The empty quote pair at the end was removed, but ours still
      reads 說『撒拉要乳養嬰孩**呢？**』 where the witness and the standard CUV
      read 說『撒拉要乳養嬰孩』**呢？** — the inner quote wrongly swallows the
      outer clause's question. `？』` is a legitimate pair, so no adjacency
      sweep will ever find it; it was caught only by the refuter reading the
      whole verse. Fixing it MOVES a character rather than deleting one, which
      is why it was left. **The general lesson is the expensive one: a
      misplaced-but-well-formed mark is invisible to every structural check
      this repo has**, so this class can only be found by reading against a
      witness.

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

      **ANSWERED 2026-08-18: the pane wins. The grid follows the text.**
      Asked after the user hit the other half of it on a tablet — the
      picker headed 创世纪 41 (its grid ran to 57, which is that
      chapter's verse count) while the pane sat on 创世纪 1. Their call:
      "网格跟着正文走".

      So the rule is now simple and one-directional: **whatever chapter
      the reading pane is on, that is the chapter the verse grid offers
      — always, including across a book change, a search jump, a
      restored session and a Home round-trip.** The v1.2.76 preference
      is superseded; it was only ever about Prev/Next sliding the grid
      along, and following the pane does that too.

      What this buys, and it is the reason to prefer it: the panel can
      no longer name one chapter while the text shows another. That is
      the same class as the version chip naming one translation while
      the verses are another (P0, fixed 2026-08-17) — an interface
      saying something that is not so.

      The cost the user accepted: opening 創世紀 41's grid to hunt for a
      verse, then moving the pane, loses that grid. Do not try to soften
      this with a "hold" heuristic — a rule that sometimes follows and
      sometimes holds is exactly the ambiguity being removed.

      Write the test as the invariant, not as a sequence: after ANY
      navigation, `picker.chapter == pane.chapter`. Cover the paths the
      previous fix found were separate — the docked sidebar, the
      full-screen route, and its `providerOverride` path.

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

- [ ] **Sweep the CDC network's country sites for songs we do not have.**
      User, 2026-08-18, pointing at the "WHERE WE MEET" menu on
      `christiandiscipleschurch.org`: Australia, Canada, Hong Kong,
      India, Indonesia, Malaysia, Nepal, The Philippines, Singapore,
      Thailand, United Kingdom, Southeast Asia — "看下所有网站里面有没有
      其他的歌也加进这个app里面".

      **Cannot be started from this machine, and not for the usual
      reason.** `christiandiscipleschurch.org`, `christiandc.org` and
      `christiandc.com` all resolve to the SAME IP (149.248.15.146) —
      they are one server, not mirrors — and it answers
      **ECONNREFUSED**, not a timeout. It refuses datacenter IPs: this
      Mac, WebFetch and the GitHub runner are all turned away, while
      the user's phone opens it. So this needs either a residential
      connection or the pages pasted in.

      **Two findings from search that change the shape of the job:**

      1. **The CDC's Chinese songs are fydt.org's.** Their own site says
         the Chinese songs are taken from fydt.org, which the sync
         already covers. So a country page carrying Chinese hymns is
         probably the SAME catalogue, not a new source. Check for
         duplicates by audio URL before adding anything, or the app
         gains 200 songs it already has under different titles.
      2. **`Classic Piano Hymns` has 15 hymns and our sync reports 0.**
         Every run logs `cdc hymns: 0 classic piano hymns`. That is a
         scraper gap on a page we already know about, and unlike the
         country sweep it is testable the moment the host answers.
         Do this one first — it is smaller, certain, and already
         scoped.

      **What to ask the user for**, if the host stays unreachable: the
      country pages that actually list a local site of their own. Most
      congregations will have no separate website; the sweep is only
      worth doing for the few that do.

- [ ] **The daily "Refresh songs" failure email is now noise — quiet it
      without going deaf.**
      `SuyangLiuPaul/yswords-data` → Refresh songs has failed every day
      since 2026-08-12; last success 08-11. Six identical failures, six
      identical emails.

      **The job is not broken. The guard is working.** Every run fetches
      all four sources fine and then refuses to write:

          ERROR: a source lost a tenth of its AUDIO while keeping its
          songs — that is what a refused fetch looks like, not an
          upstream deletion. Refusing to write.
                 cdc: 286 → 247 with audio

      `christiandiscipleschurch.org` keeps returning all 283 CDC song
      pages while withholding the media on ~39 of them. The guard exists
      because on 2026-08-10 exactly that shipped: the song count never
      moved, the old count-only guard saw nothing, and the app published
      36 hymns with a dead play button. **Do not weaken or bypass this
      guard** — failing loudly with the previous catalogue in place is
      the correct outcome, and the emails are it doing its job.

      **What to change is the notification, not the check.** Six
      identical mails teach the reader to ignore the seventh, which is
      the one that will say something new. Suppress a repeat when the
      failure reason is unchanged from the previous run, and speak up
      when either the reason changes or the same reason has persisted
      past a threshold (a week is a fair first guess — by then it is
      news again, not noise).

      Store the last failure reason next to the catalogue and compare;
      the guard messages are already stable, single-line and specific
      enough to compare on.

      **Root cause is not ours to fix from here.** The same host is
      unreachable from the maintainer's Mac for an unrelated reason (a
      managed-device policy — see the host note above), so this is two
      different blocks on one site. Getting the runner unblocked needs
      the church, not code.

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

      **Answered 2026-08-17.** The second track IS Cantonese, and there
      is no Mandarin: "如果没有普通话就空着没问题". So this series ships
      English + Cantonese, and the Mandarin slot stays empty rather than
      being filled with the Cantonese file or hidden. Two series with
      different language coverage is the case the model has to handle
      anyway — 獨一真神 has three, this has two — so an empty slot is
      the normal state, not an error to paper over.

      **The consequences of YouTube, which the design has to absorb:**
      * `video_player` **cannot play a YouTube URL.** A different
        package is needed (`youtube_player_iframe` or a webview). That
        is a real dependency decision — check bundle size and whether
        it works on all six targets before committing to one.
      * **No subtitles for this series at all.** User, 2026-08-17:
        "因为我们换成YouTube所以不要做字幕". Do not build a caption
        track, do not run `scripts/align_subtitles.py` against these,
        and do not add a subtitle toggle to this series' player —
        YouTube carries its own captions and the viewer can turn them
        on there. The `.vtt` files under `assets/subtitles/` and that
        script stay where they are: they belong to 獨一真神, which is
        still self-hosted and still needs them.
      * There is no offline download for a YouTube video. If the
        Songs-style "download for offline" affordance appears anywhere
        near this section, it must not be offered here.
      * The position-preserving language switch still matters and is
        still possible — ask the embed for its current time before
        swapping, the same idea as today, different API.

      **A SECOND series goes in the same section — the Shema videos.
      UNBLOCKED 2026-08-19, with all 29 IDs read off YouTube.**
      User: "这里面的也要加到featured video里面一个系列的". Bentley, via
      the user: "All 29 youtube links."

      **Taken from YouTube's RSS feeds, not from the church page.** That
      page still refuses datacenter IPs, but it turned out not to be
      needed: `https://www.youtube.com/feeds/videos.xml?playlist_id=<id>`
      returns clean XML with video IDs and titles, which is a better
      source than scraping HTML anyway. The channel is `@RRSuen`.

      **The count verifies itself: 25 numbered messages (#7–#31) plus 4
      series compilations = 29**, exactly the number Bentley gave. That
      agreement is the reason to trust this table.

      | playlist | numbers | id |
      |---|---|---|
      | The Shema Part 1 | #7–#13 | `PLKdS3C3dQ95RMSBg52aWzdb3KtowWw8AV` |
      | Living the Shema Part 2 | #14–#20 | `PLKdS3C3dQ95Qqif5KtfyEZgwkwIv5_SEr` |
      | Living the Shema Part 3 | #21–#27 | `PLKdS3C3dQ95RjguVV6xdtIElP95OOw7Hl` |
      | Living the Shema Part 4 | #28–#31 | `PLKdS3C3dQ95RP0tFef-MKOpEp3JWXL3hw` |

      Part 1 (#7-13): W9qBulKwZZk bpPV5CVQhtk mi3Ek9a9Gtg G1WIG-D0fxU
      DYJFQ6RfHFs 2b_sqdFnkVI DL0e9xuBTM0 · compilation ksDEG_PhuS4
      Part 2 (#14-20): NSDI_aVXh48 pWigf_uuaSw ardFs31RXrg zMPG5fjTT_I
      2vsgBwO9MqY cBSPeIJ9by8 dinbK352sW4 · compilation M3zQNM0mhoM
      Part 3 (#21-27): CAOAR4lrSXI wytRw17AN4w ucvTxRq2EP0 61ivlMTRJzM
      Rht9Sjqr9X8 jK43LNqkBQM 9oDClt6_veA · compilation PnO_OyR3cW8
      Part 4 (#28-31): PNr5ozRGZzE IY3pEDYKv2o ec3T-_0DYXA NhTgvJ_xOhQ
      · compilation GmBlrJYfP84

      **Re-fetch the titles from the feeds rather than transcribing
      them here** — they are long, they carry scripture references, and
      a typo in a title shown next to Scripture is not worth the risk.

      **Three things to decide, not to guess:**

      1. **The 4 compilations are not episodes.** Each is the whole
         part in one video ("7 Message Series on…"). Putting them in the
         episode list makes a 7-part series look like 8. They are
         probably a "watch it all" affordance, or omitted. Ask.
      2. **The church's own sub-numbering has a mistake.** Part 4 runs
         #28 #29 #30 #31 but its titles read "(15) (16) **(12)** (18)" —
         #30 says 12 where the sequence wants 17. **Do not silently
         correct it**; show the # number, which is consistent, and
         raise the sub-number with the user.
      3. **Numbering starts at #7.** #1–#6 exist somewhere — most likely
         the "Introduction" (4), "God's Name forgotten in the Church:
         YHWH" (6) and "My Testimony" (6) playlists on the same channel.
         Whether the Shema series in the app starts at #7 or includes
         those is the user's call, not an inference.

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
- **貴胄 or 貴冑? And more generally: when the printed 和合本 and modern
  Traditional orthography disagree, which wins?** Raised 2026-08-18. The
  Traditional Bible sets 貴胄 in 26 places (士 5:13, 王上 21:8/11, 尼希米記 ×8,
  以賽亞書 ×3, 耶利米書 ×3, 但 1:3, 路 19:12 …). Printed 新標點和合本 and the
  witness edition both set 貴冑; Taiwan 教育部 and opencc both say 胄 is the
  character for a scion and 冑 is a helmet, which scripture never mentions.
  Both spellings appear in published CUV editions, so this is a choice, not a
  defect — and the answer decides more than these 26, because it is the rule
  the remaining glyph instalments should follow whenever the two disagree.
  Full evidence in the 冑/胄 block under "P0 — scripture accuracy".
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
