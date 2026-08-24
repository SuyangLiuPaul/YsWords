# YsWords — project state

**Read this first when picking the project up.** It records what is true
right now and the traps that have already cost real time. The per-item
work list is `docs/autonomous-queue.md`; this file is the orientation
above it.

Last updated: 2026-08-24.

**The refuter earns its keep — do not drop it to save a turn.** On
2026-08-23 it broke a punctuation repair's stated reasoning twice in one
iteration, in both directions: first it showed eight ASCII quotes should
be converted, then, after the conversion was written, that the population
the argument rested on had been drawn wrong and the conversion had to be
undone. Both times the fix was cheap because nothing had been committed.

On 2026-08-24 two rounds of it cut a Revelation repair from **15 edits to
5** — the ten it removed would have written quotation marks into the
edition on an assumption nobody had measured. **Run it twice when the
first round changes the shape of the claim**, not just once: round one
here widened the scope and round two shrank it, and only round two
touched the part that would have done damage.

---

## The app

Flutter, six targets: web, iOS, Android, macOS, Windows, Linux. A Bible
study app in Chinese and English — translations, sermons, songs, a
Bible-evidence (archaeology) section, a misconceptions section, and a
featured-video section.

The name is **Yahweh's Words**（雅伟之言）— renamed from "YsWords" at
the user's instruction on 2026-08-23. It lives in five per-platform
places that `test/app_display_name_test.dart` pins. Three YsWords
tokens survive on purpose and must NOT be renamed: every URL and
identifier ("link不要变"), the `NotoSansSC-YsWords` font family, and
the `# YsWords export` / `YsWords.json` format markers — an old backup
must import into the renamed app. AI features say "AI", never the app
name. On Android the apostrophe must reach values.xml escaped (\').

## Where each tier is

| Tier | Sites | Version | Rule |
|---|---|---|---|
| dev | `yswords-dev`, `yswords-cn-dev` | **1.4.146** | push freely |
| qat | `yswords-qat`, `yswords-cn-qat` | **1.4.146** | push freely once dev is verified |
| prod | `yswords`, `yswords-cn` | **1.4.11** | ⛔ never without explicit permission **in the current turn** |

**The deploy debt is paid.** v1.4.146 removes the two orphan `〕` that
士師記 8:24 and 耶利米書 10:11 printed as scripture — verified against the live
asset, where `cuvs-yhwh-tr.json` now pairs 12 `〔` to 12 `〕` on both
`yswords-dev` and `yswords-cn-qat`. v1.4.145 carries the `主*` removal — verified
against the asset the sites serve, not the repo: `john.json` on both
`yswords-dev` and `yswords-cn-qat` has zero asterisks, 約翰福音 20:13 stores
`{"w":"主","s":"G2962","i":["G3588"]}` and 20:2 stores `有人把`/`主` split so
only 主 answers κύριος. v1.4.137 removes the stray `」` that 路加福音
17:36 printed after its footnote icon, on top of v1.4.136's Revelation
second-level quotation repair and v1.4.135's nine-verse speaker-attribution
repair (`1760c58`) and three word-tap repairs (`d03c81d`). Verified against the
assets the sites actually serve, not the repo: in
`yswords-dev/assets/assets/cuvs-yhwh-tr.json` 路 17:36 now ends at its `>`
while 17:35 still closes `撇下一個。」`; 啟示錄 2:1/2:8/2:12/2:18/3:1 all read
`說：『`; and 馬太福音 15:34, 約翰福音 2:7/2:8/13:36, 創世紀 30:6,
哥林多前書 15:45 and 撒上 16:11 / 王下 10:13 / 撒下 15:19 still read correctly.

**prod is 131 versions behind and it is not an oversight.** Every prod
push needs the user to say so in the moment; permission never carries
over from a previous turn. Full wording of what does and does not count
as permission: `docs/release-policy.md`. prod still serves the broken
LEB and the wrong sermon attribution — those are fixed on dev/qat and
waiting on that one word.

Deploy with `tools/release_web.sh` (auto-bumps, builds, deploys all four
dev/qat sites). Native install: `zsh tools/yswords-ios-reinstall.sh`.

## The autonomous loop

A launchd agent works the queue one item at a time.

- `com.yswords.accuracyloop`, `StartInterval 1800` (every 30 min,
  set by the user 2026-08-23; was hourly), `RunAtLoad false`
- **It stops itself on 2026-09-21 20:30.** `STOP_AT` in `run.sh` is a
  dead-man switch: past that instant the job logs and calls
  `launchctl bootout` on itself rather than idling forever. Set to 29
  days by the user on 2026-08-23; before that it was two weeks and
  would have unloaded on 2026-08-24. The value is re-read every tick,
  so extending it needs no reload — but **edit `run.sh` only via
  `.new` + `bash -n` + atomic `mv`** (see trap 2 below).
- Driver: `~/Library/Application Support/yswords-loop/run.sh`
- Brief: the same directory's `prompt.md`
- Log: the same directory's `run.log`
- `--effort high`; watchdog `MAX_RUN=5400`
- **One item, one agent — no fan-out.** The one exception is the
  refuter, which stays: it guards against confident wrong conclusions,
  which is a different failure from insufficient depth, so raising
  effort does not replace it. It has already caught a wrong ten-row
  video ID table and found 15 verses with missing characters.
- Deploys to dev/qat each iteration when something shipped; never prod.

**Health check:** `tail run.log` — an iteration that ends `rc=0` and
advances the repo hash is healthy.

## Traps that have already bitten

1. **`rm` is on the user's own deny list. Never work around it.** Use
   `mv` to a discard path, or `rmdir` for empty directories.
2. **Never edit `run.sh` in place while it may be running.** bash reads
   a script by byte offset; rewriting it shifts them and the running
   iteration dies with `unexpected EOF`, leaving a stale lock. Write to
   `run.sh.new`, `bash -n` it, then atomic `mv`.
3. **The lock's pid file lives outside the lock directory** so `rmdir`
   alone releases it — a consequence of trap 1.
4. **Rate-limit messages state a reset instant, and it is often already
   past** (the message was written when the run failed). A past instant
   means the limit has lifted — retry now. Rolling it forward waits
   until tomorrow, or, for a dated one, until next year. Both bugs were
   written and caught by test on 2026-08-23; before that the loop woke
   24×/day for three days and failed in ten seconds each time.
5. **Do not write to `/Users/pliu0036/Documents/SeekSparks`.**
6. **`AssetManifest.bin.json` is base64-wrapped binary, not a path map.**
   Grepping it for a filename gives a false negative. Decode it.
7. **`fydt.org` and `www.christiandiscipleschurch.org` refuse datacenter
   IPs** — ECONNREFUSED from this Mac and from GitHub runners alike,
   while the user's phone connects fine. Use YouTube RSS/oEmbed instead
   of scraping those pages. (This Mac is separately behind a Monash
   managed-device stack.)
8. **The `yswords-data` "Refresh songs" daily failure is the audio
   coverage guard working correctly**, not a break. Fix the alert
   fatigue, not the guard.
9. **Data and its test ship together.** Stashing data without its test
   turned four tests red.
10. **Flutter no longer ships an offline service worker.** `flutter
    build web` emits a 784-byte SELF-UNREGISTERING stub and the
    generated bootstrap registers it at scope '/'; `--pwa-strategy` is
    gone from the CLI. The app therefore ships its own network-first
    worker (`web/app_shell_sw.js`) and overrides
    `web/flutter_bootstrap.js` to stop Flutter claiming the scope.
    **Never make that worker cache-first** — this repo has already
    served users a stale shell once, and the self-heal block in
    index.html exists because of it.
11. **Embedded iframes paint ABOVE Flutter widgets on web.** Any
    control drawn over a platform view is in the tree, invisible on
    screen, and catches nothing. Put controls outside the frame's rect.
12. **Never take overlay geometry from the caller's `MediaQuery`.** A
    caller inside a bottom sheet reports the SHEET's box, which put the
    floating player off-screen on 2026-08-24. Measure in the overlay.
13. **The macOS display name is fixed with `CFBundleDisplayName`, never
    `PRODUCT_NAME`** — the latter also names the `.app`, whose path is
    hard-coded in the reinstall script.
11. **A second Claude session shares this checkout and commits blind.** On
    2026-08-23 it ran a blanket `git add` mid-iteration and swept two
    repaired asset files into its own commit. So: stage files by name,
    never `-A` or `.`; check `git status` right before committing; and if
    your work has already landed in someone else's commit, say so in your
    message rather than rewriting theirs. Skip the deploy if `pubspec.yaml`
    or `app_version.dart` is dirty — they are mid-release.

    **A clean tree is not enough — two releases can still overlap, and
    `release_web.sh` is built for it.** On 2026-08-24 the tree was clean, no
    dart process was running and all four sites agreed on 1.4.143, so a
    release started; the other session began its own during the build. The
    first `netlify deploy` of each site returned `JSONHTTPError: no records
    matched 422` from `options.onPostBuild`, the script's own retry got both
    live, and then its **verify step aborted the release** — dev and qat were
    serving 1.4.145, not the 1.4.144 just built — so it never reached the
    China build and never emptied `build/web`. The 1.4.144 bump was swept into
    the other session's "Record the v1.4.145 bump".

    **Nothing was lost, and the reason is the thing to remember: their release
    built from a tree that already held this session's committed asset fix, so
    the fix shipped inside their version.** When a release aborts this way,
    check `version.json` *and* fetch the changed asset from the live site
    before rebuilding — the work is often already live under someone else's
    version number, and rebuilding only risks publishing a bundle older than
    what is there.
12. **`git checkout <sha> -- <path>` stages as well as restores.** Restoring
    an asset to re-run a repair leaves the index holding the *old* blob, so
    a later `git commit` can quietly commit the pre-repair file. Re-`git add`
    after the tool runs.
13. **Ask what a witness CAN express before counting it.** SeekSparks'
    `cuvs-plus.json` strips every quotation mark, so on 2026-08-23 it
    "agreed" with our defective reading at all 15 verses of a punctuation
    class — silence read as confirmation. The printed 1919 is the same
    shape: it has no `：` and no quote marks at all, so it can say a
    quotation begins but never which modern mark opens it. A witness that
    cannot represent the distinction is not evidence either way.
14. **A tool docstring saying "verified" is not evidence that anything was
    verified.** `tools/repair_strongs_tw_ambiguous.py` stated the Strong's
    lexicon had "ZERO manual edits in all 28,377 field pairs (verified by
    re-converting every Simplified field and comparing)". It was committed
    **12 minutes after** the commit that hand-edited 88 of them. The provenance
    half of that sentence turned out to be true; the half that would have
    caused damage was written with identical confidence and was false. Prefer a
    re-runnable audit to a sentence — `tools/audit_lexicon_provenance.py` now
    enumerates the exceptions instead of asserting there are none.
