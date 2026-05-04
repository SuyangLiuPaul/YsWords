import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_map.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/books_page.dart';
import 'package:yswords/pages/evidence_page.dart';
import 'package:yswords/pages/highlights_page.dart';
import 'package:yswords/pages/library_page.dart';
import 'package:yswords/pages/map_viewer_page.dart';
import 'package:yswords/pages/search_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/pages/stats_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/constants/sermon_topics.dart';
import 'package:yswords/models/sermon.dart';
import 'package:yswords/pages/sermon_detail_page.dart';
import 'package:yswords/services/cross_reference_service.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/book_intro_service.dart';
import 'package:yswords/services/map_service.dart';
import 'package:yswords/services/section_title_service.dart';
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/services/synopsis_service.dart';
import 'package:yswords/services/tts_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/jump_to_reference.dart' show prepareJumpToVerse;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/google_g_logo.dart';
import 'package:yswords/widgets/today_reading_card.dart';
import 'package:yswords/utils/floating_toast.dart' show showFloatingToast;
import 'package:yswords/utils/version_mapper.dart'
    show translateBookName, toEnglish, localeAwareBookName;
import 'package:yswords/widgets/highlights_sheet.dart';
import 'package:yswords/widgets/originals_sheet.dart';
import 'package:yswords/widgets/verse_widget.dart';
import 'package:yswords/widgets/paragraph_group_widget.dart';

class BibleReadingPane extends StatefulWidget {
  final bool showSidebarToggle;
  final bool sidebarOpen;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onToggleSplitView;
  final bool splitViewActive;
  final VoidCallback? onClose;
  final bool showSearchAndSettings;

  const BibleReadingPane({
    super.key,
    this.showSidebarToggle = false,
    this.sidebarOpen = false,
    this.onToggleSidebar,
    this.onToggleSplitView,
    this.splitViewActive = false,
    this.onClose,
    this.showSearchAndSettings = true,
  });

  @override
  State<BibleReadingPane> createState() => _BibleReadingPaneState();
}

class _BibleReadingPaneState extends State<BibleReadingPane> {
  MainProvider? _positionsProvider;
  int _visibleItemIndex = 0;
  bool _showVersePosition = false;
  Timer? _versePositionTimer;
  /// Pane-local messenger so SnackBars (e.g. the "Copied!" toast) appear
  /// only in the pane that triggered them. Without this, `ScaffoldMessenger
  /// .of(context)` resolves to the app-root messenger and the toast is
  /// shown over both panes in split view.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  /// Maps whose chapter range covers the current book + chapter exactly.
  List<BibleMap> _chapterMaps = [];

  /// Maps that mention the current book at all (any chapter range).
  /// Used as the fallback when [_chapterMaps] is empty so the user
  /// still gets a relevant suggestion (e.g. Acts 22 → Paul's journeys).
  List<BibleMap> _bookMaps = [];
  String _lastBookChapter = '';

  /// Pastor Eric sermons that cite a verse anywhere in the current
  /// (book, chapter). Pre-loaded the same moment the maps are loaded
  /// so the floating-header sermon icon can show a count badge
  /// without a per-frame async lookup. Updated whenever the user
  /// turns to a new chapter — see [_updateSermonsForBookChapter].
  List<Sermon> _chapterSermons = const [];
  String _lastSermonsBookChapter = '';

