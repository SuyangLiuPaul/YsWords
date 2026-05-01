#!/usr/bin/env python3
"""
Generate maps_index.json entries for Sweet Publishing / Sweet Media
Bible illustrations and append them to the existing maps_index.json.

Fetches actual Wikimedia Commons thumbnail URLs via the API.
"""

import json
import sys
import time
import urllib.request
import urllib.error
import urllib.parse

# Flush stdout on every print
sys.stdout.reconfigure(line_buffering=True)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
MAPS_INDEX_PATH = "/Users/pliu0036/Documents/yswords/assets/maps_index.json"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
ARTIST_EN = "Sweet Publishing"
YEAR = "1984"

# ---------------------------------------------------------------------------
# Chinese book name mapping
# ---------------------------------------------------------------------------
ZH_BOOK_MAP_HANS = {
    "Ezra": "以斯拉记",
    "Nehemiah": "尼希米记",
    "1 Chronicles": "历代志上",
    "2 Chronicles": "历代志下",
    "Psalms": "诗篇",
    "1 Timothy": "提摩太前书",
    "2 Timothy": "提摩太后书",
    "Titus": "提多书",
    "James": "雅各书",
    "1 John": "约翰一书",
}

ZH_BOOK_MAP_HANT = {
    "Ezra": "以斯拉記",
    "Nehemiah": "尼希米記",
    "1 Chronicles": "歷代志上",
    "2 Chronicles": "歷代志下",
    "Psalms": "詩篇",
    "1 Timothy": "提摩太前書",
    "2 Timothy": "提摩太後書",
    "Titus": "提多書",
    "James": "雅各書",
    "1 John": "約翰一書",
}

