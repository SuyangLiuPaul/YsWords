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

- [ ] **Proofread the TRADITIONAL against the printed 註釋本, book by book.**
      **This now outranks the Simplified proofread.** The user supplied
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

- [ ] **Make the audit a permanent test.** The LEB was broken from the
      first commit and 500+ green tests never noticed, because tests
      check that code runs, not that data is true. Fail the build on:
      duplicate references, empty verses, a verse carrying the next
      verse's number, unresolvable book tags, and per-book verse counts
      that drop.

- [ ] **Audit the remaining versions the same way.** kjv / nasb / leb /
      cuvs-yhwh / cuvs-yhwh-tr were checked only for duplicates,
      empties and mojibake. Run the embedded-verse-number and
      truncation checks over all of them and report counts before
      changing anything.

## P1 — Bible study correctness

- [ ] **Verify the Strong's tagging against the originals.** `assets/
      tagged/cuvs-yhwh/` now drives "tap a word to see the original".
      Spot-check that a word's Strong's number matches the same verse in
      `assets/originals/`, and count the disagreements before trusting it.

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
- **Xcode Apple ID.** iOS and macOS builds fail with "No Accounts";
  only the user can sign in.
- **NASB licensing**, and whether 梁家鏗's source can be obtained.
