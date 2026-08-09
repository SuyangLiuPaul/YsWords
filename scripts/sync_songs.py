#!/usr/bin/env python3
"""Rebuild `assets/songs.json` from the three church song catalogues.

2026-08-09 (v2 — API rewrite). The original version of this script
scraped fydt.org's WordPress *sitemap* and then re-parsed every song
page's HTML. That broke when fydt.org migrated its backend in 2025
(the APK changelog calls it "福音电台后台迁移改造"), which is why the
whole Songs feature was pulled in v1.3.126 with "the song links were
reported broken".

fydt.org now publishes a real JSON API — `fydt-api/v1` — so this
rewrite reads structured data instead of guessing at markup. It also
picks up two things the old scrape never had: the *media* set
(instrumental / accompaniment tracks, MV video, artwork, sheet music)
and the Indonesian sister site.

Sources
-------
  fydt    https://fydt.org                 — 福音电台, Chinese (213)
          `fydt-api/v1/songs/json/listSongsBySearchKey` enumerated over
          pinyin A–Z gives resolved media URLs; `wp/v2/song` supplies
          the taxonomy + Bible reference the custom API omits. A
          handful of legacy entries carry no pinyin term, so the
          canonical `wp/v2/song` list is diffed in as a backstop.

  cahaya  https://cahayapengharapan.org    — Indonesian
          Two hand-built pages (`/pujian/` audio, `/pujian/video-pujian/`
          video) in a rigid `<p><b>title</b><br><iframe…>` shape. No
          API — WordPress holds these as page bodies, not posts — so
          this stays a parse, but a narrow and well-anchored one.

  cdc     https://www.christiandiscipleschurch.org — English + Chinese
          Drupal 7, no API of any kind. The integrated-list-songs view
          gives (title, code) rows; each song's own page is then read
          for its real media links. An earlier version DERIVED those
          from the catalogue code and got it badly wrong — see
          [fetch_cdc] for what that cost.

  fuyindiantai.org is deliberately NOT fetched. It is fydt.org's old
  domain (it 301'd to fydt.org through 2025) and its DNS delegation is
  currently broken — both Google and Cloudflare return SERVFAIL because
  it still points at ns1/ns2.fydt.org, which stopped serving the zone
  when fydt.org moved to DigiCert DNS. Its songs ARE the fydt songs;
  see `_FUYINDIANTAI_NOTE` and the `_meta.sources` block we emit.

Usage
-----
    python3 scripts/sync_songs.py            # rewrite assets/songs.json
    python3 scripts/sync_songs.py --dry-run  # report, write nothing
"""

import argparse
import html
import json
import os
import re
import string
import sys
import time
import urllib.parse
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _default_out():
    """Where the catalogue lands, picked from the repo layout.

    The same script runs in two repos: here in yswords-data, where the
    catalogue is a published dataset under `data/`, and in the YsWords
    app repo, where it is a bundled Flutter asset under `assets/`.
    Rather than fork the script, detect which tree we are in — and let
    `--out` / `$SONGS_OUT` override either way.
    """
    override = os.environ.get('SONGS_OUT')
    if override:
        return os.path.abspath(override)
    if os.path.isdir(os.path.join(REPO_ROOT, 'data')):
        return os.path.join(REPO_ROOT, 'data', 'songs.json')
    return os.path.join(REPO_ROOT, 'assets', 'songs.json')


SONGS_JSON = _default_out()

USER_AGENT = 'YsWordsSongsSyncBot/2.0 (+https://yswords.netlify.app)'

# ── Source registry ───────────────────────────────────────────────
# `label` is what the UI shows on the source chip; `home` is the
# attribution link on the About page.
SOURCES = {
    'fydt': {
        'label': '福音电台 FYDT',
        'home': 'https://fydt.org',
        'language': 'zh',
    },
    'cahaya': {
        'label': 'Cahaya Pengharapan',
        'home': 'https://cahayapengharapan.org',
        'language': 'id',
    },
    'cdc': {
        'label': 'Christian Disciples Church',
        'home': 'https://www.christiandiscipleschurch.org',
        'language': 'en',
    },
}

_FUYINDIANTAI_NOTE = (
    'fuyindiantai.org is fydt.org under its former domain (it 301-redirected '
    'to fydt.org through 2025). Its DNS delegation is currently broken '
    '(SERVFAIL — the NS records still point at ns1/ns2.fydt.org, which no '
    'longer serve the zone), so it is not fetched. Every song it published '
    'is already in this catalogue under source "fydt".'
)

FYDT_API = 'https://fydt.org/wp-json/fydt-api/v1'
FYDT_WP = 'https://fydt.org/wp-json/wp/v2'
CAHAYA_AUDIO = 'https://cahayapengharapan.org/pujian/'
CAHAYA_VIDEO = 'https://cahayapengharapan.org/pujian/video-pujian/'
CDC_ROOT = 'https://www.christiandiscipleschurch.org'
CDC_INDEX = f'{CDC_ROOT}/content/integrated-list-songs'

