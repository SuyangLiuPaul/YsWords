import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart'
    show bookNameToEnglish, standardBookOrder;

/// Lightweight record of paragraph metadata for one verse, used when
/// applying LJK2's hand-curated structure across all Bible versions so the
/// paragraph mode reads consistently regardless of translation.
class _ParaInfo {
  final bool isParagraphStart;
  final String paragraphType;
  const _ParaInfo(this.isParagraphStart, this.paragraphType);
}

class FetchVerses {
  /// LJK2 (biblexg-v2) is the only translation shipped with hand-curated
  /// paragraph metadata. We treat it as the canonical source and replay its
  /// `isParagraphStart` / `paragraphType` flags onto every other version so
  /// readers get consistent paragraph breaks across translations.
  static const _kParagraphRefPath = 'assets/biblexg-v2.json';

  /// Cached map: english-book-name -> "chapter:verse" -> _ParaInfo.
  /// Populated lazily on first load and reused across version switches.
  static Map<String, Map<String, _ParaInfo>>? _paragraphMapCache;

  static Future<Map<String, Map<String, _ParaInfo>>>
      _loadParagraphMap() async {
    if (_paragraphMapCache != null) return _paragraphMapCache!;
    final result = <String, Map<String, _ParaInfo>>{};
    try {
      final jsonString = await rootBundle.loadString(_kParagraphRefPath);
      final dynamic decoded = json.decode(jsonString);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is! Map<String, dynamic>) continue;
          final isStart = entry['isParagraphStart'] == true;
          final pType = (entry['paragraphType'] as String?) ?? 'inline';
          // Only cache rows that actually carry meaningful structure;
          // plain inline non-starts are the default and waste memory.
          if (!isStart && pType == 'inline') continue;
          final bookRaw = (entry['book'] as String?) ?? '';
          final bookEn = bookNameToEnglish[bookRaw] ?? bookRaw;
          final chapter = entry['chapter']?.toString() ?? '';
          final verse = entry['verse']?.toString() ?? '';
          if (bookEn.isEmpty || chapter.isEmpty || verse.isEmpty) continue;
          result
              .putIfAbsent(bookEn, () => <String, _ParaInfo>{})['$chapter:$verse'] =
              _ParaInfo(isStart, pType);
        }
      }
    } catch (e) {
      debugPrint(
          'Could not load paragraph reference ($_kParagraphRefPath): $e');
    }
    _paragraphMapCache = result;
    return result;
  }

  static Future<void> execute({required MainProvider mainProvider}) async {
    final version = mainProvider.currentVersion.toLowerCase();
    final path = 'assets/$version.json';

    mainProvider.setVerses([]);
    mainProvider.setBooks([]);

    try {
      final paraMap = await _loadParagraphMap();
      final verses = await _loadAndParse(path, paraMap);
      mainProvider.setVerses(verses);
    } catch (e) {
      debugPrint('Error loading verses from $path: $e');
    }
  }

  static Future<List<Verse>> _loadAndParse(
    String path,
    Map<String, Map<String, _ParaInfo>> paraMap,
  ) async {
    final jsonString = await rootBundle.loadString(path);
    final dynamic decoded = json.decode(jsonString);

    List<Map<String, dynamic>> rawList;
    if (decoded is List) {
      rawList = List<Map<String, dynamic>>.from(decoded);
    } else if (decoded is Map<String, dynamic> && decoded['passages'] != null) {
      final passages = decoded['passages'] as Map<String, dynamic>;
      final bookName = decoded['abbreviation'] ?? decoded['book'] ?? '';
      rawList = passages.entries.map((e) {
        final parts = e.key.toString().split(':');
        return {
          'book': bookName,
          'chapter': parts.isNotEmpty ? parts[0] : '',
          'verse': parts.length > 1 ? parts[1] : '',
          'text': '${e.value ?? ''}\n',
        };
      }).toList();
    } else {
      throw Exception('Unsupported verse JSON format');
    }

    // Filter out entries where verse is non-numeric
    rawList = rawList
        .where((m) => int.tryParse(m['verse']?.toString() ?? '') != null)
        .toList();

    // Map into Verse objects, skipping any parse errors
    final verses = <Verse>[];
    for (final m in rawList) {
      try {
        verses.add(Verse.fromJson(m));
      } catch (_) {}
    }

    // Apply LJK2's paragraph metadata to every verse so all translations
    // share the same paragraph structure. We only override when LJK2 has a
    // meaningful flag — versions that already carry their own metadata keep
    // theirs unless LJK2 has a stronger signal.
    final enriched = <Verse>[];
    for (final v in verses) {
      final bookEn = bookNameToEnglish[v.book] ?? v.book;
      final info = paraMap[bookEn]?['${v.chapter}:${v.verse}'];
      if (info == null) {
        enriched.add(v);
        continue;
      }
      final needsStart = info.isParagraphStart && !v.isParagraphStart;
      final needsType = info.paragraphType != 'inline' &&
          info.paragraphType != v.paragraphType;
      if (!needsStart && !needsType) {
        enriched.add(v);
      } else {
        enriched.add(v.copyWith(
          isParagraphStart: needsStart ? true : null,
          paragraphType: needsType ? info.paragraphType : null,
        ));
      }
    }

    // Sort in canonical order
    enriched.sort((a, b) {
      final ai = standardBookOrder.indexOf(bookNameToEnglish[a.book] ?? a.book);
      final bi = standardBookOrder.indexOf(bookNameToEnglish[b.book] ?? b.book);
      if (ai != bi) return ai.compareTo(bi);
      final c = a.chapter.compareTo(b.chapter);
      return c != 0 ? c : a.verse.compareTo(b.verse);
    });

    return enriched;
  }
}
