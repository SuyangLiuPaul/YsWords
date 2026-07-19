import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_style_preset.dart' show CardMaterial;
import 'package:yswords/models/dashboard_section.dart';
import 'package:yswords/models/notification_category.dart';
import 'package:yswords/services/app_icon_service.dart';
import 'package:yswords/services/notification_scheduler.dart'
    as scheduler;
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/realtime_db_sync_service.dart';
import 'package:yswords/utils/font_catalog.dart';

const _kFontFamily = 'fontFamily';
const _kFontSize = 'fontSize';
const _kLineSpacing = 'lineSpacing';
const _kPrimaryColor = 'primaryColor';
const _kCopyFormat = 'copyFormat';
const _kLocale = 'locale';
const _kThemeMode = 'themeMode';
const _kParagraphMode = 'paragraphMode';
const _kMenuScale = 'menuScale';
// 2026-05-08 (v1.1.1): which card / tile material to render across
// the app's framing surfaces. See `lib/models/app_style_preset.dart`
// for the [CardMaterial] enum. Default `classic` keeps the look the
// app shipped with through v1.0.x.
const _kCardMaterial = 'cardMaterial';
// 2026-05-07 (v17): _kOfflineMode removed; the toggle that wrote it
// was deleted from the Settings card. The persisted bool is left in
// SharedPreferences for users that have it -- it's harmless dead
// data and not worth a migration step.
const _kBooksViewMode = 'booksViewMode';
const _kBoldVerseText = 'boldVerseText';
const _kShowStrongsInOriginals = 'showStrongsInOriginals';
const _kAutoExpandFirstRef = 'autoExpandFirstRef';
const _kShowBibleEvidence = 'showBibleEvidence';
const _kNotificationsEnabled = 'notificationsEnabled';
// 2026-05-24 (v1.3.0): per-category notification prefs. Stored as a
// JSON string mapping category id → NotificationCategoryPrefs JSON.
const _kNotificationCategories = 'notificationCategories';
const _kShowSectionTitles = 'showSectionTitles';
const _kShowBookIntro = 'showBookIntro';
const _kPickVerseAfterChapter = 'pickVerseAfterChapter';
// User-supplied Gemini API key (BYOK). When non-empty, AI calls are
// routed through the user's own AI Studio key — gives them their own
// quota (15 RPM / 1500 RPD on the free tier) and keeps the app
// developer's shared quota for users who haven't pasted a key. The
// key never leaves this device's localStorage; the AI service only
// adds it to outbound POST bodies destined for our own Netlify
// function (which forwards to Google without persisting).
const _kGeminiApiKey = 'geminiApiKey';
// 2026-05-10 (v1.2.26): user's chosen AI response-depth tier.
// Maps to a Gemini model on the server side:
//   'flash-lite' → 'gemini-2.5-flash-lite' (fast, simple, default)
//   'flash'      → 'gemini-2.5-flash'      (balanced)
//   'pro'        → 'gemini-2.5-pro'        (deep, slower, smaller quota)
const _kAiModel = 'aiModel';
// Allowlist mirrored on the Netlify function side so a corrupt
// SharedPrefs entry can't drive the server to a model we don't
// support. Default 'flash-lite' matches the previous hardcoded
// MODEL constant in netlify/functions/aiBibleSearch.mjs.
const Set<String> _kAiModelAllowed = {'flash-lite', 'flash', 'pro'};
const String _kAiModelDefault = 'flash-lite';

// 2026-05-24 (v1.3.19): TTS voice preference constants removed
// along with the 朗读 feature. Existing SharedPreferences keys
// (`ttsVoiceGender`, `ttsVoiceTier`) are left untouched on disk
// — harmless orphan data that a future version can clear during
// migration if storage size becomes a concern.

// 2026-05-24 (v1.2.91): user's preferred sort order for the
// Library → Notes tab.
//   'canonical' → Genesis → Revelation (verse index in the loaded
//                 Bible; the order the app has used since v1.0)
//   'recent'    → most recently created/edited first (uses the
//                 verseNoteTimestamps map in MainProvider)
//   'oldest'    → oldest first (reverse of 'recent')
// Defaults to 'canonical' so existing users see no behaviour
// change until they pick a different sort. Allowlist-clamped on
// load to match the established pattern for aiModel + tts*.
const _kNotesSortMode = 'notesSortMode';
const Set<String> _kNotesSortAllowed = {'canonical', 'recent', 'oldest'};
const String _kNotesSortDefault = 'canonical';

// Dashboard layout (Round 55). Every section has its own
// `dashboard_section_visible_<name>` flag plus a single
// `dashboard_section_order` list that drives the render order.
const _kDashboardSectionOrder = 'dashboard_section_order';
String _kDashboardVisible(DashboardSection s) =>
    'dashboard_section_visible_${s.name}';

class AppSettings extends ChangeNotifier {
  /// User's selected font key — what gets persisted in
  /// SharedPreferences (e.g. `'EB Garamond'`). Drives the dropdown
  /// `value:` and the visible label.
  ///
  /// 2026-05-08 (v1.1.2): default switched from `'Roboto'` to
  /// `'system'`. The new default routes through the OS-native CSS
  /// font-stack chain (`-apple-system` → `Segoe UI` → `Roboto` →
  /// …), so first-launch users on every platform see their own
  /// system's typography out of the box. `'Roboto'` remains a
  /// pickable option in Settings if a user prefers it explicitly.
  String _fontSelection = 'system';
  /// Resolved family name passed to TextStyle's `fontFamily`. For
  /// bundled fonts this equals [_fontSelection]; for Google Fonts
  /// it's the registered family name (e.g. `'EBGaramond_regular'`)
  /// that the engine actually recognises. Round 56 split: previously
  /// these were the same string and Google Fonts options silently
  /// fell back to Roboto.
  String _fontFamily = '-apple-system';
  double _fontSize = 20.0;
  double _lineSpacing = 1.5;
  Color _primaryColor = Colors.lightBlue;
  // 2026-05-17 (v1.2.47): default changed from 'withRef' →
  // 'devotional' per user request — devotional puts the
  // reference in parens AFTER the text (灵修 / 抄经 friendly
  // format) which is the most common day-to-day copy use case.
  // Existing users keep whatever they had via the SharedPrefs
  // fallback in `loadSettings()`; only fresh installs (or
  // `resetAllSettings()`) get the new default.
  String _copyFormat = 'devotional';
  String _locale = 'zh-Hans';
  ThemeMode _themeMode = ThemeMode.system;
  bool _paragraphMode = true;
  double _menuScale = 1.0;
  // 2026-05-08 (v1.1.1): card / tile material; classic by default.
  CardMaterial _cardMaterial = CardMaterial.classic;
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

