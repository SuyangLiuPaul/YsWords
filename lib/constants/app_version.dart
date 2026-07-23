/// Single source of truth for the user-visible app version string.
///
/// Bumped manually in lockstep with `pubspec.yaml`'s `version:` field
/// when shipping a new build. Kept here (not derived from
/// `package_info_plus` at runtime) so the AboutPage footer renders a
/// version even before the package-info plugin has initialised, and
/// so tests can assert against a fixed string.
///
/// 2026-05-07 (v17): extracted from settings_page.dart when the
/// "Check for Updates" tile was removed; AboutPage now surfaces this
/// in its footer.
///
/// 2026-05-07 (v1.0.0 release): bumped to 1.0.0 as the first
/// stable / public-shippable release. This rolls together rounds
/// 54-56 (the post-beta polish cycle) plus the v8-v18 strands of
/// 2026-05-07 (search redesign, feedback pipeline, settings
/// cleanup, and the bug-audit fixes for Timer races / controller
/// leaks / unbounded AI prompt inputs).
///
/// 2026-05-08 (v1.0.1 perf): pure performance patch. Memoized
/// per-verse normalized search keys (collapses every keystroke
/// from O(n × regex chain) to O(n × String.contains)), memoized
/// paragraph grouping + verseToItemMap on MainProvider (was
/// being recomputed on every Consumer rebuild), capped Image
/// decode dimensions on every dashboard / news / evidence /
/// avatar surface (avoids loading 4K source bitmaps for
/// 64 px thumbnails), and dropped the 40 MB `assets/Archived/`
/// folder from the repo (it was never bundled, just bloating
/// clones).
///
/// 2026-05-08 (v1.1.0 — Liquid Glass design pass): translated
/// Apple's WWDC25 Liquid Glass material to Flutter Web. New
/// primitives in `lib/widgets/liquid_glass.dart` (LiquidGlass /
/// LiquidGlassButton / LiquidGlassChip / LiquidGlassCard) compose
/// BackdropFilter blur + translucent fill + specular highlight +
/// hairline border + soft shadows into a single material that
/// catches and refracts whatever sits behind it. High-impact
/// surfaces converted: dashboard quick-links grid, search-page
/// mode chips, welcome-page disclaimer, feedback-form intro.
/// Theme tokens bumped to Apple's iOS 26 shape language: 18 px
/// Card radius, 20 px Dialog radius, San Francisco family at the
/// front of the font fallback chain so macOS / iOS users get
/// native typography out of the box.
///
/// 2026-05-08 (v1.1.1 — material picker): user feedback that v1.1.0
/// glass-everywhere felt worse than the original look. Pivoted to
/// expose the look as one of several pickable materials in
/// Settings → Style preset. Default is Classic (recreates pre-v1.1
/// look). New presets: Liquid Glass, Paper (warm sepia flat),
/// Carbon (dark high-contrast). Backed by a new CardMaterial enum
/// + persisted setting; LiquidGlassButton / LiquidGlassCard now
/// dispatch through the user's choice.
///
/// 2026-05-08 (v1.1.2 — system defaults + accessibility): every
/// default that has a sensible OS-derived counterpart now flows
/// "user setting → system detect → app fallback":
/// • Font family: new 'system' option resolves through the CSS
///   native font stack (-apple-system / Segoe UI / Roboto /
///   Cantarell / 微软雅黑 / Noto Sans / …) so each platform's
///   users get their OS UI font with no setup.
/// • Theme mode + locale: already system-following.
/// • New 'systemDefault' AppStylePreset bundles system font +
///   classic material — the new default landing experience.
/// • LiquidGlassButton respects MediaQuery.disableAnimations
///   (skips press scale) and MediaQuery.highContrast (downgrades
///   glass / paper / carbon material to classic).
/// Reset settings now restores 'system' font + system theme +
/// system locale, not hardcoded Roboto.
///
/// 2026-05-08 (v1.1.3 robustness audit): three real fixes from a
/// post-v1.1.2 audit pass:
/// • LiquidGlassButton + LiquidGlassCard switched from
///   `context.watch<AppSettings>()` to `context.select<...>` so
///   they only rebuild when `cardMaterial` itself changes — not
///   on every unrelated AppSettings field. With ~12 dashboard
///   tiles + ~10 search chips + welcome / feedback cards all
///   listening, watching the full settings caused a cascade of
///   rebuilds whenever the user dragged the font-size slider.
/// • `fontFamilyHint` ui-string rewritten to reflect v1.1.2
///   reality — "System default" is now the recommended choice;
///   Microsoft YaHei is no longer bundled (was removed for
///   licence reasons in v1.0).
///
/// 2026-05-08 (v1.1.4 simplified→traditional fix): user noticed
/// `仆婢` in 創世紀 20:14 should be `僕婢` (servant). Comprehensive
/// audit of all 5 -tr Bible files (cuvs-yhwh-tr / cuv-tr /
/// cnv-tr / biblexg-tr / biblexg-v2-tr) found 1,111 simplified
/// chars contaminating the supposedly-traditional text:
/// • 仆 (servant context) → 僕 — preserves 仆倒 (= "fall down")
/// • 后 (after / behind) → 後 — preserves 王后 / 太后 / 母后 / 天后
/// • 发 → 髮 (in 头发 / 秀发 / 发绺 hair contexts) or 發 (everywhere
///   else)
/// • Plus ~150 other simplified-only chars (这/时/听/过/来/处/进/远/
///   边/见/关/国/万/书/开/两/纱/颊/绺/etc.) — all in cnv-tr.json
///   which was particularly contaminated.
/// Conservative: only fixes characters that exist ONLY in
/// simplified Chinese (or with disambiguating context). Did NOT
/// touch traditional variant choices the files settled on (裏 vs
/// 裡, 麽 vs 麼, 群 vs 羣 — all preserved as-is).
///
/// 2026-05-08 (v1.1.5 AI search UX fix): user reported "按 yswords
/// ai 没翻译，问问题也没有经文". Backend was healthy
/// (curl-tested aiBibleSearch returns valid refs for English +
/// Chinese queries) but the client was hiding the AI's results
/// when the refs didn't resolve to verses in the user's loaded
/// Bible version — they only saw a generic "No results found"
/// screen with a tiny notice they couldn't see.  Fixed:
/// • `_askAi` early-returns now also set `searchPerformed = true`
///   and reset state, so the inline `_aiNotice` always renders.
/// • New state fields `_aiRefs` + `_aiUnresolvedRefDisplays` keep
///   the full AI suggestion list so we can render it.
/// • New `_buildAiRefList` widget renders every AI ref as a card
///   (book + chapter:verseStart-verseEnd + AI's reason). Refs
///   that resolve in the user's version → tap goes to reader;
///   refs that don't → "reference only" tag + snackbar pointing
///   the user to switch versions.
/// Net: user always sees the AI's full suggestion list, never
/// the misleading "No results found" empty state.
///
/// 2026-05-08 (v1.1.6 chip-stuck-busy fix): user reported
/// "after AI search returns no verses, deleting a char makes the
/// AI chip un-clickable". Symptom = `_aiBusy = true` stuck after
/// some failure path. Two defensive fixes:
/// • `onChanged` (text edit) explicitly resets `_aiBusy = false`
///   so any stuck busy state clears as soon as the user types.
/// • `_askAi` is now wrapped in try/finally; the finally sets
///   `_aiBusy = false` unconditionally so an uncaught exception
///   inside the AI / resolve flow can never permanently grey the
///   chip.
///
/// 2026-05-08 (v1.1.7 — search-mode chip strip removed): user said
/// "为什么按第一次没有反应，而且经文搜索旁边那个 YsWords AI
/// 那个 button 不用在那里。因为找不到才用 ai 搜索的" — the AI chip
/// up top doesn't belong there because AI is a *fallback* for when
/// text search fails, not a peer mode. The dedicated chip ALSO
/// suffered from a "first tap no response" bug on Flutter web (the
/// LiquidGlassButton + MouseRegion + AnimatedScale stack
/// occasionally swallowed the first tap when the soft-keyboard
/// transition stole focus).
///
/// Removed the entire `_SearchModeStrip` (Search + YsWords AI chips
/// row) plus the `_ModeChip` widget, the `_SearchMode` enum, and
/// the `_lastMode` tracking field — all dead code now. AI search
/// remains accessible via the existing "Search with YsWords AI"
/// button rendered inside the empty state when text search returns
/// 0 results. Same `_askAi` handler — only the entry point
/// changed. Net: simpler search UI, no first-tap glitch, no
/// stuck-busy chip surface.
///
/// 2026-05-08 (v1.1.8 — error-message accuracy): user saw "YsWords
/// search is not configured" but the API key WAS configured —
/// the dev's free-tier Gemini quota (250 RPD) was just exhausted
/// for the day. Backend conflated the two cases: BOTH "no API key"
/// AND "all keys rate-limited" returned HTTP 503, which the client
/// hardcoded to "not configured".
///
/// Fixes:
/// • `netlify/functions/aiBibleSearch.mjs`: quota-exhausted now
///   throws statusCode 429 with a `publicReason` that points the
///   user to BYOK in Settings; 503 reserved for actual missing
///   GEMINI_API_KEY config.
/// • `lib/services/ai_bible_search_service.dart` +
///   `ai_search_service.dart`: split 503 / 429 / other into
///   distinct branches; each prefers the server's `error` body
///   over a hardcoded fallback string.
/// • `ai_word_service.dart`: already surfaced the server's error
///   correctly; no change.
///
/// 2026-05-08 (v1.1.9 — BYOK card re-exposed): user asked
/// "怎么没看到 BYOK?" — the GeminiKeyCard widget had been live in
/// `lib/widgets/gemini_key_card.dart` the whole time, but on
/// 2026-05-06 the section was hidden from Settings because the
/// dev's shared key was covering everyone. Once the shared-key
/// quota started failing (today, 2026-05-08), users had no way
/// to opt out of the shared pool. v1.1.9 puts the card back into
/// Settings under a dedicated "YsWords AI" section right above
/// About — so users hitting "AI quota exhausted" can paste their
/// own AI Studio key and keep working.
///
/// 2026-05-08 (v1.1.10 — BYOK deep-link from every AI failure UI):
/// user asked "如果没 token 会自动引导到 BYOK 那里吧". Yes — but
/// only as text in v1.1.9. v1.1.10 turns it into a one-tap deep
/// link from every AI surface that can fail:
/// • `lib/pages/search_page.dart` — under the AI fallback button
///   in the empty state
/// • `lib/pages/evidence_page.dart` — under the AI Q&A error
///   notice
/// • `lib/widgets/originals_sheet.dart` — next to the "Try again"
///   button on the verse-explanation error card
/// Each calls `Get.to(SettingsPage(initialSection: SettingsSection.ai))`
/// which scrolls the GeminiKeyCard into view via the existing
/// `Scrollable.ensureVisible` deep-link infrastructure.
/// The button only appears when the failure heuristically looks
/// like a quota / not-configured one (matches "quota" /
/// "exhausted" / "rate-limit" / 配额 / 用完 / etc.) AND the user
/// hasn't already pasted their own key. So users with BYOK
/// already set don't see the redundant CTA.
///
/// 2026-05-08 (v1.1.11 — i18n polish from final audit): the
/// hardcoded English fallback strings in
/// `ai_bible_search_service.dart` + `ai_search_service.dart`
/// (used only when the Netlify function returns 429/503 without
/// a parseable error body — rare path) are now looked up in
/// uiStrings via the request locale. Two new keys:
/// `aiQuotaExhaustedFallback` + `aiNotConfiguredFallback` (zh-Hans
/// / zh-Hant / en). Found by a final audit Explore agent — net
/// state is clean: no critical bugs, no resource leaks identified.
///
/// 2026-05-09 (v1.1.12 — CORS parity for backend functions): a
/// follow-up audit pass found that `netlify/functions/aiBibleSearch.mjs`
/// (the YsWords AI verse-search endpoint) and
/// `netlify/functions/submitFeedback.mjs` lacked OPTIONS preflight
/// handlers + (for aiBibleSearch) didn't set
/// `Access-Control-Allow-Origin` on POST responses. Same-origin
/// from yswords.netlify.app worked, but cross-origin or strict
/// preflight checks would 405. Brought to parity with
/// `aiSearch.mjs` + `aiExplainWord.mjs` (which already had
/// correct CORS). Also added the missing `userApiKey` regex
/// validation (`AIza[A-Za-z0-9_-]{20,80}`) to aiBibleSearch.mjs
/// so garbage keys are silently dropped instead of forwarded to
/// Gemini.
///
/// While testing the fix, found a SECOND bug: every `OPTIONS`
/// handler across all 4 Netlify functions used
/// `new Response('', { status: 204, headers: cors })`. Per the
/// WHATWG Fetch spec, HTTP 204 (No Content) disallows ANY body —
/// the empty string `''` is a 0-length body, so the constructor
/// throws `Invalid response status code 204` and Netlify returns
/// 502. None of this was visible in normal use because same-origin
/// from yswords.netlify.app skips preflight, but cross-origin
/// (extensions, embedded surfaces, mobile native bridges) would
/// fail. Fixed in all four files:
/// `Response(null, { status: 204, headers: cors })`. Verified
/// HTTP 204 + `Access-Control-Allow-Origin: *` for OPTIONS on
/// every endpoint live.
///
/// 2026-05-09 (v1.2.0 — China mode + second Netlify site): added a
/// compile-time `kChinaMode` flag (see
/// `lib/constants/build_flags.dart`) plus a separate Netlify site
/// (`yswords-cn.netlify.app`) that builds with
/// `--dart-define=CHINA_MODE=true`. The China build skips
/// Firebase init entirely (avoids the 4 s GFW timeout on boot),
/// hides Google-Fonts options from the picker (they can't be
/// downloaded behind the firewall), and surfaces a "中国版 /
/// China build" tag on the AboutPage footer. International users
/// see no change.
///
/// 2026-05-09 (v1.2.1 — China-mode UX cleanup): user asked
/// "中国的没有 Google 登陆是吗" — yes, but v1.2.0 still rendered
/// the static "Sign in with Google" button on the Welcome / Profiles
/// pages even in the China build (it would just never succeed and
/// the developer cloud-setup card would surface scary "auth not
/// configured" warnings). v1.2.1 hides every Google-sign-in /
/// Firebase-status surface in China mode and replaces them with a
/// single explanatory note: "中国版不支持云同步 · 数据保存在本机".
/// Touches `welcome_page.dart` (Sign-in CTA), `settings_page.dart`
/// (cloud-config rows + privacy footnote), and `about_page.dart`
/// (CloudSetupDiagnostic + SetupInstructionsCard). New
/// `chinaCloudUnavailable` ui-string key carries the localised
/// message in zh-Hans / zh-Hant / en. International users see no
/// change.
///
/// 2026-05-09 (v1.2.2 — production audit polish + dev/qat infra):
/// user asked to harden both prod sites and stand up dev / qat
/// flavours behind separate URLs. Code-side polish from a 5-finding
/// audit:
/// • welcome_page `_signInWithGoogle` now short-circuits in
///   `kChinaMode` (defensive — the button itself is hidden, but if
///   a regression ever exposes it we'd otherwise burn 4 s on a GFW
///   timeout) and routes its two fallback error messages through
///   the new `cloudSignInUnavailable` / `signInFailed` ui-string
///   keys (zh-Hans / zh-Hant / en) instead of hardcoded English.
/// • All three Gemini-proxy Netlify functions (`aiBibleSearch`,
///   `aiSearch`, `aiExplainWord`) now clamp the `locale` request
///   field to the three the app actually localises — anything else
///   falls back to 'en' rather than landing in the prompt template
///   verbatim.
/// • `font_catalog.dart` now logs (not silently swallows) Google
///   Fonts download failures via `debugPrint`, so production
///   monitoring can spot repeated fonts.googleapis.com hiccups.
/// Infra-side: four new Netlify sites added —
/// `yswords-dev` + `yswords-cn-dev` (development),
/// `yswords-qat` + `yswords-cn-qat` (QA / pre-prod). Each gets the
/// same env-var bundle as prod (GEMINI_API_KEY × 3 + RESEND_API_KEY
/// + FEEDBACK_TO). Initial deploys mirror the v1.2.2 prod build
/// but later commits can land there independently for testing.
///
/// 2026-05-09 (v1.2.3 — per-site icon variants): user asked for
/// distinct PWA icons across the 6 deploys so a saved-to-home-screen
/// install on each tier is visually identifiable at a glance.
/// • Six (flavour, tier) variants now live under
///   `tools/site-icons/<flavour>-<tier>/` — generated from the
///   1024 px `assets/app_icon.png` master by
///   `tools/generate_site_icons.py` (Pillow). prod-intl is the
///   original; cn variants get a red 中 badge in the top-right;
///   dev re-tints the background leaf-green; qat re-tints amber.
/// • Each variant ships its own `manifest.json` with a tier-aware
///   `name` / `short_name` so the iOS / Android home-screen label
///   under the icon matches the colour ("YsWords (DEV)",
///   "YsWords·中" etc).
/// • New `tools/deploy_site.py` helper takes a site name and
///   overlays the matching variant onto the base build before
///   deploying — keeps the 2-build / 6-deploy split clean.
///
/// 2026-05-09 (v1.2.4 — CN marker softened): user said the v1.2.3
/// red rounded-rectangle 中 badge was "weird" — too loud, clashed
/// with the rest of the icon's blue/green/amber palette. Replaced
/// with a small (~14% of icon width vs the previous 28%) 中
/// character drawn in the same colour family as the background —
/// specifically the auto-detected bg darkened 28% so it reads as a
/// quiet shadow / watermark rather than an alert badge. No box, no
/// outline, no contrasting fill. You have to look for it, but it's
/// there for the moments when you need to tell intl from cn at
/// a glance. Re-runs `tools/generate_site_icons.py` to refresh
/// the 3 cn variants; intl variants unchanged.
///
/// 2026-05-09 (v1.2.5 — welcome page disclaimer removed): user said
/// the LiquidGlassCard with the "神的灵才是引导，AI 只是辅助" copy
/// felt "啰嗦" (verbose) on the first-launch screen. Removed the
/// whole card. The same caveat still appears below the AI surfaces
/// themselves (search empty state, evidence Q&A error notice, word
/// study error card) where it's contextually relevant — we just
/// don't blanket-assert it before the user has even opened the app.
/// Cleaned up the now-unused `liquid_glass.dart` import on
/// welcome_page.dart. All 6 sites redeployed.
///
/// 2026-05-09 (v1.2.6 — pre-dev/qat/prod hardening pass): user
/// asked for a final all-in audit before switching to the strict
/// dev → qat → prod release flow. Three parallel audit agents
/// surfaced findings; verified each against the source and applied
/// fixes for the real ones:
///
/// CODE
/// • settings_page.dart:1578 — fallback "Sign-in failed." now
///   localised via `signInFailed` ui-string key (added in v1.2.2
///   but never wired up here; the welcome-page version was already
///   localised).
/// • ui_strings.dart — removed dead `welcomeDisclaimerTitle` /
///   `welcomeDisclaimerBody` keys left over from the v1.2.5
///   LiquidGlassCard removal.
///
/// NETLIFY FUNCTIONS
/// • All three Gemini-proxy functions (aiBibleSearch / aiSearch /
///   aiExplainWord) — Gemini 5xx response bodies were being
///   forwarded verbatim (up to 300-400 chars) in the public error
///   message. Fix: log the upstream body server-side via
///   `console.error` and return a generic "Upstream AI service
///   error (HTTP nnn)" to the client. Closes a low-severity
///   info-disclosure (Gemini's regional / config error text).
/// • aiExplainWord.mjs — `length` and `scope` request fields now
///   allowlisted to the values `styleProfile()` actually
///   recognises. Previously `.slice(0, 32)` capped length but
///   accepted any garbage which silently fell through to defaults
///   inside the switch — invalid input now hard-rejects so client
///   typos surface instead of being masked at server cost.
/// • submitFeedback.mjs — hoisted CORS headers into a shared const
///   and applied them to the 405 method-not-allowed branch (it
///   previously emitted a bare 405 with no `Access-Control-Allow-
///   Origin`, breaking strict cross-origin probes). Email-validate
///   regex tightened to require ≥2-char TLD + reject angle
///   brackets + whitespace so a malicious reply-to can't inject
///   email headers.
///
/// DOCUMENTATION
/// • HANDOFF.md — Bible Versions table no longer lists NIV (which
///   was removed in 2026-05); Dependencies table updated to reflect
///   the actually-installed packages including the round-56
///   re-addition of `google_fonts`; font_catalog strand description
///   reflects YaHei being unbundled.
/// • README.md — App Screenshots intro note updated for v1.2.5
///   (welcome-disclaimer screenshot pair removed from the table).
/// • SCREENSHOTS.md — entry 11 marked OBSOLETE; status banner
///   updated to v1.2.5 (was stale at v0.1.0).
///
/// 2026-05-09 (v1.2.7 — first dev/qat/prod-flow release: BYOK Test
/// button): user asked for an in-card "Test" mechanism so they can
/// verify their pasted Gemini key actually authenticates against
/// Gemini before saving — previously they had to commit, navigate
/// to the search page, run a query, and hope the result wasn't a
/// fallback to the dev's shared pool. New behaviour:
/// • `gemini_key_card.dart` — added a Test button next to Save +
///   Clear. Tap fires a tiny POST to /api/aiBibleSearch with the
///   current input text (not the saved value) and `userApiKey: …`
///   so the Netlify function disables the dev-shared-key fallback
///   chain (callGemini uses ONLY the override key when present).
///   A 200 with refs is conclusive proof the user's key worked.
///   Status row below the buttons shows green check + "Key works!"
///   or a red X with the actual error from the server / a
///   localised network-error message.
/// • Six new ui-string keys: `aiByokTest`, `aiByokTesting`,
///   `aiByokTestOk`, `aiByokTestFailed`, `aiByokTestInvalidShape`,
///   `aiByokTestUnexpected`, `aiByokTestTimeout` — all three
///   locales.
/// • Inaugural use of the dev → qat → prod release flow: deployed
///   to yswords-dev + yswords-cn-dev only on the first push;
///   promoted to qat then prod after the user verified the
///   feature works on dev.
///
/// During the same v1.2.7 cycle (after the BYOK Test landed on
/// dev), the China-version icon marker was iterated three more
/// times based on user feedback:
///   1. The v1.2.4 中 watermark in the top-right was visually
///      competing with the dove which lives in that corner.
///   2. Moved 中 to the bottom-right corner — clears the dove but
///      hugs the rounded-square edge of the launcher icon mask.
///   3. Switched 中 → "CN" Latin letters (more legible at favicon
///      size and language-agnostic) and nudged the position
///      ~6% inward so the marker sits in the clear background
///      strip below the dove rather than against the corner.
///   4. Final colour pass: switched from a darkened-bg watermark
///      to the same blue as the Bible cover (auto-sampled at
///      generation time from the source icon, with a hardcoded
///      fallback). The marker now reads as part of the icon's
///      foreground palette rather than a bolt-on tag.
/// All three CN tier variants (cn-prod / cn-dev / cn-qat) share
/// the same marker logic in `tools/generate_site_icons.py`; only
/// the background tint differs per tier.
///
/// Native APKs were attempted via a GitHub Actions workflow but
/// the codebase has direct `dart:js_interop` imports that don't
/// compile on Android target (offline_pack_service +
/// cloud_sync_service + settings_page). The workflow + the
/// transitive web-package pin were reverted; deferred to v1.3.
/// HANDOFF.md → "Known Issues" carries the full revival
/// instructions. PWA Add-to-Home-Screen is documented as the
/// recommended mobile install path in the meantime — the per-
/// site icons (v1.2.3+) were specifically designed for it.
///
/// 2026-05-09 (v1.2.8 — post-v1.2.7 audit polish): user asked
/// "真没有 bug 了嘛" right after v1.2.7 shipped. A targeted Explore
/// agent on the new BYOK Test code found two real edge cases — both
/// fixed before they ever bite a user.
/// • Race condition on `_testStatus` from a stale in-flight Future.
///   Scenario: paste key A → tap Test (25 s Future starts) → paste
///   key B → tap Test → key A's slow result lands and briefly
///   clobbers key B's newer state. Fixed with a generation counter
///   (`_testGen`) bumped on every test start AND every text edit;
///   each Future captures `myGen = ++_testGen` and bails out
///   silently if `myGen != _testGen` by the time it tries to
///   setState. Five guard sites total (200 success / 200 unexpected
///   / non-200 / timeout / general catch).
/// • Unhandled `FormatException` if a HTTP-200 response carries a
///   non-JSON body (rare CDN slicing / mid-stream truncation). Was
///   leaking `"FormatException: …"` raw into the status row.
///   Wrapped the offending `jsonDecode` in a try/catch that surfaces
///   the localised `aiByokTestUnexpected` message instead.
/// First polish release shipped via the dev → qat → prod flow from
/// the start (no shortcut to prod) — exercises the workflow under
/// a minor change too.
///
/// 2026-05-09 (v1.2.9 — onboarding tour: AI slide added): user
/// noticed the v2 onboarding tour didn't even mention AI even
/// though the AI features (AI Bible search, AI Word explanation /
/// BDAG-style exegesis, BYOK Test button) are now central to the
/// v1.2.x line. Added a dedicated 6th slide between "Read" and
/// "Sermons" titled "AI 研经助手 / AI study helpers" describing the
/// three core AI surfaces (theme search / word study / evidence
/// Q&A) and pointing at the BYOK card with the Test button.
/// `onboarding_dialog.dart` `_kSeen` bumped from `v2` to `v3` so
/// existing users see the refreshed tour once on next launch
/// before their flag migrates. `app_settings.dart` reset path
/// now clears v3 / v2 / v1 keys together so a Settings reset
/// definitely re-shows the tour. Two new ui-string keys:
/// `onboardAiTitle` + `onboardAiBody` (zh-Hans / zh-Hant / en).
///
/// 2026-05-10 (v1.2.10 — verse-load resilience: auto-retry +
/// timeout + progress UI): user reported "it says failed to load
/// verse and i need to open it again it load. and sometimes it
/// takes a long time to load." Three-layer fix in
/// `lib/services/fetch_verses.dart` + the splash:
/// • LAYER 1 — retry inside `FetchVerses.execute`. Up to 3 attempts
///   with exponential-ish backoff (400 ms / 1200 ms) and a fresh
///   paragraph-cache wipe between attempts (so a corrupt-on-first-
///   load paragraph map can't poison the retries). Default knobs
///   (`_kDefaultMaxAttempts`, `_kDefaultTimeout`) callable as named
///   args by the manual-retry path too.
/// • LAYER 2 — per-attempt timeout. Each rootBundle.loadString +
///   parse is wrapped in `.timeout(Duration(seconds: 12))`. Without
///   this a stalled service-worker fetch sat indefinitely on the
///   splash. Worst-case wall-clock before bailing to the manual
///   error scaffold: ~37 s for the auto-retry cycle, then another
///   ~37 s if the user clicks Retry — a real recovery window for
///   transient failures (mobile-Safari OOM during JSON decode,
///   service-worker partial response, GFW DNS hiccup pulling
///   adjacent resources).
/// • LAYER 3 — progress UI. New `loadAttempt` / `loadMaxAttempts`
///   on MainProvider track in-flight retries; the splash paints a
///   subtle spinner + "Loading verses…" (attempt 1) or
///   "Retrying… (n/max)" (attempts 2+) below the daily-verse text
///   so users know something IS happening. Two new ui-string keys:
///   `loadingVerses` and `retryingAttempt` (zh-Hans / zh-Hant /
///   en, with `{n}` / `{max}` placeholders).
/// Tested: flutter analyze + tests pass. The happy-path (attempt 1
/// succeeds) is byte-identical to v1.2.9 from the user's POV — the
/// progress subtitle only paints if the load is actually slow
/// enough to be visible.
///
/// 2026-05-10 (v1.2.11 — onboarding tour: China-mode copy fix):
/// post-v1.2.10 QC audit caught that the v1.2.9 onboarding's last
/// slide ("Customize & sync") still pitched "Sign in with Google
/// to sync bookmarks…" even in the China build. v1.2.1 had hidden
/// the Sign-in button entirely in `kChinaMode`, so a tour that
/// promised it would just send the user looking for a button that
/// doesn't exist. Two new ui-string keys — `onboardCustomizeTitleChina`
/// + `onboardCustomizeBodyChina` — replace the last slide's copy
/// in the China build with "all stays on this device". The slide-
/// builder in `onboarding_dialog.dart` now branches on `kChinaMode`
/// for the title + body, leaving the international tour byte-
/// identical. New `import 'package:yswords/constants/build_flags.dart'`
/// in onboarding_dialog.
///
/// 2026-05-10 (v1.2.12 — v1.2.10's retry was a placebo): user came
/// back next day saying "dev 还是 failed load 我重进才 load" —
/// the auto-retry added in v1.2.10 wasn't actually retrying.
/// Diagnosis: Flutter web's `rootBundle.loadString(path)` memoises
/// the in-flight Future per-asset. Once attempt 1 timed out, my
/// attempts 2 and 3 just re-awaited the SAME already-rejected
/// promise without ever asking the service worker for a fresh
/// fetch. Three "retries" collapsed into one effective try.
/// Three fixes:
/// 1. `rootBundle.clear(path)` for the version JSON + both
///    paragraph-reference assets BEFORE each retry — forces
///    Flutter to drop its memoised Future and start a brand-new
///    SW fetch.
/// 2. Per-attempt timeout bumped 12 s → 20 s. A 10 MB JSON over
///    LTE on a cold service-worker install can legitimately take
///    ~15 s; 12 s was false-failing real loads.
/// 3. New "Reload page (clear cache)" escape-hatch button on the
///    error scaffold (web only). Calls into the existing
///    `window.yswordsClearCacheAndReload()` JS helper that
///    Settings already uses — unregisters every SW + nukes every
///    cache bucket + hard-reloads. User-localStorage is preserved.
///    Plus a "Show details" expander that surfaces the raw
///    `loadError` string so the user / dev can tell which asset
///    actually failed without console access.
/// New ui-strings: `hardReloadPage`, `showDetails`. Backoff also
/// bumped to 600 / 1500 ms (was 400 / 800).
///
/// 2026-05-10 (v1.2.13 — version-switch UX rewrite): user said
/// "整本圣经 change version loading 很久，不用 keepnstate 了，
/// 快一点其实好像". Two problems with the old flow:
/// 1. The "Loading version…" snackbar fired but the reading
///    pane kept rendering the OLD version's verses, frozen, for
///    the 1–3 s of synchronous `json.decode` of the new
///    version's 5–10 MB JSON. To the user it looked broken.
/// 2. We tried to preserve the chapter-relative verse number
///    across the switch (`_captureChapterRelativeVerseNum` +
///    `_scrollToVerseInChapter`) — added layout-measurement
///    work + complexity for marginal benefit. User explicitly
///    said don't bother.
/// Fix:
/// • New `versionSwitching` flag + `versionSwitchingTo` label on
///   MainProvider, set true the moment `onVersionSelected` fires.
/// • bible_reading_pane Stack now ends with a `Positioned.fill`
///   opaque overlay painted whenever `versionSwitching` is true:
///   spinner + bold "Loading version · KJV" text on a clean
///   scaffold-coloured background. User sees a clear loading
///   screen instead of frozen old verses.
/// • `onVersionSelected` rewritten — sets the flag, yields once
///   so the overlay paints, runs setVersion / FetchVerses /
///   FetchBooks, lands the user at the top of the same chapter
///   number in the new version (book-name translated), clears
///   the flag in a finally block. No more
///   `_captureChapterRelativeVerseNum` /
///   `_scrollToVerseInChapter` — those wrappers were the only
///   callers of those helpers and got removed too.
/// • `messenger?.showSnackBar` for "Loading version…" dropped —
///   the overlay supersedes it. Failure-fallback snackbar still
///   fires if the new version's JSON is missing.
/// Net: same hard wall-clock parse time (we can't make
/// json.decode faster without a Web Worker), but **perceived**
/// time is much shorter — loading state is immediately visible.
///
/// 2026-05-10 (v1.2.14 — version cache for "一瞬间" switch):
/// after v1.2.13 user came back: "为什么换 version 不是一瞬间，
/// 之前都是一瞬间的". Honest answer: my v1.2.13 overlay made the
/// loading state MORE visible than the old silent freeze, so it
/// felt slower even though wall-clock was the same. The real
/// fix: don't re-parse versions the user has already loaded
/// this session. New `LinkedHashMap<String, List<Verse>>`
/// LRU cache on MainProvider holds the last 4 parsed verse
/// lists (~24 MB worst case). `useCachedVersion(version)` swaps
/// in the cached list, marks `currentVersion`, invalidates
/// derived caches, notifies — all in microseconds. The
/// `onVersionSelected` flow now tries the cache FIRST and
/// short-circuits with no overlay / no yield / no FetchVerses
/// when the cache hits. First switch to a brand-new version
/// still shows the overlay (pure cache miss); second switch
/// back to it = "一瞬间", what the user expected.
///
/// 2026-05-10 (v1.2.15 — background pre-load common versions):
/// after v1.2.14 user asked "loading screen 不用，换经文应该是
/// 很快的吧，要不当进入的时候 loading 已经 loaded 所有 version".
/// Loading ALL 9 versions on boot would add ~10 s × ~60 MB of
/// work to startup — not worth it. Instead, after the splash →
/// home transition settles (5 s post-boot), `_AppState`
/// kicks off a low-priority background pre-load of four hand-
/// picked common versions: KJV (English flagship), CUV
/// (Chinese union 传统), CUVS-YHWH (simplified Chinese with
/// divine-name treatment, the default), CNV (modern 新译本).
/// Each parse is followed by a 4 s pause so the inevitable 1 s
/// json.decode freeze doesn't chain into a noticeable hitch.
/// By ~16 s post-boot, MainProvider's LRU (now
/// `_kVersesCacheLimit = 6`, up from 4) holds the active
/// version PLUS the four common ones. First user-driven
/// switch to any of those: cache hit → instant. Second+
/// switch: cache hit → instant. Only off-list versions
/// (NASB / LEB / *-tr variants) still trigger the overlay on
/// first pick — and that's a one-time hit before they enter
/// the LRU too.
/// New API: `FetchVerses.loadVerseList(version)` — public
/// static helper that returns a parsed `List<Verse>` without
/// touching any provider. `MainProvider.preloadVersion(version)`
/// wraps it + populates `_versesCache` silently.
/// `_preloadCommonVersions` lives in `_AppState` next to
/// `_bootstrap`.
///
/// 2026-05-10 (v1.2.16 — pre-load ALL versions + multi-slot
/// paragraph cache): user pushed back on the 4-version preload
/// list ("都要预加载啊在里面而且前后一章都要"). Want every
/// version cached + previous/next chapter switching to be
/// instant. Two changes:
/// (a) `_preloadCommonVersions` now iterates the FULL 13-entry
///     `bibleVersions` list in priority order: simplified Chinese
///     staples → English → traditional Chinese → LJK 1/2.
///     Memory cost: 13 × ~6 MB ≈ 78 MB cached parsed lists. LRU
///     cap bumped 6 → 15 so all 13 + active + slack coexist
///     without evicting each other. Total background work
///     ~50 s (13 × ~1 s parse + 3 s gap).
/// (b) Paragraph-groups cache refactored single-slot → 30-entry
///     LRU keyed by `currentVersion | book | chapter |
///     paragraphMode | versesLength`. Old behaviour: any verse-
///     list change invalidated the entire cache, so switching
///     versions on the same chapter forced a recompute (~50 ms).
///     New behaviour: KJV John 3 + CUV John 3 + LJK John 3
///     coexist as separate keys, all stay warm. Re-visiting a
///     (version, chapter) pair the user has already seen is now
///     truly instant — no verse parse AND no paragraph-group
///     recompute. Addresses the "前后一章" half of the request:
///     adjacent chapters in the current version stay cached as
///     long as you keep visiting them.
///
/// 2026-05-10 (v1.2.17 — sync BYOK Gemini key across devices):
/// user asked "可以 sync gemini api across devices push" — yes.
/// New `users/{uid}/account/geminiApiKey` path on Firebase RTDB
/// (separate from the per-profile `users/{uid}/sync` blob since
/// the BYOK key is account-level, not profile-scoped). Firebase
/// rules enforce per-uid isolation so only the signed-in user
/// themselves can read/write their own copy.
/// Push: every `AppSettings.setGeminiApiKey` fire-and-forgets a
/// write to RTDB after the local SharedPreferences save (silent
/// no-op when not signed in / Firebase unconfigured / China
/// build). Pull: `_pullGeminiKeyFromCloudIfEmpty` runs at the
/// end of `loadSettings()` AND on every CloudAuthService auth-
/// state change — local-empty-only policy avoids clobbering a
/// freshly-pasted key the user hasn't synced yet.
/// `GeminiKeyCard` mirrors the cloud-pulled key into the text
/// controller via a settings listener (only when controller is
/// empty, so user mid-typing isn't disrupted) and shows a small
/// "☁ Signed in — auto-syncs to other devices" disclosure under
/// the input when applicable. The `aiByokBody` copy was softened
/// from "never synced across devices" to just "lives on this
/// device" since the new claim is conditional on auth state.
/// China build: kChinaMode skips Firebase init, so push/pull no-
/// op silently and the key remains SharedPreferences-only — same
/// as before, no regression.
///
/// 2026-05-10 (v1.2.18 — eager pre-load during boot): user said
/// the v1.2.16 background pre-load still let occasional overlays
/// slip through ("loading 还是 慢 across page... 反正第一次用才
/// load version，就全部 load 吧"). Made the trade explicit: accept
/// a longer splash on cold boot (~20–30 s for 12 non-active
/// versions) in exchange for guaranteed-instant version + chapter
/// switching for the rest of the session.
/// `_eagerPreloadAllVersions` now runs INSIDE bootstrap before the
/// `_loading = false` setState. `MainProvider.versionPreloadCount`
/// + `versionPreloadTotal` drive a new "Loading versions: 5/13"
/// splash subtitle (new ui-string `loadingVersionsProgress`)
/// while the sequential parse runs. After boot, the LRU cache
/// holds all 13 versions + the active one; every user pick is a
/// cache hit. The previous fire-and-forget background helper
/// `_preloadCommonVersions` was removed.
///
/// 2026-05-10 (v1.2.19 — three QC fixes from user testing): user
/// reported (a) "bibleapp version not showing in dev qat about
/// page", (b) books grid view "one word chinese or english one"
/// looked bad, (c) "by clicking verse it doesn't jump to right
/// verse correctly".
/// (a) About AppBar title now appends `· v$kAppVersion` so the
///     running build is visible without scrolling 6+ sections.
///     Footer entry kept for copy-paste support purposes.
/// (b) `book_chapter_picker.dart` `_bookTile` swapped
///     `BoxFit.scaleDown` → `BoxFit.contain` so single-character
///     labels (Chinese "创", "约" or short English "John")
///     scale UP to fill the square tile instead of floating tiny
///     in the centre. Multi-char labels like "撒母耳记上" still
///     scale DOWN — `contain` does both.
/// (c) Two defensive fixes in `MainProvider.useCachedVersion`:
///     evict cross-version paragraph-cache entries (the v1.2.16
///     LRU was keeping `verseToItemMap`s from other versions
///     warm; while the verse-grouping was correct, a stale map
///     surfacing on a chapter rebuild could send the post-frame
///     pendingJump drain to a wrong index); AND clear any in-
///     flight `_pendingJumpChapterVerseIndex` before the swap so
///     a jump queued against the OLD version's chapter doesn't
///     fire against the new one.
///
/// 2026-05-10 (v1.2.20 — best-effort QC sweep): user said "last
/// update time is still wrong and try to fix all bugs with best
/// effort". Two real findings from the targeted audit:
/// 1. The About footer's "Last updated YYYY-MM-DD" was a hardcoded
///    string in `aboutFooterNote`. Stale-drifted across v1.2.5 →
///    v1.2.19 (stuck on 2026-05-07). Now templated with a `{date}`
///    placeholder that `about_page.dart` interpolates with
///    `kAppReleaseDate` (declared below). Bump BOTH `kAppVersion`
///    and `kAppReleaseDate` together — nothing else to update.
/// 2. `RealtimeDbSyncService._parseJsonMap` had a bare
///    `catch (_) {}` swallowing JSON-decode failures of cloud-
///    side payloads. Now logs to `debugPrint` so a corrupt blob
///    surfaces in the dev console instead of silently degrading
///    to an empty merge.
///
/// 2026-05-10 (v1.2.21 — audit fixes + listener-leak fix):
/// user said "still more bugs fix fully". Spawned two parallel
/// audit agents (resource-leak focus + localisation/UI focus);
/// triaged + fixed real findings:
/// 1. Three pages had hardcoded English "Failed to load:" error
///    strings — `family_tree_page.dart:289`,
///    `bible_timeline_page.dart:82`, `sermons_page.dart:185`.
///    All three now use the existing localised
///    `loadErrorTitle` ui-string (which already has zh-Hans /
///    zh-Hant / en).
/// 2. `loading_page.dart` splash verse-reference text could clip
///    on narrow viewports — added `maxLines: 1`,
///    `overflow: TextOverflow.ellipsis`,
///    `textAlign: TextAlign.center`.
/// 3. `cloud_auth_service.dart::_doInit` — the
///    `auth.userChanges().listen(...)` subscription was untracked.
///    `retryInit()` could fire `_doInit()` again and accumulate
///    permanent stream listeners. Now stored as
///    `_userChangesSub` and cancelled before each fresh
///    subscription. Bounded leak (1-3 retries/session) but still
///    worth closing.
///
/// 2026-05-10 (v1.2.22 — boot perf + UI polish): user said
/// "increase performance and make sure all bugs fixed and ui ux
/// should be better". Three changes:
/// 1. **Hybrid pre-load.** v1.2.18 blocked the splash for ~25 s
///    eagerly loading all 13 versions. v1.2.22 keeps eager load
///    for ONLY the top 4 (cuvs-yhwh / cuv / cnv / kjv — 80% of
///    real-world switches) and defers the other 9 to a fire-
///    and-forget background pass with 3 s gaps after the splash
///    dismisses. Splash drops from ~25 s → ~5 s. By ~30 s post-
///    boot all 13 are still cached.
/// 2. **About AppBar overflow guard.** Added `maxLines: 1` +
///    `TextOverflow.ellipsis` to the "About · v1.2.22" title —
///    on 320 px-class viewports with bumped fontSize the
///    combined string was clipping mid-word.
/// 3. **Sync-success snackbar dark-mode fix.** Swapped
///    hardcoded `Colors.green.shade700` + `Colors.white` →
///    `paletteAccent(context, Colors.green)` + a brightness-
///    based contrast for the icon/text. Dark-mode users used to
///    see white-on-too-light contrast.
///
/// 2026-05-10 (v1.2.23 — polish pass: theme-aware colours +
/// padding consistency): user said "so much more". Picked off
/// the deferred polish items from v1.2.21/v1.2.22 audits:
/// • `feedback_page.dart` send-button spinner — was hardcoded
///   `Colors.white`, now `Theme.of(context).colorScheme.onPrimary`.
///   Reads correctly under any FilledButton palette.
/// • `floating_toast.dart` — foreground icon + text colour now
///   computed from `ThemeData.estimateBrightnessForColor(
///   background)` so a caller passing a light pastel doesn't
///   render invisible white text. Default callers (red / green
///   / blue) still get white as before.
/// • `map_viewer_page.dart:381` bookmark badge icon — was
///   hardcoded `Colors.white` over `scheme.primary` background;
///   now `scheme.onPrimary`. Future palette changes won't break
///   it.
/// • `gemini_key_card.dart` Card padding — was
///   `EdgeInsets.fromLTRB(14, 12, 14, 12)`, all neighbouring
///   Settings cards use 16/14. Standardised so the card no
///   longer looks visibly tighter than its siblings.
///
/// 2026-05-10 (v1.2.24 — release time precision): user asked
/// "release date and version 同步了吗？另外 release time 具体到
/// 时间分钟". v1.2.20-23 all shipped on the same calendar date
/// so the date-only `kAppReleaseDate` couldn't distinguish them.
/// Renamed `kAppReleaseDate` → `kAppReleaseTime`, expanded
/// format from "YYYY-MM-DD" to "YYYY-MM-DD HH:MM TZ" so each
/// release stamps a unique moment. ui-string `aboutFooterNote`
/// placeholder updated `{date}` → `{time}`. Single dev → qat →
/// prod cycle in one shot per user request.
///
/// 2026-05-10 (v1.2.25 — restored eager-all-13 pre-load): user
/// noticed v1.2.22's hybrid eager-top-4 + background-9 made the
/// splash stop at "Loading versions: 4/4" instead of progressing
/// through all 13 ("load why its 4/4 not all?"). Picked option B
/// — restore the v1.2.18 behaviour of loading ALL 13 eagerly
/// during splash, no background phase. Splash now goes 1/12 →
/// 12/12 (active version skipped, 12 others loaded). Boot
/// reverts to ~25 s but every session-life version + chapter
/// switch is instant — no overlay, no surprise wait.
/// `_backgroundPreloadRemainingVersions` removed; the merged
/// helper is now `_eagerPreloadAllVersions` (back to v1.2.18's
/// name).
///
/// 2026-05-10 (v1.2.26 — AI model picker): user "dev 可以在
/// setting 调整选择 ai mode". Adds three-tier AI response
/// depth selector to Settings → YsWords AI:
///   - 快 / Fast      → gemini-2.5-flash-lite (default; was the
///                      hardcoded MODEL constant pre-v1.2.26)
///   - 标准 / Standard → gemini-2.5-flash
///   - 深入 / Deep    → gemini-2.5-pro (smaller free-tier quota,
///                      BYOK key recommended)
/// New AppSettings field `aiModel` persisted in SharedPrefs +
/// allowlist-clamped against {'flash-lite', 'flash', 'pro'}. All
/// three Netlify functions (aiBibleSearch / aiSearch /
/// aiExplainWord) accept an `aiModel` body param and map to a
/// real Gemini model via a server-side `resolveModel` helper —
/// invalid/missing values fall back to the env default. Three
/// client services thread `aiModel` through. Dev-only deploy
/// per user request — qat/prod bumps after they verify on dev.
///
/// 2026-05-10 (v1.2.27 — AI model picker: per-tier detail panel):
/// user "会有写 default model 并且解释哪个好 performance 和 token
/// 限制之类的是吗". The v1.2.26 picker had a one-line generic body
/// that didn't tell the user which is the default, what each tier
/// maps to, or why "Deep" tends to fail without BYOK. v1.2.27 adds
/// a per-tier detail panel that updates with selection — names the
/// actual Gemini model, marks the default, calls out free-tier
/// quota reality so the user knows BYOK is required for the Deep
/// tier in practice.
/// Three new ui-strings: aiModelFastDetail / aiModelStandardDetail
/// / aiModelDeepDetail. New `_AiModelDetailPanel` widget rendered
/// below the SegmentedButton.
///
/// 2026-05-10 (v1.2.28 — splash-stuck-at-12/12 hotfix): user
/// reported "loading 13 verse 后就卡在那个 loading page了" —
/// after the eager pre-load reaches 12/12, the splash stays put
/// instead of advancing to home. Diagnosis: race between the
/// `_AppRoot` 4 s splash watchdog and `FetchVerses.execute`. On
/// slow networks the watchdog fires first, mounting LoadingPage
/// while `mainProvider.verses` is still empty. LoadingPage's
/// `initState` calls `_scheduleAdvanceIfReady` which returns
/// early (`verses.isEmpty`) and the 3 s auto-advance Timer is
/// never armed. When verses arrive shortly after — and even when
/// the eager pre-load finishes minting all 12 notifyListeners —
/// no code path re-arms the Timer.
/// Fix in loading_page.dart: a one-shot post-frame safety-net in
/// build() that calls `_scheduleAdvanceIfReady` the first time we
/// observe a non-error frame (verses populated, no loadError).
/// New `_advanceScheduledOnce` flag prevents the eager pre-load's
/// 12 rebuilds from cancelling-and-rearming the Timer on every
/// notify. The flag is reset in `_retry` so manual recovery still
/// works.
/// Critical bug: present on every live tier (dev/qat/prod). Push
/// straight through dev → qat → prod in one shot.
///
/// 2026-05-10 (v1.2.29 — post-v1.2.28 audit polish): three audit
/// agents (hotfix-edge-case + resource-leak + i18n) found:
/// • `bible_reading_pane.dart::_showNoteEditor` — TextEditingController
///   created at line ~2529 was never disposed. Each note edit
///   leaked one controller + its internal listeners. Disposed in
///   the existing `whenComplete` block.
/// • `loading_page.dart::_retry` — defensive: moved
///   `_advanceScheduledOnce = false` reset from PRE-await to
///   POST-await so a rebuild triggered by `setLoadError(null)`
///   can't pre-fire a stale-cached-verses Timer mid-fetch. Race
///   was latent in v1.2.28 (loadError only ever set when verses
///   are empty, so hasError stays true) but the new ordering
///   closes it for free.
/// • i18n sweep — same class as v1.2.21's batch fix. 9 hardcoded
///   English strings now route through `uiStrings`:
///     - `bible_reading_pane.dart:3549` Close tooltip
///     - `word_distribution_table.dart:148` "Failed to load"
///     - `sermon_detail_page.dart:243,261` body-missing /
///       failed-to-load error states
///     - 7 "Couldn't parse reference: $x" SnackBars in
///       library / news_detail / evidence / evidence_detail /
///       bible_timeline / dashboard / person_detail_sheet
/// New ui-string keys: `tooltipClose`, `couldNotParseRef`
/// (`{ref}` placeholder), `sermonNoBody` — all three locales.
///
/// 2026-05-19 (v1.2.55 — revert cross-version LEB overlay +
/// polish the native inline-annotation rendering): user
/// feedback after observing LEB Matt 4:12 — "Had been arrested
/// has those few words highlighted and can click and open …
/// ljk2 also has some that just few words for explanation.
/// can you check carefully that kind of format should be
/// applied to this book and other books … can you also remove
/// that LEB notes format from all other versions."
///
/// Two-part action:
///
/// (A) REVERT v1.2.53 cross-version LEB overlay.
///     The `(i)` chip surfacing LEB's notes inside KJV / CUV /
///     CNV / biblexg / NASB was tonally off — LEB's notes are
///     tied to LEB's specific English phrasing and read as
///     noise in other translations. Removed:
///       • lib/widgets/leb_insight_chip.dart (delete)
///       • lib/services/leb_insights_service.dart (delete)
///       • test/leb_insights_service_test.dart (delete)
///       • AppSettings.showLebInsights + persistence + reset
///       • 4 ui-string keys (showLebInsights*, lebInsight*)
///       • Settings → Reading toggle
///       • render-hook calls in paragraph_group_widget +
///         verse_widget
///       • LebInsightsService.init() call in main.dart
///     `lib/constants/book_names.dart` (extracted by v1.2.53
///     into its own file) is KEPT — `url_sync_service_web.dart`
///     (v1.2.54) now depends on it for the same dependency-
///     isolation reasons.
///
/// (B) POLISH the native inline-annotation rendering in
///     `lib/utils/build_verse_content_spans.dart`. LEB
///     (23,632 notes / 10,845 braces / 29,158 squares) and
///     biblexg-v2 (1,133 notes; no braces / squares — those
///     notes attach to a preceding word, not a wrapped phrase)
///     already had this format natively; v1.2.55 just tunes
///     the visuals:
///       • `{clarification}` chip border + bg: hardcoded teal
///         → `colorScheme.primary` at alpha 0.55 / 0.12. Now
///         follows the user's chosen palette instead of always
///         being teal.
///       • Inside-chip text colour: `onSecondaryContainer`
///         (high-contrast on old teal bg) → default body colour.
///         Reads as "this is verse text, slightly tinted to
///         signal it's clickable" rather than a badge of foreign
///         text.
///       • Inside-chip font size: 0.85× → 1.0× of body. Matches
///         surrounding prose so the clarification flows as part
///         of the sentence (which it semantically is).
///       • Standalone `<note: …>` icon: `Icons.menu_book` at
///         fontSize × 1.2 → `Icons.notes_rounded` at fontSize
///         × 0.9. Smaller, more discoverable footnote glyph;
///         doesn't dominate the line in paragraph mode.
///
/// Audit results pinned by this commit:
///   • LEB: all 64 books carry annotations (Daniel / Ezekiel /
///     Malachi / Deuteronomy / Leviticus are the densest at
///     400+ marks per 100 verses).
///   • biblexg-v2 (CN + TR): 24 / 27 NT books carry notes;
///     3 short epistles (2/3 John, Philemon) have none —
///     genuine asset data, not a rendering issue.
///
/// 60 / 60 tests pass (was 73 with v1.2.53 + v1.2.54 specific
/// tests — 13 deleted LEB-insights tests, 7 book-slugs tests
/// kept from v1.2.54).
///
/// 2026-05-19 (v1.2.54 — readable deep-link URLs that reflect
/// reader state): user request — "the link whether you can
/// improve? like if go which book, the link will have related…
/// Like /Rev cuvs like thos. think carefully".
///
/// The Flutter web build was shipping minified hash-based URLs
/// (`/#/minified:X4`) — opaque, un-shareable, un-bookmarkable.
/// v1.2.54 replaces them with a human-readable scheme that
/// reflects the current reading state, two-way synced:
///
///   /#/                       → dashboard / default
///   /#/genesis                → Genesis 1
///   /#/genesis/1              → Genesis 1
///   /#/john/3:16              → John 3, scroll-to-verse 16
///   /#/john/3:16?v=leb        → same, in LEB translation
///   /#/revelation/22?v=cuvs-yhwh
///
/// Behaviour:
///
///   • Cold deep link: visiting any of the URLs above lands the
///     user at the right book / chapter / verse / version. If
///     `v=` is present, the version swaps via `setVersion` +
///     `FetchVerses.execute`. If `:verse` is present, the
///     verse fires through the same pendingJump consumer used
///     by search / library / news (smooth scroll + highlight).
///
///   • Internal navigation: as the user changes chapter /
///     verse / version, the URL updates live via
///     `history.pushState` (debounced 150 ms so a rapid burst
///     of three `notifyListeners` calls writes one entry, not
///     three). Browser back / forward then walks the chapter
///     history.
///
///   • Browser back / forward: `popstate` listener re-parses
///     the hash and re-applies to MainProvider — same code path
///     as cold boot.
///
///   • Loop-guard: an `_isApplyingFromUrl` flag short-circuits
///     the `state → URL` listener while the `URL → state`
///     applier is running, so the two paths can't fight.
///
/// Slug map: `lib/constants/book_slugs.dart` carries canonical
/// English → lowercase-no-space slug (`'1 Samuel' → '1samuel'`,
/// `'Song of Solomon' → 'songofsolomon'`) plus a reverse map
/// with common short aliases (`gen`, `1sam`, `rev`, `sos`,
/// `psalm`/`psalms`, `matt`, `phlm`, …) so user-typed URLs
/// resolve even if they aren't fully canonical.
///
/// Cross-platform safety: the service uses the same
/// conditional-import pattern as `ShareService` /
/// `BrowserInfoService` / `NotificationService`. Web target gets
/// `url_sync_service_web.dart` (real `dart:js_interop` bindings
/// for `window.location.hash` + `window.history.pushState` +
/// `window.addEventListener('popstate')`). Native targets get
/// `url_sync_service_stub.dart` — a no-op. No new `dart:js_interop`
/// imports leak into native compile units (the same isolation
/// `cloud_sync_service.dart`'s v1.2.7 issue taught us).
///
/// `bookNameToEnglish` was already lifted to its own
/// dependency-free file in v1.2.53 (for the LEB-insights
/// service); the URL sync service reuses it here for the
/// reverse "local book name → canonical English" lookup that
/// drives the slug write.
///
/// New 7-test unit suite in `test/book_slugs_test.dart` pins:
///   • All 66 canonical books have a slug + round-trip
///   • Numbered books collapse spaces (`1 Samuel → 1samuel`)
///   • Song of Solomon collapses both spaces
///   • Short aliases resolve (`gen`, `rev`, `sos`, `1sam`, …)
///   • Input is normalised (uppercase + leading / trailing
///     whitespace tolerated)
///   • Unknown slugs return `null` (no exception)
///
/// Total: 73 / 73 tests pass.
///
/// 2026-05-18 (v1.2.53 — cross-version LEB translator-insights
/// overlay): user feedback — "I feel LEB has the best notes or
/// highlight or something. can you have a look and try to apply
/// those to other versions as well".
///
/// Data audit found LEB is the rich outlier in our 13-version
/// bundle:
///
///   • LEB:        23,632 `<note: …>` (77 / 100 verses)
///   • CUVS-YHWH:   1,290 (4 / 100v)
///   • biblexg-v2:  1,133 (14 / 100v)
///   • KJV / NASB / CUV / CNV / biblexg: ≤ 6 in total
///
/// LEB's notes are tied to LEB's specific English phrasing, so
/// they can't be mechanically copied into KJV / CUV / CNV (those
/// versions phrase things differently — "literal" notes about
/// Hebrew/Greek don't fit "before the people" the same way they
/// fit LEB's "in the faces of the people").
///
/// Cleanest solution: surface LEB's notes as a SUPPLEMENTARY
/// overlay when reading any other version. New components:
///
///   • `lib/services/leb_insights_service.dart` — singleton.
///     Idempotent `init()` parses LEB once (~50 ms on web) into a
///     `bookEnglish|chapter|verse → List<String>` map. ~14.4 k
///     verses indexed across ~23 k notes. Pre-warmed during
///     splash bootstrap.
///   • `lib/constants/book_names.dart` — extracted the existing
///     `bookNameToEnglish` map from `fetch_books.dart` so test-
///     only services can consume it without dragging in the
///     `MainProvider` → `cloud_sync_service.dart` →
///     `dart:js_interop` chain that breaks compile on VM tests.
///     `fetch_books.dart` re-exports for backwards compat.
///   • `lib/widgets/leb_insight_chip.dart` — `buildLebInsightChip`
///     returns an `InlineSpan` (small `Icons.info_outline_rounded`)
///     when settings.showLebInsights AND currentVersion != 'leb'
///     AND service has notes for the verse. Tap → AlertDialog
///     listing every LEB note for the verse, each on its own
///     bullet, with `lebInsightAttribution` footer
///     ("Source: Lexham English Bible").
///   • `paragraph_group_widget` + `verse_widget` call
///     `buildLebInsightChip` after rendering the verse content
///     spans; the chip is appended if non-null. Same render path
///     for both modes.
///   • `AppSettings.showLebInsights` — default `true`. Persists
///     via SharedPreferences key `'showLebInsights'`. Toggle in
///     Settings → Reading. Users on Chinese versions can opt out
///     if they find the English notes off-tone.
///   • Three new ui-strings: `showLebInsights`,
///     `showLebInsightsSubtitle`, `lebInsightDialogTitle`,
///     `lebInsightAttribution` — all in en / zh-Hans / zh-Hant.
///
/// LEB-asset quirks handled: it ships with truncated `Mic` / `Nah`
/// book names which are aliased on load to canonical `Micah` /
/// `Nahum` so lookups by the canonical English form (what
/// `bookNameToEnglish` produces) still hit. LEB is also missing
/// Judges + Obadiah entirely; those return empty (service fails
/// gracefully, chip just doesn't appear for those books).
///
/// 13-test unit suite in `test/leb_insights_service_test.dart`
/// pins:
///   • is-ready / annotated-verse-count thresholds
///   • EN / zh-Hans / zh-Hant book-name resolution
///   • Mic / Nah alias hits
///   • Judges / Obadiah / nonexistent-book empty returns
///   • init idempotency
///   • out-of-range chapter:verse safety
///
/// Total: 66 / 66 tests pass.
///
/// 2026-05-18 (v1.2.52 — annotation-stripping double-punct fix):
/// user reported a copied verse from CUVS-YHWH Rev 1:8 showed
/// `俄梅戛，，是昔在` — two commas where one should be. Root
/// cause: the source data file had the same punctuation on
/// BOTH sides of an annotation (`俄梅戛，<note: ...>，是昔在`),
/// so when `sanitizeForSearch` / `sanitizeVerseText` stripped
/// the `<note:>`, the punctuation duplicated.
///
/// Two-layer fix:
///
///   (A) DATA layer (atomic sweep): scanned every Bible JSON for
///       the `P<note:X>P` and `P{X}P` patterns where P is one of
///       `，。；：？！、`. Found 20 occurrences (10 in
///       `cuvs-yhwh.json` + 10 in the mirrored `cuvs-yhwh-tr.json`,
///       all in 10 distinct verses — Josh 21:11, 2 Sam 10:5,
///       Ezek 2:5, Acts 3:26 + 11:12, Col 3:16, 2 Thess 3:3,
///       Titus 3:7, 1 Pet 1:13, Rev 1:8). Removed the LEADING
///       punctuation in each (kept the trailing one — the note
///       hugs the term it annotates, then the natural sentence
///       punctuation follows). No other Bible asset had the
///       pattern. JSON validity preserved, 31,102 verses
///       unchanged in count per file.
///
///   (B) RENDER layer (defense-in-depth): added a
///       `_collapsePostStripDuplicates` pass at the end of
///       `sanitizeForSearch` / `sanitizeVerseText` in
///       `text_patterns.dart`. Collapses runs of any CJK punct
///       (`，。；：？！、`) to one, and runs of ASCII spaces to one.
///       Catches any future regression — or edge case the data
///       sweep missed — silently before text reaches the user.
///       Verified with 9-test unit suite in
///       `test/sanitize_collapse_test.dart`.
///
/// 2026-05-17 (v1.2.51 — paragraph-mode jump marker + BYOK
/// sync race-fix): user reported "i think because it is
/// paragraph mode that's why. juct check fully to fix it.
/// also why some api for gemini not synced".
///
/// (A) Paragraph-mode jump marker. Even with v1.2.50's
/// `primaryContainer` wash, a search-jump target can be hard
/// to spot mid-paragraph at a glance — the wash sits behind
/// inline text in a continuous block of paragraph prose,
/// and the user has to scan to find the colored region. v1.2.51
/// adds an inline `►` arrow icon (Icons.east_rounded) right
/// before the verse number when `isHighlighted` — same place
/// the bookmark / note glyphs go. Sized to font * 0.9, primary
/// colour. Auto-clears with the highlight after 3.5 s. Verse-
/// by-verse mode unchanged (the full-container wash already
/// stood out without help).
///
/// (B) BYOK Gemini key sync: the v1.2.47 "preserve local on
/// first emission" policy backfired in the most common pattern:
///   • Device A updates key X → Z. Cloud has Z.
///   • Device B was offline; reopens with local = X.
///   • Stream's first emission = Z. v1.2.47 saw local non-empty
///     and SKIPPED. Device B stayed on X. User report:
///     "why some api for gemini not synced".
/// New policy: cloud is source of truth. Every emission applies
/// unconditionally. To preserve the "paste while signed out →
/// sign in" flow without that special case, the new
/// `_doByokSync` pushes local to cloud BEFORE subscribing — so
/// the stream's first emission echoes local → no-op, no clobber.
///
/// Plus a forensic `debugPrint` trail across
/// `pushGeminiKey` / `watchGeminiKey` / `_handleRemoteGeminiKey`
/// / `_subscribe…` / `_doByokSync` so the next "sync didn't
/// work" report has full console diagnostics to point at.
///
/// 2026-05-17 (v1.2.50 — search-jump highlight uses
/// primaryContainer + forensic logging): user reported v1.2.49
/// still didn't show the highlight clearly. Diagnosis: the
/// `colorScheme.secondary` tint (even at the bumped 0.5 / 0.7
/// alpha) was visually drowned out by parchment / muted seed
/// palettes — particularly the default lightBlue seed which
/// puts `secondary` very close to neutral.
///
/// Fix: drop the `secondary` tint and make the search-jump
/// highlight render IDENTICAL to a hand-selected verse —
/// `colorScheme.primaryContainer` (saturated, theme-aware,
/// unmistakable). Same path in both `verse_widget.dart` (verse-
/// by-verse mode) and `paragraph_group_widget.dart` (paragraph
/// mode). Auto-clears after 3.5 s (bumped from 2.5 s) — long
/// enough for the user to orient on the verse, short enough
/// that reading flow isn't disturbed afterwards.
///
/// Also added a forensic `debugPrint` chain across the jump
/// flow: `prepareJumpToVerse` logs the inputs + matched book +
/// relIdx; the post-frame consumer logs each bail / success
/// path. Browser-console output now tells us exactly which
/// step a stuck jump halts at, so any future "verse not
/// highlighted" report can be diagnosed in seconds rather than
/// speculating from code-reading alone.
///
/// The 3.5 s clear timer also now guards `mp.highlightIndex ==
/// pendingIdx` before firing — if the user navigates again
/// before the timer fires, we don't accidentally wipe a fresher
/// highlight set by the new navigation.
///
/// 2026-05-17 (v1.2.49 — search-jump highlight + scroll
/// visibility): user reported "why in search the verse selected
/// not highlighted and jump properly". The pendingJump
/// machinery (resolveAndPrepareJump / prepareJumpToVerse →
/// BibleReadingPane's post-frame consumer) was correct, but
/// three UX choices made the result hard to perceive:
///
///   (a) Scroll alignment was 0.0 — the target item landed
///       glued to the very top of the viewport, so in paragraph
///       mode the highlighted verse could be anywhere inside the
///       paragraph block at the top edge. Users had to scan for
///       it. Fix: pass `alignment: 0.25` from the consumer's
///       scrollToIndexAnimated call so the SPL lands the target
///       item ~25 % from the top — comfortable reading position,
///       paragraph context above and below it.
///   (b) Scroll duration was 1 ms (effectively `jumpTo`). Visual
///       feedback was nil — the new chapter appeared at its new
///       position without any animation cue. Fix: 350 ms animated
///       scroll so the user perceives the navigation.
///   (c) Highlight visibility too low. `colorScheme.secondary`
///       with alpha 0.30 (paragraph mode) / 0.35–0.55 (verse-by-
///       verse) was easy to miss, especially against the cream/
///       parchment light theme. Plus the 1.2 s clear timer ran
///       out before the user finished orienting. Fix: alpha
///       0.5 (light) / 0.7 (dark) across both rendering paths
///       AND highlight duration 1.2 s → 2.5 s.
///
/// Net result: tap a search hit → smooth 350 ms slide to the
/// target verse (25 % from top) → 2.5 s prominent highlight
/// wash → fades. Same flow benefits Library / News / Evidence
/// reference taps for free since they all share the same
/// pendingJump consumer.
///
/// scrollToIndexAnimated signature now accepts an optional
/// `alignment` parameter (default 0.0, preserves all existing
/// callers' behaviour). Only the BibleReadingPane jump consumer
/// passes a non-zero value.
///
/// 2026-05-17 (v1.2.48 — devotional flows as one paragraph):
/// follow-up to v1.2.47 — the user clarified "灵修模式不是
/// 一节一行而是全部都一起的" (devotional should not be one verse
/// per line but all together). The previous implementation joined
/// each verse with `\n`, producing a verse-per-line layout. 灵修
/// / 抄经 style flows the text as a single continuous paragraph,
/// then the reference in parens at the end. Two-line fix:
///   • `getDevotionalFormattedText` in settings_page.dart:
///     `textParts.join('\n')` → `textParts.join(' ')`.
///   • `copyVerses` in bible_reading_pane.dart 'devotional'
///     branch: `sorted.map(...).join('\n')` → `.join(' ')`.
/// Settings preview now matches the real copy output for
/// multi-verse selections.
///
/// 2026-05-17 (v1.2.47 — copy-format preview fix, devotional
/// default, real-time BYOK sync): three user-reported issues
/// landed in one release.
///
/// (1) Copy-format preview — "include verse reference" preview
/// was wrong. The preview rendered the formatted string then
/// stripped every `\[...\]` to remove in-verse annotations,
/// which inadvertently ate the very `[Genesis 1:1]` reference
/// prefix the option promises. The actual copy logic
/// (`bible_reading_pane.dart::copyVerses` → `sanitizeForSearch`
/// in `text_patterns.dart`) only strips `<...>` and `{...}` —
/// it preserves `[...]` because some translations (KJV) use
/// brackets for italicised supplied words. Aligned the preview
/// with the real copy: keep `[...]` everywhere, so users see
/// exactly what gets copied (both the reference prefix AND the
/// in-verse italics).
///
/// (2) Default copy format → `devotional`. Was `withRef` since
/// the app's earliest days, but the user prefers devotional
/// (text first, reference in parens at the end — 灵修 / 抄经
/// friendly) as the day-to-day default. Three places updated in
/// `app_settings.dart`: field initialiser (line ~89),
/// `resetAllSettings` (line ~559), and `loadSettings`
/// fallback (line ~699). Existing users keep whatever they
/// picked — the SharedPrefs read short-circuits the fallback
/// when there's a value already; only fresh installs and
/// explicit Reset get the new default.
///
/// (3) BYOK Gemini key real-time sync. v1.2.17 added pull-on-
/// boot and pull-on-sign-in, but updates pasted on device A
/// only reached device B after a reboot or re-sign-in. v1.2.47
/// adds a true real-time RTDB listener:
///   • `RealtimeDbSyncService.watchGeminiKey()` returns a
///     `Stream<String?>` that emits on every change at
///     `users/{uid}/account/geminiApiKey`. Cloud-clear emits
///     `''` so device B can mirror the empty state.
///   • `AppSettings._subscribeToGeminiKeyChanges()` consumes
///     it. Semantics: first emission after subscribe is
///     pull-if-empty (preserves a freshly-pasted-but-not-pushed
///     key); subsequent emissions are applied unconditionally
///     INCLUDING clears.
///   • `AppSettings._unsubscribeFromGeminiKeyChanges()` cancels
///     on sign-out so the stream doesn't leak past the session.
///   • `GeminiKeyCard._onSettingsKeyChanged` was tightened with
///     a `_lastSyncedKey` baseline: clouds-driven changes mirror
///     into the text field even when it's already populated, BUT
///     only when the field still matches the last synced value
///     (i.e. the user isn't mid-edit on this device). Save-echoes
///     are detected and update the baseline without rewriting
///     the field.
///   • `aiByokSyncedNote` ui-string updated for all 3 locales
///     to say "syncs in real time … no restart needed".
///   • China build still skips (Firebase never initialised); BYOK
///     stays SharedPreferences-only for those users.
///
/// 2026-05-16 (v1.2.46 — harmonised aiBibleSearch quota-error
/// copy): thorough post-v1.2.45 verification on all 6 sites
/// exposed a minor copy inconsistency in the developer-shared-key
/// 429 message. `aiSearch.mjs` + `aiExplainWord.mjs` say "AI quota
/// for the developer's shared key is exhausted across all
/// free-tier models." but `aiBibleSearch.mjs` truncated to "AI
/// quota for the developer's shared key is exhausted." (no
/// "across all free-tier models" phrase). All three functions
/// step down across the same free-tier model chain
/// (gemini-3-flash-preview → gemini-2.5-flash → -lite), so the
/// shorter wording under-described what was tried. Backend-only
/// edit; frontend bundle unchanged. flutter analyze + 44/44
/// tests still green. BYOK message left alone — already
/// consistent.
///
/// 2026-05-11 (v1.2.45 — 祂 → 他 sweep where antecedent is
/// 耶穌/Christ; 神/雅偉 stays 祂): user "所有app里面提到耶稣不要
/// 用祂而是他，神雅伟才用祂好好全部改掉". Chinese Christian
/// convention reserves capitalised 祂 ("He") for deity; the
/// user's editorial position is that 耶穌 (Jesus) should use
/// 他 while 神 / 雅偉 / 聖靈 retain 祂.
///
/// Scope: 12,793 total 祂 across 200 sermon files + 4 JSON/Dart
/// assets. Naive find-replace would corrupt every God-reference;
/// implemented a context-aware Python classifier:
///   • For each 祂, scan back ≤400 chars (or to paragraph break)
///     for the most recent named antecedent.
///   • Marker lists: Jesus markers (主耶穌 / 耶穌基督 / 基督 /
///     人子 / 神的兒子 / 救主 / 羔羊 / 大祭司 / …) and God markers
///     (雅偉 / 雅威 / 耶和華 / 天父 / 父神 / 上帝 / 創造主 /
///     全能者 / 聖靈 / 神 / …).
///   • Regex pre-built with longest-first alternation so compound
///     markers (神的兒子) outrank prefix matches (神) at the same
///     position — a subtle bug in the first iteration where 神
///     was winning over 神的兒子.
///   • Ambiguous matches (no marker in window) default to keeping
///     祂 — conservative behaviour per user's "ambiguous → deity".
///
/// Results:
///   • 4,088 occurrences changed to 他 (Jesus references).
///   • 6,194 kept as 祂 (God / Spirit references).
///   • 2,511 kept as 祂 (ambiguous, conservative default).
///   • 200 files modified (sermons zh-CN + zh-TW, section_titles
///     .json, book_introductions.json, bible_evidence.json,
///     bible_trivia_page.dart).
///
/// Spot-check verification: 23 sampled changes (15 Jesus +
/// 8 God-kept + 5 ambiguous-kept) all correctly classified.
/// Known limitation: when 神-vocabulary is heavily interleaved
/// with Jesus content (e.g. "在祂里面居住...因為神的豐盛"), the
/// classifier may keep 祂 where a deeper coreference reader would
/// pick 他. These are reviewable case-by-case if you spot them.
///
/// 2026-05-11 (v1.2.44 — per-model timeout + better error
/// messaging on AI endpoints): user reported "Upstream AI service
/// error (HTTP ?)." on YsWords exegesis (Acts 19:14) with the
/// Retry button — the `?` placeholder meant the client received
/// no HTTP status, which only happens when the fetch itself
/// threw (AbortSignal timeout or network error).
///
/// Diagnosed with timed curl: aiExplainWord + Deep tier on Acts
/// 19:14 took 25.5 s on try 1, 24.4 s on try 2, then succeeded
/// in 7.9 s on try 3. The 25-second window was exactly
/// 3 × 8 s (= v1.2.42's flat per-call timeout × step-down chain
/// length) — `gemini-3-flash-preview` is a thinking model that
/// routinely needs 8-15 s on heavy prompts; v1.2.42's 8 s ceiling
/// killed it mid-thought before it could produce a response, and
/// the step-down chain then burned through Standard + Fast at
/// the same 8 s each.
///
/// FIX A — per-model abort timeout (3 backend functions):
///   gemini-3-flash-preview  18 s  (thinking — needs headroom)
///   gemini-2.5-flash        10 s  (standard)
///   gemini-2.5-flash-lite    6 s  (fastest)
///   default                 10 s  (defensive)
/// `callGeminiWithKey(...)` now picks its `AbortSignal.timeout`
/// per `model` via a new `modelTimeoutMs(model)` helper. Sum
/// worst case is 34 s — exceeds Netlify's 26 s cap — but the
/// outer wall-clock deadline bails before starting a call that
/// wouldn't finish.
///
/// FIX B — bumped deadline budget 22 s → 24 s, bail buffer
/// 1 s → 1.5 s. Combined with the per-model timeouts, the typical
/// step-down sequence (Deep 18 s + 4 s budget for retry, or
/// Standard 10 s + 12 s budget) fits inside Netlify's 26 s cap
/// with headroom for response serialisation.
///
/// FIX C — better public error message branching. Pre-fix, when
/// the fetch threw (status === 0), the function returned
/// `"Upstream AI service error (HTTP ?)."` which is both
/// confusing (the `?`) and misleading (the model was busy, not
/// erroring upstream). Post-fix:
///   status === 0  → HTTP 504, message:
///     "AI response took too long. The selected tier may be
///     under heavy use right now — try again, or pick a lighter
///     tier in Settings → AI."
///   status >= 500 → HTTP 502, message:
///     "Upstream AI service error (HTTP {actualCode}). Please
///     try again shortly."
///   429 (quota)   → unchanged; existing per-BYOK branching.
/// BYOK requests get a key-specific suffix ("on your Gemini
/// key").
///
/// Same fix applied symmetrically across all 3 Netlify functions
/// (aiBibleSearch / aiSearch / aiExplainWord).
///
/// 2026-05-11 (v1.2.43 — CJK query length + empty-hits content
/// fallback): user "standard one is not working for dev but qat
/// and prod are all working gemini. why? other deep and lite both
/// are working for dev. its strange since it's the same api".
///
/// Audit results — found TWO real bugs (and one explanation):
///
/// BUG 1 (HIGH): single-char CJK queries rejected. Both backends
///   and the two client services required `query.length >= 2`.
///   English needs ≥ 2 chars to be useful, but a single Chinese
///   ideograph (`爱` / `信` / `光`) carries a full semantic
///   concept and is a legitimate query. The user typing `爱` in
///   the search box got "Query is required (≥2 chars)" with no
///   path forward. Fix: lower the threshold to 1 char in:
///     - `netlify/functions/aiBibleSearch.mjs:307`
///     - `netlify/functions/aiSearch.mjs:382`
///     - `lib/services/ai_bible_search_service.dart:44`
///     - `lib/services/ai_search_service.dart:67`
///
/// BUG 2 (MEDIUM): LLM nondeterminism returns 0 refs for
///   semantically valid queries on Standard tier. Cross-tier
///   probe found `救恩` returning 0 refs on dev+qat but 10 on
///   prod within the same minute, SAME backend, SAME key. The
///   model occasionally outputs `{"refs":[]}` when it's
///   technically capable of answering — `temperature: 0.2`
///   reduces variance but doesn't eliminate it. Fix: in
///   aiBibleSearch.mjs, when the requested tier returns 0 refs
///   AND the user isn't on BYOK AND a lighter tier exists in the
///   step-down chain, retry ONCE on that tier as a content-
///   quality fallback. Capped at one extra call (total ≤ 2
///   upstream per request, fits the 22s deadline budget). Only
///   replaces the empty result if the fallback actually returns
///   refs. Users get a useful answer instead of "no matches".
///
/// EXPLANATION (not a bug): user's observation "Standard fails
///   on dev, works on qat/prod, same api" was real but
///   attributable to LLM noise + RPM bucket transience —
///   `gemini-2.5-flash` is 10 RPM on the single shared key, so
///   a brief flurry of test traffic across tiers can dip into
///   the per-minute rate-limit and any one tier's specific
///   second-by-second outcome varies. BUG 2's fix masks this
///   for the user (Standard 0 hits → flash-lite content
///   fallback returns refs anyway).
///
/// 2026-05-11 (v1.2.42 — robustness sweep + dead-code cleanup):
/// triggered by user "fix all bugs fully with good plan and
/// thinking". Three parallel audit agents (async/state +
/// backend deep-audit + dead-code) ran against the v1.2.27→v1.2.41
/// surface area; produced a triaged action list with four real
/// bugs and a sizeable dead-code cleanup.
///
/// BUG FIXES:
///
/// A. Backend step-down timeout budget — HIGH. v1.2.41 added a
///    3-tier model fallback chain but each call used
///    `AbortSignal.timeout(20_000)`. Worst case = 60 s, which
///    exceeds Netlify's 26 s function cap AND the client's 25 s
///    HTTP timeout — so Deep would never actually reach the
///    flash-lite fallback before getting killed. Fix in all 3
///    Netlify functions: tighten per-call timeout to 8 s + add
///    a wall-clock `deadline = Date.now() + 22_000` outer
///    budget that aborts the chain when remaining time < 1 s.
///    Now 8 s × 3 = 24 s < 26 s.
///
/// B. Recents list pollution — HIGH. v1.2.41 fired
///    `RecentSearchesService.add(...)` after every successful
///    debounced live-search → typing "love is the answer" saved
///    "lov" + "love" + "love " + "love i" + "love is" + … as
///    separate entries, flushing the user's real history off the
///    12-item cap. Fix in `search_page.dart`: replaced the
///    in-`search()` add with a separate `_recentsCommitTimer`
///    (2.5 s settle-debounce). Only when the user stops typing
///    for 2.5 s AND the query is still in the box AND it isn't
///    already the most-recent saved entry does it land in
///    SharedPreferences. Cancelled in `dispose()`.
///
/// C. BYOK silent downgrade — MEDIUM. v1.2.41's step-down chain
///    ran for BYOK requests too, so a power user picking Deep on
///    their own free Gemini key would silently get downgraded to
///    Standard if Pro 429'd — burning their own quota on
///    Standard-quality output with no signal. v1.2.40's commit
///    message claimed BYOK bypassed fallback but the code didn't
///    enforce it. Fix in all 3 backend functions: `isByok` guard
///    breaks the step-down `while` loop after the first inner
///    failure when `overrideKey` is set. Public error message
///    also branches — BYOK gets "Your Gemini key's quota is
///    exhausted for the selected tier" instead of the
///    shared-key text.
///
/// D. Recents write race — LOW. `RecentSearchesService.add` does
///    a non-atomic `getStringList` → mutate → `setStringList`.
///    Two overlapping calls (live-search-add racing a manual
///    delete) could interleave and drop an entry. Fix:
///    `Future<void> _writeLock` mutex chains every add / remove /
///    clear behind the previous write. All three callers go
///    through the same single-slot queue.
///
/// DEAD-CODE CLEANUP:
///
/// • Removed `fellBackToFlash` entirely. Backend (3 functions) no
///   longer emits the field; client services (3 result types) no
///   longer parse it; client UI surfaces (search/evidence/originals)
///   no longer have the now-unreachable notice branches; v1.2.37's
///   trigger words (`'deep tier needs'` / `'gemini api key'` /
///   `'深入'` / `'gemini api 密钥'` / `'gemini api 密鑰'`) removed
///   from both `_shouldOfferByokForNotice` heuristics. The flag
///   was always-`false` after v1.2.40 switched Deep to
///   `gemini-3-flash-preview`.
///
/// • Removed 3 dead ui-string keys (`aiDeepFellBackToStandard`,
///   `aiModelDeepDisabledTooltip`, `aiModelDeepLockedNote`). The
///   second + third were v1.2.39 BYOK-gating strings reverted in
///   v1.2.41; the first was v1.2.37's notice copy.
///
/// • Net: lib/ shrinks by ~80 lines; backend functions shrink by
///   ~30 lines. Same behaviour for users.
///
/// Pre-deploy verification:
///   • flutter analyze — 0 issues
///   • flutter test — 44/44 pass
///   • All 3 Netlify functions parse via `node --check`
///
/// 2026-05-11 (v1.2.41 — recents on live-search + backend model
/// step-down chain): user "ai standard one not working" + "recent
/// search but cannot see those anymore" + "its working in qat and
/// prod but not dev".
///
/// Two distinct bugs diagnosed:
///
/// 1. RECENTS WERE NOT PERSISTING ON LIVE SEARCH. The
///    search-as-you-type debounce (v1.1.7) calls `search()`
///    directly without going through the explicit `onSubmitted`
///    handler — so `RecentSearchesService.add(...)` (which lives
///    only in onSubmitted) never fired. Most users use live search
///    (250 ms debounce already shows results, no Enter needed),
///    so their Recent list stayed empty forever.
///    Fix: move the recents persistence into `search()` itself,
///    gated by `query.length >= 3` and `matches.isNotEmpty` so
///    only useful queries get logged. Both live-search and
///    onSubmitted now contribute to recents through the same path.
///
/// 2. SINGLE-KEY QUOTA EXHAUSTION RETURNS 0 HITS / 429 with no
///    fallback. Audit revealed every one of the 6 Netlify sites
///    has only 1 Gemini API key (`GEMINI_API_KEY`, no plural
///    `GEMINI_API_KEYS`). When that single key 429s (~250 RPD on
///    free-tier `gemini-2.5-flash`), the existing key-rotation
///    loop has nothing to fall through to, and the user gets a
///    hard "quota exhausted" error. User reported this as
///    "Standard not working on dev" — actually transient quota,
///    affects every tier at peak load.
///    Fix: model step-down chain in callGemini across all 3
///    Netlify functions (aiBibleSearch / aiSearch / aiExplainWord).
///    When the chosen model returns 429 on all keys, retry with
///    the next-lighter tier:
///        gemini-3-flash-preview  → gemini-2.5-flash
///        gemini-2.5-flash         → gemini-2.5-flash-lite
///        gemini-2.5-flash-lite   (terminal — 1000 RPD)
///    Net: a single-key day-long quota budget extends ~6× by
///    falling through to flash-lite. Users still get an answer
///    instead of a hard error.
///    Logs `[fn] gemini-X 429; falling back to gemini-Y.` so the
///    degradation is visible in Netlify logs.
///
/// Free-tier RPD reference (current):
///   gemini-3-flash-preview  — ~250 RPD
///   gemini-2.5-flash         — ~250 RPD
///   gemini-2.5-flash-lite   — ~1000 RPD
///   gemini-2.5-pro          — PAID ONLY since April 1 2026
///
/// 2026-05-11 (v1.2.40 — Deep tier now uses gemini-3-flash-preview):
/// user "i use my own free gemini api but deep one, when i search
/// it doesnt turn anything and when i hse exegesis it tunrs no
/// quota. can you research online maybe configuration maybe other
/// models can be used".
///
/// Research confirmed the actual cause: Google moved
/// `gemini-2.5-pro` BEHIND A PAYWALL on April 1, 2026. The free
/// tier no longer includes Pro for any user — even with their own
/// AI Studio API key — so every Deep request was hitting an
/// instant 429 quota-exhausted error. The v1.2.37 backend fallback
/// would have masked this for shared-key requests but could NOT
/// help BYOK requests (those skipped the fallback path because the
/// user explicitly opted into their own quota).
///
/// New free-tier-friendly Deep tier:
/// • `gemini-3-flash-preview` — high-speed thinking model with
///   configurable reasoning levels (minimal / low / medium /
///   high) and 1M-token context. "Near-Pro reasoning at
///   substantially lower latency" per Google's docs. Free input +
///   output, separate quota pool from flash / flash-lite.
///
/// Backend changes (3 Netlify functions: aiBibleSearch /
/// aiSearch / aiExplainWord):
/// • `_AI_MODEL_MAP['pro']` switched from `gemini-2.5-pro` to
///   `gemini-3-flash-preview`.
/// • Removed the v1.2.37 pre-emptive Pro→Flash fallback logic —
///   Deep now works natively on free tier (BYOK or shared key)
///   so no need to silently downgrade. The runtime
///   429-fall-through-to-next-key in `callGemini` still covers
///   transient rate-limit hits. `fellBackToFlash` response flag
///   stays in the contract (always `false` now) for backward
///   compat with v1.2.37+ clients.
///
/// Client changes:
/// • `settings_page.dart::_AiModelCard` — reverted v1.2.39's BYOK
///   gating (lock icon / disabled segment / locked-note). Every
///   tier is enabled now. BYOK is still recommended for heavy
///   use (the BYOK card sits below this card with that pitch).
/// • `aiModelDeepDetail` ui-string rewritten for all 3 locales
///   to name the new model, explain why we switched (April 2026
///   paywall), and call out that BYOK is no longer required.
///
/// Sources used in research:
/// • https://ai.google.dev/gemini-api/docs/pricing — confirmed
///   gemini-2.5-pro is "Not available" on free tier; lists 12+
///   free-tier-eligible models including `gemini-3-flash-preview`.
/// • https://ai.google.dev/gemini-api/docs/models — model API
///   identifiers.
///
/// 2026-05-11 (v1.2.39 — Deep tier hard-disabled when no BYOK,
/// plus history cleanup): user "when i chose deep in setting ai,
/// but search with yswords ai, nothing responded still". Backend
/// auto-fallback added in v1.2.37 was working (live curl
/// confirmed `pro` request returns refs + `fellBackToFlash:true`),
/// but the picker still LOOKED selectable for Deep, leading to
/// confusion when results came back as Flash quality without an
/// obvious explanation.
///
/// User suggestion: "i realize it might because i am using free
/// tier thats why pro version not available for pro. maybe check
/// whats availablr models and add or edit accordingly please".
/// Confirmed — `gemini-2.5-pro`'s free-tier daily quota is ~25
/// RPD per key vs ~1500 for `flash-lite`; on the dev's shared
/// 3-key pool, Pro is essentially always exhausted on prod
/// traffic.
///
/// Fix — close the gap in the picker UX:
/// • `settings_page.dart::_AiModelCard` — when
///   `settings.geminiApiKey.isEmpty`, the Deep `ButtonSegment`
///   sets `enabled: false` + a lock icon + a tooltip explaining
///   the gating. Below the picker, a subtle italic note
///   reinforces "Deep needs your own Gemini API key (set one in
///   the BYOK card below). Without it, Deep would silently run
///   as Standard."
/// • The picker's `selected` value is computed from an "effective
///   tier": when `aiModel == 'pro'` AND no BYOK, the selection
///   maps to `'flash'` so the picker matches what requests will
///   actually use (the v1.2.37 backend fallback maps that to
///   Flash anyway). The persisted `settings.aiModel` is NOT
///   mutated — once the user adds BYOK, Deep becomes selected
///   automatically.
/// • The `_AiModelDetailPanel` below the picker reads the same
///   effective tier so its description matches the picker state.
/// • Two new ui-strings: `aiModelDeepDisabledTooltip` (shown on
///   long-press / hover of the locked Deep segment) +
///   `aiModelDeepLockedNote` (subtle italic note under the
///   picker). Both have all 3 locales.
///
/// History cleanup: user also asked "github make sure remove all
/// Claude especially i can see two contributors including claude.
/// remove them". `git filter-branch --msg-filter` stripped
/// `Co-Authored-By: Claude...` trailers from every commit,
/// rewrote 11 commits + 10 tags, force-pushed main + tags. The
/// GitHub Contributors tab will refresh within a few hours;
/// Claude no longer shows as a co-author on any commit. Backup
/// branch `backup-pre-claude-strip-2026-05-11` retained locally
/// for safety. Going forward, commit messages don't include the
/// trailer.
///
/// 2026-05-11 (v1.2.38 — markdown rendering across all AI
/// surfaces): user "why it is like ** which means it is not
/// formatted well". Gemini ships `**bold**` / `*italic*` /
/// `# heading` / `- bullet` markers in its responses regardless
/// of system-prompt instructions to the contrary. The
/// `_parseAiMarkdown` helper added in v1.2.31 was rendering
/// these correctly on the OriginalsSheet word-study panel only —
/// every other AI surface still used plain `Text(_aiAnswer)` /
/// `Text(ref.reason)` etc., so users saw literal `**asterisks**`.
///
/// Fix:
/// • Extracted the parser into `lib/utils/ai_markdown.dart` as
///   `parseAiMarkdown(String, {required TextStyle base})` with
///   the same heuristic-based handling (headings → bold lines,
///   horizontal rules → dropped, bullets → `•`, inline `***` /
///   `**` / `*` / `_` → bold-italic / bold / italic / italic).
/// • `lib/widgets/originals_sheet.dart` — refactored to import
///   the shared util; the local copy + hoisted regex block is
///   removed (the multi-space regex stays, it's specific to
///   `_lookupVerseText`).
/// • `lib/pages/evidence_page.dart` — `_AiSearchDialog` answer
///   body now uses `SelectableText.rich(parseAiMarkdown(...))`
///   instead of plain `Text(...)`.
/// • `lib/pages/search_page.dart` — AI ref `reason` subtitle and
///   the inline `_aiNotice` banner (both render sites in
///   `_buildEmptyState` and `_buildAiRefList`) now use
///   `Text.rich(parseAiMarkdown(...))`.
/// • `lib/pages/settings_page.dart::_AiModelDetailPanel` — tier
///   detail panel renders through the parser so the
///   `aiModelDeepDetail` ui-string's `**Free-tier quota is
///   tiny**` callout actually appears bold.
///
/// Net effect: every AI surface in the app now shows actual
/// bold/italic/headings/bullets where Gemini emitted markdown,
/// instead of literal asterisks. Same call shape (`Text.rich` +
/// `TextSpan` children) so themes, font scaling, dark-mode
/// colors, and selection all work as before.
///
/// 2026-05-10 (v1.2.37 — Deep tier auto-fallback to Standard
/// when no BYOK): user reported "ai setting deep for 2.5 pro
/// version not working in search maybe also in otherfunctions".
/// Diagnosed: not a bug — `gemini-2.5-pro`'s free-tier quota on
/// the developer's shared keys is essentially always exhausted
/// (much smaller than flash/flash-lite). All Pro requests
/// returned 429 with a quota-exhausted message. Flash and
/// Flash-Lite both worked.
///
/// Fix — transparent fallback + clear messaging:
///
/// Backend (3 Netlify functions):
/// • `aiBibleSearch.mjs` / `aiSearch.mjs` / `aiExplainWord.mjs` —
///   when `aiModel === 'pro'` AND no BYOK key is supplied, the
///   resolved model silently downgrades to `flash`. The response
///   includes `fellBackToFlash: true` so the client UI can show
///   a one-line notice + BYOK CTA. Users WITH BYOK get true Pro
///   on their own quota — unchanged.
///
/// Client (3 services):
/// • `ai_bible_search_service.dart` / `ai_search_service.dart` /
///   `ai_word_service.dart` — result types gain a
///   `fellBackToFlash` boolean that's read from the backend
///   response.
///
/// UI surfaces (3 sites):
/// • `search_page.dart` — when `result.fellBackToFlash`, the
///   `_aiNotice` channel leads with the new
///   `aiDeepFellBackToStandard` ui-string (3 locales). Existing
///   BYOK-CTA heuristic gains `'deep tier needs'` /
///   `'gemini api key'` / 深入 / Gemini API 密钥/密鑰 trigger
///   words so the chip auto-appears.
/// • `evidence_page.dart::_AiSearchDialog._ask` — same notice +
///   heuristic update.
/// • `originals_sheet.dart::_loadAiExplanation` — prepends the
///   notice to the explanation chunk text so users see it above
///   the actual word study output.
///
/// Settings:
/// • `aiModelDeepDetail` ui-string rewritten for all 3 locales
///   to be explicit: "without BYOK, requests transparently fall
///   back to Standard (Flash)". Sets accurate expectations
///   before users pick the tier.
///
/// Net result: picking Deep without BYOK still produces a useful
/// answer (Flash quality) instead of a quota error. The user is
/// told what happened and offered a one-tap path to set up BYOK
/// for real Deep responses.
///
/// 2026-05-10 (v1.2.36 — dark-mode era-title contrast fix +
/// priorities doc): user reported "for bible timeline and family
/// tree its hard to see those titles in dark mode". Both pages
/// rendered era-tinted titles ("OT / NT / Patriarchs / Mosaic /
/// Conquest / Monarchy / Exile / …") with a hardcoded dark
/// palette (lightness ~33–44 %) tuned for light surfaces. On the
/// dark theme's `#121212`-ish surface the titles faded into the
/// background.
///
/// Fix: brightness-aware foreground helpers that lerp the era
/// colour toward white by 0.45 in dark mode (preserves the
/// hue / colour-coding while pushing the value high enough to
/// clear contrast). Backgrounds + borders + low-alpha gradients
/// keep the raw deeper hue — those are decorative and don't need
/// to clear text contrast.
///
/// • `bible_timeline_page.dart` — new `_eraColorOn(brightness,
///   era)` helper; `_EraDivider` now uses `fg` for its icon +
///   title, raw `color` for the gradient + left border.
/// • `family_tree_page.dart` — same `_eraColorOn` helper plus a
///   sibling `_readableEraFg(context, eraColor)` that operates on
///   pre-resolved colors (used by `_BridgeFooter`, `_BridgeChip`,
///   `_NextEraTag`, the `east_rounded` next-era icon, and the
///   per-person era pill in `_SearchResultTile`). Era headers
///   (chevron + history_edu icons + era title + people-count
///   badge) all switch to the brightness-aware variant.
///
/// Plus: new `docs/priorities.md` capturing the high-ROI deferred
/// items from the v1.2.35 robustness review (CI workflow, error
/// monitoring, Lam 5:21/22 data fix, test coverage on risky files,
/// browser-matrix verification). Lives separately from
/// HANDOFF.md's "Known Issues" so it can be re-prioritised
/// without rewriting the canonical doc.
///
/// 2026-05-10 (v1.2.35 — viewer-local-time release stamp): user
/// "uodate last edit should based on user's timezone also default
/// to melbourne one right". v1.2.34 stamped the build moment in
/// Melbourne wall-clock — every user worldwide saw `19:48 AEST`.
/// v1.2.35 changes the stamp to ISO 8601 UTC + adds a
/// `formatReleaseTimeLocal()` helper that converts to the
/// viewer's local timezone at display time.
/// • Build script (`tools/build_web.py::current_release_time`)
///   now emits `time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())`
///   — e.g. `2026-05-10T09:48:00Z`. Pre-v1.2.35 it emitted the
///   localtime string `2026-05-10 19:48 AEST`.
/// • `lib/constants/app_version.dart` adds `formatReleaseTimeLocal()`:
///   parses the ISO UTC, applies `DateTime.toLocal()`, formats
///   `YYYY-MM-DD HH:MM TZ`. Falls back to the raw const string if
///   parsing fails (which only happens during dev `flutter run`).
/// • `lib/pages/about_page.dart` calls the helper instead of
///   substituting the raw const into the footer.
/// • `test/release_time_format_test.dart` pins the new behaviour.
/// Net result: a Melbourne user sees `2026-05-10 19:48 AEST`, an
/// NYC user sees `2026-05-10 04:48 EST`, a Beijing user sees
/// `2026-05-10 17:48 CST` — same instant, every viewer's own
/// zone. Dev builds without UTC injection still show the
/// Melbourne-build-machine wall-clock fallback ("default to
/// Melbourne" per user request).
///
/// 2026-05-10 (v1.2.34 — auto-stamp version + release time): user
/// "kAppReleaseTime kAppVersion they are automatically update in
/// app now right?" — they weren't; both were hand-edited every
/// release. v1.2.34 makes `pubspec.yaml`'s `version:` the single
/// source of truth and auto-stamps the actual build moment as
/// `kAppReleaseTime`.
/// • Both constants now use `String.fromEnvironment` with
///   sensible fallbacks (last-released / `dev-build`) so plain
///   `flutter run` still works without setup.
/// • New `tools/build_web.py` wraps `flutter build web --release`
///   for both flavours. Reads pubspec's version, captures
///   `time.strftime('%Y-%m-%d %H:%M %Z')`, passes both via
///   `--dart-define`. Used in place of the manual
///   `flutter build web --release ...` invocations.
/// • Net release flow: bump only `pubspec.yaml`'s `version:` →
///   run `tools/build_web.py` → run `tools/deploy_site.py
///   --tier <…>`. Both kAppVersion and kAppReleaseTime are
///   correct on the live site automatically.
/// • The fallback default for `kAppVersion` still gets bumped
///   alongside pubspec each release (so `flutter run` shows the
///   right version during dev). `kAppReleaseTime`'s fallback is
///   `'YYYY-MM-DD dev-build'` so dev builds are visually
///   distinct from real releases on the About page.
///
/// 2026-05-10 (v1.2.33 — divine-name 雅威 → 雅偉 sweep):
/// follow-up to v1.2.32. User said "很多地方寫雅威但是需要雅偉
/// 繁體字有時候寫雅伟 需要雅偉" — 1.2.32 only fixed cnv-tr.json's
/// asset content, missing the 雅威 occurrences scattered across
/// runtime-render code, version labels, UI strings, Hebrew gloss
/// data, and bible_evidence content.
///
/// Comprehensive scan + fix:
/// • `text_patterns.dart::_normalizeDivineNames` — THE big one.
///   Render-side normalisation that converts CUV's `耶和華` to the
///   project's Yahweh form for every traditional reader. Was
///   producing `雅威`; now produces `雅偉`.
/// • `bible_versions.dart` cnv-tr labels: `新譯本·雅威` /
///   `新譯本（繁體·雅威版）` → `雅偉` / `雅偉版`.
/// • `ui_strings.dart` zh-Hant footers: `CUVS-YHWH 和合本雅威版`
///   → `雅偉版`; copyright lines `© 雅威的話事工` →
///   `雅偉的話事工`; `雅威版社群研經版本` → `雅偉版`.
/// • `strongs_service.dart`: `_normaliseDivineGloss` 雅威 → 雅偉
///   (matches the rendered output everywhere else); alias map
///   gains `雅偉: H3068` while keeping `雅威: H3068` for
///   backward-compat input matching (users who type the old form
///   in search still find YHWH).
/// • `bible_trivia_page.dart`: 9 zh-Hant trivia strings using
///   `雅威` → `雅偉` (Esther / Ruth / Joshua / Song of Songs /
///   Joel / Obadiah / Zephaniah).
/// • `build_verse_content_spans.dart` comment 雅威 → 雅偉.
/// • `assets/bible_evidence.json`: 10 occurrences (5 zh-Hans +
///   5 zh-Hant across `solomon_temple_evidence` and
///   `zerubbabel_second_temple`). zh-Hans → 雅伟, zh-Hant → 雅偉.
/// • `assets/strongs/hebrew.json`: 4 occurrences (defZh×2 +
///   defZhTw×2 in H113 + H136 — the Adonai entries that gloss
///   the term as "等同神的名字 雅威" / "猶太人對雅威的代稱"). Same
///   per-locale routing.
///
/// Final state: 0 user-visible `雅威` anywhere in code or assets.
/// Remaining `雅威` references are all intentional (history doc
/// strings + the strongs_service alias map for backward-compat
/// search). Project canonical pairing 雅伟 / 雅偉 now consistent
/// across all surfaces.
///
/// 2026-05-10 (v1.2.32 — 新譯本 traditional divine-name fix):
/// user reported "雅伟 雅偉 版本，但是新譯本和合本好像都沒有用對字"
/// — the simplified→traditional pairing convention everywhere
/// else in the project is 雅伟 (great, simplified) → 雅偉 (great,
/// traditional), but `assets/cnv-tr.json` (新譯本 traditional)
/// used 雅威 (might/awe) instead of 雅偉. Audit confirmed:
///   • cnv.json (simplified) → 7123× 雅伟  (correct)
///   • cnv-tr.json (traditional) → 7122× 雅威  ❌ should be 雅偉
///   • cuvs-yhwh.json / -tr.json → 雅伟 / 雅偉  (correct)
///   • cuv.json / -tr.json → 耶和华 / 耶和華  (correct, classical
///     CUV transliteration)
/// Mass-replaced all 7122 occurrences in `assets/cnv-tr.json`
/// from 雅威 → 雅偉. Verified: 0 雅威 remaining, 7122 雅偉, total
/// verse count unchanged at 31102. All other 雅X bigrams (雅各
/// = Jacob, 雅憫 = Benjamin, 雅敬 = Joiakim, 雅比 = Jabesh, 雅斤
/// = Jachin, 雅哈 = Jahath …) match between simp and trad — only
/// the divine name was inconsistent.
///
/// Known follow-up (NOT FIXED): Lamentations 5:21 and 5:22 are
/// duplicates in cnv.json (both contain a hybrid that merges
/// 5:21+5:22 content), and cnv-tr.json's 5:22 has a
/// non-canonical paraphrase ("但是您完全拒絕了我們。 你對我們很生
/// 氣。"). Needs a verified CNV (新譯本) source to correct;
/// flagged for a future data-quality pass.
///
/// 2026-05-10 (v1.2.31 — perf + a11y + web hardening + doc sync):
/// three more audit agents (performance + a11y, documentation drift,
/// web/PWA + edge cases) found 11 actionable items after v1.2.30.
///
/// PERFORMANCE (Dart):
/// • `search_page.dart` — the AI-refs ListView's `itemBuilder` was
///   rebuilding a 30k-entry verseIndex Map fresh inside every `build()`
///   call (theme toggle, font slider drag — every notifyListeners).
///   New `_getVerseIndex(mp)` helper caches by `(currentVersion,
///   verses identity)` so the Map is only built once per version
///   switch.
/// • Hoisted RegExps that were constructed per call:
///     - `search_page.dart` `r' {2,}'` (two sites: Copy-all loop +
///       inline-row preview text — fired per visible row during
///       scroll).
///     - `originals_sheet.dart::_parseAiMarkdown` — 4 RegExps were
///       constructed per call (3 per line + 1 inline pattern). Top-
///       level `final` reuses one instance.
///     - `originals_sheet.dart::_lookupVerseText` `r' {2,}'` (per
///       concordance row).
/// • `bible_reading_pane.dart::_MapTile` + `map_viewer_page.dart`
///   strip thumbnails — `Image.asset` had no cacheWidth/cacheHeight,
///   so a 44 dp / 110 dp tile was decoding the source 1500+ px map
///   bitmap. Capped at 88 / 220 px (2× DPR).
/// • Switched 8 dashboard cards + 1 reading-pane status bar from
///   `context.watch<AppSettings>()` (rebuild on every notify) to
///   `context.select` for the precise (fontSize, fontFamily) pair
///   they actually read. Locale changes / theme toggles / version
///   switches no longer rebuild every dashboard card.
///
/// ACCESSIBILITY (Dart):
/// • `originals_sheet.dart` distribution-table + copy-word-study
///   IconButtons had `padding: EdgeInsets.zero` + `constraints:
///   BoxConstraints()` ⇒ ~18 dp tap target (well below WCAG 48 dp).
///   Bumped to 48×48 minimum.
/// • `bible_reading_pane.dart` section-context info IconButton was
///   constrained to 32×32; same 48×48 fix.
///
/// WEB / PWA:
/// • `web/index.html` `theme_color` meta vs `web/manifest.json`
///   theme_color disagreed (#FFFFFF vs #2196F3 Material blue) —
///   Android PWA address bar tinted blue, iOS Safari tinted white.
///   Aligned both to the white surface the LIGHT theme actually
///   paints. Plus a second meta tag with
///   `media="(prefers-color-scheme: dark)" content="#1F1F1F"` so
///   dark-mode users get a matching status bar instead of stuck
///   white. Per-tier manifest overlays in
///   `tools/site-icons/{intl,cn}-{prod,dev,qat}/manifest.json`
///   updated to match.
/// • Removed dead `__BUILD_STAMP__` self-heal block from
///   `web/index.html`. The intended Netlify post-processing step
///   that rewrites the token never existed (`grep` confirms — only
///   the four self-references in `index.html` itself), so the
///   `stampChanged` branch was always false. Kept the SW-unregister
///   + cache-bucket-nuke + auto-reload-once path which IS
///   functional. Manual `window.yswordsClearCacheAndReload` (used
///   by Settings + LoadingPage's "Reload page" button) untouched.
///
/// QUALITY (Dart):
/// • `app_settings.dart::loadSettings` — `SharedPreferences.
///   getInstance()` could throw on Safari private browsing /
///   localStorage quota / iOS storage error, propagating into
///   `main.dart`'s bootstrap catch and routing the user to the
///   "Failed to load" verse-error scaffold even though the verse
///   load was fine. Now wrapped in try/catch — defaults are
///   compile-time sane (zh-Hans / system theme / fontSize 20),
///   `notifyListeners()` fires so the tree wires up immediately,
///   and the user keeps a usable app even if persistence is dead.
///
/// DOCUMENTATION:
/// • HANDOFF.md — corrected 14→13 Bible-translations count, splash
///   diagram updated for the eager-preload behaviour, line counts
///   bumped (HomePage 285→352, BibleReadingPane 1680→5000), Known
///   Issues — large-asset/HomePage-size sections refreshed, dropped
///   the stale Microsoft YaHei "21.8 MB" claim (font was unbundled
///   in 2026-05).
/// • README.md — fixed NASB source ("api.bible (requires API key)"
///   was wrong; it's bundled at `assets/nasb.json`); appended
///   actual-Flutter-version note (3.41.7) to the SDK floor; updated
///   the "Captured 2026-05-07 against v1.0.0" caption to point at
///   the post-v1.0 release log.
/// • SCREENSHOTS.md — bumped status banner from "v1.2.5" to
///   "v1.2.31".
/// • `lib/services/ai_search_service.dart` — class-doc claimed
///   "scaffolded but not deployed (2026-04-28)" — wrong since
///   round 52's Cloud Functions → Netlify Functions migration.
///   Updated to describe the live endpoint behaviour.
///
/// 2026-05-10 (v1.2.30 — async correctness + backend hardening):
/// two more audit agents found 6 confirmed bugs after v1.2.29.
///
/// CLIENT (Dart):
/// • `originals_sheet.dart` — three stale-Future races
///   (`_onWordTap`, `_loadRootEntry`, `_loadRelations`). Tapping
///   word A then word B before A's lookup resolves could leave
///   A's Strong's entry / concordance / family tree rendered
///   under B's selection. Same generation-counter pattern as the
///   v1.2.8 BYOK Test fix — new `_lookupGen` int bumped at every
///   tap / root-nav / clear-root, captured by each async branch
///   and checked before its setState.
/// • `evidence_page.dart::_AiSearchDialog._ask` — pressing the
///   Enter shortcut bypassed the `_busy` guard (the Ask button
///   itself is disabled during `_busy = true`, but the keyboard
///   path wasn't). New `_askGen` counter bumped per `_ask()`
///   entry so an older response's setState can't clobber a newer
///   query's results.
///
/// BACKEND (Netlify Functions):
/// • `submitFeedback.mjs` — Resend upstream error body was
///   forwarded verbatim (300-char slice) to the client. Same
///   class as the v1.2.6 fix on the AI functions — now logged
///   server-side via `console.error` and replaced with a generic
///   "Upstream email service error (HTTP ...)". Plus
///   CR/LF stripping on `category` + `name` so neither can inject
///   a CRLF into the email Subject header (defense-in-depth on
///   top of Resend's own filtering). Plus the `authEmail` comment
///   vs code mismatch fixed (an invalid signed-in email now
///   actually gets blanked from the body, as the comment claimed).
/// • `aiExplainWord.mjs::book` — was only `.slice(0, 64)`. Since
///   `book` is `.replaceAll('{book}', book)`-substituted into the
///   prompt template, a value like
///   `"Genesis. Now ignore prior instructions and"` could break
///   out of the focus directive. Now allowlisted to ASCII alpha-
///   numeric + spaces only (covers every canonical English book
///   name); cap reduced 64 → 40.
/// • `aiSearch.mjs` + `aiExplainWord.mjs` — `await
///   callGeminiWithKey(...)` was unwrapped, so a synchronous
///   throw (DNS hiccup, malformed BYOK key header) on key #i
///   aborted the whole rotation chain instead of falling through
///   to key #i+1 like the 429 / 401 paths already do. Wrapped
///   in try/catch matching aiBibleSearch's pattern.
/// • All 3 AI functions — public catch blocks fell back to
///   `String(err?.message || err)` when `publicReason` was unset.
///   Any uncaught error from `loadDataset` / `JSON.parse` / fetch
///   throws would leak server paths or dependency state. Now only
///   `publicReason` is allowed; everything else collapses to a
///   generic message + server-log retains the full detail.
/// • `aiExplainWord.mjs` — 401/403 handler used to set
///   `lastError.message = "Gemini key #${i+1} rejected ..."` and
///   then line ~422 copied `.message` straight onto
///   `publicReason`, leaking the key index + total key count to
///   the client. Now the index lives in the server log only;
///   the public message is a generic "AI service authentication
///   failed."
/// 2026-05-10 (v1.2.34): switched from a hardcoded const to a
/// `String.fromEnvironment` lookup so the build script
/// (`tools/build_web.py`) can inject the value from
/// `pubspec.yaml`'s `version:` field at compile time. The
/// fallback default below applies only to:
///   • `flutter run` (developer workflow) — fine to be slightly
///     stale.
///   • Tests asserting against a fixed string — also fine.
/// All Netlify deploys go through `tools/build_web.py` which sets
/// `--dart-define=APP_VERSION=…` from pubspec, so the About page
/// always reflects the canonical source-of-truth.
/// Bump `pubspec.yaml`'s `version:` for the next release; no
/// matching edit needed here.
// 2026-05-22 (v1.2.76): bumped the fallback so iOS / macOS / Android
// native builds — which `flutter build` does NOT auto-inject the
// dart-define for — show the right number on the About page. Only
// the web pipeline (tools/build_web.py + tools/deploy_site.py) injects
// `--dart-define=APP_VERSION=…`. Native builds via the manual reinstall
// script or `flutter build ios|macos|apk` directly inherit this
// fallback. Keep it in lock-step with `pubspec.yaml`'s `version:` on
// every release.
// 2026-06-16 (v1.3.85): Android theme-colour icon swap no longer
// "quits" the app. The launcher-icon swap disables the component the
// running task is rooted on; doing that in the foreground FINISHES the
// task (DONT_KILL_APP only spares the process), so the app closed every
// time the user changed the theme colour. MainActivity now defers the
// swap to onStop() — the home-screen icon updates once the app is
// backgrounded and the activity is never torn down. iOS/macOS/web
// unaffected. See MainActivity.kt + AndroidManifest.xml.
// 2026-06-16 (v1.3.86): NO app-code change from 1.3.85 — this is the
// first release built for ALL platforms (Windows / macOS / Linux /
// Android / iOS) via GitHub Actions. The version is bumped purely so the
// release tag points at the exact commit the binaries were built from
// (1.3.85's tag predated the CI workflows + build fixes, so its tag and
// any backfilled binaries wouldn't match). Marks the cross-platform CI
// release infrastructure going live.
// 2026-06-16 (v1.3.87): theme-colour picker simplified to exactly 7 swatches
// (blue/red/orange/green/purple/pink/dark-grey) that map 1:1 to the 7 themed
// app icons via AppIconService.variantForColor. Previously 18 Material colours
// collapsed onto the same 7 icon buckets, so colours like cyan/light-blue
// silently mapped to the default icon — "why didn't my icon change?". Now
// every pick predictably changes both the theme and the icon.
// 2026-06-16 (v1.3.88): free in-app "Check for updates" (Settings → About).
// Native builds are distributed via GitHub Releases (no app store), so the
// new `UpdateService` queries the GitHub Releases API, compares the latest
// tag to this `kAppVersion`, and — if newer — offers a one-tap download of
// the right asset per platform (Android .apk / desktop .zip/.tar.gz) via
// `LinkOpener`. Web hides the tile (the PWA is always current). Not a silent
// auto-installer (that needs an app store) — it's a check + guided download.
// 2026-06-16 (v1.3.89): scheduled-notification reminders now follow the
// app/system language. Their titles were hardcoded Simplified Chinese
// (今日经文 / 圣经考证 / 今日讲道) and the resolvers read the wrong JSON keys
// (daily_verses `verses` is a list of reference strings; evidence lives
// under `evidences`), so non-zh users got Chinese labels with empty
// bodies. notification_scheduler now threads `settings.locale` through,
// localizes every category label (en / zh-Hans / zh-Hant), localizes the
// verse reference via `localizePassage`, and reads the correct keys. Also
// `setLocale` now re-schedules so a language switch re-localizes pending
// reminders immediately (not just on next launch).
// 2026-06-18 (v1.3.90): bundle of fixes.
//  • iOS alternate-app-icon @3x: SpringBoard renders ALTERNATE icons from the
//    loose CFBundleIconFiles PNGs (not Assets.car), and actool only emitted
//    them at @2x — so @3x iPhones had no image and the swap silently no-op'd
//    (setAlternateIconName returns success + tracks the name, but the home
//    icon stays primary). Build phase `ios/inject_alt_icon_loose_3x.sh` now
//    injects ALPHA-FLATTENED 180×180 @3x loose files (iOS rejects icons with
//    an alpha channel) from `ios/alt_icons_3x/` and re-seals the signature.
//    On-device diagnosis confirmed the API path is healthy; if a given iOS 27
//    iPhone still won't repaint after this, it's a SpringBoard cache issue
//    (respring/reboot), not the app.
//  • Search: 2-digit verse numbers no longer character-break ("10"→"1"/"0")
//    in narrow panes; Strong's-entry Occurrences now show verse text and jump
//    to the verse on tap.
//  • Localization: the book-intro "key passage" and inserted note references
//    now use the reading-locale book name (round-trip-safe — see
//    note_reference_localized_roundtrip_test.dart).
// 2026-06-18 (v1.3.91): boolean Strong's search. Combine original-language
// numbers with set operators — "G25 AND G26" (verses with BOTH), "G25 OR
// G26" (EITHER), adjacent-implies-AND, and the "G25*" prefix wildcard — via
// tappable AND / OR / ✶ buttons that appear once the query contains a
// number (no syntax to memorise). Results are clickable with verse previews
// and jump to the verse. The "how to search" help panel documents it. Also:
// root references inside a Strong's entry's etymology (e.g. "from G1537")
// are now tappable → open that root's own lexicon page.
// 2026-06-18 (v1.3.92): two fixes on the v1.3.91 search work.
//  • Tapping a related / word-family ("同根词") or etymology-root word in a
//    Strong's entry did nothing: a StrongsEntryPage → StrongsEntryPage push
//    shares the same GetX route name, so GetX silently blocked it. Added
//    preventDuplicates: false to those navigations so you can drill root→root.
//  • The AND / OR / ✶ operators weren't obviously explained: the ? beside the
//    operator bar now opens a focused dialog explaining each with examples
//    (instead of burying it in the general search-help list).
// 2026-06-18 (v1.3.93): REVERT the v1.3.90 deferred-to-background iOS icon
// swap — it regressed working devices. Deferring setAlternateIconName to the
// app-background transition meant the platform-channel call often didn't
// complete before iOS suspended the app, so the swap never ran: the iPad
// (which used to recolor every time) stopped changing entirely. Back to
// applying the swap immediately in the foreground, which is the behaviour
// that worked on the iPad (every change) and the iPhone (first change). The
// iPhone's "subsequent changes don't repaint" remains an iOS 26/27
// SpringBoard bug with no app-side fix.
// 2026-06-18 (v1.3.94): copy from every search result. Long-press any result
// row (keyword / AI / Strong's-concordance / boolean) to copy
// "Book ch:verse  text", and every results list now has a "copy all" button
// (text search already did; added to the Strong's-concordance + boolean
// headers). StrongsEntryPage occurrences are long-press-copyable too. Uniform
// copy behaviour + toast across all the search modes.
// 2026-06-18 (v1.3.95): (1) unified search-result layout — every search mode
// (keyword / AI / Strong's / boolean) now shows the reference on top with the
// verse text below, so the "different search engines" look consistent.
// (2) Flutter SDK upgraded 3.41.7 → 3.44.2 (Dart 3.12); fixed the three
// resulting deprecations (cacheExtent dropped, onReorder → onReorderItem,
// SizeTransition.axisAlignment → alignment). Analyze clean, 365 tests pass.
// 2026-06-29: `String.fromEnvironment`'s defaultValue applies ONLY when the
// key is ABSENT — a build that ships `--dart-define=APP_VERSION=` (present but
// EMPTY, e.g. a launchd/script run where the shell var came back blank)
// overrides it with '' and blanks the version on-device (seen on the Mi Pad,
// which sat on such a build while it couldn't update). Guard the empty case so
// kAppVersion can never render blank again. Same hazard the script already
// fixed for APP_RELEASE_TIME by moving it to a source constant.
const String _envAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.3.113',
);
const String kAppVersion = _envAppVersion == '' ? '1.3.113' : _envAppVersion;