# ---------------------------------------------------------------------------
# Image data: list of tuples:
#   (wikimedia_filename_stem, book_name, chapter, image_num)
#
# wikimedia_filename_stem is the part before ".jpg" on Commons.
# The full title passed to the API will be:
#   File:<wikimedia_filename_stem>_(Bible_Illustrations_by_Sweet_Media).jpg
# ---------------------------------------------------------------------------
IMAGES = [
    # === EZRA (10 images) ===
    ("Book_of_Ezra_Chapter_1-1", "Ezra", 1, 1),
    ("Book_of_Ezra_Chapter_9-1", "Ezra", 9, 1),
    ("Book_of_Ezra_Chapter_9-2", "Ezra", 9, 2),
    ("Book_of_Ezra_Chapter_9-3", "Ezra", 9, 3),
    ("Book_of_Ezra_Chapter_10-1", "Ezra", 10, 1),
    ("Book_of_Ezra_Chapter_10-2", "Ezra", 10, 2),
    ("Book_of_Ezra_Chapter_10-3", "Ezra", 10, 3),
    ("Book_of_Ezra_Chapter_10-4", "Ezra", 10, 4),
    ("Book_of_Ezra_Chapter_10-5", "Ezra", 10, 5),
    ("Book_of_Ezra_Chapter_10-6", "Ezra", 10, 6),

    # === NEHEMIAH (11 images) ===
    ("Book_of_Nehemiah_Chapter_1-1", "Nehemiah", 1, 1),
    ("Book_of_Nehemiah_Chapter_2-1", "Nehemiah", 2, 1),
    ("Book_of_Nehemiah_Chapter_2-2", "Nehemiah", 2, 2),
    ("Book_of_Nehemiah_Chapter_2-3", "Nehemiah", 2, 3),
    ("Book_of_Nehemiah_Chapter_2-4", "Nehemiah", 2, 4),
    ("Book_of_Nehemiah_Chapter_2-5", "Nehemiah", 2, 5),
    ("Book_of_Nehemiah_Chapter_3-1", "Nehemiah", 3, 1),
    ("Book_of_Nehemiah_Chapter_4-2", "Nehemiah", 4, 1),
    ("Book_of_Nehemiah_Chapter_4-3", "Nehemiah", 4, 2),
    ("Book_of_Nehemiah_Chapter_6-1", "Nehemiah", 6, 1),
    ("Book_of_Nehemiah_Chapter_6-2", "Nehemiah", 6, 2),

    # === 1 CHRONICLES (15 images) ===
    ("First_Book_of_Chronicles_Chapter_10-1", "1 Chronicles", 10, 1),
    ("First_Book_of_Chronicles_Chapter_10-2", "1 Chronicles", 10, 2),
    ("First_Book_of_Chronicles_Chapter_10-3", "1 Chronicles", 10, 3),
    ("First_Book_of_Chronicles_Chapter_11-1", "1 Chronicles", 11, 1),
    ("First_Book_of_Chronicles_Chapter_13-1", "1 Chronicles", 13, 1),
    ("First_Book_of_Chronicles_Chapter_13-2", "1 Chronicles", 13, 2),
    ("First_Book_of_Chronicles_Chapter_13-3", "1 Chronicles", 13, 3),
    ("First_Book_of_Chronicles_Chapter_13-4", "1 Chronicles", 13, 4),
    ("First_Book_of_Chronicles_Chapter_15-1", "1 Chronicles", 15, 1),
    ("First_Book_of_Chronicles_Chapter_15-2", "1 Chronicles", 15, 2),
    ("First_Book_of_Chronicles_Chapter_17-1", "1 Chronicles", 17, 1),
    ("First_Book_of_Chronicles_Chapter_19-3", "1 Chronicles", 19, 1),
    ("First_Book_of_Chronicles_Chapter_22-1", "1 Chronicles", 22, 1),
    ("First_Book_of_Chronicles_Chapter_24-1", "1 Chronicles", 24, 1),
    ("First_Book_of_Chronicles_Chapter_24-2", "1 Chronicles", 24, 2),

    # === 2 CHRONICLES (11 images) ===
    ("Second_Book_of_Chronicles_Chapter_1-1", "2 Chronicles", 1, 1),
    ("Second_Book_of_Chronicles_Chapter_2-1", "2 Chronicles", 2, 1),
    ("Second_Book_of_Chronicles_Chapter_3-2", "2 Chronicles", 3, 1),
    ("Second_Book_of_Chronicles_Chapter_6-2", "2 Chronicles", 6, 1),
    ("Second_Book_of_Chronicles_Chapter_10-1", "2 Chronicles", 10, 1),
    ("Second_Book_of_Chronicles_Chapter_10-2", "2 Chronicles", 10, 2),
    ("Second_Book_of_Chronicles_Chapter_10-3", "2 Chronicles", 10, 3),
    ("Second_Book_of_Chronicles_Chapter_24-3", "2 Chronicles", 24, 1),
    ("Second_Book_of_Chronicles_Chapter_34-4", "2 Chronicles", 34, 1),
    ("Second_Book_of_Chronicles_Chapter_34-5", "2 Chronicles", 34, 2),
    ("Second_Book_of_Chronicles_Chapter_35-1", "2 Chronicles", 35, 1),

    # === PSALMS (9 images) ===
    ("Psalms_Chapter_23-1", "Psalms", 23, 1),
    ("Psalms_Chapter_23-2", "Psalms", 23, 2),
    ("Psalms_Chapter_23-3", "Psalms", 23, 3),
    ("Psalms_Chapter_25-1", "Psalms", 25, 1),
    ("Psalms_Chapter_31-1", "Psalms", 31, 1),
    ("Psalms_Chapter_51-1", "Psalms", 51, 1),
    ("Psalms_Chapter_52-1", "Psalms", 52, 1),
    ("Psalms_Chapter_119-1", "Psalms", 119, 1),
    ("Psalms_Chapter_119-2", "Psalms", 119, 2),

    # === 1 TIMOTHY (1 image) ===
    ("First_Epistle_to_Timothy_Chapter_1-2", "1 Timothy", 1, 1),

    # === 2 TIMOTHY (8 images) ===
    ("Second_Epistle_to_Timothy_Chapter_1-1", "2 Timothy", 1, 1),
    ("Second_Epistle_to_Timothy_Chapter_2-1", "2 Timothy", 2, 1),
    ("Second_Epistle_to_Timothy_Chapter_2-2", "2 Timothy", 2, 2),
    ("Second_Epistle_to_Timothy_Chapter_2-3", "2 Timothy", 2, 3),
    ("Second_Epistle_to_Timothy_Chapter_4-1", "2 Timothy", 4, 1),
    ("Second_Epistle_to_Timothy_Chapter_4-2", "2 Timothy", 4, 2),
    ("Second_Epistle_to_Timothy_Chapter_4-3", "2 Timothy", 4, 3),
    ("Second_Epistle_to_Timothy_Chapter_4-4", "2 Timothy", 4, 4),

    # === TITUS (1 image) ===
    ("Epistle_to_Titus_Chapter_1-1", "Titus", 1, 1),

    # === JAMES (5 images) ===
    ("Epistle_of_James_Chapter_1-2", "James", 1, 1),
    ("Epistle_of_James_Chapter_2-1", "James", 2, 1),
    ("Epistle_of_James_Chapter_2-2", "James", 2, 2),
    ("Epistle_of_James_Chapter_2-3", "James", 2, 3),
    ("Epistle_of_James_Chapter_2-4", "James", 2, 4),

    # === 1 JOHN (5 images) ===
    ("First_Epistle_of_John_Chapter_2-1", "1 John", 2, 1),
    ("First_Epistle_of_John_Chapter_3-1", "1 John", 3, 1),
    ("First_Epistle_of_John_Chapter_3-2", "1 John", 3, 2),
    ("First_Epistle_of_John_Chapter_3-3", "1 John", 3, 3),
    ("First_Epistle_of_John_Chapter_4-1", "1 John", 4, 1),
]