  /// Polled flag mirroring `TtsService.speaking` so the floating-header
  /// menu can swap its icon/label without recomputing on every frame.
  /// Updated by a 500 ms ticker that runs only while a TTS utterance
  /// is active.
  bool _isListening = false;
  Timer? _ttsPoller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mainProvider = context.read<MainProvider>();
      _attachPositionsListener(mainProvider);
    });
  }

  /// Toggle TTS read-aloud. Plays each verse of the current chapter as
  /// its own utterance so cancellation is responsive and we can flash
  /// a brief highlight on the verse currently being read (`_isListening`
  /// alone wouldn't surface progress to the user).
  void _toggleListenChapter() {
    // Logical state takes precedence over the browser flag because
    // chrome's speechSynthesis.speaking flickers between chunks.
    if (_isListening || TtsService.speaking) {
      TtsService.stop();
      _stopTtsPolling();
      if (mounted) {
        context.read<MainProvider>().clearHighlightIndex();
        setState(() => _isListening = false);
      }
      return;
    }
    final mp = context.read<MainProvider>();
    final book = mp.currentBook;
    final chapter = mp.currentChapter;
    if (book == null || chapter == null) return;
    final chapterVerses = mp.verses
        .where((v) => v.book == book && v.chapter == chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    if (chapterVerses.isEmpty) return;
    // Strip <note:...> tags and {variant} braces so the synthesizer
    // doesn't read editorial markup aloud. One chunk per verse so
    // (a) cancel works deterministically and (b) we can highlight
    // the current verse in the list as it's spoken.
    final chunks = chapterVerses
        .map((v) => sanitizeForSearch(v.text))
        .toList();
    final locale = _ttsLocaleForVersion(mp.currentVersion);
    TtsService.speakSequence(
      chunks,
      locale: locale,
      onAdvance: (idx) {
        if (!mounted) return;
        // Reuse the same in-list highlight machinery used by cross-
        // ref taps. Index here is the verse's position within the
        // chapter, which matches the relative index the list expects.
        mp.setHighlightIndex(idx);
        // Auto-scroll along so the spoken verse is on screen.
        if (mp.itemScrollController.isAttached) {
          mp.scrollToIndex(index: idx);
        }
      },
      onDone: () {
        if (!mounted) return;
        mp.clearHighlightIndex();
        _stopTtsPolling();
        setState(() => _isListening = false);
      },
    );
    setState(() => _isListening = true);
    _startTtsPolling();
  }

  String _ttsLocaleForVersion(String version) {
    final v = version.toLowerCase();
    if (v.contains('cuv') ||
        v.contains('cnv') ||
        v.contains('biblexg') ||
        v.contains('-tr')) {
      // Traditional vs. simplified guess: -tr suffix => zh-TW, else zh-CN.
      return v.endsWith('-tr') ? 'zh-TW' : 'zh-CN';
    }
    return 'en-US';
  }

  void _startTtsPolling() {
    _ttsPoller?.cancel();
    _ttsPoller = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final speaking = TtsService.speaking;
      if (!speaking && _isListening) {
        if (mounted) setState(() => _isListening = false);
        _stopTtsPolling();
      }
    });
  }

  void _stopTtsPolling() {
    _ttsPoller?.cancel();
    _ttsPoller = null;
  }

  /// Show a small dialog listing the keyboard shortcuts. Triggered by
  /// `?` (Shift+/) on web — pure discoverability help; tapping
  /// outside or hitting Esc dismisses.
  void _showShortcutsHelp(BuildContext context, String locale) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <List<String>>[
      ['/', uiStrings['search']?[locale] ?? 'Search'],
      ['[', uiStrings['previousChapter']?[locale] ?? 'Previous chapter'],
      [']', uiStrings['nextChapter']?[locale] ?? 'Next chapter'],
      ['Shift + T', uiStrings['ttsListen']?[locale] ?? 'Listen to chapter'],
      ['?', uiStrings['shortcutsHelp']?[locale] ?? 'Keyboard shortcuts'],
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.keyboard_outlined, color: scheme.primary),
        title: Text(
          uiStrings['shortcutsHelp']?[locale] ?? 'Keyboard shortcuts',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        row[0],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(row[1]),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(uiStrings['ok']?[locale] ?? 'OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _versePositionTimer?.cancel();
    _ttsPoller?.cancel();
    if (_isListening) TtsService.stop();
    _positionsProvider?.itemPositionsListener.itemPositions
        .removeListener(_handleItemPositionsChanged);
    super.dispose();
  }

  void _attachPositionsListener(MainProvider provider) {
    if (_positionsProvider == provider) return;
    _positionsProvider?.itemPositionsListener.itemPositions
        .removeListener(_handleItemPositionsChanged);
    _positionsProvider = provider;
    provider.itemPositionsListener.itemPositions
        .addListener(_handleItemPositionsChanged);
  }

  void _handleItemPositionsChanged() {
    final positions =
        _positionsProvider?.itemPositionsListener.itemPositions.value;
    if (positions == null || positions.isEmpty || !mounted) return;

    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList();
    if (visible.isEmpty) return;

    visible.sort((a, b) {
      final edge = a.itemLeadingEdge.compareTo(b.itemLeadingEdge);
      return edge != 0 ? edge : a.index.compareTo(b.index);
    });
    final nextIndex = visible.first.index;
    if (nextIndex != _visibleItemIndex && mounted) {
      _versePositionTimer?.cancel();
      _versePositionTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showVersePosition = false);
      });
      setState(() {
        _visibleItemIndex = nextIndex;
        _showVersePosition = true;
      });
    }
  }

  void _updateMapsForBookChapter(String book, int chapter) {
    final key = '$book:$chapter';
    if (key == _lastBookChapter) return;
    _lastBookChapter = key;
    final en = bookNameToEnglish[book] ?? book;
    Future.wait([
      MapService.mapsForBookChapter(en, chapter),
      MapService.mapsForBook(en),
    ]).then((results) {
      if (!mounted) return;
      // Discard a stale result if the user already switched chapters
      // while this Future was in flight — without this guard, an old
      // chapter's maps could overwrite the new chapter's maps and
      // briefly flicker the wrong fallback in the picker.
      if (_lastBookChapter != key) return;
      final chapterMaps = results[0];
      final bookMaps = results[1];
      // Subtract chapter matches so the "book" section only shows the
      // additional related maps and we don't render duplicates.
      final extraBookMaps = bookMaps
          .where((m) => !chapterMaps.any((c) => c.id == m.id))
          .toList();
      setState(() {
        _chapterMaps = chapterMaps;
        _bookMaps = extraBookMaps;
      });
    });
    _updateSermonsForBookChapter(book, chapter);
  }

  /// Mirror of [_updateMapsForBookChapter] for the Pastor Eric sermon
  /// corpus. Listing sermons that cite *any* verse in the current
  /// chapter is a chapter-level question, so we resolve it once per
  /// chapter change rather than re-querying every time the floating
  /// header rebuilds.
  void _updateSermonsForBookChapter(String book, int chapter) {
    final key = '$book:$chapter';
    if (key == _lastSermonsBookChapter) return;
    _lastSermonsBookChapter = key;
    final en = bookNameToEnglish[book] ?? book;
    // verse=0 ensures no exact-verse priority hits — the service
    // returns every sermon citing any verse in this chapter.
    SermonService.instance
        .sermonsForVerse(englishBook: en, chapter: chapter, verse: 0)
        .then((sermons) {
      if (!mounted) return;
      if (_lastSermonsBookChapter != key) return;
      setState(() => _chapterSermons = sermons);
    });
  }

  // ── Chapter navigation ──────────────────────────────────────────────

  void _goToNextChapter() {
    final provider = context.read<MainProvider>();
    provider.clearSelectedVerses();
    provider.clearHighlightIndex();
    final books = provider.books;
    final currentBook = provider.currentBook;
    final currentChapter = provider.currentChapter;
    if (currentBook == null || currentChapter == null) return;

    final bookIdx = books.indexWhere((b) => b.title == currentBook);
    if (bookIdx < 0) return;
    final chapters = books[bookIdx].chapters;
    final chapIdx = chapters.indexWhere((c) => c.title == currentChapter);
    String nextBook;
    int nextChap;
    if (chapIdx < chapters.length - 1) {
      nextBook = currentBook;
      nextChap = chapters[chapIdx + 1].title;
    } else if (bookIdx < books.length - 1) {
      final nextBookIdx = bookIdx + 1;
      nextBook = books[nextBookIdx].title;
      nextChap = books[nextBookIdx].chapters.first.title;
    } else {
      return;
    }
    _switchTo(provider, nextBook, nextChap);
  }

  void _goToPreviousChapter() {
    final provider = context.read<MainProvider>();
    provider.clearSelectedVerses();
    provider.clearHighlightIndex();
    final books = provider.books;
    final currentBook = provider.currentBook;
    final currentChapter = provider.currentChapter;
    if (currentBook == null || currentChapter == null) return;

    final bookIdx = books.indexWhere((b) => b.title == currentBook);
    if (bookIdx < 0) return;
    final chapters = books[bookIdx].chapters;
    final chapIdx = chapters.indexWhere((c) => c.title == currentChapter);
    String prevBook;
    int prevChap;
    if (chapIdx > 0) {
      prevBook = currentBook;
      prevChap = chapters[chapIdx - 1].title;
    } else if (bookIdx > 0) {
      final prevBookIdx = bookIdx - 1;
      prevBook = books[prevBookIdx].title;
      prevChap = books[prevBookIdx].chapters.last.title;
    } else {
      return;
    }
    _switchTo(provider, prevBook, prevChap);
  }

  void _switchTo(MainProvider provider, String book, int chap) {
    final matched = provider.verses
        .where((v) => v.book == book && v.chapter == chap)
        .toList();
    if (matched.isEmpty) return;
    provider.setCurrentChapter(book: book, chapter: chap);
    provider.updateCurrentVerse(verse: matched.first);
    provider.jumpToTop();
    if (mounted) setState(() => _visibleItemIndex = 0);
  }

  // ── Copy / format helpers ───────────────────────────────────────────

  String _formattedSelectedVerses({required List<Verse> verses}) {
    if (verses.isEmpty) return '';
    final settings = context.read<AppSettings>();

    int bookOrder(String book) {
      final en = toEnglish(book) ?? book;
      final idx = standardBookOrder.indexOf(en);
      return idx < 0 ? standardBookOrder.length : idx;
    }

    final sorted = [...verses]..sort((a, b) {
        final bookCmp = bookOrder(a.book).compareTo(bookOrder(b.book));
        if (bookCmp != 0) return bookCmp;
        if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
        return a.verse.compareTo(b.verse);
      });

    final first = sorted.first;

    switch (settings.copyFormat) {
      case 'withRef':
        return sorted
            .map((v) =>
                '[${v.book} ${v.chapter}:${v.verseLabel}] ${sanitizeForSearch(v.text)}')
            .join('\n');
      case 'devotional':
        final versesText =
            sorted.map((v) => sanitizeForSearch(v.text)).join('\n');
        final range = _formatVerseRangeLabels(sorted);
        return '$versesText\n(${first.book} ${first.chapter}:$range)';
      case 'plain':
      default:
        final body = sorted
            .map((v) => '${v.verseLabel} ${sanitizeForSearch(v.text)}')
            .join('\n');
        return '${first.book} ${first.chapter}\n$body';
    }
  }

  static String _formatVerseRange(List<int> nums) {
    if (nums.isEmpty) return '';
    final sorted = [...nums]..sort();
    final parts = <String>[];
    int start = sorted[0];
    int end = start;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        parts.add(start == end ? '$start' : '$start–$end');
        start = sorted[i];
        end = start;
      }
    }
    parts.add(start == end ? '$start' : '$start–$end');
    return parts.join(', ');
  }

  static String _formatVerseRangeLabels(List<Verse> verses) {
    if (verses.isEmpty) return '';
    if (verses.any((v) => v.verseLabel != '${v.verse}')) {
      return verses.map((v) => v.verseLabel).join(', ');
    }
    return _formatVerseRange(verses.map((v) => v.verse).toList());
  }

  /// Empty-reader scaffold — shown when verses come back empty
  /// (failed version switch, network blip, race) so the user always
  /// has a visible Reload button instead of being stuck on a blank
  /// list. The popup-menu Reload entry is also available, but
  /// surfacing the button right where the eye lands is friendlier.
  Widget _emptyReaderScaffold(BuildContext context, AppSettings settings) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 56, color: scheme.primary.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  uiStrings['noVersesAvailable']?[locale] ??
                      'No verses available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: settings.fontSize * 1.1,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  uiStrings['loadErrorBody']?[locale] ??
                      'Could not load Bible verses. Please check your connection and retry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: settings.fontSize * 0.95,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _reloadVerses,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    uiStrings['reload']?[locale] ?? 'Reload',
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: settings.fontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// User-initiated reload. Re-fetches the current Bible version's
  /// verses + books and resets the reader to the current chapter (or
  /// the first chapter when the reader was empty). Used by the
  /// "Reload" menu item AND by the empty-state widget shown when the
  /// reader has no verses for the current selection.
  ///
  /// Pre-fix the only recovery from a failed FetchVerses was quit-
  /// and-relaunch.
  Future<void> _reloadVerses() async {
    if (!mounted) return;
    final p = context.read<MainProvider>();
    final settings = context.read<AppSettings>();
    final messenger = _messengerKey.currentState;
    final reloadingMsg =
        uiStrings['reloading']?[settings.locale] ?? 'Reloading…';
    messenger?.showSnackBar(SnackBar(
      content: Text(reloadingMsg),
      duration: const Duration(seconds: 2),
    ));
    try {
      await FetchVerses.execute(mainProvider: p);
      if (!mounted) return;
      await FetchBooks.execute(mainProvider: p);
      if (!mounted) return;
      if (p.verses.isEmpty) {
        messenger?.showSnackBar(SnackBar(
          content: Text(uiStrings['loadErrorBody']?[settings.locale] ??
              'Could not load verses. Please retry.'),
          duration: const Duration(seconds: 3),
        ));
        return;
      }
      // Settle the cursor on a verse that actually exists. Prefer the
      // current selection; fall through to the bundle's first verse
      // when the previous book/chapter no longer matches anything.
      final keepBook = p.currentBook;
      final keepChapter = p.currentChapter;
      final match = p.verses.firstWhere(
        (v) => v.book == keepBook && v.chapter == keepChapter,
        orElse: () => p.verses.first,
      );
      p.setCurrentChapter(book: match.book, chapter: match.chapter);
      p.updateCurrentVerse(verse: match);
      p.setLoadError(null);
      messenger?.showSnackBar(SnackBar(
        content: Text(uiStrings['reloaded']?[settings.locale] ?? 'Reloaded'),
        duration: const Duration(milliseconds: 1500),
      ));
    } catch (e) {
      if (!mounted) return;
      final base = uiStrings['loadErrorBody']?[settings.locale] ??
          'Could not load verses.';
      final detail = e.toString();
      final detailShort =
          detail.substring(0, detail.length.clamp(0, 100));
      messenger?.showSnackBar(SnackBar(
        content: Text('$base $detailShort'),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  /// Build a deep-link URL for the first selected verse + the
  /// formatted verse text, copy to clipboard, fire a floating
  /// toast confirming "Share link copied". Used by the new Share
  /// icon in the selection action bar.
  Future<void> _shareSelectedVerses({
    required BuildContext context,
    required MainProvider mainProvider,
    required AppSettings settings,
  }) async {
    final verses = mainProvider.selectedVerses;
    if (verses.isEmpty) return;
    final v = verses.first;
    final ref = '${v.book}:${v.chapter}:${v.verse}';
    final url =
        'https://yswords.netlify.app/?verse=${Uri.encodeComponent(ref)}';
    final text =
        _formattedSelectedVerses(verses: mainProvider.selectedVerses);
    final payload = '$text\n\n$url';
    bool ok = true;
    try {
      await ClipboardHelper.copyText(payload);
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    showFloatingToast(
      context,
      message: ok
          ? (uiStrings['shareLinkCopied']?[settings.locale] ??
              'Share link copied')
          : (uiStrings['shareLinkFailed']?[settings.locale] ??
              'Copy failed — clipboard unavailable'),
      icon: ok
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      background: ok ? scheme.primary : scheme.error,
    );
  }

  Future<void> _copySelectedVerses({
    required MainProvider mainProvider,
    required AppSettings settings,
  }) async {
    // The "Copy" button does exactly what the label says: copy to
    // clipboard, immediately. The previous implementation popped the
    // OS share sheet first ("Try the platform share sheet first…")
    // and only fell back to clipboard if the user cancelled, which
    // confused users who got an unexpected share menu and then had
    // to dismiss it before the text appeared on the clipboard.
    //
    // Sharing-to-app is still available via the system's native
    // text-selection menu (long-press the copied text in any app).
    final text =
        _formattedSelectedVerses(verses: mainProvider.selectedVerses);
    await ClipboardHelper.copyText(text);
    mainProvider.clearSelectedVerses();
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final copiedLabel =
        uiStrings['copied']?[settings.locale] ?? 'Copied!';
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              copiedLabel,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: scheme.primary.withValues(alpha: 0.8),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  // ── Paragraph grouping ──────────────────────────────────────────────

  static List<List<Verse>> _groupIntoParagraphs(List<Verse> verses) {
    if (verses.isEmpty) return [];
    final groups = <List<Verse>>[];
    List<Verse> currentGroup = [];

    for (final verse in verses) {
      final startsNew =
          verse.isParagraphStart || verse.paragraphType == 'reference';
      if (startsNew && currentGroup.isNotEmpty) {
        groups.add(currentGroup);
        currentGroup = [];
      }
      currentGroup.add(verse);
    }
    if (currentGroup.isNotEmpty) groups.add(currentGroup);
    return groups;
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        _attachPositionsListener(mainProvider);

        // Show loading spinner when verses haven't been loaded yet
        if (mainProvider.verses.isEmpty && mainProvider.books.isEmpty) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // The reader has no verses at all → show an empty state with
        // a Reload button so the user has a one-tap recovery path
        // instead of having to relaunch the app. Pre-fix this
        // rendered an empty list silently.
        if (mainProvider.verses.isEmpty) {
          return _emptyReaderScaffold(context, settings);
        }

        final verses = mainProvider.verses
            .where((v) =>
                v.book == mainProvider.currentBook &&
                v.chapter == mainProvider.currentChapter)
            .toList()
          ..sort((a, b) => a.verse.compareTo(b.verse));
        final hasParagraphData =
            verses.any((v) => v.isParagraphStart == true);

        List<List<Verse>> paragraphGroups;
        if (settings.paragraphMode) {
          paragraphGroups = _groupIntoParagraphs(verses);
        } else {
          paragraphGroups = verses.map((v) => [v]).toList();
        }

        final verseToItemMap = <int, int>{};
        final itemToVerseIndex = <int, int>{0: 0};
        int vIdx = 0;
        for (int g = 0; g < paragraphGroups.length; g++) {
          itemToVerseIndex[g + 1] = vIdx;
          for (int v = 0; v < paragraphGroups[g].length; v++) {
            verseToItemMap[vIdx] = g + 1;
            vIdx++;
          }
        }
        mainProvider.setVerseToItemMap(verseToItemMap);

        // Drain a pending cross-page jump (e.g. from a Daily News
        // verse-reference tap or a Bible Evidence "scripture
        // correlation" tap). The map we just built is the missing
        // ingredient those pages couldn't wait for, so this is the
        // first frame where we can actually scroll + highlight
        // accurately. Schedule it AFTER this build completes so the
        // ScrollablePositionedList has had a chance to attach its
        // controller; without the post-frame deferral we'd hit
        // `isAttached == false` and silently no-op.
        if (mainProvider.hasPendingJump && verses.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // Round 56 fix for "first note tap goes to top, second
            // works": when Library was reached from the reader's
            // overflow menu, two HomePage instances coexist (the
            // OLD reader still in the navigator stack, plus the
            // NEW reader pushed via Get.off). The OLD reader's
            // BibleReadingPane Consumer also fires this build path
            // and races to consume `pendingJump` first — its
            // ScrollablePositionedList controller is already
            // attached, so its `tryJump` succeeds and scrolls a
            // hidden widget. The NEW (visible) reader then sees
            // pendingJump=null and lands at the top of the chapter.
            //
            // Defense: only the *current* (topmost) route consumes
            // the jump. Any non-topmost reader silently leaves
            // the flag untouched so the visible reader can take
            // it on the next post-frame tick.
            final route = ModalRoute.of(context);
            if (route != null && !route.isCurrent) return;

            final mp = context.read<MainProvider>();
            final pendingIdx = mp.consumePendingJump();
            if (pendingIdx == null) return;
            // Defensive clamp: a stale pending jump from a
            // different chapter could land out-of-range.
            if (pendingIdx < 0 || pendingIdx >= verses.length) return;
            // Wait for the controller to attach AND for the SPL
            // to have finished its first layout pass. On a fresh
            // HomePage mount the controller can be `isAttached`
            // before the items are measured, so a `jumpTo` would
            // silently land at index 0. Use `scrollTo` (not
            // `jumpTo`) with a 1 ms duration — SPL handles the
            // not-fully-laid-out case more gracefully than
            // `jumpTo`. Plus widen the poll budget to 3 s
            // (60 × 50 ms) for slow-cold-start cases.
            void tryJump([int attempt = 0]) {
              if (!mounted) return;
              if (mp.itemScrollController.isAttached) {
                try {
                  mp.scrollToIndexAnimated(index: pendingIdx);
                } catch (_) {
                  // If scrollTo can't run yet (very rare — e.g.
                  // controller detached between the isAttached
                  // check and this call), fall through to retry.
                  if (attempt < 60) {
                    Future.delayed(const Duration(milliseconds: 50),
                        () => tryJump(attempt + 1));
                  }
                  return;
                }
                mp.setHighlightIndex(pendingIdx);
                Future.delayed(const Duration(milliseconds: 1200),
                    () => mp.clearHighlightIndex());
                return;
              }
              if (attempt > 60) return;
              Future.delayed(const Duration(milliseconds: 50),
                  () => tryJump(attempt + 1));
            }
            tryJump();
          });
        }

        final currentVerse = mainProvider.currentVerse ??
            (verses.isNotEmpty ? verses.first : null);
        if (currentVerse != null) {
          _updateMapsForBookChapter(currentVerse.book, currentVerse.chapter);
        }
        final isSelected = mainProvider.selectedVerses.isNotEmpty;
        // Items: [chapter header(0), ...paragraphGroups, trailing spacer].
        // So valid item indices are 0 .. paragraphGroups.length + 1.
        final visibleItemIndex = _visibleItemIndex
            .clamp(0, paragraphGroups.length + 1)
            .toInt();
        final rawVisibleVerseIndex =
            itemToVerseIndex[visibleItemIndex] ??
                (visibleItemIndex > paragraphGroups.length
                    ? verses.length - 1
                    : 0);
        final visibleVerseIndex = verses.isEmpty
            ? 0
            : rawVisibleVerseIndex.clamp(0, verses.length - 1).toInt();
        final chapterProgress = verses.isEmpty
            ? 0.0
            : ((visibleVerseIndex + 1) / verses.length)
                .clamp(0.0, 1.0)
                .toDouble();

        return SelectionContainer.disabled(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -300) {
                _goToNextChapter();
              } else if (velocity > 300) {
                _goToPreviousChapter();
              }
            },
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                systemNavigationBarColor:
                    Theme.of(context).colorScheme.surface,
                systemNavigationBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
              ),
              child: ScaffoldMessenger(
                key: _messengerKey,
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    // Web keyboard shortcuts (Round 27E). These are
                    // discoverable but unobtrusive — they're standard
                    // app idioms (`/` for search, `[`/`]` for prev/next
                    // chapter, `?` for help). Disabled while a text
                    // field is focused so they don't fight typing.
                    const SingleActivator(LogicalKeyboardKey.bracketLeft):
                        _goToPreviousChapter,
                    const SingleActivator(LogicalKeyboardKey.bracketRight):
                        _goToNextChapter,
                    const SingleActivator(LogicalKeyboardKey.slash): () {
                      if (widget.showSearchAndSettings) {
                        Get.to(() => SearchPage(),
                            transition: Transition.rightToLeft);
                      }
                    },
                    const SingleActivator(LogicalKeyboardKey.keyT,
                        shift: true): () {
                      if (TtsService.isAvailable) _toggleListenChapter();
                    },
                    const SingleActivator(LogicalKeyboardKey.question,
                        shift: true): () =>
                        _showShortcutsHelp(context, settings.locale),
                  },
                  child: Focus(
                    autofocus: true,
                    child: Scaffold(
                // Round 56 fix: when the user opens the note editor
                // (modal bottom sheet) and the keyboard appears, the
                // default `resizeToAvoidBottomInset: true` shrinks
                // the Scaffold body. The LayoutBuilder rebuilds with
                // a smaller height, the Stack/Padding/SPL chain
                // re-lays out, and on certain devices the SPL ends
                // up snapping back to its `initialScrollIndex`
                // (which can be 0 in cold-mount cases) — user
                // reports "after click notes and click and typing,
                // that moment it goes to top". Setting this false
                // means the keyboard appears OVER the reader; the
                // bottom sheet handles its own keyboard-avoidance
                // via `MediaQuery.viewInsets.bottom` in
                // `_showNoteEditor`'s padding, so the editor still
                // sits above the keyboard. The reader stays put.
                resizeToAvoidBottomInset: false,
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final paneWidth = constraints.maxWidth;
                    final dc = ResponsiveBreakpoints.classOf(paneWidth);
                    final isWideScreen = ResponsiveBreakpoints.isTabletOrWider(paneWidth);

                    return Stack(
                      children: [
                    Padding(
                      padding: EdgeInsets.only(
                        right: ResponsiveBreakpoints.readingPadding(dc),
                      ),
                      child: ScrollablePositionedList.builder(
                        itemCount: paragraphGroups.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final topInset =
                                MediaQuery.of(context).padding.top;
                            return SizedBox(
                                height:
                                    topInset + 64 * settings.menuScale + 12);
                          }
                          final groupIdx = index - 1;
                          if (groupIdx < paragraphGroups.length) {
                            final group = paragraphGroups[groupIdx];
                            int startIdx = 0;
                            for (int g = 0; g < groupIdx; g++) {
                              startIdx += paragraphGroups[g].length;
                            }
                            final isFirst = groupIdx == 0;
                            // Look up a section / paragraph heading
                            // for the FIRST verse in this group.
                            // Heading carries optional `context` —
                            // 1-2 sentences of background rendered
                            // under the title. Both gate on
                            // settings.showSectionTitles.
                            SectionHeading? heading;
                            if (settings.showSectionTitles) {
                              final firstVerse = group.first;
                              final englishBook = toEnglish(firstVerse.book) ??
                                  firstVerse.book;
                              heading = SectionTitleService.headingAt(
                                version: mainProvider.currentVersion,
                                englishBook: englishBook,
                                chapter: firstVerse.chapter,
                                verse: firstVerse.verse,
                              );
                            }
                            final body = group.length == 1
                                ? VerseWidget(
                                    verse: group.first,
                                    index: startIdx,
                                    hasParagraphData: hasParagraphData,
                                    isFirst: isFirst,
                                  )
                                : ParagraphGroupWidget(
                                    group: group,
                                    startVerseIndex: startIdx,
                                    isFirst: isFirst,
                                  );
                            // If this is the first paragraph of the
                            // chapter AND we're at chapter 1 of the
                            // book AND a book intro is authored AND
                            // the user hasn't disabled it — wrap the
                            // body so the intro card renders above
                            // the (possibly headed) verse block.
                            Widget rendered = heading == null
                                ? body
                                : _SectionHeading(
                                    title: heading.title,
                                    context: heading.context,
                                    isFirst: isFirst,
                                    child: body,
                                  );
                            final firstVerse = group.first;
                            final englishBook =
                                toEnglish(firstVerse.book) ?? firstVerse.book;
                            if (isFirst &&
                                firstVerse.chapter == 1 &&
                                settings.showBookIntro) {
                              final intro =
                                  BookIntroService.forBook(englishBook);
                              if (intro != null) {
                                rendered = Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _BookIntroCard(
                                      intro: intro,
                                      locale: settings.locale,
                                    ),
                                    rendered,
                                  ],
                                );
                              }
                            }
                            return rendered;
                          }
                          // Trailing spacer height matches whichever
                          // bottom bar is showing (selection action bar
                          // when verses are selected, otherwise the
                          // reader status bar). On narrow screens the
                          // selection bar is now two rows tall (count+
                          // copy on top, action icons below), so we
                          // pad more aggressively when selected to
                          // keep the last verse from being hidden
                          // under it.
                          final bottomInset =
                              MediaQuery.of(context).padding.bottom;
                          final isPhoneWidth =
                              MediaQuery.of(context).size.width < 560;
                          final extra = isSelected
                              ? (isPhoneWidth
                                  ? 200 * settings.menuScale
                                  : 132 * settings.menuScale)
                              : 96 * settings.menuScale;
                          return SizedBox(height: bottomInset + extra);
                        },
                        itemScrollController:
                            mainProvider.itemScrollController,
                        itemPositionsListener:
                            mainProvider.itemPositionsListener,
                        scrollOffsetController:
                            mainProvider.scrollOffsetController,
                        scrollOffsetListener:
                            mainProvider.scrollOffsetListener,
                        // Preserve scroll position across layout
                        // changes (e.g. opening or closing split
                        // view). The SPL widget gets recreated when
                        // its parent's layout structure changes —
                        // single-pane → side-by-side / top-bottom —
                        // and it consults `initialScrollIndex` once
                        // on each mount. We've been tracking
                        // `_visibleItemIndex` from
                        // [_attachPositionsListener] all along, so
                        // feeding it back here makes the new SPL
                        // restore the user's previous reading
                        // position instead of slamming back to top
                        // (the user-reported "open split window, why
                        // the top window goes back to top" bug).
                        initialScrollIndex: _visibleItemIndex,
                      ),
                    ),
                    _FloatingHeader(
                      showBookInfo: currentVerse != null,
                      book: currentVerse?.book ?? '',
                      chapter: currentVerse?.chapter ?? 0,
                      version: mainProvider.currentVersion,
                      showSidebarToggle: widget.showSidebarToggle,
                      sidebarOpen: widget.sidebarOpen,
                      onToggleSidebar: widget.onToggleSidebar,
                      paragraphMode: settings.paragraphMode,
                      onToggleParagraphMode: () =>
                          settings.setParagraphMode(!settings.paragraphMode),
                      deviceClass: dc,
                      onToggleSplitView: widget.onToggleSplitView,
                      splitViewActive: widget.splitViewActive,
                      onClose: widget.onClose,
                      showSearchAndSettings: widget.showSearchAndSettings,
                      chapterMaps: _chapterMaps,
                      bookMaps: _bookMaps,
                      chapterSermons: _chapterSermons,
                      locale: settings.locale,
                      onBookTap: isWideScreen && widget.showSidebarToggle
                          ? () {
                              mainProvider.clearSelectedVerses();
                              widget.onToggleSidebar?.call();
                            }
                          : () {
                              mainProvider.clearSelectedVerses();
                              final chapter =
                                  mainProvider.currentVerse?.chapter ?? 1;
                              final book =
                                  mainProvider.currentVerse?.book ?? '';
                              final provider =
                                  context.read<MainProvider>();
                              Get.to(
                                () => BooksPage(
                                  chapterIdx: chapter,
                                  bookIdx: book,
                                  providerOverride: provider,
                                ),
                                transition: Transition.leftToRight,
                                duration:
                                    const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      onVersionSelected: (version) async {
                        if (!mounted) return;
                        final p = context.read<MainProvider>();
                        final messenger = _messengerKey.currentState;
                        p.clearSelectedVerses();
                        final prevVersion = p.currentVersion;
                        final prevEn = toEnglish(p.currentBook);
                        p.setVersion(version);
                        await FetchVerses.execute(mainProvider: p);
                        if (!mounted) return;
                        await FetchBooks.execute(mainProvider: p);
                        if (!mounted) return;
                        // If the new version failed to load, revert so
                        // the user keeps reading the previous version.
                        if (p.verses.isEmpty && prevVersion.isNotEmpty) {
                          p.setVersion(prevVersion);
                          await FetchVerses.execute(mainProvider: p);
                          await FetchBooks.execute(mainProvider: p);
                        }
                        if (p.verses.isEmpty) {
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(
                                uiStrings['loadErrorBody']?[
                                        settings.locale] ??
                                    'Could not load verses. Please retry.',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          return;
                        }
                        final targetBook = prevEn == null
                            ? null
                            : translateBookName(prevEn, version);
                        final targetChapter = p.currentChapter;
                        final match = p.verses.firstWhere(
                          (v) =>
                              (targetBook == null ||
                                  v.book == targetBook) &&
                              (targetChapter == null ||
                                  v.chapter == targetChapter),
                          orElse: () => p.verses.first,
                        );
                        p.setCurrentChapter(
                            book: match.book, chapter: match.chapter);
                        p.updateCurrentVerse(verse: match);
                        p.jumpToTop();
                        if (mounted) {
                          setState(() => _visibleItemIndex = 0);
                        }
                      },
                      onSearch: () {
                        mainProvider.clearSelectedVerses();
                        Get.to(
                          () => SearchPage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                      onSettings: () {
                        mainProvider.clearSelectedVerses();
                        Get.to(() => SettingsPage());
                      },
                      highlightCount:
                          mainProvider.highlights.length,
                      // The dedicated Highlights page (Round 34)
                      // gives a richer experience than the modal
                      // sheet — search, color filters, copy-all —
                      // so the floating-header entry now opens it.
                      // The modal HighlightsSheet remains for the
                      // long-press color-picker context only.
                      onHighlights: () => Get.to(
                        () => const HighlightsPage(),
                        transition: Transition.rightToLeft,
                      ),
                      // Reload — re-runs FetchVerses+FetchBooks on the
                      // current version. User asked for this so they
                      // don't have to relaunch the app when verses
                      // fail to load mid-session.
                      onReload: _reloadVerses,
                      // TTS read-aloud — only on web (or any platform
                      // where the SpeechSynthesis API is available).
                      // The state class also self-stops the utterance
                      // on dispose so swiping back doesn't leave the
                      // browser narrating an empty page.
                      onToggleListen: TtsService.isAvailable
                          ? _toggleListenChapter
                          : null,
                      isListening: _isListening,
                      // Hide the Today's Reading card while a verse
                      // selection is active — the selection action bar
                      // already crowds the screen and the card just
                      // adds noise. Also hide on the secondary split-
                      // view pane (no `onSearch`) so the card never
                      // appears twice on the same screen.
                      belowHeader: (!isSelected && widget.showSearchAndSettings)
                          ? TodayReadingCard(
                              onJump: (ref) => _navigateToBibleReference(
                                mainProvider: mainProvider,
                                ref: ref,
                                locale: settings.locale,
                              ),
                            )
                          : null,
                    ),
                    // Vertical position indicator on the right edge — a
                    // thin track + a small "current/total" pill that
                    // slides top-to-bottom as the user reads, then
                    // auto-fades after 2 s of inactivity.
                    if (!isSelected && verses.isNotEmpty)
                      Positioned(
                        right: ResponsiveBreakpoints.headerInset(dc) + 4,
                        top: MediaQuery.of(context).padding.top +
                            64 * settings.menuScale +
                            24,
                        bottom: MediaQuery.of(context).padding.bottom + 56,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _showVersePosition ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 400),
                            child: _VerticalProgressIndicator(
                              progress: chapterProgress,
                              currentLabel: '${visibleVerseIndex + 1}',
                              totalLabel: '${verses.length}',
                              fontFamily: settings.fontFamily,
                              menuScale: settings.menuScale,
                            ),
                          ),
                        ),
                      ),
                    // Bottom bar — selection actions or progress bar
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: isSelected
                          ? _SelectionActionBar(
                              selectedCount:
                                  mainProvider.selectedVerses.length,
                              anyHighlighted: mainProvider.selectedVerses
                                  .any((v) =>
                                      mainProvider.isVerseHighlighted(v)),
                              deviceClass: dc,
                              onCopy: () => _copySelectedVerses(
                                mainProvider: mainProvider,
                                settings: settings,
                              ),
                              onShare: () => _shareSelectedVerses(
                                context: context,
                                mainProvider: mainProvider,
                                settings: settings,
                              ),
                              onClear: mainProvider.clearSelectedVerses,
                              onHighlight: (color) {
                                mainProvider.setHighlightsForVerses(
                                  verses: mainProvider.selectedVerses,
                                  color: color,
                                );
                                mainProvider.clearSelectedVerses();
                              },
                              onRemoveHighlight: () {
                                mainProvider.removeHighlightsForVerses(
                                  verses: mainProvider.selectedVerses,
                                );
                                mainProvider.clearSelectedVerses();
                              },
                              onOriginal: () => _showOriginalsSheet(
                                context: context,
                                verses: mainProvider.selectedVerses,
                                locale: settings.locale,
                              ),
                              onCrossRefs: () => _showCrossRefsSheet(
                                context: context,
                                verses: mainProvider.selectedVerses,
                                locale: settings.locale,
                                mainProvider: mainProvider,
                              ),
                              onSermons: () => _showRelatedSermonsSheet(
                                context: context,
                                verses: mainProvider.selectedVerses,
                                locale: settings.locale,
                                currentVersion: mainProvider.currentVersion,
                              ),
                              anyNoted: mainProvider.selectedVerses
                                  .any(mainProvider.isVerseNoted),
                              anyBookmarked: mainProvider.selectedVerses
                                  .any(mainProvider.isBookmarked),
                              onNote: () => _showNoteEditor(
                                context: context,
                                verse: mainProvider.selectedVerses.first,
                                locale: settings.locale,
                                mainProvider: mainProvider,
                              ),
                              onBookmark: () {
                                final selected =
                                    mainProvider.selectedVerses.toList();
                                final allBookmarked = selected.every(
                                    mainProvider.isBookmarked);
                                for (final v in selected) {
                                  if (allBookmarked) {
                                    if (mainProvider.isBookmarked(v)) {
                                      mainProvider.toggleBookmark(verse: v);
                                    }
                                  } else {
                                    if (!mainProvider.isBookmarked(v)) {
                                      mainProvider.toggleBookmark(verse: v);
                                    }
                                  }
                                }
                                mainProvider.clearSelectedVerses();
                              },
                            )
                          : _ReaderStatusBar(
                              progress: chapterProgress,
                              deviceClass: dc,
                            ),
                    ),
                  ],
                );
                  },
                ),
              ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────