  /// Show the Today's Evidence card + Bible Evidence quick-link tile +
  /// the Bible Evidence page entry. Default ON.
  bool _showBibleEvidence = true;

  /// Whether the user has opted into notifications. When true, the
  /// app requests browser Notification permission on next launch and
  /// fires local reminders (today's verse, today's reading missed,
  /// etc.). Default OFF — must be explicit user opt-in.
  bool _notificationsEnabled = false;
  // 2026-05-24 (v1.3.0): per-category prefs. Lazy default — categories
  // not in the map fall back to NotificationCategoryPrefs.defaultFor.
  Map<String, NotificationCategoryPrefs> _notificationCategories = {};

  /// User-supplied Gemini API key. When non-empty, AI calls (word
  /// explanations, AI search) are billed against the user's own
  /// AI Studio quota instead of the developer-shared key.
  String _geminiApiKey = '';
  // 2026-05-10 (v1.2.26): see top-of-file _kAiModel comment.
  String _aiModel = _kAiModelDefault;
  // 2026-05-24 (v1.3.19): TTS fields removed with the 朗读 feature.
  // 2026-05-24 (v1.2.91): see _kNotesSortMode comment.
  String _notesSortMode = _kNotesSortDefault;

  /// Render section / paragraph headings (e.g. "The Sermon on the
  /// Mount" / "登山宝训") above the matched verse in the reading
  /// pane. Default ON — gives chapters useful structure. Toggle in
  /// Settings → Reading.
  bool _showSectionTitles = true;

  /// Render the collapsible book-intro card at the top of chapter 1
  /// when an intro is authored for that book. Default ON. Toggle in
  /// Settings → Reading.
  bool _showBookIntro = true;

  /// When ON, picking a chapter from the book/chapter sidebar shows
  /// a second-step verse-number grid so the user can land directly
  /// on a specific verse instead of the chapter header. Default
  /// OFF (chapter-level navigation is the established UX). Round
  /// 56 user request: "should have a toggle whether can click verse
  /// after clicking book chapter".
  bool _pickVerseAfterChapter = false;

  // ── Dashboard layout (Round 55) ─────────────────────────────────
  // The dashboard now ships with reorder + per-section visibility
  // controls (Settings → Dashboard layout). The user's order is
  // stored as a list of [DashboardSection.name] strings; each
  // section also has its own visibility bool. We seed both from
  // [defaultDashboardOrder] / [defaultVisibility] and migrate the
  // legacy `showBibleEvidence` / `showReadingPlan` flags into the new
  // map on first load (see [loadSettings]).

  /// Current render order of dashboard sections.
  List<DashboardSection> _dashboardSectionOrder =
      List.of(defaultDashboardOrder);

  /// Per-section visibility. Always contains an entry for every
  /// [DashboardSection] value (filled in by [loadSettings]).
  final Map<DashboardSection, bool> _dashboardVisibility =
      Map.of(defaultVisibility);

  /// The resolved family for TextStyle.fontFamily. Existing call
  /// sites (`fontFamily: settings.fontFamily`) automatically get the
  /// Google-Fonts-registered name without code changes elsewhere.
  String get fontFamily => _fontFamily;
  /// The user's stored selection key — use this for the dropdown
  /// `value:` and for round-tripping back into [setFontFamily].
  String get fontSelection => _fontSelection;
  double get fontSize => _fontSize;
  double get lineSpacing => _lineSpacing;
  Color get primaryColor => _primaryColor;
  String get copyFormat => _copyFormat;
  String get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get paragraphMode => _paragraphMode;
  double get menuScale => _menuScale;
  CardMaterial get cardMaterial => _cardMaterial;
  String get booksViewMode => _booksViewMode;
  bool get boldVerseText => _boldVerseText;
  bool get showStrongsInOriginals => _showStrongsInOriginals;
  bool get autoExpandFirstRef => _autoExpandFirstRef;
  bool get showBibleEvidence => _showBibleEvidence;
  bool get notificationsEnabled => _notificationsEnabled;
  /// Snapshot map of per-category preferences. Missing entries fall
  /// back to defaults — use [notificationCategory] for safe lookup.
  Map<String, NotificationCategoryPrefs> get notificationCategories =>
      Map.unmodifiable(_notificationCategories);

  /// Safe per-category lookup. Returns the stored prefs if present,
  /// or the shipped default if the user hasn't touched this category.
  NotificationCategoryPrefs notificationCategory(String categoryId) =>
      _notificationCategories[categoryId] ??
      NotificationCategoryPrefs.defaultFor(categoryId);
  bool get showSectionTitles => _showSectionTitles;
  bool get showBookIntro => _showBookIntro;
  bool get pickVerseAfterChapter => _pickVerseAfterChapter;

  /// User-supplied Gemini API key. Empty string when the user is on
  /// the developer-shared key. Caller services (AiWordService /
  /// AiSearchService) read this and include it in their request body
  /// when set. Never persisted off-device.
  String get geminiApiKey => _geminiApiKey;
  bool get hasUserGeminiKey => _geminiApiKey.trim().isNotEmpty;

  /// 2026-05-10 (v1.2.26): user's selected AI response-depth tier
  /// — one of {'flash-lite', 'flash', 'pro'}. Default 'flash-lite'
  /// matches the previous hardcoded server default.
  String get aiModel => _aiModel;