15. **A detector shaped around the defect you already found will only ever
    find that shape.** On 2026-08-24 a queue item said four verses put one
    speaker's words inside another's quotation marks. The detector behind it
    looked for a trapped `說：`, so it could only find a trapped voice that
    announces itself. The real count was **nine**: at 約翰福音 2:7 the trapped
    voice is the NARRATOR — `耶穌對用人說：「把缸倒滿了水。他們就倒滿了，直到
    缸口。」` — and it carries no speech verb at all. The second detector that
    found them makes no assumption about the trapped text: it diffs our
    quotation marks against a witness across the whole corpus and asks where
    the witness closes and we do not. **When a count is going to be published,
    build the second detector from a different premise, not a widened regex** —
    a widened regex is the same premise with more branches.
16. **Never mutate a file while a refuter is reading it.** On 2026-08-23 a
    refuter was launched in the background and the repair was applied while it
    ran; it read the reading text before the change and the tagged corpus
    after, and reported — confidently and with evidence — that the tagged
    corpus had never carried the defect. It had. The claim was only recovered
    by re-checking against `git show HEAD:`. Either finish the edit before
    launching, or tell the refuter to read from a blob. **A refuter reading a
    moving working tree is worse than no refuter**, because its output looks
    exactly like a real refutation.
17. **A second detector built from a different premise over the SAME corpus
    still shares the corpus as an assumption.** Trap 15 said to build the
    second detector from a different premise, and the nine-verse repair did —
    then missed three more verses of the identical defect, because both of its
    detectors read the *reading* text. `assets/tagged/cuvs-yhwh/` is a separate
    transcription line that carries quotation marks in **4,043 verses where the
    reading text carries none**, so a defect can sit on the word-tap sheet and
    be invisible to anything that reads the reading text however cleverly.
    Before publishing a count, ask which FILES the detector opened, not just
    what shape it looked for.
