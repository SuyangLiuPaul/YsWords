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
const String kAppVersion = '1.1.7';
