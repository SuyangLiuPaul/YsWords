#!/usr/bin/env python3
"""
Fetch Bible versions from public APIs and convert to YsWords JSON format.

Supported sources:
  - getbible.net (free, no key): CUV (cus/cut), CNV (cns/cnt)
  - api.bible (requires --api-key): NASB, NIV, and others

Usage:
  python3 tools/fetch_bible_versions.py cus cuv.json
  python3 tools/fetch_bible_versions.py cut cuv-tr.json
  python3 tools/fetch_bible_versions.py cns cnv.json
  python3 tools/fetch_bible_versions.py cnt cnv-tr.json
  python3 tools/fetch_bible_versions.py --api-key YOUR_KEY NASB nasb.json
  python3 tools/fetch_bible_versions.py --api-key YOUR_KEY NIV niv.json
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error

# Standard 66-book ordering with chapter counts (KJV numbering)
BOOKS = [
    ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36),
    ("Deuteronomy", 34), ("Joshua", 24), ("Judges", 21), ("Ruth", 4),
    ("1 Samuel", 31), ("2 Samuel", 24), ("1 Kings", 22), ("2 Kings", 25),
    ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10), ("Nehemiah", 13),
    ("Esther", 10), ("Job", 42), ("Psalms", 150), ("Proverbs", 31),
    ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66),
    ("Jeremiah", 52), ("Lamentations", 5), ("Ezekiel", 48), ("Daniel", 12),
    ("Hosea", 14), ("Joel", 3), ("Amos", 9), ("Obadiah", 1), ("Jonah", 4),
    ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3), ("Zephaniah", 3),
    ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4),
    ("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21), ("Acts", 28),
    ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13),
    ("Galatians", 6), ("Ephesians", 6), ("Philippians", 4), ("Colossians", 4),
    ("1 Thessalonians", 5), ("2 Thessalonians", 3),
    ("1 Timothy", 6), ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1),
    ("Hebrews", 13), ("James", 5), ("1 Peter", 5), ("2 Peter", 3),
    ("1 John", 5), ("2 John", 1), ("3 John", 1), ("Jude", 1), ("Revelation", 22),
]

# Book number mapping (1-based, KJV order)
BOOK_NUMBER = {name: i + 1 for i, (name, _) in enumerate(BOOKS)}

# getbible.net book number mapping (same as KJV order)
GETBIBLE_BOOK_MAP = {name: i + 1 for i, (name, _) in enumerate(BOOKS)}


def make_verse_id(book_num: int, chapter: int, verse: int) -> str:
    """Generate BBBCCCVVV format verse ID."""
    return f"{book_num:03d}{chapter:03d}{verse:03d}"


def strip_bom(s: str) -> str:
    """Remove BOM and leading/trailing whitespace."""
    return s.replace('﻿', '').strip()


def fetch_getbible(version_id: str, output_path: str):
    """Fetch a complete Bible version from getbible.net (whole-book downloads)."""
    base_url = f"https://api.getbible.net/v2/{version_id}"
    all_verses = []
    headers = {"User-Agent": "YsWords/1.0 (Bible Reader App)"}

    for book_idx, (book_name, chapter_count) in enumerate(BOOKS):
        book_num = GETBIBLE_BOOK_MAP[book_name]
        book_verses = []

        # Download entire book at once
        url = f"{base_url}/{book_num}.json"
        data = None
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers=headers)
                with urllib.request.urlopen(req, timeout=60) as resp:
                    data = json.loads(resp.read().decode('utf-8'))
                break
            except Exception as e:
                if attempt < 2:
                    print(f"  Retry {attempt+1} for {book_name}: {e}")
                    time.sleep(5)
                else:
                    print(f"  FAILED {book_name} after 3 attempts: {e}")

        if data is None:
            continue

        # Whole-book response has 'chapters' list, each with 'verses'
        api_book_name = strip_bom(data.get("name", data.get("book_name", book_name)))
        chapters = data.get("chapters", [])
        for chap_data in chapters:
            chapter = chap_data.get("chapter", 0)
            if chapter == 0:
                continue
            for v in chap_data.get("verses", []):
                verse_num = v["verse"]
                text = strip_bom(v["text"]).rstrip()
                if not text:
                    continue
                vid = make_verse_id(book_num, chapter, verse_num)
                book_verses.append({
                    "book": api_book_name,
                    "chapter": str(chapter),
                    "verse": str(verse_num),
                    "text": text,
                    "id": vid,
                })

        all_verses.extend(book_verses)
        print(f"  {book_name}: {len(book_verses)} verses")
        time.sleep(0.5)  # Rate limiting between books

    # Write output
    os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(all_verses, f, ensure_ascii=False, indent=2)

    total = len(all_verses)
    print(f"\nDone! {total} verses written to {output_path}")


def fetch_apibible(api_key: str, version_id: str, output_path: str):
    """Fetch a complete Bible version from api.bible (chapter-level text parsing)."""
    base_url = "https://rest.api.bible/v1/bibles"
    headers = {"api-key": api_key}

    # Look up Bible ID
    req = urllib.request.Request(f"{base_url}?abbreviation={version_id}", headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        bibles = json.loads(resp.read().decode('utf-8'))

    bible_data = None
    for b in bibles.get("data", []):
        if b.get("abbreviation", "").upper() == version_id.upper():
            bible_data = b
            break
    if not bible_data:
        for b in bibles.get("data", []):
            if version_id.upper() in b.get("name", "").upper() or \
               version_id.upper() in b.get("abbreviation", "").upper() or \
               b.get("abbreviation", "").upper().startswith(version_id.upper()):
                bible_data = b
                break
    if not bible_data:
        print(f"Version '{version_id}' not found.")
        for b in bibles.get("data", [])[:20]:
            print(f"  {b['abbreviation']}: {b['name']} ({b['id']})")
        sys.exit(1)

    bible_id = bible_data["id"]
    print(f"Found: {bible_data['name']} (ID: {bible_id})")

    # Get books list
    req = urllib.request.Request(f"{base_url}/{bible_id}/books", headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        books_data = json.loads(resp.read().decode('utf-8'))

    all_verses = []
    for book_entry in books_data.get("data", []):
        book_abbr = book_entry["id"]
        book_name = book_entry["name"]
        std_name = map_apibible_book(book_name, book_abbr)
        book_num = BOOK_NUMBER.get(std_name, 0)
        if book_num == 0:
            print(f"  SKIP unknown book: {book_name} ({book_abbr})")
            continue

        book_verses = []

        # Get chapters list
        req = urllib.request.Request(
            f"{base_url}/{bible_id}/books/{book_abbr}/chapters",
            headers=headers
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            chapters_data = json.loads(resp.read().decode('utf-8'))

        for chap_entry in chapters_data.get("data", []):
            chap_id = chap_entry["id"]
            if "intro" in chap_id.lower():
                continue
            try:
                chap_num = int(chap_id.split(".")[-1])
            except ValueError:
                continue

            # Fetch chapter content (text format) — contains all verses
            url = f"{base_url}/{bible_id}/chapters/{chap_id}?content-type=text"
            for attempt in range(3):
                try:
                    req = urllib.request.Request(url, headers=headers)
                    with urllib.request.urlopen(req, timeout=30) as resp:
                        chap_detail = json.loads(resp.read().decode('utf-8'))
                    break
                except Exception as e:
                    if attempt < 2:
                        print(f"  Retry {attempt+1} for {std_name} {chap_num}: {e}")
                        time.sleep(3)
                    else:
                        print(f"  FAILED {std_name} {chap_num}: {e}")
                        chap_detail = {"data": {"content": ""}}

            content = chap_detail.get("data", {}).get("content", "")
            if not content:
                continue

            # Parse verses from content like: [1] Text here.  [2] More text.
            # Split on [number] patterns
            parts = re.split(r'\[(\d+)\]', content)
            # parts[0] is before first verse (section title), then alternating: number, text
            i = 1  # skip potential leading text
            while i + 1 < len(parts):
                verse_num_str = parts[i].strip()
                verse_text = parts[i + 1].strip()
                try:
                    verse_num = int(verse_num_str)
                except ValueError:
                    i += 2
                    continue
                if not verse_text:
                    i += 2
                    continue
                vid = make_verse_id(book_num, chap_num, verse_num)
                book_verses.append({
                    "book": std_name,
                    "chapter": str(chap_num),
                    "verse": str(verse_num),
                    "text": verse_text,
                    "id": vid,
                })
                i += 2

            time.sleep(0.3)

        all_verses.extend(book_verses)
        print(f"  {std_name}: {len(book_verses)} verses")
        time.sleep(0.5)

    os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(all_verses, f, ensure_ascii=False, indent=2)

    total = len(all_verses)
    print(f"\nDone! {total} verses written to {output_path}")


def map_apibible_book(name: str, abbr: str) -> str:
    """Map api.bible book name/abbreviation to standard English name."""
    # Common mappings
    mapping = {
        # Full names
        "Genesis": "Genesis", "Exodus": "Exodus", "Leviticus": "Leviticus",
        "Numbers": "Numbers", "Deuteronomy": "Deuteronomy",
        "Joshua": "Joshua", "Judges": "Judges", "Ruth": "Ruth",
        "1 Samuel": "1 Samuel", "2 Samuel": "2 Samuel",
        "1 Kings": "1 Kings", "2 Kings": "2 Kings",
        "1 Chronicles": "1 Chronicles", "2 Chronicles": "2 Chronicles",
        "Ezra": "Ezra", "Nehemiah": "Nehemiah", "Esther": "Esther",
        "Job": "Job", "Psalms": "Psalms", "Psalm": "Psalms",
        "Proverbs": "Proverbs", "Ecclesiastes": "Ecclesiastes",
        "Song of Solomon": "Song of Solomon", "Song of Songs": "Song of Solomon",
        "Isaiah": "Isaiah", "Jeremiah": "Jeremiah",
        "Lamentations": "Lamentations", "Ezekiel": "Ezekiel",
        "Daniel": "Daniel", "Hosea": "Hosea", "Joel": "Joel",
        "Amos": "Amos", "Obadiah": "Obadiah", "Jonah": "Jonah",
        "Micah": "Micah", "Nahum": "Nahum", "Habakkuk": "Habakkuk",
        "Zephaniah": "Zephaniah", "Haggai": "Haggai",
        "Zechariah": "Zechariah", "Malachi": "Malachi",
        "Matthew": "Matthew", "Mark": "Mark", "Luke": "Luke",
        "John": "John", "Acts": "Acts", "Romans": "Romans",
        "1 Corinthians": "1 Corinthians", "2 Corinthians": "2 Corinthians",
        "Galatians": "Galatians", "Ephesians": "Ephesians",
        "Philippians": "Philippians", "Colossians": "Colossians",
        "1 Thessalonians": "1 Thessalonians", "2 Thessalonians": "2 Thessalonians",
        "1 Timothy": "1 Timothy", "2 Timothy": "2 Timothy",
        "Titus": "Titus", "Philemon": "Philemon",
        "Hebrews": "Hebrews", "James": "James",
        "1 Peter": "1 Peter", "2 Peter": "2 Peter",
        "1 John": "1 John", "2 John": "2 John", "3 John": "3 John",
        "Jude": "Jude", "Revelation": "Revelation",
        # Common abbreviations (NASB etc.)
        "Gen": "Genesis", "Exod": "Exodus", "Lev": "Leviticus",
        "Num": "Numbers", "Deut": "Deuteronomy",
        "Josh": "Joshua", "Judg": "Judges",
        "1Sam": "1 Samuel", "2Sam": "2 Samuel",
        "1Kgs": "1 Kings", "2Kgs": "2 Kings",
        "1Chr": "1 Chronicles", "2Chr": "2 Chronicles",
        "Neh": "Nehemiah", "Esth": "Esther",
        "Ps": "Psalms", "Prov": "Proverbs", "Eccl": "Ecclesiastes",
        "Song": "Song of Solomon",
        "Isa": "Isaiah", "Jer": "Jeremiah", "Lam": "Lamentations",
        "Ezek": "Ezekiel", "Dan": "Daniel", "Hos": "Hosea",
        "Obad": "Obadiah", "Jon": "Jonah",
        "Mic": "Micah", "Nah": "Nahum", "Hab": "Habakkuk",
        "Zeph": "Zephaniah", "Hag": "Haggai", "Zech": "Zechariah",
        "Mal": "Malachi", "Matt": "Matthew",
        "Rom": "Romans", "1Cor": "1 Corinthians", "2Cor": "2 Corinthians",
        "Gal": "Galatians", "Eph": "Ephesians",
        "Phil": "Philippians", "Col": "Colossians",
        "1Thess": "1 Thessalonians", "2Thess": "2 Thessalonians",
        "1Tim": "1 Timothy", "2Tim": "2 Timothy",
        "Phlm": "Philemon", "Heb": "Hebrews",
        "1Pet": "1 Peter", "2Pet": "2 Peter",
        "1John": "1 John", "2John": "2 John", "3John": "3 John",
        "Rev": "Revelation",
        # NIV-style dotted abbreviations
        "Gen.": "Genesis", "Lev.": "Leviticus", "Num.": "Numbers",
        "Deut.": "Deuteronomy", "Neh.": "Nehemiah",
        "Prov.": "Proverbs", "Eccles.": "Ecclesiastes",
        "Jer.": "Jeremiah", "Ezek.": "Ezekiel",
        "Hab.": "Habakkuk", "Zech.": "Zechariah", "Mal.": "Malachi",
        "Matt.": "Matthew", "1 Cor.": "1 Corinthians", "2 Cor.": "2 Corinthians",
        "Phil.": "Philippians",
        "1 Thes.": "1 Thessalonians", "2 Thes.": "2 Thessalonians",
        "1 Tim.": "1 Timothy", "2 Tim.": "2 Timothy",
        "Heb.": "Hebrews",
        "1 Chron.": "1 Chronicles", "2 Chron.": "2 Chronicles",
    }
    # Try full name first, then abbreviation
    return mapping.get(name, mapping.get(abbr, name))


def main():
    parser = argparse.ArgumentParser(
        description="Fetch Bible versions and convert to YsWords JSON format"
    )
    parser.add_argument("version", help="Version ID (e.g. cus, cut, cns, cnt, NASB, NIV)")
    parser.add_argument("output", help="Output JSON file path (e.g. assets/cuv.json)")
    parser.add_argument("--api-key", help="api.bible API key (required for NASB, NIV)")
    args = parser.parse_args()

    version = args.version.lower()
    # getbible.net versions (Chinese)
    getbible_ids = {"cus", "cut", "cns", "cnt"}

    if version in getbible_ids:
        print(f"Fetching {version} from getbible.net...")
        fetch_getbible(version, args.output)
    elif args.api_key:
        print(f"Fetching {args.version} from api.bible...")
        fetch_apibible(args.api_key, args.version, args.output)
    else:
        print(f"Error: '{args.version}' requires --api-key for api.bible")
        print("Free getbible.net versions: cus, cut, cns, cnt")
        sys.exit(1)


if __name__ == "__main__":
    main()
