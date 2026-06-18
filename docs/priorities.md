# YsWords — open priorities

Living list of things to address next. Append rather than rewrite.

> ⚠️ **RELEASE POLICY**: dev + qat free to push; **prod requires explicit user instruction in the current turn**. See [`release-policy.md`](release-policy.md).

## High-ROI infrastructure (deferred from 2026-05-10 robustness review)

These were identified as the highest-ROI gaps after v1.2.35. None are blocking, but each closes a real risk.

1. **GitHub Actions CI workflow** — RESOLVED in v1.3.22.
   `.github/workflows/flutter-ci.yml` runs `flutter analyze` +
   `flutter test --reporter expanded` on every push to main +
   every PR. Pinned to Flutter 3.44.2 (matches local dev env).
   ~15 min runtime. Pub cache is reused across runs.

2. **Error monitoring on prod** — RESOLVED in v1.3.21. New
   `netlify/functions/errorReport.mjs` accepts POST with
   error / stack / version / platform / locale / route /
   breadcrumbs / device info and emails via the existing
   Resend account (reuses `RESEND_API_KEY` + `FEEDBACK_TO` env
   vars). Client side: `lib/services/error_reporter.dart` hooks
   `FlutterError.onError`, `PlatformDispatcher.instance.onError`,
   wraps `main()` in `runZonedGuarded`. `BreadcrumbObserver`
   `NavigatorObserver` auto-records route push/pop trail. Works
   on every platform we ship (web / iOS / macOS / Android).
   60-second per-(session × stack) dedupe so a render loop
   can't flood the inbox.

3. **Lamentations 5:21/5:22 data-quality bug** — flagged in `v1.2.32`'s
   notes. `cnv.json` has both verses set to a hybrid that merges
   their content, and `cnv-tr.json`'s 5:22 carries a non-canonical
   paraphrase. Needs a verified 新譯本 CNV source to correct. ~30 min
   when a source is to hand.

4. **Test coverage on the risky files** — PARTIAL in v1.3.23
   (25 new tests added — 134/134 total, up from 109). Locked in
   the v1.3.21/v1.3.22 infrastructure with `error_reporter_test.dart`
   (breadcrumb ring + route/locale tracking + payload-cap helper +
   no-throw guarantee — 19 tests) and `main_provider_cache_test.dart`
   (memory-pressure cache drop — 5 tests + 1 trim refinement).
   EXTENDED in v1.3.60 (+53 → **228/228**): responsive overflow
   smoke tests (About/Settings/Library/Dashboard × 4 widths),
   `parseReference` regressions, daily-verse NT-only fallback,
   `cleanAiExplanation`. EXTENDED AGAIN same day (+8 → **236/236**):
   `MainProvider.useCachedVersion` (v1.3.40 stale-index regression,
   LRU round-trips, notify-once — 5 tests) and `FetchVerses.execute`
   (real-asset happy path, retry/rethrow contract, onAttempt
   sequence, maxAttempts honored — 3 tests). EXTENDED in v1.3.63/64
   (+7): `shouldThrottleRefresh` boundary cases. EXTENDED in v1.3.66
   (+60 → **303/303**): responsive overflow smoke tests for ALL 19
   top-level pages × 320/390/768/1280 (the remaining 15 beyond the
   original 4) — surfaced + fixed one real robustness bug (SearchPage
   verse-load poll ran up to 10 s after dispose; added `&& mounted`).
   EXTENDED in v1.3.80 (+2 → **316/316**): sync-flicker guard tests
   (`saveCurrentState` no-op when reading position unchanged; re-stamp
   on genuine navigation) — locks the content-guard contract that
   broke the "Syncing↔Synced 来回跳" loop. EXTENDED in v1.3.81 →
   v1.3.83 (+14 → **330/330**): paragraph-scroll-progress
   interpolation — monotonic across the chapter, moves WITHIN a
   paragraph (not just at group boundaries), group-boundary verse
   alignment, footer→100%, clamp + empty-chapter no-NaN, the pill
   NUMBER ticks up verse-by-verse while scrolling inside a paragraph
   (no longer freezes on the group leader), and the verse-by-verse
   case of the unified code path (one-verse-per-group → sub-verse
   smoothness).
   Still open as future test additions:
   - `jumpToReference` resolve + scroll (widget-level)
   - Split-pane secondary-provider lifecycle (widget-level)
   - BYOK Test handler (currently only smoke-tested in production)
   ~few hours each.

5. **Browser-matrix verification** — informally tested on Chromium +
   Safari macOS. iOS Safari (especially private mode), Firefox, old
   Chromium, and the China-build inside the GFW haven't been
   exercised end-to-end since v1.2.0. ~half-day. NOTE: the v1.3.60
   audit found (and fixed) the single biggest cross-browser defect —
   `web/index.html` had NO viewport meta since project creation, so
   mobile browsers laid out at the legacy 980 px desktop width. Any
   future matrix pass starts from a sane baseline now.

