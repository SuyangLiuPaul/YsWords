#!/usr/bin/env python3
"""The 16 records the transcription pass exists for, derived rather than listed.

One definition, imported by `transcribe_fetch_audio.py`,
`transcribe_sermons.py` and `transcribe_qa.py`, so the three cannot
disagree about which records they are working on.

`scripts/merge_sermon_library.py` excludes these by exactly ONE predicate,
`hasBody`, and says so in its header. This module uses the same predicate
and nothing else — not `bodyChars`, not a hard-coded id list, which would
go stale silently the next time the library is re-synced.

The awkward part, and why `include_done` exists: closing the seam means
setting `hasBody` true on these very records, at which point the predicate
that selects them stops selecting them. So a record ALSO counts as a target
once this pass has produced a sidecar for it under `transcripts/`. That
makes the set stable across the flip and every script re-runnable
afterwards, without any script having to remember a list.
"""
from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LIBRARY = REPO / "assets" / "sermon_library"
INDEX_JSON = LIBRARY / "index.json"
AUDIO_DIR = LIBRARY / "audio"
BODIES_DIR = LIBRARY / "bodies"
TRANSCRIPTS = LIBRARY / "transcripts"
RAW_DIR = TRANSCRIPTS / "raw"

# The one preacher the app carries (owner's decision, 2026-09-06).
TARGET_AUTHOR = "张熙和牧师"


def load_index() -> dict:
    return json.loads(INDEX_JSON.read_text(encoding="utf-8"))


def transcribed_ids() -> set[str]:
    if not TRANSCRIPTS.is_dir():
        return set()
    return {p.stem for p in TRANSCRIPTS.glob("*.json")
            if p.name not in ("index.json", "qa_report.json")}


def targets(index: dict, include_done: bool = True) -> list[dict]:
    done = transcribed_ids() if include_done else set()
    out = []
    for rec in index["sermons"]:
        if rec.get("author") != TARGET_AUTHOR:
            continue
        if not rec.get("audioUrls"):
            continue
        if rec.get("hasBody") and str(rec["id"]) not in done:
            continue
        out.append(rec)
    return sorted(out, key=lambda r: int(r["id"]))


def audio_path(rec: dict, i: int) -> Path:
    url = rec["audioUrls"][i]
    return AUDIO_DIR / f"{rec['id']}_{i}_{url.rsplit('/', 1)[-1]}"


if __name__ == "__main__":
    idx = load_index()
    recs = targets(idx)
    print(f"{len(recs)} targets (author={TARGET_AUTHOR}, has audio, "
          f"no body or already transcribed here)")
    for r in recs:
        print(f"  {r['id']:<7} {r['refcode']:<10} {len(r['audioUrls'])} part(s)"
              f"  hasBody={bool(r.get('hasBody'))}  {r['title']}")
