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

### This app does not ship the CSB

Filed on 2026-09-07 at the owner's request. Recording it changes
nothing that a reader sees, and nothing on the About page moved: the
bundled texts are KJV, LEB, NASB, CUVS-YHWH (简/繁) and LJK1/LJK2, and
none of them is the CSB. It is here so the paperwork is in the same repo
as the app it would govern, if it ever does.

**Two things gate ever using it here, and neither is ours to decide:**

1. **Territory.** The grant is Hong Kong / Mainland China.
   `yahwehword.com`, `yswords.netlify.app` and `yswords-cn.netlify.app`
   are open worldwide, and so are the App Store / Play listings.
2. **Licensee and work.** It names Raymond Suen personally, for one
   named work — "CUV/CSB w/Strong's Numbers bilingual Bible". This app
   is a different work by a different publisher of record, so the grant
   does not reach it on its face.

Both belong to Raymond / Paul, not to this repo. The 雅伟的话 note
raises the same two against *that* project, which does ship the text.

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

**What it does not settle, and is not an objection to him.** The
territory line — Hong Kong / Mainland China — is *Holman's* term, not
Raymond's, so extending his own permission does not move it. Worth one
question back to him before the text ships, because it is the kind of
thing a publisher asks about later rather than earlier.

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

If the CSB is ever added, the grant requires this on the copyright or
title page — which in this app is the About page — word for word:

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
