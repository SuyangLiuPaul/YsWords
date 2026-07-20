<h1 align="center">YsWords – Yahweh's Words</h1>

<p align="center">
  <img src="assets/app_icon_rounded.png" alt="YsWords App Icon" width="80"/>
</p>

<p align="center"><em>A bilingual Bible reader for Yahweh's words built with Flutter.</em></p>

<p align="center">
  <a href="https://yswords.netlify.app">
    <img alt="Live demo" src="https://img.shields.io/badge/Live%20demo-yswords.netlify.app-0284c7?style=for-the-badge&logo=netlify&logoColor=white">
  </a>
  <a href="https://github.com/SuyangLiuPaul/YsWords/releases/latest">
    <img alt="Release" src="https://img.shields.io/github/v/release/SuyangLiuPaul/YsWords?style=for-the-badge&label=Release&color=22c55e">
  </a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.41.7-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/License-See%20LICENSE-555?style=for-the-badge">
</p>

---

## Try it now

🌐 **<https://yswords.netlify.app>** — opens in any modern browser. No install, no sign-in needed. Optional Google sign-in syncs highlights / bookmarks / notes / last-read position across devices.

📱 On mobile, tap your browser's menu → **Add to Home Screen** to install as a PWA — full offline reading after one tap of the *Offline Pack* in Settings.

---

## Quick start

### For users — nothing to install
Open <https://yswords.netlify.app> and start reading. Tap any verse to copy / highlight / bookmark / get an interlinear word study. The dashboard's quick-links grid puts Search, Library, Bible Tools, Bible Evidence, Sermons, Family Tree, Bible Timeline, Bible Trivia, **Feedback**, and Settings one tap away.

### For developers — clone, run, ship
```bash
git clone https://github.com/SuyangLiuPaul/YsWords
cd YsWords
flutter pub get
flutter run -d chrome
```

To deploy to your own Netlify project:
```bash
flutter build web --release
netlify deploy --prod --dir=build/web --site=YOUR_SITE_ID
```

For cloud features (sync + AI + feedback email) to work in
production, see [**SETUP.md**](SETUP.md). The fastest path:

1. Open the deployed app → Settings → About → bottom →
   **"Run check"** diagnostic. It probes Firebase Auth, Realtime
   Database, and the AI proxy.
2. Any failing rows give one-click "Open Cloud Console" / "Open
   Firebase Console" / "Open Netlify env vars" deep-links straight
   to the page that fixes them.
3. The collapsible "One-time cloud setup walkthrough" right below
   the diagnostic explains each step with ⓘ details on why it
   matters and what breaks without it.
