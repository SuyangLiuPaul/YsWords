# Screenshot capture guide

The README references screenshots in `assets/screenshots/`. Several
new ones are needed since the most recent UI overhaul (search
mode chips, dashboard quick-links grid, feedback form). This file
is the capture brief for whoever takes them — the URL flow,
suggested viewport size, and the filename to save.

> **Status (2026-05-24, v1.3.26):** **10 rows still relevant** —
> all captured against the live build and committed into
> `assets/screenshots/`. The README's *App Screenshots* table uses
> these in 5 rows × 2 columns; older shots (note popup / multi-
> select / version switch / book picker / splash / older settings)
> are kept inside a `<details>` collapser further down. Row 11
> (`screenshot_welcome_disclaimer.png`) is **OBSOLETE** as of
> v1.2.5 — the disclaimer card was removed from the welcome page;
> the file is no longer referenced by README.md.
>
> **Drift since the shots were captured (informational — UI is
> still recognisable but not pixel-identical):**
> * v1.2.70 — auto-hide chrome (header + bottom bar slide off when
>   scrolling down). Screenshots show the chrome always-visible.
> * v1.2.96 → v1.3.3 — PageView chapter pager; the reader's swipe
>   model and chapter-boundary behaviour changed (visually similar
>   but interaction differs).
> * v1.2.96 → v1.2.98 — themed app icons (favicon / launcher /
>   Dock icon now follow `primaryColor`). Screenshots use the
>   v1.0 fixed-blue icon.
> * v1.3.10 → v1.3.19 — 朗读/TTS feature was added and then fully
>   removed. The "Listen to chapter" menu item never made it into
>   screenshots (added v1.2.86, removed v1.3.19) — nothing to
>   re-shoot.
> * v1.3.14 — split-pane chrome cleanup (3-dot menu hidden in
>   secondary pane). The Split-View screenshots, if any, would
>   need a fresh shot.
> * v1.3.20 — reading column on tablet/desktop now caps at
>   760-1040 px (was edge-to-edge). The "Feedback form on desktop"
>   shot still captures this aspect ratio correctly but the
>   Bible reader on desktop monitors is visually different now.
> * v1.3.25 — new "Install YsWords" card in Settings → About
>   surfaces a platform-aware install affordance (Chrome native
>   prompt / iOS Share-sheet guide / desktop browser instructions).
>   Not in any current screenshot.
> * v1.3.26 — new "Export my data" card in Settings → About with
>   Markdown / JSON segmented toggle + scrollable selectable
>   preview. Not in any current screenshot.

## How to capture

1. Open <https://yswords.netlify.app> in Chrome.
2. Open DevTools → toggle the device-toolbar (`Cmd+Shift+M` /
   `Ctrl+Shift+M`).
3. Choose **Responsive** and set the dimensions for each shot
   below.
4. Right-click the page → **Capture screenshot** (or
   `Cmd+Shift+P` → *"Capture full size screenshot"* for tall
   pages).
5. Save into `assets/screenshots/` with the filename listed.
6. Commit & push.

The README's *App Screenshots* table already references the
filenames below; new entries appear automatically once the files
exist.

## Capture list

> *Tip: most shots are at **414 × 819** (iPhone-ish portrait) so the
> visual matches what most users see. Add a wide shot only when the
> feature has a distinctly different desktop layout.*