# ── Theme classifier ──────────────────────────────────────────────
# Applied to titles when the source publishes no taxonomy of its own
# (cdc, cahaya). fydt songs get their real `song_category` terms and
# skip this entirely.
THEME_KEYWORDS = [
    ('敬拜', ['敬拜', '尊崇', '颂赞', 'Worship', 'Adore', 'Praise', 'Bless', 'Extol', 'Memuja', 'Menyembah', 'Penyembahan']),
    ('赞美', ['赞美', '颂', '高举', 'Praise', 'Magnif', 'Glory', 'Lifted', '荣耀', '荣美', 'Puji', 'Mulia']),
    ('救恩', ['救', '拯救', 'Salvation', 'Saved', 'Ransomed', 'Redeem', 'Rescue', 'Selamat', 'Keselamatan']),
    ('圣灵', ['灵', '圣灵', 'Spirit', 'Empowered', '圣火', '风随意', 'Roh']),
    ('委身', ['委身', '献', '为你', '凡事', 'Commit', 'Devote', 'Consecrate', 'Allegiance', 'Wholly', 'Komitmen']),
    ('顺服', ['顺服', '跟从', '跟随', '遵', '行你旨意', 'Follow', 'Obey', 'Imitate', 'Submit', 'Taat', 'Kehendak']),
    ('得胜', ['得胜', '胜', '奔', '战', 'Overcome', 'Race', 'Run', 'Fight', 'Strong', 'Bold', 'Menang', 'Kuasa', 'Kekuatan']),
    ('重生', ['重生', '复活', '新', '活', 'Resurrection', 'Reborn', 'Renew', 'New', 'Living', 'Alive', 'Hidup', 'Baru']),
    ('圣洁', ['圣洁', '洁净', '圣', '完全', 'Holy', 'Clean', 'Pure', 'Holiness', 'Perfect', 'Kudus']),
    ('平安', ['平安', '安息', '安静', '宁', 'Peace', 'Rest', 'Still', 'Quiet', 'Damai', 'Tenang']),
    ('感恩', ['感恩', '感谢', '称谢', 'Thank', 'Gratitude', 'Syukur', 'Bersyukur']),
    ('警醒', ['警醒', '儆醒', '醒', '警觉', 'Watch', 'Alert', 'Wake', 'Berjaga']),
    ('信心', ['信心', '信靠', '信', 'Faith', 'Trust', 'Believe', 'Iman', 'Percaya']),
    ('爱', ['爱', 'Love', 'Beloved', 'Kasih', 'Mengasihi']),
    ('仰望', ['仰望', '盼望', '盼', '指望', 'Hope', 'Wait', 'Harap', 'Pengharapan']),
    ('门徒', ['门徒', '弟子', '使徒', 'Disciple', 'Apostle', 'Mission', 'Murid']),
    ('祷告', ['祷告', '祈祷', '求', 'Prayer', 'Pray', 'Mercy', 'Doa']),
    ('真理', ['真理', '真', '智慧', 'Truth', 'Wisdom', 'Word', '话语', '话', 'Kebenaran', 'Hikmat', 'Firman']),
    ('心', ['心', 'Heart', 'Mind', 'Hati']),
    ('神的名', ['雅伟', 'YHWH', 'Yahweh', 'LORD', 'Adonai', '神的名', 'Allah']),
    ('教会', ['教会', '同心', '合一', '联合', 'Church', 'Together', 'United', 'One Heart', 'Bond', '一致', '合意', 'Rukun', 'Gereja']),
    ('见证', ['见证', '传扬', '宣', '使万民', '万民', 'Declare', 'Proclaim', 'Witness', 'Testimony', 'Injil', 'Saksi']),
    ('生命', ['生命', '复生', '生', 'Life', 'Kehidupan']),
    ('诗篇', ['诗篇', 'Psalm', 'Mazmur']),
    ('儿童', ['孩', '童', '小', 'Child', 'Children', 'Anak']),
]

VERSE_RE_ZH = re.compile(r'诗篇\s*(\d+)')
VERSE_RE_EN = re.compile(r'Psalm\s*(\d+)', re.IGNORECASE)

# fydt's ACF `bible_reference` repeater already uses English book
# names ("Colossians", "2Corinthians") — just needs a space inserted
# after a leading numeral.
_NUMBERED_BOOK_RE = re.compile(r'^([123])([A-Z][a-z]+)$')

CDC_ROW_RE = re.compile(
    # Two-cell pattern on the integrated-list-songs view:
    #   <td …views-field-field-song-title…> <title> </td>
    #   <td …views-field-title…> <a href="/content/<code>">CODE</a>
    r'<td[^>]*views-field-field-song-title[^>]*>'
    r'\s*([^<]+?)\s*</td>'
    r'\s*<td[^>]*views-field-title[^>]*>'
    r'\s*<a[^>]+href="(/content/([defDEF]\d{3,5}))"',
    flags=re.IGNORECASE | re.DOTALL,
)

# Both Cahaya pages wrap one song per <p>: a bolded title, then the
# embed, then (audio page only) a "Download lembar lagu" sheet link.
CAHAYA_BLOCK_RE = re.compile(r'<p[^>]*>(.*?)</p>', re.IGNORECASE | re.DOTALL)
CAHAYA_TITLE_RE = re.compile(r'<b[^>]*>(.*?)</b>|<strong[^>]*>(.*?)</strong>',
                             re.IGNORECASE | re.DOTALL)
SOUNDCLOUD_RE = re.compile(r'api\.soundcloud\.com/tracks/(\d+)')
YOUTUBE_RE = re.compile(
    r'(?:youtube\.com/(?:embed/|watch\?v=)|youtu\.be/)([A-Za-z0-9_-]{11})')
CAHAYA_PDF_RE = re.compile(r'href="([^"]+\.pdf)"', re.IGNORECASE)

