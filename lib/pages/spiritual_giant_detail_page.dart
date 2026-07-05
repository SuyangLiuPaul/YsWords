import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/spiritual_giant_categories.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/spiritual_giant.dart';
import 'package:yswords/pages/spiritual_giants_page.dart' show giantAccent;
import 'package:yswords/utils/floating_toast.dart' show showFloatingToast;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Reads one biography from the 属灵伟人小传 / Spiritual Giants corpus,
/// with a language toggle (EN / 简 / 繁) at the top.
///
/// Structure and behaviour mirror [SermonDetailPage] so the two content
/// modules feel identical: an AppBar whose title swaps to the figure's
/// name once the inline header scrolls off, tappable copy/share
/// actions, a reading-progress strip, and body text that follows the
/// reader's font settings.
class SpiritualGiantDetailPage extends StatefulWidget {
  final SpiritualGiant giant;
  const SpiritualGiantDetailPage({super.key, required this.giant});

  @override
  State<SpiritualGiantDetailPage> createState() =>
      _SpiritualGiantDetailPageState();
}

class _SpiritualGiantDetailPageState extends State<SpiritualGiantDetailPage> {
  /// Currently-displayed language code: 'en', 'zh-CN', 'zh-TW'. Starts
  /// as the app locale's match; the user can override via the toggle,
  /// after which we stop tracking the app locale.
  String? _lang;
  bool _userPickedLang = false;
  String? _loadedForAppLocale;
  AppSettings? _settings;

  final ScrollController _scrollController = ScrollController();
  double _progress = 0.0;
  bool _titleScrolledOff = false;

  /// Debounced timer for persisting the scroll offset (coalesces rapid
  /// scroll events into one SharedPreferences write ~600 ms after the
  /// user stops). Mirrors the sermon detail page so the dashboard
  /// "Resume biography" hero can show a live progress meter.
  Timer? _saveOffsetDebounce;

