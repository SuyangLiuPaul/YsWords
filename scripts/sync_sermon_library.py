#!/usr/bin/env python3
"""Build `assets/sermon_library/` from the church's WordPress sermon library.

2026-09-05. The owner supplied links to fydt.org / fuyindiantai.org and
the sermon library behind them had never been imported. This script is
that import.

What this is NOT: the 289 sermons already under `assets/sermons/` are a
different corpus (one preacher, hand-proofread, three languages). This
library is 940 Chinese-language records by ~77 credited speakers,
published by the church's own site. The two are kept in separate trees
on purpose — nothing here writes to `assets/sermons/`.

The thing that made this hard
-----------------------------
`/wp-json/wp/v2/message` returns `content.rendered` EMPTY on all 940
records, because the theme renders bodies from an ACF field rather than
from post content. A first look at the rendered page HTML finds 117 KB
of markup and ~4.9 K of text that is almost entirely site navigation —
so it is easy to conclude the bodies are unreachable and then ship an
importer that harvests menus. They are reachable: the body is
`acf.transcription_displayed`, served as structured JSON by the same
REST call, and 841 of 940 carry >=200 characters of real text.

Audio is real too, and was equally invisible from `content.rendered`:
`acf.audio_recording_mp3` holds WordPress attachment IDs (not URLs) on
673 records. Those resolve through `/wp/v2/media?include=` in batches of
100 — all 1,724 attachments across audio/PDF/DOC/video resolved, none
missing. One was HEAD-checked as a 36,977,603-byte `audio/mpeg`.

Canonical host
--------------
fydt.org and fuyindiantai.org are ONE WordPress install behind two
domains (identical `x-wp-total`, identical records). `fuyindiantai.org`
is canonical: the REST root reports `home: https://fuyindiantai.org`,
and the CMS emits fuyindiantai.org in every record `link` and every
media `source_url` EVEN WHEN QUERIED VIA fydt.org. So URLs are stored
verbatim as the CMS emits them and never host-rewritten; fydt.org is
kept only as a fetch fallback.

Note `scripts/sync_songs.py` deliberately uses fydt.org and its
docstring says fuyindiantai.org's DNS is broken (SERVFAIL). That note is
stale — fuyindiantai.org resolved and answered 200 when measured on
2026-09-05. This script does not change the songs pipeline.

Shape on disk
-------------
    assets/sermon_library/index.json        metadata, one row per sermon
    assets/sermon_library/bodies/<id>.txt   body text, only where present

Bodies live outside the index for the same reason the app's other
corpus does it: a 940-row index stays diff-readable, and the app can
lazy-load a body it is about to show.

Paragraphing is the SOURCE's, never ours. Each `<p>` in the ACF field
becomes one line and nothing else is inserted or merged — the same rule
`sermon_detail_page.dart` states for the other corpus ("inserting breaks
into another man's sermon is making an expressive decision he did not
make").

Guards: symmetric, since 2026-09-06
-----------------------------------
The design intent is the songs pipeline's — REFUSE to write a suspect
snapshot rather than write a degraded one — and until 2026-09-06 that
refusal was one-sided. The floors caught SHRINKAGE; nothing caught
SUBSTITUTION, and eight degraded snapshots were written with exit 0
against the real 940-record corpus. The worst of them replaced every
body with the same navigation string: 5,440,652 characters became
555,540, 840 distinct first lines became 1, and `_meta.withBody`
reported 940 — BETTER than the true 841, because site chrome clears a
200-character bar as easily as a sermon does.

So there is now a ceiling for every floor and a distinctness rule for
every count. See the constants block below; each one carries the
measurement it came from. The shrinkage half is unchanged — it is what
has protected the songs data since August and it was not weakened to
make room for any of this.

Every guard is mutation-tested in `test/test_sermon_library.py`, and so
is the COMPOSITION: `run_guards` is built from the `GUARDS` table and
the suite proves each entry is reachable through it. Before that, any
one of the six guards could be deleted from `run_guards` and the whole
suite stayed green.

Exit codes
----------
    0   wrote (or, with --dry-run, would have written)
    2   REFUSED — a guard fired, or the endpoint changed shape.
        Nothing was written. Investigate; do not just re-run.
    3   TRANSIENT — could not reach or read the server. Nothing was
        written and there is nothing to fix; retry later.

The distinction is made at FETCH time, not by the guards, which is what
makes it trustworthy: if the crawl finished with every page 200 and
valid JSON, then a guard firing cannot be throttling.

Usage
-----
    python3 scripts/sync_sermon_library.py              # fetch + write
    python3 scripts/sync_sermon_library.py --dry-run    # report only
    python3 scripts/sync_sermon_library.py --cache-dir /tmp/fydt
        Reuse a previous raw fetch instead of re-hitting the church's
        server. `.github/workflows/sync-songs.yml` records that this
        project once had fydt.org stop answering entirely from doubled
        traffic; re-running a transform should not cost them a crawl.

Be gentle with the origin. The crawl is now finite by construction —
it reads `x-wp-total` / `x-wp-totalpages` and iterates a range — because
it used not to be: `while True` with a short-page break never terminates
against a server that ignores `?page=`, and a stand-in server that does
so drew 201 requests before a harness stopped it.
"""

import argparse
import datetime
import hashlib
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# NOTE: deliberately NOT `data/` at the repo root. `sync_songs.py`'s
# `_default_out()` switches its own output to `data/songs.json` the
# moment a `data/` directory exists here, so creating one would
# silently redirect an unrelated pipeline.
OUT_DIR = os.path.join(REPO_ROOT, 'assets', 'sermon_library')

USER_AGENT = 'YsWordsSermonSyncBot/1.0 (+https://yswords.netlify.app)'

CANONICAL_HOST = 'fuyindiantai.org'
FALLBACK_HOST = 'fydt.org'
ALLOWED_HOSTS = frozenset({CANONICAL_HOST, FALLBACK_HOST})

# The seven taxonomies attached to the `message` post type. `content_author`
# is attribution; `shujuanchakao` is the book-of-the-Bible reference;
# the rest are series/programme groupings.
TAXONOMIES = (
    'content_author',
    'zhuantixilie',
    'shujuanchakao',
    'shengjingyishenlun',
    'qimiaoendian',
    'shengmingzaisi',
    'jiangdaoxinxi',
)

TAXONOMY_LABELS = {
    'content_author': '作者',
    'zhuantixilie': '专题系列',
    'shujuanchakao': '书卷查考',
    'shengjingyishenlun': '圣经一神论',
    'qimiaoendian': '奇妙恩典',
    'shengmingzaisi': '生命再思',
    'jiangdaoxinxi': '讲道信息',
}

# `content_author` terms that name a PROGRAMME, not a person. 奇妙恩典
# ("Amazing Grace") is a broadcast strand that is also its own taxonomy;
# it is a correct source label but a false answer to "who preached this",
# so it is stored as the author and flagged as not-a-person rather than
# dropped or rewritten. Hardcoded, never heuristic — and
# `test/test_sermon_library.py` asserts every name here is still a live
# term, so the set cannot rot in silence.
PROGRAMME_AUTHORS = frozenset({'奇妙恩典'})