| # | Filename | Viewport | What to capture | Status |
|---|----------|----------|-----------------|--------|
| 1 | `screenshot_dashboard_home.png` | 414 × 819 | Dashboard top: greeting card + Read-Bible card + Verse of the Day. Sign in as `Guest` (so the email isn't shown). | ✅ captured |
| 2 | `screenshot_dashboard_quicklinks.png` | 414 × 1100 *(scroll)* | Bottom of dashboard showing the quick-links grid: Search, Library, Bible Tools, Daily News, Bible Evidence, Sermons, Family Tree, Bible Timeline, Bible Trivia, Songs, **Feedback**, Settings. | ✅ captured |
| 3 | `screenshot_search_modes.png` | 414 × 819 | SearchPage with the **Search** + **YsWords AI** chip strip visible below the AppBar. Empty state (no query typed). | ✅ captured |
| 4 | `screenshot_search_results.png` *(replace existing)* | 414 × 819 | Type "love" → wait for live results. Show the count header + result-list + the Copy-all icon at top right. *(Captured against "God" — same UI surface, the count of 4226 reads dramatically.)* | ✅ captured |
| 5 | `screenshot_search_ai.png` | 414 × 819 | Type a thematic query like "the love chapter" → tap **YsWords AI** chip → AI-suggested verses appear. The AI chip should be highlighted (active state). *(Captured against "The Verse about Gods name", AI returned 8 passages.)* | ✅ captured |
| 6 | `screenshot_search_help_dialog.png` | 414 × 819 | Tap the **?** icon in the SearchPage AppBar → shows the localized "How to search" dialog with Basic + Advanced sections. | ✅ captured |
| 7 | `screenshot_feedback_form.png` | 414 × 819 | Dashboard → Feedback tile → form open with category chips, message field, name field, **Reply-to email (optional)** field. *(Post-v16 — the "send a copy to me" checkbox is no longer there.)* | ✅ captured |
| 8 | `screenshot_feedback_form_wide.png` | 1280 × 800 | Same form on a desktop monitor — the `ConstrainedBox(maxWidth: 600)` should center it nicely with margin on both sides. *(Captured in dark mode — looks good either way; the centering + margins are the point.)* | ✅ captured |
| 9 | `screenshot_word_study.png` | 414 × 819 | Inside reader → tap a verse → **Original** sheet opens → word-by-word interlinear with Strong's chips + tappable lemmas. *(Captured at desktop width; the same UI shows on mobile.)* | ✅ captured |
| 10 | `screenshot_ai_explanation.png` | 414 × 819 | Originals sheet → tap **AI explain** chip → AI response renders below with the *"AI is only an aid"* caveat visible at bottom. *(Captured at desktop width.)* | ✅ captured |
| 11 | `screenshot_welcome_disclaimer.png` | 414 × 819 | ~~First-launch welcome page: tagline + the *"The Spirit guides; AI only assists"* disclaimer card + Sign-in / Continue-as-guest buttons.~~ **OBSOLETE — disclaimer card removed in v1.2.5; file is kept on disk for history but no longer referenced.** | 🚫 obsolete |
| 12 | `screenshot_dark_mode.png` | 414 × 819 | Reader in dark mode (Settings → Theme → Dark) showing a chapter rendered with the dark palette. *(Captured against the Settings page itself with the **Theme Mode = Dark Mode** dropdown visible — more illustrative than a dark-themed reader page since it shows the control + the result at once.)* | ✅ captured |

## Existing screenshots (already in `assets/screenshots/`)

These should keep working as-is, but it's worth re-shooting them
in the new dashboard / search / theme:

- `screenshot_loading_page.png` — splash screen
- `screenshot_multi_select.png` — multi-verse selection toolbar
- `screenshot_note_popup.png` — `<note:...>` annotation popup
- `screenshot_search_filter_zh.png` — Chinese filter dropdown
- `screenshot_search_filter_zh_alt.png` — alternative variant
- `screenshot_settings_page.png` — Settings page
- `screenshot_book_chapter_picker.png` — book + chapter picker
- `screenshot_version_switch.png` — Bible version switcher

## Where they appear in the README

The *App Screenshots* table in `README.md` currently has 4 rows:

```
Main Reading View | Note Popup
Search Results    | Search Filter
Version Switch    | Settings Page
Book Picker       | Splash Screen
```

After capturing the new shots, replace the table with three rows
that highlight the **most user-facing features** in this order:

```
Dashboard (home)      | Verse of the Day in context
Search modes (chips)  | Live search results + Copy-all
Word study sheet      | AI explanation card
Feedback form         | Welcome disclaimer
```

The exact `<table>` markup is in `README.md` under
`## App Screenshots`. Copy the existing pattern; just swap the
`src=`/`alt=` strings to the new filenames.
