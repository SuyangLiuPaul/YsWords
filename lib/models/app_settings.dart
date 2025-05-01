import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  String _fontFamily = 'Roboto';
  double _fontSize = 20.0;
  double _lineSpacing = 1.5;
  Color _primaryColor = Colors.lightBlue;
  String _copyFormat = 'withRef';
  bool _allowUpdates = true;
  bool _lockAllowUpdates = false;
  String _locale = 'zh-Hans';
  ThemeMode _themeMode = ThemeMode.system;
  bool _readingModeCentered = false;
  bool get readingModeCentered => _readingModeCentered;

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  double get lineSpacing => _lineSpacing;
  Color get primaryColor => _primaryColor;
  String get copyFormat => _copyFormat;
  bool get allowUpdates => _allowUpdates;
  bool get lockAllowUpdates => _lockAllowUpdates;
  String get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  void setFontFamily(String family) async {
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('fontFamily', family);
    notifyListeners();
  }

  void setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('fontSize', size);
    notifyListeners();
  }

  void setLineSpacing(double spacing) async {
    _lineSpacing = spacing;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('lineSpacing', spacing);
    notifyListeners();
  }

  void setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('primaryColor', color.value);
    notifyListeners();
  }

  void setCopyFormat(String format) async {
    _copyFormat = format;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('copyFormat', format);
    notifyListeners();
  }

  void setAllowUpdates(bool allow) async {
    _allowUpdates = allow;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('allowUpdates', allow);
    notifyListeners();
  }

  void setLockAllowUpdates(bool lock) {
    _lockAllowUpdates = lock;
    notifyListeners();
  }

  void setLocale(String langCode) async {
    _locale = langCode;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('locale', langCode);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('themeMode', mode.toString());
    notifyListeners();
  }

  void setReadingModeCentered(bool centered) async {
    _readingModeCentered = centered;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('readingModeCentered', centered);
    notifyListeners();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString('fontFamily') ?? 'Roboto';
    _fontSize = prefs.getDouble('fontSize') ?? 20.0;
    _lineSpacing = prefs.getDouble('lineSpacing') ?? 1.5;
    _primaryColor =
        Color(prefs.getInt('primaryColor') ?? Colors.lightBlue.value);
    _copyFormat = prefs.getString('copyFormat') ?? 'withRef';
    _allowUpdates = prefs.getBool('allowUpdates') ?? true;
    _lockAllowUpdates = false;
    _locale = prefs.getString('locale') ?? _detectSystemLocale();
    final themeModeString = prefs.getString('themeMode') ?? 'ThemeMode.system';
    switch (themeModeString) {
      case 'ThemeMode.light':
        _themeMode = ThemeMode.light;
        break;
      case 'ThemeMode.dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    _readingModeCentered = prefs.getBool('readingModeCentered') ?? false;
    notifyListeners();
  }

  String _detectSystemLocale() {
    final String systemLocale =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (systemLocale == 'zh') {
      final String? scriptCode =
          WidgetsBinding.instance.platformDispatcher.locale.scriptCode;
      if (scriptCode == 'Hant') {
        return 'zh-Hant';
      } else {
        return 'zh-Hans';
      }
    } else {
      return 'en';
    }
  }
}