18. **`7a2dc43` corroborates; it is not independent.** Its quotation marks sit
    at the same ideograph offset as the tagged corpus's in **6,461 of the 6,631
    verses where both mark — 97.4%**. One punctuated 和合本 tradition, not two.
    This does not make it useless: when a corpus agrees with its tradition 97%
    of the time, the few places it diverges *and* produces a false reading are
    losses rather than editorial variants. But never write "independently
    confirmed by the witness" — write what the agreement rate is, and name the
    lines that really are independent (balance, the reading text, internal
    parallels).

19. **A `pgrep -f` wait loop matches its own command line and hangs forever.**
    `while pgrep -f "other-build" >/dev/null; do sleep 15; done` never exits,
    because the shell running it has `other-build` in *its* argv and so finds
    itself. On 2026-08-24 that idled a deploy for ~50 minutes while the build
    it was waiting for had already finished. Match on something the waiter
    cannot contain — a pidfile, `pgrep -f "dart compile"`, or capture the pid
    up front and poll `kill -0 "$pid"`. Symptom: `pgrep` says busy while
    `ps aux | grep "dart compile"` shows nothing.

20. **A witness more heavily punctuated than ours turns house style into a
    defect list. Size the class in OUR text before calling any member of it a
    defect.** `7a2dc43` carries 5,856 `「` to our 3,425 and 857 `：『` to our
    548, so a plain diff nominates hundreds of verses. Three of the four edits
    proposed for Revelation 2–3 on 2026-08-24 died this way: leaving level-2
    speech after `說：` unmarked is **331 verses**; a verse-initial `「` the
    witness lacks is a paragraph reopener, **144 verses**; and a `說：『` that
    never closes is **13–18**. Only the fourth — a `「` opening inside a `「`
    opened in the *same verse*, exactly 5 in 31,102 — was a defect. The queue
    entry had asserted the opposite ("leaves a `『` that never closes … a new
    artefact"), which was the assumption nobody had measured.
21. **State the SCOPE of a uniqueness claim, because it is usually doing the
    work.** "These five are the only ones in the Bible" is true per verse and
    false per chapter, where the same shape occurs 603 times. Both numbers are
    real; the sentence is only honest with the window attached.

22. **A finding about a witness may be a finding about YOUR PARSER. Reproduce
    it with a second reader before writing it down.** `audit_note_placement.py`
    anchors `{{verse|…}}` at the start of a line, which is right for the 31,032
    printed verses that begin one. But the page writes a merged pair as
    `{{verse|1|20}} {{verse|1|21}}以色列的長子…` — two markers over one block —
    so exactly 70 markers are mid-line and were silently dropped. That is
    exactly the size of our 「見上節」 class, so on 2026-08-24 the loop was one
    commit from publishing "the print does not number those 69 verses at all",
    when counting every marker gives 31,102 — our verse count exactly, and the
    print merges the same 69 we do. The artifact was shaped like the claim.
    A refuter caught it; nothing in analyze or the suite could have.

23. **The printed-1919 Wikisource witness MIS-DIVIDES verses in three places,
    and in all three OUR division is the standard one.** 歷代志上 22 (the page
    numbers our 22:1 as 21:31 and slides 22:2–19 down to 22:1–18),
    馬可福音 9:43 and 9:45 (each split, the remainder given the number of the
    bracketed variant at our 9:44/9:46), and 約翰福音 7:53 (folded into 8:1 and
    not numbered). KJV, LEB and NASB agree with us in all three. This matters
    because "the print reads …" has decided repairs before: inside those
    chapters the citation is off by a verse, and acting on it would move real
    scripture under real verse numbers. `tools/audit_print_witness.py` holds
    all 43 exceptions; `test/print_witness_alignment_test.dart` pins the
    offline half. 約翰三書 1:15 is NOT a fourth — there the page sides with
    NASB and LEB against KJV, a real variant rather than a defect.

24. **A defect can hide a verse from the allowlist written to catch it — so an
    allowlist's completeness is evidence about the data at the moment it was
    drawn up, and nothing more.** `bible_version_integrity_test.dart` lists the
    verses that are legitimately blank on screen (whole text is a `<note: …>`,
    which renders as an icon). 路加福音 17:36 belonged on it from the start and
    was not there: a stray `」` sat OUTSIDE its note, the sanitised text was
    therefore non-empty, and the verse never registered as blank, so nobody ever
    had to list it. The list read as seven complete cases; it was eight with one
    of them broken. When an exception list looks tidy, ask what would keep a
    genuine member OFF it, not just whether every entry on it is justified.

25. **A census run over the READING assets is not a census of what the reader
    sees.** `assets/tagged/cuvs-yhwh/` is a SECOND, independent transcription
    of the same edition, and `originals_sheet.dart` renders it **verbatim in
    place of** the reader's verse whenever `coversVerse` passes. On 2026-08-24
    the loop counted stray brackets in the reading text, found the class small,
    and only then thought to run the same count over the tagged corpus — where
    14 verses were printing an ASCII `)` or `{` as scripture (詩 115:17
    「死人不能)讚美雅偉」). The guard cannot catch these: `coversVerse` compares
    ideographs only, so it sees a tagged line that has LOST a word and is blind
    to one that has GAINED junk. Whenever a data claim is made, ask **which of
    the two transcriptions it was measured on**, and run it on both.