/// 2026-05-10 (v1.2.20): paired with `kAppVersion` so the About
/// footer's "Last updated …" stamp moves in lockstep with every
/// release. Bump BOTH this and `kAppVersion` together; nothing
/// else has to change.
///
/// 2026-05-10 (v1.2.24): bumped from date-only ("2026-05-10")
/// to wall-clock-minute precision ("2026-05-10 15:20 AEST").
/// User pointed out v1.2.20 → v1.2.23 all shipped on the same
/// day so a date-only stamp couldn't tell them apart — now the
/// stamp distinguishes back-to-back releases. Constant name
/// renamed from `kAppReleaseDate` → `kAppReleaseTime` and the
/// ui-string placeholder from `{date}` → `{time}` to reflect
/// the higher precision. Format: ISO local date + 24-h
/// HH:MM + tz abbreviation. The about-page interpolation is
/// locale-aware via the `aboutFooterNote` ui-string template.
/// 2026-05-10 (v1.2.34): same dart-define injection pattern as
/// `kAppVersion` above. `tools/build_web.py` stamps the actual
/// build moment via `--dart-define=APP_RELEASE_TIME=…`.
///
/// 2026-05-10 (v1.2.35): switched the canonical stamp to ISO 8601
/// UTC (`2026-05-10T09:48:00Z`). Display path goes through
/// `formatReleaseTimeLocal()` which converts to the viewer's
/// local timezone — a user in NYC sees `2026-05-10 04:48 EST`,
/// a user in Beijing sees `2026-05-10 17:48 CST`, etc.
///
/// Fallback chain when the stamp can't be parsed:
///   1. The literal string in this const (a Melbourne wall-clock
///      stamp from the build machine, e.g. `2026-05-10 19:48 AEST`)
///      — used during `flutter run` dev workflow when nothing was
///      injected.
///   2. If the const ALSO looks like a dev-build placeholder, the
///      raw value is shown as-is.
///
/// The fallback only fires when `tools/build_web.py` wasn't used
/// for the build, which in practice means dev workflow only.
const String kAppReleaseTime = String.fromEnvironment(
  'APP_RELEASE_TIME',
  defaultValue: '2026-07-23T02:22:15Z',
);

