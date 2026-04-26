import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yswords/models/strongs.dart';

/// Lazy loader for Strong's Greek + Hebrew lexicons. The two files are
/// loaded independently the first time a number from that language is
/// requested, so a NT-only session never pays the Hebrew load cost.
class StrongsService {
  static Map<String, StrongsEntry>? _greek;
  static Map<String, StrongsEntry>? _hebrew;
  static Future<Map<String, StrongsEntry>>? _greekLoading;
  static Future<Map<String, StrongsEntry>>? _hebrewLoading;

  static Future<Map<String, StrongsEntry>> _load(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in map.entries)
        entry.key:
            StrongsEntry.fromJson(entry.key, entry.value as Map<String, dynamic>)
    };
  }

  static Future<StrongsEntry?> lookup(String number) async {
    if (number.isEmpty) return null;
    final isGreek = number.startsWith('G');
    final isHebrew = number.startsWith('H');
    if (!isGreek && !isHebrew) return null;
    if (isGreek) {
      _greek ??= await (_greekLoading ??=
          _load('assets/strongs/greek.json'));
      return _greek![number];
    } else {
      _hebrew ??= await (_hebrewLoading ??=
          _load('assets/strongs/hebrew.json'));
      return _hebrew![number];
    }
  }
}
