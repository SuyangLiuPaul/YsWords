#!/usr/bin/env python3
"""
sync_songs.py — refresh assets/songs.json from the two upstream
church sites that publish the catalogue.

What this script DOES:
  • Fetches the sitemap / index page from each source.
  • For each song URL it sees, records: title, source URL, language
    (heuristic from the title), catalogue code, and direct audio /
    PDF URLs (deterministic for CDC; per-page scrape for fydt).
  • Tags each entry with theme labels via the same title-keyword
    classifier as the manual seed.
  • Detects "Psalm 23" / "诗篇 23" style verse references in titles.
  • Writes the merged result back to assets/songs.json — preserving
    any manual fields already set on existing entries (verse, themes
    overrides) so hand-curation doesn't get clobbered by the cron.

What this script DOES NOT do:
  • Download lyrics, song text, audio files, or PDFs.
  • Modify or republish any copyrighted content.
  • Touch anything outside assets/songs.json.

Run:
  python3 scripts/sync_songs.py

Exit code 0 = no change. Exit code 1 = file updated (CI uses this
to decide whether to commit).
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.parse
from xml.etree import ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONGS_JSON = os.path.join(REPO_ROOT, 'assets', 'songs.json')

# ── Constants ─────────────────────────────────────────────────────
FYDT_SITEMAP = 'https://fydt.org/wp-sitemap-posts-song-1.xml'
CDC_INDEX = 'https://www.christiandiscipleschurch.org/content/integrated-list-songs'

# Same theme keyword map as the seed builder. Kept inline so this
# script is self-contained and runs in CI without app dependencies.
THEME_KEYWORDS = [
    ('敬拜', ['敬拜', '尊崇', '颂赞', 'Worship', 'Adore', 'Praise', 'Bless', 'Extol']),
    ('赞美', ['赞美', '颂', '高举', 'Praise', 'Magnif', 'Glory', 'Lifted', '荣耀', '荣美']),
    ('救恩', ['救', '拯救', 'Salvation', 'Saved', 'Ransomed', 'Redeem', 'Rescue']),
    ('圣灵', ['灵', '圣灵', 'Spirit', 'Empowered', '圣火', '风随意']),
    ('委身', ['委身', '献', '为你', '凡事', 'Commit', 'Devote', 'Consecrate', 'Allegiance', 'Wholly']),
    ('顺服', ['顺服', '跟从', '跟随', '遵', '行你旨意', 'Follow', 'Obey', 'Imitate', 'Submit']),
    ('得胜', ['得胜', '胜', '奔', '战', 'Overcome', 'Race', 'Run', 'Fight', 'Strong', 'Bold']),
    ('重生', ['重生', '复活', '新', '活', 'Resurrection', 'Reborn', 'Renew', 'New', 'Living', 'Alive']),
    ('圣洁', ['圣洁', '洁净', '圣', '完全', 'Holy', 'Clean', 'Pure', 'Holiness', 'Perfect']),
    ('平安', ['平安', '安息', '安静', '宁', 'Peace', 'Rest', 'Still', 'Quiet']),
    ('感恩', ['感恩', '感谢', '称谢', 'Thank', 'Gratitude']),
    ('警醒', ['警醒', '儆醒', '醒', '警觉', 'Watch', 'Alert', 'Wake']),
    ('信心', ['信心', '信靠', '信', 'Faith', 'Trust', 'Believe']),
    ('爱', ['爱', 'Love', 'Beloved']),
    ('仰望', ['仰望', '盼望', '盼', '指望', 'Hope', 'Wait']),
    ('门徒', ['门徒', '弟子', '使徒', 'Disciple', 'Apostle', 'Mission']),
    ('祷告', ['祷告', '祈祷', '求', 'Prayer', 'Pray', 'Mercy']),
    ('真理', ['真理', '真', '智慧', 'Truth', 'Wisdom', 'Word', '话语', '话']),
    ('心', ['心', 'Heart', 'Mind']),
    ('神的名', ['雅伟', 'YHWH', 'Yahweh', 'LORD', 'Adonai', '神的名']),
    ('教会', ['教会', '同心', '合一', '联合', 'Church', 'Together', 'United', 'One Heart', 'Bond', '一致', '合意']),
    ('见证', ['见证', '传扬', '宣', '使万民', '万民', 'Declare', 'Proclaim', 'Witness', 'Testimony']),
    ('生命', ['生命', '复生', '生', 'Life']),
    ('诗篇', ['诗篇', 'Psalm']),
    ('儿童', ['孩', '童', '小', 'Child', 'Children']),
]

VERSE_RE_ZH = re.compile(r'诗篇\s*(\d+)')
VERSE_RE_EN = re.compile(r'Psalm\s*(\d+)', re.IGNORECASE)

CDC_CODE_RE = re.compile(r'/content/([defDEF]\d{3,5})\b', re.IGNORECASE)
TITLE_RE = re.compile(r'<title[^>]*>([^<]+)</title>', re.IGNORECASE)
# Audio link pattern: anything ending in .mp3 / .m4a inside an <a> or <audio>.
AUDIO_RE = re.compile(r'https?://[^\s"\'<>]+\.(?:mp3|m4a)', re.IGNORECASE)
# PDF link pattern.
PDF_RE = re.compile(r'https?://[^\s"\'<>]+\.pdf', re.IGNORECASE)

USER_AGENT = 'YsWordsSongsSyncBot/1.0 (+https://yswords.netlify.app)'


def http_get(url, timeout=20):
    """GET as text, with a polite UA + short timeout. Returns '' on failure."""
    req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
            try:
                return raw.decode('utf-8')
            except UnicodeDecodeError:
                return raw.decode('utf-8', errors='replace')
    except Exception as e:
        print(f'  warn: GET {url} failed: {e}', file=sys.stderr)
        return ''


def detect_language(title):
    """zh / en / th from a title string. Heuristic — works because the
    catalogue is bilingual at the title level (Chinese OR English),
    not paragraph-mixed."""
    if any('一' <= c <= '鿿' for c in title):
        return 'zh'
    if 'Thai' in title or any(
            '฀' <= c <= '๿' for c in title):
        return 'th'
    return 'en'


def infer_themes(title):
    out = set()
    for theme, keywords in THEME_KEYWORDS:
        for kw in keywords:
            if kw in title:
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


def fetch_fydt_song_urls():
    """Read the WordPress song-post sitemap → list of song page URLs."""
    xml = http_get(FYDT_SITEMAP)
    if not xml:
        return []
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return []
    ns = {'sm': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
    return [u.text for u in root.findall('.//sm:url/sm:loc', ns) if u.text]


def fetch_fydt_song_meta(url):
    """For one fydt song page, extract (title, audio_url, pdf_url).
    Returns (None, None, None) on failure — caller skips the entry."""
    html = http_get(url)
    if not html:
        return None, None, None
    title = None
    m = TITLE_RE.search(html)
    if m:
        title = m.group(1).strip()
        # Strip site suffix that fydt appends.
        title = re.sub(r'\s*[-|]\s*福音电台.*$', '', title).strip()
    audio = None
    a = AUDIO_RE.search(html)
    if a:
        audio = a.group(0)
    pdf = None
    p = PDF_RE.search(html)
    if p:
        pdf = p.group(0)
    return title, audio, pdf


def slug_from_url(url, prefix='fydt'):
    """Stable id derived from the URL path."""
    path = urllib.parse.urlparse(url).path.strip('/')
    return f'{prefix}:{path.replace("/", "_")}'


def fetch_cdc_index_codes():
    """Pull the CDC integrated-list-songs page → set of (title, code).
    The page renders as a long alphabetical table; we look for any
    /content/<code> link with a visible anchor text."""
    html = http_get(CDC_INDEX)
    if not html:
        return []
    out = []
    seen_codes = set()
    # Anchor pattern: <a href="/content/d0210">title</a>
    for m in re.finditer(
            r'<a[^>]+href="(/content/[defDEF]\d{3,5})"[^>]*>([^<]+)</a>',
            html, flags=re.IGNORECASE):
        path = m.group(1)
        title = re.sub(r'\s+', ' ', m.group(2)).strip()
        code_match = CDC_CODE_RE.search(path)
        if not code_match:
            continue
        code = code_match.group(1).upper()
        if code in seen_codes:
            continue
        seen_codes.add(code)
        out.append((title, code, path))
    return out


def merge(existing, new):
    """Merge a freshly-scraped entry over the existing one. Preserves
    user-curated fields (`verse` set by hand, `themes` overrides) so
    rerunning the sync never wipes manual work."""
    if not existing:
        return new
    merged = dict(existing)
    # Always refresh the source-derived fields.
    for k in ('title', 'url', 'audioUrl', 'pdfUrl', 'sourceLabel',
              'language', 'code'):
        v = new.get(k)
        if v:
            merged[k] = v
    # Themes: keep existing if non-empty (user may have curated),
    # otherwise take auto-derived.
    if not merged.get('themes'):
        merged['themes'] = new.get('themes', [])
    # Verse: keep existing if set; otherwise take auto-derived.
    if not merged.get('verse'):
        merged['verse'] = new.get('verse')
    return merged


def main():
    if not os.path.exists(SONGS_JSON):
        print(f'songs.json not found at {SONGS_JSON}', file=sys.stderr)
        sys.exit(2)
    with open(SONGS_JSON, encoding='utf-8') as f:
        bundle = json.load(f)
    existing = {s['id']: s for s in bundle.get('songs', [])}
    before_count = len(existing)

    print('— fydt sitemap —')
    fydt_urls = fetch_fydt_song_urls()
    print(f'  {len(fydt_urls)} song URLs in sitemap')
    for u in fydt_urls:
        sid = slug_from_url(u, 'fydt')
        existing_entry = existing.get(sid)
        # If we already have audio+pdf+title, skip the per-page hit.
        if existing_entry and existing_entry.get('audioUrl') \
                and existing_entry.get('pdfUrl') \
                and existing_entry.get('title'):
            continue
        title, audio, pdf = fetch_fydt_song_meta(u)
        if not title:
            print(f'  skip (no title): {u}')
            continue
        new_entry = {
            'id': sid,
            'title': title,
            'language': detect_language(title),
            'source': 'fydt',
            'sourceLabel': '福音电台',
            'url': u,
            'audioUrl': audio,
            'pdfUrl': pdf,
            'themes': infer_themes(title),
            'verse': infer_verse(title),
        }
        existing[sid] = merge(existing_entry, new_entry)
        time.sleep(0.5)  # be polite

    print('— CDC index —')
    cdc_entries = fetch_cdc_index_codes()
    print(f'  {len(cdc_entries)} entries in index')
    for title, code, path in cdc_entries:
        sid = f'cdc:{code.lower()}'
        existing_entry = existing.get(sid)
        new_entry = {
            'id': sid,
            'title': title,
            'code': code,
            'language': detect_language(title),
            'source': 'cdc',
            'sourceLabel': 'Christian Disciples Church',
            'url': f'https://www.christiandiscipleschurch.org{path}',
            # Deterministic CDC media URLs.
            'audioUrl': f'https://www.christiandiscipleschurch.org/sites/default/files/music/mp3/{code}.mp3',
            'pdfUrl': f'https://www.christiandiscipleschurch.org/sites/default/files/music/pdf/{code}.pdf',
            'themes': infer_themes(title),
            'verse': infer_verse(title),
        }
        existing[sid] = merge(existing_entry, new_entry)

    songs = list(existing.values())
    songs.sort(key=lambda s: (s['source'], s.get('code') or s['title']))
    bundle['songs'] = songs
    bundle.setdefault('_meta', {})['totalSongs'] = len(songs)
    bundle['_meta']['lastSyncedAt'] = time.strftime(
        '%Y-%m-%dT%H:%M:%SZ', time.gmtime())

    # Compare-then-write so CI only commits when something actually
    # changed.
    new_text = json.dumps(bundle, ensure_ascii=False, indent=2) + '\n'
    with open(SONGS_JSON, encoding='utf-8') as f:
        old_text = f.read()
    if new_text == old_text:
        print(f'No change ({len(songs)} songs total).')
        sys.exit(0)
    with open(SONGS_JSON, 'w', encoding='utf-8') as f:
        f.write(new_text)
    delta = len(songs) - before_count
    print(f'Updated: {len(songs)} songs total ({delta:+d}).')
    sys.exit(1)


if __name__ == '__main__':
    main()