_BAD_TITLE_RE = re.compile(
    r'^[DEF]\d{3,5}$|&#\d+;|&amp;|&quot;|&#x[0-9a-f]+;', re.IGNORECASE)


# ── HTTP ──────────────────────────────────────────────────────────

def http_get(url, timeout=30):
    """GET as text, polite UA. Returns '' on failure (never raises —
    a single dead page must not abort a 500-song sync)."""
    req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read().decode('utf-8', errors='replace')
    except Exception as e:
        print(f'  warn: GET {url} failed: {e}', file=sys.stderr)
        return ''


def http_json(url, timeout=40):
    """GET + parse JSON. Returns None on failure."""
    raw = http_get(url, timeout=timeout)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        print(f'  warn: bad JSON from {url}: {e}', file=sys.stderr)
        return None


# ── Helpers ───────────────────────────────────────────────────────

def clean_title(raw):
    """Decode entities, collapse whitespace, strip the fydt site
    suffix that creeps in via <title> tags."""
    if not raw:
        return None
    t = html.unescape(raw).strip()
    t = re.sub(r'\s*[\-–—|]\s*FYDT.*$', '', t, flags=re.IGNORECASE).strip()
    t = re.sub(r'\s*[\-–—|]\s*福音电台.*$', '', t).strip()
    t = re.sub(r'<[^>]+>', '', t)
    return re.sub(r'\s+', ' ', t).strip() or None


def detect_language(title, default='en'):
    """zh / id / en from a title. The catalogue is bilingual at the
    title level (whole title in one language), never paragraph-mixed,
    so a CJK sniff is enough to separate zh; everything else keeps
    the source's declared default."""
    if any('一' <= c <= '鿿' for c in title):
        return 'zh'
    return default


def infer_themes(title):
    out = set()
    for theme, keywords in THEME_KEYWORDS:
        for kw in keywords:
            if kw.lower() in title.lower():
                out.add(theme)
                break
    return sorted(out)


def infer_verse(title):
    m = VERSE_RE_ZH.search(title) or VERSE_RE_EN.search(title)
    if m:
        return f'Psalms {m.group(1)}'
    if 'Shema' in title:
        return 'Deuteronomy 6:4'
    if 'Our Father' in title or '主祷文' in title:
        return 'Matthew 6:9-13'
    return None


def normalise_book(name):
    """'2Corinthians' → '2 Corinthians'. fydt already stores English
    book names; they just lack the space after a leading numeral."""
    if not name:
        return None
    m = _NUMBERED_BOOK_RE.match(name.strip())
    return f'{m.group(1)} {m.group(2)}' if m else name.strip()


def format_verse(refs):
    """Render fydt's `bible_reference` repeater as 'Colossians 1:9-11'.
    Only the first citation is kept — the app's book-filter chip is
    single-valued and a two-book string would match neither."""
    if not isinstance(refs, list) or not refs:
        return None
    r = refs[0]
    if not isinstance(r, dict):
        return None
    book = normalise_book(r.get('books'))
    if not book:
        return None
    chapter = str(r.get('chaptertyped') or '').strip()
    verses = str(r.get('verses') or '').strip()
    if chapter and verses:
        return f'{book} {chapter}:{verses}'
    if chapter:
        return f'{book} {chapter}'
    return book


def duration_to_seconds(value):
    """fydt's custom API returns integer seconds; the ACF field is a
    'm:ss' string. Accept either."""
    if isinstance(value, (int, float)) and value > 0:
        return int(value)
    if isinstance(value, str) and ':' in value:
        parts = value.strip().split(':')
        try:
            nums = [int(p) for p in parts]
        except ValueError:
            return None
        secs = 0
        for n in nums:
            secs = secs * 60 + n
        return secs or None
    return None


def strip_lyrics(raw):
    """fydt ships lyrics either as plain text with \\r\\n (custom API)
    or as span-wrapped HTML (`body_lyrics_display`). Normalise both to
    plain text with \\n breaks."""
    if not raw:
        return None
    t = re.sub(r'(?is)<(script|style).*?</\1>', '', raw)
    t = re.sub(r'(?i)<br\s*/?>|</p>|</div>|</span>\s*\r?\n', '\n', t)
    t = re.sub(r'<[^>]+>', '', t)
    t = html.unescape(t).replace('\r\n', '\n').replace('\r', '\n')
    t = re.sub(r'[ \t]+', ' ', t)
    t = re.sub(r'\n{3,}', '\n\n', t)
    return t.strip() or None


def first_url(items, *keys):
    """Pull the first non-empty URL out of one of fydt's repeater
    groups, e.g. `songFiles: [{songId, songUrl}]`."""
    if not isinstance(items, list):
        return None
    for it in items:
        if isinstance(it, str) and it.strip():
            return it.strip()
        if isinstance(it, dict):
            for k in keys:
                v = it.get(k)
                if isinstance(v, str) and v.strip():
                    return v.strip()
    return None


def _is_bad_title(t):
    """Titles that should be replaced by a fresh fetch: entity-laden,
    site-suffix-padded, or a bare catalogue code."""
    if not t:
        return True
    if _BAD_TITLE_RE.search(t):
        return True
    return 'FYDT' in t.upper() or '福音电台' in t


def _now_iso():
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


