# YsWords — project state

**Read this first when picking the project up.** It records what is true
right now and the traps that have already cost real time. The per-item
work list is `docs/autonomous-queue.md`; this file is the orientation
above it.

Last updated: 2026-08-25.

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

Later the same day the identical pattern repeated on a Strong's-tag
repair: round one added two verses, round two removed them **and**
destroyed the frequency argument the whole list rested on (trap 36).
Round one widens, round two shrinks — twice observed, so budget for two.

**On the third observation it inverted, and that is the case to be careful
about.** On the span repair round one shrank (it killed a false docstring
sentence) and round *two* widened, arguing three more held verses should be
repaired. So the rule is not "round two shrinks"; it is that the two rounds
disagree in some direction and you need both to see it. **Act on shrinking
immediately, record widening and let a later iteration re-derive it** — a
scripture pass that grows on one round's argument, with nothing yet written
against it, is how the count outruns the evidence. See trap 38.

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
| dev | `yswords-dev`, `yswords-cn-dev` | **1.4.154** | push freely |
| qat | `yswords-qat`, `yswords-cn-qat` | **1.4.154** | push freely once dev is verified |
| prod | `yswords`, `yswords-cn` | **1.4.11** | ⛔ never without explicit permission **in the current turn** |

v1.4.154 stops six sermon titles reading as if a word were missing:
"Regeneration and Renewal — ; Foundational Problems" is what a May
cleanup left when it deleted the verse reference and kept the
punctuation, and the sermon list, the detail app-bar, the dashboard and
the reading pane have all been showing it since. Sermon 339 lost words
rather than punctuation — its "Mark 1:"…"Mark 4:" enumerate the marks of
a regenerated Christian and were read as the Gospel — and they are back,
spelled out as v1.4.153 wrote marks five to seven. Verified against the
assets the sites serve, not the repo: on both `yswords-dev` and
`yswords-cn-qat`, `sermons/index.json` has zero titles carrying stranded
`— ;` / `; :`, 339's English title reads "…Debunked; Mark one: Power to
Be Sons of God; Mark two:…", and `sermons/en/339.txt` line 1 matches it.