## Security baseline (added v1.3.24)

All in `docs/firebase-security-rules.md` + `netlify.toml` + `netlify/functions/_cors.mjs`.

- ✅ CORS lockdown on `errorReport` + `submitFeedback` — only the 6 Netlify origins allowed; off-allowlist browser POSTs hit 403 before any side effect
- ⚠️ CSP header — **REMOVED in v1.3.29** after v1.3.24 → v1.3.28 hotfix loop kept missing hosts (CanvasKit gstatic → fonts.gstatic → Firebase / Google Sign-In). Re-introduction tracked in "open" list below. The rest of the security headers stay.
- ✅ HSTS preload + X-Frame-Options + X-Content-Type-Options + Referrer-Policy + Permissions-Policy + COOP — defense-in-depth headers via `netlify.toml`
- ✅ gitleaks in CI — catches accidental commit of API keys / secrets
- ✅ Firebase rules documented at `docs/firebase-security-rules.md` with verification procedure

Still open as future security work:
- **Re-introduce CSP via Report-Only first** — deploy a `Content-Security-Policy-Report-Only` header (does NOT block, only reports) → run app through every user flow (sign-in, version switch, AI search, daily verse, evidence images, bookmarks, notes, exegesis, install prompt) on both English + Chinese builds → capture every `csp-report` violation via DevTools console OR a dedicated Netlify function endpoint → enumerate the actual hosts → THEN ship an enforcing CSP. Estimated 1 day of careful tracing. NOT another guess-and-break round.
- Per-IP rate limiting on Netlify functions (errorReport has session+stack dedupe; submitFeedback has none; AI funcs rely on Gemini quota)
- BYOK Gemini key at-rest encryption (SharedPreferences plaintext today; could use flutter_secure_storage on native)
- SRI hashes on external script tags (none today since Flutter web doesn't load external `<script>` tags)
- Dependency vulnerability scan in CI (flutter pub deps + advisory DB)

## Already deferred / low priority

- **Native builds (APK / iOS)** — RESOLVED in v1.2.67-v1.2.69
  (conditional imports for `dart:js_interop`, Firebase native init,
  flutter_local_notifications wired across iOS / Android / macOS).
  Native installs now run nightly via `tools/yswords-ios-reinstall.sh`
  (launchd `com.yswords.ios-reinstall`).
- **Sermon pipeline Phase 4 + 5** — when the back-end hits 589/589,
  run QA + finalize the verse-index decision. See `MEMORY.md`'s
  sermon entry for context.
- **CN-native coexist on iOS** — PARTIALLY RESOLVED in v1.3.38.
  Android coexist works end-to-end (product flavors → `intl` and
  `cn` install side-by-side via `tools/yswords-cn-install.sh`).
  iOS is blocked by free-Apple-ID provisioning: Xcode can't auto-
  generate a profile for a NEW bundle ID (`com.example.yswords.cn`)
  from the CLI without GUI intervention. Three resolutions when
  ready: (a) iPhone + iPad users access CN via PWA from
  `yswords-cn.netlify.app` (`Share → Add to Home Screen` in
  Safari — works today, no code), (b) enroll in Apple Developer
  Program ($99/yr — then `tools/yswords-cn-install.sh` works for
  iOS too), or (c) one-time manual "Try Again" in Xcode for the
  `.cn` bundle ID to seed the profile, after which CLI builds
  work until the 7-day free-tier re-sign cycle.

## v1.3.x cycle highlights (2026-05-23 → 2026-05-25)

All shipped to prod (yswords + yswords-cn). Detailed entries in
`HANDOFF.md` § v1.3.x highlights block.

- **v1.3.0 → v1.3.4** — notification scheduler (per-category prefs +
  local-TZ-correct fires via `flutter_timezone`); daily-verse
  rotation epoch fix (was a no-op `dayOfYear % 3650`); LoadingPage
  splash race fix (1.2s → 5s fallback); per-page SPL refactor with
  KeepAlive (PageView stutter root-cause); navigation dedup via
  `navigateToReader` helper; perf sweep (non-blocking eager preload,
  RepaintBoundary on verse / paragraph widgets).
- **v1.3.5 → v1.3.16** — fine-grained rebuild scope: VerseWidget +
  ParagraphGroupWidget migrated from Consumer/Consumer2 to Selector
  with listEquals; scroll-tick state moved to ValueNotifier so the
  whole pane no longer rebuilds on every visible-verse change.
- **v1.3.10** — TTS attempt: Chirp 3 HD voices wired through
  `aiSpeak.mjs`. Turned out `GOOGLE_TTS_API_KEY` was never set on
  Netlify, so the endpoint always 503'd. Pivoted in v1.3.18 to
  `flutter_tts` native fallback, then in v1.3.19 removed the
  feature entirely (see Removed-features section below).
- **v1.3.11** — restored 耶和华 → 雅伟 across 47 auxiliary asset
  files (section titles, book intros, sermons, evidence, Strong's
  lexicons, songs) so the YHWH-restored Bible versions are
  consistent across every overlay surface. CUV / CUV-tr left as-is
  (vanilla CUV's identity is the unrestored name).
- **v1.3.12** — empty-chapter UI distinguishes canon-edge vs
  version-gap (was a single "已到尽头" copy for both cases — confused
  users on NT-only versions navigating to Psalms).
- **v1.3.13** — Chinese exegesis prompt fully localized in
  `aiExplainWord.mjs` + `aiSearch.mjs`. Pre-fix English context
  squeezed between two Chinese directives caused frequent English
  leakage (book names, section labels).
- **v1.3.14** — split-pane chrome cleanup (overflow menu hidden in
  secondary pane) + tighter chapter top gap (gap was 32 px below
  chrome, now 8 px).
- **v1.3.17** — `lib/utils/haptics.dart` + verse-tap haptic +
  chapter-swipe haptic + macOS ⌘ shortcuts (⌘F search, ⌘, settings,
  ⌘[ / ⌘] prev/next chapter).
- **v1.3.20** — all `NetworkImage` sites wrapped with `ResizeImage`
  so Google avatars don't decode at 1024×1024 for 24-48 px circles;
  `ResponsiveBreakpoints.maxContentWidth` now caps at 760/880/1040
  for tablet/desktop/TV (was `infinity` everywhere — verses spanned
  full-viewport on big monitors past the ~75-char readability
  ceiling). Revised again in v1.3.33 → 1100/1400/1800 to better
  fit CJK characters on large tablets.
- **v1.3.21 → v1.3.26** — robustness + security cycle. Cross-platform
  error reporter via Resend (v1.3.21); GitHub Actions CI + silent-
  error wrapping + iOS memory-pressure handler (v1.3.22); 25 new
  tests on the new infra (v1.3.23 → 134/134); CORS lockdown +
  initial CSP + HSTS + gitleaks + Firebase rules audit (v1.3.24);
  PWA install affordance + analyze strictness restored (v1.3.25);
  highlights / bookmarks / notes export as Markdown or JSON (v1.3.26).
- **v1.3.27 → v1.3.29** — CSP whack-a-mole. v1.3.24's CSP broke
  CanvasKit (gstatic.com); v1.3.27 added gstatic → fonts garbled;
  v1.3.28 added fonts.* → AI / Firebase / Google Sign-In broken.
  v1.3.29 REMOVED CSP entirely; the right approach for re-adding
  documented inline in `netlify.toml` + the open-list above
  (Content-Security-Policy-Report-Only first, capture every
  csp-report violation, then enumerate hosts).
- **v1.3.30** — BYOK → shared-key auto-fallback for all three
  AI Netlify Functions. When BYOK returns 4xx (Gemini 400
  INVALID_ARGUMENT / 401-403 PERMISSION_DENIED / 429
  RESOURCE_EXHAUSTED), the function silently switches to the
  shared developer keys and reports `byokFallback: true` in the
  response. Closes the "exegesis suddenly stopped working" UX
  trap when a BYOK key expires.
- **v1.3.31** — bundled `assets/fonts/NotoSansSC-YsWords.otf`
  (1.88 MB SIL OFL subset of Noto Sans CJK SC covering every
  CJK char in the app's data: 5,537 ideographs incl. Ext-A
  `䍁` U+4341 + Ext-B `𨱔` U+28C54). Fixed the rare-CJK
  tofu-glyph issue on Flutter web (CanvasKit can't see CSS-only
  fallback fonts). New `tools/build_cjk_font_subset.sh`
  regenerates the bundle.
- **v1.3.32 → v1.3.35** — reader top-band UX. Mini-header
  translucent backdrop with platform-aware blur (BackdropFilter
  on iOS/macOS/web, solid surfaceContainerHigh tint on Android).
  Tap-top-to-scroll-to-top fixed for iPhone with Dynamic Island
  (strip extends past Island + opaque + IgnorePointer when
  chrome visible so FloatingHeader buttons still work).
- **v1.3.33** — wider reading-column caps for large tablets
  (Xiaomi Pad 7 Ultra went from 51% empty margin to 11%) +
  Strong's stub-gloss recovery for 18 lexicon entries where
  `glossZh` is just a grammar prefix.
- **v1.3.36** — Strong's gloss dedupe (the v1.3.33 recovery
  was prefixing `glossZh` twice for 4 entries where defZh's
  `1)` clause already started with the same prefix).
- **v1.3.37** — note glyph next to noted verses is now a
  direct tap target (one-tap opens the note editor; was
  decorative, required select-then-tap-note two-tap flow).
- **v1.3.38** — CN-build native coexist scaffolding. Android
  product flavors `intl` + `cn` (suffix .cn applicationId,
  label "YsWords CN") + `tools/yswords-cn-install.sh` that
  patches the iOS bundle ID + display name temporarily for
  the CN build. iOS install blocked by free-Apple-ID
  provisioning (see "Already deferred" list above).

- **v1.3.39** — note timestamp honesty. `_loadNotes` migration
  was stamping unknown notes with `DateTime.now()`, making
  months-old notes render as "just now" / "刚刚". Now stamps
  unknown notes with **0** (sentinel for "unknown time");
  library page's "Edited X" Builder skips rendering when ts
  is null OR ≤ 0. Existing bad `now` stamps already on disk
  stay (no way to recover the real edit time post-facto).

- **v1.3.40** — version-switch race fix + locale-aware default
  version. `MainProvider.useCachedVersion()` (warm-path version
  switch) wasn't invalidating `_versesByChapterKey`, so
  switching from a partial-canon version (LJK V2) to a
  full-canon version (NASB / CUVS-YHWH) showed the
  contradictory "Switch to a full-canon version" empty-state
  body under a NASB header. Cold-path `setVerses()` had the
  fix since v1.2.99 but useCachedVersion was missed. Also:
  default version on fresh install now branches on
  `prefs.getString('locale')` — en → NASB, zh-Hant →
  CUVS-YHWH-TR, zh-Hans → CUVS-YHWH (Yahweh restoration
  variants).

- **v1.3.41** — cross-device sync extended from
  highlights/notes/bookmarks to **last-read position + all
  user prefs**. Two new JSON blobs join the RTDB schema:
  (1) `lastRead` `{version, book, chapter}` written on every
  Bible state change, paired with `lastReadTimestamp` int;
  (2) `userPrefs` JSON containing 22 AppSettings fields (font,
  theme, color, locale, paragraphMode, dashboardSectionOrder,
  …) — paired with `userPrefsTimestamp`. `AppSettings.notifyListeners()`
  overridden to schedule a 600 ms-debounced blob-write so
  burst-y setter calls produce one upload, not many.
  `geminiApiKey` excluded (has its own credential-sensitive
  bidirectional stream at `users/{uid}/account/geminiApiKey`).
  Conflict resolution: newest-timestamp-wins via the new
  pair-merge in `_mergeSnapshots`.

- **v1.3.42** — seed-write fix. `MainProvider.saveCurrentState()`
  only fires on currentVersion / currentBook / currentChapter
  change. A user who upgraded to v1.3.41 but didn't navigate
  since boot had an empty `lastRead` RTDB node → Device B
  saw nothing to pull. Fix: call `saveCurrentState()` once
  at the end of `restoreState()` so the device's current
  state pushes on every boot, not just on user-driven
  changes. Hash-dedupe collapses the redundant upload when
  state hasn't changed.

- **v1.3.43 → v1.3.44** — sermon-resume cross-device sync.
  Dashboard's "继续讲道" card reads unscoped `sermons_last_read`
  prefs key, which wasn't in the sync schema. v1.3.43 added
  a `sermonId` field to the lastRead blob, but that was a
  half-fix — three further bugs found via screenshot
  feedback ("还是没有好好检查一下"): (1) WRITE — `sermons_page._openSermon`
  writes `sermons_last_read` locally but `saveCurrentState`
  only fires on Bible state changes, so the upload never
  happened if the user just opened a sermon → context.read
  MainProvider.saveCurrentState() called immediately in
  v1.3.44. (2) READ A — the scoped → unscoped mirror only
  ran in `restoreState` at app boot, missing live mid-session
  syncs → moved into `RealtimeDbSyncService._writeRemoteIntoLocal`.
  (3) READ B — dashboard's `_resumeSermon` field is cached
  in state; `_onProfileOrAuthChanged` did only setState
  without re-fetching → now also calls `_loadResumeSermon()`.
  Scroll-pixel offset deliberately NOT synced (screen-size
  dependent).

- **🚨 v1.3.45 — EMERGENCY HOTFIX**. Production user
  reported red `[unknown] set failed: value argument contains
  an invalid key (plan.activeId) in property 'users.../sync.data'`
  toast. Root cause: reading-plan feature was REMOVED in
  v1.2.69 but the RTDB sync schema still hardcoded
  `plan.activeId` / `plan.startMs` / `plan.useDate` / the
  `plan.completed.*` prefix loop. RTDB forbids `.` in keys.
  Any legacy user (signed up before v1.2.69) with a stale
  `plan.activeId` value in SharedPreferences had **every
  sync write rejected**. That was the root cause of every
  "Why all not synced yet" complaint — earlier v1.3.41–
  v1.3.44 sync work was code-correct but Firebase silently
  refused the upload. Fix: stripped plan.* from `_stringKeys`
  / `_intKeys` / `_boolKeys` / `_collectLocalSnapshot` /
  `_mergeSnapshots` / `_localHasUserData`; added defensive
  `_isInvalidRtdbKey()` helper that strips any key containing
  `.`, `#`, `$`, `/`, `[`, `]` — called at snapshot collection
  AND right before `FirebaseDatabase.set()` so a future
  regression at worst drops one key, not all sync.

- **v1.3.46 → v1.3.51 (2026-05-31)**. (46) locale-aware default
  version now persists — fresh-install locale wasn't written to
  prefs so `MainProvider.restoreState` read null and fell to the
  CUVS-YHWH default even for en users; added write-back +
  one-time en→NASB migration. (47) APP_VERSION robustness — the
  04:00 launchd reinstall's `awk` can't read `~/Documents`
  (macOS TCC on background daemons), so version resolution now
  cascades through 5 strategies incl. a `~/.config/yswords/
  current-version` cache outside the protected tree. (48) web
  `body{margin:0;padding:0;background:#FFF8F6}` reset — fixed the
  white edge-strips flanking the reader (no CSS reset existed).
  (49) RTDB sync-flicker — `_onProfileChanged` reset
  `_firstPullAfterSignIn` and re-ran on the reporter's OWN
  remote-apply writes, so every echo took the merge+upload path →
  upload→echo→loop; now bails under `_suppressLocalListener` and
  never resets the first-pull flag outside genuine auth changes.
  (50) **AI "explain this verse"** from the reading-pane selection
  bar — new ✨ action → `_AiExplainSheet` → `AiWordService.explainVerse`
  → the same `aiExplainWord` function in a new `task:'versePlain'`
  mode (`buildVersePrompt`; reuses key-rotation / model-step-down /
  BYOK); answers in the user's locale. Plus 3 fixes: `LeftAccentCard`
  ends the "borderRadius on a non-uniform `Border(left:/bottom:)`"
  crash class (the reported `InkDecoration.paintFeature` crash =
  dashboard daily-verse card); `ErrorReporter` drops benign
  CanvasKit `getParameter`/`MakeWebGLContext` WebGL noise; Chinese
  exegesis `cleanChineseDefinition` strips English-only CBOL noise
  and the derivation collapses into a 英文参考 disclosure. (51)
  narrow-phone selection-bar action row made horizontally
  scrollable (7 icons overflowed ≤340 dp). **Phase-2 audit pass:**
  sync-merge regression tests (newest-wins, plan.* key rejection,
  union/local-wins), export-dialog responsive width
  (`double.maxFinite` on phones, cap 560 on desktop), doc sync.
  Deferred for a focused profiled session: narrowing the remaining
  broad `Consumer`s → `Selector`, splitting the 7.4k-LOC
  `bible_reading_pane.dart`, and `kDebugMode`-guarding the
  deliberate `// ignore: avoid_print` sync/auth debug prints.
  Shipped to the 4 dev/qat sites + GitHub + macOS; iPhone/iPad/Mi
  Pad pending device reachability. flutter analyze: 0; test: 165/165.

- **v1.3.52 → v1.3.57 + PROD revert/re-push (2026-05-31)**.
  - **Blank prod home → revert.** prod (`yswords` + `yswords-cn`) was
    blanking on v1.3.48/49; user asked to revert with no forward push.
    Restored both prod sites to **v1.3.47** via `netlify api
    restoreSiteDeploy`. Initial guess (CSS) was wrong.
  - **v1.3.54 — real cause of the blank dashboard.** `LeftAccentCard`
    (added v1.3.50) drew its accent stripe with `Row(crossAxisAlignment:
    stretch)` + `Expanded(child)`. That forces an unbounded-height
    stretch pass; the dashboard daily-verse card's child is a
    `mainAxisSize.max Column` inside a `ListView`, so the pass threw
    during LAYOUT and blanked the scroll viewport from that card down.
    Rewrote `LeftAccentCard` to paint the stripe as a `Positioned`
    overlay inside a `Stack` sized by the content (no stretch, no
    intrinsic pass → safe for Text / RichText / SelectableText / Column).
    Added the missing regression test (max-Column child in a ListView).
  - **v1.3.53/55/56/57 — AI-verse explanation polish.** Copy button +
    SelectableText body (53); cold-start auto-retry once before erroring
    (55); render in the scripture font — `settings.fontFamily/fontSize/
    lineSpacing` — so it reads as one piece with the verse (56); and
    **buildVersePrompt rewritten to force clean flowing prose** (57) —
    the old `(1)(2)(3)` phrasing made Gemini emit a markdown OUTLINE +
    a leaked "快速思考：" preamble. Now bans lists/headings/markdown/
    preamble; added a defensive client strip of any leaked "快速思考"
    block. Verified by curling the live function.
  - **CN Google-login fix.** `yswords-cn` shipped the INTERNATIONAL
    bundle (Firebase + Google sign-in, useless behind the GFW) because
    `release_web.sh` built one bundle for all sites. Rewrote it to do
    TWO builds: international → en sites (dev/qat/`yswords`),
    `CHINA_MODE=true` → cn sites (cn-dev/cn-qat/`yswords-cn`). CHINA_MODE
    skips Firebase init → `auth.isConfigured` false → sign-in hidden.
  - **NATIVE AI gotcha + prod re-push.** Native (iOS/Android/macOS) call
    the AI function at the hardcoded prod URL (`kYswordsBaseUrl`,
    `api_base.dart`). While prod was on v1.3.47, the prod function
    lacked `versePlain` → iOS AI-explain returned "strongs, lemma,
    book, chapter, verse required". Once v1.3.54 confirmed the
    blank-home fix, user authorised pushing **v1.3.57 to all 6 sites**
    (international → en, CHINA_MODE → cn), which also restored the prod
    `versePlain` function — native AI works again with no reinstall.
  - Devices: iPhone/iPad/macOS on v1.3.57; Mi Pad pending its
    wireless-debug screen. flutter analyze: 0; test: 166/166.

- **v1.3.58 → v1.3.60 (2026-06-08 → 2026-06-11)**.
  - **v1.3.58** — mini reader header de-pilled: plain text, book+chapter
    left, version centered.
  - **v1.3.59** — release-time stamp consistency. `kAppReleaseTime` is
    stamped into source by `bump_version.sh` (was injected per-build via
    `--dart-define`, and an empty inject blanked the About footer on the
    Mi Pad); footer now renders a self-computed `UTC+10`-style offset
    instead of the platform-divergent `DateTime.timeZoneName` (iOS said
    `AEST`, Android `GMT+10:00`, web an IANA name — "格式不一样").
    Ops fix the next day: the 04:00 launchd job had been running a STALE
    COPY of the reinstall script at `~/.config/yswords/scripts/` —
    replaced with an exec shim to the repo script (never drifts again).
  - **v1.3.60 — full audit (P0–P4, user-confirmed plan).** P0: added the
    long-missing `<meta name="viewport">` (mobile browsers had used the
    980 px legacy viewport since project creation); silenced `debugPrint`
    in release builds (~103 callsites were logging sync/auth detail to
    the prod web console — one `kReleaseMode` no-op in `main()`); 20 s
    `.timeout` on every awaited RTDB op so sync can't hang forever. P1:
    responsive overflow smoke tests. P2: `cleanAiExplanation` extracted +
    tested; `parseReference` + daily-verse fallback regression tests.
    P3 perf audit came back CLEAN (shrinkWrap usage correct, image decode
    caps present, no watch-in-itemBuilder). P4: this doc + README +
    HANDOFF synced. flutter analyze: 0; test: 228/228.

- **v1.3.61 → v1.3.67 (2026-06-11 → 2026-06-13)**.
  - **v1.3.61 → v1.3.62** — deep-link cold-open + self-healing reader
    URL + preconnect. The boot path was racing the deep-link parser; now
    a missing/invalid `/read/...` recovers to a sensible default instead
    of blanking.
  - **v1.3.63 → v1.3.64** — evidence-refresh throttle perf
    (`shouldThrottleRefresh` boundary tests +7).
  - **v1.3.65** — boot auto-retry robustness.
  - **v1.3.66** — full-audit pass 2: responsive smoke tests for ALL 19
    top-level pages × 4 widths (+60 → 303/303); surfaced + fixed one
    real robustness bug (SearchPage verse-load poll ran up to 10 s after
    dispose; added `&& mounted`).
  - **v1.3.67** — escalating FetchVerses timeout (20/40/60 s). Closed
    the "failed to load / blank app" mystery on slow cellular via the
    first ErrorReporter field report.

- **v1.3.68 → v1.3.74 (2026-06-13 → 2026-06-14)**.
  - **v1.3.68 → v1.3.73** — AI verse panel turned into a multi-turn
    study chat: optional question box (v1.3.68), confirm-first / no
    auto-generate (v1.3.71), then follow-ups with conversation history,
    更简短/更详细 length controls, concise-by-default, input clears on
    success / restored on failure, and save-to-note (selection or whole
    answer → note editor, append-or-new) (v1.3.73). Also v1.3.73:
    version-switch race fix (a superseded async load could clobber the
    current version and poison the per-version LRU) + top-bar overflow
    fix (long version labels no longer hide the book name at narrow
    widths).
  - **v1.3.69** — dark mode tracks the chosen theme colour with a soft
    light-pastel accent so the "读经" hero card isn't harsh.
  - **v1.3.70 → v1.3.72** — themed app icon follows the theme colour
    reliably. The iOS icon `MethodChannel` was registered on the wrong
    binary messenger after the UISceneDelegate migration; fixed to
    `engineBridge.applicationRegistrar.messenger()`.
  - **v1.3.74** — release-visible `dart:developer` icon diagnostic
    (`name:'yswords.icon'`) for device-console verification.

- **v1.3.75 → v1.3.79 — iOS themed-icon saga: RESOLVED on stock
    SceneDelegate (2026-06-14 → 2026-06-15).**
  - Two attempts (v1.3.75, v1.3.77) registered the icon channel from a
    custom `FlutterSceneDelegate` subclass via Info.plist
    `UISceneDelegateClassName` and **black-screened the real iPhone** —
    on this Flutter 3.41 build, any custom subclass via Info.plist
    breaks window setup. Both reverted (v1.3.76 / v1.3.78).
  - **v1.3.79 (final)** — keep `SceneDelegate` stock; rely on
    `AppDelegate.didInitializeImplicitFlutterEngine` → `applicationRegistrar
    .messenger()` registration. **Sim-verified** (forced `Colors.red` +
    `debugPrint` in a debug build → `currentIconName=AppIcon-Red`).
    Real-device "no change" earlier was install-timing, not a code bug.
    ⚠️ Do NOT reintroduce a custom `FlutterSceneDelegate` subclass via
    Info.plist on this Flutter version.
  - Also v1.3.79: **loading-page logo tints to the theme primary** via
    `ColorFiltered(BlendMode.srcIn)` on a single-hue silhouette.
  - **macOS app icon** reshaped to the Big Sur rounded template
    (~82% body + continuous corners + soft drop shadow) — macOS does
    NOT auto-mask like iOS, so the old full-bleed square shipped as a
    square. `AppIcon.appiconset` (all sizes) + the 6
    `assets/themed_icons/` dock variants regenerated. iOS/Android assets
    intentionally left full-bleed (their OS auto-masks).
  - **iOS upgrade lesson:** after a major iOS version jump (the iPhone
    was on iOS 27.0), reinstall the app via `devicectl device install`
    before assuming a feature regressed — the OS can drop
    alternate-icon state.

- **v1.3.80 → v1.3.83 — sync flicker + reading-bar overhaul (2026-06-15).**
  - **v1.3.80 — cloud-sync "Syncing↔Synced 来回跳 / 发癫" flicker
    loop fixed.** Root cause: `AppSettings._writeUserPrefsBlob` and
    `MainProvider.saveCurrentState` stamped a fresh
    `userPrefsTimestamp` / `lastReadTimestamp = now()` on every
    `notifyListeners()` (including rebuilds caused by a sync-status
    change itself), so the changing timestamp defeated the sync layer's
    own dedupe hash → upload → status flip → rebuild → loop. Fix =
    **content guard**: only re-stamp + upload when the serialized blob
    actually changed (`_lastWrittenUserPrefsBlob` /
    `_lastSyncedReadBlob`); extracted `AppSettings._userPrefsSnapshot()`
    so writer + guard-primer can't drift. +2 regression tests
    (`test/sync_flicker_guard_test.dart`).
  - **v1.3.81 — paragraph-mode reading bar tracks scroll
    proportionally.** Pre-fix the right-edge pill stepped by whole
    paragraph groups (and didn't move at all while scrolling inside a
    long paragraph). `_handleItemPositionsChanged` now also derives a
    CONTINUOUS visible-item position (`itemIndex + within-item fraction
    from itemLeadingEdge/itemTrailingEdge`) and the indicator
    interpolates the verse index across the visible group via pure
    `paragraphScrollProgress()` (`lib/utils/chapter_scroll_progress.dart`)
    + 7 tests.
  - **v1.3.82 — pill NUMBER tracks scroll too** (not just the bar). New
    `paragraphCurrentVerseIndex()` shares the interp core with
    `paragraphScrollProgress()` so bar + number can never disagree; the
    number ticks up verse-by-verse while scrolling inside a paragraph
    instead of freezing on the group's leading verse. +4 tests.
  - **v1.3.83 — unified the reading-bar logic.** Verse-by-verse mode
    now drives the pill through the SAME continuous interpolation as
    paragraph mode (verse-by-verse is just the one-verse-per-group
    case), so the bar moves smoothly SUB-verse (instead of stepping by
    whole verses) and the mode branch in the indicator builder was
    deleted entirely — one code path for both. +3 tests.
  - flutter analyze: 0; test: **330 / 330**.
  - Rollout: deployed all 6 Netlify sites incl. **prod** (yswords +
    yswords-cn) on user OK; iPhone (iOS 27.0) + iPad on v1.3.83; Mi Pad
    last on v1.3.81 (offline → APK ready for reconnect); macOS app
    built (Big Sur rounded icon baked in) — `/Applications` install is
    blocked from the agent's sandbox; user installs manually.

## Removed features

- **朗读 / TTS (v1.3.19)** — Listen-to-chapter + ListenButton +
  Settings voice card + `aiSpeak.mjs` + audio generators all
  removed end-to-end. Pre-generated MP3 files at
  `yswords-data.netlify.app/audio/*` remain as orphan CDN data
  (no client fetches them) — can be batch-deleted on yswords-data
  whenever convenient. SharedPreferences keys `ttsVoiceGender` /
  `ttsVoiceTier` are inert on existing users' disks. The
  `flutter_tts` + `audioplayers` deps are removed from
  `pubspec.yaml`.

## Recent UX & sync work (2026-05-16 → 2026-05-17, v1.2.46 → v1.2.51)

Context for the next agent — these have already shipped to prod:

- **v1.2.46** — harmonised `aiBibleSearch` quota-error copy with the
  other two AI functions ("AI quota … exhausted **across all
  free-tier models**").
- **v1.2.47** — copy-format preview bug (the "With Reference"
  preview's regex stripped the `[ref]` prefix); default copy format
  switched `withRef` → `devotional`; **BYOK Gemini key real-time
  sync** via RTDB `onValue` stream (Device A → Device B updates
  without reboot).
- **v1.2.48** — devotional copy format now flows verses as a single
  continuous paragraph (was one-per-line).
- **v1.2.49** — search-jump scroll alignment 0.0 → 0.25 + 350 ms
  smooth scroll + bumped highlight alpha.
- **v1.2.50** — search-jump highlight switched from `secondary` tint
  to `primaryContainer` (identical to a hand-selected verse);
  duration 1.2 s → 3.5 s; forensic `debugPrint` chain across the
  whole jump flow.
- **v1.2.51** — paragraph-mode `►` arrow marker inline before the
  highlighted verse number; BYOK sync race-fix (cloud is source of
  truth, local pushed before subscribe to preserve the paste-then-
  sign-in flow); `[RTDBSync]` / `[YsWords BYOK]` `debugPrint` chain.

If a fresh "search verse not highlighted" or "BYOK didn't sync"
report comes in, ask the user to copy the browser-console
`[YsWords ...]` / `[RTDBSync ...]` lines first — they pinpoint the
failing step.

## Open (2026-06-14)

1. **iOS themed-icon — on-device verification PENDING.** Root cause was the
   `yswords/ios_icon` `MethodChannel` registered on the wrong binary
   messenger after the UISceneDelegate migration (Flutter 3.41+) → every
   call silently `MissingPluginException`'d. Fixed v1.3.72
   (`AppDelegate.didInitializeImplicitFlutterEngine` now uses
   `engineBridge.applicationRegistrar.messenger()`); v1.3.74 added a
   release-visible `dart:developer` log (`name:'yswords.icon'`) to read the
   swap from the device console. The 2026-06-14 reinstall missed the
   iPhone/iPad (asleep), so they're still on v1.3.72 (no diagnostic). When
   the iPhone is awake on the Mac's Wi-Fi: `xcrun devicectl device install
   --device 9FA8108D-… build/ios/iphoneos/Runner.app` then `xcrun devicectl
   device console --device 9FA8108D-…` filtered for `yswords.icon` while
   changing the theme colour. A lingering `MissingPluginException` means the
   messenger fix didn't take and the channel registration needs another look.

2. **AI study-panel follow-ups — token budget.** The follow-up `history`
   transcript is tail-clamped (~1800 chars client / 2000 server). If long
   threads start losing early context noticeably, summarise older turns
   instead of truncating.

## Notes

- Anything user-facing (UI, copy, accessibility, perf) is shipped immediately
  through dev → qat → prod when it surfaces; this list tracks the
  multi-step / infra items only.
- Re-evaluate priority order whenever a new audit pass finds something
  user-impacting.
