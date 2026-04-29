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
const _kBoldVerseText = 'boldVerseText';
const _kShowStrongsInOriginals = 'showStrongsInOriginals';
const _kAutoExpandFirstRef = 'autoExpandFirstRef';
const _kShowDailyNews = 'showDailyNews';
const _kShowBibleEvidence = 'showBibleEvidence';
const _kShowReadingPlan = 'showReadingPlan';
const _kNotificationsEnabled = 'notificationsEnabled';
const _kShowSectionTitles = 'showSectionTitles';
const _kShowBookIntro = 'showBookIntro';

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
  /// Render verse text with FontWeight.w700 instead of normal weight.
  bool _boldVerseText = false;
  /// Show the Strong's # badge inside each word chip in the originals
  /// (exegesis) sheet — handy for power users, distracting for some.
  bool _showStrongsInOriginals = true;
  /// Auto-expand the first book group in the concordance section of
  /// each Strong's entry so the user sees verse refs immediately.
  bool _autoExpandFirstRef = false;

  /// Show the Today's Headlines card + Daily News quick-link tile +
  /// the Daily News page entry. Default ON.
  bool _showDailyNews = true;

  /// Show the Today's Evidence card + Bible Evidence quick-link tile +
  /// the Bible Evidence page entry. Default ON.
  bool _showBibleEvidence = true;

  /// Show the Today's Reading card on the dashboard. Default ON.
  /// Reading-plan picker remains accessible from settings regardless.
  bool _showReadingPlan = true;

  /// Whether the user has opted into notifications. When true, the
  /// app requests browser Notification permission on next launch and
  /// fires local reminders (today's verse, today's reading missed,
  /// etc.). Default OFF — must be explicit user opt-in.
  bool _notificationsEnabled = false;

  /// Render section / paragraph headings (e.g. "The Sermon on the
  /// Mount" / "登山宝训") above the matched verse in the reading
  /// pane. Default ON — gives chapters useful structure. Toggle in
  /// Settings → Reading.
  bool _showSectionTitles = true;

  /// Render the collapsible book-intro card at the top of chapter 1
  /// when an intro is authored for that book. Default ON. Toggle in
  /// Settings → Reading.
  bool _showBookIntro = true;

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
  bool get boldVerseText => _boldVerseText;
  bool get showStrongsInOriginals => _showStrongsInOriginals;
  bool get autoExpandFirstRef => _autoExpandFirstRef;
  bool get showDailyNews => _showDailyNews;
  bool get showBibleEvidence => _showBibleEvidence;
  bool get showReadingPlan => _showReadingPlan;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get showSectionTitles => _showSectionTitles;
  bool get showBookIntro => _showBookIntro;

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

  Future<void> setBoldVerseText(bool enabled) async {
    if (_boldVerseText == enabled) return;
    _boldVerseText = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBoldVerseText, enabled);
  }

  Future<void> setShowStrongsInOriginals(bool enabled) async {
    if (_showStrongsInOriginals == enabled) return;
    _showStrongsInOriginals = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowStrongsInOriginals, enabled);
  }

  Future<void> setAutoExpandFirstRef(bool enabled) async {
    if (_autoExpandFirstRef == enabled) return;
    _autoExpandFirstRef = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoExpandFirstRef, enabled);
  }

  Future<void> setShowDailyNews(bool enabled) async {
    if (_showDailyNews == enabled) return;
    _showDailyNews = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowDailyNews, enabled);
  }

  Future<void> setShowBibleEvidence(bool enabled) async {
    if (_showBibleEvidence == enabled) return;
    _showBibleEvidence = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowBibleEvidence, enabled);
  }

  Future<void> setShowReadingPlan(bool enabled) async {
    if (_showReadingPlan == enabled) return;
    _showReadingPlan = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowReadingPlan, enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, enabled);
  }

  Future<void> setShowSectionTitles(bool enabled) async {
    if (_showSectionTitles == enabled) return;
    _showSectionTitles = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowSectionTitles, enabled);
  }

  Future<void> setShowBookIntro(bool enabled) async {
    if (_showBookIntro == enabled) return;
    _showBookIntro = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowBookIntro, enabled);
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
    _boldVerseText = prefs.getBool(_kBoldVerseText) ?? false;
    _showStrongsInOriginals =
        prefs.getBool(_kShowStrongsInOriginals) ?? true;
    _autoExpandFirstRef = prefs.getBool(_kAutoExpandFirstRef) ?? false;
    _showDailyNews = prefs.getBool(_kShowDailyNews) ?? true;
    _showBibleEvidence = prefs.getBool(_kShowBibleEvidence) ?? true;
    _showReadingPlan = prefs.getBool(_kShowReadingPlan) ?? true;
    _notificationsEnabled = prefs.getBool(_kNotificationsEnabled) ?? false;
    _showSectionTitles = prefs.getBool(_kShowSectionTitles) ?? true;
    _showBookIntro = prefs.getBool(_kShowBookIntro) ?? true;
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