# Canonical key order for every catalogue row. Enforced on write so
# entries carried over from the pre-v2 schema line up with fresh ones
# and `git diff` on songs.json stays readable.
FIELD_ORDER = (
    'id', 'title', 'language', 'source', 'sourceLabel', 'code', 'url',
    'artist', 'composer', 'lyricist', 'durationSec',
    'audioUrl', 'instrumentalUrl', 'accompanimentUrl', 'audioTracks',
    'videoUrl', 'youtubeId', 'soundcloudTrackId',
    'scoreUrl', 'artworkUrl', 'lyrics',
    'themes', 'verse', 'firstSeenAt', 'updatedAt',
)

# Fields whose empty value is a list, not None.
LIST_FIELDS = ('themes', 'audioTracks')

# Pre-v2 field names, mapped to where they live now. `pdfUrl` became
# `scoreUrl` when Cahaya joined — its PDFs are sheet music ("lembar
# lagu"), not the generic attachment the old name implied.
LEGACY_FIELDS = {'pdfUrl': 'scoreUrl'}


def make_entry(source, slug, title, url, **extra):
    """Build one catalogue row with every media field present (None
    when absent) so the Dart decoder never has to branch on shape."""
    src = SOURCES[source]
    entry = {k: None for k in FIELD_ORDER}
    entry.update({
        'id': f'{source}:{slug}',
        'title': title,
        'language': extra.pop('language', None) or src['language'],
        'source': source,
        'sourceLabel': src['label'],
        'code': extra.pop('code', None),
        'url': url,
    })
    for k in LIST_FIELDS:
        entry[k] = []
    entry.update({k: v for k, v in extra.items() if k in entry})
    return entry


def normalise(entry):
    """Fold pre-v2 field names into their current homes and re-emit in
    canonical order, dropping anything the schema no longer carries."""
    row = dict(entry)
    for old, new in LEGACY_FIELDS.items():
        value = row.pop(old, None)
        if value and not row.get(new):
            row[new] = value
    return {k: (row.get(k) or []) if k in LIST_FIELDS else row.get(k)
            for k in FIELD_ORDER}


# ── fydt.org ──────────────────────────────────────────────────────

def fetch_fydt_taxonomy():
    """song_category term id → Chinese name."""
    terms = http_json(
        f'{FYDT_WP}/song_category?per_page=100&_fields=id,name') or []
    return {t['id']: t['name'] for t in terms if t.get('id')}


def fetch_fydt_wp_index():
    """Canonical `wp/v2/song` list keyed by post id. Supplies the
    taxonomy terms and Bible reference the custom API omits, and acts
    as the completeness backstop for the pinyin enumeration."""
    index = {}
    for page in range(1, 8):  # 213 songs today; cap well clear of it
        url = (f'{FYDT_WP}/song?per_page=100&page={page}'
               '&_fields=id,title,link,acf,song_category')
        rows = http_json(url)
        if not rows:
            break
        for p in rows:
            index[p['id']] = p
        if len(rows) < 100:
            break
    return index


def fetch_fydt(taxonomy, wp_index):
    """Enumerate the custom API over pinyin A–Z (that is the only
    listing endpoint it exposes), then diff against `wp/v2/song` and
    build the stragglers — legacy entries with no pinyin term — from
    WordPress alone."""
    by_post_id = {}

    for letter in string.ascii_uppercase:
        payload = http_json(
            f'{FYDT_API}/songs/json/listSongsBySearchKey'
            f'?search_type=pinyin&search_key={letter}')
        for s in (payload or {}).get('data') or []:
            if isinstance(s, dict) and s.get('id') is not None:
                by_post_id[s['id']] = s
        time.sleep(0.15)  # be a good neighbour on the church's box

    print(f'  fydt: {len(by_post_id)} via pinyin A-Z, '
          f'{len(wp_index)} in wp/v2 index')

    entries = []
    for post_id, wp in sorted(wp_index.items()):
        api = by_post_id.get(post_id) or {}
        acf = wp.get('acf') or {}

        title = (clean_title(api.get('title'))
                 or clean_title(acf.get('title'))
                 or clean_title((wp.get('title') or {}).get('rendered')))
        if not title:
            continue

        themes = [taxonomy[t] for t in (wp.get('song_category') or [])
                  if t in taxonomy]

        entries.append(make_entry(
            'fydt', str(post_id), title,
            api.get('webSiteUrl') or wp.get('link'),
            code=acf.get('song_id_number') or None,
            artist=api.get('artist') or None,
            composer=api.get('composer') or None,
            lyricist=api.get('lyricist') or None,
            durationSec=(duration_to_seconds(api.get('duration'))
                         or duration_to_seconds(
                             acf.get('time_length_of_song'))),
            audioUrl=first_url(api.get('songFiles'), 'songUrl'),
            instrumentalUrl=first_url(api.get('songInstrumentalFiles'),
                                      'songUrl'),
            accompanimentUrl=first_url(api.get('songAccompanyFiles'),
                                       'songUrl'),
            # Same uniform track list CDC now produces, so a consumer
            # can render every mix from one field regardless of source.
            audioTracks=build_tracks([
                (first_url(api.get('songFiles'), 'songUrl'), 'vocal', None),
                (first_url(api.get('songInstrumentalFiles'), 'songUrl'),
                 'instrumental', None),
                (first_url(api.get('songAccompanyFiles'), 'songUrl'),
                 'accompaniment', None),
            ]),
            videoUrl=first_url(api.get('mvUrls'), 'url'),
            scoreUrl=first_url(api.get('scoresUrl'), 'url'),
            artworkUrl=api.get('artworkUrl') or None,
            lyrics=(strip_lyrics(api.get('lyrics'))
                    or strip_lyrics(acf.get('body_lyrics_display'))),
            themes=themes or infer_themes(title),
            verse=(format_verse(acf.get('bible_reference'))
                   or infer_verse(title)),
        ))
    return entries


