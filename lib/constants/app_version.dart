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
const String kAppVersion = '1.2.5';
