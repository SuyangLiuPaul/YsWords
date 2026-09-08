# Permissions on file / 授权文件

Originals live here. Anything a reader is shown — the licence column of
the About page's bundled-texts table, in `lib/pages/about_page.dart` —
must match a document in this directory or a note in `docs/*-licence.md`.

A document being on file is **not** the same as the app using it. The
index below says, for each one, whether this app ships the text.

---

## CSB — Christian Standard Bible (2017)

**Original:** [CSB Holman permissions grant 2017-04-04.pdf](CSB%20Holman%20permissions%20grant%202017-04-04.pdf)
(SHA-256 `643e11a8…14997`, byte-identical to the copy filed in the
雅伟的话 repo — see the cross-reference at the end.)

| | |
|---|---|
| Date of grant | 2017-04-04 |
| Licensee | **Raymond Suen, personally** — a named individual, not an organisation |
| Grantor | Jean Eckenrode, LifeWay Resources / Holman Bible Publishers |
| Grant | NON-EXCLUSIVE ebook/app — CSB text **with Strong's Numbers** |
| Title of the work | **CUV/CSB w/Strong's Numbers bilingual Bible** |
| Territory | **Hong Kong / Mainland China** |
| Fee | GRATIS **provided the work is distributed free**; if it becomes a salable product the permission terminates |
| Termination | When the Work is no longer available |

### This app ships the CSB — since 2026-09-07

It is the eighth bundled text, alongside KJV, LEB, NASB, CUVS-YHWH
(简/繁) and LJK1/LJK2. Both gates below were answered first — read them,
then the two 2026-09-07 sections that close them.

**The two gates, as they stood:**

1. **Territory.** The grant is Hong Kong / Mainland China.
   `yahwehword.com`, `yswords.netlify.app` and `yswords-cn.netlify.app`
   are open worldwide, and so are the App Store / Play listings.
2. **Licensee and work.** It names Raymond Suen personally, for one
   named work — "CUV/CSB w/Strong's Numbers bilingual Bible". This app
   is a different work by a different publisher of record, so the grant
   does not reach it on its face.

Neither belonged to this repo, and neither was decided here.

**What shipping it involved.** `tools/import_csb.py` builds
`assets/csb.json` from the module in the 雅伟的话 database. Strong's
numbers are dropped — this app ships no tagged text — which is the one
place it differs from the SeekSparks importer, where the numbers are
kept because the grant is for the CSB *with* them. The credit line
below is rendered on the About page verbatim in all three locales, and
`test/csb_asset_test.dart` quotes it in full so a paraphrase fails the
build.

**One thing the reader should be told plainly:** the text is not the
module as received. 967 verses had lost CSB's own small-caps LORD and
read a bare "Lord" — Deuteronomy 6:4, the Shema, among them. The
importer restores the divine name in those, on the module's own
typographic evidence, checked against the KJV and the Chinese
和合本雅伟版. The 雅伟的话 note records the same kind of edit — its 5,041
verses — as an editorial change the grant does not mention either way.

### 2026-09-07 — the licensee extends it to yahwehword.com

In the Yahwehdehua Work Group (Aunty Rosa, Pastor Raymond HK, Peter and
the owner), **Pastor Raymond** — who is the Raymond Suen named as
licensee on the grant above — sent this PDF at 1:14 pm with "we have
permission to use HCSB, can add that", and at 1:28 pm added:

> we can stretch this permission to cover your Yahwehword.com

Recorded here as reported by the owner, who was in that group.

**What it settles.** Gate 2. The objection was that the grant runs to
Raymond personally for one named work; the person it runs to has now
said it reaches this site. That is his to say, and he has said it.

**Territory — asked, and answered by the owner.** The written grant
says Hong Kong / Mainland China, which is *Holman's* term rather than
Raymond's, so this note raised it twice as a question to put back to
him. The owner's answer, 2026-09-07: **worldwide distribution is fine**
— the CSB is freely readable online, and the apps are free.

Recorded as what it is: the owner's decision, not a variation of the
written grant, which still reads Hong Kong / Mainland China on its face.
Anyone reading this later should know which of the two they are looking
at. The decision is his to make; this file's job is to say plainly what
the paper says and what was decided.

**One naming point, because it changes the required credit line.**
Raymond calls it HCSB. The document says **CSB**, and the 雅伟的话
verse-by-verse check found the text actually shipped there is CSB 2017,
not HCSB (its `bsapp_bible_hcsbs` table name is a legacy key). The
credit line below is the CSB one, which is the one the grant requires.