# ── cahayapengharapan.org ─────────────────────────────────────────

def _cahaya_blocks(page_html, base_url):
    """Yield (title, block_html) for each <p> that holds one song."""
    for m in CAHAYA_BLOCK_RE.finditer(page_html):
        block = m.group(1)
        tm = CAHAYA_TITLE_RE.search(block)
        if not tm:
            continue
        title = clean_title(tm.group(1) or tm.group(2))
        if not title or len(title) > 120:
            continue
        yield title, block, base_url


def _cahaya_slug(title):
    slug = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
    return slug or 'song'


def fetch_cahaya():
    """Merge the audio page (SoundCloud + sheet music) with the video
    page (YouTube) on normalised title, so a song published in both
    places lands as ONE entry carrying both."""
    by_key = {}

    audio_html = http_get(CAHAYA_AUDIO)
    for title, block, base in _cahaya_blocks(audio_html, CAHAYA_AUDIO):
        sc = SOUNDCLOUD_RE.search(block)
        pdf = CAHAYA_PDF_RE.search(block)
        if not sc and not pdf:
            continue
        key = title.casefold()
        entry = make_entry(
            'cahaya', _cahaya_slug(title), title, CAHAYA_AUDIO,
            soundcloudTrackId=sc.group(1) if sc else None,
            scoreUrl=(urllib.parse.urljoin(base, html.unescape(pdf.group(1)))
                      if pdf else None),
            themes=infer_themes(title),
            verse=infer_verse(title),
        )
        by_key[key] = entry

    video_html = http_get(CAHAYA_VIDEO)
    for title, block, _ in _cahaya_blocks(video_html, CAHAYA_VIDEO):
        yt = YOUTUBE_RE.search(block)
        if not yt:
            continue
        key = title.casefold()
        if key in by_key:
            by_key[key]['youtubeId'] = yt.group(1)
            continue
        by_key[key] = make_entry(
            'cahaya', _cahaya_slug(title), title, CAHAYA_VIDEO,
            youtubeId=yt.group(1),
            themes=infer_themes(title),
            verse=infer_verse(title),
        )

    entries = list(by_key.values())
    audio_n = sum(1 for e in entries if e['soundcloudTrackId'])
    video_n = sum(1 for e in entries if e['youtubeId'])
    print(f'  cahaya: {len(entries)} songs '
          f'({audio_n} audio, {video_n} video)')
    return entries


# ── christiandiscipleschurch.org ──────────────────────────────────

# CDC's filename suffixes, learned by reading the published pages:
#   D0180.mp3           the sung track
#   D0375_English.mp3   \ bilingual songs publish one per language and
#   D0375_Chinese.mp3   / usually have no bare-code file at all
#   D0180i.mp3          instrumental  (same 'i' convention fydt uses)
#   D0415m.mp3          minus-one / accompaniment
#   D0180_melody.mp3    melody-only guide track
#   E0440R.mp3          a revised re-recording; still the sung take
_CDC_SUFFIXES = [
    ('_english', 'vocal', 'en'),
    ('_chinese', 'vocal', 'zh'),
    ('melody', 'instrumental', None),
    ('_melody', 'instrumental', None),
    ('i', 'instrumental', None),
    ('m', 'accompaniment', None),
    ('r', 'vocal', None),
    ('', 'vocal', None),
]

_MP3_RE = re.compile(r'["\'(]([^"\'()\s\\]+\.mp3)["\')]', re.IGNORECASE)
_PDF_RE = re.compile(r'["\'(]([^"\'()\s\\]+\.pdf)["\')]', re.IGNORECASE)


#: Suffixes seen in the wild that were not in the original list —
#: recorded so the sync can report them rather than silently guess.
UNKNOWN_CDC_SUFFIXES = set()


def classify_cdc_track(filename, code):
    """('vocal'|'instrumental'|'accompaniment', lang|None) for a CDC
    mp3 filename, or None when it does not belong to `code`.

    Deliberately PERMISSIVE about suffixes it does not recognise. The
    first version of this only accepted a fixed list and returned None
    otherwise — so `E0440R.mp3` was dropped and that song showed up as
    having no audio at all, which is how this whole class of bug got
    reported in the first place. Anything whose stem starts with the
    catalogue code is that song's audio; an unrecognised suffix is
    treated as another vocal take and recorded in
    [UNKNOWN_CDC_SUFFIXES] so a new convention surfaces in the sync log
    instead of quietly costing us a track.
    """
    stem = filename[:-4] if filename.lower().endswith('.mp3') else filename
    # Drupal appends _0, _1… when a file is re-uploaded; same track.
    stem = re.sub(r'_\d+$', '', stem)
    if not stem.upper().startswith(code.upper()):
        return None
    suffix = stem[len(code):].lower()
    for candidate, kind, lang in _CDC_SUFFIXES:
        if suffix == candidate:
            return kind, lang
    UNKNOWN_CDC_SUFFIXES.add(suffix)
    return 'vocal', None


