# YsWords — open priorities

Living list of things to address next. Append rather than rewrite.

> ⚠️ **RELEASE POLICY**: dev + qat free to push; **prod requires explicit user instruction in the current turn**. See [`release-policy.md`](release-policy.md).

## High-ROI infrastructure (deferred from 2026-05-10 robustness review)

These were identified as the highest-ROI gaps after v1.2.35. None are blocking, but each closes a real risk.

1. **GitHub Actions CI workflow** — run `flutter analyze` + `flutter test`
   on every push to main + every PR. Catches regressions automatically
   instead of relying on the developer remembering to run them. The
   only existing workflow today is `.github/workflows/sync-songs.yml`
   (data pipeline, not tests). ~30 min.

2. **Error monitoring on prod** — wire `FlutterError.onError` (and a
   `runZonedGuarded` for async) to either Sentry or a Cloud Function
   endpoint that captures stack traces. Today, a crash on
   yswords.netlify.app is invisible to the developer. Decide between
   Sentry (free tier OK for this volume) or a tiny Resend-or-similar
   forwarder. ~1 hour.

3. **Lamentations 5:21/5:22 data-quality bug** — flagged in `v1.2.32`'s
   notes. `cnv.json` has both verses set to a hybrid that merges
   their content, and `cnv-tr.json`'s 5:22 carries a non-canonical
   paraphrase. Needs a verified 新譯本 CNV source to correct. ~30 min
   when a source is to hand.

4. **Test coverage on the risky files** — current ratio is ~1.25 % by
   line count (847 / 67 769). Highest-impact additions:
   - `FetchVerses.execute` retry/timeout/clear-cache path
   - `MainProvider.useCachedVersion` + paragraph cache eviction
   - `jumpToReference` resolve + scroll
   - Split-pane secondary-provider lifecycle
   - BYOK Test handler (currently only smoke-tested in production)
   ~few hours.

5. **Browser-matrix verification** — informally tested on Chromium +
   Safari macOS. iOS Safari (especially private mode), Firefox, old
   Chromium, and the China-build inside the GFW haven't been
   exercised end-to-end since v1.2.0. ~half-day.

## Already deferred / low priority

- **Native builds (APK / iOS)** — broken since v1.2.7's revert (direct
  `dart:js_interop` imports outside web-only files). Revival
  instructions in `HANDOFF.md` § Known Issues. PWA Add-to-Home-Screen
  is the recommended mobile install path in the meantime.
- **Sermon pipeline Phase 4 + 5** — when the back-end hits 589/589,
  run QA + finalize the verse-index decision. See `MEMORY.md`'s
  sermon entry for context.

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

## Notes

- Anything user-facing (UI, copy, accessibility, perf) is shipped immediately
  through dev → qat → prod when it surfaces; this list tracks the
  multi-step / infra items only.
- Re-evaluate priority order whenever a new audit pass finds something
  user-impacting.
