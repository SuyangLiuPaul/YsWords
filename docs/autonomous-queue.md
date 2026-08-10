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

- [ ] **梁家鏗譯本 is damaged in both editions. Get the publisher's source.**
      Measured 2026-08-10 across both files:
      * 7 verses exist in one edition only — Traditional lacks 以弗所書 3:16
        and 彼得前書 3:11-12; Simplified lacks 馬可福音 6:8-11.
      * ~117 verses per edition swallow the NEXT verse's number and text
        ("…管住嘴唇不沾詭詐。11還要避惡行善…").
      * 8 verses truncated >40% against their counterpart; 以弗所書 3:15
        stops mid-word at "用權能使你們內".
      Same signature as the LEB damage — a conversion that lost
      boundaries. **Do not reconstruct across editions**: each holds part
      of what the other lost and bridging them needs a 简繁 converter.
      Guessing is what must never happen to a Bible.
      *Action:* ask the user to obtain the source from 聖經釋經事工, and
      meanwhile write the audit as a repeatable script + test so the
      damage cannot silently grow.

- [ ] **Make the Bible audit a permanent test.** The LEB was broken from
      the first commit and 500+ green tests never noticed, because tests
      check that code runs, not that data is true. Add a test that fails
      on: duplicate references, empty verses, a verse carrying the next
      verse's number, book tags that do not resolve, and per-book verse
      counts that drop.

- [ ] **Audit the remaining versions the same way.** kjv / nasb / leb /
      cuvs-yhwh / cuvs-yhwh-tr were checked for duplicates, empties and
      mojibake only. Run the embedded-verse-number and truncation checks
      across all of them and report counts before changing anything.

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
