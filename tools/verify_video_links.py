#!/usr/bin/env python3
"""Check every YouTube id in assets/videos.json still resolves.

2026-08-25: 獨一真神's English recording (S7VEdxrWcX8) had gone — deleted
or made private — and nothing in the app or the test suite could tell.
The card rendered, the language button appeared, and tapping it played
nothing. The user found it by hand.

This repo has been here before with the songs catalogue, which is why
sync_songs.py grew `--verify`; the Songs feature was once deleted
outright because links rotted silently after a backend migration. Video
links rot the same way and had no equivalent check.

Deliberately NOT a Dart test: `flutter test` runs on CI with no promise
of network access, and a unit test that fails when GitHub's runner has a
bad minute teaches people to ignore red. Run this when a video is
reported broken, and after adding one.

    python3 tools/verify_video_links.py

Exits non-zero if any id is unreachable, and prints which series and
episode it belongs to so the report names the thing a reader would see.
"""
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

OEMBED = 'https://www.youtube.com/oembed'


def title_of(video_id, timeout=15):
    """The video's own title, or None when YouTube will not serve it.

    oEmbed answers 404 for a deleted or private video and 401 for one
    whose owner disabled embedding — both mean the app cannot play it,
    which is the only question being asked here.
    """
    url = f'{OEMBED}?' + urllib.parse.urlencode(
        {'url': f'https://youtu.be/{video_id}', 'format': 'json'})
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return json.load(r)['title']


def main():
    doc = json.loads(
        (pathlib.Path(__file__).resolve().parents[1] / 'assets' /
         'videos.json').read_text(encoding='utf-8'))

    checked = 0
    dead = []
    for series in doc['series']:
        for episode in series['episodes']:
            for track in episode['tracks']:
                checked += 1
                vid = track['youtubeId']
                where = f"{series['id']} ep{episode['id']} [{track['lang']}]"
                try:
                    print(f'  ok   {where:28} {vid}  {title_of(vid)[:58]}')
                except (urllib.error.HTTPError, urllib.error.URLError,
                        TimeoutError) as exc:
                    print(f'  DEAD {where:28} {vid}  {exc}')
                    dead.append((where, vid, str(exc)))
                # Gentle on someone else's API — this is ~55 requests and
                # there is no hurry.
                time.sleep(0.15)

    print(f'\nchecked {checked} ids, {len(dead)} unreachable')
    if dead:
        print('\nEach of these renders a language button that plays nothing:')
        for where, vid, exc in dead:
            print(f'  {where}  {vid}  {exc}')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