v1.4.153 stops two sermons claiming to expound passages they never open.
Sermon 339 is "Seven Marks of a Regenerated Christian" and its Part-B
heading enumerates "Mark 5:", "Mark 6:", "Mark 7:" — ordinals, not the
Gospel — while sermon 424's "Is 50% enough?" reached the index as
`Isaiah 50`, because `%` sat inside a `\b` that a following space cannot
satisfy. The tell the queue proposed for the first ("a bare chapter
followed by a colon carrying no digit is a label") fits 94 matches in
this corpus and 91 are genuine, so the repair is in the heading — which
also cures the reader-visible half, since that line is body text and the
Dart `passageRefPattern` linkified it independently (trap 52). Verified
against the assets the sites serve, not the repo: on both `yswords-dev`
and `yswords-cn-qat`, `sermons/refs.json` holds 2,966 keys, `Mark 6` and
`Isaiah 50` are absent, `Mark 5` answers only 140, `Mark 7` only
013/104/CP18, and `sermons/en/339.txt` line 43 reads "Mark five:".

v1.4.152 rebuilds the sermon reference index: 1,294 keys become 2,968 and
282 sermons become 289, because the extractor finally reads the spoken
citations these transcripts use. Eight entries it dropped were false — four
of them an ordinal swallowed from the next book, so sermon 237 was filed
under `John 1` for a sentence that says `1 John 2:18` (trap 50). Verified
against the assets the sites serve, not the repo: on both `yswords-dev` and
`yswords-cn-qat`, `sermons/refs.json` holds 2,968 keys, sermon 237 answers
only `1 John 2:18`, sermon 325 now reaches `2 Kings 13` and `13:20`, and
`Revelation 2` no longer names sermon 238.

**The deploy debt is paid.** v1.4.151 was a debt release rather than a fix of
its own: nine commits had accumulated past the v1.4.150 build and two of them
were user-visible and undeployed — the error reporter learning to drop
synthetic emulator devices, and Standing at the Cross gaining its Mandarin
episode 1. It also carries the asset freshness guard, which matters beyond the
web sites: `release_web.sh` re-copies the reinstall script to
`~/.config/yswords/scripts/`, so per trap 44 the guard stopped being inert the
moment this shipped. Verified: all four dev/qat sites report 1.4.151, both prod
sites still report 1.4.11, and the launchd copy is now byte-identical to the
repo one. v1.4.150 stops a search-result tap leaving a SECOND
reader mounted under the first — `Get.off(() => const HomePage())` is
`pushReplacement`, and search is pushed on top of the reader, so it replaced the
search route and left the original reader alive to overwrite
`MainProvider._activeChapterControllers`. The jump was consumed correctly and
scrolled a list nobody could see. Verified against the bundle the sites serve,
not the repo: all four dev/qat sites report 1.4.150 and `yswords-dev`'s
`main.dart.js` now carries 14 `"/HomePage"` route-name literals where 1.4.149
had 8. v1.4.149 stops the word-tap sheet answering 39 words
with a particle inside their own span — 約翰福音 3:5's 神 answered ὁ, *the*, and
θεός was reachable nowhere in the verse; 使徒行傳 2:29's 弟兄們 answered ἀνήρ.
Verified against the assets the sites serve, not the repo: on both `yswords-dev`
and `yswords-cn-qat`, `john.json` 3:5 stores `{"w":"神","s":"G2316"}` and
`{"w":"的国。","s":"G932"}`, `matthew.json` 6:8 stores `G3962`, `acts.json` 2:37
stores `G80`, `jeremiah.json` 52:30 stores `H6242`, and `isaiah.json` 17:3 stores
`H669` with no `i`. v1.4.148 stops the word-tap sheet answering
六 runs with the wrong word of their own verse — 民數記 11:8's 百姓 no longer
returns H8081 שֶׁמֶן, *oil*, and 使徒行傳 12:24 / 20:32's 神 no longer returns
the bare definite article. Verified against the assets the sites serve, not the
repo: on both `yswords-dev` and `yswords-cn-qat`, `tagged/cuvs-yhwh/numbers.json`
11:8 stores `{"w":"百姓","s":"H5971"}`, `acts.json` 12:24 and 20:32 both store
`"s":"G2316"`, `jeremiah.json` 47:4 stores `H3605`, `1_corinthians.json` 1:14
stores `G2316` and `1_chronicles.json` 16:39 stores `H1116`. v1.4.147 stops the
word-tap sheet printing a
character of scripture twice in seven verses — verified against the assets the
sites serve, where 馬太福音 9:28 now reads 「耶穌說：」 and none of 若若, 箭箭,
我們我們, 敵我敵, 你要要, 未未曾 survives. v1.4.146 removes the two orphan `〕` that
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

**prod is 138 versions behind and it is not an oversight.** Every prod
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

33. **A coverage census must count what the RENDERER reads, not what the data
    records.** A tagged run's `i` (implied words) is parsed into
    `TaggedRun.implied` and **no widget in `lib/` ever reads it**. So a census
    that treats `i` as coverage is measuring the file; the reader can only
    reach a number that is some run's `s`. On 2026-08-24 that one substitution
    took a misaligned-tag census from **11 to 71** and pulled in 約翰福音 3:5
    and 馬太福音 22:37, where 神 is tagged G3588 and θεός is displayed nowhere
    in the verse. Trap 25 said to ask which transcription a claim was measured
    on; this is the next question after it — **which FIELD does production
    display?** `test/strongs_alignment_test.dart` now fails if any widget
    starts reading `implied`, because that would invalidate the census.

34. **Decompose a defect count before publishing it, or the headline will be
    false in both directions at once.** "71 misaligned tags" was wrong twice
    over: 53 of them are one importer convention repeated (the right number is
    already in that run's own `i`; `s` went on a particle inside the span), so
    it is not 71 mistakes — and it is simultaneously a FLOOR, because the
    detector only admits run texts occurring ≥20 times with a ≥95% dominant
    number, so 馬可福音 6:33's own 城的 cannot be seen by it. A number that is
    both an overcount and an undercount needs its parts named, not a caveat.

35. **The refuter's arithmetic can beat yours on a figure you actually
    computed.** Trap 27 says a refuter's numbers are not privileged. That
    stands, but the converse bit on 2026-08-24: it said 7 hits displayed a
    number absent from the verse, my script said 3, and **7 was right** — I had
    bucketed the hits exclusively when the categories overlap, so four were
    silently filed under the earlier branch. Re-measure the disagreement
    orthogonally rather than assuming the code wins because it is code.

36. **"Rare" is not "wrong". Before a rarity argument decides anything, count
    how many things in the corpus are equally rare.** Six Strong's-tag repairs
    were justified on 2026-08-24 by the fact that each (Chinese run text,
    number) pair occurred **exactly once** in 31,102 verses while the number
    being written carried the same run text hundreds of times. It sounds
    decisive. **367 runs have that property**, and 約伯記 3:2 has it and is
    correct — its lone run 说： is tagged H6030 עָנָה, *answered*, because the
    Hebrew is וַיַּעַן אִיּוֹב וַיֹּאמַר and the Chinese collapses the pair into
    one verb. The argument did not even cover two of the six it was advanced
    for. This is trap 20 in a new coat: there the witness's house style
    nominated hundreds, here rarity does. **The repairs were right; the reason
    was worthless**, and a worthless reason in a tool docstring is how trap 14
    happened. Each entry had to be re-grounded on its own verse.

    The refuter round that broke it was the SECOND one, and it also broke two
    verses the FIRST round had persuaded me to add. Round one widening the
    scope and round two shrinking it is now the observed pattern twice running.

37. **A watchdog kill leaves an unverified scripture repair in the working tree,
    and it looks exactly like finished work.** On 2026-08-24 the 15:19 iteration
    was killed at `MAX_RUN=5400` with 39 tagged-asset edits applied, a 20 KB
    repair tool untracked, and nothing committed. The next iteration inherits a
    dirty tree with no note saying whether it is half-applied or done — and trap
    11's second session commits blind, so an unverified edit to scripture data
    can be swept into someone else's commit and deployed. **Read `run.log`
    before trusting or discarding a dirty tree**: it names the iteration that
    left it.

    The cause was in the tool. `original_numbers()` re-read
    `assets/originals/<book>.json` on **every call**, and the completeness gate
    calls it once per verse: 31,102 loads at ~15 ms is ~10 minutes for one gate,
    inside a 90-minute budget it did not have. Caching the file took the whole
    dry run from that to **2.9 s**. Any audit that walks the corpus and opens a
    per-book file inside the loop has this bug; check for it before blaming the
    watchdog.

38. **Round two WIDENED, which is the dangerous direction, and the right answer
    was to record it rather than act.** Traps 20/36 established "round one
    widens, round two shrinks" — twice observed. On the span repair it inverted:
    round one found a false docstring sentence and one gate-consistency
    question, and round *two* argued three more HELD rows should be repaired.
    Widening on a single round with nothing arguing against it is how a
    scripture pass grows past its evidence, so the three went into the queue
    with the evidence for and against, and the 39 that both rounds endorsed were
    committed. **The asymmetry is deliberate: shrinking is safe to act on
    immediately, widening needs another round.**

39. **"Mechanical, no per-verse judgement needed" is a claim about the data, and
    a queue item is the last place that should be trusted.** The 53
    `spans-the-word` runs were queued as one pass: the right number already sits
    in the run's own `i`, so promote it. That is a *structural* description, and
    it is true of all 53 — but where the Chinese spells BOTH words the old `s`
    is **partial rather than false**, and swapping trades one partial answer for
    another while writing "this text does not render it" about a character that
    plainly does. 王下 3:27's 的長子 spells בֵּן in 子 and בְּכוֹר in 長. Adding
    that gate cut 53 → 39. A structural definition can enumerate a class; it
    cannot tell you the members are wrong.

40. **A promotion pass has a cost, and "demote the particle" hides it.** Because
    `i` is inert — no widget reads it (trap 33) — promoting a run's `s` leaves
    the displaced number reachable by no tap anywhere in its verse. That
    happened in **30 of the 36 verses** the span pass touched, and **11 of the
    30 were content words, not particles**: ἀνήρ, פֶּה, מִסְפָּר, עֵת ×2,
    מִשְׁפָּחָה, שָׁלֹשׁ, בֵּן ×3. A draft said the reader "only gains";
    約翰福音 3:5 disproves it, since BOTH 神 and 的国。 showed G3588 beforehand,
    so ὁ was reachable twice while θεός and βασιλεία were reachable nowhere.
    The trade is worth making — a tap on 弟兄們 must answer ἀδελφοί, not ἀνήρ —
    but it is a trade. Also: three counts were in play (36 verses, 39 runs, 30
    losses) and a draft mixed them into "30 of the 39 runs"; the refuter's
    arithmetic was right again (cf. trap 35).

41. **A route pushed by `pushPage` is named `/HomePage` on native and
    `minified:<mangled>` on release web, so any stack search by route name
    is correct on five targets and silently wrong on the sixth.** dart2js's
    `Type.toString()` falls back to `"minified:"+a` for anything absent from
    `mangledGlobalNames`, and the shipped bundle's table holds only the ten
    core types. `navigateToReader` finds the existing reader by name, so on
    web it walked past readers pushed without an explicit `routeName`, popped
    them, and cold-mounted a replacement. Four call sites already passed the
    name; eight did not. **Never let a web route name come from
    `runtimeType`** — `test/reader_route_leak_test.dart` now fails if a
    `pushPage(const HomePage())` omits it.

42. **`Get.off` is `pushReplacement`, and in this app the reader is almost
    never the top route.** Search, Library and the lexicon are all pushed ON
    TOP of the reader, so `Get.off(() => const HomePage())` replaced the
    search route and left the original reader mounted underneath — two panes
    on the one `MainProvider`, which is created above the navigator in
    `main.dart:100`. This was found, fixed and named in v1.3.7 for Library
    and four other call sites kept it for three months. The lesson is about
    the fix, not the bug: **when a helper is written to be canonical, grep
    for the pattern it replaced on the same day**, because a helper cannot
    protect a path that does not call it.

    The mechanism sentence in the original queue item was wrong and shipped
    that way for a day: the panes do NOT share an `ItemScrollController` —
    each `_ChapterPage` mints its own — they share
    `MainProvider._activeChapterControllers`, a last-writer-wins slot that
    `mp.itemScrollController` forwards through. `_isLivePane` already stopped
    the covered pane consuming the jump, so the live pane consumed it
    correctly and scrolled a list nobody could see. A wrong mechanism aims
    every subsequent fix at the wrong object.

43. **A build-provenance marker is only as fine-grained as the thing that
    moves it, and "verified" printed at the wrong granularity is a lie with
    a tick next to it.** The APK freshness guard greps `lib/*/libapp.so` for
    `kAppReleaseTime`'s source stamp — sound, and measured: the on-disk APK
    carries `2026-08-24T02:16:51Z` in all three slices, reads
    `versionName=1.4.147`, and `4ac245c` is the commit that wrote that stamp.
    But the stamp moves only when `bump_version.sh` runs, and the 04:00
    launchd reinstall does **not** bump (`BUMP_VERSION` unset in the plist).
    So the guard is blind exactly between releases — which is the window the
    nightly builds in, and the window the three phantom Mi Pad reports came
    out of. The first draft's comment said "compiled from the current
    source"; that sentence was false and the refuter killed it. The check
    was kept (it is real across bumps) and made to **print the drift** —
    how many commits touched `lib/` since the stamp — so the `✓` cannot be
    read as an all-clear. Ask what interval your marker resolves, not just
    whether it is present.

    Two more from the same round, both in code that was being kept rather
    than written: `pm list packages | grep -q "com.example.yswords"` matches
    `com.example.yswords.cn` too, so a device holding only the China flavor
    reported the intl install "verified present"; and the guard depends on a
    widget still rendering the stamp, because an unread const is shaken out
    of the AOT snapshot and the guard would then refuse **every** build.
    A guard whose failure mode is refusing everything needs its own test.

    A second refuter round found the disclosure itself was conditional on a
    `git log -S` lookup that returns empty right after a bump — because
    `bump_version.sh` does not commit — so the very state the script's own
    advice created was the state it stayed silent in. Also: `git rev-list
    --count` undercounts across merges without `--full-history`, and
    uncommitted `lib/` work is in the build while being in no commit at all.
    **A disclosure with a silent branch is not a disclosure.**

    That round also produced one confident claim that was itself false — that
    a 13:42 intermediate `libapp.so` held stale 1.4.147 bytes, when the
    v1.4.147 bump was 12:34 and v1.4.148 was 14:48, so 1.4.147 was correct
    for that moment. The refuter is a source of hypotheses, not verdicts;
    check its timeline arithmetic before acting, and when it is wrong say so
    in the queue rather than quietly dropping it.

44. **`tools/yswords-ios-reinstall.sh` is not the file launchd runs.** The
    plist points at `~/.config/yswords/scripts/yswords-ios-reinstall.sh`, a
    full copy that exists because macOS TCC blocks the launchd-spawned shell
    from opening anything under `~/Documents`. `release_web.sh:63-69` re-copies
    it on every release, so it self-heals — but a change to the repo script
    is INERT until then. The two were byte-identical before this change
    (`cmp`), so the older note claiming they had drifted was stale.

45. **A plugin's "your Activity must extend X" requirement fails SILENTLY
    and expensively: audio_service answered a plain `FlutterActivity` by
    building a SECOND FlutterEngine and running `main()` again.** One
    process, two isolates, two full app boots — Firebase initialised
    twice, every startup service ran twice, and the lock screen was wired
    to the second, idle copy while the user's taps drove the first. It
    had shipped that way since Songs v2 (2026-08-09) and nothing in
    analyze, the suite, or any log the user sees could show it. Two
    lessons. **First: a native misconfiguration is invisible to every
    Dart-side gate, so when a package documents a platform requirement,
    pin it with a source guard** (`test/android_audio_service_engine_
    test.dart` reads MainActivity.kt). **Second: the way to find it was
    to print a marker in `main()` and count the lines** — three minutes
    on an emulator settled what an hour of reading the plugin source only
    made plausible. The emulator AVD `spark` plus
    `/opt/homebrew/share/android-commandlinetools/emulator` works when
    the Mi Pad's wireless ADB is down, which it usually is.

    The refuter earned its keep twice more here. It broke "the media
    session was entirely dead" — the headless engine never receives
    `onAttachedToActivity`, so ITS `AudioService.init` succeeded, making
    the defect a phantom session rather than none. And it broke the
    safety claim: with the engine now provided by the host,
    `shouldDestroyEngineWithHost()` is false, so the engine outlives the
    activity — which collides with this app's icon swap deliberately
    finishing the task. Queued as a device check rather than waved off.

46. **Reproducing a crash on purpose fires the PRODUCTION error reporter,
    and it mails the user.** On 2026-08-25 this loop provoked the
    SQLITE_BUSY bug 11 times on an emulator to prove the duplicate-engine
    fix. Every one was a real report; four identical emails reached
    lsy95112@gmail.com mid-run, and the user asked why crash mail kept
    arriving. A parallel session had to trace them back to this Mac
    (version 1.4.147, OS `android sdk_phone64_arm64-userdebug`, screen
    0x0 because the emulator is `-no-window`) and teach `_send` to drop
    synthetic devices (`e381442`). Two things follow. **Before
    deliberately reproducing a crash, ask what the app does with it** —
    this one has had an error reporter wired to `FlutterError.onError`,
    `PlatformDispatcher.instance.onError` and `runZonedGuarded` the whole
    time. And the guard is **baked into the APK**, so any build made
    before `e381442` — including every APK now sitting in
    `build/app/outputs/` and `/tmp` — still mails. Shut the emulator down
    when the experiment ends rather than leaving it to idle.

    The silver lining is evidence: it proved the async path from
    `CacheStore`'s unawaited `repo.open()` to an email runs end to end,
    which the write-up had been about to record as merely inferred.

47. **A concurrent session can move HEAD and rewrite the standing rules
    underneath a long iteration.** This one started at `9d16cf3` and
    finished at `058eaa9`, three commits later, and one of them reversed
    the commit-trailer rule the loop's own brief still states ("use the
    Opus 5 `Co-Authored-By`" → **no trailer on anything**, user, 2026-08-25).
    An `Edit` failing with "file has been modified since read" is the
    cheap warning; take it as a signal to re-read `PROJECT_STATE.md`'s
    rules and `git log` before committing, not just to re-read the one
    file. Where the brief and this file disagree, this file is newer.

48. **"It is a copy" is not what makes an mtime untrustworthy — the SKIP RULE
    of whatever does the copying is.** Both candidates for the Android
    freshness marker are copies. `jniLibs/<abi>/libapp.so` is filled by
    Gradle's `copyJniLibs<Variant>`, a `Sync` task, and Gradle is up-to-date
    per TASK, so one changed input re-stamps the whole set: measured
    2026-08-25, `jniLibs/arm64-v8a/libpdfium.so` carried mtime `01:00:18`
    over bytes byte-identical to a source last written `2026-08-24T07:26:50`.
    `<abi>/app.so` is `AndroidAotBundle.copySync`, and flutter's build_system
    skips per TARGET on the input's md5, with the AOT app.so as that target's
    only input — so an unchanged AOT leaves it alone (two identical builds
    78s apart: the second returned in 1m18s with every mtime and sha256
    unchanged). Same file operation, opposite trustworthiness.

    Three further lessons from the same round. **A `find` over a source
    directory is not the set of inputs to a build**: `lib/.DS_Store` exists
    and Finder rewrites it whenever it likes, and 22 of 234 `lib/*.dart` are
    not Android inputs at all (17 `*_web.dart` conditional-import stubs), so
    a web-only commit would have made the guard refuse a correct build every
    night. `flutter_build.d` — the depfile the build itself wrote — is the
    honest source set. **"Re-runs iff X" is almost always too strong**:
    `computeChanges` also invalidates on outputMissing / outputChanged /
    buildKeyChanged, so the corrected claim is that a fresh mtime proves
    flutter ran the AOT chain to completion this build, not that the bytes
    encode current source — no mtime can prove that. **And a refuter's
    preferred alternative can be worse than what it refuted**: round two
    argued for measuring `.dart_tool/flutter_build/<hash>/<abi>/app.so`,
    which is one step further from the APK — if flutter recompiled and
    Gradle never copied the result it would read fresh while the installed
    APK was stale, the exact failure the guard exists for. Declined and
    recorded rather than quietly dropped. Measure as close to the shipped
    artifact as the skip rules allow.

49. **"Widen the filter" and "add a second check" look like the same
    edit and are opposite ones. The question is not what you FILTER, it
    is what you COMPARE AGAINST.** A queue item guessed the AOT
    freshness guard could cover assets by widening its depfile prefix
    past `lib/`, since the depfile lists 1093 assets against 212 `lib/`
    inputs. It reads as nearly free. But that guard compares against
    `<abi>/app.so`, and no asset is an input to anything that writes it:
    `kernel_snapshot_program.d` has 2780 inputs and **zero** under
    `assets/`. Assets feed a separate target whose outputs are the
    copies under `flutter_assets/`. So the "free" version would have
    **refused correct builds on 129 of this repo's 1266 commits** — the
    asset-only ones, which is precisely what this loop ships. Pick the
    output that the input actually feeds, then ask what filter it needs.

    Two more from the same round, both about a ✓ rather than a ✗.
    **`flutter_build.d` escapes a literal space as `\ `** — depfile.dart
    does `path.replaceAll(r' ', r'\ ')` — so `tr ' ' '\n'` shears such a
    path into fragments that exist nowhere, and the draft printed
    **"✓ verified"** over a genuinely stale asset it had silently
    dropped. The live tree could never have caught it: the only
    space-containing asset files here are under `assets/fonts_backup/`,
    which pubspec does not declare. And `cmp` exits 0 identical, 1
    different, **>1 could not read** — folding the third into the second
    refuses the unattended nightly while naming the wrong cause. Both
    hazards produce output that reads like success or like a real
    finding; neither is visible to analyze or the suite.

    The useful positive result, since a guard needs a signal to exist:
    that asset target copies with Dart's `File.copy`, and macOS
    preserves the source mtime through it — **1093 of 1093 inputs equal
    to their bundled copy to the nanosecond, on distinct inodes**, so
    they are real copies, not clones. "Source newer than its own copy"
    is therefore a valid staleness signal, and `cmp` on the handful that
    trip it removes the false-alarm class the `lib/` check has to live
    with.

50. **A book name at the end of a sentence swallows the ordinal of the next
    one, and the wreckage is a perfectly valid reference.** `extract_sermon_
    refs.py` tolerates an abbreviating full stop (`Matt. 5:3`), so "…only in
    the letters of John. **1** John 2 and verse 18" parsed as *John 1* and
    filed sermon 237 under a chapter it never opens. Three more shipped the
    same way — `1 Peter 1`→765 from "1 Peter. 1 Peter chapter 4",
    `Revelation 2`→238 from "the book of Revelation. 2 John, verse 7". None
    is detectable by a validity check: every one resolves against `kjv.json`,
    which is exactly why they sat in the index. **The fix has to live inside
    the pattern, not after the match** — a post-hoc `continue` leaves the
    ordinal consumed, so the scan resumes mid-name and re-reads the Gospel.
    A lookahead makes the engine retry from the digit and find `1 John`.

    Two more from the same round. **A coverage diff that clears a lost key
    because the sermon reappears elsewhere in that chapter is asking whether
    the sermon is still reachable, not whether it was ever right.** 348 pairs
    vanished on regeneration; 340 were a bare chapter key re-filed onto verse
    keys, and all 8 of the remainder turned out to be false positives being
    *cured*. Reading each against the transcript is what separated them —
    the aggregate could not. And **"is this a loss?" has a third answer
    besides yes and no**: `Mark 1`–`Mark 4` → 339 were "the Nth **mark** of
    a regenerated Christian", and their source text had already been deleted
    by an earlier title edit, so no regeneration could ever have reproduced
    them. `Mark 5`–`Mark 7` survive and are the same false-positive class,
    live in the shipped index today (queued).

51. **A prose-widening fix and the false positive it admits arrive one
    refuter round apart, and the second is invisible in the aggregate.**
    Round one showed the pattern could not read a comma after a book name,
    hiding sermon 325's central exposition behind an aside sixty lines away.
    The comma fix added 26 keys — and one of them, `John 2:19` for sermon
    343, came from "the first letter of **John**, chapter 2 and verse 19",
    an appositive the newly-permissive comma let the pattern reach across.
    +26 keys reads like unmixed good news at every level above the
    individual sentence. Trap 38 said widening needs another round; this is
    what the other round is *for*. Note the corpus decided the shape of the
    guard: of the 14 "…of ⟨Book⟩, chapter N" phrasings, **13 are correct**
    ("the book of Revelation, chapter 21"), so a blanket rule would have
    destroyed twelve real references to cure one. Only *John* is ambiguous,
    because it is the one book name shared by a gospel and three letters.

52. **Two independent patterns read the same sermon text, so a fix in the
    extractor only ever cures half the defect — and `\b` after a non-word
    character is a silent no-op.** Sermon 339's heading "Mark 5: Does Not
    Sin" was indexed as the Gospel by `scripts/extract_sermon_refs.py`
    AND rendered as a tappable link by `passageRefPattern` in
    `lib/utils/passage_localizer.dart`, which is a separate regex in a
    separate language that nothing keeps in step. Only line 1 of a sermon
    is dropped as the title (`sermon_detail_page.dart:829`), and this
    heading is line 43 of a concatenated Part A + Part B, so it was body
    text. **Repairing the DATA fixed both surfaces; repairing the
    extractor would have fixed one and left the visible one alone.** Ask
    how many readers of a string there are before choosing where to fix
    it.

    Two more from the same round. **The `\b` hazard**: `_UNIT_AFTER`
    ended `…|percent|%)\b`, and `%` followed by a space is not a word
    boundary, so the whole guard was blind to percentages — "Is 50%
    enough?" (the verb, plus the alias for Isaiah) became `Isaiah 50`.
    `Isaiah 100` and `Isaiah 99` in the same sentence were stopped only
    by the canon check, so `exists()` was the only thing standing there.
    And **trap 20 again, in its sharpest form yet**: the queue item
    proposed "a bare chapter followed by a colon carrying no digit is a
    label" as "the obvious tell". It fits 94 matches in this corpus and
    **91 are genuine** — a colon before a quotation is how a preacher
    cites. The fallback rule ("ignore `# ` headings") was 19 genuine
    against 3 false. Both are now pinned by example in
    `test/sermon_refs_resolve_test.dart`, because a rejected repair that
    is not written down gets re-derived.

53. **"Not user-visible" in a queue item is a claim about ONE reader, and
    a string usually has two.** Sermon 339's mangled H1 was written down
    as invisible because `sermon_detail_page.dart:825-829` drops line 1
    of the body. True — and beside the point, because
    `scripts/ingest_sermons.py` copies every H1 into `index.json`'s
    per-locale `titles`, which `Sermon.localizedTitle` renders in the
    sermon list, the detail app-bar, the dashboard and the reading pane.
    Six sermons had been showing English readers "Regeneration and
    Renewal — ; Foundational Problems" for four months behind that
    sentence. Trap 52 is the same lesson from the other side: there two
    readers of one string meant fixing the extractor would only cure
    half; here it meant a defect was filed as cosmetic.

    Two more from the round. **A detector built from the defect you can
    see finds only what has punctuation in it**: the repair's own scan
    (stranded `— ;`, `; :`, `( )`) found 16 strings and called that the
    class; the same cleanup pass also left bare numerals ("— 3 —", the
    tail of a range whose head was deleted), orphan 章, and stranded
    commas — 36 more strings in 9 more sermons, all invisible to it
    because they are ordinary characters. And **"regenerating the
    derived file produced no diff" proves only what that script reads**:
    `extract_sermon_refs.py` came back byte-identical, which validates
    the H1 edits and says nothing whatever about the `titles` map, since
    the map is not one of its inputs.

## Standing rules from the user

- **經文一定要准确，查经的一定要最高 priority 准确.** Anything where the
  app states something untrue about scripture jumps the queue. An
  interface that looks wrong is annoying; one that reads plausibly and
  is wrong gets believed and quoted.
- **BUT on 2026-08-24 the user reordered the WORK, not that rule:**
  "第一个可以推到后面去做，先把功能性的和系统bugs issues之前提到的全部
  先做完" / "P2 P3先做完". Tier order is now: device-reported BUGS → P2 →
  P3 → P1 → P0 → 繁體 glyph class. **The order of the queue FILE is no
  longer the order of work**; the banner at the top of
  `docs/autonomous-queue.md` and the loop's `prompt.md` both carry it,
  and they must be kept in step. One carve-out keeps P0 precedence: a
  defect that **omits or blanks actual verse text** — a reader unable
  to see scripture that should be there is data loss, not polish. The
  reason for the reorder is in the numbers: P0 grew 76 → 83 open in a
  day, because auditing discovers faster than it repairs.
- **繁體 glyph work is deferred to last** — "fantizi 放在最后 do others
  first", 2026-08-18. This overrides the accuracy rule *for that class
  only*; blank verses, wrong citations and mislabelled translations are
  still P0. What already shipped stays shipped.
- **No `Co-Authored-By` trailer on anything — commit or PR.** The user,
  2026-08-25: "我要把coauthored全部去掉". The previous rule ("use the Opus
  5 one, never another model's") had quietly become unfollowable: this
  loop invokes `--model claude-opus-5`, but the token does not always
  resolve to that model, so 123 of the last 342 trailers said Opus 4.7.
  The only options were a trailer that lies about who wrote the commit
  or no trailer, and the user chose none. Enforced globally by
  `attribution: {commit: "", pr: ""}` in `~/.claude/settings.json`, so it
  holds for any session on this Mac, not only the loop.
- Credentials are the user's to handle — including the Xcode Apple ID.

## The loop checks CI now — and why it has to

Since 2026-08-25 the loop's `prompt.md` opens every iteration by asking
`gh run list --branch main --limit 1` whether CI is green, and closes it
by watching its own push to a conclusion.

The reason is a measured failure, not a policy preference. On 2026-08-24
Flutter CI was red for **six hours across roughly a dozen iterations**,
and every one of those iterations honestly reported "analyze clean, all
tests green" — because they ran on this Mac and CI runs on
`ubuntu-latest`. Both failures were things the Mac had and the runner
did not:

- `tools/yswords-ios-reinstall.sh` reads mtimes with `stat -f '%m %N'`,
  which is BSD. GNU coreutils wants `-c '%Y %n'`, and every call site
  sent the difference to `/dev/null`, so the guard reported "could not
  read mtimes" and returned 0. The guard was fine in production (it only
  runs here); what was broken was the ability to test it.
- `apk_freshness_guard_test.dart` executes the guard under `zsh`,
  deliberately, because that is the script's own `#!` line.
  `ubuntu-latest` ships bash and dash, not zsh.

The user learned about it by forwarding a pile of failure emails. That
is the loop's single largest blind spot: **a local green is evidence
about this Mac, not about the shipped artifact.** The same class
produced three Mi Pad bug reports (a Gradle build that reused stale
artifacts) a day earlier.

When a CI failure is environmental, fix it so the test RUNS on Linux.
Never weaken the test or skip it on CI — that buys green by testing
something the shipped code never does.

## The queue

`docs/autonomous-queue.md` — 84 open items across BUGS (reported from
the user's own devices — the top tier since 2026-08-24), P0 (scripture
accuracy — **deferred to last**), P1 (Bible study correctness), P2
(features the user asked for), P3 (blocked or deferred). Read the
banner at the top of the file before picking anything: the file is
ordered P0-first for historical reasons and that is NOT the work order.

**BUGS holds one open item, and it is not startable right now.** The
`SQLITE_BUSY` crash was reproduced on demand on 2026-08-25 and closed:
10/10 launches crash with the duplicate engine, 0/10 without, with a
one-line control holding the Dart constant. What remains is the
follow-on check that the now-cached FlutterEngine outliving
MainActivity does not strand the launcher-icon swap — and that one
needs the Mi Pad, which had no device attached at all on 2026-08-25.
The recorded list of three holes in the AOT freshness guard was closed
the same day for its costed-out member (assets); `lib/` edits landing
mid-build, mtime-moved-but-content-did-not, and `pubspec.yaml` /
dart-defines / `android/` Kotlin remain uncovered and are written down.

**The Android nightly now has a freshness guard that carries no version
in it**, so Dart landing between releases is covered for the first time —
`aot_postdates_dart_source()` refuses the install when a Dart file the
build declared as an input post-dates the AOT snapshot. Per trap 44 it
is **inert until the next release**, because launchd runs the copy at
`~/.config/yswords/scripts/` and `release_web.sh` is what re-copies it.

Largest live threads: the 繁體 glyph class (deferred, ~19 items), the 14
`spans-the-word` Strong's tags still held (39 of the 53 shipped 2026-08-24;
the remaining 14 each need a per-verse call — see trap 39), URL routing rework (approved, staged, single-agent
only), sermon passage highlighting with verse-level filtering, seven
invalid sermon references, and an Overlay crash on route pop.

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
