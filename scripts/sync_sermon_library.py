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

Usage
-----
    python3 scripts/sync_sermon_library.py              # fetch + write
    python3 scripts/sync_sermon_library.py --dry-run    # report only
    python3 scripts/sync_sermon_library.py --cache-dir /tmp/fydt
        Reuse a previous raw fetch instead of re-hitting the church's
        server. `.github/workflows/sync-songs.yml` records that this
        project once had fydt.org stop answering entirely from doubled
        traffic; re-running a transform should not cost them a crawl.
"""

import argparse
import html
import json
import os
import re
import sys
import time
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

# ── Guard floors ──────────────────────────────────────────────────
# Hand-ratcheted, exactly like the songs catalogue's floors. Raise them
# when the church legitimately publishes more; never lower them to make
# a red run go green.
#
# Measured 2026-09-05: 940 records, 841 bodied, 673 with audio.
MIN_RECORDS = 940
MIN_BODIED = 841
MIN_WITH_AUDIO = 673


# ── HTTP ──────────────────────────────────────────────────────────

def http_get(url, timeout=40, attempts=3):
    """GET as text, polite UA, retried. Returns '' on failure.

    Same contract as `sync_songs.http_get` — never raises, so one dead
    page cannot abort a 940-record crawl — but with retries, because
    this crawl makes ~30 requests and a single transient failure in the
    middle would otherwise silently shrink the result and trip a floor
    guard for the wrong reason.
    """
    req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read().decode('utf-8', errors='replace')
        except Exception as e:
            if attempt == attempts - 1:
                print(f'  warn: GET {url} failed: {e}', file=sys.stderr)
                return ''
            time.sleep(1.5 * (attempt + 1))
    return ''


def http_json(url, timeout=60):
    """GET + parse JSON. Returns None on failure."""
    raw = http_get(url, timeout=timeout)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        print(f'  warn: bad JSON from {url}: {e}', file=sys.stderr)
        return None


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

def fetch_messages(host, cache_dir=None):
    """All `message` records, ordered by id. 10 pages of 100."""
    if cache_dir:
        path = os.path.join(cache_dir, 'messages.json')
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                return json.load(f)

    root = api_root(host)
    out = []
    page = 1
    while True:
        data = http_json(f'{root}/message?per_page=100&page={page}'
                         '&orderby=id&order=asc')
        if not isinstance(data, list) or not data:
            break
        out.extend(data)
        print(f'  messages page {page}: {len(data)} (total {len(out)})')
        if len(data) < 100:
            break
        page += 1
        time.sleep(0.6)

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
        rows = http_json(f'{root}/{tax}?per_page=100'
                         '&_fields=id,name,slug,count') or []
        out[tax] = {r['id']: {'name': clean_title(r.get('name')),
                              'slug': r.get('slug'),
                              'count': r.get('count')}
                    for r in rows if isinstance(r, dict) and 'id' in r}
        print(f'  taxonomy {tax}: {len(out[tax])} terms')
        time.sleep(0.4)

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
        rows = http_json(
            f'{root}/media?per_page=100&_fields=id,source_url,mime_type'
            '&include=' + ','.join(str(x) for x in chunk)) or []
        for m in rows:
            out[m['id']] = {'url': m.get('source_url'),
                            'mime': m.get('mime_type')}
        print(f'  media batch {i // 100 + 1}: asked {len(chunk)}, '
              f'resolved {len(rows)} (total {len(out)})')
        time.sleep(0.6)

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
    """Every stored URL must live on the install's own two domains.

    A siteurl change is a structural change: it would silently rewrite
    940 stored URLs, and storing them verbatim (which is the rule here)
    means we would carry the new host without noticing.
    """
    fails = []
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


def run_guards(messages, rows, terms, existing_rows):
    return (guard_structural(messages)
            + guard_unresolved_terms(messages, terms)
            + guard_identity(rows)
            + guard_floors(rows)
            + guard_hosts(rows)
            + guard_author_collapse(rows, existing_rows))


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
    messages = fetch_messages(args.host, args.cache_dir)
    if not messages and args.host == CANONICAL_HOST:
        print(f'  {CANONICAL_HOST} returned nothing — retrying via '
              f'{FALLBACK_HOST}', file=sys.stderr)
        args.host = FALLBACK_HOST
        messages = fetch_messages(args.host, args.cache_dir)
    if not messages:
        print('ERROR: no records fetched — refusing to write.',
              file=sys.stderr)
        return 1
    print(f'  fetched {len(messages)} messages')

    terms = fetch_terms(args.host, args.cache_dir)
    media = fetch_media(args.host, collect_attachment_ids(messages),
                        args.cache_dir)
    print(f'  resolved {len(media)} attachments')

    rows, bodies = build_records(messages, terms, media)
    existing = load_existing(index_path)

    fails = run_guards(messages, rows, terms, existing)
    if fails:
        print('\nERROR: refusing to write a suspect snapshot:',
              file=sys.stderr)
        for f in fails:
            print(f'  · {f}', file=sys.stderr)
        return 1

    doc = build_document(rows, terms, args.host)
    m = doc['_meta']
    print(f"\n  total      {m['count']}")
    print(f"  bodies     {m['withBody']} (>=200 chars); "
          f"{m['withoutBody']} have none")
    print(f"  audio      {m['withAudio']}   docs {m['withTranscriptDoc']}   "
          f"video {m['withVideo']}")
    print(f"  authors    {m['authorCount']}  {m['byAuthorSource']}")

    if args.dry_run:
        print('\n(dry run — nothing written)')
        return 0

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
    return 0


if __name__ == '__main__':
    sys.exit(main())
