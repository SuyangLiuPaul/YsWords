import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFontFamily = 'fontFamily';
const _kFontSize = 'fontSize';
const _kLineSpacing = 'lineSpacing';
const _kPrimaryColor = 'primaryColor';
const _kCopyFormat = 'copyFormat';
const _kLocale = 'locale';
const _kThemeMode = 'themeMode';
const _kParagraphMode = 'paragraphMode';
const _kMenuScale = 'menuScale';
const _kOfflineMode = 'offlineMode';
const _kBooksViewMode = 'booksViewMode';

class AppSettings extends ChangeNotifier {
  String _fontFamily = 'Roboto';
  double _fontSize = 20.0;
  double _lineSpacing = 1.5;
  Color _primaryColor = Colors.lightBlue;
  String _copyFormat = 'withRef';
  String _locale = 'zh-Hans';
  ThemeMode _themeMode = ThemeMode.system;
  bool _paragraphMode = true;
  double _menuScale = 1.0;
  bool _offlineMode = true;
  /// 'list' or 'grid' — persisted choice for the books picker.
  String _booksViewMode = 'grid';

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  double get lineSpacing => _lineSpacing;
  Color get primaryColor => _primaryColor;
  String get copyFormat => _copyFormat;
  String get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get paragraphMode => _paragraphMode;
  double get menuScale => _menuScale;
  bool get offlineMode => _offlineMode;
  String get booksViewMode => _booksViewMode;

  Future<void> setFontFamily(String family) async {
    if (_fontFamily == family) return;
    _fontFamily = family;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontFamily, family);
  }

  Future<void> setFontSize(double size) async {
    if (_fontSize == size) return;
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, size);
  }

  Future<void> setLineSpacing(double spacing) async {
    if (_lineSpacing == spacing) return;
    _lineSpacing = spacing;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLineSpacing, spacing);
  }

  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor == color) return;
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrimaryColor, color.toARGB32());
  }

  Future<void> setCopyFormat(String format) async {
    if (_copyFormat == format) return;
    _copyFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCopyFormat, format);
  }

  Future<void> setLocale(String langCode) async {
    if (_locale == langCode) return;
    _locale = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, langCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setParagraphMode(bool enabled) async {
    if (_paragraphMode == enabled) return;
    _paragraphMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kParagraphMode, enabled);
  }

  Future<void> setOfflineMode(bool enabled) async {
    if (_offlineMode == enabled) return;
    _offlineMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOfflineMode, enabled);
  }

  Future<void> setBooksViewMode(String mode) async {
    final normalized = (mode == 'grid') ? 'grid' : 'list';
    if (_booksViewMode == normalized) return;
    _booksViewMode = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBooksViewMode, normalized);
  }

  Future<void> setMenuScale(double scale) async {
    final clamped = scale.clamp(0.7, 1.5);
    if (_menuScale == clamped) return;
    _menuScale = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMenuScale, clamped);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(_kFontFamily) ?? 'Roboto';
    // Round to nearest step to avoid Slider assertion with stale values
    final rawFontSize = prefs.getDouble(_kFontSize) ?? 20.0;
    _fontSize = (rawFontSize - 12).roundToDouble() + 12;
    final rawLineSpacing = prefs.getDouble(_kLineSpacing) ?? 1.5;
    _lineSpacing = (rawLineSpacing * 10).roundToDouble() / 10;
    _primaryColor =
        Color(prefs.getInt(_kPrimaryColor) ?? Colors.lightBlue.toARGB32());
    _copyFormat = prefs.getString(_kCopyFormat) ?? 'withRef';
    _locale = prefs.getString(_kLocale) ?? _detectSystemLocale();
    _themeMode = _parseThemeMode(prefs.getString(_kThemeMode));
    _paragraphMode = prefs.getBool(_kParagraphMode) ?? true;
    final rawMenuScale = prefs.getDouble(_kMenuScale) ?? 1.0;
    _menuScale = ((rawMenuScale * 10).roundToDouble() / 10).clamp(0.7, 1.5);
    _offlineMode = prefs.getBool(_kOfflineMode) ?? true;
    final rawBooksView = prefs.getString(_kBooksViewMode) ?? 'grid';
    _booksViewMode = rawBooksView == 'grid' ? 'grid' : 'list';
    notifyListeners();
  }

  static ThemeMode _parseThemeMode(String? raw) {
    if (raw == null) return ThemeMode.system;
    // Accept new 'light'/'dark'/'system' and legacy 'ThemeMode.light' etc.
    final normalized = raw.startsWith('ThemeMode.') ? raw.substring(10) : raw;
    return ThemeMode.values.firstWhere(
      (m) => m.name == normalized,
      orElse: () => ThemeMode.system,
    );
  }

  static String _detectSystemLocale() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final locale = dispatcher.locale;
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ? 'zh-Hant' : 'zh-Hans';
    }
    return 'en';
  }
}
