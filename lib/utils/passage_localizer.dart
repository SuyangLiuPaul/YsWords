import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;

/// Pattern that detects English (full + abbreviated) and Chinese
/// (Simplified + Traditional) Bible references inside free-form
/// text. Used by the sermon list, sermon detail body, and any other
/// surface that wants to rewrite English abbreviations into the
/// reader's preferred locale ("Mt 5:27-30" → "马太福音 5:27-30").
///
/// Each match is the **whole reference** including chapter and
/// verse fragment. The book name itself is recoverable by feeding
/// the matched text through [parseReference].
final RegExp passageRefPattern = RegExp(
  // ── English ──────────────────────────────────────────────────
  r'(?:\b(?:[1-3]\s?)?'
  r'(?:Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|'
  r'Samuel|Kings|Chronicles|Ezra|Nehemiah|Esther|Job|Psalms?|Proverbs|'
  r'Ecclesiastes|Song(?:\s+of\s+(?:Solomon|Songs))?|Isaiah|Jeremiah|'
  r'Lamentations|Ezekiel|Daniel|Hosea|Joel|Amos|Obadiah|Jonah|Micah|'
  r'Nahum|Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|Matthew|Mark|'
  r'Luke|John|Acts|Romans|Corinthians|Galatians|Ephesians|Philippians|'
  r'Colossians|Thessalonians|Timothy|Titus|Philemon|Hebrews|James|'
  r'Peter|Jude|Revelation|'
  r'Gen|Exo|Exod|Lev|Num|Deut|Josh|Judg|Ru|1Sam|2Sam|1Kgs|2Kgs|1Chr|'
  r'2Chr|Neh|Est|Ps|Prv|Prov|Eccl|Isa|Jer|Lam|Ezek|Eze|Dan|Hos|Jl|'
  r'Am|Obad|Jonah|Mic|Nah|Hab|Zeph|Hag|Zech|Mal|Matt|Mt|Mk|Lk|Jn|'
  r'Rom|Cor|Gal|Eph|Phil|Col|Thess|Tim|Heb|Pet|Rev)'
  r'\.?\s*\d+(?:\s*[:.]\s*\d+(?:\s*[-–]\s*\d+)?)?)'
  // ── Chinese (full Simplified + Traditional book names) ──────
  r'|(?:'
  // Old Testament — Simplified
  r'创世纪|创世记|出埃及记|利未记|民数记|申命记|约书亚记|士师记|路得记|'
  r'撒母耳记上|撒母耳记下|列王纪上|列王纪下|历代志上|历代志下|'
  r'以斯拉记|尼希米记|以斯帖记|约伯记|诗篇|箴言|传道书|雅歌|'
  r'以赛亚书|耶利米书|耶利米哀歌|以西结书|但以理书|何西阿书|约珥书|'
  r'阿摩司书|俄巴底亚书|约拿书|弥迦书|那鸿书|哈巴谷书|西番雅书|'
  r'哈该书|撒迦利亚书|玛拉基书|'
  // New Testament — Simplified
  r'马太福音|马可福音|路加福音|约翰福音|使徒行传|罗马书|'
  r'哥林多前书|哥林多后书|加拉太书|以弗所书|腓立比书|歌罗西书|'
  r'帖撒罗尼迦前书|帖撒罗尼迦后书|提摩太前书|提摩太后书|提多书|'
  r'腓利门书|希伯来书|雅各书|彼得前书|彼得后书|'
  r'约翰一书|约翰二书|约翰三书|犹大书|启示录|'
  // Old Testament — Traditional
  r'創世紀|創世記|出埃及記|利未記|民數記|申命記|約書亞記|士師記|路得記|'
  r'撒母耳記上|撒母耳記下|列王紀上|列王紀下|歷代志上|歷代志下|'
  r'以斯拉記|尼希米記|以斯帖記|約伯記|詩篇|箴言|傳道書|雅歌|'
  r'以賽亞書|耶利米書|耶利米哀歌|以西結書|但以理書|何西阿書|約珥書|'
  r'阿摩司書|俄巴底亞書|約拿書|彌迦書|那鴻書|哈巴谷書|西番雅書|'
  r'哈該書|撒迦利亞書|瑪拉基書|'
  // New Testament — Traditional
  r'馬太福音|馬可福音|路加福音|約翰福音|使徒行傳|羅馬書|'
  r'哥林多前書|哥林多後書|加拉太書|以弗所書|腓立比書|歌羅西書|'
  r'帖撒羅尼迦前書|帖撒羅尼迦後書|提摩太前書|提摩太後書|提多書|'
  r'腓利門書|希伯來書|雅各書|彼得前書|彼得後書|'
  r'約翰一書|約翰二書|約翰三書|猶大書|啟示錄'
  r')\s*\d+(?:\s*[:：.]\s*\d+(?:\s*[-–]\s*\d+)?)?',
  caseSensitive: false,
);

/// Rewrite a free-form passage like `Mt 7:21-27 and Lk 6:46-49` into
/// the reader's locale (`马太福音 7:21-27 and 路加福音 6:46-49`).
///
/// Each detected reference is replaced with the locale-aware book
/// name + chapter:verse tail; non-reference fragments (e.g. " and ",
/// commas, surrounding prose) are left untouched. When [locale] is
/// English the input is returned unchanged.
String localizePassage(String passage, String locale) {
  if (!locale.startsWith('zh') || passage.isEmpty) return passage;
  final buf = StringBuffer();
  var idx = 0;
  for (final m in passageRefPattern.allMatches(passage)) {
    if (m.start > idx) buf.write(passage.substring(idx, m.start));
    final matched = m.group(0)!;
    final parsed = parseReference(matched);
    if (parsed == null) {
      buf.write(matched);
    } else {
      final book = localeAwareBookName(parsed.englishBook, locale);
      buf.write(book);
      buf.write(' ${parsed.chapter}');
      if (parsed.verseStart != null) {
        buf.write(':${parsed.verseStart}');
        if (parsed.verseEnd != null && parsed.verseEnd! > parsed.verseStart!) {
          buf.write('-${parsed.verseEnd}');
        }
      }
    }
    idx = m.end;
  }
  if (idx < passage.length) buf.write(passage.substring(idx));
  return buf.toString();
}
