import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/sermon_topics.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/sermon.dart';
import 'package:yswords/utils/floating_toast.dart' show showFloatingToast;
import 'package:yswords/utils/passage_localizer.dart'
    show localizePassage, passageRefPattern;
import 'package:yswords/widgets/verse_popup_sheet.dart' show showVersePopup;
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Reads one sermon body in the user's preferred language with a
/// language-toggle (EN / 简 / 繁) at the top.
///
/// The body is plain prose (Markdown H1 first line + paragraphs).
/// Each paragraph renders via `SelectableText.rich` with one
/// [TextSpan] per matched Bible reference (regex from
/// `lib/utils/passage_localizer.dart`). Tapping a reference opens a
/// `VersePopupSheet` modal so the user can peek at the cited verses
/// without losing their place in the sermon. In zh locales the
/// matched span text is rewritten to the locale's preferred book
/// name (e.g. "Mt5:27-30" → "马太福音 5:27-30").
///
/// Font size + family follow the user's reader settings via
/// `AppSettings`, so sermon text matches the look of the Bible
/// reader.
class SermonDetailPage extends StatefulWidget {
  final Sermon sermon;
  const SermonDetailPage({super.key, required this.sermon});

  @override
  State<SermonDetailPage> createState() => _SermonDetailPageState();
}

class _SermonDetailPageState extends State<SermonDetailPage> {
  /// Currently-displayed body language code: 'en', 'zh-CN', 'zh-TW'.
  String? _lang;
  String? _body;
  bool _loading = true;
  String? _error;

  /// True once the user has manually picked a language via the
  /// toggle. Until then we mirror the app's UI locale, so a user who
  /// just changed the app to 简体 sees Simplified Chinese sermons by
  /// default — and a user opening a fresh sermon while the app is on
  /// English sees English. After a manual pick we stop tracking the
  /// app locale so we don't yank the user back when they're reading.
  bool _userPickedLang = false;

  /// Cached app locale we've already loaded against. Prevents a
  /// redundant reload on every AppSettings notify (e.g. font-size
  /// change which also fires `notifyListeners`).
  String? _loadedForAppLocale;

  AppSettings? _settings;

  /// Scroll controller for the sermon body. Owned by this State so we
  /// can both observe scroll progress (for the Scrollbar + position
  /// persistence) and programmatically restore the saved offset on
  /// re-entry.
  final ScrollController _scrollController = ScrollController();

  /// Debounced timer for persisting the scroll offset. We don't want
  /// to write SharedPreferences on every pixel of scroll — coalesce
  /// rapid changes into a single write 600 ms after the user stops
  /// scrolling.
  Timer? _saveOffsetDebounce;

  /// True once we've attempted to restore the user's last-saved
  /// scroll offset for the currently-loaded body. Prevents repeated
  /// restores when the body finishes loading after the controller has
  /// already attached.
  bool _restoredOffset = false;

  /// Best-known reading progress (0.0–1.0). Updated as the user
  /// scrolls so the AppBar progress indicator reflects it live.
  double _progress = 0.0;

