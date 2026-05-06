# Plan: NET Bible notes + Matthew Henry Commentary

These two features are **content-dependent** — the work is roughly
80% data acquisition + parsing, 20% UI integration. This doc captures
the plan so a follow-up session can finish them.

Everything else from the 6-feature batch (deep AI exegesis, lemma
search, TSK already integrated, proper-noun definition fix) shipped
in the same round. This doc is just for the two pending items.

## Goal

Surface free, public-domain commentary content alongside each verse:

| Feature | Goal | Why |
|---|---|---|
| **NET Bible notes** | ~60,000 translator notes inline-linked to verses | Free + Creative Commons. Mini-BDAG quality. |
| **Matthew Henry** | Full commentary tied to verse ranges | Public domain, comprehensive, 18-c classic. |

Trigger from the verse selection action bar:
*Selected verses → Original | Copy | Highlight | Notes | Commentary*

The new "Commentary" button opens a sheet showing both NET note(s)
and Matthew Henry section for that verse range.

---

## NET Bible notes

### Data source
- **Original**: <https://netbible.org> (Bible.org)
- **Distribution license**: NET Bible is free with permissive terms
  for non-commercial use; translator notes are CC-BY (with attribution
  required).
- **Bulk download**: <https://labs.bible.org/api_doc> exposes a JSON
  API. For bulk acquisition, the cleanest path is the XML release at
  <https://bible.org/downloads> ("NET Bible XML download" — sign-in
  needed).
- **Alternative**: scrape via the labs.bible.org JSON endpoint.
  Example:
  ```
  https://labs.bible.org/api/?passage=John+3:16&type=json&formatting=full
  ```

### Approximate size
- ~60,500 translator notes
- ~50–70 MB raw JSON
- Bundled (compressed in app): ~15-25 MB

### Schema (proposed)
File: `assets/net_bible_notes.json`
```json
{
  "_meta": { ... },
  "John 3:16": {
    "verseText": "For this is the way God loved...",
    "notes": [
      {
        "id": "tn1",
        "type": "tn",        // tn = translator note
        "text": "...",
        "anchor": "loved",   // word/phrase the note attaches to
        "ord": 1
      },
      ...
    ]
  },
  ...
}
```

### Acquisition steps (next session)
1. Sign in to bible.org and download the NET Bible XML release.
2. Run `scripts/build_net_notes.py` (to be written) that:
   - Parses the XML
   - Strips formatting except basic emphasis
   - Indexes by canonical English book name + chapter + verse
   - Writes `assets/net_bible_notes.json`
3. Add to `pubspec.yaml` under assets.
4. Add `lib/services/net_notes_service.dart` lazy loader (similar to
   `originals_service.dart` shape).

### UI
- New "Commentary" button in the verse-selection action bar.
- Modal sheet: lists NET notes (tn, sn, study notes) with anchor
  text bolded, plus the Matthew Henry section below.

---

## Matthew Henry Commentary

### Data source
- **Original**: 1706-1721, fully public domain.
- **Bulk download**: <https://ccel.org/ccel/henry/mhc.html> has the
  full work as plain HTML / TEI. The simplest distribution is
  Henry's CCEL XML release, free.
- **Alternative**: openbible.com has parsed-by-verse-range JSON.

### Approximate size
- ~1,800-2,000 pages of commentary
- Per book: 5-50 commentary sections per chapter
- Bundled compressed: ~25-30 MB

### Schema (proposed)
File: `assets/matthew_henry_commentary.json`
```json
{
  "_meta": { ... },
  "John|3": [   // book + chapter
    {
      "verseStart": 1,
      "verseEnd": 21,
      "title": "Christ's Discourse with Nicodemus",
      "body": "..."
    },
    {
      "verseStart": 22,
      "verseEnd": 36,
      "title": "John's Testimony to Christ",
      "body": "..."
    }
  ],
  ...
}
```

### Acquisition steps (next session)
1. Download the CCEL XML/HTML release of Matthew Henry's complete
   commentary.
2. Run `scripts/build_matthew_henry.py` (to be written) that:
   - Parses the document
   - Extracts each (book, chapter, verseRange, title, body) section
   - Strips formatting
   - Writes `assets/matthew_henry_commentary.json`
3. Add to `pubspec.yaml`.
4. Add `lib/services/matthew_henry_service.dart` lazy loader.

### UI
- Same "Commentary" sheet as NET notes — Matthew Henry section
  appears below NET notes.
- Each MH section is collapsible; default to the section that
  contains the user's selected verses, others collapsed.

---

## Why we're not doing both this session

- **External data acquisition**: bible.org needs sign-in; CCEL needs
  multi-step XML processing. Both are 30+ minutes just to get the
  raw bytes.
- **Per-version parsing scripts**: each is ~200 lines of careful Python
  with edge cases (non-standard verse refs, footnote formatting, etc.).
- **App size**: adding ~40-55 MB to the bundle is a serious decision
  — affects offline pack size, initial load time, App Store / Netlify
  bandwidth.

Those decisions and the data work merit their own focused session.

---

## What this session DID ship

- ✅ **Item 1** — AI Deep Exegesis (BDAG-level structured analysis,
  500-750 words, new "Deep exegesis" chip in the AI scope row)
- ✅ **Item 3** — TSK cross-references (already in
  `assets/cross_references.json`, surfaced via the cross-refs sheet)
- ✅ **Item 5** — Lemma search (type Greek / Hebrew / transliteration
  → resolves to Strong's # → standard concordance flow)
- ✅ **Item 6** — Proper-noun definition consistency fix (now shows
  both EN and ZH definitions side-by-side for proper nouns, not
  just the locale-preferred one)

**Net session output**: 4 of 6 items + a planned doc for the
remaining 2.
