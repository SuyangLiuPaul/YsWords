#!/usr/bin/env python3
"""Integrate ALL remaining Tissot catalog entries into maps_index.json."""
import json, re, sys

ZH_BOOK_MAP_HANS = {
    "Genesis": "创世记", "Exodus": "出埃及记", "Leviticus": "利未记",
    "Numbers": "民数记", "Deuteronomy": "申命记", "Joshua": "约书亚记",
    "Judges": "士师记", "Ruth": "路得记", "1 Samuel": "撒母耳记上",
    "2 Samuel": "撒母耳记下", "1 Kings": "列王纪上", "2 Kings": "列王纪下",
    "1 Chronicles": "历代志上", "2 Chronicles": "历代志下", "Ezra": "以斯拉记",
    "Nehemiah": "尼希米记", "Esther": "以斯帖记", "Job": "约伯记",
    "Psalms": "诗篇", "Proverbs": "箴言", "Ecclesiastes": "传道书",
    "Song of Solomon": "雅歌", "Isaiah": "以赛亚书", "Jeremiah": "耶利米书",
    "Lamentations": "耶利米哀歌", "Ezekiel": "以西结书", "Daniel": "但以理书",
    "Hosea": "何西阿书", "Joel": "约珥书", "Amos": "阿摩司书",
    "Obadiah": "俄巴底亚书", "Jonah": "约拿书", "Micah": "弥迦书",
    "Nahum": "那鸿书", "Habakkuk": "哈巴谷书", "Zephaniah": "西番雅书",
    "Haggai": "哈该书", "Zechariah": "撒迦利亚书", "Malachi": "玛拉基书",
    "Matthew": "马太福音", "Mark": "马可福音", "Luke": "路加福音",
    "John": "约翰福音", "Acts": "使徒行传", "Romans": "罗马书",
    "1 Corinthians": "哥林多前书", "2 Corinthians": "哥林多后书",
    "Galatians": "加拉太书", "Ephesians": "以弗所书",
    "Philippians": "腓立比书", "Colossians": "歌罗西书",
    "1 Thessalonians": "帖撒罗尼迦前书", "2 Thessalonians": "帖撒罗尼迦后书",
    "1 Timothy": "提摩太前书", "2 Timothy": "提摩太后书", "Titus": "提多书",
    "Philemon": "腓利门书", "Hebrews": "希伯来书", "James": "雅各书",
    "1 Peter": "彼得前书", "2 Peter": "彼得后书", "1 John": "约翰一书",
    "2 John": "约翰二书", "3 John": "约翰三书", "Jude": "犹大书",
    "Revelation": "启示录",
}
ZH_BOOK_MAP_HANT = {
    "Genesis": "創世記", "Exodus": "出埃及記", "Leviticus": "利未記",
    "Numbers": "民數記", "Deuteronomy": "申命記", "Joshua": "約書亞記",
    "Judges": "士師記", "Ruth": "路得記", "1 Samuel": "撒母耳記上",
    "2 Samuel": "撒母耳記下", "1 Kings": "列王紀上", "2 Kings": "列王紀下",
    "1 Chronicles": "歷代志上", "2 Chronicles": "歷代志下", "Ezra": "以斯拉記",
    "Nehemiah": "尼希米記", "Esther": "以斯帖記", "Job": "約伯記",
    "Psalms": "詩篇", "Proverbs": "箴言", "Ecclesiastes": "傳道書",
    "Song of Solomon": "雅歌", "Isaiah": "以賽亞書", "Jeremiah": "耶利米書",
    "Lamentations": "耶利米哀歌", "Ezekiel": "以西結書", "Daniel": "但以理書",
    "Hosea": "何西阿書", "Joel": "約珥書", "Amos": "阿摩司書",
    "Obadiah": "俄巴底亞書", "Jonah": "約拿書", "Micah": "彌迦書",
    "Nahum": "那鴻書", "Habakkuk": "哈巴谷書", "Zephaniah": "西番雅書",
    "Haggai": "哈該書", "Zechariah": "撒迦利亞書", "Malachi": "瑪拉基書",
    "Matthew": "馬太福音", "Mark": "馬可福音", "Luke": "路加福音",
    "John": "約翰福音", "Acts": "使徒行傳", "Romans": "羅馬書",
    "1 Corinthians": "哥林多前書", "2 Corinthians": "哥林多後書",
    "Galatians": "加拉太書", "Ephesians": "以弗所書",
    "Philippians": "腓立比書", "Colossians": "歌羅西書",
    "1 Thessalonians": "帖撒羅尼迦前書", "2 Thessalonians": "帖撒羅尼迦後書",
    "1 Timothy": "提摩太前書", "2 Timothy": "提摩太後書", "Titus": "提多書",
    "Philemon": "腓利門書", "Hebrews": "希伯來書", "James": "雅各書",
    "1 Peter": "彼得前書", "2 Peter": "彼得後書", "1 John": "約翰一書",
    "2 John": "約翰二書", "3 John": "約翰三書", "Jude": "猶大書",
    "Revelation": "啟示錄",
}

