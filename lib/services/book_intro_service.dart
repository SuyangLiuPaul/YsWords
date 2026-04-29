// _LocalizedText / _LocalizedList are deliberately private — they're
// internal value objects whose only public API is the getX(locale)
// accessors on BookIntro. The lint warnings about private types in
// the BookIntro constructor are spurious for this internal-only use.
// ignore_for_file: library_private_types_in_public_api

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Localized text bundle. Each field can be looked up via the
/// active app locale (`zh-Hans`, `zh-Hant`, `en`).
class _LocalizedText {
  final Map<String, String> _byLang;
  const _LocalizedText(this._byLang);

  String get(String locale) {
    return _byLang[locale] ?? _byLang['en'] ?? _byLang.values.firstOrNull ?? '';
  }
}

class _LocalizedList {
  final Map<String, List<String>> _byLang;
  const _LocalizedList(this._byLang);

  List<String> get(String locale) {
    return _byLang[locale] ??
        _byLang['en'] ??
        (_byLang.values.firstOrNull ?? const <String>[]);
  }
}

/// One book's introduction card data. Authored in Chinese (Hans + Hant)
/// and English. Surfaces in the reading pane above chapter 1.
class BookIntro {
  final String englishBook;
  final _LocalizedText _subtitle;
  final _LocalizedText _summary;
  final _LocalizedText _author;
  final _LocalizedText _date;
  final _LocalizedText _audience;
  final _LocalizedList _themes;
  final String keyPassage;
  final _LocalizedText _keyPassageDescription;

  const BookIntro({
    required this.englishBook,
    required _LocalizedText subtitle,
    required _LocalizedText summary,
    required _LocalizedText author,
    required _LocalizedText date,
    required _LocalizedText audience,
    required _LocalizedList themes,
    required this.keyPassage,
    required _LocalizedText keyPassageDescription,
  })  : _subtitle = subtitle,
        _summary = summary,
        _author = author,
        _date = date,
        _audience = audience,
        _themes = themes,
        _keyPassageDescription = keyPassageDescription;

  String getSubtitle(String locale) => _subtitle.get(locale);
  String getSummary(String locale) => _summary.get(locale);
  String getAuthor(String locale) => _author.get(locale);
  String getDate(String locale) => _date.get(locale);
  String getAudience(String locale) => _audience.get(locale);
  List<String> getThemes(String locale) => _themes.get(locale);
  String getKeyPassageDescription(String locale) =>
      _keyPassageDescription.get(locale);
}

/// Lazy loader for `assets/book_introductions.json`. Single
/// in-memory cache. Returns null when the requested book has no
/// authored intro yet (10 books in the Phase-1 dataset; rest follow
/// in subsequent rounds).
class BookIntroService {
  static Map<String, BookIntro>? _cache;
  static Future<void>? _loadFuture;

  static Future<void> ensureLoaded() {
    if (_cache != null) return Future.value();
    return _loadFuture ??= _doLoad();
  }

  static Future<void> _doLoad() async {
    try {
      final raw =
          await rootBundle.loadString('assets/book_introductions.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final intros = decoded['intros'] as Map<String, dynamic>?;
      final out = <String, BookIntro>{};
      if (intros != null) {
        intros.forEach((book, data) {
          if (data is! Map<String, dynamic>) return;
          out[book] = BookIntro(
            englishBook: book,
            subtitle: _LocalizedText(_textMap(data['subtitle'])),
            summary: _LocalizedText(_textMap(data['summary'])),
            author: _LocalizedText(_textMap(data['author'])),
            date: _LocalizedText(_textMap(data['date'])),
            audience: _LocalizedText(_textMap(data['audience'])),
            themes: _LocalizedList(_listMap(data['themes'])),
            keyPassage: (data['keyPassage'] as String?) ?? '',
            keyPassageDescription:
                _LocalizedText(_textMap(data['keyPassageDescription'])),
          );
        });
      }
      _cache = out;
    } catch (e, st) {
      debugPrint('BookIntroService load failed: $e\n$st');
      _cache = const {};
    } finally {
      _loadFuture = null;
    }
  }

  static Map<String, String> _textMap(Object? raw) {
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          if (entry.value is String)
            entry.key.toString(): entry.value as String,
      };
    }
    return const {};
  }

  static Map<String, List<String>> _listMap(Object? raw) {
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          if (entry.value is List)
            entry.key.toString():
                (entry.value as List).whereType<String>().toList(),
      };
    }
    return const {};
  }

  /// Lookup an intro by canonical English book name. Returns null
  /// when this book hasn't been authored yet.
  static BookIntro? forBook(String englishBook) {
    final cache = _cache;
    if (cache == null) return null;
    return cache[englishBook];
  }

  @visibleForTesting
  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