  Future<void> setAiModel(String model) async {
    if (!_kAiModelAllowed.contains(model)) return;
    if (_aiModel == model) return;
    _aiModel = model;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAiModel, model);
  }

  // 2026-05-24 (v1.3.19): `ttsVoiceGender` / `ttsVoiceTier` getters
  // + setters removed with the 朗读 feature.

  /// 2026-05-24 (v1.2.91): which sort to apply in Library → Notes.
  /// One of 'canonical' / 'recent' / 'oldest'. See _kNotesSortMode
  /// for semantics. Defaults to 'canonical' for backwards compat.
  String get notesSortMode => _notesSortMode;

  Future<void> setNotesSortMode(String mode) async {
    if (!_kNotesSortAllowed.contains(mode)) return;
    if (_notesSortMode == mode) return;
    _notesSortMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotesSortMode, mode);
  }

  Future<void> setGeminiApiKey(String key) async {
    final trimmed = key.trim();
    if (_geminiApiKey == trimmed) return;
    _geminiApiKey = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_kGeminiApiKey);
    } else {
      await prefs.setString(_kGeminiApiKey, trimmed);
    }
    // 2026-05-10 (v1.2.17): also push to RTDB so the key is
    // available on every device the user signs in on. Silent no-op
    // when not signed in / China build / Firebase unconfigured —
    // see RealtimeDbSyncService.pushGeminiKey for guards. Fire-and-
    // forget — local SharedPreferences is the source of truth for
    // the *current* device, the cloud copy is just a convenience
    // for other devices.
    // ignore: unawaited_futures
    RealtimeDbSyncService.instance.pushGeminiKey(trimmed);
  }

  /// 2026-05-10 (v1.2.17): pull the Gemini key from RTDB and apply
  /// to local if (and only if) local is currently empty. Called
  /// from `loadSettings()` on boot after SharedPrefs has populated
  /// the local copy, and from a CloudAuthService listener on sign-
  /// in success. Local-empty-only policy avoids clobbering a key
  /// the user just pasted on this device but hasn't pushed yet
  /// (signed out → paste → sign in → would otherwise lose it).
  Future<void> _pullGeminiKeyFromCloudIfEmpty() async {
    if (_geminiApiKey.trim().isNotEmpty) return;
    final remote = await RealtimeDbSyncService.instance.pullGeminiKey();
    if (remote == null) return; // no info / not signed in
    if (remote.trim().isEmpty) return; // cloud explicitly empty
    _geminiApiKey = remote.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGeminiApiKey, remote.trim());
  }

  /// 2026-05-17 (v1.2.47): real-time BYOK sync — subscribes to
  /// RTDB `onValue` and applies remote changes live.
  ///
  /// 2026-05-17 (v1.2.51): semantic change — the first-emission
  /// preservation policy (keep local if non-empty) actively
  /// surprised users in the most common pattern:
  ///
  ///   • Device A: user updates key X → Z (cloud now has Z).
  ///   • Device B: was offline; reopens app with local key = X.
  ///     The stream's first emission is Z. v1.2.47 saw local = X
  ///     (non-empty) and SKIPPED — Device B remained stuck on X.
  ///
  /// User report: "why some api for gemini not synced".
  ///
  /// New policy: cloud is the source of truth — every emission
  /// (including the first one) is applied. To preserve the "paste
  /// on Device B while signed out → sign in" flow, the sign-in
  /// path (`_doByokSync`) PUSHES local to cloud BEFORE subscribing
  /// so the stream's first emission is the local value, which
  /// matches local → no-op, no clobber.
  ///
  ///   • Echo emissions (cloud value matches local already): no-op,
  ///     guarded by an equality check so we don't fire a redundant
  ///     `notifyListeners()` on every push round-trip.
  ///
  /// Subscription lifecycle:
  ///   • Started from `loadSettings()` (if already signed in) and
  ///     from `_onAuthChangedForByokSync` (on every sign-in).
  ///   • Cancelled in `_onAuthChangedForByokSync` on sign-out so
  ///     the stream doesn't leak past the auth session.
  StreamSubscription<String?>? _geminiKeySub;

  void _subscribeToGeminiKeyChanges() {
    // Idempotent — avoid stacking subscriptions.
    if (_geminiKeySub != null) {
      debugPrint('[YsWords BYOK] subscribe: already subscribed, skip');
      return;
    }
    final stream = RealtimeDbSyncService.instance.watchGeminiKey();
    if (stream == null) {
      debugPrint('[YsWords BYOK] subscribe: stream is null '
          '(not signed in / not configured)');
      return;
    }
    debugPrint('[YsWords BYOK] subscribing to RTDB stream');
    _geminiKeySub = stream.listen(_handleRemoteGeminiKey);
  }

  Future<void> _unsubscribeFromGeminiKeyChanges() async {
    debugPrint('[YsWords BYOK] unsubscribing from RTDB stream');
    await _geminiKeySub?.cancel();
    _geminiKeySub = null;
  }

  Future<void> _handleRemoteGeminiKey(String? remote) async {
    if (remote == null) {
      debugPrint('[YsWords BYOK] stream emit: null (skip)');
      return;
    }
    final trimmed = remote.trim();
    debugPrint('[YsWords BYOK] stream emit: '
        '${trimmed.isEmpty ? "<empty>" : "${trimmed.substring(0, trimmed.length.clamp(0, 6))}…"} '
        '(local: '
        '${_geminiApiKey.isEmpty ? "<empty>" : "${_geminiApiKey.substring(0, _geminiApiKey.length.clamp(0, 6))}…"})');
    if (trimmed == _geminiApiKey) {
      debugPrint('[YsWords BYOK] echo, no-op');
      return;
    }
    _geminiApiKey = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_kGeminiApiKey);
    } else {
      await prefs.setString(_kGeminiApiKey, trimmed);
    }
    debugPrint('[YsWords BYOK] applied remote → local updated');
  }

  /// 2026-05-17 (v1.2.51): on sign-in, push local to cloud BEFORE
  /// subscribing so the first emission matches local — preserves
  /// the "paste while signed out → sign in" case without the
  /// first-emission special-case logic. On sign-in with empty
  /// local, fall back to the existing pull-if-empty so a fresh
  /// device picks up the cloud's key.
  Future<void> _doByokSync() async {
    if (_geminiApiKey.trim().isNotEmpty) {
      debugPrint('[YsWords BYOK] sign-in: pushing local key to cloud first');
      await RealtimeDbSyncService.instance.pushGeminiKey(_geminiApiKey.trim());
    } else {
      debugPrint('[YsWords BYOK] sign-in: local empty, pulling from cloud');
      await _pullGeminiKeyFromCloudIfEmpty();
    }
    _subscribeToGeminiKeyChanges();
  }

  /// The current dashboard render order. Returns a defensive copy so
  /// callers can't mutate internal state directly.
  List<DashboardSection> get dashboardSectionOrder =>
      List.unmodifiable(_dashboardSectionOrder);

  /// Whether [section] should render on the dashboard. Combines the
  /// user's stored preference with [defaultVisibility] when no entry
  /// has been written yet.
  ///
  /// Special case: [DashboardSection.readBible] is *always* visible.
  /// It's the primary entry point into the app — if the user hides
  /// every other section AND this one, they'd have no way to open
  /// the Bible. So we lock its visibility on at the model layer
  /// (Settings UI also disables the Switch for it).
  bool isDashboardSectionVisible(DashboardSection section) {
    if (section == DashboardSection.readBible) return true;
    return _dashboardVisibility[section] ?? defaultVisibility[section] ?? true;
  }

  /// [selection] is a catalogue key like `'EB Garamond'` (see
  /// [availableFontOptions]). We persist the key as-is and resolve
  /// it through the Google Fonts package when needed so the rest of
  /// the codebase keeps using `settings.fontFamily` unchanged.
  Future<void> setFontFamily(String selection) async {
    if (_fontSelection == selection) return;
    _fontSelection = selection;
    _fontFamily = resolveFontFamily(selection);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontFamily, selection);
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
    // 2026-05-24 (v1.2.96): also swap the iOS home-screen icon if
    // the user picked a color that has a matching alternate-icon
    // variant. Non-iOS platforms are a silent no-op. The OS shows
    // a one-time alert per session ("icon changed for ...") which
    // is iOS-imposed and can't be suppressed.
    // Fire-and-forget — we don't await because the alert is async
    // and the user's already moved on from Settings.
    // ignore: unawaited_futures
    AppIconService.updateForColor(color);
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
    // 2026-06-16 (v1.3.89): scheduled-notification titles/bodies are
    // localized at schedule time, so a language change must re-create them
    // — otherwise pending reminders keep firing in the OLD language until
    // the next app launch. (No-op on web; the scheduler guards platform.)
    unawaited(_rescheduleAllSafely());
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

  // 2026-05-08 (v1.1.1): card / tile material picker. Persisted as
  // the enum's name string so future enum reorderings don't reshuffle
  // user choices the way an int index would.
  Future<void> setCardMaterial(CardMaterial material) async {
    if (_cardMaterial == material) return;
    _cardMaterial = material;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCardMaterial, material.name);
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

  Future<void> setShowBibleEvidence(bool enabled) async {
    if (_showBibleEvidence == enabled) return;
    _showBibleEvidence = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowBibleEvidence, enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, enabled);
    // 2026-05-24 (v1.3.0): kick off (or tear down) all scheduled
    // category notifications when the master toggle flips.
    // Lazy-import to avoid pulling timezone/native code into web.
    unawaited(_rescheduleAllSafely());
  }

  /// Replace per-category prefs and persist. Callers from the
  /// Settings UI typically call this with a `copyWith` of the
  /// current category's prefs (e.g. toggling enabled, picking a
  /// new time). Fires a notify + a reschedule.
  Future<void> setNotificationCategory(
      String categoryId, NotificationCategoryPrefs newPrefs) async {
    if (_notificationCategories[categoryId] == newPrefs) return;
    _notificationCategories = {
      ..._notificationCategories,
      categoryId: newPrefs,
    };
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final e in _notificationCategories.entries) {
      map[e.key] = e.value.toJson();
    }
    await prefs.setString(_kNotificationCategories, jsonEncode(map));
    unawaited(_rescheduleAllSafely());
  }

  /// Wrapper that pulls the scheduler off the conditional-import
  /// boundary. On web the scheduler short-circuits internally.
  Future<void> _rescheduleAllSafely() async {
    try {
      await scheduler.rescheduleAll(this);
    } catch (_) {
      // Schedule failures shouldn't kill the settings write path.
      // notification_scheduler logs internally with debugPrint.
    }
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


  Future<void> setPickVerseAfterChapter(bool enabled) async {
    if (_pickVerseAfterChapter == enabled) return;
    _pickVerseAfterChapter = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPickVerseAfterChapter, enabled);
  }

  Future<void> setMenuScale(double scale) async {
    final clamped = scale.clamp(0.7, 1.5);
    if (_menuScale == clamped) return;
    _menuScale = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMenuScale, clamped);
  }

  /// Persist a new dashboard render order. Caller is responsible for
  /// passing a complete list (containing every [DashboardSection]
  /// value exactly once) — typically the result of a
  /// [ReorderableListView] drag in the Settings page. The list is
  /// re-normalized here as a defensive measure.
  Future<void> setDashboardSectionOrder(
      List<DashboardSection> order) async {
    final normalized = normalizeDashboardOrder(
      order.map((s) => s.name).toList(),
    );
    // Cheap equality check — bail when nothing changed so we don't
    // notify listeners on a no-op reorder (e.g. drag-and-drop back
    // to the same slot).
    final unchanged =
        normalized.length == _dashboardSectionOrder.length &&
            List.generate(normalized.length, (i) => i)
                .every((i) => normalized[i] == _dashboardSectionOrder[i]);
    if (unchanged) return;
    _dashboardSectionOrder = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kDashboardSectionOrder,
      normalized.map((s) => s.name).toList(),
    );
  }

  /// Toggle visibility of one dashboard section. Mirrors the legacy
  /// `setShowBibleEvidence` / `setShowReadingPlan` / etc. for any new
  /// section; the legacy setters remain available and stay in sync.
  ///
  /// No-op for [DashboardSection.readBible] — it's the app's primary
  /// entry point and stays mandatory regardless of what the caller
  /// passes in.
  Future<void> setDashboardSectionVisible(
      DashboardSection section, bool visible) async {
    if (section == DashboardSection.readBible) return;
    final current = isDashboardSectionVisible(section);
    if (current == visible) return;
    _dashboardVisibility[section] = visible;
    // Mirror into the legacy bools where they exist so any code path
    // still reading the old field gets the same answer.
    switch (section) {
      case DashboardSection.todayEvidence:
        _showBibleEvidence = visible;
        break;
      default:
        break;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDashboardVisible(section), visible);
    // Mirror legacy key so a downgrade still picks up the user's
    // intent (the only one that pre-dated round 55).
    switch (section) {
      case DashboardSection.todayEvidence:
        await prefs.setBool(_kShowBibleEvidence, visible);
        break;
      default:
        break;
    }
  }

  /// Restore every visual / preference setting to its factory default
  /// (round 55 "Reset settings" button). Resets fonts, theme, primary
  /// color, copy format, theme mode, paragraph mode, menu scale,
  /// books view mode, the show-* flags, dashboard order +
  /// visibility, AND the onboarding-seen flag (so the user can re-
  /// walk the tour after resetting).
  ///
  /// Deliberately preserves:
  ///   • [_locale] — wiping it would yank the user back to the system
  ///     default mid-session, which is jarring and not what users
  ///     expect from a "Reset settings" button.
  ///   • Bookmarks, notes, highlights, profile, last-read positions,
  ///     sermon scroll positions — these are user *content*, not
  ///     preferences. Lives in MainProvider / SermonService /
  ///     ProfileService and is owned by those services.
  ///
  /// Caller (Settings page) is responsible for showing a confirm
  /// dialog before calling this — it's idempotent but visible.
  Future<void> resetAllSettings() async {
    // 2026-05-08 (v1.1.2): reset returns the user to the system
    // default font (not hardcoded Roboto), matching the priority
    // chain "user setting → system detect → app fallback". On
    // every platform the system token resolves via the CSS font
    // stack to the OS UI font.
    _fontSelection = 'system';
    _fontFamily = '-apple-system';
    _fontSize = 20.0;
    _lineSpacing = 1.5;
    _primaryColor = Colors.lightBlue;
    _copyFormat = 'devotional';
    _themeMode = ThemeMode.system;
    _paragraphMode = true;
    _menuScale = 1.0;
    _cardMaterial = CardMaterial.classic;
    _booksViewMode = 'grid';
    _boldVerseText = false;
    _showStrongsInOriginals = true;
    _autoExpandFirstRef = false;
    _showBibleEvidence = true;
    _notificationsEnabled = false;
    _showSectionTitles = true;
    _showBookIntro = true;
    _pickVerseAfterChapter = false;
    _dashboardSectionOrder = List.of(defaultDashboardOrder);
    _dashboardVisibility
      ..clear()
      ..addAll(defaultVisibility);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // Wipe every preference key we've ever written. Loop is the
    // safest implementation — additions to AppSettings won't drift
    // out of sync the way an explicit list would.
    final managedKeys = <String>{
      _kFontFamily,
      _kFontSize,
      _kLineSpacing,
      _kPrimaryColor,
      _kCopyFormat,
      _kThemeMode,
      _kParagraphMode,
      _kMenuScale,
      _kCardMaterial,
      // 2026-05-07 (v17): the offlineMode toggle is gone, but we
      // still purge the stored bool on reset so users who toggled
      // it before don't carry dead data forever.
      'offlineMode',
      _kBooksViewMode,
      _kBoldVerseText,
      _kShowStrongsInOriginals,
      _kAutoExpandFirstRef,
      _kShowBibleEvidence,
      _kNotificationsEnabled,
      _kShowSectionTitles,
      _kShowBookIntro,
      _kPickVerseAfterChapter,
      _kDashboardSectionOrder,
      for (final s in DashboardSection.values) _kDashboardVisible(s),
      // Re-show the onboarding tour after a reset so the user can
      // re-discover any features they hid by accident. Clear all
      // historical keys — `v3` is the active one (since v1.2.9), but
      // someone resetting from a v2 / v1 install needs both legacy
      // keys gone too so a stale flag from before this version
      // can't suppress the refreshed tour.
      'onboarding.seen.v3',
      'onboarding.seen.v2',
      'onboarding.seen.v1',
    };
    for (final k in managedKeys) {
      await prefs.remove(k);
    }
  }

  /// Restore the canonical default order + visibility (every section
  /// on, in [defaultDashboardOrder] order). Used by the Settings
  /// "Reset to default" button.
  Future<void> resetDashboardLayout() async {
    _dashboardSectionOrder = List.of(defaultDashboardOrder);
    _dashboardVisibility
      ..clear()
      ..addAll(defaultVisibility);
    _showBibleEvidence =
        defaultVisibility[DashboardSection.todayEvidence] ?? true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kDashboardSectionOrder,
      _dashboardSectionOrder.map((s) => s.name).toList(),
    );
    for (final s in DashboardSection.values) {
      await prefs.setBool(
          _kDashboardVisible(s), defaultVisibility[s] ?? true);
    }
    await prefs.setBool(_kShowBibleEvidence, _showBibleEvidence);
  }

  Future<void> loadSettings() async {
    // 2026-05-10 (v1.2.31): wrap in try/catch so a Safari-private-
    // browsing localStorage block, an iOS storage quota error, or
    // any other shared_preferences plugin failure leaves all
    // settings at compile-time defaults instead of throwing into
    // the bootstrap catch (which would mis-route the user to the
    // "Failed to load" verse-error scaffold even though the verse
    // load is fine). Compile-time defaults are sane: zh-Hans /
    // system theme / fontSize 20 — user can still use the app.
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e, st) {
      debugPrint('AppSettings.loadSettings: shared_preferences '
          'unavailable, using defaults — $e\n$st');
      // Notify listeners with default values so the rest of the
      // tree wires up immediately; later writes via setX(...) will
      // also fail-soft so functionality degrades gracefully.
      notifyListeners();
      return;
    }
    // Round 56: migrate legacy keys (Times New Roman, Garamond, …)
    // before resolving — DropdownButton would otherwise crash on a
    // value that doesn't match any item.
    //
    // 2026-05-08 (v1.1.2): when the user has no stored choice we
    // fall through to 'system' (the new default) — which routes
    // through the OS-native CSS font stack defined in main.dart's
    // fontFamilyFallback. Roboto remains the **app fallback** at
    // the end of that chain, but it's no longer the eager default
    // for users who haven't expressed a preference.
    final stored = prefs.getString(_kFontFamily) ?? 'system';
    _fontSelection = migrateLegacyFontKey(stored);
    _fontFamily = resolveFontFamily(_fontSelection);
    // Persist the migrated key so the next launch is clean.
    if (_fontSelection != stored) {
      await prefs.setString(_kFontFamily, _fontSelection);
    }
    // Round to nearest step to avoid Slider assertion with stale values
    final rawFontSize = prefs.getDouble(_kFontSize) ?? 20.0;
    _fontSize = (rawFontSize - 12).roundToDouble() + 12;
    final rawLineSpacing = prefs.getDouble(_kLineSpacing) ?? 1.5;
    _lineSpacing = (rawLineSpacing * 10).roundToDouble() / 10;
    _primaryColor =
        Color(prefs.getInt(_kPrimaryColor) ?? Colors.lightBlue.toARGB32());
    // 2026-06-14 (v1.3.70): re-apply the themed home-screen / dock /
    // favicon icon on startup so it tracks the saved theme colour.
    // iOS resets `alternateIconName` to the primary icon on every app
    // reinstall/update (the nightly launchd reinstall + any App Store
    // update), and updateForColor previously fired ONLY when the user
    // CHANGED the colour — so after an update the icon reverted to the
    // default blue and never came back, and re-tapping the already-
    // selected swatch is a no-op (setPrimaryColor early-returns). Sync
    // here, once after the first frame so the platform channel is live;
    // the service no-ops when the icon already matches (no redundant
    // iOS "you changed the icon" alert on normal launches).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: unawaited_futures
      AppIconService.updateForColor(_primaryColor);
    });
    _copyFormat = prefs.getString(_kCopyFormat) ?? 'devotional';
    // 2026-05-26 (v1.3.46): persist the detected locale on first
    // load. Previously `_locale = prefs.get ?? _detectSystemLocale()`
    // only kept the detection IN MEMORY — the prefs key stayed
    // empty. `MainProvider.restoreState` reads the prefs key (not
    // AppSettings.locale) to pick its locale-aware default Bible
    // version, so an English-locale fresh install hit the
    // switch's `default:` branch and got CUVS-YHWH instead of the
    // intended NASB. Writing the detected value back the first
    // time we see an unset prefs key fixes that without touching
    // the read path.
    final persistedLocale = prefs.getString(_kLocale);
    _locale = persistedLocale ?? _detectSystemLocale();
    if (persistedLocale == null) {
      await prefs.setString(_kLocale, _locale);
    }
    _themeMode = _parseThemeMode(prefs.getString(_kThemeMode));
    _paragraphMode = prefs.getBool(_kParagraphMode) ?? true;
    final rawMenuScale = prefs.getDouble(_kMenuScale) ?? 1.0;
    _menuScale = ((rawMenuScale * 10).roundToDouble() / 10).clamp(0.7, 1.5);
    // 2026-05-08 (v1.1.1): card material — default `classic` so
    // existing users see no visual change from earlier versions
    // unless they explicitly opt into a new look.
    final rawCardMaterial = prefs.getString(_kCardMaterial);
    _cardMaterial = CardMaterial.values.firstWhere(
      (m) => m.name == rawCardMaterial,
      orElse: () => CardMaterial.classic,
    );
    final rawBooksView = prefs.getString(_kBooksViewMode) ?? 'grid';
    _booksViewMode = rawBooksView == 'grid' ? 'grid' : 'list';
    _boldVerseText = prefs.getBool(_kBoldVerseText) ?? false;
    _showStrongsInOriginals =
        prefs.getBool(_kShowStrongsInOriginals) ?? true;
    _autoExpandFirstRef = prefs.getBool(_kAutoExpandFirstRef) ?? false;
    _showBibleEvidence = prefs.getBool(_kShowBibleEvidence) ?? true;
    _notificationsEnabled = prefs.getBool(_kNotificationsEnabled) ?? false;
    // 2026-05-24 (v1.3.0): load per-category notification prefs.
    // Stored as one JSON object keyed by category id. Missing keys
    // fall back to NotificationCategoryPrefs.defaultFor at read time
    // (via the notificationCategory() helper), so we don't need to
    // pre-populate the map here.
    final notifCatRaw = prefs.getString(_kNotificationCategories);
    if (notifCatRaw != null && notifCatRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(notifCatRaw) as Map<String, dynamic>;
        final map = <String, NotificationCategoryPrefs>{};
        decoded.forEach((id, value) {
          if (value is Map<String, dynamic>) {
            map[id] = NotificationCategoryPrefs.fromJson(value);
          }
        });
        _notificationCategories = map;
      } catch (_) {
        // Corrupted JSON — fall back to empty (defaults will apply).
        _notificationCategories = {};
      }
    }
    _showSectionTitles = prefs.getBool(_kShowSectionTitles) ?? true;
    _showBookIntro = prefs.getBool(_kShowBookIntro) ?? true;
    _pickVerseAfterChapter =
        prefs.getBool(_kPickVerseAfterChapter) ?? false;
    _geminiApiKey = prefs.getString(_kGeminiApiKey) ?? '';
    // 2026-05-10 (v1.2.26): restore aiModel from prefs. Allowlist
    // -clamp so a corrupt entry doesn't drive the server to an
    // unsupported model — invalid values fall back to default.
    final storedAiModel = prefs.getString(_kAiModel);
    _aiModel = (storedAiModel != null && _kAiModelAllowed.contains(storedAiModel))
        ? storedAiModel
        : _kAiModelDefault;

    // 2026-05-24 (v1.3.19): TTS voice pref restore removed with the
    // 朗读 feature. The stored SharedPreferences keys are left in
    // place as harmless orphan data.

    // 2026-05-24 (v1.2.91): Library → Notes sort mode. Same
    // allowlist-clamp pattern as aiModel.
    final storedNotesSort = prefs.getString(_kNotesSortMode);
    _notesSortMode = (storedNotesSort != null &&
            _kNotesSortAllowed.contains(storedNotesSort))
        ? storedNotesSort
        : _kNotesSortDefault;

    // Dashboard layout (Round 55): load order list + per-section
    // visibility. Missing entries fall back to defaults; the legacy
    // showBibleEvidence / showReadingPlan flags win over the new keys
    // when both are set so a user upgrading from Round 54 keeps their
    // existing toggles.
    final storedOrder = prefs.getStringList(_kDashboardSectionOrder) ?? const [];
    _dashboardSectionOrder = normalizeDashboardOrder(storedOrder);
    _dashboardVisibility.clear();
    for (final s in DashboardSection.values) {
      // Prefer the new key; fall back to the legacy key for the
      // section that pre-dated round 55; final fall-back to
      // defaultVisibility.
      bool? v = prefs.getBool(_kDashboardVisible(s));
      v ??= switch (s) {
        DashboardSection.todayEvidence => prefs.getBool(_kShowBibleEvidence),
        _ => null,
      };
      _dashboardVisibility[s] = v ?? defaultVisibility[s] ?? true;
    }

    // 2026-05-25 (v1.3.41): if a synced userPrefs JSON blob exists
    // (written by another device + downloaded via
    // RealtimeDbSyncService), apply it OVER the legacy individual-
    // key reads above. The blob is the source of truth when present
    // — it carries the most-recent device's full settings snapshot
    // (newest `userPrefsTimestamp` wins via the merge in
    // RealtimeDbSyncService._mergeSnapshots). Fields the blob
    // doesn't contain fall through to the legacy values we just
    // loaded (forward-compatible: an older device that doesn't
    // know a future field can still overwrite the rest).
    final userPrefsBlob = prefs.getString(
        ProfileService.instance.scopedKey('userPrefs'));
    if (userPrefsBlob != null && userPrefsBlob.isNotEmpty) {
      try {
        _applyUserPrefsBlob(jsonDecode(userPrefsBlob) as Map<String, dynamic>);
      } catch (_) {/* corrupt blob → keep legacy values already loaded */}
    }

    notifyListeners();

    // 2026-05-10 (v1.2.17): now that the local key is settled (or
    // confirmed empty), give the cloud copy a chance to fill in
    // when local is blank but the user is signed in on another
    // device that has set one. Fire-and-forget — no point blocking
    // boot on a network round-trip for a non-essential convenience.
    // Local-empty-only policy means a freshly-pasted local key
    // (signed-out → paste → sign-in flow) survives intact; the
    // pull only fills a vacuum.
    // 2026-05-17 (v1.2.47 + v1.2.51): bootstrap BYOK sync — push
    // local first if non-empty so cloud reflects this device,
    // pull otherwise so a fresh device picks up the cloud key.
    // Then subscribe to live changes so subsequent updates on
    // other devices arrive in real time. All branches fire-and-
    // forget; `_doByokSync` itself awaits in order.
    // ignore: unawaited_futures
    _doByokSync();

    // Also re-pull whenever the user signs in on this device. The
    // CloudAuthService notifier fires on every auth-state change;
    // we narrow to "now signed in AND key is currently empty" via
    // the same idempotent helper.
    if (!_authListenerWired) {
      _authListenerWired = true;
      CloudAuthService.instance.addListener(_onAuthChangedForByokSync);
    }
  }

  bool _authListenerWired = false;

  // 2026-05-25 (v1.3.41): debounce timer for the comprehensive
  // userPrefs blob writer. Every change to AppSettings fields
  // triggers notifyListeners(); we schedule a single blob write
  // 600 ms later so a burst of consecutive setter calls (e.g.
  // restoring a sheet that flips 5 toggles in a row) produces
  // exactly one blob write + one RTDB upload, not five.
  Timer? _userPrefsWriteDebounce;
  // While applying the blob from disk, suppress the write-back
  // scheduler — otherwise we'd echo the same blob right back to
  // RTDB on every device load.
  bool _suppressUserPrefsWrite = false;
  // 2026-06-15 (v1.3.80): the last userPrefs blob we actually wrote.
  // Content guard against the "Syncing↔Synced 发癫" flicker loop:
  // `notifyListeners()` fires for MANY reasons (incl. rebuilds driven
  // by a sync-status change that some widget listens to). Each one
  // used to stamp `userPrefsTimestamp = now()` + call requestUpload —
  // and because the timestamp changed every time, the sync layer's
  // own dedupe hash never matched, so it uploaded again, flipped the
  // status, triggered another rebuild → setter → notifyListeners →
  // upload … forever. Skipping the write when the serialized content
  // is byte-identical breaks the feedback loop at the source.
  String? _lastWrittenUserPrefsBlob;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_suppressUserPrefsWrite) return;
    _userPrefsWriteDebounce?.cancel();
    _userPrefsWriteDebounce = Timer(const Duration(milliseconds: 600), () {
      // ignore: unawaited_futures
      _writeUserPrefsBlob();
    });
  }

  /// Serialize all sync-eligible settings into a single JSON blob +
  /// write it to the ProfileService-scoped `userPrefs` key in
  /// SharedPreferences + bump the paired `userPrefsTimestamp` int.
  /// `RealtimeDbSyncService.requestUpload` is then asked to push;
  /// the existing dedupe + debounce in the sync service coalesces
  /// rapid back-to-back uploads.
  ///
  /// `geminiApiKey` is deliberately excluded — it has its own sync
  /// path (`users/{uid}/account/geminiApiKey`, bidirectional stream)
  /// for the credential-security reasons documented near the
  /// `_kGeminiApiKey` declaration.
  /// Single source of truth for the sync-eligible settings snapshot.
  /// Used by both the writer and the content-guard primer so the two
  /// can never drift (a drift would defeat the guard and re-open the
  /// flicker loop). `geminiApiKey` is deliberately excluded — separate
  /// sync path.
  Map<String, dynamic> _userPrefsSnapshot() => {
        'fontFamily': _fontSelection,
        'fontSize': _fontSize,
        'lineSpacing': _lineSpacing,
        'primaryColor': _primaryColor.toARGB32(),
        'copyFormat': _copyFormat,
        'locale': _locale,
        'themeMode': _themeMode.name,
        'paragraphMode': _paragraphMode,
        'menuScale': _menuScale,
        'cardMaterial': _cardMaterial.name,
        'booksViewMode': _booksViewMode,
        'boldVerseText': _boldVerseText,
        'showStrongsInOriginals': _showStrongsInOriginals,
        'autoExpandFirstRef': _autoExpandFirstRef,
        'notificationsEnabled': _notificationsEnabled,
        'showSectionTitles': _showSectionTitles,
        'showBookIntro': _showBookIntro,
        'pickVerseAfterChapter': _pickVerseAfterChapter,
        'aiModel': _aiModel,
        'notesSortMode': _notesSortMode,
        'dashboardSectionOrder':
            _dashboardSectionOrder.map((s) => s.name).toList(),
        'dashboardVisibility': {
          for (final e in _dashboardVisibility.entries) e.key.name: e.value,
        },
      };

  Future<void> _writeUserPrefsBlob() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blob = jsonEncode(_userPrefsSnapshot());
      // Content guard (v1.3.80): nothing sync-eligible actually
      // changed → don't bump the timestamp or trigger an upload.
      // This is the fix for the "Syncing↔Synced 来回跳" loop — a
      // status-driven rebuild that nudges any setter no longer
      // churns the sync pipeline when the resulting blob is the same.
      if (blob == _lastWrittenUserPrefsBlob) return;
      _lastWrittenUserPrefsBlob = blob;
      await prefs.setString(
          ProfileService.instance.scopedKey('userPrefs'), blob);
      await prefs.setInt(
          ProfileService.instance.scopedKey('userPrefsTimestamp'),
          DateTime.now().millisecondsSinceEpoch);
      RealtimeDbSyncService.instance.requestUpload();
    } catch (e) {
      // Non-fatal — the legacy per-key writes already persisted the
      // change locally. The sync just won't carry until the next
      // successful blob write.
      debugPrint('AppSettings._writeUserPrefsBlob failed: $e');
    }
  }

  /// Apply a previously-serialized userPrefs blob onto the live
  /// state. Called from `loadSettings` after legacy per-key reads
  /// when the blob is present; takes precedence so a newer
  /// synced-blob device's preferences win over the local
  /// individual-key reads. Suppresses the write-back debounce so
  /// applying the blob doesn't immediately re-upload an identical
  /// copy.
  void _applyUserPrefsBlob(Map<String, dynamic> m) {
    _suppressUserPrefsWrite = true;
    try {
      if (m['fontFamily'] is String) {
        _fontSelection = m['fontFamily'] as String;
        _fontFamily = resolveFontFamily(_fontSelection);
      }
      if (m['fontSize'] is num) _fontSize = (m['fontSize'] as num).toDouble();
      if (m['lineSpacing'] is num) {
        _lineSpacing = (m['lineSpacing'] as num).toDouble();
      }
      if (m['primaryColor'] is num) {
        _primaryColor = Color((m['primaryColor'] as num).toInt());
      }
      if (m['copyFormat'] is String) _copyFormat = m['copyFormat'] as String;
      if (m['locale'] is String) _locale = m['locale'] as String;
      if (m['themeMode'] is String) {
        _themeMode = _parseThemeMode(m['themeMode'] as String);
      }
      if (m['paragraphMode'] is bool) _paragraphMode = m['paragraphMode'] as bool;
      if (m['menuScale'] is num) _menuScale = (m['menuScale'] as num).toDouble();
      if (m['cardMaterial'] is String) {
        _cardMaterial = CardMaterial.values.firstWhere(
          (c) => c.name == m['cardMaterial'],
          orElse: () => _cardMaterial,
        );
      }
      if (m['booksViewMode'] is String) {
        final raw = m['booksViewMode'] as String;
        _booksViewMode = raw == 'grid' ? 'grid' : 'list';
      }
      if (m['boldVerseText'] is bool) _boldVerseText = m['boldVerseText'] as bool;
      if (m['showStrongsInOriginals'] is bool) {
        _showStrongsInOriginals = m['showStrongsInOriginals'] as bool;
      }
      if (m['autoExpandFirstRef'] is bool) {
        _autoExpandFirstRef = m['autoExpandFirstRef'] as bool;
      }
      if (m['notificationsEnabled'] is bool) {
        _notificationsEnabled = m['notificationsEnabled'] as bool;
      }
      if (m['showSectionTitles'] is bool) {
        _showSectionTitles = m['showSectionTitles'] as bool;
      }
      if (m['showBookIntro'] is bool) {
        _showBookIntro = m['showBookIntro'] as bool;
      }
      if (m['pickVerseAfterChapter'] is bool) {
        _pickVerseAfterChapter = m['pickVerseAfterChapter'] as bool;
      }
      if (m['aiModel'] is String) {
        final raw = m['aiModel'] as String;
        _aiModel =
            _kAiModelAllowed.contains(raw) ? raw : _kAiModelDefault;
      }
      if (m['notesSortMode'] is String) {
        final raw = m['notesSortMode'] as String;
        _notesSortMode =
            _kNotesSortAllowed.contains(raw) ? raw : _kNotesSortDefault;
      }
      if (m['dashboardSectionOrder'] is List) {
        final names = (m['dashboardSectionOrder'] as List)
            .map((e) => e.toString())
            .toList();
        _dashboardSectionOrder = normalizeDashboardOrder(names);
      }
      if (m['dashboardVisibility'] is Map) {
        final viz = m['dashboardVisibility'] as Map;
        for (final s in DashboardSection.values) {
          final v = viz[s.name];
          if (v is bool) _dashboardVisibility[s] = v;
        }
      }
    } finally {
      _suppressUserPrefsWrite = false;
      // Prime the content guard with the blob we just applied so the
      // write-back scheduled by loadSettings' notifyListeners() sees
      // identical content and skips the redundant seed-upload.
      _lastWrittenUserPrefsBlob = jsonEncode(_userPrefsSnapshot());
    }
  }

  void _onAuthChangedForByokSync() {
    if (!CloudAuthService.instance.isSignedIn) {
      // Signed out — tear down the live listener; it will be
      // re-established on next sign-in. Fire-and-forget; cancel()
      // returns a Future but there's nothing to await here.
      // ignore: unawaited_futures
      _unsubscribeFromGeminiKeyChanges();
      return;
    }
    // 2026-05-17 (v1.2.51): push-then-subscribe (or pull-then-
    // subscribe) so the stream's first emission matches local —
    // avoids the v1.2.47 surprise where local was preserved even
    // when cloud had a more recent key from another device.
    // ignore: unawaited_futures
    _doByokSync();
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