4. Optional: `bash scripts/enable-cloud-apis.sh` (or paste it into
   <https://shell.cloud.google.com>) auto-enables the Gemini API
   in one command.

The diagnostic + walkthrough live inside the app permanently —
once set up, you can ignore them. **End users never need to enable
any APIs themselves**; everything is at the Firebase project level.

---

## Features

| Category     | Details                                                                                                                 |
| ------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Versions     | KJV, LEB, NASB, 和合本雅伟版 (简 / 繁), 和合本 (简 / 繁), 新译本 (简 / 繁), 原文释经圣经 (简 / 繁)                              |
| Reading      | Apple-glass reader controls; Light / Dark / System theme; Adjustable font family, size, line spacing, menu scale; Verse-by-verse or Paragraph Flow reading mode (default); Full-width reading on all devices; Grid view default for new users; Reading mode toggle in header on tablet+ |
| Highlights   | Mark verses with 6 colors (yellow, green, blue, pink, orange, purple); persistent across sessions                      |
| Bookmarks    | Bookmark + per-verse notes; visible inline indicator next to every flagged verse in both verse-by-verse and paragraph mode |
| Navigation   | Swipe left/right to change chapter; Floating chapter picker; Previous/next chapter buttons; Grid/List view for books with compact English/Chinese labels; Responsive grid for tablets/desktops; Collapsible sidebar for wide screens (≥600px) |
| Split View   | Two fully independent Bible panes; Side-by-side on tablet/desktop (≥600px) with draggable divider; Top-bottom on phone with draggable divider; Each pane has its own book, chapter, and version; Toggle in header |
| Search       | **Live search-as-you-type** with 250 ms debounce · Two explicit modes via chip strip: **Search** (text scan, also Enter default) and **YsWords AI** (Gemini-backed fuzzy/thematic, reference-only) · Direct-reference jump (`John 3:16`, `约 3:16`, `Rom 12:1-2`) · Strong's-# pattern (`G2316` / `H7200`) opens the lexicon page · Top-aligned **recent searches** with per-item delete · Bulk **Copy all results** to clipboard · Built-in **"?" help dialog** in your locale · Filter dropdown for whole-Bible vs current-book scope · Every keystroke resets to default scope (entire Bible) · **Tap a hit → smooth 350 ms scroll lands the verse 25 % from the top** with a bold `primaryContainer` wash + inline `►` arrow before the verse number in paragraph mode (auto-clears after 3.5 s) |
| Word Study   | Tap any verse → "Original" → word-by-word interlinear with Strong's, transliteration, gloss · Tap a chip → full lexicon entry, word family, synonyms, LXX cross-testament refs, concordance · **YsWords AI explanation** with adjustable scope: this verse / chapter / book / whole Bible / cross-testament / **deep exegesis (BDAG-level structured analysis)** — all reference-only · **Aramaic words highlighted** in Daniel 2:4-7:28, Ezra 4:8-6:18 + 7:12-26, Genesis 31:47, Jeremiah 10:11, plus NT transliterations (raca, talitha koum, abba, eloi, ephphatha, maranatha) · **Proper-noun complementary glosses** (English etymology + Chinese biblical identification side-by-side) |
| Annotations  | `{...}` inline badges with linked `<note:...>` pop-ups; `[...]` dotted-underline keywords; Book icon notes              |
| Section titles | Inline scripture-section headings with optional ⓘ context popovers — covers all 13 versions × 66 books                  |
| Book intros  | Collapsible historical-context card at the top of every chapter 1, bilingual                                            |
| Cross-refs   | Treasury of Scripture Knowledge (TSK) + OpenBible.info community votes — 29,319 source verses with their highest-voted to-references; surfaced via the cross-refs sheet on any selected verse |
| Bible Tools  | Originals overview · Strong's lookup · Word distribution table · Daily verse rotation (curated) · Languages card (Hebrew / Aramaic / Greek deep-dives with tappable passage links) |
| Bible Trivia | 68 curated entries on hidden patterns, acrostics, divine-name codes, numerical structures · Sorted by canonical Bible order · 4 schematic diagram types (Hebrew alphabet grid, chapter-counts bar chart, threefold sequence, numbered Hebrew words) for the most pattern-heavy entries |
| Bible Evidence | Browsable archive of 225 archaeology / manuscript / science / history finds with bilingual descriptions and scripture cross-link · **AI evidence search** (daily-rotating example queries based on today's evidence; Enter key submits — AI-generated, reference-only) · Chapter-aware filter from inside the reader |
| Cloud Sync   | Optional Google sign-in (from Settings → Account) syncs highlights + bookmarks + notes via Firebase Realtime Database (own-write echo guard + content-hash skip — no flicker, minimal traffic); offline-first with merge-then-overwrite reconciliation · **BYOK Gemini key real-time sync** across signed-in devices (paste on Device A → appears on Device B in seconds, no restart; clear on Device A → clears on Device B too) |
| Offline Pack | 5-category pre-fetch (Bibles 70 MB / Sermons 26 MB / Tools 10 MB / Originals 31 MB / Maps 29 MB) — full offline use after one-tap download |
| Reload       | One-tap Reload from the floating-header overflow menu and the empty-reader scaffold so users never have to relaunch the app to recover from a load failure |
| Copy & Share | Tap verses to multi-select; Copy in **Plain**, **With Reference**, or **Devotional** (default — flows as one continuous paragraph with the reference in parens at the end, 灵修 / 抄经 friendly) formats                            |
| Feedback     | In-app feedback form (Dashboard → **Feedback** tile) with category chips · Submitted server-side via Resend → developer's inbox · No tab switch · Auto-attached diagnostics (locale / Bible version / position / screen / theme / timezone / browser / IP) · Signed-in users get an opt-in "Send a copy to me" checkbox; guests can type their email · Falls back gracefully to `mailto:` if the email service is unconfigured |
| Persistence  | Last-read position, highlights & user settings stored with `shared_preferences`; cloud sync layered on top              |
| Platforms    | Android, iOS, Web, macOS, Windows, Linux                                                                                |

---

## App Screenshots

<p align="center"><sub>Captured on an iPhone 17 Pro (iOS 26.5). Current release <b>v1.3.97</b>. Download builds for every platform from <a href="https://github.com/SuyangLiuPaul/YsWords/releases/latest">Releases</a>; full release log in <a href="HANDOFF.md">HANDOFF.md</a>.</sub></p>

<h3 align="center">Read &amp; study the Word</h3>

<p align="center"><img height="300" src="assets/screenshots/screenshot_ipad_split_landscape.png" alt="Split View"/><br/><sub><b>Split View — two fully independent panes, bilingual side-by-side (here NASB &amp; 和合本雅伟版)</b></sub></p>

<table align="center">
  <tr>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_dashboard_home.png" alt="Dashboard"/><br/><sub><b>Dashboard</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_reading_paragraph.png" alt="Paragraph reader"/><br/><sub><b>Paragraph reader</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_reading_immersive.png" alt="Immersive reading"/><br/><sub><b>Immersive reading</b></sub></td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_multi_select.png" alt="Verse actions"/><br/><sub><b>Verse actions</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_word_study.png" alt="Word-by-word exegesis"/><br/><sub><b>Word-by-word exegesis</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_ai_panel.png" alt="AI study panel"/><br/><sub><b>AI study panel</b></sub></td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_ai_explanation.png" alt="AI study chat"/><br/><sub><b>AI study chat</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_version_switch.png" alt="14 translations"/><br/><sub><b>14 translations</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_book_chapter_picker.png" alt="Book &amp; chapter"/><br/><sub><b>Book &amp; chapter</b></sub></td>
  </tr>
</table>

<h3 align="center">On iPad &amp; large screens</h3>

<p align="center"><img height="320" src="assets/screenshots/screenshot_ipad_split_landscape.png" alt="iPad Split View (landscape)"/><br/><sub><b>Landscape Split View — two full columns side by side (NASB ‖ 和合本雅伟版)</b></sub></p>

<table align="center">
  <tr>
    <td align="center" valign="top"><img height="360" src="assets/screenshots/screenshot_ipad_split_view.png" alt="iPad Split View (portrait)"/><br/><sub><b>Portrait Split View</b></sub></td>
    <td align="center" valign="top"><img height="360" src="assets/screenshots/screenshot_ipad_reading.png" alt="iPad reading"/><br/><sub><b>Wide reading column</b></sub></td>
  </tr>
</table>

<h3 align="center">Discover &amp; explore</h3>

<table align="center">
  <tr>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_search.png" alt="Search"/><br/><sub><b>Search</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_dashboard_quicklinks.png" alt="Quick-links"/><br/><sub><b>Quick-links</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_bible_evidence.png" alt="Bible Evidence"/><br/><sub><b>Bible Evidence</b></sub></td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_evidence_detail.png" alt="Evidence detail"/><br/><sub><b>Evidence detail</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_bible_tools.png" alt="Original languages"/><br/><sub><b>Original languages</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_bible_timeline.png" alt="Bible Timeline"/><br/><sub><b>Bible Timeline</b></sub></td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_family_tree.png" alt="Family Tree"/><br/><sub><b>Family Tree</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_bible_trivia.png" alt="Bible Trivia"/><br/><sub><b>Bible Trivia</b></sub></td>
  </tr>
</table>

<h3 align="center">Sermons &amp; personalize</h3>

<table align="center">
  <tr>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_sermons.png" alt="Sermons"/><br/><sub><b>Sermons</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_settings_page.png" alt="Settings"/><br/><sub><b>Settings</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_settings_theme.png" alt="Theme &amp; colour"/><br/><sub><b>Theme &amp; colour</b></sub></td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_dark_mode.png" alt="Dark mode"/><br/><sub><b>Dark mode</b></sub></td>
    <td align="center" valign="top" width="33%"><img height="340" src="assets/screenshots/screenshot_dark_dashboard.png" alt="Dark dashboard"/><br/><sub><b>Dark dashboard</b></sub></td>
  </tr>
</table>

<h3 align="center">Your theme, your icon</h3>

<p align="center"><sub>Pick a primary colour in Settings and the app icon recolours to match — the iOS home screen, Android launcher, macOS Dock, and the browser favicon all follow.</sub></p>

<p align="center">
  <img width="76" src="assets/screenshots/screenshot_icon_blue.png" alt="Blue"/>&nbsp;
  <img width="76" src="assets/screenshots/screenshot_icon_red.png" alt="Red"/>&nbsp;
  <img width="76" src="assets/screenshots/screenshot_icon_orange.png" alt="Orange"/>&nbsp;
  <img width="76" src="assets/screenshots/screenshot_icon_green.png" alt="Green"/>&nbsp;
  <img width="76" src="assets/screenshots/screenshot_icon_purple.png" alt="Purple"/>&nbsp;
  <img width="76" src="assets/screenshots/screenshot_icon_pink.png" alt="Pink"/>&nbsp;
  <img width="76" src="assets/screenshots/screenshot_icon_dark.png" alt="Dark"/>
</p>

---

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/SuyangLiuPaul/YsWords.git
cd YsWords

# 2. Install Flutter dependencies
flutter pub get

# 3. Run (choose one)
flutter run                    # Debug on default device
flutter run -d chrome          # Debug in browser
flutter build apk --release    # Release APK
```

Requires **Flutter >= 3.22** and **Dart >= 3.2** (active dev/prod builds run on Flutter 3.44.2 / Dart 3.12; the SDK constraint in `pubspec.yaml` is `'>=3.2.3 <4.0.0'`). On Flutter 3.44 the iOS/macOS builds stay on CocoaPods — run `flutter config --no-enable-swift-package-manager` once per machine (the SPM-resolved Firebase SDK is incompatible with the pinned `cloud_firestore`).

---

## Live Web Demo

A production build is hosted on Netlify:

```
https://yswords.netlify.app/
```

- Open in any modern browser (Chrome, Edge, Safari, Firefox).
- All Bible data is bundled — no download required on first load.
- On mobile, tap the browser menu -> "Add to Home Screen" to install as a PWA.

---

## Architecture at a glance

```
┌────────────────────────────┐     POST /api/aiSearch
│ Flutter Web app            ├────────────────────────┐
│ (Provider + Get + Material)│     POST /api/aiBibleSearch
│                            │     POST /api/aiExplainWord
│ Bible JSON in assets/      │     POST /api/submitFeedback
│ Strong's lexicon in assets │                        │
│ Local storage:             │                        ▼
│   shared_preferences       │              ┌──────────────────────┐
└─────┬───────────┬──────────┘              │ Netlify Functions    │
      │           │                          │ (serverless mjs)     │
      │ Google    │ Highlights/notes         └────┬───────┬─────────┘
      │ sign-in   │ via WebSocket                 │       │
      ▼           ▼                               │       │
┌──────────┐  ┌────────────────┐                  │       │
│ Firebase │  │ Firebase RTDB  │                  ▼       ▼
│ Auth     │  │ users/{uid}/   │       ┌───────────┐  ┌─────────────┐
└──────────┘  │ sync           │       │ Gemini    │  │ Resend      │
              └────────────────┘       │ (AI text) │  │ (feedback   │
                                       └───────────┘  │  emails)    │
                                                      └─────────────┘
```

The app itself has zero backend — it's a static Flutter web build
served by Netlify. The four `.mjs` Netlify Functions are the only
server-side code, each ≤200 lines. Every function returns 503 +
falls back gracefully when its env vars aren't set, so partial
deploys keep the offline parts of the app working.

---

## Project Structure

```
assets/                       Bible JSONs, Strong's lexicons, fonts, images,
                              maps, sermons, screenshots
docs/                         Setup notes (drive-sync, google-signin, etc.)
lib/
  main.dart                   App entry: Provider scope, GetMaterialApp,
                              theme, bootstrap (FetchVerses + auth init).
  models/                     Verse, Book, AppSettings, Strong's,
                              ReadingPlan, Sermon.
  providers/                  MainProvider (verses, current position,
                              highlights, bookmarks, notes).
  pages/                      DashboardPage, HomePage (reader), SearchPage,
                              SettingsPage, LibraryPage, HighlightsPage,
                              FeedbackPage, SermonsPage, EvidencePage,
                              FamilyTreePage, BibleTimelinePage, etc.
  widgets/                    BibleReadingPane, OriginalsSheet,
                              SetupInstructionsCard, CloudSetupDiagnostic,
                              GreetingCard, GoogleGLogo, etc.
  services/                   Cloud (CloudAuthService,
                              RealtimeDbSyncService), AI proxy clients
                              (AiSearchService, AiBibleSearchService,
                              FeedbackService, ProfileService),
                              StrongsService, FetchVerses, FetchBooks,
                              ConcordanceService, browser-info /
                              link-opener / share-service stubs.
  constants/                  Book lists, UI strings (trilingual),
                              text patterns, Bible versions metadata.
  utils/                      Clipboard helper, search formatter,
                              version mapper, verse span builder,
                              responsive breakpoints, jump-to-reference,
                              short-book-name.
netlify/
  functions/                  Server-side serverless functions:
                                aiSearch.mjs (Bible-evidence AI search)
                                aiBibleSearch.mjs (verse-ref AI search)
                                aiExplainWord.mjs (lexicon AI gloss)
                                submitFeedback.mjs (feedback → Resend)
  netlify.toml                Build config + redirects + cache headers
scripts/
  enable-cloud-apis.sh        One-shot Gemini API enabler for the Cloud
                              project that owns the OAuth client.
pubspec.yaml                  Flutter / Dart dependencies + asset
                              registration.
```

---

## Key Packages

| Package                        | Purpose                                   |
| ------------------------------ | ----------------------------------------- |
| `provider`                     | State management                          |
| `get`                          | Navigation via GetX                       |
| `scrollable_positioned_list`   | Precise verse scrolling and jump-to-index |
| `scroll_to_index`              | Auto-scroll in BooksPage                  |
| `shared_preferences`           | Persist settings & last position          |

---

## Data Sources

| Language | Version                    | Source                                             |
| -------- | -------------------------- | -------------------------------------------------- |
| English  | KJV, LEB                   | Public domain / Logos Bible Software               |
| English  | NASB 2020                  | Bundled at `assets/nasb.json` (text licensed)      |
| Chinese  | 和合本, 新译本               | getbible.net (free public API)                     |
| Chinese  | 原文释经圣经 (BIBLEXG)      | https://www.biblexg.com/                           |
| Chinese  | 雅伟的话 和合本雅伟版        | https://yahwehdehua.net/cn                         |

All JSON files in `/assets/` are used with permission or where public-domain applies.

---

## JSON Verse Schema

Each verse record:

```json
{
  "book": "Genesis",
  "chapter": "1",
  "verse": "1",
  "text": "In the beginning God created the heavens and the earth.",
  "id": "001001001",
  "isParagraphStart": true
}
```

### Inline Tag Grammar

| Pattern | Rendered As |
| ------- | ----------- |
| `{text}` | Tappable colored badge annotation |
| `[text]` | Dotted-underline keyword |
| `<note:text>` | Book icon, tap to show note dialog |

Chapter/verse may be stored as strings or integers depending on source.

---

## Bible Versions

| Key | Name | Language | Filename | Paragraph Data (raw) | Paragraph Data (effective) |
| --- | ---- | -------- | -------- | -------------------- | -------------------------- |
| `kjv` | King James Version | English | `assets/kjv.json` | No | OT + NT replay |
| `leb` | Lexham English Bible | English | `assets/leb.json` | No | OT + NT replay for available verses |
| `nasb` | New American Standard Bible 2020 | English | `assets/nasb.json` | No | OT + NT replay |
| `cuvs-yhwh` | 和合本雅伟版 (简) | Simplified Chinese | `assets/cuvs-yhwh.json` | No | OT + NT replay |
| `cuvs-yhwh-tr` | 和合本雅伟版 (繁) | Traditional Chinese | `assets/cuvs-yhwh-tr.json` | No | OT + NT replay |
| `cuv` | 和合本 (简) | Simplified Chinese | `assets/cuv.json` | No | OT + NT replay |
| `cuv-tr` | 和合本 (繁) | Traditional Chinese | `assets/cuv-tr.json` | No | OT + NT replay |
| `cnv` | 新译本 (简) | Simplified Chinese | `assets/cnv.json` | No | OT + NT replay |
| `cnv-tr` | 新译本 (繁) | Traditional Chinese | `assets/cnv-tr.json` | No | OT + NT replay |
| `biblexg` | 原文释经圣经 (简) | Simplified Chinese | `assets/biblexg.json` | No; NT text only | NT replay |
| `biblexg-tr` | 原文释经圣经 (繁) | Traditional Chinese | `assets/biblexg-tr.json` | No; NT text only | NT replay |
| `biblexg-v2` | 原文释经圣经第二版 (简) | Simplified Chinese | `assets/biblexg-v2.json` | NT only (canonical source) | NT |
| `biblexg-v2-tr` | 原文释经圣经第二版 (繁) | Traditional Chinese | `assets/biblexg-v2-tr.json` | NT only (canonical source) | NT |

Default version on first launch: `cuvs-yhwh`.

**Paragraph mode note**: Paragraph metadata is shared at load time. The NT uses LJK2 (`biblexg-v2`) as the canonical source; the OT uses `assets/web-ot-paragraphs.json`, a derived map of 11,922 verse starts from the public-domain World English Bible USFM. `FetchVerses` replays both sources by english book name + `chapter:verse`, so paragraph layout is consistent across translations wherever the version includes those verses.

---

## Build & Deploy

```bash
# Build for web
flutter build web

# Build for Android
flutter build apk --release
```

### Deploy to Netlify (manual)

GitHub and Netlify are NOT linked. Deployment is manual:

```bash
# 1. Build locally
flutter build web

# 2. Deploy to Netlify
netlify deploy --prod --dir=build/web --auth $NETLIFY_AUTH_TOKEN --site $NETLIFY_SITE_ID

# 3. Push to GitHub (uses GITHUB_TOKEN from .env when configured)
git push origin main
```

- **Live site**: https://yswords.netlify.app
- **Publish directory**: `build/web/`
- **SPA redirect**: configured in `netlify.toml`

Netlify does NOT run Flutter — the build must be done locally first.

---

## Contributing

1. Fork this repo and clone your fork.
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Commit your changes with clear messages.
4. Push and open a Pull Request.

Please run `flutter analyze` before committing.

---

## Developer Environment

| Tool      | Version           |
| --------- | ----------------- |
| Flutter   | 3.22+             |
| Dart      | 3.2+              |
| IDEs      | VS Code, Android Studio |
| Analyzer  | `flutter analyze` |

---

## Disclaimer & Use

YsWords is a **non-commercial personal / community Bible-study tool**.
The application code is open source, but **scripture texts and other
embedded resources remain the copyright of their respective rights
holders**. They are reproduced here under fair-use / personal-study
exemptions and the explicit licences listed below.

This project is **not affiliated with or endorsed by** any of the
publishers, ministries, or font foundries referenced. The bundled
asset files are subject to their own licences which take precedence
over the MIT licence on the application code.

If you are a rights holder and have any concern about content
included here, please contact me at the address below — I commit to
responding and, where appropriate, removing the content within
**72 hours**.

---

## License

The **application code** in this repository is released under the
[MIT License](LICENSE). The **bundled scripture texts and other
asset files** are licensed separately as listed below.

### Bundled scripture texts

| Edition | Status | Notes |
| --- | --- | --- |
| KJV (1611 / 1769) | Public domain | No restrictions in most jurisdictions. |
| LEB (Lexham English Bible) | © Logos Bible Software | Used under the LEB licence; non-commercial study only. |
| NASB 2020 | © The Lockman Foundation | Used under the publisher's free-quotation provisions; non-commercial use only. |
| 和合本 1919 (CUV, 简/繁) | Public domain | Original 1919 text. |
| 和合本雅伟版 (CUVS-YHWH, 简/繁) | Used with permission | © Yahweh De Hua Ministry · https://yahwehdehua.net/cn |
| 新译本 1992 / 2011 (CNV, 简/繁) | © Worldwide Bible Society | Yahweh-substituted edition; community study version. |
| 原文释经圣经 LJK1 / LJK2 (简/繁) | Used with permission | © Bible Exegesis Ministry · https://www.biblexg.com/ |

> **NIV (New International Version) was previously bundled but
> removed in 2026-05.** Biblica / Zondervan retain commercial
> copyright on the full text, and we cannot redistribute the JSON
> bundle without an explicit publisher licence. Readers seeking NIV
> should follow Bible Gateway / YouVersion.

### Strong's lexicons & original-language data

| Resource | Licence |
| --- | --- |
| Strong's Greek + Hebrew Concordance | Public domain (1890s). |
| CBOL Chinese definitions (`bible.fhl.net`) | CC-BY-NC-SA 4.0 — non-commercial only; all derivatives must keep this licence. |
| LXX (Septuagint) data | Public domain. |
| Greek + Hebrew interlinear (Strong's-tagged) | Public-domain morphological databases. |

### Maps, fonts, and other assets

- Bible-history maps (`assets/maps/`) — sourced from public-domain /
  Creative Commons archives. See in-app About → Attributions for
  per-map credits.
- Fonts: **Roboto** (Apache 2.0, Google) bundled. All other fonts
  (EB Garamond, Lora, Merriweather, Inter, Open Sans, Lato,
  Noto Serif SC, Noto Sans SC, ZCOOL XiaoWei, Ma Shan Zheng, …) are
  loaded at runtime via Google Fonts under the SIL OFL.
- Sermons (`assets/sermons/`) — © Liang Jia-keng (LJK), used with
  permission.

---

## Contact / Takedown Requests

For questions, feedback, or licensing / takedown requests:

**paul.sy.liu@gmail.com**

If you are a rights holder and would like content removed, a single
email to that address is sufficient. I will acknowledge within
24 hours and act within 72 hours.

---

> "Your word is a lamp to my feet and a light for my path." — Psalm 119:105
