#!/usr/bin/env python3
"""
Make the 940-record FYDT sermon library findable by scripture.

Reads:
  assets/sermon_library/index.json      (the catalogue synced by
                                         scripts/sync_sermon_library.py)
  assets/sermon_library/bodies/<id>.txt (843 Chinese-only bodies)
  lib/constants/sermon_credit.dart      READ ONLY — whose sermons the
                                        app's separate corpus holds
  assets/sermons/index.json             READ ONLY — the app's separate
  assets/sermons/refs.json              289-sermon corpus, read only to
                                        detect cross-corpus duplicates.

Writes:
  assets/sermon_library/refs.json

────────────────────────────────────────────────────────────────────
ONE GRAMMAR, NOT A THIRD (PROJECT_STATE trap 60)
────────────────────────────────────────────────────────────────────
`scripts/extract_sermon_refs.py` and `lib/utils/reference_parser.dart`
are already two implementations of the sermon<->verse grammar that have
drifted from each other once. This script adds NO third one: it imports
`extract_refs` from the Python side and calls it. Every rule about what
counts as a citation — the bare-numeral refusal, the single-CJK-
character abbreviation rule, the 節-says-verse guard, the canon check —
is that module's, unchanged. Nothing here re-implements any of it, and
this script never writes `assets/sermons/refs.json`.

The one thing this script adds is an INPUT NORMALIZATION, which is
deliberately not a grammar change:

    《哥林多前书》15：15-17节

This corpus wraps book names in 《》 book-title brackets. The closing 》
sits between the book name and the chapter number, where REF_RE admits
only `\\.?\\s*`, so the whole citation is invisible. Sermon 3170
「复活的盼望」 is a forty-minute exposition of 1 Corinthians 15 that
cites it twelve times and extracted ZERO references because of it.

Measured before the rule was written:
  * 58 sites of <book>》<number> in the 843 library bodies, across 25 of
    them; every one uses 》, no other closing bracket occurs. 41 of the
    58 carry the matching opening 《, and only those 41 are taken — see
    the comment on `BRACKET_JOIN` for the 17 that are refused and for
    the one false key the looser form invents.
  * ZERO sites in all 867 body files of the app's 289-sermon corpus, and
    the normalizer changes NOTHING in any of those 867 files. So it
    cannot move `assets/sermons/refs.json`.
  * Effect on this corpus: +61 (sermon, key) pairs, -0. Six records go
    from zero references to some: 3170 (25 keys), 3172 (16), 5131 (4),
    5202 (2), 4985 (1), 5064 (1).
  * All four single-key gains were read in context and are ordinary
    citations: 《出埃及记》11:4, 《路加福音》12章16节,
    《哥林多前书》第七章, 《箴言》三十章十节.

It is scoped to a complete 《book》 wrapper standing in front of a
number, rather than a blanket bracket strip, so it cannot join two
unrelated pieces of text. A blanket strip was not measured, so it is
not shipped.

────────────────────────────────────────────────────────────────────
WHY THE TAXONOMY IS NOT FETCHED HERE
────────────────────────────────────────────────────────────────────
The task brief said the records' `book` field "holds WordPress taxonomy
term ids for 书卷查考". It does not — `sync_sermon_library.py` already
resolved them, and `book` holds the term NAME (创世记, 马太福音, ...).

Verified against the live taxonomy on 2026-09-06 with ONE request to
`/wp-json/wp/v2/shujuanchakao?per_page=100`: 15 terms, and their
`count` fields sum to exactly 461, which is exactly the number of
records carrying a non-null `book`. So every record has at most one
term and `sync_sermon_library.py`'s `_first()` drops nothing. There is
nothing left to resolve, and this script makes no network calls at all.

Two of the 15 terms name the same Bible book: 罗马书 and 罗马书(纵览)
("Romans, overview"). `taxonomy_book` folds them, because a reader
looking for sermons on Romans wants both.

Run from repo root:
    python3 scripts/index_sermon_library_refs.py
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

import extract_sermon_refs as G  # the ONE grammar — see the header

LIB = REPO / "assets" / "sermon_library"
LIB_INDEX = LIB / "index.json"
REFS_OUT = LIB / "refs.json"

# Read-only. A separate corpus; this script never writes under it.
APP = REPO / "assets" / "sermons"
APP_INDEX = APP / "index.json"
APP_REFS = APP / "refs.json"
SERMON_CREDIT_DART = REPO / "lib" / "constants" / "sermon_credit.dart"


# ── Thresholds ──────────────────────────────────────────────────────
# Every number here is a ruling, not a preference. See the block
# comments at each use site for the measurement each rests on.
FOCUS_MIN_KEYS = 3          # distinct keys the chapter must hold
FOCUS_MIN_SHARE = 0.20      # ...and share of the sermon's keys
FOCUS_MAX_CHAPTERS = 3      # cap per sermon, highest share first

DUP_TITLE_HIGH = 0.75       # difflib ratio on normalized titles
DUP_CHAP_HIGH = 0.60        # chapter-set Jaccard
DUP_CHAP_FLOOR = 0.30       # below this, not a candidate at all
DUP_MIN_CHAPTERS = 3        # a fingerprint needs this many chapters

# A book in which the app corpus runs a long consecutive expository
# series. Sharing chapters with such a series is weak evidence, because
# two DIFFERENT sermons walking adjacent passages legitimately overlap.
SERIES_RISK_MIN_APP_SERMONS = 20


# ── Input normalization ─────────────────────────────────────────────
# A COMPLETE 《book》 title wrapper standing in front of a chapter
# number. See the header for the measurement; the reason it demands the
# OPENING 《 as well is here.
#
# The first draft asked only for a book alias in front of the 》, and
# that is too loose in this corpus, because so many Chinese book names
# end in a character that is itself a one-character alias. Measured:
# the loose form takes 58 sites, the anchored form 41, and all 17 it
# gives up are the same shape —
#
#     《圣经人物·摩西》第六讲     《圣经人物·约书亚》第一讲
#
# — a series header, where 摩 / 书 / 亚 are the tails of MOSES and
# JOSHUA rather than Amos, Joshua and Zechariah, and 第六讲 is "lecture
# six", not a chapter. None of the 17 reaches a key today (the grammar's
# single-character rule refuses them for want of a verse or a 章), so
# the loose form was wrong without yet being harmful — which is the
# worst way for a rule to be wrong, because nothing measures it.
#
# One site does get through, and it is a real invention: 36556 quotes a
# book called 《天国的福音——马太福音》一书中, and the loose form reads
# 一书中 ("in a book") as chapter 1 and files the sermon under
# `Matthew 1`. So the anchored form is +61 −0 against the raw text and
# −1 FALSE key against the loose form. It is the one that ships.
BRACKET_JOIN = re.compile(
    rf"《({G.BOOK_RE})》(?=\s*(?:第|\d|[〇零一二三四五六七八九十百]))")


def normalize_body(text: str) -> str:
    """Drop the closing 》 of a 《book》 wrapper that sits in front of a
    chapter number. The opening 《 is KEPT: it is not in the grammar's
    way — a word boundary already matches between 《 and the book name —
    and keeping it means the normalized text still reads as the original
    did, so a human checking a site sees what the corpus says."""
    return BRACKET_JOIN.sub(r"《\1", text)


# ── Taxonomy ────────────────────────────────────────────────────────
_QUALIFIER = re.compile(r"[(（].*?[)）]")


def taxonomy_book(term_name: str | None) -> str | None:
    """A 书卷查考 term name → canonical English book name.

    Resolved through the grammar module's own alias index rather than a
    second hand-typed table, so this cannot come to disagree with the
    extractor about what 马太福音 means. That second-copy mistake is
    exactly what once left 90 of the app's 130 Chinese spellings
    invisible to `extract_sermon_refs.py`.
    """
    if not term_name:
        return None
    base = _QUALIFIER.sub("", term_name).strip()
    return G.ALIAS.get(G.normalize_alias(base))


# ── Titles ──────────────────────────────────────────────────────────
_PUNCT = re.compile(r"[—–\-－()（）\[\]【】《》「」“”\"'’‘·．.,，、:：;；!！?？]")


def normalize_title(s: str | None) -> str:
    s = unicodedata.normalize("NFKC", s or "")
    s = re.sub(r"[\s　]+", "", s)
    return _PUNCT.sub("", s).lower()


def title_similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, normalize_title(a), normalize_title(b)).ratio()


def app_preacher() -> str:
    """The app corpus's single preacher, in Simplified Chinese, read out
    of `sermon_credit.dart` rather than typed here again. The whole
    cross-corpus duplicate question turns on this name: the app's 289
    are all his, and the library holds 198 more under the same name."""
    src = SERMON_CREDIT_DART.read_text(encoding="utf-8")
    m = re.search(r"'zh-Hans'\s*:\s*'([^']+)'", src)
    if not m:
        raise SystemExit(
            f"ERROR: no 'zh-Hans' preacher name in {SERMON_CREDIT_DART}")
    return m.group(1)


# ── Reference-set helpers ───────────────────────────────────────────
def chapters_of(keys) -> set[str]:
    """The chapter each key names. "Genesis 3:1" and "Genesis 3" both
    give "Genesis 3", which is what makes two INDEPENDENT transcriptions
    of one spoken sermon comparable. Verse-level agreement is not: the
    two texts quote the same passage at different lengths."""
    return {k.split(":")[0] for k in keys}


def jaccard(a: set, b: set) -> float:
    return len(a & b) / len(a | b) if (a or b) else 0.0


def focus_chapters(keys: list[str]) -> list[str]:
    """The chapters this sermon is ABOUT, as opposed to the ones it
    merely quotes.

    RULING (2026-09-06): a chapter qualifies on BOTH >= 3 distinct keys
    AND >= 20% of the sermon's keys. Both, not either — and this is the
    only bar whose joint count was measured: 797 of the corpus's 7,637
    (sermon, chapter) pairs, against 1,662 for the key-count test alone
    and 1,123 for the share test alone.

    Each half kills a distinct failure. The key-count floor kills the
    short record where one passing quote is 33% of three total keys; the
    share floor kills a 3-key chapter buried in a 72-chapter sprawl
    (the corpus's widest record cites 72 distinct chapters).

    A sermon with no qualifying chapter gets NO entry. "Not about any
    one chapter" is an honest answer for a topical sermon, not a gap to
    be filled by lowering the bar until something appears.
    """
    counts = Counter(k.split(":")[0] for k in keys)
    total = sum(counts.values())
    hits = [c for c, n in counts.items()
            if n >= FOCUS_MIN_KEYS and n / total >= FOCUS_MIN_SHARE]
    hits.sort(key=lambda c: (-counts[c], c))
    return hits[:FOCUS_MAX_CHAPTERS]


def load_app_corpus():
    """(app refs by id, app title by id, books carrying a long series).

    Returns empty structures if the app corpus is absent — this script
    is about the library, and cross-corpus duplicate detection is an
    annotation on top, not a precondition for indexing.
    """
    if not (APP_INDEX.exists() and APP_REFS.exists()):
        return {}, {}, set()
    refs = json.loads(APP_REFS.read_text(encoding="utf-8"))["bySermon"]
    titles = {}
    for a in json.loads(APP_INDEX.read_text(encoding="utf-8")):
        t = (a.get("titles") or {}).get("zh-CN") or a.get("title") or ""
        titles[a["id"]] = t
    # Which books the app corpus expounds at series length. Derived with
    # the same focus rule as everything else, so it cannot drift from it.
    per_book = Counter()
    for aid, keys in refs.items():
        for ch in focus_chapters(keys):
            per_book[ch.rsplit(" ", 1)[0]] += 1
    series_books = {b for b, n in per_book.items()
                    if n >= SERIES_RISK_MIN_APP_SERMONS}
    return refs, titles, series_books


def cross_corpus_duplicates(records, by_sermon, app_refs, app_titles,
                            series_books, preacher):
    """Candidate (library record, app sermon) duplicate pairs.

    RULING (2026-09-06): graded, never boolean, and NEVER auto-merged.

    A boolean would force one threshold to serve both the pairs where
    title and fingerprint agree and the weakest candidates; either way
    it asserts unverified merges as fact or throws away real duplicates.

    Restricted to library records by the app corpus's own preacher.
    A shared title across two DIFFERENT preachers is a title collision,
    which is a different fact and is reported separately — 「新造的人」 is
    a sermon title two men can both use.

    The evidence is the CHAPTER FINGERPRINT, not the text. Measured over
    every candidate pair, 6-gram containment between the library body
    and the app body peaks at 0.153: the two are independent
    transcriptions of one spoken sermon, not copies of one text, so text
    similarity is not a weak signal here but the absence of one. Library
    record 4249 「舍己：门徒的标记」 and app sermon 062 「施与，成为世上的
    光」 have a title similarity near zero and are demonstrably the same
    sermon — same opening on Matthew 11:28, same move to John 8:12 then
    Matthew 5:14, same argument. Chapter Jaccard 0.929.
    """
    tiers = []
    for rec in records:
        if rec.get("author") != preacher:
            continue
        sid = str(rec["id"])
        lib_chaps = chapters_of(by_sermon.get(sid, []))
        for aid, akeys in app_refs.items():
            app_chaps = chapters_of(akeys)
            exact = normalize_title(rec["title"]) == normalize_title(
                app_titles.get(aid))
            if (len(lib_chaps) < DUP_MIN_CHAPTERS
                    or len(app_chaps) < DUP_MIN_CHAPTERS):
                # No usable fingerprint. Only an exact title can speak,
                # and it is recorded as unverifiable rather than dropped.
                if exact:
                    tiers.append({
                        "libId": sid, "appId": aid, "tier": "confirmed",
                        "titleSim": 1.0, "chapterJaccard": None,
                        "sharedChapters": [], "seriesRisk": False,
                        "fingerprintAvailable": False,
                        "basis": "exactTitle",
                    })
                continue
            cj = jaccard(lib_chaps, app_chaps)
            if cj < DUP_CHAP_FLOOR and not exact:
                continue
            ts = title_similarity(rec["title"], app_titles.get(aid, ""))
            if exact or (ts >= DUP_TITLE_HIGH and cj >= DUP_CHAP_HIGH):
                tier = "confirmed"
            elif cj >= DUP_CHAP_HIGH:
                tier = "probable"
            elif ts >= DUP_TITLE_HIGH:
                tier = "possible"
            else:
                tier = "weak"
            shared = sorted(lib_chaps & app_chaps)
            books = {c.rsplit(" ", 1)[0] for c in shared}
            tiers.append({
                "libId": sid, "appId": aid, "tier": tier,
                "titleSim": round(ts, 3), "chapterJaccard": round(cj, 3),
                "sharedChapters": shared,
                # EVERY shared chapter inside a book the app expounds at
                # series length, so the overlap may be the series rather
                # than the sermon.
                #
                # PRICED, because a guard nobody measures is a guard
                # nobody can trust (trap 58). It fires ONCE in 105 pairs,
                # on a `weak` one. The confound is real in principle but
                # measurably rare here: pairs with a high Jaccard cite
                # WIDELY, so their shared chapters are never confined to
                # one book — 4004/012 at J=1.0 shares Matthew, Galatians,
                # Luke and 1 Timothy; 4249/062 at J=0.929 shares John,
                # Matthew, Acts and Daniel.
                #
                # Three looser readings were measured and rejected.
                # ">=50% of shared chapters in a series book" fires 13
                # and ">=75%" fires 2, neither tracking anything
                # meaningful. "The most-shared book is a series book"
                # fires 40 — including NINE `confirmed` pairs — so it
                # would mark known-good matches as suspect, which is
                # noise wearing a warning label, not a warning.
                #
                # Kept at the strict reading because it is the honest
                # one and because a future re-sync that adds more of the
                # Matthew series is exactly when it earns its keep.
                "seriesRisk": bool(books) and books <= series_books,
                "fingerprintAvailable": True,
                "basis": "exactTitle" if exact else "fingerprint",
            })
    # One row per (libId, appId); keep the strongest per library record
    # first so the UI can take the head of the list.
    rank = {"confirmed": 0, "probable": 1, "possible": 2, "weak": 3}
    tiers.sort(key=lambda d: (int(d["libId"]), rank[d["tier"]],
                              -(d["chapterJaccard"] or 1.0)))
    return tiers


def within_corpus_duplicates(records, by_sermon):
    """Records the SITE itself published twice, and bare title clashes.

    RULING (2026-09-06): treat these two differently.

    A byte-identical body under two record ids is a publishing artifact,
    not two sermons — the corpus holds two such pairs, and in both the
    copies differ only in that one carries an author attribution and the
    other carries none. The attributed copy is canonical and the UI may
    collapse the other by default. Neither record is deleted here: an id
    may be linked from outside.

    Two records sharing a title but not a text are NOT that. With 71
    preachers, a shared title across two of them is a coincidence of
    naming, so it is reported as a title collision and must not be
    conflated with duplication.
    """
    by_title = defaultdict(list)
    digest = {}
    for rec in records:
        by_title[normalize_title(rec["title"])].append(rec)
        if rec.get("bodyFile"):
            digest[str(rec["id"])] = hashlib.sha256(
                (LIB / rec["bodyFile"]).read_bytes()).hexdigest()

    identical, collisions = [], []
    for _, group in sorted(by_title.items()):
        if len(group) < 2:
            continue
        by_digest = defaultdict(list)
        for rec in group:
            by_digest[digest.get(str(rec["id"]))].append(rec)
        for dg, same in by_digest.items():
            if dg is not None and len(same) > 1:
                # Canonical = the copy that carries an author.
                canon = next((r for r in same if r.get("author")), same[0])
                for r in same:
                    if r is not canon:
                        identical.append({
                            "id": str(r["id"]),
                            "identicalCopyOf": str(canon["id"]),
                            "title": r["title"],
                        })
        if len({digest.get(str(r["id"])) for r in group}) > 1:
            collisions.append({
                "title": group[0]["title"],
                "ids": [str(r["id"]) for r in group],
                "authors": [r.get("author") for r in group],
                "samePreacher": len({r.get("author") for r in group}) == 1,
            })
    return identical, collisions


def build_document():
    lib_doc = json.loads(LIB_INDEX.read_text(encoding="utf-8"))
    records = lib_doc["sermons"]

    # ── Extract ─────────────────────────────────────────────────────
    by_sermon: dict[str, list[str]] = {}
    tax_book: dict[str, str] = {}
    for rec in records:
        sid = str(rec["id"])
        tb = taxonomy_book(rec.get("book"))
        if tb:
            tax_book[sid] = tb
        keys: list[str] = []
        if rec.get("bodyFile"):
            body = (LIB / rec["bodyFile"]).read_text(encoding="utf-8")
            keys = G.extract_refs(normalize_body(body))
        # The TITLE is deliberately not a second source here, and that
        # is a measurement rather than an oversight.
        #
        # It was written, shipped, and then deleted: running the grammar
        # over all 940 titles as well adds exactly ZERO (sermon, key)
        # pairs. 23 records have a title that parses, and every key it
        # yields is one the body already yielded — 4755's
        # 「约翰福音17章3节的再思」 is the shape, and its body states the
        # same reference. Mutation-testing is what exposed it: breaking
        # the line changed nothing any test could see, which is the
        # definition of an unpriced line (trap 58). A line that moves
        # nothing is deleted and the number written down, rather than
        # kept because it is obviously harmless — titles in this corpus
        # also carry 「圣经人物·摩西》第六讲」 and 「约瑟(3)」, so the
        # shape that would first make it non-inert is as likely to be an
        # invention as a rescue.
        if keys:
            by_sermon[sid] = keys

    by_verse: dict[str, list[str]] = defaultdict(list)
    for sid, keys in by_sermon.items():
        for k in keys:
            by_verse[k].append(sid)

    # ── byBook ──────────────────────────────────────────────────────
    # Book-level reach, which is the ONLY level 27 records have: they
    # carry a 书卷查考 term but no extractable citation. `bookSource`
    # says where each claim comes from, so the UI can tell a book the
    # sermon demonstrably quotes from one the site's editor filed it
    # under. The two disagree for 109 of the 434 records that have both,
    # which is far too often to declare either side the loser.
    by_book: dict[str, list[str]] = defaultdict(list)
    book_source: dict[str, dict[str, str]] = {}
    for rec in records:
        sid = str(rec["id"])
        from_body = {k.rsplit(" ", 1)[0] for k in by_sermon.get(sid, [])}
        from_tax = {tax_book[sid]} if sid in tax_book else set()
        for b in sorted(from_body | from_tax):
            by_book[b].append(sid)
            src = ("both" if b in from_body and b in from_tax
                   else "body" if b in from_body else "taxonomy")
            book_source.setdefault(sid, {})[b] = src

    # ── Focus ───────────────────────────────────────────────────────
    # ADDITIVE. `byVerse` and `bySermon` keep exactly the meaning they
    # have in the app corpus's refs.json; nothing is removed from them.
    # A chapter entry says what the sermon expounds; a book entry from
    # the taxonomy says what its publisher filed it under, and carries
    # NO chapter. `level` is mandatory on every entry precisely so the
    # UI cannot mistake a book entry for a chapter-scoped one — that is
    # the same over-broad reading that colon-less keys already get from
    # `passage_filter.dart`, and it must not be reproduced here.
    focus: dict[str, list[dict]] = {}
    for rec in records:
        sid = str(rec["id"])
        entries = [{"ref": ch, "level": "chapter", "source": "body"}
                   for ch in focus_chapters(by_sermon.get(sid, []))]
        if sid in tax_book:
            entries.append({"ref": tax_book[sid], "level": "book",
                            "source": "taxonomy"})
        if entries:
            focus[sid] = entries

    # ── Duplicates ──────────────────────────────────────────────────
    preacher = app_preacher()
    app_refs, app_titles, series_books = load_app_corpus()
    cross = cross_corpus_duplicates(records, by_sermon, app_refs,
                                    app_titles, series_books, preacher)
    identical, collisions = within_corpus_duplicates(records, by_sermon)

    # Records whose duplicate status can be neither confirmed nor
    # denied, because there is no body to fingerprint. Silence here
    # would be indistinguishable from "checked, clean".
    #
    # Scoped to the app preacher's own records, because that is the only
    # population the cross-corpus check covers at all: a body-less
    # record by one of the other 70 preachers is not an unchecked
    # duplicate candidate, it is not a candidate. The corpus-wide
    # body-less count is carried in `_meta.bodylessRecords` so the
    # narrower number here cannot be mistaken for it.
    flagged = {d["libId"] for d in cross}
    unavailable = [
        {"id": str(r["id"]), "reason": "noBody"}
        for r in records
        if r.get("author") == preacher and not r.get("hasBody")
        and str(r["id"]) not in flagged
    ]

    unresolved = sorted(
        (str(r["id"]) for r in records
         if str(r["id"]) not in by_sermon and str(r["id"]) not in tax_book),
        key=int)

    tier_counts = Counter(d["tier"] for d in cross)
    doc = {
        "_meta": {
            "generator": "scripts/index_sermon_library_refs.py",
            "grammar": "scripts/extract_sermon_refs.py (imported, "
                       "unmodified) + the 》 input normalization "
                       "documented in this script's header",
            "records": len(records),
            "withAtLeastOneBook": sum(1 for r in records
                                      if str(r["id"]) in book_source),
            "withAtLeastOneChapter": len(by_sermon),
            "withAtLeastOneVerse": sum(
                1 for keys in by_sermon.values()
                if any(":" in k for k in keys)),
            "withNothing": len(unresolved),
            "withNothingAndNoBody": sum(
                1 for r in records
                if str(r["id"]) in set(unresolved) and not r.get("hasBody")),
            "bodylessRecords": sum(1 for r in records
                                   if not r.get("hasBody")),
            "taxonomyBookRecords": len(tax_book),
            "taxonomyOnlyRecords": sum(1 for sid in tax_book
                                       if sid not in by_sermon),
            "distinctKeys": len(by_verse),
            "distinctBooks": len(by_book),
            "sermonKeyPairs": sum(len(v) for v in by_sermon.values()),
            "bareChapterKeyPairs": sum(
                1 for v in by_sermon.values() for k in v if ":" not in k),
            "focusRule": {
                "minDistinctKeys": FOCUS_MIN_KEYS,
                "minShare": FOCUS_MIN_SHARE,
                "maxChapters": FOCUS_MAX_CHAPTERS,
            },
            "duplicateRule": {
                "restrictedToPreacher": preacher,
                "titleHigh": DUP_TITLE_HIGH,
                "chapterJaccardHigh": DUP_CHAP_HIGH,
                "chapterJaccardFloor": DUP_CHAP_FLOOR,
                "minChapters": DUP_MIN_CHAPTERS,
                "seriesRiskBooks": sorted(series_books),
                "note": "Candidates only. Nothing is merged, nothing is "
                        "hidden, no record is removed.",
            },
            "duplicateTierCounts": dict(sorted(tier_counts.items())),
            "appCorpusSermons": len(app_refs),
            "libraryRecordsBySamePreacher": sum(
                1 for r in records if r.get("author") == preacher),
        },
        "byVerse": {k: sorted(set(v), key=int)
                    for k, v in sorted(by_verse.items())},
        "bySermon": by_sermon,
        "byBook": {b: sorted(set(ids), key=int)
                   for b, ids in sorted(by_book.items())},
        "bookSource": book_source,
        "focus": focus,
        "duplicates": {
            "crossCorpus": cross,
            "identicalWithinCorpus": identical,
            "titleCollisionsWithinCorpus": collisions,
            "checkUnavailable": unavailable,
        },
        "unresolved": unresolved,
    }
    return doc


def report(doc) -> None:
    m = doc["_meta"]
    n = m["records"]
    print(f"Wrote {REFS_OUT.relative_to(REPO)}  "
          f"({REFS_OUT.stat().st_size / 1024:.0f} KB)")
    print()
    print(f"  records                       {n}")
    for label, key in (("resolve to >=1 book", "withAtLeastOneBook"),
                       ("resolve to >=1 chapter", "withAtLeastOneChapter"),
                       ("resolve to >=1 verse", "withAtLeastOneVerse"),
                       ("resolve to NOTHING", "withNothing")):
        v = m[key]
        print(f"  {label:29s} {v:4d}  ({100 * v / n:.1f}%)")
    print(f"    ...of those, no body at all {m['withNothingAndNoBody']:4d}")
    print()
    print(f"  distinct scripture keys       {m['distinctKeys']}")
    print(f"  distinct books                {m['distinctBooks']}")
    print(f"  (sermon, key) pairs           {m['sermonKeyPairs']}"
          f"  ({m['bareChapterKeyPairs']} bare-chapter)")
    print(f"  sermons with a focus entry    {len(doc['focus'])}")
    print()
    print(f"  duplicate candidates          {m['duplicateTierCounts']}")
    print(f"  identical copies in corpus    "
          f"{len(doc['duplicates']['identicalWithinCorpus'])}")
    print(f"  title collisions in corpus    "
          f"{len(doc['duplicates']['titleCollisionsWithinCorpus'])}")
    print(f"  dup check unavailable         "
          f"{len(doc['duplicates']['checkUnavailable'])}")


def main() -> int:
    if not LIB_INDEX.exists():
        print(f"ERROR: {LIB_INDEX} missing — run sync_sermon_library.py "
              f"first", file=sys.stderr)
        return 1
    doc = build_document()
    REFS_OUT.write_text(
        json.dumps(doc, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8")
    report(doc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
