import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/models/app_settings.dart';

class FetchVerses {
  static Future<void> execute(
      {required MainProvider mainProvider,
      required AppSettings settings}) async {
    final version = mainProvider.currentVersion;
    final path = 'assets/${version.toLowerCase()}.json';

    if (settings.allowUpdates == false) {
      await loadLocalOnly(mainProvider: mainProvider);
      return;
    }

    mainProvider.setVerses([]);
    mainProvider.setBooks([]);

    // Load & parse the JSON from assets, supporting both list and passages-map formats
    String jsonString = await rootBundle.loadString(path);
    final dynamic decoded = json.decode(jsonString);

    // Build a flat list of maps with book, chapter, verse, text
    List<Map<String, dynamic>> rawList;
    if (decoded is List) {
      rawList = List<Map<String, dynamic>>.from(decoded);
    } else if (decoded is Map<String, dynamic> && decoded['passages'] != null) {
      final passages = decoded['passages'] as Map<String, dynamic>;
      final bookName = decoded['abbreviation'] ?? decoded['book'] ?? '';
      rawList = passages.entries.map((e) {
        final parts = e.key.split(':');
        return {
          'book': bookName,
          'chapter': parts[0],
          'verse': parts[1],
          'text': e.value + '\n',
        };
      }).toList();
    } else {
      throw Exception('Unsupported verse JSON format');
    }

    // Filter out entries where verse is non-numeric (e.g. Psalm titles)
    rawList = rawList.where((m) => int.tryParse(m['verse']?.toString() ?? '') != null).toList();

    // Map into Verse objects, skipping any parse errors
    final verses = <Verse>[];
    for (final m in rawList) {
      try {
        verses.add(Verse.fromJson(m));
      } catch (_) {
        // skip invalid entries
      }
    }

    // Sort in canonical order
    const bookOrder = [
      'Genesis','Exodus','Leviticus','Numbers','Deuteronomy','Joshua',
      'Judges','Ruth','1 Samuel','2 Samuel','1 Kings','2 Kings',
      '1 Chronicles','2 Chronicles','Ezra','Nehemiah','Esther','Job',
      'Psalms','Proverbs','Ecclesiastes','Song of Solomon','Isaiah',
      'Jeremiah','Lamentations','Ezekiel','Daniel','Hosea','Joel',
      'Amos','Obadiah','Jonah','Micah','Nahum','Habakkuk',
      'Zechariah','Haggai','Malachi','Matthew','Mark','Luke','John',
      'Acts','Romans','1 Corinthians','2 Corinthians','Galatians',
      'Ephesians','Philippians','Colossians','1 Thessalonians',
      '2 Thessalonians','1 Timothy','2 Timothy','Titus','Philemon',
      'Hebrews','James','1 Peter','2 Peter','1 John','2 John',
      '3 John','Jude','Revelation'
    ];
    verses.sort((a, b) {
      final ai = bookOrder.indexOf(a.book);
      final bi = bookOrder.indexOf(b.book);
      if (ai != bi) return ai.compareTo(bi);
      final c = a.chapter.compareTo(b.chapter);
      return c != 0 ? c : a.verse.compareTo(b.verse);
    });

    // Update provider
    mainProvider.setVerses(verses);
  }

  static Future<void> loadLocalOnly(
      {required MainProvider mainProvider}) async {
    try {
      // Determine the asset file based on the current version
      final version = mainProvider.currentVersion.toLowerCase();
      final path = 'assets/$version.json';

      // Clear existing verses and books
      mainProvider.setVerses([]);
      mainProvider.setBooks([]);

      // Load & parse the JSON from assets, supporting both list and passages-map formats
      String jsonString = await rootBundle.loadString(path);
      final dynamic decoded = json.decode(jsonString);

      // Build a flat list of maps with book, chapter, verse, text
      List<Map<String, dynamic>> rawList;
      if (decoded is List) {
        rawList = List<Map<String, dynamic>>.from(decoded);
      } else if (decoded is Map<String, dynamic> && decoded['passages'] != null) {
        final passages = decoded['passages'] as Map<String, dynamic>;
        final bookName = decoded['abbreviation'] ?? decoded['book'] ?? '';
        rawList = passages.entries.map((e) {
          final parts = e.key.split(':');
          return {
            'book': bookName,
            'chapter': parts[0],
            'verse': parts[1],
            'text': e.value + '\n',
          };
        }).toList();
      } else {
        throw Exception('Unsupported verse JSON format');
      }

      // Filter out entries where verse is non-numeric (e.g. Psalm titles)
      rawList = rawList.where((m) => int.tryParse(m['verse']?.toString() ?? '') != null).toList();

      // Map into Verse objects, skipping any parse errors
      final verses = <Verse>[];
      for (final m in rawList) {
        try {
          verses.add(Verse.fromJson(m));
        } catch (_) {
          // skip invalid entries
        }
      }

      // Sort in canonical order
      const bookOrder = [
        'Genesis','Exodus','Leviticus','Numbers','Deuteronomy','Joshua',
        'Judges','Ruth','1 Samuel','2 Samuel','1 Kings','2 Kings',
        '1 Chronicles','2 Chronicles','Ezra','Nehemiah','Esther','Job',
        'Psalms','Proverbs','Ecclesiastes','Song of Solomon','Isaiah',
        'Jeremiah','Lamentations','Ezekiel','Daniel','Hosea','Joel',
        'Amos','Obadiah','Jonah','Micah','Nahum','Habakkuk',
        'Zechariah','Haggai','Malachi','Matthew','Mark','Luke','John',
        'Acts','Romans','1 Corinthians','2 Corinthians','Galatians',
        'Ephesians','Philippians','Colossians','1 Thessalonians',
        '2 Thessalonians','1 Timothy','2 Timothy','Titus','Philemon',
        'Hebrews','James','1 Peter','2 Peter','1 John','2 John',
        '3 John','Jude','Revelation'
      ];
      verses.sort((a, b) {
        final ai = bookOrder.indexOf(a.book);
        final bi = bookOrder.indexOf(b.book);
        if (ai != bi) return ai.compareTo(bi);
        final c = a.chapter.compareTo(b.chapter);
        return c != 0 ? c : a.verse.compareTo(b.verse);
      });

      // Update provider
      mainProvider.setVerses(verses);
      print('Loaded local $path verses.');
    } catch (e) {
      print(
          'Error loading local verses for version ${mainProvider.currentVersion}: $e');
    }
  }

  static Future<bool> testLoadLocal() async {
    final List<String> assetPaths = [
      'assets/kjv.json',
      'assets/leb.json',
      'assets/cuvs-yhwh.json',
      'assets/cuvs-yhwh-tr.json',
      'assets/biblexg.json',
      'assets/biblexg-tr.json',
      'assets/app_icon.png',
      'assets/loading.png',
      'assets/fonts/Microsoft Yahei.ttf',
      'assets/fonts/Roboto-VariableFont_wdth,wght.ttf',
    ];

    try {
      for (final path in assetPaths) {
        await rootBundle.load(path);
      }
      return true;
    } catch (e) {
      print('Local resource not fully ready: $e');
      return false;
    }
  }
}
