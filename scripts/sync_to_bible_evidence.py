#!/usr/bin/env python3
"""
Mirror YsWords' assets/bible_evidence.json to the bible-evidence repo:
  • Patch missing image arrays in src/data/evidences.ts
  • Append new entries (objects in evidences.ts + i18n keys in en.json + zh.json)

The TS file is parsed via simple regex on `id: '...'` blocks — this isn't
a full TS parser, but the file is generated to a regular shape so it
holds. Re-runs are idempotent: existing entries are not duplicated.
"""
from __future__ import annotations

import json
import os
import re
import sys

YSWORDS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BE_ROOT = "/Users/pliu0036/Documents/CodingProject/bible-evidence"

YSWORDS_JSON = os.path.join(YSWORDS_ROOT, "assets", "bible_evidence.json")
TS_FILE = os.path.join(BE_ROOT, "src", "data", "evidences.ts")
EN_FILE = os.path.join(BE_ROOT, "src", "locales", "en.json")
ZH_FILE = os.path.join(BE_ROOT, "src", "locales", "zh.json")


# Match an entry block in evidences.ts. The TS file uses 2-space indent
# objects with `id: '...'` as the first key. We don't need to *parse*
# the entries — only enumerate which ids exist + locate the closing `]`.
ID_RX = re.compile(r"^  \{\s*$|^\s*id:\s*'([^']+)'", re.MULTILINE)


def read_existing_ids(ts: str) -> set[str]:
    return set(re.findall(r"id:\s*'([^']+)'", ts))


def read_existing_images(ts: str) -> dict[str, str]:
    """Return {id: full-images-line-string} for in-place replacement."""
    out: dict[str, str] = {}
    # Match each entry block roughly: id: 'X', ... , images: [...] , ...
    for m in re.finditer(
        r"id:\s*'([^']+)'.*?images:\s*(\[[^\]]*\])",
        ts,
        flags=re.DOTALL,
    ):
        out[m.group(1)] = m.group(2)
    return out


def ts_array_for(images: list[str]) -> str:
    """Produce a TS array literal preserving the project's quoting style."""
    if not images:
        return "[]"
    inner = ", ".join(f'"{u}"' for u in images)
    return f"[{inner}]"


def render_ts_entry(e: dict) -> str:
    """Render one new evidence as a TS object literal."""
    id_ = e["id"]
    cat = e["category"]
    books = ", ".join(f"'{b}'" for b in e.get("bibleBooks", []))
    sources = ",\n      ".join(json.dumps(s, ensure_ascii=False) for s in e.get("academicSources", []))
    images = ts_array_for(e.get("images", []))
    return f"""  {{
    id: '{id_}',
    category: '{cat}',
    bibleBooks: [{books}],
    timeline: {json.dumps(e.get('timeline', ''), ensure_ascii=False)},
    titleKey: 'evidence.{id_}.title',
    summaryKey: 'evidence.{id_}.summary',
    detailedDescriptionKey: 'evidence.{id_}.detailedDescription',
    scripturalCorrelationKey: 'evidence.{id_}.scripturalCorrelation',
    discoveryDate: {json.dumps(e.get('discoveryDate', ''), ensure_ascii=False)},
    location: {json.dumps(e.get('location', ''), ensure_ascii=False)},
    scriptureReference: {json.dumps(e.get('scriptureReference', ''), ensure_ascii=False)},
    images: {images},
    confidenceLevel: '{e.get("confidenceLevel", "Strong")}',
    icon: {json.dumps(e.get('icon', '📜'), ensure_ascii=False)},
    academicSources: [
      {sources}{',' if sources else ''}
    ],
  }},
"""