26. **A repair that DELETES a character can leave the run empty, and an empty
    run is not nothing — it is an invisible tap target.** Removing a stray
    brace that was a whole run left `{"w":"","s":"H1245"}`, which
    `_taggedVerseLine` faithfully rendered as a zero-width `TextSpan` carrying
    a `TapGestureRecognizer`: a lexicon entry opening for a word that is not on
    the line. Analyze was clean and 1,100 tests were green, because the code
    rendered exactly the runs it was given. The refuter found it. Two lessons:
    **after any deletion pass, count what the deletion emptied**; and prefer
    fixing it in the renderer over deleting the Strong's number from the data,
    which here also retired ten such dead targets that had already shipped.

27. **When a docstring cites a witness, name the witness precisely enough to
    be checked — or someone will check the wrong one and conclude you lied.**
    A claim that "the Traditional import writes `〈〉`" was true of git blob
    `7a2dc43` and false of the shipped `cuvs-yhwh-tr.json`, which writes `（）`.
    The refuter checked the shipped file, reported the statement as refuted,
    and it took a re-measurement to establish the sentence had been right and
    merely ambiguous. Cite the blob sha or the file path. Related: a refuter's
    numbers are not privileged either — its "236 uncovered" was the stale
    constant it had read out of the test, and the measured figure was 223.