**Scope.** The message names `Yahwehword.com`. This note first read
that narrowly, as covering this app only; the owner corrected it —
**SeekSparks is one of the Yahweh's Words products, so the extension
reaches it too.** He publishes both, and the sibling repo carries the
same claim independently: its `pubspec.yaml` describes it as "forked
from YsWords", its iOS display name is *Yahweh's Sword*, and its bundle
id is `com.example.yahwehswords`. Its copy of this file records the
correction.

### The credit line, verbatim

The grant requires this on the copyright or title page — which in this
app is the About page — word for word:

> Scripture quotations marked CSB®, are taken from the Christian
> Standard Bible®, Copyright © 2017 by Holman Bible Publishers. Used by
> permission. Christian Standard Bible®, and CSB® are federally
> registered trademarks of Holman Bible Publishers.

Holman's naming rule: use **CSB** in running text and in Scripture
references; the ® is needed on the copyright page and on first mention
in promotional copy, not in ordinary running text.

### Cross-reference — the full analysis is not repeated here

`CodingProject/Yahwehdehua/docs/授权 permissions/README.md` carries the
work this note deliberately does not duplicate: the verse-by-verse check
confirming that project's `bsapp_bible_hcsbs` table really is CSB 2017
rather than HCSB, the note that its table name is a legacy key, and the
record of its 5,041-verse `the LORD` → `Yahweh` edit — an editorial
change the grant does not mention either way.

---

## The other bundled texts

Not in this directory; they are prose notes or have no document.

| Text | Where its licence is recorded |
|---|---|
| KJV | Public domain — About page |
| LEB | `docs/leb-licence-request.md` |
| NASB 2020 | `docs/nasb-licence-request.md` — quotation provisions |
| CUVS-YHWH (简/繁) | `docs/cuv-yhwh-publisher-notes.md`; © Yahweh De Hua Ministry, used with permission |
| LJK1 / LJK2 | © Bible Exegesis Ministry, used with permission — no written document on file |
| JFB commentary | `docs/jfb-commentary-licence.md` |
| BSB / BSB (Yahweh) | Public domain since 2023-04-30; Yahweh restoration © Yahweh De Hua Ministry — see below |
| ASV (Yahweh) 1901 | Public domain by age; Yahweh restoration © Yahweh De Hua Ministry — see below |
| WH Greek NT 1881 | Public domain — About page |

---

## 2026-09-08 — the Septuagint, and what this app does NOT claim about it

**Shipped as `lxx`, on the owner's instruction, with no licence
asserted.** This section exists because that combination is unusual and
should not be discovered later as an oversight.

### What is known

| | |
|---|---|
| Source | `bsapp_bible_lxxs` in `Yahwehdehua/app/build/bible.db`, imported by `tools/import_ydh_texts.py lxx` |
| Where it came from | Peter supplied the module `LXX-WH+.ont` (theWord, 2026-08-30 build) directly to the 雅伟的话 project |
| Which critical edition it is | **Unknown.** A theWord module does not name its edition, and nothing in the export does either |
| Licence | **Unresolved.** The note recording its arrival reads 「授权仍归 Peter 判断」 — the licence remains Peter's to judge |

The reflex is "the Septuagint is ancient, so it is public domain." That
reflex is wrong in the way that matters: the Greek is ancient, but what
carries copyright is the **modern critical edition** that reconstructs
it. `Yahwehdehua/PROJECT_STATE.md` records its own survey reaching that
conclusion — Rahlfs is claimed by the German Bible Society, CATSS
requires a signed agreement, Swete is bare text, STEPBible's TAGOT was
unreleased — and a second line in the same file says the edition
question 「不宜擅自采用，需 Raymond 判断版本」.

### The decision, and who made it

The owner was shown this position **and** the alternative — that the
sibling app's `lxxwh` is Eagle's View's electronic edition, whose grant
is written down in this file — and chose this module anyway:

> 用 yahwehdehua lxxs 版本吧 — owner, 2026-09-08

That is his to decide and it is recorded here rather than argued with.

### What the app therefore does and does not say

The rule this repo follows is that **anything a reader is shown must
match a document on file.** There is no document here, so the app shows
provenance and stops:

* The About row (`aboutLicenseLxx`) says the module was supplied by the
  雅伟的话 project and **does not name a critical edition**. It does
  **not** say "public domain" — `test/ydh_imported_texts_test.dart`
  asserts the absence of that phrase in all three locales.