def make_id(title):
    s = title.lower()
    s = re.sub(r'[^a-z0-9]+', '_', s)
    s = re.sub(r'_+', '_', s).strip('_')
    return f"illus_tissot_{s}"

def make_desc_en(title, books):
    book_list = ', '.join(f"{b} {c}" for b, chapters in books.items() for c in chapters)
    return f"James Tissot — {title} ({book_list})."

def make_desc_zh(title, books, zmap):
    book_list = ', '.join(f"{zmap.get(b, b)} {c}" for b, chapters in books.items() for c in chapters)
    return f"詹姆斯·蒂索 — {title} ({book_list})。"

def main():
    with open('tissot_catalog.json') as f:
        catalog = json.load(f)
    with open('assets/maps_index.json') as f:
        existing = json.load(f)

    existing_ids = {e['id'] for e in existing}
    existing_files = set()
    for e in existing:
        if 'tissot' in e['id'].lower():
            furl = e.get('file', '')
            fn = furl.split('/')[-1].lower() if furl else ''
            existing_files.add(fn)

    new_entries = []
    skipped = 0
    for entry in catalog:
        fn = entry['fileName']
        fn_norm = fn.replace(' ', '_').lower()

        # Check if already present by filename
        found = any(fn_norm in ef or ef in fn_norm for ef in existing_files)
        if found:
            skipped += 1
            continue

        title = entry['title']
        books = entry.get('books', {})
        if not books:
            continue

        entry_id = make_id(title)
        # Ensure unique ID
        base_id = entry_id
        counter = 2
        while entry_id in existing_ids:
            entry_id = f"{base_id}_{counter}"
            counter += 1
        existing_ids.add(entry_id)

        # Convert chapter arrays to [start, end] format
        books_ranges = {}
        for book, chapters in books.items():
            if not chapters:
                continue
            mn, mx = min(chapters), max(chapters)
            books_ranges[book] = [mn, mx]

        desc_en = make_desc_en(title, books_ranges)
        desc_zh_hans = make_desc_zh(title, books_ranges, ZH_BOOK_MAP_HANS)
        desc_zh_hant = make_desc_zh(title, books_ranges, ZH_BOOK_MAP_HANT)

        new_entries.append({
            "id": entry_id,
            "kind": "scene",
            "title": {
                "en": f"{title} (Tissot)",
                "zh-Hans": f"{title} (蒂索)",
                "zh-Hant": f"{title} (蒂索)",
            },
            "description": {
                "en": desc_en,
                "zh-Hans": desc_zh_hans,
                "zh-Hant": desc_zh_hant,
            },
            "books": books_ranges,
            "file": entry['url'],
        })

    print(f"Catalog: {len(catalog)}, Already present: {skipped}, New: {len(new_entries)}")

    # Append new entries
    existing.extend(new_entries)
    with open('assets/maps_index.json', 'w') as f:
        json.dump(existing, f, ensure_ascii=False, indent=2)

    print(f"Total entries now: {len(existing)}")

if __name__ == '__main__':
    main()