28. **"This matches what the rest of the file does" is a claim, and it is usually
    the sloppiest sentence in a repair.** The `主*` repair was justified as
    producing "the shape the other 105 asterisk runs use". Only 23 of them used
    it, and six of the 105 were not even tagged with the number the argument
    assumed. The repair was right; the sentence defending it was false, and a
    false sentence in a tool docstring is how trap 14 happened. The fix is to
    quote a **corpus-wide** count you measured (`{"w":"主","s":"G2962",
    "i":["G3588"]}` occurs 125 times) rather than a local impression of the
    neighbours. Related: the first draft of that same repair merged each
    orphaned marker into the whole preceding run, which would have made
    「有人把主」 answer κύριος for 有人把. **Two refuter rounds, two different
    faults — one in the change, one in its justification.**

29. **`cuvs-plus.json` is this edition's BASE TEXT, not a witness — and it has
    been cited as one.** Normalising 雅伟→耶和华 and 〔〕→（), **23,845 of
    31,102 verses are character-identical** with ours; it has 31,103 verses to
    our 31,102 and reads the standard 耶和华 where we read the distinctive
    雅偉, so it is upstream and we are downstream. Any argument of the form
    "our asset and cuvs-plus both read X, so two lines agree" is **one line
    counted twice**. Trap 13 already said it cannot express quotation marks;
    this is the stronger statement — on everything else it is our own ancestor
    agreeing with itself.

    The useful consequence: where the base carries a defect and our edition
    FIXED it, the fix records this edition's editorial policy. Pairing brackets
    across the base gives 9 unpaired marks; the pass resolved 7, completing
    every orphan **opener** and deleting every orphan **closer**. That is how
    士 8:24 / 耶 10:11 were settled — by reading what the editor did the other
    three times, not by asking a witness.

30. **Ask which direction a repair points BEFORE gathering evidence for it.**
    The 〔 item sat in the queue for days stating "an opening bracket was lost",
    and an iteration spent its whole evidence-gathering budget locating where
    the opener belonged. The answer was that no opener was ever lost. A queue
    item's stated premise is a hypothesis written by someone with less evidence
    than you now have — re-derive the direction first, because every witness
    you then consult will be answering the wrong question.