# Book name used in IDs (lowercase, no spaces)
def book_slug(book: str) -> str:
    """Convert book name to lowercase slug for IDs.
    e.g. '1 Chronicles' -> '1_chronicles', 'Psalms' -> 'psalms'
    """
    return book.lower().replace(" ", "_")


def make_entry_id(book: str, chapter: int, image_num: int) -> str:
    """e.g. 'illus_sweet_ezra_1_1'"""
    return f"illus_sweet_{book_slug(book)}_{chapter}_{image_num}"


# ---------------------------------------------------------------------------
# Wikimedia Commons API helpers
# ---------------------------------------------------------------------------
BATCH_SIZE = 20
API_URL = "https://commons.wikimedia.org/w/api.php"


def full_filename(stem: str) -> str:
    """Return the full file title for the API, e.g.
    'File:Book_of_Ezra_Chapter_1-1_(Bible_Illustrations_by_Sweet_Media).jpg'
    """
    return f"File:{stem}_(Bible_Illustrations_by_Sweet_Media).jpg"


def fetch_urls_batch(stems: list[str], retries: int = 3) -> dict[str, str]:
    """Fetch thumbnail URLs for a batch of filename stems (max BATCH_SIZE).

    Returns {stem: thumburl} for images that were found.
    """
    results: dict[str, str] = {}
    titles = "|".join(full_filename(s) for s in stems)
    body = urllib.parse.urlencode({
        "action": "query",
        "titles": titles,
        "prop": "imageinfo",
        "iiprop": "url",
        "iiurlwidth": "1280",
        "format": "json",
    }).encode("utf-8")

    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(
                API_URL,
                data=body,
                headers={
                    "User-Agent": "YSWordsSweetScript/1.0",
                    "Content-Type": "application/x-www-form-urlencoded",
                },
            )
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read().decode("utf-8"))

            pages = data.get("query", {}).get("pages", {})
            for _pageid, page in pages.items():
                title = page.get("title", "")
                # Wikimedia normalizes underscores to spaces in returned titles.
                # We need to match back to our stem.
                # title e.g. "File:Book of Ezra Chapter 1-1 (Bible Illustrations by Sweet Media).jpg"
                # Extract the stem by removing prefix and suffix
                if not title.startswith("File:"):
                    continue
                name = title[len("File:"):]
                # Remove the suffix " (Bible Illustrations by Sweet Media).jpg"
                suffix = " (Bible Illustrations by Sweet Media).jpg"
                if not name.endswith(suffix):
                    suffix = " (Bible Illustrations by Sweet Media)"  # maybe no .jpg
                    if not name.endswith(suffix):
                        continue
                stem_normalized = name[: -len(suffix)]
                # Convert spaces back to underscores to match our stems
                stem_key = stem_normalized.replace(" ", "_")

                ii = page.get("imageinfo", [])
                if ii:
                    thumb = ii[0].get("thumburl") or ii[0].get("url")
                    if thumb:
                        results[stem_key] = thumb
            return results

        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
            print(f"  [RETRY {attempt}/{retries}] batch starting at {stems[0]}: {exc}")
            time.sleep(5 * attempt)

    return results


