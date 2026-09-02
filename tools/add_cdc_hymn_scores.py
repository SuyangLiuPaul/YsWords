#!/usr/bin/env python3
"""Give the 15 CDC hymns the sheet music the church already publishes.

    python3 tools/add_cdc_hymn_scores.py --check
    python3 tools/add_cdc_hymn_scores.py

Re-runnable and idempotent; `--check` never writes.

WHERE THIS CAME FROM
--------------------
The user, 2026-08-18, pointing at the "WHERE WE MEET" menu:
「看下所有网站里面有没有其他的歌也加进这个app里面」. The queue recorded that
as impossible — the host refused every datacenter IP. It answers now.

**The sweep's headline answer is "nothing missing":** the church's
integrated song list carries 256 code-shaped songs (`/content/d0180` →
`music/mp3/D0180.mp3`), and the app already has all 256, plus 42 more.
No new songs to add.

**But the country pages link a different directory.** `hymns/`, not
`music/` — 15 classic English hymns, each with an MP3 *and* a PDF score,
and our sync only ever read `music/`. We already had all 15 by title
(`cdc:h01`–`h15`, audio and all), so they never showed up as missing
songs. What we did not have is their sheet music: every one of the 15
has `scoreUrl` empty, and those are 15 of the 18 CDC songs in the whole
catalogue without a score.

So the answer to "are there songs we don't have" is no, and the answer
to "is there anything on those pages we're not using" is yes.

MATCHING
--------
By title, normalised, against `source == 'cdc'` only. The filenames are
the titles (`Be_Thou_My_Vision.pdf`), and all 15 matched exactly with no
fuzzy fallback needed — so this refuses rather than guesses if a name
ever stops matching. Each URL was confirmed to answer 206 to a range
request before being written.
"""
import argparse
import json
import os
import re
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONGS = os.path.join(ROOT, 'assets/songs.json')
HOST = 'https://www.christiandiscipleschurch.org'
DIR = '/sites/default/files/hymns/pdf'

# Transcribed from the country pages. Filenames, not titles — the two
# differ in punctuation and the file is what has to resolve.
HYMNS = [
    'Amazing_Grace',
    'Be_Still_My_Soul',
    'Be_Thou_My_Vision',
    'Blest_Be_the_Tie_That_Binds',
    'Christ_the_Lord_is_Risen_Today',
    'Close_to_Thee',
    'I_Sing_the_Mighty_Power_of_God',
    'Immortal_Invisible_God_Only_Wise',
    'Like_a_River_Glorious',
    'O_Worship_the_King',
    'Take_My_Life_and_Let_it_Be',
    'There_is_a_Fountain_Filled_with_Blood',
    'Thine_is_the_Glory',
    'To_God_be_the_Glory',
    'Trust_and_Obey',
]


def norm(s):
    return re.sub(r'\s+', ' ',
                  re.sub(r'[^a-z ]', ' ',
                         (s or '').replace('_', ' ').lower())).strip()


def score_url(stem):
    return f'{HOST}{DIR}/{urllib.parse.quote(stem)}.pdf'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()

    with open(SONGS, encoding='utf-8') as fh:
        doc = json.load(fh)
    songs = doc['songs'] if isinstance(doc, dict) and 'songs' in doc else None
    if songs is None:
        sys.exit('REFUSE: songs.json is not the {"songs": [...]} shape')

    by_title = {}
    for s in songs:
        if s.get('source') == 'cdc':
            by_title.setdefault(norm(s.get('title')), []).append(s)

    changed, already, missing = [], [], []
    for stem in HYMNS:
        cands = by_title.get(norm(stem))
        if not cands:
            missing.append(stem)
            continue
        if len(cands) > 1:
            missing.append(f'{stem} (ambiguous: '
                           f'{[c["id"] for c in cands]})')
            continue
        s = cands[0]
        url = score_url(stem)
        if s.get('scoreUrl') == url:
            already.append(s['id'])
        elif s.get('scoreUrl'):
            # Never overwrite a score that came from somewhere else.
            already.append(f'{s["id"]} (kept existing {s["scoreUrl"]})')
        else:
            changed.append((s['id'], s.get('title'), url))
            if not args.check:
                s['scoreUrl'] = url

    print(f'hymns listed        {len(HYMNS)}')
    print(f'already had a score {len(already)}')
    print(f'to set              {len(changed)}')
    for i, t, u in changed:
        print(f'   {i:<10} {str(t)[:38]:40} {u.rsplit("/", 1)[1]}')

    if missing:
        print(f'\nREFUSE: {len(missing)} did not match exactly one cdc song:')
        for m in missing:
            print('   ', m)
        sys.exit(1)

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