/// Returns a user-locale-formatted release time string. Parses
/// `kAppReleaseTime` as ISO 8601 UTC if possible, then formats
/// in the viewer's local timezone. Falls back to the raw string
/// (which is Melbourne wall-clock for dev builds).
///
/// Example outputs:
///   • viewer in Melbourne: `2026-05-10 19:48 AEST`
///   • viewer in NYC:       `2026-05-10 04:48 EST`
///   • viewer in Beijing:   `2026-05-10 17:48 CST`
///   • dev build (no UTC):  `2026-05-10 dev-build (Melbourne)`
///
/// Format: `YYYY-MM-DD HH:MM TZ` to match the legacy display.
String formatReleaseTimeLocal() =>
    formatReleaseStamp(kAppReleaseTime, (utc) => utc.toLocal());

/// Formats a UTC offset [Duration] as a stable, platform-independent
/// label: `UTC+10`, `UTC+8`, `UTC-5`, `UTC+5:30`, `UTC+0`.
///
/// 2026-06-09 (v1.3.59): used by [formatReleaseStamp] INSTEAD of
/// `DateTime.timeZoneName`, which returns a different string per
/// platform for the same instant — `AEST` on iOS, `GMT+10:00` on
/// Android, a long IANA/Intl name (or empty) on web. That divergence
/// was the "format looks different across iOS / web / Android" the user
/// reported. This is pure arithmetic, so every platform agrees.
/// Public for testing.
String formatUtcOffsetLabel(Duration off) {
  final sign = off.isNegative ? '-' : '+';
  final oh = off.inHours.abs();
  final om = off.inMinutes.abs() % 60;
  return om == 0
      ? 'UTC$sign$oh'
      : 'UTC$sign$oh:${om.toString().padLeft(2, '0')}';
}

