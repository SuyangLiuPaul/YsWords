#!/usr/bin/env python3
"""Generate Old Testament paragraph starts from public-domain WEB USFM.

The app only needs a compact verse-start map, not the WEB text itself. This
script downloads the public-domain World English Bible USFM archive and
extracts OT verse starts that follow USFM block markers such as paragraph and
poetry markers.
"""

from __future__ import annotations

import io
import json
import re
import urllib.request
import zipfile
from pathlib import Path


SOURCE_URL = "https://ebible.org/Scriptures/engwebp_usfm.zip"
OUTPUT_PATH = Path("assets/web-ot-paragraphs.json")

BOOKS = {
    "GEN": "Genesis",
    "EXO": "Exodus",
    "LEV": "Leviticus",
    "NUM": "Numbers",
    "DEU": "Deuteronomy",
    "JOS": "Joshua",
    "JDG": "Judges",
    "RUT": "Ruth",
    "1SA": "1 Samuel",
    "2SA": "2 Samuel",
    "1KI": "1 Kings",
    "2KI": "2 Kings",
    "1CH": "1 Chronicles",
    "2CH": "2 Chronicles",
    "EZR": "Ezra",
    "NEH": "Nehemiah",
    "EST": "Esther",
    "JOB": "Job",
    "PSA": "Psalms",
    "PRO": "Proverbs",
    "ECC": "Ecclesiastes",
    "SNG": "Song of Solomon",
    "ISA": "Isaiah",
    "JER": "Jeremiah",
    "LAM": "Lamentations",
    "EZK": "Ezekiel",
    "DAN": "Daniel",
    "HOS": "Hosea",
    "JOL": "Joel",
    "AMO": "Amos",
    "OBA": "Obadiah",
    "JON": "Jonah",
    "MIC": "Micah",
    "NAM": "Nahum",
    "HAB": "Habakkuk",
    "ZEP": "Zephaniah",
    "HAG": "Haggai",
    "ZEC": "Zechariah",
    "MAL": "Malachi",
}

BLOCK_MARKER = re.compile(r"^\\(p|m|q\d*|pi\d*|mi|li\d*|b)\b")
CHAPTER = re.compile(r"^\\c\s+(\d+)")
VERSE = re.compile(r"\\v\s+(\d+)")
BOOK_FILE = re.compile(r"-(\w{3})engwebp\.usfm$")


def extract_books(archive: zipfile.ZipFile) -> dict[str, dict[str, list[int]]]:
    books: dict[str, dict[str, list[int]]] = {}

    for name in sorted(archive.namelist()):
        file_match = BOOK_FILE.search(name)
        if not file_match:
            continue
        book = BOOKS.get(file_match.group(1))
        if book is None:
            continue

        chapter: int | None = None
        pending_block_start = False
        chapters: dict[str, list[int]] = {}
        text = archive.read(name).decode("utf-8")

        for raw_line in text.splitlines():
            line = raw_line.strip()
            chapter_match = CHAPTER.match(line)
            if chapter_match:
                chapter = int(chapter_match.group(1))
                pending_block_start = True
                continue

            block_match = BLOCK_MARKER.match(line)
            verse_matches = list(VERSE.finditer(line))

            if block_match and verse_matches:
                pending_block_start = True

            if verse_matches:
                if pending_block_start and chapter is not None:
                    verse = int(verse_matches[0].group(1))
                    chapters.setdefault(str(chapter), []).append(verse)
                pending_block_start = False
            elif block_match:
                rest = line[block_match.end() :].strip()
                if not rest:
                    pending_block_start = True

        books[book] = chapters

    return books


def main() -> None:
    with urllib.request.urlopen(SOURCE_URL) as response:
        data = response.read()

    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        books = extract_books(archive)

    output = {
        "source": "World English Bible, public domain, engwebp USFM from eBible.org",
        "sourceUrl": SOURCE_URL,
        "sourceLastUpdated": "2026-03-13",
        "scope": "Canonical Old Testament only",
        "extraction": (
            "Verse starts following USFM block markers "
            "(p, m, q*, pi*, mi, li*, b) are marked as paragraph starts."
        ),
        "books": books,
    }

    OUTPUT_PATH.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    total = sum(len(verses) for chapters in books.values() for verses in chapters.values())
    print(f"Wrote {OUTPUT_PATH} with {total} OT paragraph starts")


if __name__ == "__main__":
    main()