  /// True once we've attempted to restore the saved offset for the
  /// currently-selected language. Reset whenever the language changes
  /// so each language's body restores independently.
  bool _restoredOffset = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Restore the last-saved position once the list has laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffsetIfAny());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = Provider.of<AppSettings>(context, listen: false);
    if (_settings != s) {
      _settings?.removeListener(_onSettingsChanged);
      _settings = s;
      _settings!.addListener(_onSettingsChanged);
      _maybeSyncAppLocale();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _saveOffsetDebounce?.cancel();
    _flushSaveOffset();
    _scrollController.dispose();
    _settings?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted || _userPickedLang) return;
    _maybeSyncAppLocale();
  }

  void _maybeSyncAppLocale() {
    final s = _settings;
    if (s == null) return;
    if (s.locale == _loadedForAppLocale) return;
    _loadedForAppLocale = s.locale;
    final lang = SpiritualGiant.bodyLangForLocale(s.locale);
    final next = widget.giant.hasLang(lang) ? lang : _firstLang();
    if (next == _lang) return;
    _saveOffsetDebounce?.cancel();
    _saveOffset(); // preserve the outgoing language's position
    _restoredOffset = false;
    setState(() => _lang = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffsetIfAny());
  }

  String _firstLang() {
    for (final l in const ['en', 'zh-CN', 'zh-TW']) {
      if (widget.giant.hasLang(l)) return l;
    }
    return 'en';
  }

  void _switchTo(String lang) {
    if (lang == _lang || !widget.giant.hasLang(lang)) return;
    _userPickedLang = true;
    // Save the current language's position before switching, so the
    // user can return to where they were in each language.
    _saveOffsetDebounce?.cancel();
    _saveOffset();
    _restoredOffset = false;
    setState(() => _lang = lang);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffsetIfAny());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final newProgress = pos.maxScrollExtent <= 0
        ? 0.0
        : (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    final shouldShowTitle = pos.pixels > 96;
    final progressChanged = (newProgress - _progress).abs() > 0.005;
    final titleChanged = shouldShowTitle != _titleScrolledOff;
    if (progressChanged || titleChanged) {
      setState(() {
        if (progressChanged) _progress = newProgress;
        if (titleChanged) _titleScrolledOff = shouldShowTitle;
      });
    }
    _saveOffsetDebounce?.cancel();
    _saveOffsetDebounce =
        Timer(const Duration(milliseconds: 600), _saveOffset);
  }

  // ── Scroll persistence (per figure + language) ───────────────────

  /// SharedPreferences key for this figure's saved offset in [lang].
  /// The language is part of the key because body lengths differ, so a
  /// raw pixel offset is only meaningful within one language.
  String _offsetKey(String lang) => 'giantScroll:${widget.giant.id}:$lang';

  Future<void> _saveOffset() async {
    final lang = _lang;
    if (lang == null || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final pixels = pos.pixels;
    final prefs = await SharedPreferences.getInstance();
    // Don't persist "almost top" — lets the user reset by scrolling up.
    if (pixels < 24) {
      await prefs.remove(_offsetKey(lang));
    } else {
      await prefs.setDouble(_offsetKey(lang), pixels);
    }
    await prefs.setDouble('${_offsetKey(lang)}:max', pos.maxScrollExtent);
  }

  void _flushSaveOffset() {
    if (!_scrollController.hasClients) return;
    final lang = _lang;
    final pixels = _scrollController.position.pixels;
    if (lang == null || pixels < 24) return;
    // Fire-and-forget on dispose; no await available.
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setDouble(_offsetKey(lang), pixels));
  }

  Future<void> _restoreOffsetIfAny() async {
    final lang = _lang;
    if (lang == null || _restoredOffset) return;
    _restoredOffset = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_offsetKey(lang));
    if (saved == null || saved < 24) return;
    // Wait for the ListView to lay out and report its extent.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted || !_scrollController.hasClients) return;
    final maxNow = _scrollController.position.maxScrollExtent;
    final clamped = saved.clamp(0.0, maxNow);
    _scrollController.jumpTo(clamped);
    if (mounted) {
      setState(() => _progress = maxNow > 0 ? clamped / maxNow : 0.0);
    }
  }

  /// Body text for the currently-selected language, falling back to the
  /// app locale's pick if nothing is selected yet.
  String _currentBody(String appLocale) {
    final lang = _lang;
    if (lang != null) {
      final v = widget.giant.bio[lang];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return widget.giant.localizedBio(appLocale);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final g = widget.giant;
    final locale = settings.locale;
    final accent = giantAccent(g.category);
    final name = g.localizedName(locale);
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _titleScrolledOff
              ? Text(
                  name,
                  key: ValueKey('title-${g.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                )
              : Text(
                  uiStrings['spiritualGiants']?[locale] ?? 'Spiritual Giants',
                  key: const ValueKey('label-giants'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: uiStrings['giantsCopy']?[locale] ?? 'Copy',
            onPressed: () => _copyBio(g, locale),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            tooltip: uiStrings['shareLink']?[locale] ?? 'Share link',
            onPressed: () => _shareGiant(g, locale),
          ),
          const HomeIconButton(),
        ],
        bottom: _progress > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2,
                  backgroundColor:
                      scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: accent,
                    child: Text(
                      name.isNotEmpty ? name.characters.first : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (g.years.isNotEmpty) _MetaChip(label: g.years),
                  _MetaChip(
                    label: localizedGiantCategory(g.category, locale),
                    color: accent.withValues(alpha: 0.16),
                    fg: accent,
                  ),
                  _MetaChip(label: g.localizedRole(locale)),
                ],
              ),
              const SizedBox(height: 14),
              _LanguageToggle(
                giant: g,
                currentLang: _lang,
                appLocale: locale,
                onSelect: _switchTo,
              ),
              const SizedBox(height: 16),
              _BioBody(
                text: _currentBody(locale),
                settings: settings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyBio(SpiritualGiant g, String locale) async {
    final name = g.localizedName(locale);
    final buf = StringBuffer()
      ..writeln(name)
      ..writeln([
        if (g.years.isNotEmpty) g.years,
        g.localizedRole(locale),
      ].join(' · '))
      ..writeln()
      ..writeln(_currentBody(locale))
      ..writeln()
      ..writeln('— ${uiStrings['sermonAttribution']?[locale] ?? 'From YsWords'}')
      ..writeln('https://yswords.netlify.app/?giant=${Uri.encodeComponent(g.id)}');
    bool ok = true;
    try {
      await Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    showFloatingToast(
      context,
      message: ok
          ? (uiStrings['giantsCopied']?[locale] ?? 'Copied')
          : (uiStrings['shareLinkFailed']?[locale] ??
              'Copy failed — clipboard unavailable'),
      icon: ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      background: ok ? scheme.primary : scheme.error,
    );
  }

  Future<void> _shareGiant(SpiritualGiant g, String locale) async {
    final name = g.localizedName(locale);
    final url =
        'https://yswords.netlify.app/?giant=${Uri.encodeComponent(g.id)}';
    bool ok = true;
    try {
      await Clipboard.setData(ClipboardData(text: '$name\n$url'));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    showFloatingToast(
      context,
      message: ok
          ? (uiStrings['shareLinkCopied']?[locale] ?? 'Share link copied')
          : (uiStrings['shareLinkFailed']?[locale] ??
              'Copy failed — clipboard unavailable'),
      icon: ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      background: ok ? scheme.primary : scheme.error,
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? fg;
  const _MetaChip({required this.label, this.color, this.fg});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: fg ?? scheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final SpiritualGiant giant;
  final String? currentLang;
  final String appLocale;
  final void Function(String lang) onSelect;

  const _LanguageToggle({
    required this.giant,
    required this.currentLang,
    required this.appLocale,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allEntries = <(String, String)>[
      ('en', 'English'),
      ('zh-CN', '简体'),
      ('zh-TW', '繁體'),
    ];
    final preferred = SpiritualGiant.bodyLangForLocale(appLocale);
    allEntries.sort((a, b) {
      if (a.$1 == preferred) return -1;
      if (b.$1 == preferred) return 1;
      return 0;
    });
    return Wrap(
      spacing: 8,
      children: [
        for (final (code, label) in allEntries)
          ChoiceChip(
            label: Text(label),
            selected: currentLang == code,
            onSelected:
                giant.hasLang(code) ? (_) => onSelect(code) : null,
            backgroundColor: giant.hasLang(code)
                ? null
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            labelStyle: const TextStyle(fontSize: 12.5),
          ),
      ],
    );
  }
}

class _BioBody extends StatelessWidget {
  final String text;
  final AppSettings settings;
  const _BioBody({required this.text, required this.settings});

  @override
  Widget build(BuildContext context) {
    final fontSize = settings.fontSize;
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in paragraphs)
          if (p.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SelectableText(
                p.trim(),
                style: TextStyle(fontSize: fontSize, height: 1.6),
              ),
            ),
      ],
    );
  }
}