31. **An audit's DISMISSAL is only as wide as the question it asked, and a
    dismissal reads exactly like an all-clear.** `audit_tagged_running_text.py`
    had already found all seven verses where the word-tap sheet printed a
    character of scripture twice — 「耶穌說說：」, 「箭箭」, 「我們我們」 — and
    filed each one as "an artifact on the tagged side; ours is right, do not
    repair towards the tagged copy". Every word true, about the READING text,
    which was the only thing it asked about. It never asked what the sheet
    prints, so seven defects sat inside a table of resolved entries for days.
    Traps 15, 17 and 25 all say to vary the detector; this one is about the
    OUTPUT. When you inherit a triage table, re-read what question earned each
    dismissal — an entry that says "not our problem" is a claim about scope,
    not about the data.

32. **Verify which input production feeds a guard before quoting the guard's
    rate.** `originals_sheet.dart:709` is
    `final verseText = sanitizeForSearch(vo.verse.text);`, and that value —
    not the raw verse — is what reaches `coversVerse`. Two censuses therefore
    exist and both are honest: 270 verses fall back on RAW input, 223 on the
    input the app actually uses, and the 238 in the docstring is neither. A
    refuter once asserted the opposite (that production passes raw) and it
    went into the queue as an open question for days; nobody had read the
    line. One `sed -n '709p'` settled it. The class is bigger than the
    number: on sanitised input 1,153 verses pass the guard while reading
    long, against 113 on raw, because sanitising strips the reader's
    `<note: …>` while the tagged line still inlines it as `〔…〕`.

## Standing rules from the user

- **經文一定要准确，查经的一定要最高 priority 准确.** Anything where the
  app states something untrue about scripture jumps the queue. An
  interface that looks wrong is annoying; one that reads plausibly and
  is wrong gets believed and quoted.
- **繁體 glyph work is deferred to last** — "fantizi 放在最后 do others
  first", 2026-08-18. This overrides the accuracy rule *for that class
  only*; blank verses, wrong citations and mislabelled translations are
  still P0. What already shipped stays shipped.
- Commits use an Opus 5 `Co-Authored-By` trailer, never another model's.
- Credentials are the user's to handle — including the Xcode Apple ID.

## The queue

`docs/autonomous-queue.md` — 78 open items across P0 (scripture
accuracy), P1 (Bible study correctness), P2 (features the user asked
for), P3 (blocked or deferred).

Largest live threads: the 繁體 glyph class (deferred, ~19 items), URL
routing rework (approved, staged, single-agent only), sermon passage
highlighting with verse-level filtering, seven invalid sermon
references, and an Overlay crash on route pop.

**When closing an item, close the original too.** The loop's habit is to
add an `[x] SHIPPED/SUPERSEDED` entry *above* the open original and
leave the original checked-out; three such duplicates were found on
2026-08-23 and would have made it redo shipped work.

## Blocked on the user — do not attempt

1. **prod deploy** — see above.
2. **貴胄 or 貴冑, and the general rule behind it:** when the printed
   和合本 and modern Traditional orthography disagree, which wins? 26
   places turn on it, and so does every remaining glyph instalment.
3. **NASB licensing** — `assets/nasb.json` is 7.2 MB and publicly
   fetchable from both prod sites. The user's position is that NASB
   needs permission; nothing has been done. Ask before investing in
   anything NASB-shaped.
4. **約翰三書 1:14 versification**, **路加福音 23:34a sub-verse label**, and
   **路加福音 21:30** — editorial choices, not inferences. 21:30 joined them
   on 2026-08-24: it is the only one of our 70 「見上節」 stubs the print does
   not also merge, but every witness in our own lineage merges it, so this is
   a division the two editions disagree on rather than a defect. Splitting it
   moves every id, highlight and note anchored to 21:29.
5. **Should the 原文 apparatus set its quotes full-width?** 344 ASCII `"`
   per edition, reader-visible wherever notes render. An edition-wide
   typographic choice, not a defect; a sweep tried and was reverted.
6. **Should the Strong's lexicon be re-set in this edition's Traditional
   orthography?** It is `opencc -c s2t` output, so it writes 爲/着/羣/衆/
   喫/牀 where the Bible text writes 為/著/群/眾/吃/床 — 2,816 positions,
   shown side by side on the word-tap sheet. Same shape as 4 and 5: every
   character is legitimate, nothing false is printed, so it is a choice
   and not a repair. Pinned by test until answered.