/// Thin vertical "scroll bookmark" on the right edge of the reader.
/// A small pill (e.g. `12 / 50`) slides top-to-bottom in lockstep with
/// the chapter progress. The whole widget is wrapped in an
/// [AnimatedOpacity] by the caller so it auto-fades after 2 s of
/// inactivity, matching the previous pill behavior.
class _VerticalProgressIndicator extends StatelessWidget {
  final double progress;
  final String currentLabel;
  final String totalLabel;
  final String fontFamily;
  final double menuScale;

  const _VerticalProgressIndicator({
    required this.progress,
    required this.currentLabel,
    required this.totalLabel,
    required this.fontFamily,
    required this.menuScale,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontSize = (10.0 * menuScale).clamp(9.0, 13.0).toDouble();

    return LayoutBuilder(builder: (ctx, constraints) {
      final h = constraints.maxHeight;
      final pillHeight = (22 * menuScale).clamp(20.0, 32.0).toDouble();
      // Anchor the pill so its center tracks the progress; clamp so it
      // never overflows the track.
      final clamped = progress.clamp(0.0, 1.0);
      final pillTop =
          (clamped * (h - pillHeight)).clamp(0.0, h - pillHeight).toDouble();

      return SizedBox(
        width: 56 * menuScale,
        height: h,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // Background track — full height.
            Positioned(
              right: 1,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Filled portion from the top down to the pill.
            Positioned(
              right: 1,
              top: 0,
              child: Container(
                width: 2,
                height: pillTop + pillHeight / 2,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Floating "current/total" pill.
            Positioned(
              right: 6,
              top: pillTop,
              child: Container(
                height: pillHeight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surface
                      .withValues(alpha: isDark ? 0.86 : 0.92),
                  borderRadius: BorderRadius.circular(pillHeight / 2),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.45),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.32 : 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: currentLabel,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' / $totalLabel',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ReaderStatusBar extends StatelessWidget {
  final double progress;
  final DeviceClass deviceClass;

  const _ReaderStatusBar({
    required this.progress,
    required this.deviceClass,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: (2.5 * settings.menuScale).clamp(2.0, 4.0),
          backgroundColor:
              scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          color: scheme.primary.withValues(alpha: 0.7),
        ),
        SizedBox(height: bottomInset),
      ],
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;

  const _GlassSurface({
    required this.child,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: scheme.outlineVariant
                  .withValues(alpha: isDark ? 0.35 : 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final bool anyHighlighted;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onClear;
  final ValueChanged<int> onHighlight;
  final VoidCallback onRemoveHighlight;
  final VoidCallback onOriginal;
  final VoidCallback onCrossRefs;
  final VoidCallback onSermons;
  final VoidCallback onNote;
  final VoidCallback onBookmark;
  /// True when at least one of the currently-selected verses is
  /// already bookmarked — so the star icon can render filled.
  final bool anyBookmarked;
  /// True when at least one of the currently-selected verses already
  /// has a note attached — so the note icon can render filled.
  final bool anyNoted;
  final DeviceClass deviceClass;

  const _SelectionActionBar({
    required this.selectedCount,
    required this.anyHighlighted,
    required this.onCopy,
    required this.onShare,
    required this.onClear,
    required this.onHighlight,
    required this.onRemoveHighlight,
    required this.onOriginal,
    required this.onCrossRefs,
    required this.onSermons,
    required this.onNote,
    required this.onBookmark,
    required this.anyBookmarked,
    required this.anyNoted,
    required this.deviceClass,
  });

  static const _highlightColors = <int>[
    0xFFFFF176,
    0xFFA5D6A7,
    0xFF90CAF9,
    0xFFF48FB1,
    0xFFFFCC80,
    0xFFCE93D8,
  ];

  void _showColorPicker(BuildContext context) {
    final settings = context.read<AppSettings>();
    final locale = settings.locale;
    final ms = settings.menuScale;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16 * ms),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiStrings['highlightColor']?[locale] ?? 'Highlight color',
                style: TextStyle(
                    fontSize: 16 * ms, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16 * ms),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _highlightColors.map((argb) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onHighlight(argb);
                    },
                    child: Container(
                      width: 44 * ms,
                      height: 44 * ms,
                      margin: EdgeInsets.symmetric(horizontal: 6 * ms),
                      decoration: BoxDecoration(
                        color: Color(argb),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (anyHighlighted) ...[
                SizedBox(height: 12 * ms),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRemoveHighlight();
                  },
                  icon: Icon(Icons.highlight_remove, size: 20 * ms),
                  label: Text(
                    uiStrings['removeHighlight']?[locale] ??
                        'Remove highlight',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final label =
        (uiStrings['selectedVerses']?[settings.locale] ?? '{count} selected')
            .replaceAll('{count}', '$selectedCount');
    final fontSize =
        (settings.fontSize.clamp(11.0, 18.0) * settings.menuScale)
            .toDouble();
    final inset = ResponsiveBreakpoints.headerInset(deviceClass);

    // Pre-build the secondary action icons. Each is a small
    // IconButton with the same compact density. Order: Original →
    // Cross-refs → Note → Bookmark → Highlight.
    final actionButtons = <Widget>[
      IconButton(
        tooltip:
            uiStrings['originalText']?[settings.locale] ?? 'Original',
        onPressed: onOriginal,
        icon: const Icon(Icons.auto_stories),
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        tooltip: uiStrings['crossRefs']?[settings.locale] ??
            'Cross-references',
        onPressed: onCrossRefs,
        icon: const Icon(Icons.hub_outlined),
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        tooltip: uiStrings['relatedSermons']?[settings.locale] ??
            'Related sermons',
        onPressed: onSermons,
        icon: const Icon(Icons.menu_book_outlined),
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        tooltip: uiStrings['noteAdd']?[settings.locale] ?? 'Note',
        onPressed: onNote,
        icon: Icon(anyNoted
            ? Icons.sticky_note_2
            : Icons.sticky_note_2_outlined),
        color: anyNoted ? scheme.primary : null,
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        tooltip: uiStrings['bookmark']?[settings.locale] ?? 'Bookmark',
        onPressed: onBookmark,
        icon: Icon(anyBookmarked
            ? Icons.bookmark_rounded
            : Icons.bookmark_outline_rounded),
        color: anyBookmarked ? scheme.primary : null,
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        tooltip:
            uiStrings['highlight']?[settings.locale] ?? 'Highlight',
        onPressed: () => _showColorPicker(context),
        icon: const Icon(Icons.format_color_fill),
        visualDensity: VisualDensity.compact,
      ),
    ];

    final clearBtn = IconButton(
      tooltip: uiStrings['clearSelection']?[settings.locale] ?? 'Clear',
      onPressed: onClear,
      icon: const Icon(Icons.close_rounded),
    );
    final countLabel = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: settings.fontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    );
    final copyBtn = FilledButton.icon(
      onPressed: onCopy,
      icon: const Icon(Icons.copy_rounded),
      label: Text(
        uiStrings['copySelection']?[settings.locale] ?? 'Copy',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final shareBtn = IconButton(
      onPressed: onShare,
      tooltip: uiStrings['shareLink']?[settings.locale] ?? 'Share',
      icon: const Icon(Icons.ios_share_rounded),
      color: scheme.primary,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
        child: _GlassSurface(
          radius: 22,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12 * settings.menuScale,
                6 * settings.menuScale, 12 * settings.menuScale, 6 * settings.menuScale),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                // On narrow screens (phones, ~360–600 dp wide) split
                // the bar into two rows so nothing collides:
                //   [Clear] [count] [Copy]
                //   [Original Cross-ref Note Bookmark Highlight]
                // On wider screens keep everything on one row.
                final isNarrow = constraints.maxWidth < 560;
                if (isNarrow) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          clearBtn,
                          Expanded(child: countLabel),
                          shareBtn,
                          const SizedBox(width: 4),
                          Flexible(child: copyBtn),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: actionButtons,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    clearBtn,
                    Expanded(child: countLabel),
                    ...actionButtons,
                    shareBtn,
                    const SizedBox(width: 4),
                    Flexible(child: copyBtn),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the original Hebrew/Greek text for the currently selected
/// verses as a draggable bottom sheet. Tapping a word in the sheet
/// expands its Strong's lexicon entry below; tapping a concordance
/// reference closes the sheet and jumps the reader to that verse.
void _showOriginalsSheet({
  required BuildContext context,
  required List<Verse> verses,
  required String locale,
}) {
  if (verses.isEmpty) return;
  // Capture the provider synchronously — by the time the user taps a
  // concordance reference the sheet's BuildContext may be defunct, so
  // we rely on the provider reference instead.
  final mainProvider = context.read<MainProvider>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    // Material's default ~640dp cap squeezes the exegesis panel on
    // wide desktop/iPad screens. Allow up to 1100px so the panel
    // breathes on web while still feeling sheet-like on phones.
    constraints: const BoxConstraints(maxWidth: 1100),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => OriginalsSheet(
      verses: verses,
      allVerses: mainProvider.verses,
      locale: locale,
      currentVersion: mainProvider.currentVersion,
      onNavigateRef: (ref) {
        Navigator.of(sheetCtx).maybePop();
        _navigateToConcordanceRef(
          mainProvider: mainProvider,
          ref: ref,
          locale: locale,
        );
      },
    ),
  );
}

/// Shows a draggable bottom sheet listing the cross-references
/// curated for the FIRST selected verse. Each row is tappable to
/// navigate; the sheet falls back to a friendly message when the
/// dataset doesn't yet have an entry for that verse.
void _showCrossRefsSheet({
  required BuildContext context,
  required List<Verse> verses,
  required String locale,
  required MainProvider mainProvider,
}) {
  if (verses.isEmpty) return;
  final firstSorted = [...verses]..sort(
      (a, b) => a.verse.compareTo(b.verse),
    );
  final source = firstSorted.first;
  final englishBook = toEnglish(source.book) ?? source.book;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 900),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Scaffold(
        backgroundColor: Colors.transparent,
        body: _CrossRefsSheetBody(
          englishBook: englishBook,
          chapter: source.chapter,
          verse: source.verse,
          locale: locale,
          mainProvider: mainProvider,
          scrollController: scrollController,
          onNavigate: (ref) {
            Navigator.of(sheetCtx).maybePop();
            _navigateToBibleReference(
              mainProvider: mainProvider,
              ref: ref,
              locale: locale,
            );
          },
        ),
      ),
    ),
  );
  mainProvider.clearSelectedVerses();
}

/// Bottom sheet listing every Pastor Eric sermon that cites at least
/// one of the currently-selected verses. Reads the precomputed
/// reverse index from `assets/sermons/refs.json` (~66 KB) loaded by
/// [SermonService] — no per-verse async work in the build path.
///
/// Empty result is handled with a friendly message inside the sheet
/// rather than refusing to open: the user just tapped a deliberate
/// affordance, so giving them a "no sermons reference these verses"
/// confirmation is more useful than silent no-op.
/// Sister of [_showRelatedSermonsSheet] but driven by the chapter
/// header rather than verse-selection. Caller passes the already-
/// loaded list of sermons (computed in
/// [_BibleReadingPaneState._updateSermonsForBookChapter]) so the
/// sheet opens instantly — no spinner, no per-tap async fan-out.
///
/// Empty list still opens the sheet so the user gets a friendly
/// "no sermons reference this chapter" message instead of the menu
/// item just doing nothing on tap.
void _showChapterSermonsSheet({
  required BuildContext context,
  required List<Sermon> sermons,
  required String locale,
  required String book,
  required int chapter,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 800),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _PreloadedSermonsSheetBody(
        sermons: sermons,
        locale: locale,
        title: '$book $chapter',
        scrollController: scrollController,
      ),
    ),
  );
}

class _PreloadedSermonsSheetBody extends StatelessWidget {
  final List<Sermon> sermons;
  final String locale;
  final String title;
  final ScrollController scrollController;

  const _PreloadedSermonsSheetBody({
    required this.sermons,
    required this.locale,
    required this.title,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerLabel = uiStrings['relatedSermons']?[locale] ??
        'Related sermons';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headerLabel,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(title,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                scheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: sermons.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      uiStrings['noRelatedSermons']?[locale] ??
                          'No sermons reference this chapter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65)),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                  itemCount: sermons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = sermons[i];
                    return ListTile(
                      title: Text(
                        s.localizedTitle(locale),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            Text('#${s.id}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.55))),
                            if (s.displayDate != '—')
                              Text(s.displayDate,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.55))),
                            Text(localizedSermonTopic(s.topic, locale),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.primary
                                        .withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      trailing:
                          const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.of(context).maybePop();
                        Get.to(
                          () => SermonDetailPage(sermon: s),
                          transition: Transition.rightToLeft,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

void _showRelatedSermonsSheet({
  required BuildContext context,
  required List<Verse> verses,
  required String locale,
  required String currentVersion,
}) {
  if (verses.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 800),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _RelatedSermonsSheetBody(
        verses: verses,
        locale: locale,
        scrollController: scrollController,
      ),
    ),
  );
}

class _RelatedSermonsSheetBody extends StatefulWidget {
  final List<Verse> verses;
  final String locale;
  final ScrollController scrollController;

  const _RelatedSermonsSheetBody({
    required this.verses,
    required this.locale,
    required this.scrollController,
  });

  @override
  State<_RelatedSermonsSheetBody> createState() =>
      _RelatedSermonsSheetBodyState();
}

class _RelatedSermonsSheetBodyState extends State<_RelatedSermonsSheetBody> {
  Future<List<Sermon>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRelated();
  }

  Future<List<Sermon>> _loadRelated() async {
    final svc = SermonService.instance;
    final seen = <String>{};
    final out = <Sermon>[];
    for (final v in widget.verses) {
      final englishBook = toEnglish(v.book) ?? v.book;
      final hits = await svc.sermonsForVerse(
        englishBook: englishBook,
        chapter: v.chapter,
        verse: v.verse,
      );
      for (final s in hits) {
        if (seen.add(s.id)) out.add(s);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = uiStrings['relatedSermons']?[widget.locale] ??
        'Related sermons';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Sermon>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sermons = snap.data!;
              if (sermons.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      uiStrings['noRelatedSermons']?[widget.locale] ??
                          'No Pastor Eric sermons reference these verses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              scheme.onSurface.withValues(alpha: 0.65)),
                    ),
                  ),
                );
              }
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                itemCount: sermons.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = sermons[i];
                  return ListTile(
                    title: Text(
                      s.localizedTitle(widget.locale),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          Text('#${s.id}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.55))),
                          if (s.displayDate != '—')
                            Text(s.displayDate,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.55))),
                          Text(localizedSermonTopic(s.topic, widget.locale),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.primary
                                      .withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.of(context).maybePop();
                      Get.to(
                        () => SermonDetailPage(sermon: s),
                        transition: Transition.rightToLeft,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Navigate to a free-form parsed [BibleReference] from a cross-ref
/// tap. Same dance as the search-page handler: setCurrentChapter,
/// scroll to verse, briefly highlight.
void _navigateToBibleReference({
  required MainProvider mainProvider,
  required BibleReference ref,
  required String locale,
}) {
  final localBook =
      translateBookName(ref.englishBook, mainProvider.currentVersion);
  final chapterMatches = mainProvider.verses
      .where((v) => v.book == localBook && v.chapter == ref.chapter)
      .toList()
    ..sort((a, b) => a.verse.compareTo(b.verse));
  if (chapterMatches.isEmpty) return;
  final targetVerse = ref.verseStart ?? chapterMatches.first.verse;
  final hit = chapterMatches.firstWhere(
    (v) => v.verse == targetVerse,
    orElse: () => chapterMatches.first,
  );
  // pendingJump handshake — see lib/utils/jump_to_reference.dart for
  // the rationale. Replaces the previous Future.delayed(300ms).
  prepareJumpToVerse(hit, mainProvider);
}

/// Modal text-editing sheet for attaching a note to a single verse.
/// If the verse already has a note, the editor pre-fills with it
/// and shows a Delete button.
void _showNoteEditor({
  required BuildContext context,
  required Verse verse,
  required String locale,
  required MainProvider mainProvider,
}) {
  final controller = TextEditingController(
      text: mainProvider.getVerseNote(verse) ?? '');
  final ref = '${verse.book} ${verse.chapter}:${verse.verseLabel}';
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      final scheme = Theme.of(sheetCtx).colorScheme;
      final hasExisting =
          (mainProvider.getVerseNote(verse) ?? '').isNotEmpty;
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        uiStrings['noteEdit']?[locale] ?? 'Edit note',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        ref,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(sheetCtx).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 8,
              minLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: uiStrings['noteHint']?[locale] ??
                    'Type your note for this verse…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasExisting)
                  TextButton.icon(
                    onPressed: () {
                      mainProvider.clearVerseNote(verse: verse);
                      mainProvider.clearSelectedVerses();
                      Navigator.of(sheetCtx).maybePop();
                    },
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    label: Text(
                      uiStrings['noteDelete']?[locale] ?? 'Delete',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    mainProvider.setVerseNote(
                      verse: verse,
                      text: controller.text,
                    );
                    mainProvider.clearSelectedVerses();
                    Navigator.of(sheetCtx).maybePop();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(uiStrings['noteSave']?[locale] ?? 'Save'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

// Round 34 replaced this modal sheet with a dedicated
// `HighlightsPage` (see lib/pages/highlights_page.dart) reachable
// from both the floating-header overflow menu and the dashboard's
// Highlights count tile. Kept here for now in case a future flow
// (e.g. an in-reader long-press shortcut) wants the modal again;
// safe to delete entirely once that is decided.
// ignore: unused_element
void _showHighlightsSheet({
  required BuildContext context,
  required Map<String, int> highlights,
  required String locale,
}) {
  final mainProvider = context.read<MainProvider>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => HighlightsSheet(
      highlights: highlights,
      locale: locale,
      currentVersion: mainProvider.currentVersion,
      onNavigate: (englishBook, chapter, verse) {
        Navigator.of(sheetCtx).maybePop();
        final localBook =
            translateBookName(englishBook, mainProvider.currentVersion);
        final match = mainProvider.verses.where(
          (v) => v.book == localBook &&
              v.chapter == chapter &&
              v.verse == verse,
        );
        if (match.isEmpty) return;
        // pendingJump handshake — see lib/utils/jump_to_reference.dart
        prepareJumpToVerse(match.first, mainProvider);
      },
    ),
  );
}

/// Jump the reader to a `ConcordanceRef` (e.g. "John 3:16") translated
/// into the current version's book naming. Mirrors the search-page
/// pattern: setCurrentChapter → updateCurrentVerse → jumpToIndex →
/// momentary highlight. Falls back silently when the verse isn't in
/// the current version (e.g. an OT ref while reading a NT-only edition).
void _navigateToConcordanceRef({
  required MainProvider mainProvider,
  required ConcordanceRef ref,
  required String locale,
}) {
  final localBook =
      translateBookName(ref.englishBook, mainProvider.currentVersion);
  final match = mainProvider.verses.where(
    (v) => v.book == localBook &&
        v.chapter == ref.chapter &&
        v.verse == ref.verse,
  );
  if (match.isEmpty) return;
  // pendingJump handshake — see lib/utils/jump_to_reference.dart
  prepareJumpToVerse(match.first, mainProvider);
}

/// Shows the map picker as a tabbed sheet.
///
///   - "For this chapter" — exact chapter matches (highlighted; auto-
///     selected as the default tab when at least one exists).
///   - "For this book" — additional maps that mention this book.
///     Auto-selected when no chapter match exists, with a small note
///     explaining that nothing matches the exact chapter.
///   - "All maps" — the full library, always available so users can
///     browse even on chapters with zero matches (Judges, Job, etc.).
void _showMapPicker(
  BuildContext context, {
  required List<BibleMap> chapterMaps,
  required List<BibleMap> bookMaps,
  required String locale,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      return _MapPickerSheet(
        chapterMaps: chapterMaps,
        bookMaps: bookMaps,
        locale: locale,
      );
    },
  );
}

class _MapPickerSheet extends StatefulWidget {
  final List<BibleMap> chapterMaps;
  final List<BibleMap> bookMaps;
  final String locale;
  const _MapPickerSheet({
    required this.chapterMaps,
    required this.bookMaps,
    required this.locale,
  });

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<BibleMap> _allMaps = const [];
  bool _allLoading = true;

  // Tab indices that are visible in the current configuration.
  // The "Chapter" tab is hidden when there are no chapter matches —
  // so we don't waste a tab on an empty list.
  late final List<_MapTab> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs();
    // Auto-select the "book" tab when no chapter-specific match exists,
    // so the picker opens directly on the most useful list. Falls back
    // to index 0 (always valid) when the book tab isn't present. The
    // final clamp guarantees we never feed an out-of-range index to
    // TabController, even if _buildTabs() composition changes later.
    final bookIdx = _tabs.indexWhere((t) => t.kind == _MapTabKind.book);
    final initial = (widget.chapterMaps.isEmpty && bookIdx >= 0) ? bookIdx : 0;
    _tab = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initial.clamp(0, _tabs.length - 1),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final all = await MapService.loadMaps();
    if (!mounted) return;
    setState(() {
      _allMaps = all;
      _allLoading = false;
    });
  }

  List<_MapTab> _buildTabs() {
    final tabs = <_MapTab>[];
    if (widget.chapterMaps.isNotEmpty) {
      tabs.add(_MapTab(_MapTabKind.chapter,
          uiStrings['mapsForThisChapter']?[widget.locale] ??
              'For this chapter'));
    }
    if (widget.bookMaps.isNotEmpty) {
      tabs.add(_MapTab(_MapTabKind.book,
          uiStrings['mapsForThisBook']?[widget.locale] ?? 'For this book'));
    }
    tabs.add(_MapTab(
        _MapTabKind.all, uiStrings['mapsAll']?[widget.locale] ?? 'All maps'));
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaH = MediaQuery.of(context).size.height;
    final sheetHeight = mediaH * 0.7;

    return SizedBox(
      height: sheetHeight,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.collections_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uiStrings['maps']?[widget.locale] ?? 'Maps',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: uiStrings['close']?[widget.locale] ?? 'Close',
                  ),
                ],
              ),
            ),
            // Tab strip — only render when there's more than one tab.
            if (_tabs.length > 1)
              TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final t in _tabs) Tab(text: t.label)],
              ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  for (final t in _tabs) _buildTabContent(t.kind),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(_MapTabKind kind) {
    switch (kind) {
      case _MapTabKind.chapter:
        return _mapList(widget.chapterMaps);
      case _MapTabKind.book:
        return Column(
          children: [
            if (widget.chapterMaps.isEmpty)
              _FallbackNote(
                text: uiStrings['mapsNoneForChapterFallback']
                        ?[widget.locale] ??
                    'No map specifically for this chapter — here are related maps:',
              ),
            Expanded(child: _mapList(widget.bookMaps)),
          ],
        );
      case _MapTabKind.all:
        if (_allLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        // Group by canonical book and render collapsible sections
        // — pre-fix this dumped 200+ tiles in a single flat list
        // which "had too many when opened" per user feedback.
        return _AllIllustrationsByBook(
          all: _allMaps,
          locale: widget.locale,
          related: [...widget.chapterMaps, ...widget.bookMaps],
          onCloseSheet: () => Navigator.of(context).pop(),
        );
    }
  }

  Widget _mapList(List<BibleMap> maps) {
    if (maps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            uiStrings['noMapsForChapter']?[widget.locale] ??
                'No maps for this chapter',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: maps.length,
      itemBuilder: (ctx, i) => _MapTile(
        map: maps[i],
        locale: widget.locale,
        related: [
          ...widget.chapterMaps,
          ...widget.bookMaps,
        ],
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

enum _MapTabKind { chapter, book, all }

class _MapTab {
  final _MapTabKind kind;
  final String label;
  const _MapTab(this.kind, this.label);
}

class _FallbackNote extends StatelessWidget {
  final String text;
  const _FallbackNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Groups all illustrations by canonical book and renders each group
/// as a collapsible section with "{Book} ({n})" header. Supports a
/// quick search field that filters by book name OR illustration title.
class _AllIllustrationsByBook extends StatefulWidget {
  final List<BibleMap> all;
  final String locale;
  final List<BibleMap> related;
  final VoidCallback onCloseSheet;
  const _AllIllustrationsByBook({
    required this.all,
    required this.locale,
    required this.related,
    required this.onCloseSheet,
  });

  @override
  State<_AllIllustrationsByBook> createState() =>
      _AllIllustrationsByBookState();
}

class _AllIllustrationsByBookState extends State<_AllIllustrationsByBook> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Build [book → maps] map preserving canonical OT/NT order.
  /// A single illustration can map to multiple books (cross-period
  /// world maps); each book group lists it under that book's section.
  Map<String, List<BibleMap>> _groupByBook() {
    final order = standardBookOrder;
    final groups = <String, List<BibleMap>>{
      for (final b in order) b: <BibleMap>[],
    };
    for (final m in widget.all) {
      for (final book in m.books.keys) {
        if (groups.containsKey(book)) groups[book]!.add(m);
      }
    }
    return groups;
  }

  bool _bookMatches(String book, String q) {
    if (q.isEmpty) return true;
    final qLower = q.toLowerCase();
    if (book.toLowerCase().contains(qLower)) return true;
    final localized = translateBookName(book, 'zh-Hans').toLowerCase();
    if (localized.contains(qLower)) return true;
    return false;
  }

  bool _illustrationMatches(BibleMap m, String q) {
    if (q.isEmpty) return true;
    final qLower = q.toLowerCase();
    final title = (m.title[widget.locale] ?? m.title['en'] ?? '').toLowerCase();
    return title.contains(qLower);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.text.trim();
    final groups = _groupByBook();

    return Column(
      children: [
        // Search field — filters by book name OR illustration title.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: uiStrings['search']?[widget.locale] ?? 'Search',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _query.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final entry in groups.entries)
                if (entry.value.isNotEmpty &&
                    (_bookMatches(entry.key, q) ||
                        entry.value.any((m) => _illustrationMatches(m, q))))
                  _BookIllustrationGroup(
                    book: entry.key,
                    locale: widget.locale,
                    maps: q.isEmpty
                        ? entry.value
                        : entry.value
                            .where((m) =>
                                _bookMatches(entry.key, q) ||
                                _illustrationMatches(m, q))
                            .toList(),
                    related: widget.related,
                    onCloseSheet: widget.onCloseSheet,
                    initiallyExpanded: q.isNotEmpty,
                    accentColor: scheme.primary,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Single book's ExpansionTile in the All-illustrations list.
/// Header shows "{LocalizedBook} ({count})" with the count tinted
/// in the primary color; body is the per-illustration list.
class _BookIllustrationGroup extends StatelessWidget {
  final String book;
  final String locale;
  final List<BibleMap> maps;
  final List<BibleMap> related;
  final VoidCallback onCloseSheet;
  final bool initiallyExpanded;
  final Color accentColor;
  const _BookIllustrationGroup({
    required this.book,
    required this.locale,
    required this.maps,
    required this.related,
    required this.onCloseSheet,
    required this.initiallyExpanded,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localizedBook = translateBookName(book, locale);
    final headerTpl = uiStrings['illustrationsBookCount']?[locale] ??
        '{book} ({n})';
    final headerText = headerTpl
        .replaceAll('{book}', localizedBook)
        .replaceAll('{n}', maps.length.toString());
    return Theme(
      // Strip the default ExpansionTile divider; we have our own.
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          headerText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        children: [
          for (final m in maps)
            _MapTile(
              map: m,
              locale: locale,
              related: related,
              onClose: onCloseSheet,
            ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  final BibleMap map;
  final String locale;
  final List<BibleMap> related;
  final VoidCallback onClose;
  const _MapTile({
    required this.map,
    required this.locale,
    required this.related,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 44,
          height: 44,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Image.asset(
            'assets/maps/${map.file}',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.collections, size: 22, color: scheme.primary),
          ),
        ),
      ),
      title: Text(
        map.localizedTitle(locale),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: map.localizedDescription(locale).isNotEmpty
          ? Text(
              map.localizedDescription(locale),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            )
          : null,
      trailing:
          Icon(Icons.chevron_right_rounded, size: 20, color: scheme.outline),
      onTap: () {
        onClose();
        Get.to(() => MapViewerPage(
              map: map,
              locale: locale,
              relatedMaps: related,
            ));
      },
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  final bool showBookInfo;
  final String book;
  final int chapter;
  final String version;
  final VoidCallback onBookTap;
  final ValueChanged<String> onVersionSelected;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final bool showSidebarToggle;
  final bool sidebarOpen;
  final VoidCallback? onToggleSidebar;
  final bool paragraphMode;
  final VoidCallback? onToggleParagraphMode;
  final DeviceClass deviceClass;
  final VoidCallback? onToggleSplitView;
  final bool splitViewActive;
  final VoidCallback? onClose;
  final bool showSearchAndSettings;
  final List<BibleMap> chapterMaps;
  final List<BibleMap> bookMaps;
  /// Pastor Eric sermons whose body or passage hint cites any verse
  /// in the current (book, chapter). Drives the "Related sermons"
  /// menu item — count badge + tap-to-open sheet.
  final List<Sermon> chapterSermons;
  final String locale;
  final int highlightCount;
  final VoidCallback? onHighlights;
  /// One-tap reload triggered from the overflow menu. Re-runs
  /// FetchVerses + FetchBooks on the current Bible version. Null
  /// hides the menu item.
  final VoidCallback? onReload;
  /// Toggles read-aloud (web TTS) for the current chapter. Null hides
  /// the menu item — set to null on platforms / browsers without
  /// SpeechSynthesis support.
  final VoidCallback? onToggleListen;
  /// True when a TTS utterance is currently in progress, so the menu
  /// can show "Stop reading" instead of "Listen to chapter".
  final bool isListening;
  /// Optional widget rendered immediately below the glass header
  /// (still inside the same SafeArea + Positioned region). Used for
  /// the "Today's Reading" card when a reading plan is active.
  final Widget? belowHeader;

  const _FloatingHeader({
    required this.showBookInfo,
    required this.book,
    required this.chapter,
    required this.version,
    required this.onBookTap,
    required this.onVersionSelected,
    required this.onSearch,
    required this.onSettings,
    this.showSidebarToggle = false,
    this.sidebarOpen = false,
    this.onToggleSidebar,
    this.paragraphMode = false,
    this.onToggleParagraphMode,
    required this.deviceClass,
    this.onToggleSplitView,
    this.splitViewActive = false,
    this.onClose,
    this.showSearchAndSettings = true,
    this.chapterMaps = const [],
    this.bookMaps = const [],
    this.chapterSermons = const [],
    this.locale = 'en',
    this.highlightCount = 0,
    this.onHighlights,
    this.onReload,
    this.onToggleListen,
    this.isListening = false,
    this.belowHeader,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final fontSize =
        (settings.fontSize.clamp(12.0, 19.0) * settings.menuScale).toDouble();
    final iconSize =
        (settings.fontSize.clamp(16.0, 28.0) * settings.menuScale)
            .toDouble();
    final iconPad = (iconSize * 0.45).clamp(6.0, 10.0);
    final inset = ResponsiveBreakpoints.headerInset(deviceClass);

    return Positioned(
      top: 0,
      left: inset,
      right: inset,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlassSurface(
              radius: 22,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 6 * settings.menuScale,
                    vertical: 4 * settings.menuScale),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Back arrow as the leftmost element when
                          // the reader is pushed (has a parent on
                          // the navigator stack). Pops one level —
                          // matches the back-arrow-on-leading
                          // pattern across all AppBar-based pages.
                          // Hidden in split view's secondary pane
                          // (where `onClose` already sits in this
                          // slot) so we don't get two close-style
                          // buttons stacking up.
                          if (onClose == null &&
                              Navigator.of(context).canPop())
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                              icon: Icon(Icons.arrow_back_rounded,
                                  size: iconSize),
                              padding: EdgeInsets.all(iconPad),
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              tooltip:
                                  uiStrings['back']?[locale] ?? 'Back',
                            ),
                          if (onClose != null)
                            IconButton(
                              onPressed: onClose,
                          icon: Icon(Icons.close_rounded, size: iconSize),
                          padding: EdgeInsets.all(iconPad),
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          tooltip: 'Close',
                        ),
                      if (showSidebarToggle)
                        IconButton(
                          onPressed: onToggleSidebar,
                          icon: Icon(
                            sidebarOpen
                                ? Icons.chevron_left_rounded
                                : Icons.menu_book_rounded,
                            size: iconSize,
                          ),
                          padding: EdgeInsets.all(iconPad),
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          tooltip: sidebarOpen
                              ? (uiStrings['close']?[settings.locale] ??
                                  'Close')
                              : (uiStrings['bibleBooks']?[settings.locale] ??
                                  'Bible Books'),
                        ),
                      if (showBookInfo) ...[
                        Flexible(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onBookTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Text(
                                '$book $chapter',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: settings.fontFamily,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          position: PopupMenuPosition.under,
                          tooltip: uiStrings['changeVersion']
                                  ?[settings.locale] ??
                              'Change Version',
                          itemBuilder: (context) => availableVersions
                              .map((v) => PopupMenuItem(
                                    value: v.value,
                                    // Constrain + ellipsize so localized
                                    // long labels (e.g.
                                    // "原文释经圣经第二版 (繁)") never push
                                    // the popup past the screen edge.
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxWidth: 280),
                                      child: Text(
                                        v.menuLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onSelected: onVersionSelected,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              shortBibleVersionLabel(version),
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontSize: fontSize * 0.85,
                                fontWeight: FontWeight.w600,
                                color:
                                    scheme.primary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Right-side actions: Material 3 best practice — keep
                // the most-used action (Search) visible and consolidate
                // everything else into a single overflow menu so the
                // book/chapter label on the left has room to render
                // (avoids "马可..." truncation in narrow layouts and
                // split view).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showSearchAndSettings)
                      IconButton(
                        onPressed: onSearch,
                        icon: Icon(Icons.search_rounded, size: iconSize),
                        padding: EdgeInsets.all(iconPad),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        tooltip: uiStrings['search']?[locale] ?? 'Search',
                      ),
                    // Home action — jump back to the Dashboard root.
                    // Sits in the right-side action group, mirroring
                    // the actions-area HomeIconButton on every
                    // AppBar page. Self-hides when there's no
                    // parent route (rare; defends against deep-link
                    // edge cases).
                    if (Navigator.of(context).canPop() && onClose == null)
                      IconButton(
                        onPressed: () => Navigator.of(context)
                            .popUntil((r) => r.isFirst),
                        icon:
                            Icon(Icons.home_rounded, size: iconSize),
                        padding: EdgeInsets.all(iconPad),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        tooltip: uiStrings['home']?[locale] ?? 'Home',
                      ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: iconSize),
                      padding: EdgeInsets.all(iconPad),
                      tooltip: uiStrings['more']?[locale] ?? 'More',
                      position: PopupMenuPosition.under,
                      // Each item fires its action via `onTap` (which
                      // runs the moment the user taps the row, before
                      // the menu's close animation begins) so layout-
                      // changing actions like Open Split View take
                      // effect immediately. Using `onSelected` here
                      // delayed the callback until after the menu had
                      // fully animated closed (~250 ms), making the
                      // first split-view tap feel like it was lost.
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<String>>[];
                        // Top-level "Sign in" — only when Firebase
                        // is configured and the user isn't signed
                        // in. Tapping triggers Google popup
                        // directly, no detour through Settings.
                        if (CloudAuthService.instance.isConfigured &&
                            !CloudAuthService.instance.isSignedIn) {
                          items.add(PopupMenuItem(
                            value: 'cloudSignIn',
                            onTap: () async {
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              final result = await CloudAuthService
                                  .instance
                                  .signInWithGoogleAndAdoptProfile();
                              if (!context.mounted) return;
                              if (!result.isOk) {
                                messenger.showSnackBar(SnackBar(
                                  content: Text(
                                    result.errorMessage ??
                                        'Sign-in failed.',
                                  ),
                                  duration:
                                      const Duration(seconds: 3),
                                ));
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const GoogleGLogo(size: 16),
                                const SizedBox(width: 12),
                                Text(
                                  uiStrings['cloudSignInGoogle']
                                          ?[locale] ??
                                      'Sign in with Google',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ));
                          items.add(const PopupMenuDivider());
                        }
                        if (highlightCount > 0) {
                          items.add(PopupMenuItem(
                            value: 'highlights',
                            onTap: () => onHighlights?.call(),
                            child: _menuRow(
                              context,
                              icon: Icons.format_color_fill,
                              iconColor: scheme.primary,
                              label: uiStrings['myHighlights']?[locale] ??
                                  'My Highlights',
                              trailing: highlightCount.toString(),
                            ),
                          ));
                        }
                        // Home — pops everything off the stack so
                        // the user lands back on the Dashboard root.
                        // After Round 33 the Dashboard IS the app
                        // root; any nested stack (Settings, Library,
                        // Stats etc. on top of the reader) collapses
                        // to it via popUntil(isFirst).
                        items.add(PopupMenuItem(
                          value: 'home',
                          onTap: () {
                            Navigator.of(context)
                                .popUntil((r) => r.isFirst);
                          },
                          child: _menuRow(
                            context,
                            icon: Icons.home_outlined,
                            label: uiStrings['home']?[locale] ?? 'Home',
                          ),
                        ));
                        // Reload — always available so the user has
                        // a one-tap recovery when the reader ends up
                        // empty (failed version switch, network blip,
                        // race condition). User asked for this
                        // explicitly: "I need to quit and open app
                        // again" was their previous workaround.
                        if (onReload != null) {
                          items.add(PopupMenuItem(
                            value: 'reload',
                            onTap: () => onReload!(),
                            child: _menuRow(
                              context,
                              icon: Icons.refresh,
                              label:
                                  uiStrings['reload']?[locale] ?? 'Reload',
                            ),
                          ));
                        }
                        // Library entry — always shown so the user
                        // can discover Notes / Bookmarks even before
                        // creating any.
                        items.add(PopupMenuItem(
                          value: 'library',
                          onTap: () {
                            Get.to(
                              () => const LibraryPage(),
                              transition: Transition.rightToLeft,
                            );
                          },
                          child: _menuRow(
                            context,
                            icon: Icons.collections_bookmark_outlined,
                            label: uiStrings['library']?[locale] ?? 'Library',
                          ),
                        ));
                        items.add(PopupMenuItem(
                          value: 'stats',
                          onTap: () {
                            Get.to(
                              () => const StatsPage(),
                              transition: Transition.rightToLeft,
                            );
                          },
                          child: _menuRow(
                            context,
                            icon: Icons.insights_outlined,
                            label: uiStrings['statistics']?[locale] ??
                                'Statistics',
                          ),
                        ));
                        // Bible Evidence — pre-filtered to the
                        // current English book AND chapter so users
                        // only see archaeological / manuscript /
                        // historical findings whose pictures actually
                        // illustrate the chapter on screen. Falls back
                        // to book-wide and then to the full archive
                        // when chapter-specific coverage is thin.
                        items.add(PopupMenuItem(
                          value: 'evidence',
                          onTap: () {
                            Get.to(
                              () => EvidencePage(
                                filterBook: toEnglish(book),
                                filterChapter: chapter,
                              ),
                              transition: Transition.rightToLeft,
                            );
                          },
                          child: _menuRow(
                            context,
                            icon: Icons.museum_outlined,
                            label: uiStrings['bibleEvidence']?[locale] ??
                                'Bible Evidence',
                          ),
                        ));
                        // Gospel Synopsis — only shown when the
                        // current chapter belongs to one of the four
                        // Gospels. The data is curated from public-
                        // domain harmony tables so non-Gospel books
                        // never have anything to show.
                        if (onToggleListen != null) {
                          items.add(PopupMenuItem(
                            value: 'listen',
                            onTap: onToggleListen,
                            child: _menuRow(
                              context,
                              icon: isListening
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                              iconColor:
                                  isListening ? scheme.primary : null,
                              label: isListening
                                  ? (uiStrings['ttsStop']?[locale] ??
                                      'Stop reading')
                                  : (uiStrings['ttsListen']?[locale] ??
                                      'Listen to chapter'),
                            ),
                          ));
                        }
                        if (SynopsisService.isGospel(toEnglish(book) ?? '')) {
                          items.add(PopupMenuItem(
                            value: 'synopsis',
                            onTap: () => _showSynopsisSheet(
                              context: context,
                              englishBook: toEnglish(book) ?? book,
                              chapter: chapter,
                              locale: locale,
                            ),
                            child: _menuRow(
                              context,
                              icon: Icons.compare_arrows_rounded,
                              label: uiStrings['synopsis']?[locale] ??
                                  'Gospel Synopsis',
                            ),
                          ));
                        }
                        items.add(PopupMenuItem(
                          value: 'maps',
                          onTap: () => _showMapPicker(
                            context,
                            chapterMaps: chapterMaps,
                            bookMaps: bookMaps,
                            locale: locale,
                          ),
                          child: _menuRow(
                            context,
                            icon: chapterMaps.isNotEmpty
                                ? Icons.collections_rounded
                                : Icons.collections_outlined,
                            iconColor: chapterMaps.isNotEmpty
                                ? scheme.primary
                                : null,
                            label: uiStrings['maps']?[locale] ?? 'Maps',
                            trailing: chapterMaps.isNotEmpty
                                ? chapterMaps.length.toString()
                                : null,
                          ),
                        ));
                        items.add(PopupMenuItem(
                          value: 'sermons',
                          onTap: () =>
                              _showChapterSermonsSheet(
                                context: context,
                                sermons: chapterSermons,
                                locale: locale,
                                book: book,
                                chapter: chapter,
                              ),
                          child: _menuRow(
                            context,
                            icon: chapterSermons.isNotEmpty
                                ? Icons.menu_book_rounded
                                : Icons.menu_book_outlined,
                            iconColor: chapterSermons.isNotEmpty
                                ? scheme.primary
                                : null,
                            label: uiStrings['relatedSermons']?[locale] ??
                                'Related sermons',
                            trailing: chapterSermons.isNotEmpty
                                ? chapterSermons.length.toString()
                                : null,
                          ),
                        ));
                        if (onToggleSplitView != null) {
                          items.add(PopupMenuItem(
                            value: 'split',
                            onTap: () => onToggleSplitView?.call(),
                            child: _menuRow(
                              context,
                              icon: splitViewActive
                                  ? Icons.close_fullscreen
                                  : Icons.vertical_split,
                              label: splitViewActive
                                  ? (uiStrings['closeSplitView']?[locale] ??
                                      'Close Split View')
                                  : (uiStrings['openSplitView']?[locale] ??
                                      'Open Split View'),
                            ),
                          ));
                        }
                        if (showSidebarToggle &&
                            onToggleParagraphMode != null) {
                          items.add(PopupMenuItem(
                            value: 'paragraph',
                            onTap: () => onToggleParagraphMode?.call(),
                            child: _menuRow(
                              context,
                              icon: paragraphMode
                                  ? Icons.format_align_left
                                  : Icons.format_list_numbered_rounded,
                              iconColor:
                                  paragraphMode ? scheme.primary : null,
                              label: paragraphMode
                                  ? (uiStrings['paragraphFlow']?[locale] ??
                                      'Paragraph Flow')
                                  : (uiStrings['verseByVerse']?[locale] ??
                                      'Verse by Verse'),
                            ),
                          ));
                        }
                        if (showSearchAndSettings) {
                          items.add(const PopupMenuDivider());
                          items.add(PopupMenuItem(
                            value: 'settings',
                            onTap: onSettings,
                            child: _menuRow(
                              context,
                              icon: Icons.settings_outlined,
                              label: uiStrings['settings']?[locale] ??
                                  'Settings',
                            ),
                          ));
                        }
                        return items;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
            if (belowHeader != null) belowHeader!,
          ],
        ),
      ),
    );
  }

  /// Compact menu row used inside the overflow popup. The optional
  /// [trailing] string renders as a small count badge on the right.
  Widget _menuRow(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String label,
    String? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor ?? scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Body of the cross-references modal sheet — loads cross-refs for
/// the source verse and renders them as a tappable list with verse
/// previews in the user's current Bible version.
class _CrossRefsSheetBody extends StatefulWidget {
  final String englishBook;
  final int chapter;
  final int verse;
  final String locale;
  final MainProvider mainProvider;
  final ScrollController scrollController;
  final void Function(BibleReference ref) onNavigate;

  const _CrossRefsSheetBody({
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.mainProvider,
    required this.scrollController,
    required this.onNavigate,
  });

  @override
  State<_CrossRefsSheetBody> createState() => _CrossRefsSheetBodyState();
}

class _CrossRefsSheetBodyState extends State<_CrossRefsSheetBody> {
  late Future<List<BibleReference>> _future;
  // Index of the current Bible version's verses by canonical book +
  // chapter + verse so the preview text loads instantly.
  late final Map<String, String> _verseIndex;

  @override
  void initState() {
    super.initState();
    _future = CrossReferenceService.forVerseOrNearby(
        widget.englishBook, widget.chapter, widget.verse);
    _verseIndex = {
      for (final v in widget.mainProvider.verses)
        '${toEnglish(v.book) ?? v.book}-${v.chapter}-${v.verse}': v.text,
    };
  }

  String? _previewFor(BibleReference ref) {
    final v = ref.verseStart ?? 1;
    final raw = _verseIndex['${ref.englishBook}-${ref.chapter}-$v'];
    if (raw == null) return null;
    return sanitizeForSearch(raw);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final sourceLabel =
        '${localeAwareBookName(widget.englishBook, locale, widget.mainProvider.currentVersion)} '
        '${widget.chapter}:${widget.verse}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Icon(Icons.hub_outlined, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      uiStrings['crossRefs']?[locale] ?? 'Cross-references',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      sourceLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                iconSize: 20,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<BibleReference>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final refs = snap.data ?? const <BibleReference>[];
              if (refs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline,
                            color: scheme.onSurfaceVariant, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          uiStrings['crossRefsNone']?[locale] ??
                              'No curated cross-references for this verse yet.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: refs.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: scheme.outlineVariant.withValues(alpha: 0.4)),
                itemBuilder: (_, i) {
                  final r = refs[i];
                  final preview = _previewFor(r);
                  final label = r.toString().replaceFirst(
                        r.englishBook,
                        localeAwareBookName(r.englishBook, locale,
                            widget.mainProvider.currentVersion),
                      );
                  return InkWell(
                    onTap: () => widget.onNavigate(r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                          if (preview != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Open a modal sheet showing the harmony entries that touch the
/// current Gospel chapter. Each row lists the parallels in the
/// other Gospels — tapping any reference jumps the reader to it.
void _showSynopsisSheet({
  required BuildContext context,
  required String englishBook,
  required int chapter,
  required String locale,
}) {
  final mainProvider = context.read<MainProvider>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 900),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Scaffold(
        backgroundColor: Colors.transparent,
        body: _SynopsisSheetBody(
          englishBook: englishBook,
          chapter: chapter,
          locale: locale,
          scrollController: scrollController,
          onNavigate: (ref) {
            Navigator.of(sheetCtx).maybePop();
            _navigateToBibleReference(
              mainProvider: mainProvider,
              ref: ref,
              locale: locale,
            );
          },
        ),
      ),
    ),
  );
}

class _SynopsisSheetBody extends StatefulWidget {
  final String englishBook;
  final int chapter;
  final String locale;
  final ScrollController scrollController;
  final void Function(BibleReference) onNavigate;

  const _SynopsisSheetBody({
    required this.englishBook,
    required this.chapter,
    required this.locale,
    required this.scrollController,
    required this.onNavigate,
  });

  @override
  State<_SynopsisSheetBody> createState() => _SynopsisSheetBodyState();
}

class _SynopsisSheetBodyState extends State<_SynopsisSheetBody> {
  List<SynopsisEvent>? _events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list =
        await SynopsisService.byChapter(widget.englishBook, widget.chapter);
    if (!mounted) return;
    setState(() => _events = list);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final events = _events;
    final mainProvider = context.read<MainProvider>();

    if (events == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Drag handle.
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.outline.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.compare_arrows_rounded,
                  color: scheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uiStrings['synopsis']?[widget.locale] ??
                          'Gospel Synopsis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      '${localeAwareBookName(widget.englishBook, widget.locale, mainProvider.currentVersion)} ${widget.chapter}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      uiStrings['synopsisNone']?[widget.locale] ??
                          'No parallel passages curated for this chapter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final ev = events[i];
                    return _SynopsisRow(
                      event: ev,
                      currentBook: widget.englishBook,
                      locale: widget.locale,
                      version: mainProvider.currentVersion,
                      fontFamily: settings.fontFamily,
                      onNavigate: widget.onNavigate,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SynopsisRow extends StatelessWidget {
  final SynopsisEvent event;
  final String currentBook;
  final String locale;
  final String version;
  final String fontFamily;
  final void Function(BibleReference) onNavigate;

  const _SynopsisRow({
    required this.event,
    required this.currentBook,
    required this.locale,
    required this.version,
    required this.fontFamily,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gospels = ['Matthew', 'Mark', 'Luke', 'John'];
    final present = gospels
        .where((g) => event.refs.containsKey(g.toLowerCase()))
        .toList();
    final isUnique = present.length == 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.localizedTitle(locale),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final g in present)
                _RefChip(
                  label: _shortLabel(g, event.rawRef(g.toLowerCase()) ?? ''),
                  isCurrentGospel: g == currentBook,
                  onTap: () {
                    final ref = event.referenceFor(g);
                    if (ref != null) onNavigate(ref);
                  },
                ),
              if (isUnique)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    uiStrings['synopsisOnlyHere']?[locale] ??
                        'Only in this Gospel',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact chip label like "Mt 5:1-12" (English) or
  /// "马太 5:1-12" (Chinese). Strips the full English name from the raw
  /// "Matthew 5:1-12" and replaces with the localized abbreviation.
  String _shortLabel(String englishGospel, String raw) {
    // raw looks like "Matthew 5:1-12" — take everything after the first
    // space and prepend a localized short name.
    final spaceIdx = raw.indexOf(' ');
    final tail = spaceIdx > 0 ? raw.substring(spaceIdx + 1) : raw;
    final shortBook = locale.startsWith('zh')
        ? localeAwareBookName(englishGospel, locale, version)
        : _enShortGospel(englishGospel);
    return '$shortBook $tail';
  }

  String _enShortGospel(String g) {
    switch (g) {
      case 'Matthew':
        return 'Matt';
      case 'Mark':
        return 'Mark';
      case 'Luke':
        return 'Luke';
      case 'John':
        return 'John';
    }
    return g;
  }
}

class _RefChip extends StatelessWidget {
  final String label;
  final bool isCurrentGospel;
  final VoidCallback onTap;

  const _RefChip({
    required this.label,
    required this.isCurrentGospel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isCurrentGospel
        ? scheme.primary.withValues(alpha: 0.20)
        : scheme.primary.withValues(alpha: 0.08);
    final fg = isCurrentGospel ? scheme.primary : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative section / paragraph heading rendered above the matching
/// verse in the reading pane. Title text comes from
/// `SectionTitleService` — the version-to-set mapping in
/// `lib/constants/section_title_map.dart` decides which set is used
/// for the active translation. When optional `context` is present an
/// info-icon button next to the title toggles a 1-2 sentence
/// background note. Default state is collapsed — readers who want
/// the context tap to reveal it; everyone else gets a clean heading.
class _SectionHeading extends StatefulWidget {
  final String title;
  final String? context;
  final bool isFirst;
  final Widget child;
  const _SectionHeading({
    required this.title,
    this.context,
    required this.isFirst,
    required this.child,
  });

  @override
  State<_SectionHeading> createState() => _SectionHeadingState();
}

class _SectionHeadingState extends State<_SectionHeading> {
  bool _expanded = false;

  @override
  Widget build(BuildContext buildContext) {
    final settings = buildContext.watch<AppSettings>();
    final scheme = Theme.of(buildContext).colorScheme;
    final fs = settings.fontSize;
    final hasContext =
        widget.context != null && widget.context!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Larger top spacing between sections; tighter when this
          // is the very first paragraph in the chapter so the
          // heading doesn't push the body too far down.
          padding: EdgeInsets.fromLTRB(
            12, widget.isFirst ? 6 : 18, 12, _expanded ? 4 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Small accent bar — anchors the heading without
              // shouting.
              Container(
                width: 3,
                height: (fs + 2).clamp(14.0, 20.0).toDouble(),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize:
                        (fs + 1).clamp(14.0, 20.0).toDouble(),
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (hasContext) ...[
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  iconSize: 18,
                  splashRadius: 18,
                  tooltip: uiStrings['sectionContextTooltip']
                          ?[settings.locale] ??
                      'Background',
                  icon: Icon(
                    _expanded
                        ? Icons.info
                        : Icons.info_outline,
                    color: scheme.primary,
                  ),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ],
          ),
        ),
        if (hasContext)
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: _expanded
                ? Padding(
                    padding:
                        const EdgeInsets.fromLTRB(23, 0, 12, 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: scheme.outlineVariant
                                .withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        widget.context!,
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: (fs - 3)
                              .clamp(12.0, 15.0)
                              .toDouble(),
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        widget.child,
      ],
    );
  }
}

/// Collapsible card rendered at the top of chapter 1 when the active
/// book has an authored intro. Shows subtitle + summary by default;
/// tap "Read more" to expand author / date / audience / themes /
/// key passage. Hidden when `settings.showBookIntro` is false.
class _BookIntroCard extends StatefulWidget {
  final BookIntro intro;
  final String locale;
  const _BookIntroCard({required this.intro, required this.locale});

  @override
  State<_BookIntroCard> createState() => _BookIntroCardState();
}

class _BookIntroCardState extends State<_BookIntroCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final fs = settings.fontSize;
    final intro = widget.intro;

    final textStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: (fs - 2).clamp(13.0, 16.0).toDouble(),
      color: scheme.onSurface,
      height: 1.55,
    );
    final labelStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: (fs - 4).clamp(11.0, 13.0).toDouble(),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: scheme.primary,
    );

    Widget metaRow(String labelKey, String value) {
      if (value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (uiStrings[labelKey]?[locale] ?? labelKey).toUpperCase(),
              style: labelStyle,
            ),
            const SizedBox(height: 2),
            Text(value, style: textStyle),
          ],
        ),
      );
    }

    final themes = intro.getThemes(locale);

    // Default-collapsed: a slim banner — book icon + "About this
    // book" label, the subtitle, and a "Background ▾" chip-button
    // that reveals everything else on tap. Keeps the chapter's
    // first verses immediately reachable for users who don't want
    // the metadata.
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + label on the left, expand chevron
            // on the right. Whole card is tappable, but the chevron
            // makes the affordance obvious.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    uiStrings['aboutThisBook']?[locale] ??
                        'About this book',
                    style: labelStyle,
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 22,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              intro.getSubtitle(locale),
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (fs).clamp(14.0, 19.0).toDouble(),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                height: 1.35,
              ),
            ),
            // Collapsed state stops here. Expanded state reveals
            // summary + author / date / audience / themes / key
            // passage. AnimatedSize gives a soft expand/collapse
            // motion without dropping into the verse layout.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: _expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(intro.getSummary(locale), style: textStyle),
                        metaRow('authorLabel', intro.getAuthor(locale)),
                        metaRow('dateLabel', intro.getDate(locale)),
                        metaRow('audienceLabel', intro.getAudience(locale)),
                        if (themes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (uiStrings['themesLabel']?[locale] ??
                                          'Themes')
                                      .toUpperCase(),
                                  style: labelStyle,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final t in themes)
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 10,
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                          color: scheme.primary
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          t,
                                          style: TextStyle(
                                            fontFamily:
                                                settings.fontFamily,
                                            fontSize: (fs - 4)
                                                .clamp(11.0, 14.0)
                                                .toDouble(),
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (intro.keyPassage.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            (uiStrings['keyPassageLabel']?[locale] ??
                                    'Key passage')
                                .toUpperCase(),
                            style: labelStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            intro.keyPassage,
                            style: TextStyle(
                              fontFamily: settings.fontFamily,
                              fontSize:
                                  (fs - 1).clamp(13.0, 17.0).toDouble(),
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (intro
                              .getKeyPassageDescription(locale)
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              intro.getKeyPassageDescription(locale),
                              style: textStyle.copyWith(
                                fontStyle: FontStyle.italic,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