def parse_cdc_media(page_html, code):
    """Pull the real media links out of one CDC song page."""
    if not page_html:
        return {'tracks': [], 'score': None}

    # Keyed on the normalised filename stem, NOT on (kind, lang):
    # since unrecognised suffixes all classify as plain vocal, keying
    # on the classification would make `D0180.mp3` and `D0180R.mp3`
    # collide and silently drop one. Each page lists every file twice
    # (player markup + download link) and `_0` re-uploads normalise
    # onto the same stem, so this still dedupes what should dedupe.
    tracks = {}
    for raw in _MP3_RE.findall(page_html):
        name = raw.rsplit('/', 1)[-1]
        classified = classify_cdc_track(name, code)
        if not classified:
            continue
        kind, lang = classified
        stem = re.sub(r'_\d+$', '', name[:-4]).lower()
        url = urllib.parse.urljoin(CDC_ROOT, raw.replace('\\/', '/'))
        tracks.setdefault(stem, {'url': url, 'kind': kind, 'lang': lang})

    score = None
    for raw in _PDF_RE.findall(page_html):
        name = raw.rsplit('/', 1)[-1]
        if name.upper().startswith(code.upper()):
            score = urllib.parse.urljoin(CDC_ROOT, raw.replace('\\/', '/'))
            break

    # Sung takes first (language-tagged before the bare one), then the
    # instrumental, then the minus-one — the order the detail sheet
    # shows them in.
    def rank(t):
        kind_rank = {'vocal': 0, 'instrumental': 1, 'accompaniment': 2}
        return (kind_rank.get(t['kind'], 3), t['lang'] is None, t['url'])

    return {'tracks': sorted(tracks.values(), key=rank), 'score': score}


def build_tracks(candidates):
    """[(url, kind, lang), …] → the audioTracks list, dropping empties."""
    return [{'url': url, 'kind': kind, 'lang': lang}
            for url, kind, lang in candidates if url]


def _track_url(tracks, kind):
    for t in tracks or []:
        if t['kind'] == kind:
            return t['url']
    return None


def pick_primary_audio(tracks, language):
    """Which track the play button uses.

    Prefer a vocal take in the song's own language — a title listed in
    English should not start playing in Chinese — then any vocal, then
    nothing. Instrumentals are never primary: someone tapping play on a
    song expects to hear it sung.
    """
    vocals = [t for t in (tracks or []) if t['kind'] == 'vocal']
    if not vocals:
        return None
    for t in vocals:
        if t['lang'] == language:
            return t['url']
    for t in vocals:
        if t['lang'] is None:
            return t['url']
    return vocals[0]['url']


def head_ok(url, timeout=25, attempts=2):
    """True when a HEAD on `url` returns 200.

    Retries once on a non-HTTP failure: a pruned URL is *removed* from
    the catalogue, so a dropped connection must not be able to delete
    a perfectly good link. A real 404 is definitive and not retried.
    """
    req = urllib.request.Request(
        url, method='HEAD', headers={'User-Agent': USER_AGENT})
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.status == 200
        except urllib.error.HTTPError:
            return False  # upstream answered; the file really is gone
        except Exception:
            if attempt == attempts - 1:
                return False
            time.sleep(1.0)
    return False


def prune_derived_urls(entries, workers=4):
    """Null out CDC media URLs that 404.

    Unlike fydt and Cahaya — where every URL is one the site itself
    published, and which verify 100% clean — CDC's are *derived* from
    the catalogue code (`D0180` → `.../mp3/D0180.mp3`). The pattern is
    right for the great majority, but ~23 of ~566 files were never
    uploaded, so the guess 404s.

    A play button that 404s is precisely the failure that got the
    Songs feature deleted in v1.3.126, so the guesses are checked here
    and dropped rather than shipped on a hope.
    """
    import concurrent.futures

    targets = [(e, f) for e in entries
               for f in ('audioUrl', 'scoreUrl') if e.get(f)]
    if not targets:
        return 0

    print(f'  cdc: verifying {len(targets)} derived URLs…')
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(lambda t: head_ok(t[0][t[1]]), targets))

    pruned = 0
    for (entry, field), ok in zip(targets, results):
        if not ok:
            entry[field] = None
            pruned += 1
    if pruned:
        print(f'  cdc: dropped {pruned} URL(s) that 404 upstream')
    return pruned


