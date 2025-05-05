import json
from pathlib import Path


def add_verse_ids(json_file_path: str, language: str = "english") -> None:
    simplified_books = {
        "创世纪": 1, "出埃及记": 2, "利未记": 3, "民数记": 4, "申命记": 5,
        "约书亚记": 6, "士师记": 7, "路得记": 8, "撒母耳记上": 9, "撒母耳记下": 10,
        "列王纪上": 11, "列王纪下": 12, "历代志上": 13, "历代志下": 14,
        "以斯拉记": 15, "尼希米记": 16, "以斯帖记": 17, "约伯记": 18, "诗篇": 19,
        "箴言": 20, "传道书": 21, "雅歌": 22, "以赛亚书": 23, "耶利米书": 24,
        "耶利米哀歌": 25, "以西结书": 26, "但以理书": 27, "何西阿书": 28, "约珥书": 29,
        "阿摩司书": 30, "俄巴底亚书": 31, "约拿书": 32, "弥迦书": 33, "那鸿书": 34,
        "哈巴谷书": 35, "西番雅书": 36, "哈该书": 37, "撒迦利亚书": 38, "玛拉基书": 39,
        "马太福音": 40, "马可福音": 41, "路加福音": 42, "约翰福音": 43, "使徒行传": 44,
        "罗马书": 45, "哥林多前书": 46, "哥林多后书": 47, "加拉太书": 48, "以弗所书": 49,
        "腓立比书": 50, "歌罗西书": 51, "帖撒罗尼迦前书": 52, "帖撒罗尼迦后书": 53,
        "提摩太前书": 54, "提摩太后书": 55, "提多书": 56, "腓利门书": 57, "希伯来书": 58,
        "雅各书": 59, "彼得前书": 60, "彼得后书": 61, "约翰一书": 62, "约翰二书": 63,
        "约翰三书": 64, "犹大书": 65, "启示录": 66
    }

    traditional_books = {
        "創世紀": 1, "出埃及記": 2, "利未記": 3, "民數記": 4, "申命記": 5,
        "約書亞記": 6, "士師記": 7, "路得記": 8, "撒母耳記上": 9, "撒母耳記下": 10,
        "列王紀上": 11, "列王紀下": 12, "歷代志上": 13, "歷代志下": 14,
        "以斯拉記": 15, "尼希米記": 16, "以斯帖記": 17, "約伯記": 18, "詩篇": 19,
        "箴言": 20, "傳道書": 21, "雅歌": 22, "以賽亞書": 23, "耶利米書": 24,
        "耶利米哀歌": 25, "以西結書": 26, "但以理書": 27, "何西阿書": 28, "約珥書": 29,
        "阿摩司書": 30, "俄巴底亞書": 31, "約拿書": 32, "彌迦書": 33, "那鴻書": 34,
        "哈巴谷書": 35, "西番雅書": 36, "哈該書": 37, "撒迦利亞書": 38, "瑪拉基書": 39,
        "馬太福音": 40, "馬可福音": 41, "路加福音": 42, "約翰福音": 43, "使徒行傳": 44,
        "羅馬書": 45, "哥林多前書": 46, "哥林多後書": 47, "加拉太書": 48, "以弗所書": 49,
        "腓立比書": 50, "歌羅西書": 51, "帖撒羅尼迦前書": 52, "帖撒羅尼迦後書": 53,
        "提摩太前書": 54, "提摩太後書": 55, "提多書": 56, "腓利門書": 57, "希伯來書": 58,
        "雅各書": 59, "彼得前書": 60, "彼得後書": 61, "約翰一書": 62, "約翰二書": 63,
        "約翰三書": 64, "猶大書": 65, "啟示錄": 66
    }

    english_books = {
        "Genesis": 1, "Exodus": 2, "Leviticus": 3, "Numbers": 4, "Deuteronomy": 5,
        "Joshua": 6, "Judges": 7, "Ruth": 8, "1 Samuel": 9, "2 Samuel": 10,
        "1 Kings": 11, "2 Kings": 12, "1 Chronicles": 13, "2 Chronicles": 14,
        "Ezra": 15, "Nehemiah": 16, "Esther": 17, "Job": 18, "Psalms": 19,
        "Proverbs": 20, "Ecclesiastes": 21, "Song of Solomon": 22, "Isaiah": 23, "Jeremiah": 24,
        "Lamentations": 25, "Ezekiel": 26, "Daniel": 27, "Hosea": 28, "Joel": 29,
        "Amos": 30, "Obadiah": 31, "Jonah": 32, "Micah": 33, "Nahum": 34,
        "Habakkuk": 35, "Zephaniah": 36, "Haggai": 37, "Zechariah": 38, "Malachi": 39,
        "Matthew": 40, "Mark": 41, "Luke": 42, "John": 43, "Acts": 44,
        "Romans": 45, "1 Corinthians": 46, "2 Corinthians": 47, "Galatians": 48, "Ephesians": 49,
        "Philippians": 50, "Colossians": 51, "1 Thessalonians": 52, "2 Thessalonians": 53,
        "1 Timothy": 54, "2 Timothy": 55, "Titus": 56, "Philemon": 57, "Hebrews": 58,
        "James": 59, "1 Peter": 60, "2 Peter": 61, "1 John": 62, "2 John": 63,
        "3 John": 64, "Jude": 65, "Revelation": 66
    }

    if language == "simplified":
        book_map = simplified_books
    elif language == "traditional":
        book_map = traditional_books
    elif language == "english":
        book_map = english_books
    else:
        raise ValueError("Unsupported language")

    json_path = Path(json_file_path)

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    for verse in data:
        book_name = verse.get("book", "")
        chapter_str = str(verse.get("chapter", "")).strip()
        verse_str = str(verse.get("verse", "")).strip()

        if not chapter_str.isdigit() or not verse_str.isdigit():
            verse["id"] = None
            continue

        book_num = book_map.get(book_name, 0)
        chapter = int(chapter_str)
        verse_no = int(verse_str)
        verse["id"] = f"{book_num:03d}{chapter:03d}{verse_no:03d}"

    output_path = json_path.with_name(json_path.stem + ".json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"Saved with ID to: {output_path}")


# Example usage:
add_verse_ids("/Users/paul/Downloads/cuvs-yhwh.json", language="simplified")
add_verse_ids("/Users/paul/Downloads/cuvs-yhwh-tr.json",language="traditional")
add_verse_ids("/Users/paul/Downloads/kjv.json", language="english")
add_verse_ids("/Users/paul/Downloads/leb.json", language="english")
add_verse_ids("/Users/paul/Downloads/biblexg.json", language="simplified")
add_verse_ids("/Users/paul/Downloads/biblexg-tr.json", language="traditional")
