import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart'
    show bookNameToEnglish, standardBookOrder;

class FetchVerses {
  static Future<void> execute({required MainProvider mainProvider}) async {
    final version = mainProvider.currentVersion.toLowerCase();
    final path = 'assets/$version.json';

    mainProvider.setVerses([]);
    mainProvider.setBooks([]);

    try {
      final verses = await _loadAndParse(path);
      mainProvider.setVerses(verses);
    } catch (e) {
      debugPrint('Error loading verses from $path: $e');
    }
  }

  static Future<List<Verse>> _loadAndParse(String path) async {
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

    // Sort in canonical order
    verses.sort((a, b) {
      final ai = standardBookOrder.indexOf(bookNameToEnglish[a.book] ?? a.book);
      final bi = standardBookOrder.indexOf(bookNameToEnglish[b.book] ?? b.book);
      if (ai != bi) return ai.compareTo(bi);
      final c = a.chapter.compareTo(b.chapter);
      return c != 0 ? c : a.verse.compareTo(b.verse);
    });

    return verses;
  }
}