  /// True once the user has scrolled past the inline header (title +
  /// meta chips + language toggle). Drives the AppBar title swap from
  /// the generic "Sermon" label to the actual sermon title — a single
  /// source of truth for "where am I" once the inline title scrolls
  /// off-screen.
  bool _titleScrolledOff = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = Provider.of<AppSettings>(context, listen: false);
    if (_settings != s) {
      _settings?.removeListener(_onSettingsChanged);
      _settings = s;
      _settings!.addListener(_onSettingsChanged);
      // First entry: load against the app locale.
      _maybeReloadForAppLocale();
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _saveOffsetDebounce?.cancel();
    _flushSaveOffset(); // Save synchronously on dispose
    _scrollController.dispose();
    _settings?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  // ── Scroll persistence ───────────────────────────────────────────

  /// Build the SharedPreferences key for this sermon's saved offset.
  /// Includes the language so flipping between EN/简/繁 doesn't yank
  /// the user from a familiar position to a stale one in the other
  /// language. (Body lengths differ across languages so a raw offset
  /// would be meaningless across lang switches.)
  String _offsetKey(String lang) => 'sermonScroll:${widget.sermon.id}:$lang';

  Future<void> _saveOffset() async {
    final lang = _lang;
    if (lang == null) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final pixels = pos.pixels;
    final max = pos.maxScrollExtent;
    final prefs = await SharedPreferences.getInstance();
    // Avoid writing tiny values — there's no point persisting "almost
    // top". Lets the user "reset" by scrolling to top.
    if (pixels < 24) {
      await prefs.remove(_offsetKey(lang));
    } else {
      await prefs.setDouble(_offsetKey(lang), pixels);
    }
    // Stash the max separately so a future restore can compare and
    // refuse to restore an offset past the end of a now-truncated
    // body (e.g. after a re-ingestion).
    await prefs.setDouble('${_offsetKey(lang)}:max', max);
  }

  void _flushSaveOffset() {
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    if (pixels < 24) return;
    // Fire-and-forget on dispose; no await available.
    SharedPreferences.getInstance().then((prefs) {
      final lang = _lang;
      if (lang == null) return;
      prefs.setDouble(_offsetKey(lang), pixels);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    final newProgress = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    // The inline title block (title + meta chips + language toggle)
    // takes roughly the first 110 px of the body. Past that, swap
    // the AppBar's generic "Sermon" label for the actual title so
    // the user always knows what they're reading without scrolling
    // back up.
    final shouldShowTitle = pos.pixels > 110;
    final progressChanged = (newProgress - _progress).abs() > 0.005;
    final titleChanged = shouldShowTitle != _titleScrolledOff;
    if (progressChanged || titleChanged) {
      // Avoid rebuilding for sub-percent scroll movement. The
      // progress indicator at the top of the body re-renders on
      // every setState — keep it cheap.
      setState(() {
        if (progressChanged) _progress = newProgress;
        if (titleChanged) _titleScrolledOff = shouldShowTitle;
      });
    }
    _saveOffsetDebounce?.cancel();
    _saveOffsetDebounce =
        Timer(const Duration(milliseconds: 600), _saveOffset);
  }

  Future<void> _restoreOffsetIfAny() async {
    final lang = _lang;
    if (lang == null || _restoredOffset) return;
    _restoredOffset = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_offsetKey(lang));
    if (saved == null || saved < 24) return;
    // Wait until the ListView has laid out and reported its
    // maxScrollExtent — only then is jumpTo meaningful.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted || !_scrollController.hasClients) return;
    final maxNow = _scrollController.position.maxScrollExtent;
    final clamped = saved.clamp(0.0, maxNow);
    _scrollController.jumpTo(clamped);
    if (mounted) {
      setState(() => _progress = maxNow > 0 ? clamped / maxNow : 0.0);
    }
  }

  void _onSettingsChanged() {
    if (!mounted || _userPickedLang) return;
    _maybeReloadForAppLocale();
  }

  void _maybeReloadForAppLocale() {
    final s = _settings;
    if (s == null) return;
    if (s.locale == _loadedForAppLocale) return;
    _loadedForAppLocale = s.locale;
    _loadForAppLocale(s.locale);
  }

  Future<void> _loadForAppLocale(String appLocale) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final loc = _localeToBodyLang(appLocale);
    try {
      final res = await SermonService.instance.loadBestBody(
        sermon: widget.sermon,
        locale: loc,
      );
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _loading = false;
          _error = uiStrings['sermonNoBody']?[appLocale] ??
              'No body text available for this sermon.';
        });
        return;
      }
      setState(() {
        _lang = res.lang;
        _body = res.body;
        _loading = false;
        _restoredOffset = false; // Allow restore for the new body.
      });
      // Restore on the next frame, after the ListView has laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreOffsetIfAny();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            '${uiStrings['loadErrorTitle']?[appLocale] ?? 'Failed to load'}: $e';
      });
    }
  }

  Future<void> _switchTo(String lang) async {
    if (lang == _lang) return;
    _userPickedLang = true;
    final has = lang == 'en'
        ? widget.sermon.hasEn
        : lang == 'zh-CN'
            ? widget.sermon.hasZhCn
            : widget.sermon.hasZhTw;
    if (!has) return;
    // Save the current language's offset before switching, so the
    // user can return to where they were in language A while reading
    // in language B.
    _saveOffsetDebounce?.cancel();
    _saveOffset();
    setState(() => _loading = true);
    final body = await SermonService.instance
        .loadBody(id: widget.sermon.id, lang: lang);
    if (!mounted) return;
    setState(() {
      _lang = lang;
      _body = body ?? '';
      _loading = false;
      _restoredOffset = false; // Restore for the new language's body.
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreOffsetIfAny();
    });
  }

  String _localeToBodyLang(String appLocale) {
    switch (appLocale) {
      case 'zh-Hant':
        return 'zh-TW';
      case 'zh-Hans':
        return 'zh-CN';
      default:
        return 'en';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final s = widget.sermon;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        // Generic "Sermon" label when the inline title is still on-
        // screen, the actual sermon title once it scrolls off — gives
        // the user a persistent reminder of what they're reading
        // without stealing horizontal space when not needed.
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
                  s.localizedTitle(settings.locale),
                  key: ValueKey('title-${s.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Text(
                  uiStrings['sermon']?[settings.locale] ?? 'Sermon',
                  key: const ValueKey('label-sermon'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
        actions: [
          // 2026-05-24 (v1.3.19): ListenButton (AI TTS) removed with
          // the rest of the 朗读 feature.
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: uiStrings['sermonCopyAll']?[settings.locale] ??
                'Copy sermon',
            onPressed: () => _copySermonBody(s, settings.locale),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            tooltip: uiStrings['shareLink']?[settings.locale] ??
                'Share link',
            onPressed: () => _shareSermon(s, settings.locale),
          ),
          const HomeIconButton(),
        ],
        // Reading-progress strip under the AppBar — width-tracks the
        // user's scroll through the body. Visible whenever the body
        // has actually scrolled (avoids a stale "0%" bar above
        // un-scrollable content like the metadata header on small
        // bodies). Updates live via _onScroll.
        bottom: _progress > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2,
                  backgroundColor:
                      scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              )
            : null,
      ),
      body: SafeArea(
        // The Scrollbar gives the user a persistent visual indicator
        // of where they are in a long body — important because a
        // sermon transcript can run 30–50 paragraphs and is easy to
        // get lost in. Always-visible thumb (vs Flutter's default
        // hover-only) per round-51 user feedback "there should be a
        // bar at the right".
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              s.localizedTitle(settings.locale),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaChip(label: '#${s.id}'),
                if (s.displayDate != '—') _MetaChip(label: s.displayDate),
                // The "A/B parts" chip used to live here. Removed in
                // Round 56 — the sermons are already concatenated for
                // display, so showing "A/B parts" only confused users
                // into thinking the body was incomplete. The `parts`
                // field stays on the model for audit / future use.
                // Multi-passage sermons (e.g. sermon 005's
                // "Mt 3:15 and Mt 4:17", sermon 046/047's
                // "Mt 7:21-27 and Lk 6:46-49") render as ONE chip per
                // ref so each is independently tappable + localized.
                // Splits on " and " / " 和 " / " 與 " / "; " — the
                // common ways sermon refs are joined in the index.
                ...[
                  for (final segment in _splitPassageSegments(s.passage))
                    _MetaChip(
                      label: _localizedPassage(segment, settings.locale),
                      color: scheme.primaryContainer,
                      fg: scheme.onPrimaryContainer,
                      onTap: () => _openPassagePopup(segment),
                    ),
                ],
                _MetaChip(
                  label: localizedSermonTopic(s.topic, settings.locale),
                  color: scheme.surfaceContainerHigh,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LanguageToggle(
              sermon: s,
              currentLang: _lang,
              appLocale: settings.locale,
              onSelect: _switchTo,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              )
            else
              _SermonBody(text: _body ?? '', settings: settings),
            ],
          ),
        ),
      ),
    );
  }

  /// Copy the full sermon — title + metadata + body + attribution
  /// footer — to the clipboard so users can paste into their
  /// notes / Word / messaging apps. Always appends a "From
  /// YsWords (Yahweh's Words)" line with the deep-link URL so
  /// recipients know the source. Floating toast confirms.
  Future<void> _copySermonBody(Sermon s, String locale) async {
    final body = _body ?? '';
    if (body.isEmpty) {
      // Body still loading — surface a clear message rather than
      // copying an empty payload.
      showFloatingToast(
        context,
        message:
            uiStrings['sermonCopyEmpty']?[locale] ?? 'Sermon not loaded yet',
        icon: Icons.error_outline_rounded,
        background: Theme.of(context).colorScheme.error,
      );
      return;
    }
    final title = s.titles[_titleLocaleKey(locale)] ?? s.title;
    final url =
        'https://yswords.netlify.app/?sermon=${Uri.encodeComponent(s.id)}';
    final attribution = uiStrings['sermonAttribution']?[locale] ??
        'From YsWords (Yahweh\'s Words)';
    final buf = StringBuffer();
    buf.writeln(title);
    final metaParts = <String>[];
    if (s.displayDate.isNotEmpty && s.displayDate != '—') {
      metaParts.add(s.displayDate);
    }
    if (s.passage.isNotEmpty) metaParts.add(s.passage);
    if (metaParts.isNotEmpty) buf.writeln(metaParts.join(' · '));
    buf.writeln();
    buf.writeln(body.trim());
    buf.writeln();
    buf.writeln('— $attribution');
    buf.writeln(url);

    final ok = await ClipboardHelper.copyText(buf.toString().trim());
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    showFloatingToast(
      context,
      message: ok
          ? (uiStrings['sermonCopied']?[locale] ?? 'Sermon copied')
          : (uiStrings['shareLinkFailed']?[locale] ??
              'Copy failed — clipboard unavailable'),
      icon: ok
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      background: ok ? scheme.primary : scheme.error,
    );
  }

  /// Build a deep-link URL for this sermon and copy it (plus the
  /// localized title) to the clipboard, with a floating toast
  /// confirming "Share link copied" / "分享链接已复制" /
  /// "分享連結已複製".
  Future<void> _shareSermon(Sermon s, String locale) async {
    final title = s.titles[_titleLocaleKey(locale)] ?? s.title;
    final url =
        'https://yswords.netlify.app/?sermon=${Uri.encodeComponent(s.id)}';
    final payload = '$title\n$url';
    final ok = await ClipboardHelper.copyText(payload);
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    showFloatingToast(
      context,
      message: ok
          ? (uiStrings['shareLinkCopied']?[locale] ??
              'Share link copied')
          : (uiStrings['shareLinkFailed']?[locale] ??
              'Copy failed — clipboard unavailable'),
      icon: ok
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      background: ok ? scheme.primary : scheme.error,
    );
  }

  String _titleLocaleKey(String locale) {
    if (locale == 'zh-Hant') return 'zh-TW';
    if (locale.startsWith('zh')) return 'zh-CN';
    return 'en';
  }

  /// Rewrite a passage like `Mt 7:21-27 and Lk 6:46-49` into the
  /// reader's locale (`马太福音 7:21-27 and 路加福音 6:46-49`). Thin
  /// wrapper around the shared [localizePassage] utility so the
  /// sermon list and detail page stay in sync.
  String _localizedPassage(String passage, String locale) =>
      localizePassage(passage, locale);

  /// Split a multi-citation passage string into individual segments
  /// that each contain (at most) one Bible reference. Recognises
  /// the join words / punctuation actually used in the sermon index:
  ///   • English: " and " / " AND " / " & " / "; "
  ///   • Chinese: " 和 " / " 與 " / "；"
  ///
  /// Returns a list of trimmed non-empty segments. Single-ref
  /// passages return a single-element list; empty input returns
  /// an empty list.
  static final RegExp _passageSplitPattern = RegExp(
    r'\s+and\s+|\s+&\s+|\s*;\s*|\s+和\s+|\s+與\s+|\s*；\s*',
    caseSensitive: false,
  );
  List<String> _splitPassageSegments(String passage) {
    if (passage.trim().isEmpty) return const [];
    final parts = passage.split(_passageSplitPattern);
    return [
      for (final p in parts)
        if (p.trim().isNotEmpty) p.trim(),
    ];
  }

  /// Tap the passage chip → open the [VersePopupSheet] for the first
  /// reference in the passage. Multi-ref passages like
  /// `Mt 7:21-27 and Lk 6:46-49` only popup the first ref; the user
  /// can hit "Open in reader" if they want to navigate further.
  Future<void> _openPassagePopup(String passage) async {
    if (passage.trim().isEmpty) return;
    BibleReference? ref;
    final m = _SermonBody._refPattern.firstMatch(passage);
    if (m != null) {
      ref = parseReference(m.group(0)!);
    }
    ref ??= parseReference(passage);
    if (ref == null) return;
    if (!mounted) return;
    await showVersePopup(context, ref);
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? fg;

  /// Optional tap handler. When non-null, the chip becomes
  /// interactive (cursor pointer, ripple) — used for the passage
  /// chip so a tap opens the verse popup.
  final VoidCallback? onTap;

  const _MetaChip({required this.label, this.color, this.fg, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: onTap == null
            ? null
            : Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
                width: 0.7,
              ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: fg ?? scheme.onSurface.withValues(alpha: 0.75),
          decoration: onTap == null ? null : TextDecoration.underline,
          decorationColor:
              onTap == null ? null : (fg ?? scheme.primary).withValues(alpha: 0.4),
          decorationStyle: TextDecorationStyle.dotted,
        ),
      ),
    );
    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: body,
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final Sermon sermon;
  final String? currentLang;
  final String appLocale;
  final void Function(String lang) onSelect;

  const _LanguageToggle({
    required this.sermon,
    required this.currentLang,
    required this.appLocale,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Order entries so the user's UI-locale-matched language appears
    // first — reinforces that it's the visual default and matches
    // their reading preference. The user can still pick the others;
    // they just don't lead the row.
    final allEntries = <(String, String, bool)>[
      ('en', 'English', sermon.hasEn),
      ('zh-CN', '简体', sermon.hasZhCn),
      ('zh-TW', '繁體', sermon.hasZhTw),
    ];
    final preferred = appLocale == 'zh-Hant'
        ? 'zh-TW'
        : appLocale == 'zh-Hans'
            ? 'zh-CN'
            : 'en';
    allEntries.sort((a, b) {
      if (a.$1 == preferred) return -1;
      if (b.$1 == preferred) return 1;
      return 0;
    });
    final entries = allEntries;
    return Wrap(
      spacing: 8,
      children: [
        for (final (code, label, has) in entries)
          ChoiceChip(
            label: Text(label),
            selected: currentLang == code,
            onSelected: has ? (_) => onSelect(code) : null,
            backgroundColor:
                has ? null : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            disabledColor:
                scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            labelStyle: TextStyle(
              fontSize: 12.5,
              color: has
                  ? null
                  : scheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}

class _SermonBody extends StatelessWidget {
  final String text;
  final AppSettings settings;

  const _SermonBody({required this.text, required this.settings});

  /// Pattern for inline Bible references — shared with the sermon
  /// list and any other surface that wants to detect/rewrite refs.
  /// See `lib/utils/passage_localizer.dart` for the full pattern.
  static final RegExp _refPattern = passageRefPattern;

  @override
  Widget build(BuildContext context) {
    // The first line is a Markdown H1 already shown in the page title.
    // Drop it from the body so we don't render the title twice.
    final lines = text.split('\n');
    var start = 0;
    if (lines.isNotEmpty && lines.first.startsWith('# ')) start = 1;
    // Skip blank lines after the title.
    while (start < lines.length && lines[start].trim().isEmpty) {
      start += 1;
    }
    final body = lines.sublist(start).join('\n').trim();

    // Split on blank lines for paragraph spacing.
    final paragraphs = body.split(RegExp(r'\n\s*\n'));
    final fontSize = settings.fontSize;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in paragraphs)
          if (p.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SelectableText.rich(
                _buildSpans(context, p.trim(), fontSize, scheme),
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.55,
                ),
              ),
            ),
      ],
    );
  }

  /// Build a [TextSpan] tree where every Bible-reference match
  /// becomes a tappable underlined span. Non-matching slices are
  /// plain text so the user can still select-and-copy normally.
  ///
  /// Display form follows the user's UI locale: in `zh-Hans`/`zh-Hant`
  /// the matched text is rewritten to the locale's preferred book
  /// name (e.g. "Mt5:27-30" → "马太福音 5:27-30"), so a Chinese
  /// reader doesn't see raw English abbreviations like "Mt".
  TextSpan _buildSpans(
    BuildContext context,
    String paragraph,
    double fontSize,
    ColorScheme scheme,
  ) {
    final locale = settings.locale;
    final spans = <InlineSpan>[];
    var idx = 0;
    for (final match in _refPattern.allMatches(paragraph)) {
      if (match.start > idx) {
        spans.add(TextSpan(text: paragraph.substring(idx, match.start)));
      }
      final matched = match.group(0)!;
      // Only treat as a link if our parser actually recognises it —
      // this filters out false positives like "Mark sat down" that
      // the regex catches but the alias index rejects.
      final parsed = parseReference(matched);
      if (parsed == null) {
        spans.add(TextSpan(text: matched));
      } else {
        // Prefer the user's locale for display. We only rewrite when
        // the locale name actually differs from what's already in
        // the body text — otherwise the display would jitter (e.g.
        // English body in English locale stays as-is).
        final localizedBook = localeAwareBookName(parsed.englishBook, locale);
        var displayText = matched;
        if (locale.startsWith('zh')) {
          final tail = StringBuffer();
          tail.write(' ${parsed.chapter}');
          if (parsed.verseStart != null) {
            tail.write(':${parsed.verseStart}');
            if (parsed.verseEnd != null && parsed.verseEnd! > parsed.verseStart!) {
              tail.write('-${parsed.verseEnd}');
            }
          }
          displayText = '$localizedBook${tail.toString()}';
        }
        spans.add(TextSpan(
          text: displayText,
          style: TextStyle(
            color: scheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: scheme.primary.withValues(alpha: 0.4),
            decorationStyle: TextDecorationStyle.dotted,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _jumpToParsedRef(context, parsed),
        ));
      }
      idx = match.end;
    }
    if (idx < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(idx)));
    }
    return TextSpan(children: spans);
  }

  /// Tap a verse-ref chip in a sermon → show a [VersePopupSheet]
  /// modal so the user can peek at the cited verse(s) without
  /// losing their place in the sermon. The popup itself has
  /// "expand to full chapter" and "open in reader" actions.
  Future<void> _jumpToParsedRef(
      BuildContext context, BibleReference ref) async {
    await showVersePopup(context, ref);
  }
}