def patch_ts_images(ts: str, ys_evidences: list[dict]) -> tuple[str, int]:
    """Patch in-place every entry whose YsWords copy has images but TS is empty."""
    existing_imgs = read_existing_images(ts)
    patched = 0
    for e in ys_evidences:
        id_ = e["id"]
        if id_ not in existing_imgs:
            continue
        if existing_imgs[id_] != "[]":
            continue  # already has images, leave alone
        new_imgs = e.get("images", [])
        if not new_imgs:
            continue
        # Replace the empty `images: []` for THIS specific id only.
        # Use a non-greedy search anchored on the id.
        pattern = re.compile(
            rf"(id:\s*'{re.escape(id_)}'.*?images:\s*)\[\]",
            flags=re.DOTALL,
        )
        replacement = r"\1" + ts_array_for(new_imgs)
        ts, n = pattern.subn(replacement, ts, count=1)
        patched += n
    return ts, patched


def append_ts_entries(ts: str, new_entries: list[dict]) -> str:
    """Append render_ts_entry blocks before the closing `]` of the
    `evidences` array. The TS file has additional `export const`
    blocks AFTER the array, so we anchor on the first `^]$` line that
    appears AFTER the `evidences` declaration."""
    if not new_entries:
        return ts
    block = "\n  // ── ROUND 36 EXPANSION ────────────────────────────────────────────\n"
    block += "".join(render_ts_entry(e) for e in new_entries)
    # Find the array opener, then the first standalone `]` after it.
    open_match = re.search(r"export const evidences: Evidence\[\] = \[", ts)
    if not open_match:
        raise RuntimeError("Could not find evidences array opener in TS file")
    after = ts[open_match.end():]
    # First line that is exactly `]` (closing the evidences array).
    close_rel = re.search(r"\n\]\n", after)
    if not close_rel:
        raise RuntimeError("Could not find evidences array closer in TS file")
    abs_close = open_match.end() + close_rel.start()
    return ts[:abs_close] + "\n" + block + ts[abs_close + 1:]


def add_locale_entries(
    locale_path: str,
    new_entries: list[dict],
    locale_key: str,
) -> int:
    with open(locale_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    section = data.setdefault("evidence", {})
    added = 0
    for e in new_entries:
        if e["id"] in section:
            continue
        section[e["id"]] = {
            "title": e["title"][locale_key],
            "summary": e["summary"][locale_key],
            "detailedDescription": e["description"][locale_key],
            "scripturalCorrelation": e["scripturalCorrelation"][locale_key],
        }
        added += 1
    with open(locale_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    return added


def patch_locale_for_existing(
    locale_path: str,
    ys_evidences: list[dict],
    locale_key: str,
) -> int:
    """If we patched images on an existing YsWords entry, the locale text is
    unchanged so nothing needs writing here. Kept as a no-op stub for symmetry."""
    return 0


def main() -> int:
    if not os.path.exists(YSWORDS_JSON):
        print(f"FATAL: {YSWORDS_JSON} missing", file=sys.stderr)
        return 1
    if not os.path.isdir(BE_ROOT):
        print(f"FATAL: {BE_ROOT} not found", file=sys.stderr)
        return 1

    with open(YSWORDS_JSON, "r", encoding="utf-8") as fh:
        ys = json.load(fh)
    ys_list = ys.get("evidences", [])

    with open(TS_FILE, "r", encoding="utf-8") as fh:
        ts = fh.read()

    existing = read_existing_ids(ts)

    # 1. Patch images for entries that exist but have empty arrays.
    ts, patched = patch_ts_images(ts, ys_list)

    # 2. Find truly NEW entries (in YsWords but not in TS).
    new_entries = [e for e in ys_list if e["id"] not in existing]

    # 3. Append new TS entries.
    ts = append_ts_entries(ts, new_entries)

    with open(TS_FILE, "w", encoding="utf-8") as fh:
        fh.write(ts)

    # 4. Append i18n entries for the new ones.
    en_added = add_locale_entries(EN_FILE, new_entries, "en")
    zh_added_hans = add_locale_entries(ZH_FILE, new_entries, "zh-Hans")

    print(
        f"bible-evidence sync: patched {patched} image arrays, "
        f"appended {len(new_entries)} new TS entries, "
        f"{en_added} en.json, {zh_added_hans} zh.json"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
