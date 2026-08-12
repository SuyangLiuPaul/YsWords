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
        2026-08-11 (sixth) and 2026-08-12 (seventh and eighth): still
        `connect=0.000000`, curl times out with no TCP connect.
        Unchanged across eight consecutive iterations. **Tell the user** — they can probably reach Bentley
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

- [ ] **Rename 獨一真神 to "Featured video" — LOW priority.**
      User, 2026-08-12: "独一真神那个板块换名字叫featured video之后里面我
      会要变成YouTube link".

      Two steps, and only the first is asked for now:
      1. **Rename.** `oneGodTitle` is used at 4 sites. The page itself
         keeps its own heading; what changes is the SECTION label. Give
         the section its own key rather than editing `oneGodTitle` in
         place — the video's actual title is still 獨一真神, and the
         Featured card already has a separate subtitle.
      2. **Later, not now:** the content becomes YouTube links instead
         of the self-hosted MP4s. Do NOT start this until the user says
         so — it changes the subtitle track story completely (the burned
         cue files in `assets/subtitles/` are ours; YouTube captions are
         not), and it decides whether the Netlify-hosted 238 MB of video
         can be dropped. Ask before touching it.

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
