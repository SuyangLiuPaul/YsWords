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

- [x] **AUDIT EVERY ORIGINAL-LANGUAGE CLAIM THE APP MAKES.** Hebrew side
      done (`e714e31`): the importer kept only `<w>` and lost every marker
      that says "these are not two words" — 784 multi-word lexemes now
      render as one chip, 1,229 ketiv/qere as one word marked 寫作/讀作,
      and the 2,018 genuine repetitions are left alone. Greek still open.
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
        • **The Greek side has never been classified.** ~260 adjacent
          same-Strong runs in the NT, source OpenGNT, none of them looked
          at. Do the same measurement there before assuming it is clean.
        • **The Chinese glosses.** They come from CBOL/bible.fhl.net
          (CC-BY-NC-SA 4.0). Nothing has checked that the gloss shown
          belongs to the number shown.

      Report counts before changing data, as everywhere else in this
      queue. A wrong number here is the same class of error as a wrong
      verse — it is quoted in Bible study.


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

- [ ] **18 verses set an editor's gloss as scripture in the Traditional.**
      Found by the new cross-edition length check. Where the Simplified
      marks a short gloss as a note, the Traditional prints it inside the
      verse: 馬太福音 26:29 「…這葡萄藤的果實，**即葡萄酒，**直至那一天」,
      27:48 「蘸滿了酸酒，**士兵解渴的飲料，**綁在蘆葦竿子上」, 使徒行傳
      8:41 「再繼續前行，**即向北沿海，**走遍那一帶」, 路加福音 9:5
      「**作為警告**」 (the Simplified's note reads 「意即警告」), 馬太福音
      9:14 「都經常禁食，**通常每逢週一週四，**你的門徒卻不禁食」 — that
      last one the Simplified does not have at all. Same class as 羅馬書
      16:24: it reads plausibly as the evangelist's words and gets quoted.
      **18 refs have more `<note:>` in the Simplified than the
      Traditional, and 18 the other way** — so measure both directions
      before touching anything, and check the `tw` source to see whether
      the gloss is unmarked upstream or was flattened by our importer.
      Pinned meanwhile in `test/biblexg_verse_integrity_test.dart`.

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

- [ ] **Proofread the TRADITIONAL against the printed 註釋本, book by book.**
      Wording only; the characters are now done (see above). The user supplied
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
        2026-08-11 (sixth): still `connect=0.000000`, curl times out
        with no TCP connect. Unchanged across six consecutive
        iterations. **Tell the user** — they can probably reach Bentley
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

- [ ] **Verify the Strong's tagging against the originals.** `assets/
      tagged/cuvs-yhwh/` now drives "tap a word to see the original".
      `tools/audit_strongs_tagging.py` counts the disagreements over the
      whole corpus rather than spot-checking: 360,946 tagged runs,
      **24,983 carrying a number that is not in that verse's original**.

      **Most of that is a false alarm and should not be "fixed".** The
      two datasets use different Strong's conventions — the tagger's
      inflected-form numbers (G2076 ἐστίν, G5213 ὑμῖν, G2258 ἦν, G2257
      ἡμῶν) against the originals' lemma numbers (G1510, G4771, G1473).
      Every one of those resolves correctly in `assets/strongs/`, so the
      tapped word gives the right lexicon entry. Chasing the count down
      by rewriting numbers would make the app *less* accurate.
      The versification defect above was found by this audit and is
      fixed; that is what the 23.6% was really hiding.

      What is left to decide is the genuinely wrong tail: run the audit
      with the versification map applied to get a clean count, then look
      at what remains once the convention difference is factored out.

- [ ] **295 tagged runs carry `H0` / `G0`, which is not a Strong's
      number.** 253 Hebrew, 42 Greek; neither is a key in
      `assets/strongs/`, so tapping those words gives "not found".
      Likely the tagger's marker for the Hebrew direct-object particle
      or for untagged punctuation. Decide whether they should be
      untagged runs (no dotted underline, no promise of an answer)
      rather than tagged ones that cannot answer. Found by
      `tools/audit_strongs_tagging.py`.

- [ ] **Commentary import (public domain).** One module first — Matthew
      Henry or JFB — via the published `.cmt.mybible` SQLite file, never
      scraped. Credit the source on the About page even though the
      copyright has expired. 20-60 MB, so lazy per-book loading.

## P2 — features the user asked for

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

- [ ] **Extend tap-the-status-bar-to-scroll-to-top past the Songs list.**
      `lib/widgets/scroll_to_top_on_status_bar_tap.dart` exists and
      Songs uses it. 26 other scroll views still pass their own
      `controller:` and so never attach to `PrimaryScrollController`,
      which is the only thing material's Scaffold drives. Highest value
      first: Sermons, Search results, the Bible reading pane.

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