* `editionYear` is not a year. Every other row can name its edition;
  this one cannot, and filling the field with "Rahlfs" or "1935" would
  be the app asserting the single fact that decides the licence.
* `lxx` is in `kVerseImageRestrictedVersions`. Reading it in the app is
  unaffected; putting it on a shareable image that leaves the app is a
  further act of redistribution, and there is nothing to print on the
  card as a licence.

**If the edition is ever identified**, that is the moment to revisit all
three. Deleting the `kVerseImageRestrictedVersions` entry and rewriting
`aboutLicenseLxx` is the whole change.

## 2026-09-08 — four texts from the 雅伟的话 export

Built by `tools/import_ydh_texts.py` from
`CodingProject/Yahwehdehua/app/build/bible.db`, the SQLite that project
exports for its own phone app. No document is filed here for any of
them, and none is owed: the three base texts are free, and the two
restorations are this ministry's own work.

**BSB and BSB (Yahweh).** The Berean Standard Bible has been public
domain outright since **2023-04-30** — "any use, no permission
required". `Yahwehdehua/PROJECT_STATE.md` records the same finding,
along with the detail that the official tagged edition exists only as
PDF and Word, which is why this app ships the untagged text.

**ASV (Yahweh).** The American Standard Version of 1901 is public
domain by age.

**What the "(Yahweh)" editions add, and why the About page says so.**
In both, the divine name is the ministry's own editorial restoration,
not something the Berean or ASV translators published — BSB (Yahweh)
reads Yahweh in 5,942 verses where the BSB prints the LORD, and ASV
(Yahweh) in 5,787 where the 1901 text printed Jehovah. Nothing is owed
for saying so; it is on the page because a reader told only "public
domain" has been told the true half that matters least. The four verses
where the ASV still shouts JEHOVAH inside a quoted inscription (Exod
28:36, Exod 39:30, Deut 28:58, Zech 14:20) are left as the ministry left
them.

**Westcott-Hort Greek NT.** Published 1881, public domain by age. The
module also carries the editors' own single and double brackets for
doubtful text, which ship untouched.

### Two texts in the same export that this app does NOT ship

**The Septuagint — the licence is unresolved, and not ours to resolve.**
The reflex is "the Septuagint is ancient, therefore public domain", and
it is the wrong reflex: what carries copyright is the modern critical
**edition**. `Yahwehdehua/PROJECT_STATE.md` records its own survey
finding no source that was at once available, authoritative and clearly
licensed — Rahlfs is claimed by the German Bible Society, CATSS requires
a signed agreement, Swete is bare text. The module in the database did
not settle that. It arrived from Peter on 2026-08-30, and the note
recording its arrival says in the same breath 「授权仍归 Peter 判断」 —
the licence is still Peter's to judge. Nothing in a theWord module names
its edition, so this app could not even state which text it was
offering.

The exported database's own `meta.licence` string does assert "WH/LXX/
WLC public domain". That line is the exporter's summary, written after
the module was already loaded, and it does not survive being read beside
the decision log above. **This file's rule is that what a reader is
shown must match a document on file or a note in `docs/`; one sentence
in a generated database is neither.**

*To ship it:* get Peter's answer on which edition it is and whether it
may be redistributed, file it here, then
`python3 tools/import_ydh_texts.py lxx`, add the code to `SHIPPED` in
that script, add a catalogue entry and an About-page row.

**"CSB (Yahweh)" — it is the CSB above, a second time.** The export
carries a text under that name. Its source is `bsapp_bible_hcsbs`, which
is the table `tools/import_csb.py` already built `assets/csb.json` from
on 2026-09-07. Measured verse by verse: **26,298 of 31,102 identical,
1,633 differing only in whitespace, and the remaining 3,138 differing
only by that importer's own two clean-ups** — the `? ”` spacing repair
and the divine-name restoration.

Shipping it as a distinct edition would put 6 MB of a licensed text in
the bundle twice, under terms that are gratis only while the work is
distributed free — and the naming would be backwards. The raw module
reads Yahweh in **5,041** verses; the `csb` this app already offers
reads it in **5,805**, Deuteronomy 6:4 among the difference:

> module: "Listen, Israel: The Lord our God, the Lord is one."
> shipped `csb`: "Listen, Israel: Yahweh our God, Yahweh is one."

So the row labelled "(Yahweh)" would be the one showing a reader FEWER
occurrences of the name than the row labelled plainly "CSB" above it.
`test/ydh_imported_texts_test.dart` pins that measurement, so if the two
ever genuinely diverge the reason recorded here fails rather than
quietly stops being true.
