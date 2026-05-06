<h1 align="center">YsWords – Yahweh's Words</h1>

<p align="center">
  <img src="assets/app_icon.png" alt="YsWords App Icon" width="60"/>
</p>

<p align="center"><em>A bilingual Bible reader for Yahweh's words built with Flutter.</em></p>

---

## Quick start

### For users — nothing to install
Open <https://yswords.netlify.app>. Read the Bible immediately
(no sign-in needed). Optional: sign in with Google to sync
highlights / bookmarks / notes / reading-plan progress across your
devices via your own Drive (one click "Allow" on the consent
screen, no setup).

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
netlify deploy --prod --dir=build/web
```

For cloud features (sync + AI) to work in production, see
[**SETUP.md**](SETUP.md) for the one-time Google Cloud Console
configuration. The fastest path:

1. Run `bash scripts/enable-cloud-apis.sh` (or paste it into
   <https://shell.cloud.google.com> if you don't have gcloud
   installed locally) — enables Drive + Gemini APIs in your
   project.
2. Open the deployed app → Settings → Account → "Run check"
   diagnostic. Any remaining UI-only steps (OAuth scope, Firebase
   authorized domains, Netlify env vars) get one-click deep-links
   straight to the Cloud Console pages that fix them.
3. Verify: every probe row should turn ✅.

The diagnostic + walkthrough live inside the app permanently —
once set up, you can ignore them. End users never need to enable
any APIs themselves; everything is at the project level.

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
| Search       | Book-only or whole-Bible search; Highlighted results with book summary                                                  |
| Annotations  | `{...}` inline badges with linked `<note:...>` pop-ups; `[...]` dotted-underline keywords; Book icon notes              |
| Section titles | Inline scripture-section headings with optional ⓘ context popovers — covers all 14 versions × 66 books                  |
| Book intros  | Collapsible historical-context card at the top of every chapter 1, bilingual                                            |
| Bible Evidence | Browsable archive of 225 archaeology / manuscript / science / history finds with bilingual descriptions and scripture cross-link; chapter-aware filter from inside the reader |
| Daily News   | Bilingual world / China / Australia headlines with full article body, AI-picked Bible verse, and reflection — refreshed hourly from the central data CDN |
| Cloud Sync   | Optional Google sign-in syncs highlights + bookmarks + notes via Firestore; offline-first with last-writer-wins reconciliation |
| Reload       | One-tap Reload from the floating-header overflow menu and the empty-reader scaffold so users never have to relaunch the app to recover from a load failure |
| Copy & Share | Tap verses to multi-select; Copy in **Plain**, **With Reference**, or **Devotional** formats                            |
| Persistence  | Last-read position, highlights & user settings stored with `shared_preferences`; cloud sync layered on top              |
| Platforms    | Android, iOS, Web, macOS, Windows, Linux                                                                                |

---

## App Screenshots

| Main Reading View & Multi-select                                                                   | Note Popup                                                                             |
| -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| <img src="assets/screenshots/screenshot_multi_select.png" alt="Main Reading View" height="250"/>   | <img src="assets/screenshots/screenshot_note_popup.png" alt="Note popup" height="250"/> |

| Search Results                                                                                    | Search Filter                                                                                         |
| ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| <img src="assets/screenshots/screenshot_search_results.png" alt="Search results" height="250"/>   | <img src="assets/screenshots/screenshot_search_filter_zh.png" alt="Dropdown Simplified" height="250"/> |

| Version Switching                                                                                         | Settings Page                                                                                    |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| <img src="assets/screenshots/screenshot_version_switch.png" alt="Version switching menu" height="250"/>   | <img src="assets/screenshots/screenshot_settings_page.png" alt="Settings page" height="250"/>    |

| Book & Chapter Picker                                                                                         | Splash Screen                                                                                       |
| ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| <img src="assets/screenshots/screenshot_book_chapter_picker.png" alt="Book and chapter picker" height="250"/> | <img src="assets/screenshots/screenshot_loading_page.png" alt="Splash screen" height="250"/>       |

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

Requires **Flutter >= 3.22** and **Dart >= 3.2**.

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

## Project Structure

```
assets/                 Bible JSON files, fonts, images
lib/
  models/               Verse, Book, Chapter, AppSettings
  providers/            MainProvider (state + persistence)
  pages/                HomePage, BooksPage, SearchPage, SettingsPage
  widgets/              VerseWidget, ParagraphGroupWidget, BookChapterPicker, SidebarPanel, LocalizedBackButton, BibleReadingPane
  services/             FetchVerses, FetchBooks
  constants/            Book lists, UI strings, text patterns, Bible versions
  utils/                Clipboard helper, search formatter, version mapper, verse span builder, responsive breakpoints
pubspec.yaml            Dependencies & asset registration
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
| English  | NASB 2020, NIV 2011        | api.bible (requires API key)                       |
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
| `niv` | New International Version 2011 | English | `assets/niv.json` | No | OT + NT replay |
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
- Songs metadata (`assets/songs.json`) — link-out only; no audio /
  PDF / lyrics are embedded.

---

## Contact / Takedown Requests

For questions, feedback, or licensing / takedown requests:

**paul.sy.liu@gmail.com**

If you are a rights holder and would like content removed, a single
email to that address is sufficient. I will acknowledge within
24 hours and act within 72 hours.

---

> "Your word is a lamp to my feet and a light for my path." — Psalm 119:105