def fetch_cdc(verify=True):
    """Walk the paginated integrated-list-songs view for (title, code,
    path) rows, then read each song's own page for its real media
    links.

    2026-08-09: this used to DERIVE the URLs from the catalogue code
    (`D0180` → `.../mp3/D0180.mp3`) and HEAD-check the guesses. That
    was wrong in both directions, and a user caught it:

      • It missed every bilingual song. CDC publishes those as
        `D0375_English.mp3` + `D0375_Chinese.mp3` with no plain
        `D0375.mp3`, so the guess 404'd and the sync concluded the
        audio "was never uploaded". It was there the whole time,
        under a name the guess could not reach — that is where the
        supposed 23 missing files went.
      • It missed the instrumental and accompaniment tracks on
        essentially every CDC song (`D0180i.mp3`, `D0415m.mp3`),
        because it only ever looked for the bare code.

    Reading the page costs ~283 fetches per sync instead of ~566 HEAD
    checks, and returns what the church actually published rather than
    what we hoped it had named things.
    """
    import concurrent.futures

    rows = []
    seen = set()
    for page in range(0, 10):
        page_html = http_get(f'{CDC_INDEX}?page={page}')
        if not page_html:
            continue
        before = len(seen)
        for m in CDC_ROW_RE.finditer(page_html):
            title_raw, path, code = m.group(1), m.group(2), m.group(3).upper()
            if code in seen:
                continue
            title = clean_title(title_raw)
            if not title or _is_bad_title(title):
                continue
            seen.add(code)
            rows.append((title, code, path))
        if len(seen) == before:
            break

    print(f'  cdc: {len(rows)} songs, reading each page for media…')

    def build(row):
        title, code, path = row
        url = f'{CDC_ROOT}{path}'
        media = parse_cdc_media(http_get(url), code)
        language = detect_language(title, default='en')
        return make_entry(
            'cdc', code.lower(), title, url,
            code=code,
            language=language,
            audioUrl=pick_primary_audio(media['tracks'], language),
            instrumentalUrl=_track_url(media['tracks'], 'instrumental'),
            accompanimentUrl=_track_url(media['tracks'], 'accompaniment'),
            audioTracks=media['tracks'],
            scoreUrl=media['score'],
            themes=infer_themes(title),
            verse=infer_verse(title),
        )

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        entries = list(pool.map(build, rows))

    with_audio = sum(1 for e in entries if e['audioUrl'])
    extra = sum(len(e['audioTracks'] or []) for e in entries)
    print(f'  cdc: {with_audio}/{len(entries)} have audio, '
          f'{extra} tracks total')
    if UNKNOWN_CDC_SUFFIXES:
        # Not a failure — the file IS captured, as a vocal take. But a
        # new suffix means CDC has a convention we do not model yet, so
        # say so rather than let it pass unnoticed.
        print(f'  cdc: note — unrecognised filename suffixes treated as '
              f'vocal: {sorted(UNKNOWN_CDC_SUFFIXES)}')
    return entries


# ── Merge ─────────────────────────────────────────────────────────

# Fields refreshed from upstream, keeping the stored value when the
# fresh one is empty. Descriptive metadata only.
_REFRESH_FIELDS = (
    'url', 'sourceLabel', 'language', 'code', 'artist', 'composer',
    'lyricist', 'durationSec', 'artworkUrl', 'lyrics',
)

# Media links, where the fresh value is AUTHORITATIVE — including when
# it is empty. A URL that has stopped resolving gets pruned upstream
# (see [prune_derived_urls]) and that pruning has to survive the
# merge, or the catalogue would keep serving the dead link forever.
# head_ok retries, so a blip cannot clear a good URL by itself.
_MEDIA_FIELDS = (
    'audioUrl', 'instrumentalUrl', 'accompanimentUrl', 'audioTracks',
    'videoUrl', 'youtubeId', 'soundcloudTrackId', 'scoreUrl',
)


def merge(existing, new):
    """Fold a freshly-fetched entry over the stored one.

    `firstSeenAt` never moves and `updatedAt` only bumps when
    something actually changed — otherwise the weekly cron would
    restamp all 500 rows every run and destroy the "Recently updated"
    sort. Hand-curated `verse` and `themes` are never overwritten,
    only backfilled.
    """
    if not existing:
        out = dict(new)
        out['firstSeenAt'] = _now_iso()
        out['updatedAt'] = out['firstSeenAt']
        return normalise(out)

    merged = dict(existing)
    merged.setdefault('firstSeenAt', _now_iso())
    changed = False

    new_title = new.get('title')
    if new_title and _is_bad_title(merged.get('title')) \
            and new_title != merged.get('title'):
        merged['title'] = new_title
        changed = True

    for k in _REFRESH_FIELDS:
        v = new.get(k)
        if v not in (None, '') and merged.get(k) != v:
            merged[k] = v
            changed = True

    for k in _MEDIA_FIELDS:
        v = new.get(k) or None
        if merged.get(k) != v:
            merged[k] = v
            changed = True

    # Backfill only — a hand-edited value wins over the classifier.
    if not merged.get('themes') and new.get('themes'):
        merged['themes'] = new['themes']
        changed = True
    if not merged.get('verse') and new.get('verse'):
        merged['verse'] = new['verse']
        changed = True

    # Any field the older schema never had.
    for k, v in new.items():
        if k not in merged:
            merged[k] = v
            changed = True

    merged['updatedAt'] = _now_iso() if changed \
        else merged.get('updatedAt', merged['firstSeenAt'])
    return normalise(merged)


