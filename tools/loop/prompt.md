# YsWords autonomous iteration

You are working alone on the YsWords repo at
`/Users/pliu0036/Documents/yswords`. No human is watching this run.
Do **one** meaningful piece of work, verify it, commit it, and stop.

## The queue

`docs/autonomous-queue.md` **inside the repo** is the work queue — not
any copy under `~/Library`. It lives in the repo so that ticking an item
is a commit, which makes the progress of this loop readable in `git log`
by someone who was never here.

Take the **topmost unchecked item you can actually finish this hour**.
If the top item is blocked on the user, say so in the log and take the
next one — do not sit idle, and do not attempt anything under
"Blocked on the user".

When you finish, tick it `[x]` with a one-line result. When you discover
something new, **add it to the queue** rather than fixing it inline and
forgetting it.

## The one rule that outranks the queue

The user's standing instruction:

> 经文一定要准确,查经的一定要最高 priority 准确

Any defect where the app **states something untrue about scripture** —
a missing verse, a wrong reference, a wrong Strong's number, a
misattribution — jumps to the front whatever else is queued. An
interface that looks wrong is annoying. An interface that reads
plausibly and is wrong gets believed and quoted.

Two habits that go with it:

1. **Measure before concluding.** When you find one defect, ask "how
   many more are there" and count the whole corpus before reporting.
   The last time this was skipped, three defects turned out to be ~120.
2. **Never invent scripture.** Repair labels, ordering and structure
   using an independent copy as evidence. If the only way to fix a
   verse is to write it, stop and queue it for the user instead.

## Guard rails

- **dev and qat only. NEVER deploy prod.** Both prod sites need explicit
  human permission per deploy. `./tools/release_web.sh` without
  `--include-prod`, or the per-site netlify deploy the repo already uses.
- **Do not write to `/Users/pliu0036/Documents/CodingProject/SeekSparks`.**
  It has its own hourly loop; reading is fine, writing collides.
- Do not add a `Co-Authored-By` trailer other than the Opus 5 one the
  repo already uses.
- Do not commit secrets. `.env` and `~/.config/yswords/secrets/` stay out.
- If a change needs a new third-party dependency, weigh bundle size
  across all six targets and say so in the commit; if it is large or
  risky, queue it for the user instead of adding it.

## Definition of done for one iteration

1. `flutter analyze` — **check the exit code**, not the output. An
   info-level lint turns CI red and greps for "error" will not see it.
   Flutter is not on PATH here: use `/Users/pliu0036/flutter/bin/flutter`.
2. `flutter test` — the whole suite, and it must pass. If you changed
   behaviour, add or update a test that would fail without your change.
3. Commit with a message that explains **why**, including what the
   defect actually was and how you know. Push to `origin main`
   (fetch/rebase first — another machine works on this branch).
4. If the change is user-visible, build and deploy dev + qat, then
   verify `version.json` on all four sites.
5. Update TODO.md.

If the work does not reach a green state, **commit nothing**, write what
you learned into TODO.md, and stop. A half-finished commit is worse than
no commit.

## Things this repo has already learned the hard way

- Netlify serves a **200 with index.html** for a missing file, not a 404.
  Anything fetched and then parsed must reject HTML first.
- `flutter build web --output=build-cn` **empties `build/web`**. Build
  China-mode FIRST, intl second, and check `build/web/main.dart.js`
  exists before deploying — a shell without it deploys a blank app.
- Any inline `<script>` edited in `web/index.html` should be extracted
  and run through `node --check`; a stray brace silently disabled the
  whole self-heal script on four live sites.
- Tests prove code runs, not that data is true. Data defects need a
  data check.
