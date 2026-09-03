# JFB commentary — why we believe we may ship it

**Read this before touching `assets/commentary/jfb-matthew.json` or adding
any further commentary module.**

This repository already has one unresolved licensing problem — NASB and
LEB are bundled natively but stripped from the web build while we wait
on the publishers (`docs/nasb-licence-request.md`,
`docs/leb-licence-request.md`, `lib/constants/bible_versions.dart:151`).
NIV was deleted outright. The standing position is that redistributing
somebody's whole text needs permission, and "it's old" is not evidence.
So the evidence is written down here, verbatim and dated, the way
`docs/cuv-yhwh-publisher-notes.md` does it for the Bible edition.

Evidence gathered **2026-09-03**.

---

## The work

**Commentary Critical and Explanatory on the Whole Bible**, by

| Author | Born | Died |
|---|---|---|
| Robert Jamieson | 1802 | **1880** |
| Andrew Robert Fausset | 1821 | **1910** (8 February, at York) |
| David Brown | 1803 | **1897** |

Published in six volumes 1864–1870; the one-volume edition on which
every modern digital text is based appeared in **1871**.

CCEL's own title page for the work, <https://ccel.org/ccel/j/jamieson/jfb/>,
retrieved 2026-09-03:

> This commentary has been a bestseller since its original publication
> in 1871

and, in the author panel on the same page:

> Born: AD 1802 Died: AD 1880

Fausset's dates are from the Wikipedia biography and the standard
reference works agreeing with it; he is the last of the three to die,
so he is the one that matters.

## Why that makes it public domain

Two independent routes, either of which is sufficient:

1. **United States — publication date.** The work was published in
   1871. As of 2026 every work published before 1931 is out of
   copyright in the United States. 1871 clears that by sixty years.

2. **Life + 70 jurisdictions.** The last surviving author, Fausset,
   died in 1910. Copyright expired on 1 January 1981. This covers the
   UK, the EU, and every other life+70 country. Life+50 countries were
   clear in 1961.

There is no route by which a work published in 1871 by three men all
dead before the First World War is still in copyright anywhere.

## What the distributor says

The text ships as the CrossWire Bible Society SWORD module `JFB`,
version 3.0, `SwordVersionDate=2021-02-15`. Verbatim from
`mods.d/jfb.conf` inside the module archive:

> DistributionLicense=Public Domain

> TextSource=https://ccel.org/ccel/j/jamieson/jfb/cache/jfb.txt

> About=Robert Jamieson, A. R. Fausset and David Brown\par Commentary
> Critical and Explanatory on the Whole Bible (1871)

This is worth more than boilerplate. CrossWire tracks licences per
module and marks the restricted ones as such — sibling modules in the
same repository carry `DistributionLicense=Copyrighted; Permission to
distribute granted to CrossWire`. They distinguish, and they put JFB in
the free column.

**Archive this was built from**

| | |
|---|---|
| URL | `https://www.crosswire.org/ftpmirror/pub/sword/packages/rawzip/JFB.zip` |
| Retrieved | 2026-09-03 |
| Size | 5,687,740 bytes |
| SHA-256 | `3d767dbf8d89608dffdc94e1dbd629ce37ee5bb5072e61accf1cb7a106d1f6aa` |

The archive is data only — a `.conf` plus six binary index/blob files,
parsed with `zlib` and a struct unpacker in
`tools/build_commentary_jfb.py`. Nothing from it is executed.

## The one soft spot, recorded honestly

CrossWire's stated text source is CCEL, and **CCEL's site-wide copyright
policy is not a public-domain dedication**. Verbatim from
<https://ccel.org/about/copyright.html>, retrieved 2026-09-03:

> CCEL.org website and special contents copyright 1993-2020 Harry
> Plantinga.

> Most of the editions at the Christian Classics Ethereal library are
> based on books that are public domain in the United States. However,
> they may have copyrighted introductions, cover art, and other special
> contents. A few books are under another publisher's copyright and are
> used by permission; these are noted on the book information page.

> These books may be used for personal, educational, or non-profit
> purposes. Contact us for permission to republish CCEL works or to use
> them commercially.

> Copyright laws in other countries vary; it may be that some books that
> are in the public domain in the United States but are still under
> copyright in other countries. Check your local copyright law before
> copying.

Three things about that, in order of how much weight they carry:

1. **The JFB title page carries no publisher-copyright note.** CCEL's
   policy says the books that *are* under another publisher's copyright
   "are noted on the book information page". <https://ccel.org/ccel/j/jamieson/jfb/>
   was checked on 2026-09-03 and carries no such note — only the
   site-wide footer link. By CCEL's own rule that puts JFB in the
   "public domain in the United States" majority.

2. **What we ship is the 1871 text, not CCEL's presentation.** The
   caveats CCEL raises are about "copyrighted introductions, cover art,
   and other special contents" and about the website. We ship none of
   those. A faithful transcription of a public-domain text is not itself
   copyrightable in the United States — there is no original authorship
   in retyping someone else's words (*Feist*, and *Bridgeman v. Corel*
   for the same point about faithful reproductions).

3. **The "personal, educational, or non-profit purposes" sentence is a
   site term, not a copyright claim**, and this app is a non-commercial
   scripture-study app given away free. Even reading that sentence at
   its most restrictive, we are inside it.

**What would change this assessment:** CCEL adding a publisher-copyright
note to the JFB book information page, or CrossWire changing
`DistributionLicense`. If either happens, this module comes out. Re-check
before adding a *second* commentary module — do not assume the next one
inherits this finding.

## What we owe

Nothing legally. But the queue item says to credit the source anyway,
and that is right. The credit is on the About page under Lexicons &
references (`lib/pages/about_page.dart`), naming the three authors, the
1871 date, the public-domain status and CrossWire as the source of the
digital text. `test/jfb_commentary_test.dart` fails if that row or this
file disappears.

## What was rejected, and why

- **`.cmt.mybible` SQLite from ph4.org / myswordmodules.com** — the
  format the queue item named. Those aggregators publish no per-module
  licence statement at all. CrossWire publishes one in the module
  itself, and the brief asked to prefer a source that states its licence
  explicitly, so the format requirement lost to the licence requirement.
  The queue item's actual concern — "never scraped" — is satisfied
  either way: this is a published, packaged module, not HTML off a page.
- **Matthew Henry's Concise (MHCC)** — also marked Public Domain by
  CrossWire, but its `About` field describes a text "prepared from the
  printed edition as published by Moody Press, 28th printing, no
  Copyright displayed", re-keyed by a third party "with roughly 1200
  errors corrected". "No copyright displayed" on a 20th-century printing
  is not the same quality of evidence as an 1871 publication date, and
  the Concise is an abridgement whose abridger is not named. Weaker
  chain, so not chosen.
- **Matthew Henry's Complete (MHC)** — unimpeachable (Henry died 1714)
  but the module is 15 MB against JFB's 5.7 MB, and the brief asked for
  one module shipped end to end with the bundle cost watched.