# ── Guard floors and ceilings ─────────────────────────────────────
# Hand-ratcheted, exactly like the songs catalogue's floors. Raise them
# when the church legitimately publishes more; never lower them to make
# a red run go green.
#
# Measured 2026-09-05: 940 records, 841 bodied, 673 with audio.
MIN_RECORDS = 940
# 856 from 2026-09-06: 841 fetched bodies plus 15 locally transcribed
# from audio. A floor is a promise that a crawl which comes back
# thinner than this is refused — so it has to move when the corpus
# genuinely grows, and it must never be compared against itself.
# `test_floor_constants_still_match_what_was_measured` is what makes
# that impossible to forget.
MIN_BODIED = 856
MIN_WITH_AUDIO = 673

# ── Why the floors alone were not enough ──────────────────────────
#
# The floors above refuse SHRINKAGE. Measured 2026-09-06, they refused
# nothing about SUBSTITUTION, and eight degraded snapshots wrote with
# exit 0 against the real 940-record corpus:
#
#   * every body replaced by one 591-char navigation string — 5,440,652
#     characters became 555,540, 840 distinct first lines became 1, and
#     `_meta.withBody` reported 940, BETTER than the true 841, because
#     the chrome string clears the 200-char bar on every record;
#   * 501 real records cloned under fresh ids to 1002 rows;
#   * every record repeated five times under fresh ids — 4,700 rows,
#     with no ceiling of any kind to stop it;
#   * every url null (the host guard's `if u and …` skipped them),
#     every title identical, every date corrupt, every audio reference
#     repointed at one file, every body cut to a uniform 200-char stub.
#
# So the constants below are the SYMMETRIC half. A shrinkage floor asks
# "did we get enough?"; these ask "is what we got still the corpus?"
# Every value is measured against the committed snapshot, and every one
# is a hand-ratcheted absolute or a ratio with real margin — never a
# threshold tuned until the current data happens to pass.
#
# Measured 2026-09-06 against assets/sermon_library/:
#   940 records · 843 bodies · 841 of them >=200 chars
#   5,440,652 body characters · 841 distinct body texts of 843 (0.9976)
#   most-shared body text: 2 records (0.0024)
#   933 distinct titles of 940 (0.9926) · 938 distinct urls (0.9979)
#   940 distinct slugs (1.0000) · 739 distinct audio urls of 739 (1.0000)
#   dates span 2014-06-18 … 2026-08-27, plus one corrupt year (see below)

# ── Ruling (Fable 5.1, 2026-09-06), followed exactly ──────────────
# The thresholds below are that ruling's, with its stated division of
# labour: hand-ratcheted ABSOLUTES for magnitudes that only legitimately
# grow (counts, characters); RATIOS for shape invariants (distinctness
# fractions), because shape does not change when the church publishes
# more, so a ratio never needs ratcheting and cannot be lazily widened;
# small absolute COUNTS for "how many times may one value repeat",
# because duplicates are human events and do not scale with the corpus.

# Ceiling, mirroring the floors. The absolute is 940 plus roughly a
# year of the church's output; the ratio is the backstop against an
# absolute somebody widened and forgot. Neither is meant to catch a
# +6.6% clone — that is the distinctness guards' job, and a ceiling
# tight enough to catch it would fire after one skipped year of syncing.
#
# Never raise MAX_RECORDS to make a red run green until `x-wp-total`
# confirms upstream really has that many. That is the inverse of the
# floor rule above and it binds just as hard.
MAX_RECORDS = 1000
MAX_GROWTH_RATIO = 1.10

# Per the ruling: nobody may quietly turn the band into a barn door.
assert MAX_RECORDS <= MIN_RECORDS * 1.15, (
    'MAX_RECORDS has been widened past 1.15x MIN_RECORDS; ratchet the '
    'floor in the same edit or the ceiling stops meaning anything')

# Body substitution. The character floor is absolute and tight —
# measured 5,440,652, so ~0.75% of slack, about six average sermons'
# worth of upstream corrections. Ratchet it to (measured − 50,000)
# rounded down to 100,000.
MIN_BODY_CHARS = 5_400_000
# Shape invariant: distinct body texts as a fraction of BODIED records
# (empty bodies are excluded, not counted as one shared value).
MIN_DISTINCT_BODY_FRACTION = 0.95
# The sensitive one, and the realistic failure it is for: a theme change
# makes the scraper return chrome for the thirty newest posts — 3.6% of
# the corpus, which the fraction above would pass. Eight identical
# transcripts is never a republish. Measured worst case today: 2.
MAX_SAME_BODY = 8

# Field distinctness — shape invariants, so fractions.
# Titles collide legitimately (series parts such as 约书亚(2)); WordPress
# permalinks and slugs do not.
MIN_DISTINCT_TITLE_FRACTION = 0.95
MIN_DISTINCT_URL_FRACTION = 0.99
MIN_DISTINCT_AUDIO_FRACTION = 0.98

# Dates. A date is sane iff it parses as YYYY-MM-DDTHH:MM:SS with a
# real month and day AND its year is in window. The window is a sanity
# bound on the YEAR, not a claim about the publishing schedule.
MIN_YEAR = 1980
# An upstream typo is a human-count event and does not scale with the
# corpus, so this is an absolute. Measured today: exactly 1 (record
# 2967, `0214-07-02T11:19:11`). Three leaves room for two more before a
# human has to look; attack #6 put all 940 out of window.
MAX_SUSPECT_DATES = 3