# ---------------------------------------------------------------------------
# Build entry helpers
# ---------------------------------------------------------------------------
def build_entry(book: str, chapter: int, image_num: int, file_url: str) -> dict:
    """Build a single maps_index entry."""
    entry_id = make_entry_id(book, chapter, image_num)

    zh_hans = ZH_BOOK_MAP_HANS[book]
    zh_hant = ZH_BOOK_MAP_HANT[book]

    # "Ezra Chapter 1 (Sweet Publishing)"
    title_en = f"{book} Chapter {chapter} (Sweet Publishing)"
    title_zh_hans = f"{zh_hans}第{chapter}章 (Sweet Publishing)"
    title_zh_hant = f"{zh_hant}第{chapter}章 (Sweet Publishing)"

    # "Sweet Publishing, 1984 — Bible illustration, Ezra Chapter 1."
    desc_en = f"Sweet Publishing, {YEAR} — Bible illustration, {book} Chapter {chapter}."
    desc_zh_hans = f"Sweet Publishing,{YEAR}年——圣经插图，{zh_hans}第{chapter}章。"
    desc_zh_hant = f"Sweet Publishing,{YEAR}年——聖經插圖，{zh_hant}第{chapter}章。"

    return {
        "id": entry_id,
        "kind": "scene",
        "title": {
            "en": title_en,
            "zh-Hans": title_zh_hans,
            "zh-Hant": title_zh_hant,
        },
        "description": {
            "en": desc_en,
            "zh-Hans": desc_zh_hans,
            "zh-Hant": desc_zh_hant,
        },
        "books": {book: [chapter, chapter]},
        "file": file_url,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    # 1. Read existing maps_index.json
    with open(MAPS_INDEX_PATH, "r", encoding="utf-8") as f:
        entries = json.load(f)
    print(f"Existing entries: {len(entries)}")

    # 2. Track existing IDs to avoid duplicates
    existing_ids = {e["id"] for e in entries}

    # 3. Filter to images we actually need
    images_to_process = [
        (stem, book, chapter, image_num)
        for stem, book, chapter, image_num in IMAGES
        if make_entry_id(book, chapter, image_num) not in existing_ids
    ]
    print(f"Images needing entries: {len(images_to_process)}")

    if not images_to_process:
        print("No new entries to generate. Done.")
        return

    # 4. Fetch all URLs in batches
    stems_to_fetch = [item[0] for item in images_to_process]
    url_map: dict[str, str] = {}

    total_batches = (len(stems_to_fetch) + BATCH_SIZE - 1) // BATCH_SIZE
    for batch_idx in range(total_batches):
        batch_start = batch_idx * BATCH_SIZE
        batch = stems_to_fetch[batch_start : batch_start + BATCH_SIZE]
        print(
            f"Fetching batch {batch_idx + 1}/{total_batches}"
            f" ({len(batch)} images: {batch[0]} ...)"
        )
        batch_results = fetch_urls_batch(batch)
        url_map.update(batch_results)
        print(f"  Got {len(batch_results)} URLs (cumulative: {len(url_map)})")
        if batch_idx < total_batches - 1:
            time.sleep(2)  # rate limit between batches

    # 5. Generate new entries
    new_entries = []
    for stem, book, chapter, image_num in images_to_process:
        file_url = url_map.get(stem)
        if file_url is None:
            print(f"  [SKIP] No URL for {stem}")
            continue

        entry = build_entry(book, chapter, image_num, file_url)
        new_entries.append(entry)

    print(f"\nGenerated {len(new_entries)} new entries.")

    # 6. Append and write back
    if new_entries:
        entries.extend(new_entries)
        with open(MAPS_INDEX_PATH, "w", encoding="utf-8") as f:
            json.dump(entries, f, indent=2, ensure_ascii=False)
        print(f"Wrote {len(entries)} total entries to {MAPS_INDEX_PATH}")
    else:
        print("No new entries to write.")

    print("Done.")


if __name__ == "__main__":
    main()
