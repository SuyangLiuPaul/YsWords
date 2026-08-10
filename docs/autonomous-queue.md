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

Getting that ordering backwards already produced one wrong report:
約翰一書 4:16 was written up as "the Simplified is missing 神就是愛…",
when the publisher's own 4:16 is exactly what our Simplified has. It is
the Traditional that carries text the translation does not have there.
**Check the source before believing a diff.**

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
      to the pastor. The headline: the printed Traditional 約翰一書 4:16
      ends 「神就是愛，那住在愛裡的…」 and the official Simplified webapp
      does not have that clause at all. Both are the publisher's own.
      Until they answer, change neither.

- [ ] **Proofread the Simplified against the publisher, book by book.**
      `python3 tools/proofread_biblexg.py --book <code>` — 27 NT books.
      First run: 4,826 comparable verses, **98% identical**, **95
      genuinely different in wording**, and the differences read as a
      later revision by the publisher rather than as damage
      (以弗所書 2:4 upstream "神富有愛憐，出於他愛我們的大愛" against our
      "神滿有憐憫，因著他愛我們的大愛").
      Take **one book per iteration**. For each difference decide, and
      say in the commit, whether it is a publisher revision we should
      adopt or a defect on our side. Adopting a revision means copying
      the publisher's wording exactly — never paraphrasing, never
      merging the two.

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
      - Retried 2026-08-10 (fourth iteration): still `connect=0.000000`,
        curl times out with no TCP connect. Unchanged.
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

- [ ] **In-app score (PDF) and video.** 554 songs have sheet music and 82
      have video, and both currently leave the app. Needs a PDF
      dependency that works on web + iOS + Android + macOS + Windows;
      check bundle-size cost before committing to one.
- [ ] **Downloads should include the score**, so an offline song still
      has its music.
- [ ] Search box on the Downloads page (Playlists already has one).
- [ ] Artwork thumbnails in song list rows — 199 songs have artwork and
      only Now Playing shows it.

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