# Crawl bound. Derived from MAX_RECORDS, never guessed.
PER_PAGE = 100
HARD_PAGE_CAP = -(-MAX_RECORDS // PER_PAGE) + 1      # ceil(1000/100)+1 = 11

# Exit codes, per the ruling. The operator must be able to tell "fix the
# script" from "retry later" without reading the log.
EXIT_OK = 0
EXIT_REFUSED = 2        # guards fired, or the site changed shape
EXIT_TRANSIENT = 3      # we could not reach or read the server


# ── HTTP ──────────────────────────────────────────────────────────
#
# Ruling (Fable 5.1, 2026-09-06) on telling "the site changed" from "we
# were rate-limited": DECIDE IT AT FETCH TIME, NOT AT GUARD TIME.
#
#   * network error / timeout / 429 / 5xx        -> TRANSIENT
#   * 200 with a non-JSON content type, or JSON
#     that will not decode                       -> TRANSIENT (suspect:
#     a challenge or cache page, so print status, content type and the
#     first 200 characters of what came back)
#   * 200 + valid JSON of the wrong shape        -> SITE_CHANGED
#
# The crisp consequence, and the reason this is worth the machinery: if
# the crawl completed with every page 200 + valid JSON and a guard still
# fires, it is BY DEFINITION not throttling — the data or the site
# changed. So a guard failure never needs a "maybe just retry" caveat,
# and the operator is never left guessing which of the two it was.
#
# Retries are deliberately gentle and then give up on the WHOLE crawl
# rather than going on to hammer the remaining pages: the docstring
# above records that this project once had fydt.org stop answering
# entirely from doubled traffic.

TRANSIENT = 'TRANSIENT'
SITE_CHANGED = 'SITE_CHANGED'

RETRY_SLEEPS = (10, 30)     # at most two retries, per the ruling
MAX_RETRY_AFTER = 120       # never honour an absurd Retry-After


class CrawlAbort(Exception):
    """Stop the crawl. `kind` is TRANSIENT or SITE_CHANGED."""

    def __init__(self, kind, message, detail=''):
        super().__init__(message)
        self.kind = kind
        self.message = message
        self.detail = detail


def _retry_after(headers):
    try:
        return min(int(headers.get('Retry-After', '')), MAX_RETRY_AFTER)
    except (TypeError, ValueError):
        return None


def http_get(url, timeout=40):
    """GET once, with gentle retries. Returns (status, headers, text).

    Raises `CrawlAbort(TRANSIENT)` rather than returning '' when the
    server cannot be read. The old contract ("never raises, returns ''")
    is what made the unbounded crawl invisible: an unreachable server
    just produced empty pages that the loop kept asking for.
    """
    req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    last = 'unknown'
    for attempt in range(len(RETRY_SLEEPS) + 1):
        status, headers, body = None, {}, ''
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                status = r.status
                headers = dict(r.headers)
                body = r.read().decode('utf-8', errors='replace')
        except urllib.error.HTTPError as e:
            status = e.code
            headers = dict(e.headers or {})
            last = f'HTTP {status}'
        except Exception as e:                       # URLError, timeout, …
            last = f'{type(e).__name__}: {e}'

        if status == 200:
            return status, headers, body
        if status is not None and status not in (429,) and status < 500:
            raise CrawlAbort(
                SITE_CHANGED,
                f'GET {url} returned HTTP {status} — the endpoint moved or '
                f'was removed; this is not throttling.')

        if attempt < len(RETRY_SLEEPS):
            wait = _retry_after(headers) or RETRY_SLEEPS[attempt]
            print(f'  ! {last} on {url} — retrying in {wait}s '
                  f'({attempt + 1}/{len(RETRY_SLEEPS)})', file=sys.stderr)
            time.sleep(wait)

    raise CrawlAbort(
        TRANSIENT,
        f'GET {url} failed after {len(RETRY_SLEEPS) + 1} attempts '
        f'({last}) — could not reach or read the server.')


def http_json(url, timeout=60):
    """GET + parse JSON. Returns (data, headers). Raises `CrawlAbort`."""
    status, headers, raw = http_get(url, timeout=timeout)
    ctype = (headers.get('Content-Type') or '').lower()
    if 'json' not in ctype:
        raise CrawlAbort(
            TRANSIENT,
            f'GET {url} answered {status} with content type '
            f'{ctype or "(none)"}, not JSON — almost certainly a challenge '
            f'or cache page rather than the API.',
            detail=raw[:200])
    try:
        return json.loads(raw), headers
    except json.JSONDecodeError as e:
        raise CrawlAbort(
            TRANSIENT,
            f'GET {url} answered {status} with undecodable JSON: {e}',
            detail=raw[:200])


def api_root(host):
    return f'https://{host}/wp-json/wp/v2'


# ── Text helpers ──────────────────────────────────────────────────

_TAG_RE = re.compile(r'<[^>]+>')
_BLOCK_END_RE = re.compile(
    r'</p\s*>|<br\s*/?>|</div\s*>|</h[1-6]\s*>', re.IGNORECASE)


def clean_title(raw):
    """Decode entities and collapse whitespace. 7 of the 940 titles
    carry HTML entities (`&#8220;` and friends); left alone they reach
    the UI literally."""
    if not raw:
        return None
    t = html.unescape(raw)
    t = _TAG_RE.sub('', t)
    return re.sub(r'\s+', ' ', t).strip() or None


def body_text(raw_html):
    """ACF body HTML → plain text, ONE LINE PER SOURCE PARAGRAPH.

    Block ends become newlines; every other tag is dropped. Nothing is
    merged, wrapped or re-broken — the paragraph structure that comes
    out is the one the church's own editor put in. See the module
    docstring on why that rule is not negotiable here.
    """
    if not isinstance(raw_html, str) or not raw_html.strip():
        return ''
    s = raw_html.replace('\r\n', '\n')
    s = _BLOCK_END_RE.sub('\n', s)
    s = _TAG_RE.sub('', s)
    s = html.unescape(s)
    s = s.replace(' ', ' ')
    lines = [re.sub(r'[ \t]+', ' ', ln).strip() for ln in s.split('\n')]
    return '\n'.join(ln for ln in lines if ln).strip()


def _acf_ids(value, key):
    """ACF repeater → the list of attachment IDs under `key`.

    ACF hands back `None`, `False`, `''` or a list of dicts depending on
    how the field was filled in, and 44 records legitimately carry more
    than one mp3 (multi-part sermons), so this always returns a list.
    """
    out = []
    if isinstance(value, list):
        for item in value:
            if isinstance(item, dict):
                v = item.get(key)
                if isinstance(v, int) and v > 0:
                    out.append(v)
    return out


def url_host(url):
    m = re.match(r'https?://([^/]+)', url or '')
    return m.group(1).lower() if m else ''


# ── Fetch ─────────────────────────────────────────────────────────

REQUIRED_RECORD_KEYS = ('id', 'title', 'link', 'date')


def _require_shape(rows, url):
    if not isinstance(rows, list):
        raise CrawlAbort(SITE_CHANGED,
                         f'{url} returned {type(rows).__name__}, not a list '
                         f'of records — the endpoint changed shape.')
    for r in rows[:5]:
        if not isinstance(r, dict):
            raise CrawlAbort(SITE_CHANGED,
                             f'{url} returned a list of '
                             f'{type(r).__name__}, not records.')
        missing = [k for k in REQUIRED_RECORD_KEYS if k not in r]
        if missing:
            raise CrawlAbort(
                SITE_CHANGED,
                f'{url} records are missing {missing} — the `message` post '
                f'type changed shape.')


def fetch_messages(host, cache_dir=None):
    """All `message` records, ordered by id. FINITE BY CONSTRUCTION.

    The crawl used to be `while True`, breaking only when a page came
    back short or empty. If the server ignores `?page=` — an ordinary
    WordPress/caching behaviour — it answers with page 1 forever and the
    loop never terminates. Measured 2026-09-06 against a stand-in server
    that ignores `?page=`: 201 requests issued and still going, against
    a church's WordPress install this project has already knocked over
    once with doubled traffic.

    Ruling (Fable 5.1, 2026-09-06): the response HEADERS are the
    authority, and the loop is finite by construction.

      * Page 1 must carry `x-wp-total` and `x-wp-totalpages`. WordPress's
        posts controller always sends them; their absence means this is
        not the endpoint we think it is.
      * If the header total exceeds MAX_RECORDS, or the page count
        exceeds HARD_PAGE_CAP, refuse THEN — the ceiling fires on the
        header, at a cost of one request, instead of after a full crawl.
      * Iterate `for page in range(1, total_pages + 1)`, never `while
        True`, with HARD_PAGE_CAP as the belt to the header's braces.
      * `orderby=id&order=asc` so a sermon published mid-crawl is
        appended to the last page instead of shifting every offset. With
        the order stable, an id seen twice across pages can only mean
        pagination is broken — abort at that moment rather than letting
        the floors refuse later. The floors would refuse anyway, but
        aborting stops the traffic after two requests instead of eleven
        and hands the operator the right diagnosis instead of a
        misleading "short crawl" verdict.
    """
    if cache_dir:
        path = os.path.join(cache_dir, 'messages.json')
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                return json.load(f)

    root = api_root(host)

    def page_url(page):
        return (f'{root}/message?per_page={PER_PAGE}&page={page}'
                f'&orderby=id&order=asc')

    url = page_url(1)
    first, headers = http_json(url)
    _require_shape(first, url)

    lower = {k.lower(): v for k, v in headers.items()}
    try:
        total = int(lower['x-wp-total'])
        total_pages = int(lower['x-wp-totalpages'])
    except (KeyError, TypeError, ValueError):
        raise CrawlAbort(
            SITE_CHANGED,
            'the message endpoint did not send `x-wp-total` / '
            '`x-wp-totalpages`. WordPress always sends them, so this is '
            'not the REST collection we think it is — refusing to page '
            'through it blind.')

    print(f'  upstream reports x-wp-total={total} '
          f'x-wp-totalpages={total_pages}')
    if total > MAX_RECORDS:
        raise CrawlAbort(
            SITE_CHANGED,
            f'upstream reports {total} records, ceiling is {MAX_RECORDS} — '
            f'refusing after one request rather than crawling it all.')
    if total_pages > HARD_PAGE_CAP:
        raise CrawlAbort(
            SITE_CHANGED,
            f'upstream reports {total_pages} pages, cap is '
            f'{HARD_PAGE_CAP} — refusing after one request.')

    out = []
    seen = set()

    def absorb(rows, page):
        repeated = [r.get('id') for r in rows if r.get('id') in seen]
        if repeated:
            raise CrawlAbort(
                SITE_CHANGED,
                f'pagination is broken: page {page} repeated '
                f'{len(repeated)} id(s) already seen (e.g. '
                f'{repeated[:3]}). The server is ignoring `?page=`. '
                f"Check that curl '{page_url(2)}' differs from page 1.")
        seen.update(r.get('id') for r in rows)
        out.extend(rows)

    absorb(first, 1)
    print(f'  messages page 1: {len(first)} (total {len(out)})')

    for page in range(2, min(total_pages, HARD_PAGE_CAP) + 1):
        time.sleep(1.0)
        url = page_url(page)
        rows, _ = http_json(url)
        _require_shape(rows, url)
        if not rows:
            raise CrawlAbort(
                SITE_CHANGED,
                f'page {page} of {total_pages} came back empty — upstream '
                f'contradicted its own `x-wp-totalpages`.')
        absorb(rows, page)
        print(f'  messages page {page}: {len(rows)} (total {len(out)})')

    # Tolerance of 2 for a publish or a deletion landing mid-crawl.
    if abs(len(out) - total) > 2:
        raise CrawlAbort(
            SITE_CHANGED,
            f'collected {len(out)} records but `x-wp-total` said {total} — '
            f'the crawl and the server disagree by more than the '
            f'one-publish tolerance.')

    if cache_dir and out:
        os.makedirs(cache_dir, exist_ok=True)
        with open(os.path.join(cache_dir, 'messages.json'), 'w',
                  encoding='utf-8') as f:
            json.dump(out, f, ensure_ascii=False)
    return out


def fetch_terms(host, cache_dir=None):
    """{taxonomy: {term_id: {'name','slug','count'}}}"""
    if cache_dir:
        path = os.path.join(cache_dir, 'terms.json')
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                return {k: {int(i): v for i, v in d.items()}
                        for k, d in json.load(f).items()}

    root = api_root(host)
    out = {}
    for tax in TAXONOMIES:
        rows, _ = http_json(f'{root}/{tax}?per_page=100'
                            '&_fields=id,name,slug,count')
        rows = rows or []
        out[tax] = {r['id']: {'name': clean_title(r.get('name')),
                              'slug': r.get('slug'),
                              'count': r.get('count')}
                    for r in rows if isinstance(r, dict) and 'id' in r}
        print(f'  taxonomy {tax}: {len(out[tax])} terms')
        time.sleep(1.0)

    if cache_dir:
        os.makedirs(cache_dir, exist_ok=True)
        with open(os.path.join(cache_dir, 'terms.json'), 'w',
                  encoding='utf-8') as f:
            json.dump(out, f, ensure_ascii=False)
    return out


def fetch_media(host, ids, cache_dir=None):
    """{attachment_id: {'url','mime'}} for every id, 100 per request."""
    if cache_dir:
        path = os.path.join(cache_dir, 'media.json')
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                return {int(k): v for k, v in json.load(f).items()}

    root = api_root(host)
    ids = sorted(set(ids))
    out = {}
    for i in range(0, len(ids), 100):
        chunk = ids[i:i + 100]
        rows, _ = http_json(
            f'{root}/media?per_page=100&_fields=id,source_url,mime_type'
            '&include=' + ','.join(str(x) for x in chunk))
        rows = rows or []
        for m in rows:
            out[m['id']] = {'url': m.get('source_url'),
                            'mime': m.get('mime_type')}
        print(f'  media batch {i // 100 + 1}: asked {len(chunk)}, '
              f'resolved {len(rows)} (total {len(out)})')
        time.sleep(1.0)

    if cache_dir:
        os.makedirs(cache_dir, exist_ok=True)
        with open(os.path.join(cache_dir, 'media.json'), 'w',
                  encoding='utf-8') as f:
            json.dump(out, f, ensure_ascii=False)
    return out


def collect_attachment_ids(messages):
    ids = set()
    for r in messages:
        acf = r.get('acf') or {}
        ids.update(_acf_ids(acf.get('audio_recording_mp3'), 'mp3_recording'))
        ids.update(_acf_ids(acf.get('transcription_doc_pdf'),
                            'transcription_file'))
        ids.update(_acf_ids(acf.get('mobile_version_transcript'),
                            'mobile_transcript_file'))
        ids.update(_acf_ids(acf.get('video'), 'video_file'))
    return ids


# ── Transform (pure — no network, so tests can drive it) ──────────

FIELD_ORDER = (
    'id', 'refcode', 'title', 'slug', 'url', 'language',
    'date', 'modified',
    'author', 'authorSource', 'authorKind',
    'series', 'book', 'programmes',
    'audioUrls', 'transcriptDocUrls', 'mobileTranscriptUrls', 'videoUrls',
    'hasBody', 'bodyChars', 'bodyFile',
    # Annotation, never a correction — see the ruling above `date_is_sane`.
    'dateSuspect',
)

# Which taxonomy feeds which output field.
SERIES_TAX = 'zhuantixilie'
BOOK_TAX = 'shujuanchakao'
PROGRAMME_TAXES = ('shengjingyishenlun', 'qimiaoendian',
                   'shengmingzaisi', 'jiangdaoxinxi')


def resolve_author(record, terms):
    """(name, source, kind) for one record.

    Ruling (Fable 5.1, 2026-09-05), followed exactly:
      * `content_author` taxonomy is authoritative — it covers 889/940
        and carries EXACTLY ONE term, never more.
      * Where there is no term, fall back to the legacy free-text ACF
        field `author_simple`, but ONLY when it is non-blank and not
        all-digits. 12 of its 59 non-blank values are junk numerals
        ("9", "3", "10") that look like stale term ids; all 12 sit on
        records that already have a taxonomy term, so refusing to
        interpret them loses nothing (measured).
      * Otherwise `None` — never "未知", never "", never the church's
        name. Any placeholder would become a fake 78th preacher in
        every facet and credit line downstream.
    """
    term_ids = record.get('content_author') or []
    if term_ids:
        info = (terms.get('content_author') or {}).get(term_ids[0])
        name = info['name'] if info else None
        if name:
            kind = 'programme' if name in PROGRAMME_AUTHORS else 'person'
            return name, 'taxonomy', kind

    legacy = ((record.get('acf') or {}).get('author_simple') or '')
    if isinstance(legacy, str):
        legacy = legacy.strip()
        if legacy and not legacy.isdigit():
            kind = 'programme' if legacy in PROGRAMME_AUTHORS else 'person'
            return legacy, 'legacy_field', kind

    return None, 'none', None


def _term_names(record, tax, terms):
    return [n for n in
            ((terms.get(tax) or {}).get(t, {}).get('name')
             for t in (record.get(tax) or []))
            if n]


def _first(seq):
    return seq[0] if seq else None


def build_records(messages, terms, media):
    """Raw API rows → catalogue rows + {id: body_text}.

    Pure: everything it needs is passed in, so the guards and the shape
    can be tested without touching the network.
    """
    rows = []
    bodies = {}
    for r in messages:
        acf = r.get('acf') or {}
        rid = r.get('id')
        body = body_text(acf.get('transcription_displayed'))

        def urls(field, key):
            out = []
            for aid in _acf_ids(acf.get(field), key):
                info = media.get(aid)
                if info and info.get('url'):
                    out.append(info['url'])
            return out

        author, author_source, author_kind = resolve_author(r, terms)
        programmes = []
        for tax in PROGRAMME_TAXES:
            programmes.extend(_term_names(r, tax, terms))

        row = {
            'id': rid,
            'refcode': (acf.get('refcode') or '').strip() or None,
            'title': clean_title((r.get('title') or {}).get('rendered')),
            'slug': r.get('slug'),
            'url': r.get('link'),
            'language': 'zh',
            'date': r.get('date'),
            'modified': r.get('modified'),
            'author': author,
            'authorSource': author_source,
            'authorKind': author_kind,
            'series': _first(_term_names(r, SERIES_TAX, terms)),
            'book': _first(_term_names(r, BOOK_TAX, terms)),
            'programmes': programmes,
            'audioUrls': urls('audio_recording_mp3', 'mp3_recording'),
            'transcriptDocUrls': urls('transcription_doc_pdf',
                                      'transcription_file'),
            'mobileTranscriptUrls': urls('mobile_version_transcript',
                                         'mobile_transcript_file'),
            'videoUrls': urls('video', 'video_file'),
            'hasBody': bool(body),
            'bodyChars': len(body),
            'bodyFile': f'bodies/{rid}.txt' if body else None,
            'dateSuspect': not date_is_sane(r.get('date')),
        }
        rows.append({k: row.get(k) for k in FIELD_ORDER})
        if body:
            bodies[rid] = body

    rows.sort(key=lambda x: (x['id'] is None, x['id']))
    return rows, bodies


# ── Guards ────────────────────────────────────────────────────────
#
# Every guard returns a list of human-readable failures; `main` refuses
# to write if any fire. This mirrors `sync_songs.py`, whose per-source
# collapse guard has been correctly refusing to write since 2026-08-30
# because an upstream source broke — the behaviour that saved the data.
#
# Each is deliberately mutation-tested in `test/test_sermon_library.py`:
# a guard that cannot be made to fail is decorative.

def guard_structural(messages):
    """The ACF object and its body key must be present on every record.

    This is the guard that matters most, and the reason it is separate
    from the count guards: the difference between "this sermon has no
    transcript" (normal — 97 records, audio-only) and "the body field
    was renamed or removed" (a broken scrape) is exactly the difference
    between a key that is present-but-empty and a key that is GONE.
    Measured 2026-09-05: the key is present on all 940, so its absence
    is a real signal and not a tolerated quirk.
    """
    fails = []
    missing_acf = [r.get('id') for r in messages
                   if not isinstance(r.get('acf'), dict)]
    if missing_acf:
        fails.append(
            f'{len(missing_acf)} record(s) have no `acf` object '
            f'(e.g. {missing_acf[:5]}) — the ACF REST integration is off '
            f'or the field group was deleted. Refusing to write.')
    missing_key = [r.get('id') for r in messages
                   if isinstance(r.get('acf'), dict)
                   and 'transcription_displayed' not in r['acf']]
    if missing_key:
        fails.append(
            f'{len(missing_key)} record(s) lack the '
            f'`transcription_displayed` key (e.g. {missing_key[:5]}) — the '
            f'body field was renamed. Refusing to write.')
    return fails


def guard_floors(rows):
    """Total / bodied / audio counts must not fall below the measured
    floors. A partial-content outage (ACF present but rendering empty)
    cannot slip past the structural guard, so this is its backstop."""
    fails = []
    if len(rows) < MIN_RECORDS:
        fails.append(f'only {len(rows)} records, floor is {MIN_RECORDS} — '
                     f'a short crawl, not an upstream deletion. '
                     f'Refusing to write.')
    bodied = sum(1 for r in rows if r['bodyChars'] >= 200)
    if bodied < MIN_BODIED:
        fails.append(f'only {bodied} records have a >=200-char body, floor '
                     f'is {MIN_BODIED} — bodies stopped rendering. '
                     f'Refusing to write.')
    with_audio = sum(1 for r in rows if r['audioUrls'])
    if with_audio < MIN_WITH_AUDIO:
        fails.append(f'only {with_audio} records have audio, floor is '
                     f'{MIN_WITH_AUDIO} — attachment resolution failed. '
                     f'Refusing to write.')
    return fails


def guard_hosts(rows):
    """Every stored URL must live on the install's own two domains, and
    every record must actually HAVE one.

    A siteurl change is a structural change: it would silently rewrite
    940 stored URLs, and storing them verbatim (which is the rule here)
    means we would carry the new host without noticing.

    The missing-url half is the asymmetry this guard used to have. The
    host check reads `if u and url_host(u) not in ALLOWED_HOSTS`, so a
    `None` url was not on a foreign host — it was skipped. Setting all
    940 `link` fields to null therefore passed every guard and wrote
    (measured 2026-09-06). A record with no url is not a lenient case;
    it is a record nobody can open, and `url` is present on all 940.
    """
    fails = []
    missing = [r.get('id') for r in rows if not (r.get('url') or '').strip()]
    if missing:
        fails.append(
            f'{len(missing)} record(s) have no `url` '
            f'(e.g. {missing[:5]}) — `link` is present on all 940 upstream, '
            f'so a null one is a broken fetch, not a lenient case. '
            f'Refusing to write.')
    bad = []
    for r in rows:
        candidates = [r.get('url')] + list(r.get('audioUrls') or []) \
            + list(r.get('transcriptDocUrls') or []) \
            + list(r.get('mobileTranscriptUrls') or []) \
            + list(r.get('videoUrls') or [])
        for u in candidates:
            if u and url_host(u) not in ALLOWED_HOSTS:
                bad.append((r['id'], u))
    if bad:
        fails.append(
            f'{len(bad)} URL(s) on an unexpected host '
            f'(e.g. {bad[:3]}) — allowed: {sorted(ALLOWED_HOSTS)}. '
            f'Refusing to write.')
    return fails


def guard_ceiling(rows, existing_rows):
    """Symmetric partner to `guard_floors`: refuse an INFLATED crawl.

    There was no upper bound at all, so repeating every record five
    times under fresh ids produced a 4,700-row snapshot that passed
    every guard (measured 2026-09-06). Duplicate ids were already
    refused; minting new ones was free.

    Two clauses, for two different failure shapes. The absolute is the
    hand-ratcheted twin of MIN_RECORDS — raise it when the church has
    genuinely published that much. The growth ratio catches an
    inflation that stays under the absolute, and only fires when a
    previous snapshot exists to compare against.
    """
    fails = []
    if len(rows) > MAX_RECORDS:
        fails.append(
            f'{len(rows)} records, ceiling is {MAX_RECORDS} — a crawl that '
            f'grew by this much has repeated itself, not found new '
            f'sermons. Refusing to write.')
    if not existing_rows:
        return fails

    # The same ratio is applied to the bodied and audio counts, not just
    # the row count. That is what catches the chrome substitution from
    # this side: it drove `withBody` from the true 841 to 940 — a 1.118x
    # jump — because every navigation string cleared the 200-char bar.
    for label, now, was in (
            ('records', len(rows), len(existing_rows)),
            ('bodied records',
             sum(1 for r in rows if (r.get('bodyChars') or 0) >= 200),
             sum(1 for r in existing_rows
                 if (r.get('bodyChars') or 0) >= 200)),
            ('records with audio',
             sum(1 for r in rows if r.get('audioUrls')),
             sum(1 for r in existing_rows if r.get('audioUrls')))):
        if was and now > was * MAX_GROWTH_RATIO:
            fails.append(
                f'{now} {label} against {was} in the previous snapshot — '
                f'more than {MAX_GROWTH_RATIO}x growth in one sync. '
                f'Refusing to write.')
    return fails


def guard_body_substitution(rows, bodies):
    """Bodies must be a corpus of distinct transcripts, not one string.

    This is the guard the whole hardening pass exists for. Replacing
    every body with the SAME >=200-character navigation string took the
    corpus from 5,440,652 characters to 555,540 and from 840 distinct
    first lines to 1 — while `_meta.withBody` climbed from the true 841
    to 940, because site chrome clears a length bar as easily as a
    sermon does. Every count guard read it as an IMPROVEMENT.

    A length bar cannot tell a transcript from a menu. Volume and
    distinctness together can, and the module docstring already records
    why: the rendered page holds ~4.9K of text that is almost entirely
    navigation, so a harvested-chrome corpus is both far smaller than
    the real one and far more repetitive.
    """
    fails = []
    total_chars = sum(r['bodyChars'] for r in rows)
    if total_chars < MIN_BODY_CHARS:
        fails.append(
            f'only {total_chars:,} characters of body text, floor is '
            f'{MIN_BODY_CHARS:,} — the bodies are stubs or chrome, not '
            f'transcripts. Refusing to write.')

    # Hash the WHOLE body, not its first line: two transcripts that open
    # with the same greeting are not the same sermon, and a substitution
    # that varied only the first line would walk past a first-line rule.
    digests = {}
    for rid, text in bodies.items():
        if not text:
            continue          # the 97 audio-only records are legitimate
        d = hashlib.sha1(text.encode('utf-8')).hexdigest()
        digests.setdefault(d, []).append(rid)

    n_bodied = sum(len(v) for v in digests.values())
    if n_bodied:
        distinct = len(digests)
        frac = distinct / n_bodied
        if frac < MIN_DISTINCT_BODY_FRACTION:
            fails.append(
                f'only {distinct} distinct body texts across {n_bodied} '
                f'bodied records ({frac:.4f}), floor is '
                f'{MIN_DISTINCT_BODY_FRACTION} — one string has been '
                f'substituted for the transcripts. Refusing to write.')

        worst_digest, worst_ids = max(digests.items(), key=lambda kv: len(kv[1]))
        if len(worst_ids) > MAX_SAME_BODY:
            sample = bodies[worst_ids[0]].splitlines()[0][:60]
            fails.append(
                f'one identical body text is shared by {len(worst_ids)} '
                f'records (limit {MAX_SAME_BODY}; e.g. {worst_ids[:5]}), '
                f'beginning {sample!r} — that is boilerplate, not a '
                f'sermon. Refusing to write.')
    return fails


def guard_field_distinctness(rows):
    """Near-unique fields must stay near-unique.

    Measured upstream: 933 distinct titles of 940, 938 distinct urls,
    940 distinct slugs, and 739 distinct audio urls across 739 audio
    references — no audio file is shared by two records at all. So a
    little title/url duplication is real and tolerated; a collapse to
    one value is a substituted field, and all three collapses wrote
    with exit 0 before this guard existed.

    Ratios rather than absolutes on purpose: these properties are about
    the SHAPE of the corpus and must keep holding as it grows, whereas
    the count floors are claims about a particular measured size.
    """
    fails = []
    n = len(rows)
    if not n:
        return fails

    for field, floor, label in (
            ('title', MIN_DISTINCT_TITLE_FRACTION, 'titles'),
            ('url', MIN_DISTINCT_URL_FRACTION, 'urls'),
            # Slugs are not in the ruling; they are added on the same
            # principle and measured at 940/940 distinct today, so the
            # url fraction is already generous for them.
            ('slug', MIN_DISTINCT_URL_FRACTION, 'slugs')):
        distinct = len({r.get(field) for r in rows})
        frac = distinct / n
        if frac < floor:
            fails.append(
                f'only {distinct} distinct {label} across {n} records '
                f'({frac:.4f}), floor is {floor} — the field has been '
                f'substituted or the crawl repeated itself. '
                f'Refusing to write.')

    refs = [u for r in rows for u in (r.get('audioUrls') or [])]
    if refs:
        distinct = len(set(refs))
        frac = distinct / len(refs)
        if frac < MIN_DISTINCT_AUDIO_FRACTION:
            fails.append(
                f'only {distinct} distinct audio URL(s) across '
                f'{len(refs)} audio reference(s) ({frac:.4f}), floor is '
                f'{MIN_DISTINCT_AUDIO_FRACTION} — attachment resolution '
                f'collapsed onto one file. Refusing to write.')
    return fails


# ── Dates ─────────────────────────────────────────────────────────
# Ruling (Fable 5.1, 2026-09-06) on record 2967 (约书亚(2)), whose
# upstream `date` is `0214-07-02T11:19:11` — a corrupt year:
#
#   Keep the value byte-for-byte, add `dateSuspect: true`, and list the
#   record in `_meta.suspectDates`. Do NOT infer 2014. That inference
#   is exactly the silent fix this repo forbids elsewhere ("inserting
#   breaks into another man's sermon is making an expressive decision
#   he did not make"); the flag is not a fix, it is an annotation, and
#   the app's rule is that a `dateSuspect` record sorts as undated —
#   last — in date-ordered views.
#
# No allowlist is needed: `_meta.suspectDates` makes any change to the
# suspect set visible in the diff of the very next sync.

_DATE_RE = re.compile(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$')


def date_is_sane(value):
    """Strict `YYYY-MM-DDTHH:MM:SS` with a real date and an in-window year.

    `datetime.fromisoformat` is not enough on its own: it happily parses
    `0214-07-02T11:19:11`, which is precisely the record this exists for.
    """
    if not isinstance(value, str):
        return False
    m = _DATE_RE.match(value.strip())
    if not m:
        return False
    year = int(m.group(1))
    if not (MIN_YEAR <= year <= time.gmtime().tm_year + 1):
        return False
    try:
        datetime.datetime(*(int(g) for g in m.groups()))
    except ValueError:
        return False
    return True


def suspect_date_ids(rows):
    return [r['id'] for r in rows if not date_is_sane(r.get('date'))]


def guard_dates(rows):
    """A handful of upstream date typos are annotated; a wall of them is
    a broken fetch.

    Setting all 940 dates to `0000-00-00T00:00:00` passed every guard
    and wrote (measured 2026-09-06). The threshold is an absolute count
    rather than a fraction because an upstream typo is a human event
    that does not scale with the corpus: today there is exactly one, and
    attack #6 missed by a factor of 300.
    """
    suspect = suspect_date_ids(rows)
    if len(suspect) > MAX_SUSPECT_DATES:
        return [f'{len(suspect)} record(s) carry an unparseable or '
                f'out-of-window date (e.g. {suspect[:5]}), limit is '
                f'{MAX_SUSPECT_DATES} — that is a broken fetch, not a '
                f'handful of upstream typos. Refusing to write.']
    return []


def guard_identity(rows):
    """Ids must exist and be unique, and every row needs a title.

    Note `refcode` is NOT used as the key: it collides on 2 records
    (`sm06`, `Topm_04`), measured 2026-09-05. The WordPress post id is
    the only stable unique handle.
    """
    fails = []
    ids = [r.get('id') for r in rows]
    if any(i is None for i in ids):
        fails.append('some records have no id. Refusing to write.')
    dupes = sorted({i for i in ids if i is not None and ids.count(i) > 1})
    if dupes:
        fails.append(f'duplicate record ids {dupes[:5]} — the crawl '
                     f'repeated a page. Refusing to write.')
    untitled = [r.get('id') for r in rows if not r.get('title')]
    if untitled:
        fails.append(f'{len(untitled)} record(s) have no title '
                     f'(e.g. {untitled[:5]}). Refusing to write.')
    return fails


def guard_author_collapse(rows, existing_rows):
    """Per-author regression guard — the songs collapse rule, by author.

    A church does not lose 90% of one preacher's sermons overnight. If
    a previous snapshot exists and an author's count halves (or goes to
    zero at any size), that is a failed fetch, not real news.
    """
    if not existing_rows:
        return []
    before = {}
    for r in existing_rows:
        if r.get('author'):
            before[r['author']] = before.get(r['author'], 0) + 1
    after = {}
    for r in rows:
        if r.get('author'):
            after[r['author']] = after.get(r['author'], 0) + 1

    collapsed = []
    for author, was in before.items():
        now = after.get(author, 0)
        if (was >= 10 and now < was * 0.5) or (was > 0 and now == 0):
            collapsed.append(f'{author}: {was} → {now}')
    if collapsed:
        return ['an author collapsed — almost certainly a failed fetch, '
                'not an upstream deletion: ' + '; '.join(sorted(collapsed))
                + '. Refusing to write.']
    return []


def guard_unresolved_terms(messages, terms):
    """Every taxonomy term id referenced by a record must resolve.

    Without this, a truncated taxonomy fetch silently blanks the author,
    series and book of every record that used the missing terms — the
    rows still look well-formed, they are just quietly emptier.
    """
    fails = []
    for tax in TAXONOMIES:
        known = set((terms.get(tax) or {}).keys())
        used = set()
        for r in messages:
            used.update(r.get(tax) or [])
        missing = sorted(used - known)
        if missing:
            fails.append(
                f'taxonomy `{tax}` is missing {len(missing)} referenced '
                f'term(s) {missing[:5]} — the term fetch was truncated. '
                f'Refusing to write.')
    return fails


# Every guard in the pipeline, as (name, callable). `run_guards` is
# built FROM this table rather than from a hand-written sum, so the
# composition itself is inspectable: `test/test_sermon_library.py`
# walks GUARDS and proves each entry is reachable through `run_guards`
# with input that only that guard rejects. Before this existed, any
# five of the six guards could be deleted from `run_guards` and all 54
# tests stayed green (measured 2026-09-06) — the guards were tested,
# their wiring was not.
GUARDS = (
    ('structural',
     lambda ctx: guard_structural(ctx['messages'])),
    ('unresolved_terms',
     lambda ctx: guard_unresolved_terms(ctx['messages'], ctx['terms'])),
    ('identity',
     lambda ctx: guard_identity(ctx['rows'])),
    ('floors',
     lambda ctx: guard_floors(ctx['rows'])),
    ('ceiling',
     lambda ctx: guard_ceiling(ctx['rows'], ctx['existing_rows'])),
    ('hosts',
     lambda ctx: guard_hosts(ctx['rows'])),
    ('body_substitution',
     lambda ctx: guard_body_substitution(ctx['rows'], ctx['bodies'])),
    ('field_distinctness',
     lambda ctx: guard_field_distinctness(ctx['rows'])),
    ('dates',
     lambda ctx: guard_dates(ctx['rows'])),
    ('author_collapse',
     lambda ctx: guard_author_collapse(ctx['rows'], ctx['existing_rows'])),
)


def run_guards(messages, rows, bodies, terms, existing_rows):
    ctx = {'messages': messages, 'rows': rows, 'bodies': bodies,
           'terms': terms, 'existing_rows': existing_rows}
    fails = []
    for _name, fn in GUARDS:
        fails.extend(fn(ctx))
    return fails


# ── Provenance ────────────────────────────────────────────────────
# Wording per the Fable 5.1 ruling of 2026-09-05. No licence is named
# because none was granted — "authorised" is the accurate word, and the
# rights holder is the institution plus the individual speakers.

RIGHTS = '© 福音电台 及各讲员 · 经授权使用'
RIGHTS_EN = ('© FYDT 福音电台 (fuyindiantai.org) and the individual '
             'speakers · used with permission')
RIGHTS_NOTE = (
    'Sermons are the work of the speakers of the church that operates '
    'fuyindiantai.org. Use in this app was authorised by the church. '
    "Per-sermon credit is the record's `author`; where `author` is null, "
    'or `authorKind` is "programme", the credit is to 福音电台.')


def _now_iso():
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


def build_document(rows, terms, host):
    by_author = {}
    for r in rows:
        key = r['author'] or '(unattributed)'
        by_author[key] = by_author.get(key, 0) + 1
    return {
        '_meta': {
            'generatedAt': _now_iso(),
            'generator': 'scripts/sync_sermon_library.py v1',
            'source': ('FYDT 福音电台 (fuyindiantai.org), WordPress custom '
                       'post type `message`'),
            'fetchedFrom': f'https://{host}/wp-json/wp/v2/message',
            'canonicalHost': CANONICAL_HOST,
            'aliasHost': FALLBACK_HOST,
            'hostNote': (
                'fydt.org and fuyindiantai.org are one WordPress install '
                'behind two domains. fuyindiantai.org is canonical: the '
                'REST root reports it as `home`, and the CMS emits it in '
                'every record link and media source_url even when queried '
                'via fydt.org. URLs here are stored verbatim as the CMS '
                'emits them and are never host-rewritten.'),
            'rights': RIGHTS,
            'rightsEn': RIGHTS_EN,
            'rightsNote': RIGHTS_NOTE,
            'authorisedBy': None,   # owner to fill: who granted it
            'authorisedOn': None,   # owner to fill: YYYY-MM-DD
            'count': len(rows),
            'withBody': sum(1 for r in rows if r['bodyChars'] >= 200),
            'withoutBody': sum(1 for r in rows if not r['hasBody']),
            'withAudio': sum(1 for r in rows if r['audioUrls']),
            'withTranscriptDoc': sum(1 for r in rows
                                     if r['transcriptDocUrls']),
            'withVideo': sum(1 for r in rows if r['videoUrls']),
            'byAuthorSource': {
                s: sum(1 for r in rows if r['authorSource'] == s)
                for s in ('taxonomy', 'legacy_field', 'none')},
            'authorCount': len({r['author'] for r in rows if r['author']}),
            'byAuthor': dict(sorted(by_author.items(),
                                    key=lambda kv: -kv[1])),
            'taxonomies': {t: TAXONOMY_LABELS[t] for t in TAXONOMIES},
            'programmeAuthors': sorted(PROGRAMME_AUTHORS),
            # Records whose upstream `date` is unparseable or out of
            # window. Kept verbatim and annotated, never corrected — see
            # the ruling above `date_is_sane`. Listing them here is what
            # makes a change to the suspect set visible in the diff of
            # the next sync, so no allowlist is needed.
            'suspectDates': suspect_date_ids(rows),
            'suspectDateNote': (
                'These records carry an upstream `date` this script '
                'could not accept (unparseable, or a year outside '
                f'{MIN_YEAR}–present). The value is stored verbatim and '
                'flagged `dateSuspect`; nothing is inferred or repaired. '
                'Date-ordered views should sort a flagged record as '
                'undated rather than trusting the value.'),
        },
        'sermons': rows,
    }


def load_existing(index_path):
    if not os.path.exists(index_path):
        return []
    try:
        with open(index_path, encoding='utf-8') as f:
            return json.load(f).get('sermons', [])
    except (OSError, json.JSONDecodeError) as e:
        print(f'  warn: could not read {index_path}: {e}', file=sys.stderr)
        return []


# ── Main ──────────────────────────────────────────────────────────

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--dry-run', action='store_true',
                    help='report what would change, write nothing')
    ap.add_argument('--out-dir', default=OUT_DIR,
                    help=f'output directory (default: {OUT_DIR})')
    ap.add_argument('--cache-dir',
                    help='reuse/store the raw API responses here instead '
                         'of re-crawling the church server')
    ap.add_argument('--host', default=CANONICAL_HOST,
                    help=f'host to fetch from (default: {CANONICAL_HOST})')
    args = ap.parse_args(argv)

    out_dir = os.path.abspath(args.out_dir)
    index_path = os.path.join(out_dir, 'index.json')

    print(f'Syncing sermon library from {args.host}…')
    try:
        messages = fetch_messages(args.host, args.cache_dir)
        if not messages and args.host == CANONICAL_HOST:
            print(f'  {CANONICAL_HOST} returned nothing — retrying via '
                  f'{FALLBACK_HOST}', file=sys.stderr)
            args.host = FALLBACK_HOST
            messages = fetch_messages(args.host, args.cache_dir)
        print(f'  fetched {len(messages)} messages')

        terms = fetch_terms(args.host, args.cache_dir)
        media = fetch_media(args.host, collect_attachment_ids(messages),
                            args.cache_dir)
    except CrawlAbort as e:
        # The fetch layer, not the guards, decided which of these it is —
        # see the ruling above `http_get`. A TRANSIENT abort means retry
        # later and change nothing; a SITE_CHANGED abort means go and
        # look at the endpoint.
        print(f'\nERROR: {e.kind} — {e.message}', file=sys.stderr)
        if e.detail:
            print(f'  first 200 chars of the response: {e.detail!r}',
                  file=sys.stderr)
        if e.kind == TRANSIENT:
            print(f'{TRANSIENT} host={args.host} — nothing written; '
                  f'retry later, there is nothing to fix.', file=sys.stderr)
            return EXIT_TRANSIENT
        print(f'{SITE_CHANGED} host={args.host} — nothing written; '
              f'investigate the endpoint before re-running.',
              file=sys.stderr)
        return EXIT_REFUSED

    if not messages:
        print('ERROR: no records fetched — refusing to write.',
              file=sys.stderr)
        return EXIT_REFUSED
    print(f'  resolved {len(media)} attachments')

    rows, bodies = build_records(messages, terms, media)
    existing = load_existing(index_path)

    fails = run_guards(messages, rows, bodies, terms, existing)
    if fails:
        # Every page of this crawl was 200 + valid JSON, or we would not
        # be here — so this is not throttling. The data or the site
        # changed, and the operator needs no "maybe retry" caveat.
        print('\nERROR: refusing to write a suspect snapshot:',
              file=sys.stderr)
        for f in fails:
            print(f'  · {f}', file=sys.stderr)
        print(f'REFUSED guards={len(fails)} records={len(rows)} '
              f'bodied={sum(1 for r in rows if r["bodyChars"] >= 200)} '
              f'audio={sum(1 for r in rows if r["audioUrls"])} — the crawl '
              f'completed cleanly, so this is a real change upstream or a '
              f'broken transform, not throttling. Nothing written.',
              file=sys.stderr)
        return EXIT_REFUSED

    doc = build_document(rows, terms, args.host)
    m = doc['_meta']
    print(f"\n  total      {m['count']}")
    print(f"  bodies     {m['withBody']} (>=200 chars); "
          f"{m['withoutBody']} have none")
    print(f"  audio      {m['withAudio']}   docs {m['withTranscriptDoc']}   "
          f"video {m['withVideo']}")
    print(f"  authors    {m['authorCount']}  {m['byAuthorSource']}")
    if m['suspectDates']:
        print(f"  ! {len(m['suspectDates'])} record(s) carry a date this "
              f"script will not vouch for: {m['suspectDates']}")
        print(f"    stored verbatim and flagged `dateSuspect`; nothing "
              f"inferred (limit {MAX_SUSPECT_DATES})")

    if args.dry_run:
        print('\n(dry run — nothing written)')
        return EXIT_OK

    bodies_dir = os.path.join(out_dir, 'bodies')
    os.makedirs(bodies_dir, exist_ok=True)
    for rid, text in bodies.items():
        with open(os.path.join(bodies_dir, f'{rid}.txt'), 'w',
                  encoding='utf-8') as f:
            f.write(text + '\n')
    # Drop bodies for records that lost theirs upstream.
    keep = {f'{rid}.txt' for rid in bodies}
    for name in os.listdir(bodies_dir):
        if name.endswith('.txt') and name not in keep:
            os.remove(os.path.join(bodies_dir, name))

    with open(index_path, 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write('\n')

    print(f'\n✓ wrote {index_path} '
          f'({os.path.getsize(index_path):,} bytes)')
    print(f'✓ wrote {len(bodies)} body files to {bodies_dir}')
    return EXIT_OK


if __name__ == '__main__':
    sys.exit(main())