def verify_links(songs, workers=4):
    """HEAD every media URL in the catalogue and report the dead ones.

    This exists because the Songs feature was pulled in v1.3.126 with
    "the song links were reported broken" — nobody noticed the fydt
    backend migration had rotted the whole catalogue until users did.
    Run it after a sync (or from the weekly cron) so rot surfaces as a
    diff instead of a bug report.
    """
    import concurrent.futures

    targets = []
    seen = set()
    for s in songs:
        for field in ('audioUrl', 'instrumentalUrl', 'accompanimentUrl',
                      'videoUrl', 'scoreUrl'):
            if s.get(field):
                targets.append((s['id'], s['title'], field, s[field]))
                seen.add(s[field])
        # The scalar fields above are drawn FROM audioTracks, but the
        # extra language variants live only here — check those too, or
        # a dead Chinese take would ride along unnoticed behind a
        # healthy English one.
        for t in s.get('audioTracks') or []:
            if t.get('url') and t['url'] not in seen:
                targets.append(
                    (s['id'], s['title'],
                     f"track:{t.get('kind')}/{t.get('lang') or '-'}",
                     t['url']))
                seen.add(t['url'])

    def check(t):
        _id, title, field, url = t
        req = urllib.request.Request(
            url, method='HEAD', headers={'User-Agent': USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=25) as r:
                return t, r.status, None
        except urllib.error.HTTPError as e:
            return t, e.code, None
        except Exception as e:
            return t, None, str(e)[:60]

    print(f'\nVerifying {len(targets)} media URLs '
          f'({workers} workers)…')
    dead = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for i, (t, status, err) in enumerate(pool.map(check, targets), 1):
            if status != 200:
                dead.append((t, status, err))
            if i % 100 == 0:
                print(f'  …{i}/{len(targets)} checked, {len(dead)} dead')

    if not dead:
        print(f'  ✓ all {len(targets)} media URLs return 200')
        return 0
    print(f'  ✗ {len(dead)} dead URL(s):')
    for (_id, title, field, url), status, err in dead[:40]:
        print(f'    {status or err}  {_id}  {field}  {title[:30]}')
        print(f'      {url}')
    if len(dead) > 40:
        print(f'    … and {len(dead) - 40} more')
    return len(dead)


def load_existing():
    if not os.path.exists(SONGS_JSON):
        return {}
    try:
        with open(SONGS_JSON, encoding='utf-8') as f:
            doc = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f'  warn: could not read {SONGS_JSON}: {e}', file=sys.stderr)
        return {}
    return {s['id']: s for s in doc.get('songs', []) if s.get('id')}


def main():
    global SONGS_JSON

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--dry-run', action='store_true',
                    help='report what would change, write nothing')
    ap.add_argument('--verify', action='store_true',
                    help='HEAD every media URL afterwards and report '
                         'dead links (exits non-zero if any are dead)')
    ap.add_argument('--verify-only', action='store_true',
                    help='skip the sync; just verify the stored catalogue')
    ap.add_argument('--no-prune', action='store_true',
                    help="keep CDC's derived URLs without HEAD-checking "
                         'them (faster; ships known-dead links)')
    ap.add_argument('--out', metavar='PATH',
                    help='where to write the catalogue (default: '
                         f'{_default_out()})')
    args = ap.parse_args()

    if args.out:
        SONGS_JSON = os.path.abspath(args.out)

    if args.verify_only:
        stored = load_existing()
        if not stored:
            print('No catalogue to verify.', file=sys.stderr)
            return 1
        return 1 if verify_links(list(stored.values())) else 0

    print('Syncing church song catalogues…')
    existing = load_existing()
    print(f'  existing catalogue: {len(existing)} songs')

    taxonomy = fetch_fydt_taxonomy()
    wp_index = fetch_fydt_wp_index()
    fresh = (fetch_fydt(taxonomy, wp_index)
             + fetch_cahaya()
             + fetch_cdc(verify=not args.no_prune))

    if not fresh:
        print('ERROR: every source returned nothing — refusing to write an '
              'empty catalogue.', file=sys.stderr)
        return 1

    merged = {}
    for entry in fresh:
        merged[entry['id']] = merge(existing.get(entry['id']), entry)

    dropped = sorted(set(existing) - set(merged))
    added = sorted(set(merged) - set(existing))

    songs = sorted(merged.values(),
                   key=lambda s: (s['source'], s['title']))

    by_source = {}
    by_language = {}
    for s in songs:
        by_source[s['source']] = by_source.get(s['source'], 0) + 1
        by_language[s['language']] = by_language.get(s['language'], 0) + 1

    with_audio = sum(1 for s in songs
                     if s.get('audioUrl') or s.get('soundcloudTrackId'))
    with_video = sum(1 for s in songs
                     if s.get('videoUrl') or s.get('youtubeId'))
    with_score = sum(1 for s in songs if s.get('scoreUrl'))
    with_lyrics = sum(1 for s in songs if s.get('lyrics'))

    doc = {
        '_meta': {
            'generatedAt': _now_iso(),
            'generator': 'scripts/sync_songs.py v2',
            'count': len(songs),
            'bySource': by_source,
            'byLanguage': by_language,
            'withAudio': with_audio,
            'withVideo': with_video,
            'withScore': with_score,
            'withLyrics': with_lyrics,
            'sources': {
                k: {'label': v['label'], 'home': v['home']}
                for k, v in SOURCES.items()
            },
            'notes': {'fuyindiantai.org': _FUYINDIANTAI_NOTE},
        },
        'songs': songs,
    }

    print(f'\n  total     {len(songs)}')
    print(f'  by source {by_source}')
    print(f'  by lang   {by_language}')
    print(f'  audio {with_audio} · video {with_video} · '
          f'score {with_score} · lyrics {with_lyrics}')
    if added:
        print(f'  + {len(added)} new')
    if dropped:
        print(f'  - {len(dropped)} no longer upstream: {dropped[:8]}')

    if args.dry_run:
        print('\n(dry run — nothing written)')
        return verify_links(songs) and 1 or 0 if args.verify else 0

    os.makedirs(os.path.dirname(SONGS_JSON), exist_ok=True)
    with open(SONGS_JSON, 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write('\n')
    size = os.path.getsize(SONGS_JSON)
    print(f'\n✓ wrote {SONGS_JSON} ({size:,} bytes)')

    if args.verify:
        return 1 if verify_links(songs) else 0
    return 0


if __name__ == '__main__':
    sys.exit(main())
