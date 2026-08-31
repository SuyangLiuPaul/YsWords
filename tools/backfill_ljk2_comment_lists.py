#!/usr/bin/env python3
"""
2026-08-31: additive backfill of `comment-list` / `ul-comment-list` block
notes that `tools/import_ljk2.py` dropped on every import to date (fixed
in the same commit — see the new `elif` branch in `build_book_verses`).

This does NOT re-run the importer over the shipped assets: at least ten
commits have hand-repaired assets/biblexg-v2*.json since the 2026-05-19
import, and a full regeneration would revert every one of them. Instead
this reads the untracked upstream source already on disk at
`ljk-nt-bible-webapp/public/resources/`, finds the 22 verses per edition
(cn + tw) that carry a comment-list, computes WHERE in that verse's
existing blockNotes the list belongs, and inserts — nothing else in the
shipped JSON is touched.

Position, not string match: the two editions' note text has diverged
under post-import repairs, so anchoring by content would miss verses
whose neighbouring note text no longer matches upstream verbatim.
Instead: k = the number of non-empty `comment` nodes that precede the
list node within its verse's attachment run (the same run
`build_book_verses` uses to build blockNotes in the first place). If a
verse's shipped blockNotes array is shorter than k, the anchor doesn't
hold — skip it and print, rather than insert blind.

Run:
    python3 tools/backfill_ljk2_comment_lists.py           # dry run
    python3 tools/backfill_ljk2_comment_lists.py --write   # apply
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_ljk2 as ljk  # noqa: E402

REPO_ROOT = ljk.REPO_ROOT
SRC_DIR = os.path.join(REPO_ROOT, 'ljk-nt-bible-webapp', 'public', 'resources')


def find_insertions(lang: str, abbr: str, book_id: int) -> list[tuple[str, int, str]]:
    """Return `(verse_id, k, list_text)` for every comment-list /
    ul-comment-list node in one upstream book file, in encounter order.
    """
    path = os.path.join(SRC_DIR, f'{lang}-{abbr}.json')
    with open(path, encoding='utf-8') as f:
        book_data = json.load(f)

    out: list[tuple[str, int, str]] = []
    chapter = 0
    verse_id = None
    run_comment_count = 0
    for ch_data in book_data:
        for n in ch_data.get('nodeData', []):
            t = n.get('type')
            if t == 'chapter':
                chapter = int(n.get('chapterIndex', '0'))
            elif t == 'verse':
                verse_label = n.get('verseIndex', '0')
                import re
                m = re.match(r'\d+', verse_label)
                verse_num = int(m.group(0)) if m else 0
                if verse_num == 0:
                    continue
                verse_id = f'{book_id:02d}{chapter:03d}{verse_num:03d}'
                run_comment_count = 0
            elif t == 'comment':
                contents = n.get('contents', [])
                if not isinstance(contents, list):
                    contents = [str(contents)]
                cleaned, _body = ljk.split_block_comment(contents)
                if cleaned:
                    run_comment_count += 1
            elif t in ('comment-list', 'ul-comment-list'):
                contents = n.get('contents', [])
                if not isinstance(contents, list):
                    contents = [str(contents)]
                cleaned = ljk.clean_comment_list(contents, ordered=t == 'comment-list')
                if cleaned and verse_id is not None:
                    out.append((verse_id, run_comment_count, cleaned))
    return out


def backfill(asset_path: str, lang: str) -> None:
    with open(asset_path, encoding='utf-8') as f:
        verses = json.load(f)
    by_id = {v['id']: v for v in verses}

    insertions_by_verse: dict[str, list[tuple[int, str]]] = {}
    for abbr, _en, _cn, _tr, book_id in ljk.BOOKS:
        for verse_id, k, text in find_insertions(lang, abbr, book_id):
            insertions_by_verse.setdefault(verse_id, []).append((k, text))

    applied = 0
    skipped = 0
    for verse_id, items in insertions_by_verse.items():
        v = by_id.get(verse_id)
        if v is None:
            print(f'  SKIP {verse_id}: verse not found in {asset_path}')
            skipped += len(items)
            continue
        notes = v.setdefault('blockNotes', [])
        # `k` for every item in `items` is computed against the SOURCE
        # (only counting real `comment` nodes, never list nodes), so it
        # is stable however many lists this verse gets — but that also
        # means it is relative to the PRE-insertion array. `items` is
        # already in non-decreasing `k` order (encounter order in the
        # source can only add more comments, never fewer), so inserting
        # at `k + offset` — where `offset` is how many of THIS verse's
        # own list notes have already gone in — keeps every earlier
        # insertion's shift accounted for. Inserting at raw `k` for the
        # 2nd+ item would land it one slot too early, ahead of the
        # comment that should still precede it.
        original_len = len(notes)
        offset = 0
        for k, text in items:
            if k > original_len:
                print(f'  SKIP {verse_id}: k={k} but only {original_len} '
                      f'existing blockNotes — anchor does not hold')
                skipped += 1
                continue
            notes.insert(k + offset, text)
            offset += 1
            applied += 1

    print(f'{asset_path}: {applied} inserted, {skipped} skipped')

    # Preserve each asset's existing on-disk format rather than forcing
    # one style: biblexg-v2.json ships compact, biblexg-v2-tr.json ships
    # pretty-printed (indent=1) since an earlier hand-repair reformatted
    # it. Re-dumping both compact would turn this into a whole-file
    # rewrite in `git diff` instead of the additive change it is.
    pretty = os.path.basename(asset_path).endswith('-tr.json')
    with open(asset_path, 'w', encoding='utf-8') as f:
        if pretty:
            json.dump(verses, f, ensure_ascii=False, indent=1)
        else:
            json.dump(verses, f, ensure_ascii=False, separators=(',', ':'))


def main() -> None:
    write = '--write' in sys.argv
    cn_path = os.path.join(REPO_ROOT, 'assets', 'biblexg-v2.json')
    tr_path = os.path.join(REPO_ROOT, 'assets', 'biblexg-v2-tr.json')

    if not write:
        print('Dry run (pass --write to apply). Computing insertions only:')
        for lang, path in (('cn', cn_path), ('tw', tr_path)):
            total = 0
            for abbr, _en, _cn, _tr, book_id in ljk.BOOKS:
                total += len(find_insertions(lang, abbr, book_id))
            print(f'  {lang}: {total} list nodes found')
        return

    backfill(cn_path, 'cn')
    backfill(tr_path, 'tw')


if __name__ == '__main__':
    main()