/// Pure core of [formatReleaseTimeLocal]: given a raw stamp and a
/// `toLocal` converter, produces the display string. Split out so the
/// never-blank guard and the platform-independent formatting can be
/// unit tested without depending on the host machine's timezone.
/// Public for testing.
String formatReleaseStamp(
  String rawInput,
  DateTime Function(DateTime utc) toLocal,
) {
  final raw = rawInput.trim();
  // 2026-06-09 (v1.3.59): never render blank. A build that injected an
  // empty `--dart-define=APP_RELEASE_TIME=` (e.g. an ad-hoc CLI build
  // where the shell var wasn't set) leaves `raw` empty and the About
  // footer would show "本页最后更新于 。" with no time — exactly the blank
  // the user saw on the Mi Pad. Guard it. (Real builds now read the
  // bump-stamped `kAppReleaseTime` constant, so this only fires on a
  // misconfigured manual build.)
  if (raw.isEmpty) return '—';

  // ISO 8601 UTC stamps look like `2026-05-10T09:48:00Z` (Z = UTC).
  // Anything else falls through to the raw display.
  if (raw.length >= 20 &&
      raw.contains('T') &&
      (raw.endsWith('Z') || raw.contains('+') || raw.contains('-'))) {
    try {
      final local = toLocal(DateTime.parse(raw));
      final y = local.year.toString().padLeft(4, '0');
      final m = local.month.toString().padLeft(2, '0');
      final d = local.day.toString().padLeft(2, '0');
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $hh:$mm ${formatUtcOffsetLabel(local.timeZoneOffset)}';
    } catch (_) {
      // Fall through to raw display below.
    }
  }
  return raw;
}
