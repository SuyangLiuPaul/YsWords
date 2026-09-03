#!/usr/bin/env python3
"""Give the CDC songs the cover art the church already publishes.

    python3 tools/add_cdc_artwork.py --check
    python3 tools/add_cdc_artwork.py

Re-runnable and idempotent; `--check` never writes.

WHERE THIS CAME FROM
--------------------
The queue, 2026-08-11: "393 of 606 songs have no `artworkUrl` — CDC,
CGDC and Cahaya publish none". Half of that was already wrong when it
was written (cgdc's songbook logos were wired the same night, and all
63 cgdc songs now carry one), and the CDC half carried its own warning:
"Re-check CDC when the host is reachable — it was down for this whole
investigation, so 'CDC has no images' is unverified rather than
established."

It is reachable now, and it was wrong. **CDC publishes a per-song
600×300 cover** — a photograph with the song's title set over it — at
`/sites/default/files/music/jpg/<CODE>.jpg`, and every song page carries
an `<img>` pointing at it. Nothing ever looked, because `artworkUrl`
was only ever read from fydt's WordPress API.

WHAT THE SURVEY FOUND (2026-09-03, all 298 CDC pages read)
----------------------------------------------------------
    123/123  d-coded (Chinese)  page has the <img>, and it resolves
     68/160  e-coded (English)  page has the <img>, and it resolves
     92/160  e-coded (English)  page has the <img>, and it 404s
     15/15   h-coded (hymns)    no <img> at all

So **191 real covers**, which is the largest single artwork gap in the
catalogue — it takes "songs with no artwork" from 359 to 168.

**The 92 are why this verifies instead of deriving.** Those pages link
an image the church never uploaded; the markup is identical to the ones
that work. Deriving `E0710` → `E0710.jpg` from the code, or trusting
the `<img>` without asking, would write 92 URLs that answer 404 — and a
dead artworkUrl is not free: it costs a request per row at runtime and
pollutes `RemoteImage`'s failure memo before degrading to the source
mark. The check belongs here, once, in a script nobody is waiting on.

WHY A PATCHER AND NOT JUST THE SYNC
-----------------------------------
Both. `scripts/sync_songs.py` now reads and verifies this so the
published catalogue carries it going forward (that copy is the
reference implementation — the run that actually publishes lives in
yswords-data and needs the same change). This script exists because the
bundled `assets/songs.json` is a snapshot of the *published* dataset,
so it would otherwise stay blank until that side is updated and
re-published. Same shape as `tools/add_cdc_hymn_scores.py`, for the
same reason, and `test/cdc_artwork_test.dart` fails if a later snapshot
pull drops what this wrote.

COST
----
298 page reads plus one HEAD per image found, throttled, four at a
time — the same traffic one sync already makes. Do not run it in a
loop.
"""
import argparse
import json
import os
import re
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONGS = os.path.join(ROOT, 'assets/songs.json')
HOST = 'https://www.christiandiscipleschurch.org'

# Anchored on the directory, not on the code: the point of reading the
# page is to take the church's own answer rather than rebuild it from
# the catalogue code, which is the mistake `fetch_cdc`'s docstring
# records having already made once with the mp3s.
IMG_RE = re.compile(
    r'<img[^>]+src="(/sites/default/files/music/jpg/[^"]+)"', re.IGNORECASE)

UA = {'User-Agent': 'Mozilla/5.0 (compatible; yswords-catalogue/1.0)'}
TIMEOUT = 25
WORKERS = 4
PAUSE = 0.15


def get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read().decode('utf-8', 'replace')


def head_ok(url):
    """True only for a 200 that is actually an image.

    Drupal answers a missing file with an HTML error page on some
    paths, which is the same trap `tools/add_cdc_hymn_scores.py` hit
    with the PDFs — so the content type is part of the check, not a
    nicety.
    """
    req = urllib.request.Request(url, method='HEAD', headers=UA)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            ctype = (r.headers.get('Content-Type') or '').lower()
            return r.status == 200 and ctype.startswith('image/')
    except urllib.error.HTTPError:
        return False
    except Exception:
        return False


def survey(songs):
    """{song id: verified absolute artwork url} for the CDC songs."""
    found, lock = {}, threading.Lock()
    pending = list(songs)
    idx = [0]

    def work():
        while True:
            with lock:
                if idx[0] >= len(pending):
                    return
                s = pending[idx[0]]
                idx[0] += 1
            try:
                m = IMG_RE.search(get(s['url']))
            except Exception as exc:              # noqa: BLE001
                with lock:
                    found[s['id']] = ('error', str(exc)[:60])
                time.sleep(PAUSE)
                continue
            if not m:
                with lock:
                    found[s['id']] = ('none', None)
            else:
                url = urllib.parse.urljoin(HOST, m.group(1))
                with lock:
                    found[s['id']] = ('ok' if head_ok(url) else '404', url)
            time.sleep(PAUSE)

    threads = [threading.Thread(target=work) for _ in range(WORKERS)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true',
                    help='report only, write nothing')
    args = ap.parse_args()

    with open(SONGS, encoding='utf-8') as fh:
        doc = json.load(fh)
    songs = doc.get('songs') if isinstance(doc, dict) else None
    if songs is None:
        sys.exit('REFUSE: songs.json is not the {"songs": [...]} shape')

    cdc = [s for s in songs if s.get('source') == 'cdc' and s.get('url')]
    if not cdc:
        sys.exit('REFUSE: no cdc songs in the catalogue')
    print(f'reading {len(cdc)} cdc song pages…')

    result = survey(cdc)
    errors = {k: v[1] for k, v in result.items() if v[0] == 'error'}
    if errors:
        # A partial survey would look exactly like "the church deleted
        # its covers" and would silently write fewer than it should.
        print(f'\nREFUSE: {len(errors)} pages could not be read; a partial '
              f'survey must not be written.')
        for k, v in list(errors.items())[:5]:
            print(f'   {k}: {v}')
        sys.exit(1)

    kinds = {'ok': 0, '404': 0, 'none': 0}
    for state, _ in result.values():
        kinds[state] += 1
    print(f'  page links a cover that resolves   {kinds["ok"]}')
    print(f'  page links a cover that 404s       {kinds["404"]}')
    print(f'  page links no cover at all         {kinds["none"]}')

    by_id = {s['id']: s for s in cdc}
    changed, already, kept = [], [], []
    for sid, (state, url) in sorted(result.items()):
        if state != 'ok':
            continue
        s = by_id[sid]
        current = s.get('artworkUrl')
        if current == url:
            already.append(sid)
        elif current:
            # Never overwrite artwork that came from somewhere else.
            kept.append(f'{sid} (kept existing {current})')
        else:
            changed.append((sid, s.get('title'), url))
            if not args.check:
                s['artworkUrl'] = url

    print(f'\nalready set  {len(already)}')
    print(f'left alone   {len(kept)}')
    print(f'to set       {len(changed)}')
    for i, t, u in changed[:10]:
        print(f'   {i:<10} {str(t)[:38]:40} {u.rsplit("/", 1)[1]}')
    if len(changed) > 10:
        print(f'   … and {len(changed) - 10} more')

    if args.check:
        print('\n--check: nothing written.')
        return
    if changed:
        with open(SONGS, 'w', encoding='utf-8') as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=1)
            fh.write('\n')
        print(f'\nwrote {SONGS}')
    else:
        print('\nnothing to do.')


if __name__ == '__main__':
    main()
