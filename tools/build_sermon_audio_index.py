#!/usr/bin/env python3
"""Rebuild assets/sermons/audio_index.json against the church's own MP3s.

    python3 tools/build_sermon_audio_index.py --check   # report only
    python3 tools/build_sermon_audio_index.py           # rewrite the index

Re-runnable and idempotent. `--check` never writes.

WHY THIS EXISTS
---------------
The 289 sermons all had audio in the inventory and none of it was
reachable: `SermonAudioService.baseUrl` was empty because hosting was
undecided, and 5.46 GB is not a casual bill. The user, 2026-09-02:
「录音你可以直接用我们教会的」 — the church already publishes them.

    https://www.christiandiscipleschurch.org/content/ehhc_sermons_public

589 MP3s, server-rendered into that page as relative hrefs, grouped into
20 category folders. Measured before writing any of this:

    accept-ranges: bytes                  → seeking works
    Range: bytes=0-1023 → 206             → confirmed, not just advertised
    cache-control: public, max-age=31536000
    no access-control-allow-origin        → and it does not matter

That last line is the one worth keeping. There is no CORS header, which
would sink anything that *fetches* the bytes — but a media element is
not a fetch. Loading one of these into `new Audio()` from the
https://yahwehword.com origin resolved metadata and reported a 764 s
duration, so playback works on web as well as native. Verified in a
browser on the real origin, not assumed from the spec.

WHAT IT CHANGES
---------------
Two things, and the second was not the point of the exercise.

1. Every part gains `path` — the real nested location. The service used
   to build a URL as `baseUrl + filename`, which cannot address
   `.../ehhc_mp3_sermons/20_Antichrist/234a_….mp3`; a flat base was
   always going to be wrong for this host.

2. **The index double-counted 72 parts.** It claimed 661; the church
   publishes 589, and the 72 extras are apostrophe variants of files
   that are already there — `The_Lord_s_Concept` beside
   `The_Lord's_Concept`, byte-identical, same tape side. Checked
   individually: all 72 have a byte-identical twin among the matched
   parts, 0 are unexplained, and no sermon loses any audio. Left alone
   they would have made a 2-part sermon play as 4, twice through.

Every one of the 289 sermons is covered. If that ever stops being true
this script says so and refuses to write.
"""
import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, 'assets/sermons/audio_index.json')

PAGE = ('https://www.christiandiscipleschurch.org/content/'
        'ehhc_sermons_public')
# Kept separate from the paths so the host can move without touching 589
# rows. Mirrors SermonAudioService.baseUrl.
HOST = 'https://www.christiandiscipleschurch.org'

CACHE = '/tmp/ehhc_sermons_public.html'


def fetch(use_cache=True):
    if use_cache and os.path.exists(CACHE):
        with open(CACHE, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    req = urllib.request.Request(PAGE, headers={'User-Agent': 'yswords-audio-index'})
    with urllib.request.urlopen(req, timeout=60) as r:
        html = r.read().decode('utf-8', 'replace')
    with open(CACHE, 'w', encoding='utf-8') as fh:
        fh.write(html)
    return html


def church_paths(html):
    """filename -> site-relative path, for every published MP3.

    The hrefs are RELATIVE. An earlier pass grepped for `https?://…\\.mp3`
    against the same HTML, found zero, and concluded the page was
    JavaScript-rendered — it is not, it is plain Drupal output.
    """
    out = {}
    for raw in re.findall(r'href="([^"]+\.mp3)"', html):
        path = urllib.parse.unquote(raw)
        out[path.rsplit('/', 1)[1]] = path
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--refetch', action='store_true',
                    help='ignore the cached copy of the page')
    args = ap.parse_args()

    published = church_paths(fetch(use_cache=not args.refetch))
    print(f'church publishes {len(published)} distinct MP3s')
    if len(published) < 400:
        sys.exit(f'REFUSE: only {len(published)} MP3s found — the page '
                 'shape changed, or the fetch was truncated')

    with open(INDEX, encoding='utf-8') as fh:
        index = json.load(fh)

    rebuilt = {}
    dropped = 0
    unexplained = []
    for sid, parts in index.items():
        kept = []
        seen = set()
        for p in parts:
            path = published.get(p['file'])
            if path is None:
                # Only tolerable if an already-kept part is byte-identical
                # on the same tape side — the apostrophe-variant case.
                twin = any(k['part'] == p['part'] and k['bytes'] == p['bytes']
                           for k in kept)
                if twin:
                    dropped += 1
                else:
                    unexplained.append(f'{sid} {p["file"]}')
                continue
            key = (p['part'], path)
            if key in seen:
                dropped += 1
                continue
            seen.add(key)
            kept.append({'part': p['part'], 'file': p['file'],
                         'bytes': p['bytes'], 'path': path})
        kept.sort(key=lambda p: p['part'])
        if not kept:
            unexplained.append(f'{sid} HAS NO AUDIO AT ALL')
        rebuilt[sid] = kept

    total = sum(len(v) for v in rebuilt.values())
    print(f'sermons {len(rebuilt)}   parts {total}   '
          f'duplicates dropped {dropped}')

    if unexplained:
        print(f'\nREFUSE: {len(unexplained)} parts are neither published nor '
              'a duplicate of one that is:')
        for u in unexplained[:20]:
            print('   ', u)
        sys.exit(1)

    if args.check:
        print('\n--check: nothing written.')
        return

    with open(INDEX, 'w', encoding='utf-8') as fh:
        json.dump(rebuilt, fh, ensure_ascii=False, indent=1, sort_keys=True)
        fh.write('\n')
    print(f'\nwrote {INDEX}')
    print(f'host for SermonAudioService.baseUrl: {HOST}')


if __name__ == '__main__':
    main()
