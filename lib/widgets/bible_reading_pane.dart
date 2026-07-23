import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/widgets/note_reference_picker_sheet.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_map.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/bible_trivia_page.dart' as trivia;
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
import 'package:yswords/services/ai_word_service.dart';
import 'package:yswords/utils/ai_text_cleaner.dart';
import 'package:yswords/utils/chapter_scroll_progress.dart';
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
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/haptics.dart';
import 'package:yswords/utils/illustration_grouping.dart';
// 2026-05-10 (v1.2.13): the `as jumper` import was only needed by
// the `_captureChapterRelativeVerseNum` / `_scrollToVerseInChapter`
// thin wrappers that v1.2.13 removed alongside the version-switch
// scroll-restore complexity. Only `prepareJumpToVerse` is still
// used in this file (jump-to-reference flow on a verse tap).
import 'package:yswords/utils/jump_to_reference.dart' show prepareJumpToVerse;
import 'package:yswords/utils/note_reference_parser.dart'
    show extractNoteReferences, NoteReferenceMatch;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/widgets/verse_popup_sheet.dart' show showVersePopup;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/short_book_name.dart';
import 'package:yswords/widgets/google_g_logo.dart';
import 'package:yswords/widgets/illustration_image.dart';
import 'package:yswords/utils/floating_toast.dart' show showFloatingToast;
import 'package:yswords/utils/version_mapper.dart'
    show translateBookName, toEnglish, localeAwareBookName;
import 'package:yswords/widgets/highlights_sheet.dart';
import 'package:yswords/widgets/originals_sheet.dart';
import 'package:yswords/widgets/verse_widget.dart';
import 'package:yswords/widgets/paragraph_group_widget.dart';
import 'package:yswords/widgets/version_picker_sheet.dart'
    show showLanguageGroupedVersionMenu;
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

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
  // ignore: unused_field
  MainProvider? _positionsProvider;
  // 2026-05-24 (v1.3.3): track the LISTENER INSTANCE we subscribed to,
  // not just the provider, because mp.itemPositionsListener is now a
  // getter that forwards to the active _ChapterPage's local listener
  // — the instance changes every time the user swipes to a new
  // chapter. _attachPositionsListener compares identity and
  // re-subscribes when the active page swaps.
  ItemPositionsListener? _attachedPositionsListener;
  // 2026-05-24 (v1.3.16) PERF: scroll-position state moved to
  // ValueNotifiers so `_handleItemPositionsChanged` (which fires on
  // every visible-verse change during scrolling, ~60 Hz) no longer
  // calls `setState()` on the whole pane. Pre-fix the setState
  // rebuilt the entire `_BibleReadingPaneState.build()` subtree
  // including the top-level Consumer2 (~3 KB of children + chrome
  // + sidebar slot + glass surfaces). Post-fix only the right-edge
  // position indicator's `ValueListenableBuilder` rebuilds (~80
  // bytes of widget tree). The notifiers replace what used to be
  // two `setState`-managed instance fields; reads use `.value`,
  // writes assign to `.value` (no setState needed).
  final ValueNotifier<int> _visibleItemIndexNotifier = ValueNotifier(0);
  // 2026-06-15 (v1.3.80): CONTINUOUS visible-item position — the first
  // visible item's index PLUS the fraction of that item already scrolled
  // off the top. The integer `_visibleItemIndexNotifier` above is enough
  // for verse-by-verse mode (one item == one verse, so the right-edge
  // bar moves smoothly), but in PARAGRAPH mode each item is a whole
  // paragraph group, so the bar jumped group-to-group (and didn't move
  // at all while scrolling inside one long paragraph). The build path
  // interpolates the verse index across the visible group with this
  // fraction so the bar position tracks "how much is left" proportionally
  // — exactly what the verse number already implies. Verse-by-verse mode
  // is intentionally left on its existing formula.
  final ValueNotifier<double> _visibleItemPosNotifier = ValueNotifier(0.0);
  // 2026-06-28 (v1.3.110): the right-edge BAR is now a PIXEL-proportional scroll
  // fraction (even with the page length, in both paragraph + verse modes). This
  // notifier carries the precomputed 0..1 progress; the NUMBER still uses
  // _visibleItemPosNotifier (top-of-screen verse).
  final ValueNotifier<double> _chapterProgressNotifier = ValueNotifier(0.0);
  // Measured item heights (trailingEdge − leadingEdge, in viewport-height units)
  // for the ACTIVE chapter, accumulated as items scroll into view. Keyed reset
  // (_progressKey) whenever the version/book/chapter changes. _progressItemCount
  // (header + groups + footer) is refreshed from the pill builder each frame.
  final Map<int, double> _itemHeights = {};
  String _progressKey = '';
  int _progressItemCount = 0;
  final ValueNotifier<bool> _showVersePositionNotifier = ValueNotifier(false);
  Timer? _versePositionTimer;

  // 2026-05-21 (v1.2.70): chrome feature is enabled on every platform.
  // The iOS-only disable from an earlier hotfix attempt is reverted —
  // we now filter out the large programmatic-jump scroll deltas (see
  // [_onScrollDelta]) which were the likely trigger for the swipe-left
  // grey-screen hang on iPhone. Keeping the constant as a one-place
  // kill-switch if we need to disable again.
  //
  // 2026-06-22 (v1.3.102): MUST stay `true`. v1.3.99 tried flipping it
  // to `false` to disable the auto-hide-on-scroll feature — but the
  // bottom bar's `if (_chromeFeatureEnabled && …)` gate then short-
  // circuited and the WHOLE bottom bar stopped mounting. Auto-hide is
  // disabled the right way: `_onScrollDelta` is now a no-op (see below).
  bool get _chromeFeatureEnabled => true;

  // 2026-05-21 (v1.2.70): WeDevote-style auto-hide chrome.
  //   _chromeVisible drives both the top _FloatingHeader and the new
  //   _BibleReaderBottomBar. Pixel-level scroll detection drives the
  //   hide/show — more responsive than item-index changes (which can
  //   stall on long verses that span the screen).
  //   Thresholds: hide on cumulative scroll-down >= 50 px; show on
  //   cumulative scroll-up >= 10 px (more sensitive going up, matching
  //   Kindle / WeDevote / iBooks).
  //   No idle-timer re-show — once hidden, chrome stays hidden until
  //   the user explicitly scrolls up, taps, or selects a verse.
  bool _chromeVisible = true;
  double _chromeScrollAccumulator = 0;
  StreamSubscription<double>? _scrollOffsetSub;
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

  // 2026-05-24 (v1.3.19): TTS (朗读) feature removed end-to-end at
  // user request ("then remove 朗读 totally please"). The polled
  // `_isListening` flag + `_ttsPoller` ticker are gone; so are
  // `_toggleListenChapter`, `_legacyTtsSpeakSequence`,
  // `_startTtsPolling`/`_stopTtsPolling`, `_ttsLocaleForVersion`,
  // the menu item, the keyboard shortcut, and the entire
  // `lib/services/tts_*` + `lib/widgets/listen_button.dart` files.
  // See the v1.3.19 entry in HANDOFF.md for the full removal log.

  // 2026-05-24 (v1.2.96): N-page chapter pager. PageView with one
  // page per chapter in `mainProvider.chapterList` (~1189 entries
  // Gen 1 → Rev 22). PageView.builder keeps only the visible page
  // + a couple cached neighbours alive, so memory is fine.
  //
  // Why this replaced the v1.2.94 3-page model: that design called
  // `jumpToPage(1)` after every settle to keep the SPL centred,
  // which is an INSTANT snap. User reported "一松手，就马上跳动
  // 到那一章一瞬间，而不是滑过去" — the snap broke the WeDevote
  // book-flip feel. With one page per chapter the PageController
  // index directly tracks the chapter; settle = land = no jump.
  //
  // The active page (index == findChapterIndex(currentChapter))
  // renders the FULL SPL (selection, highlights, notes,
  // paragraph grouping, mainProvider's controllers). Adjacent
  // pages render `_ChapterPreview` (lightweight Text list) so we
  // don't pay the cost of N concurrent SPLs nor fight over the
  // mainProvider controllers.
  late final PageController _pageController;
  // Set true between user swipe and the post-frame
  // `setCurrentChapter` so the build-time controller-sync pass
  // (which exists to handle EXTERNAL chapter changes, e.g.
  // pendingJump from search) doesn't try to "correct" a swipe
  // that's already in flight.
  bool _pageSwipeInFlight = false;
  // 2026-05-24 (v1.2.98): track the last chapter index we synced
  // the PageController to. The build-time sync block was
  // misfiring during normal builds (provider notifies on
  // selection / highlight / etc., not just chapter changes),
  // scheduling a redundant jumpToPage that landed on top of an
  // in-flight swipe and produced the "翻页还是卡顿一下" stutter.
  // Sync only when this differs from `currentChapterPageIdx` AND
  // the controller is somewhere else — i.e. an EXTERNAL chapter
  // change (search / library jump). Pure rebuilds become no-ops.
  int? _lastSyncedChapterIdx;

  @override
  void initState() {
    super.initState();
    final mp = context.read<MainProvider>();
    final initialChapterIdx = mp.findChapterIndex(
            mp.currentBook, mp.currentChapter) ??
        0;
    _pageController = PageController(
        initialPage: initialChapterIdx, viewportFraction: 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mainProvider = context.read<MainProvider>();
      _attachPositionsListener(mainProvider);
      // 2026-05-24 (v1.3.1): warm adjacent chapters on first mount
      // too — otherwise the user's first swipe out of the
      // boot-time chapter would still hit the cold path.
      if (mainProvider.currentBook != null &&
          mainProvider.currentChapter != null) {
        Future.microtask(() => _prewarmAdjacentChapters(
              mainProvider,
              mainProvider.currentBook!,
              mainProvider.currentChapter!,
            ));
      }
    });
  }

  // 2026-05-24 (v1.3.19): TTS toggle + polling + locale-mapper +
  // legacy SpeechSynthesis fallback all removed. See header
  // comment for the rationale.

  /// Show a small dialog listing the keyboard shortcuts. Triggered by
  /// `?` (Shift+/) on web — pure discoverability help; tapping
  /// outside or hitting Esc dismisses.
  void _showShortcutsHelp(BuildContext context, String locale) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <List<String>>[
      ['/', uiStrings['search']?[locale] ?? 'Search'],
      ['[', uiStrings['previousChapter']?[locale] ?? 'Previous chapter'],
      [']', uiStrings['nextChapter']?[locale] ?? 'Next chapter'],
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
    _scrollOffsetSub?.cancel();
    _pageController.dispose();
    _attachedPositionsListener?.itemPositions
        .removeListener(_handleItemPositionsChanged);
    _visibleItemIndexNotifier.dispose();
    _visibleItemPosNotifier.dispose();
    _chapterProgressNotifier.dispose();
    _showVersePositionNotifier.dispose();
    super.dispose();
  }

  void _attachPositionsListener(MainProvider provider) {
    // 2026-05-24 (v1.3.3): provider.itemPositionsListener is now a
    // getter returning the active _ChapterPage's local listener.
    // Compare the LISTENER instance, not the provider, so we
    // re-subscribe whenever the user swipes to a new chapter (the
    // active controllers swap and the listener instance with them).
    final currentListener = provider.itemPositionsListener;
    if (identical(_attachedPositionsListener, currentListener)) return;
    _attachedPositionsListener?.itemPositions
        .removeListener(_handleItemPositionsChanged);
    _scrollOffsetSub?.cancel();
    _scrollOffsetSub = null;
    _chromeScrollAccumulator = 0; // fresh slate on listener switch
    _positionsProvider = provider;
    _attachedPositionsListener = currentListener;
    currentListener.itemPositions
        .addListener(_handleItemPositionsChanged);
    // 2026-05-22 (v1.2.71): no longer subscribing to
    // provider.scrollOffsetListener.changes — that stream stops
    // emitting after the SPL re-mounts (verified bug). Chrome auto-
    // hide is now driven by NotificationListener<ScrollNotification>
    // wrapping the SPL, which works on every mount including re-mounts.
  }

  void _handleItemPositionsChanged() {
    final positions =
        _attachedPositionsListener?.itemPositions.value;
    if (positions == null || positions.isEmpty || !mounted) return;

    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList();
    if (visible.isEmpty) return;

    visible.sort((a, b) {
      final edge = a.itemLeadingEdge.compareTo(b.itemLeadingEdge);
      return edge != 0 ? edge : a.index.compareTo(b.index);
    });
    final first = visible.first;
    final nextIndex = first.index;

    // v1.3.80: continuous position = item index + the fraction of that
    // first visible item already scrolled past the top of the viewport.
    // itemLeadingEdge is ≤ 0 once the item's top crosses above the
    // viewport top; the span (trailing − leading) is the item's height
    // in viewport-fraction units. Drives the proportional right-edge bar
    // (smooth even while scrolling inside one long paragraph).
    final span = first.itemTrailingEdge - first.itemLeadingEdge;
    final withinFrac =
        span <= 0 ? 0.0 : (-first.itemLeadingEdge / span).clamp(0.0, 1.0);
    // topPos = content position at the viewport TOP — drives the verse NUMBER
    // (the verse you're reading). The number stays on the line you're on, e.g.
    // "19/24" even when the bar is already at the bottom.
    final pos = first.index + withinFrac;

    // 2026-06-28 (v1.3.110): PIXEL-proportional BAR. Cache each visible item's
    // height (in viewport-height units), reset when the chapter changes, then
    // estimate the scroll fraction from those heights so the bar advances evenly
    // with the actual page length in both paragraph + verse modes (not by verse
    // count). `_progressItemCount` (header + groups + footer) is supplied by the
    // pill builder.
    final provider = _positionsProvider;
    final key = provider == null
        ? ''
        : '${provider.currentVersion}|${provider.currentBook}'
            '|${provider.currentChapter}';
    if (key != _progressKey) {
      _progressKey = key;
      _itemHeights.clear();
    }
    for (final p in visible) {
      final h = p.itemTrailingEdge - p.itemLeadingEdge;
      if (h > 0) _itemHeights[p.index] = h;
    }
    final progress = pixelScrollFraction(
      firstIndex: first.index,
      firstLeadingEdge: first.itemLeadingEdge,
      itemCount: _progressItemCount,
      itemHeights: _itemHeights,
    );

    if (mounted) {
      _visibleItemPosNotifier.value = pos;
      _chapterProgressNotifier.value = progress;
      // Keep the pill visible while the position is changing (covers
      // scrolling within a single big paragraph where the integer index
      // never moves) and re-arm the 2 s auto-fade.
      _showVersePositionNotifier.value = true;
      _versePositionTimer?.cancel();
      _versePositionTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) _showVersePositionNotifier.value = false;
      });
    }

    if (nextIndex != _visibleItemIndexNotifier.value && mounted) {
      // v1.3.16: notifier assignment instead of setState — only the
      // position indicator's ValueListenableBuilder rebuilds, not
      // the whole pane.
      _visibleItemIndexNotifier.value = nextIndex;
      // 2026-05-22 (v1.2.71): chrome auto-hide is now driven by
      // NotificationListener<ScrollNotification> instead of this
      // item-level path (which silently stopped emitting after
      // BibleReadingPane re-mount). The ONLY chrome rule still
      // tied to item-level: force chrome visible when the user
      // reaches index 0 (top of chapter) so they're never in a
      // "chrome hidden + can't scroll up" dead state.
      if (nextIndex == 0 && !_chromeVisible) {
        _safeChromeSetState(() {
          _chromeVisible = true;
          _chromeScrollAccumulator = 0;
        });
      }
    }
  }

  /// Defer a chrome-state change to after the current frame so we never
  /// call setState during build / layout / paint. Stream listeners and
  /// ValueListenable callbacks can fire during any of those phases.
  void _safeChromeSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  /// 2026-05-22 (v1.2.71): NotificationListener handler — catches every
  /// ScrollUpdateNotification from the SPL directly, which means it
  /// continues working after BibleReadingPane unmounts + re-mounts
  /// (the previous provider-based ItemPositionsListener subscription
  /// silently went dead on the second open). Delegates to the same
  /// accumulator logic as the old scrollOffsetListener handler.
  bool _onScrollNotification(ScrollNotification notification) {
    if (!_chromeFeatureEnabled) return false;
    if (widget.splitViewActive) return false; // chrome pinned in split
    if (notification is ScrollUpdateNotification) {
      final dy = notification.scrollDelta ?? 0;
      _onScrollDelta(dy);
    }
    return false; // never consume — let SPL handle scrolling
  }

  /// Pixel-level scroll-direction handler. Called from
  /// [_onScrollNotification] (and the legacy ScrollOffsetListener
  /// subscription, kept for completeness). Positive delta = user
  /// scrolling DOWN; negative = UP.
  void _onScrollDelta(double delta) {
    // 2026-06-22 (v1.3.102): auto-hide-on-scroll DISABLED per user
    // request — "top bottom menu自动隐藏这个功能其实不好用，去掉".
    // The handler is a no-op now: `_chromeVisible` stays at its initial
    // `true` forever, so the top FloatingHeader + bottom bar remain
    // pinned visible while reading. Kept as a separate gate (not via
    // `_chromeFeatureEnabled`) because that flag also controls whether
    // the bottom bar widget itself MOUNTS — flipping it false would
    // remove the bottom bar entirely (v1.3.101 bug). All the rest of
    // the chrome state machine (`_toggleChrome`, manual reveal on
    // scroll-to-top, etc.) still works for future use if we ever want
    // to bring back manual toggle. Original auto-hide algorithm below
    // is intentionally dead code, kept for diff-clarity.
    return;
    // ignore: dead_code
    if (!mounted || delta == 0) return;
    // 2026-05-21 (v1.2.70 hotfix): chapter-switch via swipe / Prev /
    // Next calls `provider.jumpToTop()` which fires a single, huge
    // negative delta (often -3000+ px) through this stream. On iOS
    // that synchronous emission inside the gesture handler was the
    // likely cause of the "swipe-left → grey screen" hang. Filter
    // anything > 300 px in one event — real user-scroll deltas are
    // always much smaller (a single scroll tick is < 60 px even on
    // high-rate trackpads). Also reset the accumulator so the next
    // real scroll starts from a clean slate.
    if (delta.abs() > 300) {
      _chromeScrollAccumulator = 0;
      return;
    }
    // Direction reversal → restart accumulator.
    if (_chromeScrollAccumulator != 0 &&
        delta.sign != _chromeScrollAccumulator.sign) {
      _chromeScrollAccumulator = 0;
    }
    _chromeScrollAccumulator += delta;
    if (_chromeScrollAccumulator >= 50 && _chromeVisible) {
      _safeChromeSetState(() => _chromeVisible = false);
      _chromeScrollAccumulator = 0;
    } else if (_chromeScrollAccumulator <= -10 && !_chromeVisible) {
      _safeChromeSetState(() => _chromeVisible = true);
      _chromeScrollAccumulator = 0;
    }
  }

  /// 2026-05-24 (v1.3.8): scroll the active chapter's SPL back to
  /// verse 1 (item index 0). Triggered by the cross-platform "tap
  /// status bar" zone added in the Stack below — matches iOS muscle
  /// memory (tap status bar → scroll-to-top) and brings the same
  /// affordance to Android / web / macOS where the OS doesn't
  /// provide it.
  ///
  /// Uses mainProvider.itemScrollController which (since v1.3.3) is
  /// a forwarder pointing at the currently-active _ChapterPage's
  /// local controller. Animated 350 ms easeOut for an obvious "I'm
  /// flying back up" affordance — instant jumpTo on a long chapter
  /// would feel like a teleport.
  void _scrollChapterToTop() {
    final mp = context.read<MainProvider>();
    final c = mp.itemScrollController;
    if (!c.isAttached) return;
    c.scrollTo(
      index: 0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0,
    );
    // Also reveal the chrome — convention is "I'm back at the top,
    // here are the navigation controls again".
    if (_chromeFeatureEnabled && !_chromeVisible) {
      _safeChromeSetState(() => _chromeVisible = true);
    }
  }

  /// Toggle the auto-hide chrome. Historically called by a tap on the
  /// reader's empty area (top/bottom margins, gaps between verses).
  ///
  /// 2026-06-28: NO-OP. The user asked for the bible reader to have no
  /// hide behaviour at all — "when clicking the background white part the
  /// top and bottom menu will still hide but it shouldn't have auto hide
  /// or hide function anymore". The scroll auto-hide was already disabled
  /// (`_onScrollDelta` no-op, v1.3.102); this disables the remaining
  /// tap-to-hide path too, so `_chromeVisible` stays `true` and both the
  /// header + bottom bar are permanently pinned. Kept as a method (not
  /// deleted) so the existing call sites compile unchanged.
  void _toggleChrome() {
    // Intentionally does nothing — chrome never hides in the reader.
  }

  /// Quick font-size adjuster sheet, opened from the bottom bar's Aa
  /// button. Mirrors the slider in Settings → Display but inline so the
  /// user doesn't lose their reading position. Range matches AppSettings
  /// (12-32 pt). Closes when the user taps outside the sheet.
  void _showFontSizeSheet(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: StatefulBuilder(
              builder: (innerCtx, setSheet) {
                final size = settings.fontSize;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      uiStrings['fontSize']?[settings.locale] ?? 'Font size',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.text_decrease_rounded),
                          onPressed: size <= 12
                              ? null
                              : () async {
                                  await settings
                                      .setFontSize((size - 1).clamp(12, 32));
                                  setSheet(() {});
                                },
                        ),
                        Text(
                          size.round().toString(),
                          style: TextStyle(
                            fontSize: (size * 1.2).clamp(18.0, 32.0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.text_increase_rounded),
                          onPressed: size >= 32
                              ? null
                              : () async {
                                  await settings
                                      .setFontSize((size + 1).clamp(12, 32));
                                  setSheet(() {});
                                },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
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
    }).catchError((Object e, StackTrace st) {
      // 2026-05-22 (v1.2.72): map asset reads occasionally fail on
      // first launch (race with offline-pack hydration). Swallow the
      // error so it doesn't end up as an unhandled future log;
      // _chapterMaps stays at its previous value and the picker
      // will silently fall back to "all maps" / empty state.
      debugPrint('[BibleReadingPane] map load failed: $e');
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

  // Round 56: helpers extracted to `lib/utils/jump_to_reference.dart`
  // 2026-05-10 (v1.2.13): the `_captureChapterRelativeVerseNum`
  // and `_scrollToVerseInChapter` thin wrappers that lived here
  // were removed. Their only caller was `onVersionSelected`,
  // which dropped the verse-precise scroll-restore logic per
  // user request ("不用 keep state 了"). The underlying
  // `jumper.captureCurrentVerseNum` / `scrollToVerseNumInChapter`
  // helpers are still in `lib/utils/jump_to_reference.dart` if a
  // future feature wants the precise restore back.
  void _switchTo(MainProvider provider, String book, int chap) {
    final matched = provider.versesInChapter(book, chap);
    if (matched.isEmpty) return;
    provider.setCurrentChapter(book: book, chapter: chap);
    provider.updateCurrentVerse(verse: matched.first);
    provider.jumpToTop();
    if (mounted) _visibleItemIndexNotifier.value = 0;
    // 2026-05-24 (v1.3.1): pre-warm paragraph cache for next-prev
    // chapters so the user's NEXT swipe lands on a cache hit instead
    // of a ~50 ms recompute. User reported persistent "翻页还是有点
    // 卡" even after v1.2.99's 30→300 cache bump and O(1) verse
    // index. The remaining cost was first-visit paragraph grouping
    // for chapters the user hasn't been to. Pre-warming the two
    // closest neighbours eliminates that cost for the common forward/
    // backward swipe pattern.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.microtask(() => _prewarmAdjacentChapters(provider, book, chap));
    });
  }

  /// Re-anchor the chapter PageController after a version switch.
  ///
  /// A version switch can RESIZE the canon: LJK (NT-only, ~260 pages)
  /// ↔ a full-canon version (~1189 pages). That silently reinterprets
  /// every PageController page index. The build-time sync block can't
  /// always catch it: `currentChapterPageIdx` collapses to 0 via its
  /// `?? 0` fallback whenever the pre-switch position isn't in the old
  /// version's canon (the partial-canon empty-state — e.g. an LJK pane
  /// synced to an OT chapter it doesn't ship). `_lastSyncedChapterIdx`
  /// then also holds 0, so after switching to a full-canon version
  /// whose target chapter resolves to that same stale index, the guard
  /// `_lastSyncedChapterIdx != currentChapterPageIdx` is false and the
  /// controller is never moved — the PageView stays parked on a stale
  /// page (user: the 希伯来圣经 / OT chapter only appears after closing +
  /// reopening the menu, which forces an unrelated rebuild). Forcing the
  /// re-anchor here makes the new chapter show immediately.
  void _reanchorPageForVersionSwitch(MainProvider p) {
    // Invalidate the gate so the next sync pass can't early-return on a
    // stale-equal index.
    _lastSyncedChapterIdx = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final idx =
          p.findChapterIndex(p.currentBook, p.currentChapter) ?? 0;
      _lastSyncedChapterIdx = idx;
      if (_pageController.page?.round() != idx) {
        _pageController.jumpToPage(idx);
      }
    });
  }

  /// Compute + cache paragraph groups for the chapter that's one
  /// step before AND one step after `(book, chap)`. Idempotent —
  /// cache hits short-circuit. Microtask-scheduled so it never
  /// blocks the active build.
  void _prewarmAdjacentChapters(
      MainProvider provider, String book, int chap) {
    final settings = context.read<AppSettings>();
    final idx = provider.findChapterIndex(book, chap);
    if (idx == null) return;
    final list = provider.chapterList;
    for (final delta in const [-1, 1]) {
      final target = idx + delta;
      if (target < 0 || target >= list.length) continue;
      final tgt = list[target];
      final verses = provider.versesInChapter(tgt.book, tgt.chapter);
      if (verses.isEmpty) continue;
      // Cache hit? Skip.
      final cached = provider.cachedParagraphGrouping(
        book: tgt.book,
        chapter: tgt.chapter,
        paragraphMode: settings.paragraphMode,
        versesLength: verses.length,
      );
      if (cached != null) continue;
      // Compute + store. Same logic as the main build path so the
      // cached record matches structure-wise.
      final paragraphGroups = settings.paragraphMode
          ? _groupIntoParagraphs(verses)
          : verses.map((v) => [v]).toList();
      final vToI = <int, int>{};
      final iToV = <int, int>{0: 0};
      int vIdx = 0;
      for (int g = 0; g < paragraphGroups.length; g++) {
        iToV[g + 1] = vIdx;
        for (int v = 0; v < paragraphGroups[g].length; v++) {
          vToI[vIdx] = g + 1;
          vIdx++;
        }
      }
      provider.setCachedParagraphGrouping(
        book: tgt.book,
        chapter: tgt.chapter,
        paragraphMode: settings.paragraphMode,
        versesLength: verses.length,
        groups: paragraphGroups,
        verseToItem: vToI,
        itemToVerseIndex: iToV,
      );
    }
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

    // 2026-05-19 (v1.2.58): switched from `sanitizeForSearch` to
    // `sanitizeForCopy` so v1.2.57's internal `\n` poetry line
    // breaks (LJK2 OT-quote verses) don't leak into the copied
    // clipboard text and split one verse across multiple lines
    // inside an otherwise inline format. `sanitizeForCopy`
    // replaces `\n` → ' ' but keeps `{phrase}` + `[supplied]`
    // content the same way the search variant does.
    switch (settings.copyFormat) {
      case 'withRef':
        return sorted
            .map((v) =>
                '[${v.book} ${v.chapter}:${v.verseLabel}] ${sanitizeForCopy(v.text)}')
            .join('\n');
      case 'devotional':
        // 2026-05-17 (v1.2.48): join with a single space, not '\n'.
        // 灵修 / 抄经 style flows the verses as ONE continuous
        // paragraph rather than one-verse-per-line. User report:
        // "灵修模式不是一节一行而是全部都一起的". Settings preview
        // mirrors this in getDevotionalFormattedText().
        final versesText =
            sorted.map((v) => sanitizeForCopy(v.text)).join(' ');
        final range = _formatVerseRangeLabels(sorted);
        return '$versesText\n(${first.book} ${first.chapter}:$range)';
      case 'plain':
      default:
        final body = sorted
            .map((v) => '${v.verseLabel} ${sanitizeForCopy(v.text)}')
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
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
    final ok = await ClipboardHelper.copyText(payload);
    if (!context.mounted) return;
    // 2026-06-30: dismiss the verse-selection bottom bar after Share,
    // matching Copy (_copySelectedVerses) — the action is done, so the
    // selection + its action menu should clear. The toast below is an
    // overlay and still shows the confirmation.
    // 2026-07-07: only on SUCCESS — a failed clipboard write keeps the
    // selection so the user can retry with one tap instead of
    // re-long-pressing every verse.
    if (ok) mainProvider.clearSelectedVerses();
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
    // 2026-07-10: copyText never throws (prod copy_fail crash on iOS
    // Safari). Only clear the selection on success so a failed copy
    // can be retried with one tap.
    final ok = await ClipboardHelper.copyText(text);
    if (ok) mainProvider.clearSelectedVerses();
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final label = ok
        ? (uiStrings['copied']?[settings.locale] ?? 'Copied!')
        : (uiStrings['shareLinkFailed']?[settings.locale] ??
            'Copy failed — clipboard unavailable');
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ok ? scheme.onPrimary : scheme.onError,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: ok
            ? scheme.primary.withValues(alpha: 0.8)
            : scheme.error,
        duration: Duration(milliseconds: ok ? 800 : 1800),
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

        // 2026-07-21 PERF: this used to be a full
        // `mainProvider.verses.where(...).toList()..sort(...)` — an
        // O(31k) filter + sort re-run on EVERY notifyListeners of
        // either provider, because this Consumer2 wraps the whole
        // pane. Verse taps, highlights, note saves, bookmark
        // changes — each paid the full-corpus scan before anything
        // painted, measured as ~90-100 ms tap→paint latency via the
        // Event Timing API on the live site. `versesInChapter` is
        // the provider's (book|chapter)-keyed index: O(1) lookup,
        // pre-sorted, invalidated on version switch by both
        // setVerses and useCachedVersion. The returned list is the
        // cache's own — every use below is read-only; do NOT mutate
        // it here.
        final verses = (mainProvider.currentBook != null &&
                mainProvider.currentChapter != null)
            ? mainProvider.versesInChapter(
                mainProvider.currentBook!, mainProvider.currentChapter!)
            : const <Verse>[];
        // ignore: unused_local_variable
        final hasParagraphData =
            verses.any((v) => v.isParagraphStart == true);

        // 2026-05-08 (v1.0.1 perf): paragraph grouping + index maps
        // are stable for a given (book, chapter, paragraphMode,
        // verses-length) tuple. Provider-level cache keeps us from
        // recomputing them on every Consumer rebuild — highlights /
        // bookmarks / scroll updates trigger notifyListeners many
        // times per second; before the cache, each one re-grouped
        // ~140 verses + rebuilt two int→int maps.
        final cachedGrouping = mainProvider.cachedParagraphGrouping(
          book: mainProvider.currentBook,
          chapter: mainProvider.currentChapter,
          paragraphMode: settings.paragraphMode,
          versesLength: verses.length,
        );

        late final List<List<Verse>> paragraphGroups;
        late final Map<int, int> verseToItemMap;
        late final Map<int, int> itemToVerseIndex;
        if (cachedGrouping != null) {
          paragraphGroups = cachedGrouping.groups;
          verseToItemMap = cachedGrouping.verseToItem;
          itemToVerseIndex = cachedGrouping.itemToVerseIndex;
        } else {
          paragraphGroups = settings.paragraphMode
              ? _groupIntoParagraphs(verses)
              : verses.map((v) => [v]).toList();
          final vToI = <int, int>{};
          final iToV = <int, int>{0: 0};
          int vIdx = 0;
          for (int g = 0; g < paragraphGroups.length; g++) {
            iToV[g + 1] = vIdx;
            for (int v = 0; v < paragraphGroups[g].length; v++) {
              vToI[vIdx] = g + 1;
              vIdx++;
            }
          }
          verseToItemMap = vToI;
          itemToVerseIndex = iToV;
          mainProvider.setCachedParagraphGrouping(
            book: mainProvider.currentBook,
            chapter: mainProvider.currentChapter,
            paragraphMode: settings.paragraphMode,
            versesLength: verses.length,
            groups: paragraphGroups,
            verseToItem: verseToItemMap,
            itemToVerseIndex: itemToVerseIndex,
          );
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
            if (!mounted) {
              debugPrint('[YsWords jump] post-frame bail: !mounted');
              return;
            }
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
            if (route != null && !route.isCurrent) {
              debugPrint('[YsWords jump] post-frame bail: '
                  '!route.isCurrent (older HomePage in stack)');
              return;
            }

            final mp = context.read<MainProvider>();
            final pendingIdx = mp.consumePendingJump();
            if (pendingIdx == null) {
              debugPrint('[YsWords jump] post-frame bail: '
                  'consumePendingJump returned null (already consumed)');
              return;
            }
            // Defensive clamp: a stale pending jump from a
            // different chapter could land out-of-range.
            if (pendingIdx < 0 || pendingIdx >= verses.length) {
              debugPrint('[YsWords jump] post-frame bail: '
                  'pendingIdx=$pendingIdx out of range '
                  '[0, ${verses.length})');
              return;
            }
            // Wait for the controller to attach AND for the SPL
            // to have finished its first layout pass. On a fresh
            // HomePage mount the controller can be `isAttached`
            // before the items are measured, so a `jumpTo` would
            // silently land at index 0. Use `scrollTo` (not
            // `jumpTo`) with a 1 ms duration — SPL handles the
            // not-fully-laid-out case more gracefully than
            // `jumpTo`. Plus widen the poll budget to 3 s
            // (60 × 50 ms) for slow-cold-start cases.
            // 2026-05-17 (v1.2.49 + v1.2.50): search / library /
            // news / evidence "jump to verse" flow renders the
            // target verse identical to a hand-selected one
            // (primaryContainer wash). 350 ms smooth scroll +
            // alignment 0.25 (target lands ~25 % from top so the
            // surrounding verses stay visible). Highlight clears
            // after 3.5 s — long enough for the user to orient,
            // short enough that the verse goes back to normal
            // when they start reading.
            //
            // v1.2.50 added a forensic `debugPrint` chain so users
            // who still report problems can paste the browser
            // console output. Each step logs whether it ran or
            // bailed.
            debugPrint('[YsWords jump] pendingIdx=$pendingIdx '
                'verses.length=${verses.length} '
                'currentBook=${mainProvider.currentBook} '
                'currentChapter=${mainProvider.currentChapter}');
            void tryJump([int attempt = 0]) {
              if (!mounted) {
                debugPrint('[YsWords jump] bail: !mounted (attempt $attempt)');
                return;
              }
              if (mp.itemScrollController.isAttached) {
                try {
                  mp.scrollToIndexAnimated(
                    index: pendingIdx,
                    duration: const Duration(milliseconds: 350),
                    // 2026-05-24 (v1.2.95): user "现在只是到那一章
                    // 而不是相关节，跳转没有" — alignment 0.25 was
                    // landing the target verse near the top, which
                    // visually looks like "just opened the chapter".
                    // Bumped to 0.38 so the verse sits well inside
                    // the viewport (with context above and below)
                    // and the highlight is obviously on a specific
                    // verse, not the chapter as a whole.
                    alignment: 0.38,
                  );
                  // 2026-05-24 (v1.2.95): defensive second-pass scroll
                  // 380 ms later. With v1.2.94's PageView wrapping
                  // the SPL, the chapter rebuild can race with the
                  // first scroll — the SPL's layout pass and the
                  // scroll request overlap and the verse ends up
                  // off-target. A re-scroll after the rebuild
                  // settles guarantees the final position is right.
                  Future.delayed(const Duration(milliseconds: 380), () {
                    if (!mounted) return;
                    if (!mp.itemScrollController.isAttached) return;
                    try {
                      mp.scrollToIndexAnimated(
                        index: pendingIdx,
                        duration: const Duration(milliseconds: 200),
                        alignment: 0.38,
                      );
                    } catch (_) {/* harmless — already at target */}
                  });
                  debugPrint('[YsWords jump] scrolled to chapter-verse '
                      'index $pendingIdx (attempt $attempt)');
                } catch (e) {
                  debugPrint('[YsWords jump] scroll threw: $e '
                      '(attempt $attempt) — retrying');
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
                debugPrint('[YsWords jump] highlight set to $pendingIdx');
                Future.delayed(const Duration(milliseconds: 3500), () {
                  // Only clear if the highlight is still on OUR target —
                  // a subsequent jump (e.g. user navigated chapters) may
                  // have already overwritten it.
                  if (mp.highlightIndex == pendingIdx) {
                    mp.clearHighlightIndex();
                    debugPrint('[YsWords jump] highlight cleared');
                  }
                });
                return;
              }
              if (attempt > 60) {
                debugPrint('[YsWords jump] gave up after 60 attempts '
                    '— controller never attached');
                return;
              }
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
        // v1.3.16: `visibleItemIndex` / `chapterProgress` /
        // `visibleVerseIndex` derivations moved INTO the position
        // indicator's `ValueListenableBuilder` below (lines ~2050).
        // Items layout for reference (used by the inner builder):
        //   [chapter header(0), ...paragraphGroups, trailing spacer]
        // So valid item indices are 0 .. paragraphGroups.length + 1.

        return SelectionContainer.disabled(
          child: GestureDetector(
            // 2026-05-21 (v1.2.70): tap on empty area toggles the
            // auto-hide chrome. Verses absorb their own taps (selection
            // + popup), so this only fires on the margins / gaps.
            //
            // 2026-05-24 (v1.2.94): removed onHorizontalDragEnd —
            // the new 3-page PageView captures horizontal swipes
            // directly (see PageView.builder below), so the outer
            // gesture detector only needs the tap-to-toggle-chrome
            // affordance.
            behavior: HitTestBehavior.translucent,
            onTap: _toggleChrome,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              // 2026-05-22 (v1.2.71): full system-chrome theming —
              // status-bar text and the Android nav-bar icons follow
              // the app's brightness, and the nav-bar background
              // matches the new bottom-bar color (surfaceContainerHighest)
              // so the bottom-bar visually flows into the system gesture
              // pill area on iOS / 3-button nav on Android.
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.dark
                        : Brightness.light,
                statusBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
                systemNavigationBarColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    // v1.3.19: Shift+T (toggle TTS) removed with the
                    // rest of the 朗读 feature.
                    const SingleActivator(LogicalKeyboardKey.question,
                        shift: true): () =>
                        _showShortcutsHelp(context, settings.locale),
                    // 2026-05-24 (v1.3.17): macOS-native ⌘ shortcuts.
                    // Mac users expect Command-prefixed shortcuts for
                    // app-level actions; the bare `[` / `]` / `/`
                    // bindings above still work but Cmd variants
                    // surface in the macOS menu-bar habit. Each uses
                    // SingleActivator with `meta: true` so it maps to
                    // ⌘ on Mac and to Win/Super on Windows/Linux
                    // (where the Cmd convention isn't universal but
                    // doesn't conflict either).
                    const SingleActivator(LogicalKeyboardKey.bracketLeft,
                        meta: true): _goToPreviousChapter,
                    const SingleActivator(LogicalKeyboardKey.bracketRight,
                        meta: true): _goToNextChapter,
                    // ⌘F → search. The universal Mac/web convention.
                    const SingleActivator(LogicalKeyboardKey.keyF,
                        meta: true): () {
                      if (widget.showSearchAndSettings) {
                        Get.to(() => SearchPage(),
                            transition: Transition.rightToLeft);
                      }
                    },
                    // ⌘, → settings. Standard Mac "open Preferences"
                    // gesture for any well-behaved app.
                    const SingleActivator(LogicalKeyboardKey.comma,
                        meta: true): () {
                      if (widget.showSearchAndSettings) {
                        Get.to(() => const SettingsPage(),
                            transition: Transition.rightToLeft);
                      }
                    },
                    // Ctrl+ variants for Windows / Linux desktop users
                    // who don't have a Meta key. No-op on Mac because
                    // Ctrl+F there is line-start.
                    const SingleActivator(LogicalKeyboardKey.bracketLeft,
                        control: true): _goToPreviousChapter,
                    const SingleActivator(LogicalKeyboardKey.bracketRight,
                        control: true): _goToNextChapter,
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
                    // 2026-05-24 (v1.2.96): N-page chapter pager —
                    // one page per chapter in chapterList
                    // (~1189). Replaces the v1.2.94 3-page model,
                    // which needed an instant `jumpToPage(1)` to
                    // re-centre the SPL after every swipe. The
                    // jump broke the smooth book-flip feel; user
                    // reported "一松手，就马上跳动到那一章一瞬间".
                    //
                    // With one page per chapter, PageController's
                    // index directly tracks the chapter — swipe
                    // settles ARE the chapter change, no jump.
                    // PageView.builder lazily builds + caches
                    // only the visible page and a couple
                    // neighbours so memory is bounded.
                    //
                    // The active page (idx ==
                    // _currentChapterPageIdx) renders the full
                    // SPL with mainProvider's controllers and
                    // full annotation features; neighbours
                    // render a lightweight preview while the user
                    // is dragging towards them. After settle the
                    // newly-active page rebuilds as the SPL —
                    // visually the preview → SPL swap happens at
                    // the same screen position so there is no
                    // visible snap.
                    //
                    // External chapter changes (pendingJump from
                    // search, library tile, etc.) flow through
                    // the build-time sync block above which
                    // animates the PageController to the new
                    // page when currentChapter shifts outside of
                    // a user swipe.
                    // 2026-05-24 (v1.3.3): NotificationListener at
                    // the PageView level captures scroll deltas
                    // from ANY child SPL (via bubble-up) so the
                    // auto-hide chrome works regardless of which
                    // _ChapterPage is currently visible. v1.2.71
                    // had this wrapping the single inline SPL —
                    // now we need it outside the PageView so it
                    // catches scrolls from all alive _ChapterPage
                    // instances.
                    NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child:
                    Builder(builder: (pageBuildCtx) {
                      final chapterList = mainProvider.chapterList;
                      final currentChapterPageIdx =
                          mainProvider.findChapterIndex(
                                  mainProvider.currentBook,
                                  mainProvider.currentChapter) ??
                              0;
                      // 2026-05-24 (v1.2.98): sync only on
                      // EXTERNAL chapter changes. v1.2.96 fired
                      // on every build where `controllerPage !=
                      // currentChapterPageIdx`, which during a
                      // mid-swipe is constantly true (controller
                      // is interpolating between pages, provider
                      // still on the old chapter until settle) —
                      // it scheduled a `jumpToPage(oldChapter)`
                      // that fought the gesture and landed as a
                      // visible snap. User: "翻页还是卡顿一下".
                      //
                      // Gate on `_lastSyncedChapterIdx` so we
                      // act exactly once per actual chapter
                      // change. Builds triggered by anything
                      // OTHER than a chapter change (selection,
                      // highlight, font setting, etc.) become
                      // no-ops for the PageController.
                      if (_lastSyncedChapterIdx != currentChapterPageIdx) {
                        final previousSynced = _lastSyncedChapterIdx;
                        _lastSyncedChapterIdx = currentChapterPageIdx;
                        if (previousSynced != null &&
                            !_pageSwipeInFlight &&
                            _pageController.hasClients) {
                          final controllerPage =
                              _pageController.page?.round();
                          if (controllerPage != null &&
                              controllerPage != currentChapterPageIdx) {
                            // Genuine external change — the
                            // provider's chapter shifted while
                            // the controller is on a different
                            // page. Animate over so the user
                            // sees the transition smoothly
                            // (jumpToPage would be jarring for
                            // a jump triggered by tapping a
                            // search result).
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (!mounted) return;
                              if (!_pageController.hasClients) return;
                              if (_pageSwipeInFlight) return;
                              final delta = (controllerPage -
                                      currentChapterPageIdx)
                                  .abs();
                              if (delta > 3) {
                                // Big jump (e.g. Gen 1 → John 3):
                                // animation would scroll through
                                // hundreds of pages — just jump.
                                _pageController
                                    .jumpToPage(currentChapterPageIdx);
                              } else {
                                _pageController.animateToPage(
                                  currentChapterPageIdx,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          }
                        }
                      }
                      return PageView.builder(
                      controller: _pageController,
                      itemCount: chapterList.length,
                      physics: const PageScrollPhysics(),
                      onPageChanged: (idx) {
                        // Idx is the chapter's index in
                        // chapterList. Translate to (book,
                        // chapter) and update provider. No
                        // jumpToPage needed — the page IS the
                        // new current chapter.
                        if (idx < 0 || idx >= chapterList.length) {
                          return;
                        }
                        if (idx == currentChapterPageIdx) return;
                        // v1.3.17: light haptic on chapter-swipe
                        // commit — iOS Taptic Engine confirms the
                        // page-snap; Android vibrator pulse.
                        hapticLight();
                        _pageSwipeInFlight = true;
                        final tgt = chapterList[idx];
                        final provider =
                            context.read<MainProvider>();
                        provider.clearSelectedVerses();
                        provider.clearHighlightIndex();
                        _switchTo(provider, tgt.book, tgt.chapter);
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) {
                          _pageSwipeInFlight = false;
                        });
                      },
                      itemBuilder: (pageCtx, pageIdx) {
                        if (pageIdx < 0 ||
                            pageIdx >= chapterList.length) {
                          return const SizedBox.shrink();
                        }
                        final tgt = chapterList[pageIdx];
                        // 2026-05-24 (v1.3.3): EVERY page is now a
                        // `_ChapterPage` — same widget type at every
                        // index. Adjacent pages stay alive via
                        // AutomaticKeepAliveClientMixin; the
                        // preview ↔ SPL widget-tree swap is gone.
                        // Only the active page's controllers feed
                        // back into mp; inactive pages render their
                        // own SPL with local controllers so scroll
                        // position survives the swipe round-trip.
                        // ValueKey on (book|chapter) lets the
                        // PageView cache identify each page
                        // canonically across version switches /
                        // chapterList rebuilds.
                        return _ChapterPage(
                          key: ValueKey(
                              '${tgt.book}|${tgt.chapter}'),
                          book: tgt.book,
                          chapter: tgt.chapter,
                          isActive: pageIdx == currentChapterPageIdx,
                          deviceClass: dc,
                        );
                      },
                    );
                    }),
                    ),
                    // 2026-05-24 (v1.2.91 + v1.3.32): mini reader
                    // header. When the auto-hide chrome is hidden,
                    // show a tiny pair of pills at top — version on
                    // left, book + chapter on right — so the reader
                    // always knows their bearings. In split view the
                    // full header is pinned visible, so the mini
                    // stays hidden.
                    //
                    // v1.3.32: tap target now SCROLLS TO TOP of the
                    // chapter AND re-shows the chrome (user-reported
                    // "为什么top tap 不go back to top"). The combined
                    // action is intuitive — user expects "tap top" to
                    // return to chapter beginning, and bringing the
                    // full header back is a natural side-effect since
                    // they've signalled they want to navigate. Chrome
                    // can still be toggled by tapping verse content.
                    if (currentVerse != null && !widget.splitViewActive)
                      _MiniReaderHeader(
                        visible: !_chromeVisible,
                        version: mainProvider.currentVersion,
                        book: currentVerse.book,
                        chapter: currentVerse.chapter,
                        locale: settings.locale,
                        onTap: () {
                          _scrollChapterToTop();
                          if (!_chromeVisible) _toggleChrome();
                        },
                      ),
                    // 2026-05-24 (v1.3.8 / v1.3.34): cross-platform
                    // tap-top → scroll-to-top. iOS's system status-bar
                    // tap only auto-wires when a Scaffold has a
                    // primary AppBar driving a PrimaryScrollController;
                    // our reader uses a custom Positioned _FloatingHeader
                    // + ScrollablePositionedList (its own ItemScroll-
                    // Controller, NOT a PrimaryScrollController), so
                    // neither iOS nor Android get the feature for free.
                    //
                    // v1.3.34 fix: user reported "按了顶部没反应". Root
                    // cause was the previous strip height of
                    // `topInset.clamp(20, 64)` — on iPhone 16 Pro Max
                    // / 15 Pro / 14 Pro that's ~59 px which exactly
                    // covers the Dynamic Island. iOS reserves the
                    // Island for system gestures (long-press = expand,
                    // short tap = often swallowed by the system), so
                    // taps on that zone never reach the Flutter app.
                    //
                    // Three changes to make tap-top reliably work:
                    //   (1) Enlarge the strip to `topInset + 56` —
                    //       extends down past the Dynamic Island into
                    //       the mini-header chip row, so a tap
                    //       anywhere in the top band (not just on the
                    //       Island) lands on the strip.
                    //   (2) Switch from `translucent` to `opaque` — the
                    //       translucent variant put the strip into a
                    //       three-way gesture arena (strip + mini-
                    //       header + outer chrome-toggle GestureDetector
                    //       at line ~1320) where one of the others
                    //       could win and call _toggleChrome instead
                    //       of _scrollChapterToTop. Opaque wins
                    //       definitively for any tap in the strip's
                    //       bounding box.
                    //   (3) Combine actions: scroll-to-top + show
                    //       chrome. Convention: "I'm at the top, here
                    //       are the navigation controls".
                    if (currentVerse != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height:
                            MediaQuery.of(context).padding.top + 56,
                        // 2026-05-24 (v1.3.35): wrap the tap-strip in
                        // IgnorePointer that disables it when chrome
                        // is visible. Without this gate, the strip's
                        // opaque GestureDetector covered the chrome's
                        // top region (status-bar inset + chip row =
                        // topInset+56 px) and stole taps that should
                        // have gone to the back-arrow / version / book
                        // / search / home / 3-dot buttons inside
                        // _FloatingHeader. User report: "iOS top menu
                        // 里面所有menu都按不动了".
                        //
                        // When chrome is hidden the mini-header chips
                        // are decorative + the strip is the only thing
                        // in that band — it should be live so users
                        // can tap-top to scroll. When chrome is shown
                        // the FloatingHeader's buttons need first dibs
                        // on every tap in the top band.
                        child: IgnorePointer(
                          ignoring: _chromeVisible,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _scrollChapterToTop();
                              if (_chromeFeatureEnabled &&
                                  !_chromeVisible) {
                                _safeChromeSetState(
                                    () => _chromeVisible = true);
                              }
                            },
                          ),
                        ),
                      ),
                    _FloatingHeader(
                      // 2026-05-22 (v1.2.71): pin chrome visible in
                      // split view. Each pane's _FloatingHeader is
                      // Positioned(top:0) RELATIVE to its own Stack
                      // — in top/bottom split, the bottom pane's
                      // header sits at the middle of the screen, and
                      // the auto-hide animation made it appear to
                      // "jump around" near the bottom half. With
                      // chrome pinned, both panes' headers stay
                      // static.
                      chromeVisible:
                          widget.splitViewActive ? true : _chromeVisible,
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
                        // 2026-05-10 (v1.2.13): rewritten end-to-end
                        // per user feedback "整本圣经 change version
                        // loading 很久，不用 keepnstate 了，快一点".
                        //
                        // OLD flow had two problems:
                        //   1. The snackbar showed "Loading…" but the
                        //      reading pane kept rendering the OLD
                        //      version's verses, frozen, for the
                        //      1–3 s of synchronous json.decode. To
                        //      the user: "screen looks broken for a
                        //      bit, then suddenly switches".
                        //   2. We tried to preserve the user's
                        //      chapter-relative verse number across
                        //      the switch (`_captureChapterRelative
                        //      VerseNum` + `_scrollToVerseInChapter`)
                        //      which adds layout-measurement work
                        //      AND complexity for marginal benefit
                        //      — the user said outright "不用 keep
                        //      state 了".
                        //
                        // NEW flow:
                        //   • Set `versionSwitching = true` IMMED-
                        //     IATELY → the reading pane stack paints
                        //     an opaque overlay over the old verses
                        //     (see build() below). User sees a clean
                        //     loading screen, not frozen text.
                        //   • Skip _captureChapterRelativeVerseNum.
                        //   • Skip _scrollToVerseInChapter — the
                        //     chapter-level reset (jumpToTop after
                        //     setCurrentChapter) lands the user at
                        //     the top of the same chapter in the
                        //     new version. Same passage, just no
                        //     verse-precise scroll restore.
                        //   • Clear flag at the end so overlay goes
                        //     away.
                        if (!mounted) return;
                        final p = context.read<MainProvider>();
                        final messenger = _messengerKey.currentState;
                        p.clearSelectedVerses();
                        final prevVersion = p.currentVersion;
                        final prevEn = toEnglish(p.currentBook);
                        // 2026-05-10 (v1.2.14): instant-switch path.
                        // If we already have this version's parsed
                        // verses in MainProvider's per-version LRU
                        // cache (populated whenever setVerses fires
                        // with a non-empty list), skip the entire
                        // json.decode + FetchVerses pipeline and
                        // just swap the verse list in. No overlay,
                        // no spinner, no yield, ~0 ms wall-clock.
                        // This is what makes "back to a previously-
                        // visited version" truly "一瞬间" (instant)
                        // — the user's expected behaviour that
                        // v1.2.13's overlay made feel slower than
                        // it should.
                        if (p.useCachedVersion(version)) {
                          // Books are derived from verses; rebuild
                          // them (pure in-memory, fast). No overlay
                          // because this whole branch should be
                          // imperceptible.
                          await FetchBooks.execute(mainProvider: p);
                          if (!mounted) return;
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
                              book: match.book,
                              chapter: match.chapter);
                          p.updateCurrentVerse(verse: match);
                          p.jumpToTop();
                          if (mounted) _visibleItemIndexNotifier.value = 0;
                          // Canon may have resized (e.g. LJK NT-only →
                          // full): force the PageView onto the new
                          // chapter so it doesn't stay on a stale page.
                          _reanchorPageForVersionSwitch(p);
                          return;
                        }
                        // Slow path (cache miss): show overlay then
                        // run the full parse pipeline.
                        // Lookup the target version's short label so
                        // the overlay can show "Loading KJV…" instead
                        // of the generic "Loading version…".
                        final destLabel = bibleVersions
                            .firstWhere(
                              (v) => v.value == version,
                              orElse: () => const BibleVersionInfo(
                                  value: '',
                                  shortLabel: '',
                                  menuLabel: '',
                                  language: 'zh-Hans'),
                            )
                            .shortLabel;
                        p.setVersionSwitching(true, to: destLabel);
                        // Yield once so the overlay actually paints
                        // before we kick off the heavy json.decode
                        // that blocks the main thread for 1–3 s.
                        await Future<void>.delayed(Duration.zero);
                        try {
                          p.setVersion(version);
                          await FetchVerses.execute(mainProvider: p);
                          if (!mounted) return;
                          await FetchBooks.execute(mainProvider: p);
                          if (!mounted) return;
                          // Failure-recovery: revert to previous
                          // version so the user keeps reading what
                          // they had instead of getting an empty
                          // shell.
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
                          // Land on the same chapter in the new
                          // version (book name translated, chapter
                          // number reused). Top-of-chapter scroll —
                          // no verse-precise restore.
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
                          if (mounted) _visibleItemIndexNotifier.value = 0;
                          // Canon may have resized (e.g. LJK NT-only →
                          // full): force the PageView onto the new
                          // chapter so it doesn't stay on a stale page.
                          _reanchorPageForVersionSwitch(p);
                        } finally {
                          // Always clear the flag so the overlay
                          // disappears even on error.
                          if (mounted) {
                            p.setVersionSwitching(false);
                          }
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
                      // 2026-05-24 (v1.3.19): TTS feature removed —
                      // no more `onToggleListen` / `isListening` wiring.
                      // 2026-05-21 (v1.2.69): TodayReadingCard removed
                      // along with the rest of the reading-plan feature.
                      belowHeader: null,
                    ),
                    // Vertical position indicator on the right edge — a
                    // thin track + a small "current/total" pill that
                    // slides top-to-bottom as the user reads, then
                    // auto-fades after 2 s of inactivity. Kept visible
                    // during verse selection too — hiding it here was
                    // bundled onto the same `isSelected` check the
                    // bottom-bar swap needed, not a deliberate choice.
                    // Extra bottom clearance while selected: on narrow
                    // phones _SelectionActionBar wraps to two rows
                    // (taller than the single-row chrome bar it
                    // replaces), so the pill needs more room to clear it.
                    if (verses.isNotEmpty)
                      Positioned(
                        right: ResponsiveBreakpoints.headerInset(dc) + 4,
                        top: MediaQuery.of(context).padding.top +
                            64 * settings.menuScale +
                            24,
                        bottom: MediaQuery.of(context).padding.bottom +
                            (isSelected ? 100 : 56),
                        child: IgnorePointer(
                          // v1.3.16: nested ValueListenableBuilders so
                          // scroll-tick updates only rebuild THIS
                          // subtree (the right-edge position pill),
                          // not the whole pane. Outer listens to the
                          // visible-item index → derives chapter
                          // progress + label. Inner listens to the
                          // show-position bool → drives AnimatedOpacity.
                          child: ValueListenableBuilder<double>(
                            valueListenable: _visibleItemPosNotifier,
                            builder: (context, itemPos, _) =>
                                ValueListenableBuilder<double>(
                            valueListenable: _chapterProgressNotifier,
                            builder: (context, chapterProgress, _) {
                              // 2026-06-28 (v1.3.110): BAR + NUMBER decoupled.
                              //  • BAR = PIXEL-proportional scroll fraction,
                              //    precomputed in _handleItemPositionsChanged
                              //    from measured item heights → even with the
                              //    page length in paragraph AND verse mode,
                              //    0% at top, 100% at the bottom, no jump.
                              //  • NUMBER = the verse at the TOP of the screen.
                              // Keep the active chapter's item count fresh for
                              // the pixel estimator (header + groups + footer).
                              _progressItemCount = paragraphGroups.length + 2;
                              final displayVerseIndex =
                                  paragraphCurrentVerseIndex(
                                itemPos: itemPos,
                                itemToVerseIndex: itemToVerseIndex,
                                groupCount: paragraphGroups.length,
                                totalVerses: verses.length,
                              );
                              return ValueListenableBuilder<bool>(
                                valueListenable: _showVersePositionNotifier,
                                builder: (context, showPos, _) => AnimatedOpacity(
                                  opacity: showPos ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 400),
                                  child: _VerticalProgressIndicator(
                                    progress: chapterProgress,
                                    currentLabel: '${displayVerseIndex + 1}',
                                    totalLabel: '${verses.length}',
                                    fontFamily: settings.fontFamily,
                                    menuScale: settings.menuScale,
                                  ),
                                ),
                              );
                            },
                          )),
                        ),
                      ),
                    // 2026-05-21 (v1.2.70 hotfix): bottom bar hidden in
                    // split-view to avoid the grey-screen layout glitch
                    // when two Positioned(left:0,right:0) bars co-exist
                    // inside narrow SizedBox-constrained panes. The
                    // primary pane's top header still works for nav;
                    // we'll restore the bottom bar in split view once
                    // the layout interaction is understood.
                    if (_chromeFeatureEnabled &&
                        !isSelected &&
                        !widget.splitViewActive &&
                        verses.isNotEmpty)
                      _BibleReaderBottomBar(
                        visible: _chromeVisible,
                        deviceClass: dc,
                        locale: settings.locale,
                        onPrevChapter: _goToPreviousChapter,
                        onNextChapter: _goToNextChapter,
                        onOpenNotes: () {
                          mainProvider.clearSelectedVerses();
                          Get.to(
                            () => const LibraryPage(),
                            transition: Transition.rightToLeft,
                          );
                        },
                        onOpenIllustrations: (_chapterMaps.isEmpty &&
                                _bookMaps.isEmpty)
                            ? null
                            : () => _showMapPicker(
                                  context,
                                  chapterMaps: _chapterMaps,
                                  bookMaps: _bookMaps,
                                  locale: settings.locale,
                                ),
                        onFontSize: () => _showFontSizeSheet(context, settings),
                        paragraphMode: settings.paragraphMode,
                        onToggleParagraphMode: () => settings
                            .setParagraphMode(!settings.paragraphMode),
                      ),
                    // Bottom bar — selection actions only. (v1.2.69:
                    // the always-visible reader-progress bar was
                    // removed; chapter progress is still visible via
                    // the right-edge pill that fades in while scrolling.)
                    //
                    // 2026-05-24 (v1.2.91): switched from
                    // Align(bottomCenter) → Positioned(bottom/left/
                    // right: 0) so the bar is anchored to the screen
                    // edge edge-to-edge instead of floating with
                    // horizontal margins. Matches the always-visible
                    // bottom chrome bar's shape — feels like a real
                    // bottom menu rather than an overlay card.
                    if (isSelected)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _SelectionActionBar(
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
                              onAiExplain: () => _showAiExplainSheet(
                                context: context,
                                verses: mainProvider.selectedVerses,
                                settings: settings,
                                mainProvider: mainProvider,
                              ),
                              anyNoted: mainProvider.selectedVerses
                                  .any(mainProvider.isVerseNoted),
                              anyBookmarked: mainProvider.selectedVerses
                                  .any(mainProvider.isBookmarked),
                              // 2026-05-19 (v1.2.60): pass the FULL
                              // selection list (sorted by chapter +
                              // verse) instead of just the first verse.
                              // Multi-verse notes share text across the
                              // whole range — WeDevote-style. Single
                              // selection still works the same way; the
                              // editor handles both cases uniformly.
                              onNote: () => showNoteEditor(
                                context: context,
                                verses:
                                    mainProvider.selectedVerses.toList()
                                      ..sort((a, b) {
                                        if (a.chapter != b.chapter) {
                                          return a.chapter.compareTo(b.chapter);
                                        }
                                        return a.verse.compareTo(b.verse);
                                      }),
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
                            ),
                      ),
                    // 2026-05-24 (v1.2.91 / v1.3.34 / v1.3.35): iOS-style
                    // tap-top to scroll-to-top, this time inside the
                    // verse-select toolbar overlay. v1.3.34 fix
                    // mirrors the main reader strip above
                    // (line ~1657): enlarged from
                    // `topInset.clamp(20, 80)` to `topInset + 56` so
                    // taps below the Dynamic Island (where iOS
                    // actually forwards them to the app) still hit
                    // the strip. v1.3.35: gated by IgnorePointer so
                    // it doesn't steal taps from the FloatingHeader
                    // buttons when chrome is visible.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height:
                          MediaQuery.of(context).padding.top + 56,
                      child: IgnorePointer(
                        ignoring: _chromeVisible,
                        child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!mainProvider
                              .itemScrollController.isAttached) {
                            return;
                          }
                          mainProvider.itemScrollController.scrollTo(
                            index: 0,
                            duration:
                                const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                      ),
                    ),
                    // 2026-05-10 (v1.2.13): version-switch loading
                    // overlay. Painted on top of everything in the
                    // Stack while `MainProvider.versionSwitching`
                    // is true. Opaque background so the user
                    // doesn't see the OLD version's verses frozen
                    // for the 1–3 s of synchronous json.decode
                    // chewing through the new version's 5–10 MB
                    // JSON. Background uses scaffold colour so
                    // it blends with the surrounding chrome and
                    // looks like an intentional loading state,
                    // not a glitch.
                    if (mainProvider.versionSwitching)
                      Positioned.fill(
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  mainProvider.versionSwitchingTo
                                          .isNotEmpty
                                      ? '${uiStrings['loadingVersion']?[settings.locale] ?? 'Loading version'} · ${mainProvider.versionSwitchingTo}'
                                      : (uiStrings['loadingVersion']
                                              ?[settings.locale] ??
                                          'Loading version…'),
                                  style: TextStyle(
                                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                    fontSize: settings.fontSize * 0.95,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;

  /// 2026-05-21 (v1.2.70): when true, render a fully-opaque surface
  /// (no blur, alpha 1.0) so the bar visually COVERS the content
  /// behind it instead of letting verses bleed through.
  final bool opaque;

  /// 2026-05-21 (v1.2.70): when true, only the top corners are
  /// rounded — the bottom is flush. Used by the auto-hide bottom bar
  /// so its surface meets the screen edge cleanly (no rounded curve
  /// + gap between the bar and the home indicator).
  final bool topRoundedOnly;

  /// 2026-05-22 (v1.2.71): mirror of [topRoundedOnly] for the top
  /// auto-hide chrome. Only the BOTTOM corners are rounded — the top
  /// is flush, so the surface meets the very top edge of the screen
  /// (covering the status-bar / notch area) with no visible gap.
  final bool bottomRoundedOnly;

  const _GlassSurface({
    required this.child,
    this.radius = 20,
    this.opaque = false,
    this.topRoundedOnly = false,
    this.bottomRoundedOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillAlpha =
        opaque ? 1.0 : (isDark ? 0.72 : 0.78);
    // 2026-05-22 (v1.2.71): when opaque, use surfaceContainerHighest
    // (Material 3's deepest-tinted variant) so the chrome bar reads
    // as a clear visual layer — most distinct from the scaffold
    // background while still feeling like part of the surface family.
    final fillColor = opaque
        ? scheme.surfaceContainerHighest
        : scheme.surface.withValues(alpha: fillAlpha);
    final br = topRoundedOnly
        ? BorderRadius.only(
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          )
        : bottomRoundedOnly
            ? BorderRadius.only(
                bottomLeft: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              )
            : BorderRadius.circular(radius);
    final outlineColor =
        scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6);
    // 2026-05-22 (v1.2.71): bolder hairline on the chrome bars so they
    // read as distinct strips against the body. Half-rounded variants
    // (topRoundedOnly / bottomRoundedOnly) are the chrome bars; full-
    // rounded (selection bar) keeps the subtle outline.
    final chromeHairlineColor =
        scheme.outline.withValues(alpha: isDark ? 0.45 : 0.55);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: br,
        // v1.3.x: half-rounded chrome bars previously used a single
        // directional Border side (top / bottom). A non-uniform border
        // combined with `borderRadius: br` throws "A borderRadius can
        // only be given on borders with uniform colors" in Border.paint
        // (the InkDecoration.paintFeature crash family). Use a uniform
        // thin outline — visually near-identical on a bar that's flush
        // to a screen edge, and legal alongside a borderRadius.
        border: (topRoundedOnly || bottomRoundedOnly)
            ? Border.all(color: chromeHairlineColor, width: 0.6)
            : Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color:
                scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 24,
            offset: topRoundedOnly
                // Cast the shadow UPWARDS for a bottom-anchored bar so
                // it visually lifts off the verses behind it.
                ? const Offset(0, -6)
                : bottomRoundedOnly
                    // Cast the shadow DOWNWARDS for a top-anchored bar.
                    ? const Offset(0, 6)
                    : const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (opaque) {
      // Skip the BackdropFilter when fully opaque — the blur would be
      // wasted work and on web it can cause noticeable text shimmer
      // on the verses scrolling behind.
      return ClipRRect(
        borderRadius: br,
        child: box,
      );
    }
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: box,
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
  /// v1.3.x: AI plain-language explanation of the selected verse(s),
  /// in the user's locale.
  final VoidCallback onAiExplain;
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
    required this.onAiExplain,
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
        // 2026-05-24 (v1.2.94): was VisualDensity.compact (~40 px)
        // which violates Apple HIG's 44 pt minimum. Standard density
        // keeps the bar a touch taller but every icon is reliably
        // tappable on phones.
        visualDensity: VisualDensity.standard,
      ),
      IconButton(
        tooltip: uiStrings['crossRefs']?[settings.locale] ??
            'Cross-references',
        onPressed: onCrossRefs,
        icon: const Icon(Icons.hub_outlined),
        // 2026-05-24 (v1.2.94): was VisualDensity.compact (~40 px)
        // which violates Apple HIG's 44 pt minimum. Standard density
        // keeps the bar a touch taller but every icon is reliably
        // tappable on phones.
        visualDensity: VisualDensity.standard,
      ),
      IconButton(
        tooltip: uiStrings['relatedSermons']?[settings.locale] ??
            'Related sermons',
        onPressed: onSermons,
        icon: const Icon(Icons.menu_book_outlined),
        // 2026-05-24 (v1.2.94): was VisualDensity.compact (~40 px)
        // which violates Apple HIG's 44 pt minimum. Standard density
        // keeps the bar a touch taller but every icon is reliably
        // tappable on phones.
        visualDensity: VisualDensity.standard,
      ),
      // v1.3.x: AI plain-language explanation of the selection.
      IconButton(
        tooltip:
            uiStrings['aiExplainVerse']?[settings.locale] ?? 'AI explain',
        onPressed: onAiExplain,
        icon: const Icon(Icons.auto_awesome),
        visualDensity: VisualDensity.standard,
      ),
      IconButton(
        tooltip: uiStrings['noteAdd']?[settings.locale] ?? 'Note',
        onPressed: onNote,
        icon: Icon(anyNoted
            ? Icons.sticky_note_2
            : Icons.sticky_note_2_outlined),
        color: anyNoted ? scheme.primary : null,
        // 2026-05-24 (v1.2.94): was VisualDensity.compact (~40 px)
        // which violates Apple HIG's 44 pt minimum. Standard density
        // keeps the bar a touch taller but every icon is reliably
        // tappable on phones.
        visualDensity: VisualDensity.standard,
      ),
      IconButton(
        tooltip: uiStrings['bookmark']?[settings.locale] ?? 'Bookmark',
        onPressed: onBookmark,
        icon: Icon(anyBookmarked
            ? Icons.bookmark_rounded
            : Icons.bookmark_outline_rounded),
        color: anyBookmarked ? scheme.primary : null,
        // 2026-05-24 (v1.2.94): was VisualDensity.compact (~40 px)
        // which violates Apple HIG's 44 pt minimum. Standard density
        // keeps the bar a touch taller but every icon is reliably
        // tappable on phones.
        visualDensity: VisualDensity.standard,
      ),
      IconButton(
        tooltip:
            uiStrings['highlight']?[settings.locale] ?? 'Highlight',
        onPressed: () => _showColorPicker(context),
        icon: const Icon(Icons.format_color_fill),
        // 2026-05-24 (v1.2.94): was VisualDensity.compact (~40 px)
        // which violates Apple HIG's 44 pt minimum. Standard density
        // keeps the bar a touch taller but every icon is reliably
        // tappable on phones.
        visualDensity: VisualDensity.standard,
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
        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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

    // 2026-05-24 (v1.2.91): bottom-menu style — edge-to-edge, only
    // top corners rounded, opaque. Was a floating Card-like bar
    // with horizontal margins + bottom padding (v1.2.70 design).
    // User feedback: "when clicking verse the floating should like
    // bottom menu as well not floating" — i.e. align with the same
    // shape as the always-visible bottom chrome bar.
    // The `inset` value is unused now (was driving the horizontal
    // padding before) — left in place for potential future tweaks.
    return _GlassSurface(
      radius: 22,
      opaque: true,
      topRoundedOnly: true,
      child: SafeArea(
        top: false,
        // Inner padding keeps the icons above the home indicator
        // even though the surface itself extends underneath.
        // Mirrors the structure of _BottomChromeBar so both bars
        // feel like one consistent piece of UI.
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12 * settings.menuScale + inset,
            6 * settings.menuScale,
            12 * settings.menuScale + inset,
            6 * settings.menuScale,
          ),
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
                      // v1.3.x: the action row grew to 7 icons (added
                      // AI explain). 7 × 48 px standard-density buttons
                      // overflow a ~320–340 dp phone, so make the row
                      // horizontally scrollable — it stays centered when
                      // everything fits and scrolls only when it can't.
                      // (spaceEvenly needs a bounded width, incompatible
                      // with a scroll view, so we center a min-width Row.)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            mainAxisSize: MainAxisSize.min,
                            children: actionButtons,
                          ),
                        ),
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

/// v1.3.x: AI plain-language explanation of the selected verse(s).
/// Gathers the selection's reference + text, then opens a bottom sheet
/// that calls the Gemini-backed `aiExplainWord` function in
/// `task: 'versePlain'` mode and renders the answer in the user's
/// locale. Reuses the same BYOK key + model tier as the word study.
void _showAiExplainSheet({
  required BuildContext context,
  required List<Verse> verses,
  required AppSettings settings,
  required MainProvider mainProvider,
}) {
  if (verses.isEmpty) return;
  // selectedVerses is already sorted by chapter+verse (see the note at
  // the _SelectionActionBar call site).
  final first = verses.first;
  final last = verses.last;
  final englishBook = bookNameToEnglish[first.book] ?? first.book;
  final verseStart = first.verse;
  final verseEnd = last.verse;
  // Combine the selected verse text with verse labels so the model
  // sees exactly what the reader is looking at.
  final buf = StringBuffer();
  for (final v in verses) {
    if (buf.isNotEmpty) buf.write(' ');
    buf.write('${v.verseLabel} ${v.text}');
  }
  var verseText = buf.toString().trim();
  if (verseText.length > 3500) verseText = '${verseText.substring(0, 3500)}…';
  final refLabel = verseEnd > verseStart
      ? '${first.book} ${first.chapter}:$verseStart-$verseEnd'
      : '${first.book} ${first.chapter}:$verseStart';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 1100),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => _AiExplainSheet(
      englishBook: englishBook,
      chapter: first.chapter,
      verseStart: verseStart,
      verseEnd: verseEnd,
      verseText: verseText,
      refLabel: refLabel,
      settings: settings,
      verses: verses,
      mainProvider: mainProvider,
    ),
  );
}

/// Bottom-sheet body for the AI verse explanation. Fires the request
/// on mount; shows a spinner, then the prose (or an error + retry).
class _AiExplainSheet extends StatefulWidget {
  const _AiExplainSheet({
    required this.englishBook,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.verseText,
    required this.refLabel,
    required this.settings,
    required this.verses,
    required this.mainProvider,
  });

  final String englishBook;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final String verseText;
  final String refLabel;
  final AppSettings settings;
  // v1.3.73: the selected verses + provider, so an answer can be saved
  // into the passage's note via showNoteEditor.
  final List<Verse> verses;
  final MainProvider mainProvider;

  @override
  State<_AiExplainSheet> createState() => _AiExplainSheetState();
}

/// v1.3.73: one turn in the AI study conversation. The opening turn has
/// a null [question] (the passage explanation); later turns carry the
/// reader's follow-up question.
class _AiTurn {
  _AiTurn({this.question});
  final String? question;
  String length = 'concise'; // 'concise' | 'default' | 'longer'
  String? answer;
  String? error;
  bool loading = true;
  String selectedText = ''; // live text selection within the answer
}

class _AiExplainSheetState extends State<_AiExplainSheet> {
  // v1.3.73: the panel is now a multi-turn study chat. Generation only
  // runs on user confirm (never on open); the input clears on success and
  // is restored only on failure; each answer can be regenerated shorter /
  // longer and saved (whole or just the selection) into the passage note.
  final List<_AiTurn> _turns = [];
  final TextEditingController _questionController = TextEditingController();
  final FocusNode _questionFocus = FocusNode();
  final ScrollController _bodyScroll = ScrollController();

  String get _loc => widget.settings.locale;
  bool get _busy => _turns.any((t) => t.loading);

  @override
  void dispose() {
    _questionController.dispose();
    _questionFocus.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  Future<AiWordResult> _request(
      {String? question, required String length, String? history}) {
    final key = widget.settings.geminiApiKey.trim();
    return AiWordService.explainVerse(
      englishBook: widget.englishBook,
      chapter: widget.chapter,
      verseStart: widget.verseStart,
      verseEnd: widget.verseEnd,
      verseText: widget.verseText,
      locale: widget.settings.locale,
      length: length,
      userApiKey: key.isEmpty ? null : key,
      aiModel: widget.settings.aiModel,
      userQuestion: question,
      history: history,
    );
  }

  // Compact transcript of completed turns before [upto], for follow-up
  // coherence. Tail-clamped so a long thread can't blow the prompt.
  String _historyBefore(int upto) {
    final buf = StringBuffer();
    for (var i = 0; i < upto && i < _turns.length; i++) {
      final t = _turns[i];
      final a = t.answer;
      if (a == null || a.isEmpty) continue;
      if (t.question != null && t.question!.isNotEmpty) {
        buf
          ..writeln('Q: ${t.question}')
          ..writeln('A: $a');
      } else {
        buf.writeln('Explanation: $a');
      }
    }
    var s = buf.toString().trim();
    const maxChars = 1800;
    if (s.length > maxChars) s = s.substring(s.length - maxChars);
    return s;
  }

  // Submit the input box. Empty ⇒ opening passage explanation (only when
  // there are no turns yet); otherwise a follow-up question.
  Future<void> _submit() async {
    if (_busy) return;
    final q = _questionController.text.trim();
    if (q.isEmpty && _turns.isNotEmpty) return; // need a question to follow up
    _questionFocus.unfocus();
    _questionController.clear(); // restored only if this turn fails
    final turn = _AiTurn(question: q.isEmpty ? null : q);
    setState(() => _turns.add(turn));
    _scrollBodyToEnd();
    await _runTurn(turn, restoreOnFail: q);
  }

  Future<void> _runTurn(_AiTurn turn, {String? restoreOnFail}) async {
    if (!mounted) return;
    final idx = _turns.indexOf(turn);
    final history = idx > 0 ? _historyBefore(idx) : '';
    setState(() {
      turn.loading = true;
      turn.error = null;
    });
    // The service layer now retries transient failures (503 "high demand" /
    // timeout / network) with backoff, so a redundant client-side cold-start
    // retry is no longer needed here. restoreOnFail is kept for call-site
    // compatibility but no longer used — the failed turn now stays on screen
    // with its question + an inline error instead of being removed.
    final result = await _request(
        question: turn.question,
        length: turn.length,
        history: history.isEmpty ? null : history);
    if (!mounted) return;
    setState(() {
      turn.loading = false;
      if (result.unavailable) {
        final reason = result.unavailableReason ??
            (uiStrings['aiExplainError']?[_loc] ??
                'AI explanation is not available right now.');
        // 2026-06-30 robustness: NEVER drop the turn on failure. If a good
        // answer already exists (a failed regenerate), keep it and toast the
        // reason; otherwise show a PERSISTENT inline error + Retry button —
        // for the OPENING explanation AND follow-up questions alike.
        // Previously a failed follow-up deleted the turn + showed only a
        // fleeting toast, so the question vanished with no visible reason
        // ("追问没回复"). Retry re-runs this same turn with its stored question.
        if (turn.answer != null) {
          _snack(reason);
        } else {
          turn.error = reason;
        }
      } else {
        turn.answer = cleanAiExplanation(result.explanation);
        turn.error = null;
      }
    });
    _scrollBodyToEnd();
  }

  String? _shorter(String length) =>
      length == 'longer' ? 'default' : (length == 'default' ? 'concise' : null);
  String? _longer(String length) =>
      length == 'concise' ? 'default' : (length == 'default' ? 'longer' : null);

  void _regenerate(_AiTurn turn, String length) {
    if (_busy) return;
    turn.length = length;
    _runTurn(turn);
  }

  void _snack(String msg) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _scrollBodyToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_bodyScroll.hasClients) return;
      _bodyScroll.animateTo(
        _bodyScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  // Save an answer (its current selection if any, else the whole thing)
  // into the passage note via the normal editor (append-to-existing).
  void _saveTurnToNote(_AiTurn turn) {
    final sel = turn.selectedText.trim();
    final text = sel.isNotEmpty ? sel : (turn.answer ?? '').trim();
    if (text.isEmpty) return;
    final attribution = uiStrings['aiNoteAttribution']?[_loc] ?? '— YsWords AI';
    final snippet = '「${widget.refLabel}」\n$text\n$attribution';
    showNoteEditor(
      context: context,
      verses: widget.verses,
      locale: _loc,
      mainProvider: widget.mainProvider,
      appendText: snippet,
    );
  }

  String _composeCopyText() {
    final buf = StringBuffer()..writeln(widget.refLabel);
    if (widget.verseText.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(widget.verseText);
    }
    for (final t in _turns) {
      final a = t.answer;
      if (a == null || a.isEmpty) continue;
      buf.writeln();
      if (t.question != null && t.question!.isNotEmpty) {
        buf
          ..writeln(
              '${uiStrings['aiAskYourQuestion']?[_loc] ?? 'Your question'}: ${t.question}')
          ..writeln();
      }
      buf.writeln(a);
    }
    return buf.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = _loc;
    final media = MediaQuery.of(context);
    final canCopy = _turns.any((t) => (t.answer ?? '').isNotEmpty);
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(20, 16, 20, 16 + media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${uiStrings['aiExplainHeader']?[locale] ?? 'AI explanation'} · ${widget.refLabel}',
                      style: TextStyle(
                        fontFamily: widget.settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (canCopy)
                    IconButton(
                      tooltip: uiStrings['copySelection']?[locale] ?? 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ClipboardHelper.copyWithFeedback(
                          context, _composeCopyText()),
                    ),
                  IconButton(
                    tooltip: uiStrings['close']?[locale] ?? 'Close',
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  controller: _bodyScroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.verseText.isNotEmpty)
                        _scriptureBlock(scheme, locale),
                      if (_turns.isEmpty)
                        _idleHint(scheme, locale)
                      else
                        for (var i = 0; i < _turns.length; i++)
                          _turnCard(scheme, locale, _turns[i], i),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _inputArea(scheme, locale),
              const SizedBox(height: 10),
              Text(
                uiStrings['aiExplainVerseDisclaimer']?[locale] ??
                    'AI-generated; for reference only — let Scripture itself be the authority.',
                style: TextStyle(
                  fontFamily: widget.settings.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scriptureBlock(ColorScheme scheme, String locale) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius:
            const BorderRadius.horizontal(right: Radius.circular(10)),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings['aiExplainScriptureLabel']?[locale] ?? 'Scripture',
            style: TextStyle(
              fontFamily: widget.settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 5),
          SelectableText(
            widget.verseText,
            style: TextStyle(
              fontFamily: widget.settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: widget.settings.fontSize,
              height: widget.settings.lineSpacing,
              color: scheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _idleHint(ColorScheme scheme, String locale) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 18,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              uiStrings['aiExplainIdleHint']?[locale] ??
                  'Generate an explanation of this passage, or type a question first and confirm.',
              style: TextStyle(
                fontFamily: widget.settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _turnCard(ColorScheme scheme, String locale, _AiTurn turn, int i) {
    final reading = TextStyle(
      fontFamily: widget.settings.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineSpacing,
      color: scheme.onSurface,
    );
    return Padding(
      padding: EdgeInsets.only(top: i == 0 ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
          if (turn.question != null && turn.question!.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.help_outline_rounded,
                    size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    turn.question!,
                    style: reading.copyWith(
                        fontSize: widget.settings.fontSize - 1,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (turn.loading)
            _loadingRow(scheme, locale, turn.question != null)
          else if (turn.error != null)
            _errorBody(scheme, locale, turn.error!, () => _runTurn(turn))
          else ...[
            SelectableText(
              turn.answer ?? '',
              style: reading,
              onSelectionChanged: (sel, cause) {
                final a = turn.answer ?? '';
                if (sel.isValid &&
                    !sel.isCollapsed &&
                    sel.start >= 0 &&
                    sel.end <= a.length) {
                  turn.selectedText = sel.textInside(a);
                } else {
                  turn.selectedText = '';
                }
              },
            ),
            const SizedBox(height: 8),
            _turnActions(scheme, locale, turn),
          ],
        ],
      ),
    );
  }

  Widget _turnActions(ColorScheme scheme, String locale, _AiTurn turn) {
    final shorter = _shorter(turn.length);
    final longer = _longer(turn.length);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (shorter != null)
          _miniChip(
              scheme,
              Icons.unfold_less_rounded,
              uiStrings['aiMoreConcise']?[locale] ?? 'More concise',
              _busy ? null : () => _regenerate(turn, shorter)),
        if (longer != null)
          _miniChip(
              scheme,
              Icons.unfold_more_rounded,
              uiStrings['aiMoreDetail']?[locale] ?? 'More detail',
              _busy ? null : () => _regenerate(turn, longer)),
        _miniChip(
            scheme,
            Icons.bookmark_add_outlined,
            uiStrings['aiSaveToNote']?[locale] ?? 'Save to note',
            () => _saveTurnToNote(turn),
            filled: true),
      ],
    );
  }

  Widget _miniChip(ColorScheme scheme, IconData icon, String label,
      VoidCallback? onTap,
      {bool filled = false}) {
    final fg = filled ? scheme.onPrimary : scheme.primary;
    final bg =
        filled ? scheme.primary : scheme.primary.withValues(alpha: 0.10);
    return Material(
      color: onTap == null ? bg.withValues(alpha: 0.4) : bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: widget.settings.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingRow(ColorScheme scheme, String locale, bool isQuestion) {
    final msg = isQuestion
        ? (uiStrings['aiAskAnswering']?[locale] ?? 'Answering your question…')
        : (uiStrings['aiExplainGenerating']?[locale] ??
            'Generating explanation…');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              msg,
              style: TextStyle(
                fontFamily: widget.settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputArea(ColorScheme scheme, String locale) {
    final firstTurn = _turns.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _questionController,
          focusNode: _questionFocus,
          minLines: 1,
          maxLines: 4,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
          style: TextStyle(
            fontFamily: widget.settings.fontFamily,
            fontFamilyFallback: kCjkFontFallback,
            fontSize: widget.settings.fontSize - 1,
            color: scheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: firstTurn
                ? (uiStrings['aiAskQuestionHint']?[locale] ??
                    'Ask a question about this passage… (optional)')
                : (uiStrings['aiFollowUpHint']?[locale] ?? 'Ask a follow-up…'),
            hintStyle: TextStyle(
              fontFamily: widget.settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: widget.settings.fontSize - 2,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _questionController,
          builder: (context, value, _) {
            final hasQuestion = value.text.trim().isNotEmpty;
            // First turn: empty allowed (opening explanation). Later turns:
            // a follow-up needs a typed question.
            final canSubmit = !_busy && (firstTurn || hasQuestion);
            final label = hasQuestion
                ? (uiStrings['aiAskSend']?[locale] ?? 'Ask')
                : (uiStrings['aiExplainGenerate']?[locale] ??
                    'Explain this passage');
            return FilledButton.icon(
              onPressed: canSubmit ? _submit : null,
              icon: Icon(
                hasQuestion
                    ? Icons.send_rounded
                    : Icons.auto_awesome_rounded,
                size: 18,
              ),
              label: Text(
                label,
                style: TextStyle(
                  fontFamily: widget.settings.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _errorBody(ColorScheme scheme, String locale, String reason,
      VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: widget.settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(uiStrings['retry']?[locale] ?? 'Retry'),
          ),
        ],
      ),
    );
  }
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
///
/// Round 56 hardening for "after click notes and click and typing,
/// that moment it goes to top": the underlying Bible reading pane
/// can lose its scroll position when the modal sheet animates in
/// and the on-screen keyboard appears (iOS Safari PWA, native
/// Android with `resizeToAvoidBottomInset` cascading effects, and
/// some desktop browser layouts). Defense in depth: capture the
/// topmost-visible item index before the sheet shows, and on
/// completion restore the scroll if it has shifted unexpectedly.
/// This treats the symptom regardless of which underlying browser
/// quirk caused it.
/// 2026-05-19 (v1.2.60): editor accepts a LIST of verses, not just
/// one. Multi-verse selection (long-press + chain-tap a range) opens
/// ONE editor whose Save writes the same text to every verse in the
/// selection — WeDevote-style "passage note". Single-verse selection
/// (one verse only) is the same code path, with [verses].length == 1.
///
/// Pre-population: text is taken from the first verse in the
/// selection that already has a non-empty note (so an existing note
/// on any verse in the range surfaces and the user can refine it
/// before re-saving across the whole range).
///
/// Delete: clears the note from every verse in the selection (the
/// user opened ONE editor for the range, "Delete" means "remove the
/// note from the whole range", not "remove from the first verse
/// only" — the latter would be confusing).
/// 2026-05-24 (v1.2.95): public so Library's note tile can open
/// the editor directly without navigating to the reader first.
/// Was private (`_showNoteEditor`) since v1.2.59; user feedback
/// "按了应该打开笔记本而不是跳到那个经文章节" — tile tap should
/// open the note, not jump to verse. Verse-ref text retains its
/// own tap handler for the jump path.
void showNoteEditor({
  required BuildContext context,
  required List<Verse> verses,
  required String locale,
  required MainProvider mainProvider,
  /// v1.3.73 — when provided (e.g. "save AI answer to note"), the editor
  /// opens prefilled with the verse's existing note + this text appended
  /// (or just this text if there's no existing note), editable before
  /// saving. Reuses the normal save path; nothing is written until the
  /// user confirms.
  String? appendText,
}) {
  if (verses.isEmpty) return;
  final firstVerse = verses.first;
  // Pre-populate from the first verse in the selection that has an
  // existing non-empty note. If none, start empty.
  String? prefill;
  String? prefillTitle;
  for (final v in verses) {
    final existing = mainProvider.getVerseNote(v);
    if (existing != null && existing.isNotEmpty) {
      prefill = existing;
      // 2026-05-24 (v1.2.91): pull the title from the same verse
      // we pulled the body from. For multi-verse passage notes,
      // all verses share the same title (setVerseNote writes both
      // to every verse in the selection), so this is consistent.
      prefillTitle = mainProvider.getVerseNoteTitle(v.id);
      break;
    }
  }
  // v1.3.73: fold an optional appended snippet (e.g. an AI answer) into
  // the initial body — after the existing note if there is one.
  var initialBody = prefill ?? '';
  final addText = (appendText ?? '').trim();
  if (addText.isNotEmpty) {
    initialBody = initialBody.isEmpty ? addText : '$initialBody\n\n$addText';
  }
  final controller = TextEditingController(text: initialBody);
  final titleController = TextEditingController(text: prefillTitle ?? '');
  // Reference label: single verse → "Genesis 1:16"; range → "Genesis 1:16-18".
  String ref;
  if (verses.length == 1) {
    ref = '${firstVerse.book} ${firstVerse.chapter}:${firstVerse.verseLabel}';
  } else {
    final last = verses.last;
    final sameChapter = last.book == firstVerse.book && last.chapter == firstVerse.chapter;
    if (sameChapter) {
      ref = '${firstVerse.book} ${firstVerse.chapter}:'
          '${firstVerse.verseLabel}-${last.verseLabel}';
    } else {
      // Cross-chapter range (rare but possible if user multi-selected
      // across a chapter break). Show start + end with full labels.
      ref = '${firstVerse.book} ${firstVerse.chapter}:${firstVerse.verseLabel} – '
          '${last.book} ${last.chapter}:${last.verseLabel}';
    }
  }
  // [verse] is used by several downstream operations (scroll
  // restoration, position capture). Keep the variable name but
  // alias it to the first verse for backwards compatibility with
  // the rest of this function's body.
  final verse = firstVerse;

  // Round 56 round 5: actually-correct index handling.
  //
  // Bug in round 4: `savedIndex` was set from
  // `chapterVerses.indexWhere(...)` — which is a 0-based VERSE
  // index — but `restoreScroll` then called
  // `itemScrollController.jumpTo(index: savedIndex)` which
  // expects an ITEM index. The two spaces differ:
  //
  //   - Item index:   header(0), paragraphGroup(1)...(N), trailer
  //   - Verse index:  verse_0...verse_N within chapter
  //
  // With paragraph mode (default ON), one item can wrap several
  // verses, so verse N maps to a substantially smaller item
  // index. So my restore was landing on a WRONG (higher) item —
  // looking like "scroll to top + tiny scroll down" because we
  // were scrolling back to a near-top item that wasn't where the
  // user actually was. That's the user's exact symptom.
  //
  // Fix: capture the topmost-visible ITEM index directly from
  // the positions listener (already in item space — perfect for
  // jumpTo), and fall back to verse-derived only when the
  // listener is empty AND go through `mainProvider.jumpToIndex`
  // which routes through `_verseToItemMap`.
  int? savedItemIndex;
  int? savedVerseIndex;

  // Primary: read item index from positions listener.
  try {
    final positions = mainProvider.itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      final visible = positions
          .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
          .toList()
        ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
      if (visible.isNotEmpty) savedItemIndex = visible.first.index;
    }
  } catch (_) {}

  // Backup: derive verse-relative index from the selected verse,
  // for cases where the positions listener was empty (rare —
  // cold-mount races mostly).
  try {
    final chapterVerses = mainProvider.verses
        .where((v) => v.book == verse.book && v.chapter == verse.chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    final relIdx = chapterVerses.indexWhere((v) => v.verse == verse.verse);
    if (relIdx >= 0) savedVerseIndex = relIdx;
  } catch (_) {}

  void restoreScroll() {
    if (!mainProvider.itemScrollController.isAttached) return;
    try {
      final itemIdx = savedItemIndex;
      final verseIdx = savedVerseIndex;
      if (itemIdx != null && itemIdx > 0) {
        // Direct item-index path: positions listener already
        // gave us the item index, no map translation needed.
        mainProvider.itemScrollController.jumpTo(index: itemIdx);
      } else if (verseIdx != null) {
        // Fall back to mp.jumpToIndex which translates verse
        // index through `_verseToItemMap` to land on the right
        // paragraph group / single-verse item.
        mainProvider.jumpToIndex(index: verseIdx);
      }
    } catch (_) {}
  }

  // Watch the reader's item positions while the sheet is open.
  // If the topmost visible item drifts away from our saved
  // position (jumps to top OR anywhere unexpected), restore.
  //
  // 2026-05-20 (v1.2.64): dropped the `saved <= 5` early-return —
  // user reported the scroll-restore still failed on iOS even
  // after v1.2.63's 10s timer + viewInsets watcher. Tightening
  // analysis: if the user was reading near the top of the chapter
  // (e.g. verse 3 visible at item index 3), the old guard
  // disabled the defender entirely. Then any keyboard-induced
  // remount that snapped the SPL to item 0 stayed there. Now the
  // defender fires whenever currentTop differs from savedItemIndex
  // by more than 1 (1-item tolerance for sub-pixel drift).
  void onPositionsChanged() {
    if (!mainProvider.itemScrollController.isAttached) return;
    final saved = savedItemIndex;
    if (saved == null) return;
    try {
      final positions =
          mainProvider.itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;
      final visible = positions
          .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
          .toList()
        ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
      if (visible.isEmpty) return;
      final currentTop = visible.first.index;
      // Restore whenever the SPL drifted away from where we saved.
      // 1-item tolerance for sub-pixel layout adjustments.
      if ((currentTop - saved).abs() > 1) {
        Future.microtask(restoreScroll);
      }
    } catch (_) {}
  }

  mainProvider.itemPositionsListener.itemPositions
      .addListener(onPositionsChanged);

  // Aggressive enforcement: every 16 ms (≈ one frame at 60 fps)
  // jumpTo the saved index. This brute-force approach guarantees
  // that no matter which frame some browser/keyboard quirk fires
  // the jump-to-top, the next tick puts us back.
  //
  // 2026-05-20 (v1.2.63): extended from 1.5 s (94 ticks) to
  // 10 s (625 ticks). User reported "when clicking the note it
  // goes to the top — I need to close the keyboard first then
  // things stay normal". Root cause: on web (esp. Safari iOS),
  // the keyboard appearance is decoupled from the sheet open
  // event — `autofocus: true` doesn't reliably trigger the
  // keyboard until the user taps the TextField, which can be
  // several seconds after the sheet animates up. The v1.2.29
  // 1.5 s window covered the OPEN animation but not the later
  // first-tap keyboard pop, so the resulting viewport shrink
  // pulled the SPL to top with no restore active. Bumping to
  // 10 s comfortably covers any realistic delay.
  //
  // Also: a viewInsets watcher inside the StatefulBuilder (below)
  // fires restoreScroll on EVERY keyboard show / hide event for
  // the lifetime of the editor — defense-in-depth in case the
  // user keeps the editor open past 10 s.
  //
  // Cost is negligible: jumpTo on an already-correct position is
  // a no-op trivial call.
  Timer? enforceTimer;
  enforceTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
    if (t.tick >= 625) {
      // ~10 s elapsed (625 × 16 ≈ 10 s). Stop hammering.
      t.cancel();
      return;
    }
    restoreScroll();
  });

  // 2026-05-24 (v1.2.92): the editor was previously expandable
  // (compact ↔ fullscreen toggle, v1.2.62). User reported the
  // toggle was buggy on iOS — sometimes closed the sheet
  // entirely, layout glitches on Android. Root cause:
  // AnimatedContainer height transition INSIDE a modal sheet is
  // a known-fragile pattern. The simplest robust fix is to
  // remove the toggle entirely and always open fullscreen — note
  // editing is a focused task, fullscreen is the better default
  // anyway, and there's no longer any compact/fullscreen state
  // to get wrong.
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 2026-05-24 (v1.2.94): drag-to-dismiss re-enabled. Was
    // disabled in v1.2.91 to dodge the fullscreen-toggle bug, but
    // v1.2.92 removed the toggle entirely so the AnimatedContainer
    // height transition that confused iOS is gone. Re-enabling
    // gives users the iOS-native swipe-down dismiss (drag the top
    // pill down) — addresses v1.2.93 user feedback "note taking
    // in iOS clicking close it hard, bad UX". X + backdrop tap
    // remain as backup dismiss paths.
    enableDrag: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      // 2026-05-20 (v1.2.63): viewInsets watcher closed over by the
      // StatefulBuilder so we can fire restoreScroll on EVERY
      // keyboard show / hide event. Lives outside the builder so
      // we can compare against the previous value.
      double lastViewInsetsBottom = 0;
      return StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
      final scheme = Theme.of(sheetCtx).colorScheme;
      final mq = MediaQuery.of(sheetCtx);
      // 2026-05-20 (v1.2.63): keyboard show / hide listener. Every
      // time the bottom inset changes (≥4 px to avoid noise from
      // sub-pixel layout adjustments), fire restoreScroll multiple
      // times — same multi-shot pattern as the Focus.onFocusChange
      // handler, so we beat whatever frame the browser uses to
      // resize the viewport. Defense-in-depth on top of the 10 s
      // enforceTimer above.
      final bottomInset = mq.viewInsets.bottom;
      if ((bottomInset - lastViewInsetsBottom).abs() > 4.0) {
        lastViewInsetsBottom = bottomInset;
        // Schedule restores post-frame so the layout is settled
        // first; multi-shot at 0 / 50 / 150 / 350 / 800 ms covers
        // both fast and slow keyboard animations.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          restoreScroll();
          for (final delayMs in const [50, 150, 350, 800]) {
            Future.delayed(
                Duration(milliseconds: delayMs), restoreScroll);
          }
        });
      }
      // v1.2.60: "Delete" button shows when ANY verse in the
      // multi-verse selection has a note (and Delete clears them all).
      final hasExisting = verses.any(
          (v) => (mainProvider.getVerseNote(v) ?? '').isNotEmpty);
      // 2026-05-24 (v1.2.93): height = viewport minus status bar
      // ONLY. Do NOT also subtract viewInsets.bottom here — the
      // Padding below already adds viewInsets.bottom to its
      // bottom inset, and subtracting in BOTH places is a double
      // subtraction. With a 400 px iOS keyboard up that bug
      // squeezed the Expanded body TextField to negative height
      // (user reported: 标题/chips/buttons visible, no body —
      // see screenshot in conversation). Fix: sheet container =
      // full visible area below status bar; Padding handles
      // keyboard avoidance. Was correct in v1.2.91 compact mode
      // because height was `null` (intrinsic), but broke when
      // v1.2.92 made fullscreen the only mode.
      final fullscreenHeight =
          mq.size.height - mq.padding.top;
      return SizedBox(
        height: fullscreenHeight,
        child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2026-05-24 (v1.2.95): drag handle is now a tappable
            // dismiss target. User report: "note 打开，关闭在右上角，
            // ios 有时候按不到，网页版好点". The top-right X near
            // the notch / Dynamic Island is awkward to thumb on
            // iOS. The drag pill at top-center IS reachable. Tap
            // it to dismiss; drag it down to dismiss
            // (enableDrag: true from v1.2.94). Both dismiss paths
            // are obvious + thumb-friendly.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(sheetCtx).maybePop(),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                // Extra vertical padding makes the tap target ~28 pt
                // tall — comfortably hittable without making the
                // pill itself visually fat.
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                child: Container(
                  width: 56,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
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
                // 2026-05-24 (v1.2.94): enlarged X tap target.
                // Default IconButton is 48 pt but with snug
                // visualDensity it shrinks below Apple HIG's 44 pt
                // minimum, which user called out on iOS: "clicking
                // close it hard and it is bad UX". Explicit 28 pt
                // icon + EdgeInsets.all(12) padding = 52 pt overall
                // — comfortably thumb-tappable near the notch.
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 28),
                  padding: const EdgeInsets.all(12),
                  constraints:
                      const BoxConstraints(minWidth: 52, minHeight: 52),
                  tooltip: uiStrings['tooltipClose']?[locale] ?? 'Close',
                  onPressed: () => Navigator.of(sheetCtx).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 2026-05-24 (v1.2.91): optional title field. Single
            // line, no autofocus (focus goes to the body so users
            // who skip titles aren't slowed down). Empty title is
            // valid — Library tile falls back to the verse ref as
            // the header. Library tile renders the title in bold
            // when set, so a typed title essentially "renames"
            // the note for at-a-glance recognition in the list.
            TextField(
              controller: titleController,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: uiStrings['noteTitleHint']?[locale] ??
                    'Title (optional)',
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              ),
            ),
            Divider(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
                height: 12,
                thickness: 1),
            // 2026-05-24 (v1.2.92): always-fullscreen body TextField.
            // Was a compact/fullscreen branching (v1.2.62) before
            // the v1.2.92 simplification. Wrap in Expanded so the
            // field fills the remaining vertical space of the
            // fullscreen sheet; maxLines: null + expands: true
            // give an edge-to-edge editing surface. Focus +
            // onChanged trigger scroll-restore on the underlying
            // SPL since the keyboard popup can shift it.
            Expanded(
              child: Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    // 2026-07-23: must NOT call restoreScroll()
                    // synchronously here. This callback runs from
                    // inside Flutter's own FocusManager.
                    // applyFocusChangesIfNeeded(), which iterates its
                    // _dirtyNodes set and calls node._notify() —
                    // that's what invokes this onFocusChange. If
                    // restoreScroll's jumpTo() synchronously disposes
                    // off-screen list-item FocusNodes (e.g. the
                    // autofocus items in the reading pane behind this
                    // sheet), FocusNode.dispose() removes itself from
                    // that same _dirtyNodes set mid-iteration, which
                    // throws ConcurrentModificationError (prod crash,
                    // v1.3.143, decoded via source map to
                    // focus_manager.dart:2008). Future.microtask defers
                    // just past the end of that synchronous loop —
                    // same escape hatch already used above for the
                    // positions-listener restore (see
                    // Future.microtask(restoreScroll) a few lines up).
                    Future.microtask(restoreScroll);
                    for (final delayMs in const [16, 50, 150, 350]) {
                      Future.delayed(
                          Duration(milliseconds: delayMs), restoreScroll);
                    }
                  }
                },
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textInputAction: TextInputAction.newline,
                  onTap: () {
                    restoreScroll();
                    for (final delayMs in const [16, 50, 150, 350]) {
                      Future.delayed(
                          Duration(milliseconds: delayMs), restoreScroll);
                    }
                  },
                  onChanged: (_) {
                    restoreScroll();
                    // 2026-05-20 (v1.2.65): rebuild so the ref-chip
                    // strip below recomputes from the new note
                    // text.
                    setSheetState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: uiStrings['noteHint']?[locale] ??
                        'Type your note for this verse…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
            // 2026-05-20 (v1.2.65): live ref-chip strip. As the
            // user types or inserts `[Book Ch:V]` references via
            // the picker, each parseable ref renders as a tappable
            // ActionChip below the TextField. Tap → opens the same
            // VersePopupSheet the Library notes view uses, so the
            // user can preview a referenced verse WITHOUT having
            // to save the note first. Hidden when no refs present.
            Builder(builder: (chipCtx) {
              final refs = extractNoteReferences(controller.text);
              if (refs.isEmpty) return const SizedBox(height: 12);
              // 2026-05-20 (v1.2.66): for the "cross-canon indicator"
              // check (Issue 2 — LJK1/2 are NT only; OT refs are
              // valid but need a full-canon fallback to read), build
              // a set of english book names that EXIST in the
              // currently-loaded verses. Anything outside this set
              // gets the small fallback marker on its chip.
              final loadedBooksEn = <String>{
                for (final v in mainProvider.verses)
                  bookNameToEnglish[v.book] ?? v.book
              };
              // 2026-07-19: bounded single-row, horizontally scrolling
              // strip instead of an unbounded multi-row Wrap.
              // extractNoteReferences intentionally does NOT dedup
              // (see its doc comment), so a note with many (or
              // repeated) [Book Ch:V] refs used to make the Wrap grow
              // to N rows — and since it's the only non-flex sibling
              // of the Expanded body TextField above, every extra row
              // it claimed shrank the writing area, down to a sliver
              // for long ref lists. A fixed-height horizontal
              // ListView caps this strip's footprint at a constant
              // regardless of ref count. Same bounded-strip pattern
              // already used elsewhere for "row of chips that must
              // never compete for vertical space" — see the color
              // filter row in highlights_page.dart.
              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: refs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => _buildNoteRefChip(
                      ref: refs[i],
                      scheme: scheme,
                      locale: locale,
                      currentVersion: mainProvider.currentVersion,
                      isInCurrentVersion:
                          loadedBooksEn.contains(refs[i].englishBook),
                      chipCtx: chipCtx,
                    ),
                  ),
                ),
              );
            }),
            // 2026-05-19 (v1.2.59): "+ Verse Reference" button.
            // Opens a 3-step picker (book → chapter → verse) and
            // inserts the chosen `[Book Ch:V]` at the textfield's
            // cursor position. The reference becomes a tappable
            // link when viewed in the Library / wherever the note
            // is displayed.
            Row(
              children: [
                // 2026-05-24 (v1.2.95): thumb-reachable Cancel
                // button in an OutlinedButton — more visible than
                // the v1.2.94 plain TextButton so users see it as
                // a real dismiss option alongside Save / Delete.
                // Three dismiss paths now: top drag handle (tap or
                // swipe down), bottom Cancel, top X. All three
                // work; user picks whichever is comfortable.
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetCtx).maybePop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(
                      color: scheme.outlineVariant,
                      width: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
                ),
                const SizedBox(width: 4),
                if (hasExisting)
                  TextButton.icon(
                    onPressed: () {
                      // 2026-05-19 (v1.2.60): delete clears the note
                      // from EVERY verse in the selection (multi-verse
                      // editor). For single-verse selection this is
                      // identical to the previous behaviour.
                      for (final v in verses) {
                        mainProvider.clearVerseNote(verse: v);
                      }
                      mainProvider.clearSelectedVerses();
                      Navigator.of(sheetCtx).maybePop();
                      // 2026-05-24 (v1.2.91): same confirmation toast
                      // pattern as the Save button — destructive
                      // actions deserve at least the same visibility.
                      final scheme = Theme.of(context).colorScheme;
                      showFloatingToast(
                        context,
                        message: uiStrings['noteDeleted']?[locale] ??
                            'Note deleted',
                        icon: Icons.delete_outline_rounded,
                        background: scheme.error,
                      );
                    },
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    label: Text(
                      uiStrings['noteDelete']?[locale] ?? 'Delete',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final settings =
                        Provider.of<AppSettings>(sheetCtx, listen: false);
                    final inserted = await showNoteReferencePicker(
                      context: sheetCtx,
                      locale: locale,
                      mainProvider: mainProvider,
                      settings: settings,
                    );
                    if (inserted == null || inserted.isEmpty) return;
                    // Insert at cursor (or append at end if no
                    // selection / no focus). TextEditingController
                    // selection is null when the field has never
                    // been focused — fall back to end-of-text.
                    final sel = controller.selection;
                    final cur = controller.text;
                    if (sel.isValid && sel.start >= 0 && sel.end <= cur.length) {
                      final before = cur.substring(0, sel.start);
                      final after = cur.substring(sel.end);
                      final next =
                          '$before$inserted$after';
                      controller.value = TextEditingValue(
                        text: next,
                        selection: TextSelection.collapsed(
                          offset: (before + inserted).length,
                        ),
                      );
                    } else {
                      controller.text = cur + inserted;
                    }
                  },
                  icon: Icon(Icons.add_link_rounded, color: scheme.primary),
                  label: Text(
                    uiStrings['noteAddReference']?[locale] ??
                        '+ Verse',
                    style: TextStyle(color: scheme.primary),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    // 2026-05-19 (v1.2.60): save the same text to
                    // every verse in the selection — WeDevote-style
                    // "passage note". Single-verse selection
                    // writes one note; multi-verse writes N copies
                    // of the same text. Library tab groups
                    // consecutive matching notes back into one
                    // display tile.
                    //
                    // 2026-05-24 (v1.2.91): pass the optional title
                    // to every verse in the selection too. All
                    // verses in a passage note share one title so
                    // the Library tile renders consistently.
                    for (final v in verses) {
                      mainProvider.setVerseNote(
                        verse: v,
                        text: controller.text,
                        title: titleController.text,
                      );
                    }
                    mainProvider.clearSelectedVerses();
                    // 2026-05-24 (v1.2.91): capture inputs BEFORE
                    // the sheet pops so the toast reflects what
                    // actually got persisted. An empty body deletes
                    // the note (see setVerseNote); distinguish the
                    // two outcomes for the user-facing confirmation.
                    final wasDeleted = controller.text.trim().isEmpty;
                    Navigator.of(sheetCtx).maybePop();
                    // Toast on the reader's outer context (the sheet
                    // ctx is gone now); use rootOverlay via
                    // showFloatingToast so we render above any
                    // closing-sheet animation.
                    final scheme = Theme.of(context).colorScheme;
                    showFloatingToast(
                      context,
                      message: wasDeleted
                          ? (uiStrings['noteDeleted']?[locale] ??
                              'Note deleted')
                          : (uiStrings['noteSaved']?[locale] ??
                              'Note saved'),
                      icon: wasDeleted
                          ? Icons.delete_outline_rounded
                          : Icons.check_circle_rounded,
                      background:
                          wasDeleted ? scheme.error : scheme.primary,
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(uiStrings['noteSave']?[locale] ?? 'Save'),
                ),
              ],
            ),
          ],
        ),
        ),
      );
      },
    );
    },
  ).whenComplete(() {
    // Sheet closed — stop watching positions and stop the
    // per-frame enforcement, do one last defensive restore in
    // case the close animation itself shifted scroll to top.
    enforceTimer?.cancel();
    mainProvider.itemPositionsListener.itemPositions
        .removeListener(onPositionsChanged);
    // 2026-05-10 (v1.2.29): controller created at line ~2529 was
    // never disposed — every note edit leaked one
    // TextEditingController + its internal listeners. Bounded but
    // unbounded across a long session of editing notes.
    controller.dispose();
    // 2026-05-24 (v1.2.91): same hygiene for the new title
    // controller.
    titleController.dispose();
    Future.delayed(const Duration(milliseconds: 50), restoreScroll);
  });
  // After the sheet has had time to animate up + the keyboard to
  // settle, do a one-shot defensive restore. This catches the
  // most common "click textfield → keyboard pops up → reader
  // jumps" timing, even before the user types a single character.
  Future.delayed(const Duration(milliseconds: 350), restoreScroll);
}

/// 2026-05-20 (v1.2.66): note-editor verse-reference chip.
///
/// Locale-aware label: routes the english book name through
/// `localeAwareBookName` so a user reading a Chinese version sees
/// '创世记 1:1' on the chip, not 'Genesis 1:1'. The COMPACT verse
/// spec (1, 1-5, 2,5,7-10) stays as digits since verse numbers are
/// universal across translations.
///
/// Cross-canon indicator: if the ref's book isn't in the loaded
/// version (e.g. user has LJK2 NT-only loaded and the ref is for
/// Genesis), a small dotted-border style plus an `info_outline`
/// icon signals that tapping will need to load the OT companion
/// version. The popup itself already handles this via
/// `bibleVersionFullCanonFallback` + `_ensureVersesLoaded`; the
/// chip marker is purely a heads-up.
Widget _buildNoteRefChip({
  required NoteReferenceMatch ref,
  required ColorScheme scheme,
  required String locale,
  required String currentVersion,
  required bool isInCurrentVersion,
  required BuildContext chipCtx,
}) {
  // Localized book name based on the current reading version
  // (zh-Hans / zh-Hant → Chinese; English versions → English).
  // Falls back to the original English book name if the version
  // isn't in our locale-mapping table.
  final localizedBook = localeAwareBookName(
    ref.englishBook,
    locale,
    currentVersion,
  );
  // Compact verse-spec formatter — same shape as the picker output.
  String verseSpec;
  final v = ref.verses;
  if (v.length == 1) {
    verseSpec = '${v.first}';
  } else {
    final parts = <String>[];
    int start = v.first;
    int end = start;
    for (var i = 1; i < v.length; i++) {
      final n = v[i];
      if (n == end + 1) {
        end = n;
      } else {
        parts.add(start == end ? '$start' : '$start-$end');
        start = n;
        end = n;
      }
    }
    parts.add(start == end ? '$start' : '$start-$end');
    verseSpec = parts.join(',');
  }
  final label = '$localizedBook ${ref.chapter}:$verseSpec';

  final borderColor = isInCurrentVersion
      ? scheme.primary.withValues(alpha: 0.35)
      : scheme.outline.withValues(alpha: 0.5);
  final bgColor = isInCurrentVersion
      ? scheme.primaryContainer.withValues(alpha: 0.35)
      : scheme.surfaceContainerHighest.withValues(alpha: 0.4);

  return ActionChip(
    avatar: Icon(
      isInCurrentVersion
          ? Icons.menu_book_rounded
          : Icons.swap_horiz_rounded,
      size: 16,
      color: isInCurrentVersion
          ? scheme.primary
          : scheme.onSurfaceVariant,
    ),
    label: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        color: scheme.onSurface,
      ),
    ),
    backgroundColor: bgColor,
    side: BorderSide(color: borderColor, width: 0.7),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    // Tooltip explains the swap-horiz icon: tapping will load
    // a full-canon companion version because the current
    // version doesn't include this book.
    tooltip: isInCurrentVersion
        ? null
        : (uiStrings['noteChipFallbackTooltip']?[locale] ??
            'This book isn\'t in your current version — '
                'tapping will load the full-canon companion'),
    onPressed: () {
      final bibleRef = BibleReference(
        englishBook: ref.englishBook,
        chapter: ref.chapter,
        verseStart: ref.verseStart,
        verseEnd: ref.verseEnd,
        verses: ref.verses,
      );
      showVersePopup(chipCtx, bibleRef);
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
  // 2026-06-29: illustration book-group headers must follow the READING
  // VERSION (NASB → "Genesis", CUVS → "创世记", `-tr` → "創世記"), not the
  // UI locale. Previously the group passed `locale` ('en') into
  // translateBookName's VERSION slot; `toLocale('Genesis','en')` doesn't
  // recognise 'en' as an English version (only kjv/nasb/niv/leb) and fell
  // through to Chinese — so an English reader saw 创世纪/出埃及记. Thread the
  // real version in (mirrors HighlightsSheet). See [[feedback_book_name_localization]].
  final version = context.read<MainProvider>().currentVersion;
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
        version: version,
      );
    },
  );
}

class _MapPickerSheet extends StatefulWidget {
  final List<BibleMap> chapterMaps;
  final List<BibleMap> bookMaps;
  final String locale;
  final String version;
  const _MapPickerSheet({
    required this.chapterMaps,
    required this.bookMaps,
    required this.locale,
    required this.version,
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
            // 2026-05-22 (v1.2.72): explicit labelColor / unselected /
            // indicator. The global `tabBarTheme` in main.dart sets
            // labelColor = onPrimary (white on a primary-tinted AppBar),
            // which renders WHITE-ON-WHITE here inside a surface
            // bottom-sheet. Override locally for readability.
            if (_tabs.length > 1)
              TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                indicatorColor: scheme.primary,
                dividerColor: Colors.transparent,
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
          version: widget.version,
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
  final String version;
  final List<BibleMap> related;
  final VoidCallback onCloseSheet;
  const _AllIllustrationsByBook({
    required this.all,
    required this.locale,
    required this.version,
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
  /// 2026-06-30 (v1.3.118): de-duplicated the catalogue — wide survey
  /// maps used to repeat group after group (1192 illustrations → 1940
  /// tiles). 2026-07-07: the primary-book-only version of that de-dup
  /// EMPTIED 13 NT books whose every illustration also touched an
  /// earlier book (e.g. Ephesians lost "Paul leaves Ephesus" to Acts).
  /// Now delegates to [groupIllustrationsByBook]: small spans (≤4
  /// books) list under each tagged book, wide survey maps under their
  /// first book only, and any still-empty book gets its referencing
  /// illustrations back. Per-book relevance is unaffected: the "For
  /// this book / chapter" tabs filter `widget.all` directly.
  Map<String, List<BibleMap>> _groupByBook() =>
      groupIllustrationsByBook(widget.all, standardBookOrder);

  bool _bookMatches(String book, String q) {
    if (q.isEmpty) return true;
    final qLower = q.toLowerCase();
    if (book.toLowerCase().contains(qLower)) return true;
    // Match the name the user actually SEES (reading-version localized) …
    if (translateBookName(book, widget.version).toLowerCase().contains(qLower)) {
      return true;
    }
    // … plus the Simplified name so a Chinese query always works regardless
    // of the reading version.
    if (translateBookName(book, 'zh-Hans').toLowerCase().contains(qLower)) {
      return true;
    }
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
                    version: widget.version,
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
  final String version;
  final List<BibleMap> maps;
  final List<BibleMap> related;
  final VoidCallback onCloseSheet;
  final bool initiallyExpanded;
  final Color accentColor;
  const _BookIllustrationGroup({
    required this.book,
    required this.locale,
    required this.version,
    required this.maps,
    required this.related,
    required this.onCloseSheet,
    required this.initiallyExpanded,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Follow the reading VERSION, not the UI locale: `book` is the English
    // canonical key, so translateBookName(book, version) yields "Genesis"
    // for NASB/KJV, "创世记" for CUVS, "創世記" for the -tr variants.
    final localizedBook = translateBookName(book, version);
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
          // 2026-05-23 (v1.2.83): IllustrationImage helper dispatches
          // asset vs. CDN. Previously this hard-coded the asset path,
          // so the 1041 entries whose `file` was a Wikimedia URL all
          // rendered the collections-icon error fallback. They now
          // resolve to yswords-data CDN images.
          child: IllustrationImage(
            map: map,
            fit: BoxFit.cover,
            cacheWidth: 88,
            cacheHeight: 88,
            errorBuilder: (_) =>
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

/// 2026-05-21 (v1.2.70): WeDevote-style auto-hide bottom bar. Renders
/// 2026-05-24 (v1.2.91): minimal always-on header rendered ONLY
/// when the full auto-hide chrome is collapsed. Top-left pill shows
/// the current Bible version's short label (e.g. "CUV", "LJK2"),
/// top-right pill shows the book + chapter ("创世记 1", "Genesis 1").
/// Pills are subtle (low-alpha surface fill, small font) so they
/// don't compete with verse content. Both pills tap → re-show the
/// chrome (a one-tap "give me back the toolbar" shortcut).
///
/// Sits in the Stack BEFORE [_FloatingHeader] so when chrome is
/// visible the full header paints on top and covers the mini. A
/// crossfade animation hides the mini whenever chromeVisible == true,
/// so we don't get double-painting.
class _MiniReaderHeader extends StatelessWidget {
  final bool visible;
  final String version;
  final String book;
  final int chapter;
  final String locale;

  /// 2026-05-24 (v1.3.32): tapping the mini-header (either a chip
  /// OR the empty backdrop between the chips) now SCROLLS TO TOP
  /// of the chapter, not just toggles chrome. User asked for the
  /// top band to be a discoverable scroll-to-top zone. Chrome can
  /// still be toggled by tapping the verse area.
  final VoidCallback onTap;

  const _MiniReaderHeader({
    required this.visible,
    required this.version,
    required this.book,
    required this.chapter,
    required this.locale,
    required this.onTap,
  });

  String _versionLabel(String slug) {
    for (final v in bibleVersions) {
      if (v.value == slug) return v.shortLabel;
    }
    return slug.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    // 2026-05-24 (v1.3.32): platform-aware backdrop tuning so the
    // top band reads as intentional chrome on every host:
    //   * iOS / macOS / web (CanvasKit) — BackdropFilter blur for
    //     the Safari URL-bar look. Verses scroll behind, but
    //     visually obscured by the blur + the translucent surface
    //     colour layered on top.
    //   * Android — solid theme.surfaceContainerHigh tint. Material
    //     3 design guidance prefers an opaque elevated surface
    //     over a frosted glass effect.
    //
    // The backdrop is ALWAYS painted while the mini-header is
    // visible — without it, verse text bled through the chip
    // gap and looked broken (user-reported on Acts 10:2 with
    // the rare-CJK fix landing in v1.3.31).
    final platform = Theme.of(context).platform;
    final useBlur = kIsWeb ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS;
    final backdropColor = scheme.surface.withValues(alpha: 0.86);
    // v1.3.x: dropped the rounded "pill" chips (user: "no that circle")
    // — the labels now sit as plain text directly on the blurred/tinted
    // top band. Layout: book + chapter on the LEFT, VERSION CENTERED
    // (user asked for the version in the middle, not top-left). The
    // whole band is still a scroll-to-top tap target via the
    // GestureDetector below, so the chips no longer need their own taps.
    final bookStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    final versionStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: scheme.primary,
      letterSpacing: 0.1,
    );
    final backdropChild = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            // Left: where you are (book + chapter).
            Expanded(
              child: Text(
                '$book $chapter',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bookStyle,
              ),
            ),
            // Center: the version — the focal indicator.
            Text(
              _versionLabel(version),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: versionStyle,
            ),
            // Equal-flex spacer on the right so the version sits dead
            // centre regardless of how wide the book label is.
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        // Ignore taps when fully faded out — otherwise an invisible
        // strip would still swallow taps along the top edge and
        // prevent the user from swiping / tapping verses near the
        // status bar.
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          // Wrap the entire band in a GestureDetector so that
          // tapping ANY part of the chip row (chip or empty space
          // between chips, or the status-bar inset above the
          // chips) fires scroll-to-top. Chip taps still win
          // first because _MiniHeaderPill has its own
          // GestureDetector layered on top.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: useBlur
                ? ClipRect(
                    child: BackdropFilter(
                      // 2026-07-20: sigma dropped from 18 → 8. Skia's
                      // gaussian blur cost scales roughly with sigma²,
                      // and this backdrop repaints every scroll frame
                      // while the mini-header is visible (i.e. most of
                      // any real reading session, since the full chrome
                      // auto-hides quickly) — the biggest single-frame
                      // cost in the reader's scroll path. 8 still reads
                      // as a clear frosted-glass blur.
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: ColoredBox(
                        color: backdropColor,
                        child: backdropChild,
                      ),
                    ),
                  )
                : ColoredBox(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
                    child: backdropChild,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 2026-05-24 (v1.2.96): lightweight chapter preview rendered for
/// any PageView page that is NOT the current chapter. Shows the
/// chapter text so the user can read the first verses while
/// dragging. Deliberately NOT a real SPL: avoids the
/// ItemScrollController conflict (only one SPL can attach to
/// mainProvider's controllers at a time), keeps memory bounded
/// when PageView caches a couple of neighbour pages.
///
/// v1.2.96 takes [book] + [chapter] directly instead of the
/// previous [direction] (-1 / +1 relative to current), because
/// the N-page PageView places each chapter at its own page
/// index — direction no longer maps cleanly.
class _ChapterPreview extends StatelessWidget {
  final MainProvider mainProvider;
  final AppSettings settings;
  final String book;
  final int chapter;
  final DeviceClass deviceClass;

  const _ChapterPreview({
    required this.mainProvider,
    required this.settings,
    required this.book,
    required this.chapter,
    required this.deviceClass,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Verify the target chapter actually has verses in the
    // current version (defensive — chapterList is built from
    // `books`, but if the version was swapped mid-build the
    // verses list may not include this chapter yet).
    // 2026-05-24 (v1.2.99): use the O(1) index helper.
    final hasVerses =
        mainProvider.versesInChapter(book, chapter).isNotEmpty;
    if (!hasVerses) {
      // 2026-05-24 (v1.3.12): better empty-chapter UI. Previously
      // every empty page rendered as "已到尽头" (End of Bible) —
      // which confused users (user: "诗篇显示没有经文，不知道
      // 怎么按出来的"). The page is empty NOT because they reached
      // the end of canon, but because they're on a version that
      // doesn't include this book/chapter (e.g. LJK V2 NT-only +
      // a stored Psalms note from a previous full-canon version).
      //
      // Distinguish two cases:
      //   1. Canon edge: PageView's first/last page, chapter list
      //      really does end here. Show the genuine "End of Bible".
      //   2. Mid-canon hole: chapter exists in the full canon but
      //      not the current version's books list. Show specific
      //      "current version doesn't have this chapter" + button
      //      to switch to a version that does.
      //
      // Detection: if `mainProvider.findChapterIndex(book, chapter)`
      // resolves AND it's not the first/last in chapterList, this
      // is case 1 (canon edge). Otherwise case 2 (version-specific
      // gap).
      // chapterIdx == null means the chapter is NOT in the current
      // version's chapterList (version doesn't ship this book) —
      // that's case 2 (version-specific gap), NOT a canon edge.
      // Genuine canon edges are chapterList[0] (Gen 1) and
      // chapterList[length-1] (last book's last chapter).
      final chapterIdx =
          mainProvider.findChapterIndex(book, chapter);
      final isEdge = chapterIdx != null &&
          (chapterIdx == 0 ||
              chapterIdx == mainProvider.chapterList.length - 1);
      final isZh = settings.locale.startsWith('zh');
      final msg = isEdge
          ? (uiStrings['endOfBible']?[settings.locale] ??
              (isZh ? '已到尽头' : 'End of Bible'))
          : (isZh
              ? '当前版本没有 $book $chapter 章。\n请切换到包含此章节的版本（如 CUVS-YHWH / CNV）。'
              : '$book $chapter not available in the current version.\nSwitch to a full-canon version (e.g. CUVS-YHWH / CNV / KJV).');
      return ColoredBox(
        color: scheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: settings.fontSize,
                color: scheme.outline,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    // 2026-05-24 (v1.2.99): O(1) lookup via versesInChapter (replaces
    // O(n) `.where(...)` filter over all 31000 verses per build).
    // Was the dominant cost during a chapter swipe — preview rebuilt
    // for 2-3 visible pages per frame at 60 fps = ~5 M iter/s. User
    // reported persistent stutter after the v1.2.98 sync-block fix;
    // this is the remaining hot path.
    final verses = mainProvider.versesInChapter(book, chapter);
    final topInset = MediaQuery.of(context).padding.top;
    return ColoredBox(
      color: scheme.surface,
      // ListView so the user can scroll the preview if they want;
      // matches what the real chapter would feel like during the
      // swipe transition. NeverScrollable would feel "stuck".
      child: ListView.builder(
        // 2 extra slots: chapter heading (idx 0) + trailing
        // spacer (idx verses.length + 1). Same shape as the real
        // SPL so visual heights match during a swipe.
        itemCount: verses.length + 2,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (ctx, idx) {
          if (idx == 0) {
            return SizedBox(
                height: topInset + 64 * settings.menuScale + 12);
          }
          if (idx == verses.length + 1) {
            return SizedBox(height: 96 * settings.menuScale);
          }
          final v = verses[idx - 1];
          final inset = ResponsiveBreakpoints.readingPadding(deviceClass);
          return Padding(
            padding: EdgeInsets.fromLTRB(
                inset + 16, 4, inset + 16, 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${v.verseLabel} ',
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontWeight: FontWeight.w600,
                      fontSize: (settings.fontSize - 2).clamp(11.0, 16.0),
                      color: scheme.primary,
                    ),
                  ),
                  TextSpan(
                    text: v.text
                        .replaceAll(RegExp(r'<note:[^>]*>'), '')
                        .replaceAll(RegExp(r'<[^>]+>'), '')
                        .replaceAll(RegExp(r'\{[^}]+\}'), ''),
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: settings.fontSize,
                      height: 1.6,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 2026-05-24 (v1.3.3): per-chapter PageView page. Replaces the
/// v1.2.96 active-SPL-vs-preview split that caused ~1 s of jank on
/// every swipe (the widget-tree swap between two different types
/// destroyed and rebuilt everything at settle).
///
/// Every visible page in the PageView is now a `_ChapterPage` — the
/// SAME widget type at every index. Each instance:
///   - owns its own four `scrollable_positioned_list` controllers
///     (so all alive SPLs can attach without conflict);
///   - mixes in `AutomaticKeepAliveClientMixin` so PageView keeps it
///     alive when scrolled off-screen (cached up to ~3-5 pages);
///   - if it's the active page (idx matches
///     `mp.currentBook|chapter`), registers its controllers with
///     `mp.setActiveChapterControllers` so external scroll commands
///     (pendingJump from search / library / sermon; jumpToTop on
///     chapter change; scroll-to-top button) reach the right SPL
///     through the existing `mp.itemScrollController` getter.
///
/// Result: a swipe to the next chapter no longer triggers a
/// preview→SPL widget-tree replacement. The neighbour page's SPL is
/// already mounted (kept alive); settling on it is a viewport
/// translation, not a rebuild. User-perceived stutter drops to zero.
class _ChapterPage extends StatefulWidget {
  final String book;
  final int chapter;
  final bool isActive;
  final DeviceClass deviceClass;

  const _ChapterPage({
    super.key,
    required this.book,
    required this.chapter,
    required this.isActive,
    required this.deviceClass,
  });

  @override
  State<_ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<_ChapterPage>
    with AutomaticKeepAliveClientMixin<_ChapterPage> {
  late final ChapterControllers _controllers;

  // 2026-05-24 (v1.3.3): KeepAlive on every page so PageView's
  // adjacent-page cache preserves the SPL widget tree across swipes
  // — eliminates the widget-tree destruction at settle that was the
  // root cause of the residual "stuck for one sec" stutter.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controllers = ChapterControllers(
      itemScrollController: ItemScrollController(),
      scrollOffsetController: ScrollOffsetController(),
      itemPositionsListener: ItemPositionsListener.create(),
      scrollOffsetListener: ScrollOffsetListener.create(),
    );
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<MainProvider>()
            .setActiveChapterControllers(_controllers);
      });
    }
  }

  @override
  void didUpdateWidget(_ChapterPage old) {
    super.didUpdateWidget(old);
    // Become-active transitions only — we never proactively
    // de-register because the NEW active page's register call
    // displaces us atomically.
    if (widget.isActive && !old.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<MainProvider>()
            .setActiveChapterControllers(_controllers);
      });
    }
  }

  @override
  void dispose() {
    // Defensive: if we were holding active registration when we
    // disposed (rare — PageView only disposes pages when the cache
    // overflows, by which time another page has usually displaced
    // us), clear the registration so the fallback controllers
    // become authoritative until the next active page registers.
    try {
      final mp = context.read<MainProvider>();
      if (identical(mp.activeChapterControllers, _controllers)) {
        mp.setActiveChapterControllers(null);
      }
    } catch (_) {
      // context may already be detached; harmless.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    final mp = context.watch<MainProvider>();
    final settings = context.watch<AppSettings>();

    final verses = mp.versesInChapter(widget.book, widget.chapter);
    if (verses.isEmpty) {
      // Defensive — chapterList claimed this (book, chapter) exists
      // but the version's verses don't include it. Render the same
      // "end of canon" placeholder _ChapterPreview uses so the user
      // gets visual continuity instead of a blank page.
      return _ChapterPreview(
        mainProvider: mp,
        settings: settings,
        book: widget.book,
        chapter: widget.chapter,
        deviceClass: widget.deviceClass,
      );
    }

    // Compute or look up paragraphGroups for THIS chapter (each
    // _ChapterPage has its own (book, chapter); the v1.2.99 cache
    // is keyed on (version | book | chapter | mode | length) so
    // adjacent pages share nothing — no interference).
    final cached = mp.cachedParagraphGrouping(
      book: widget.book,
      chapter: widget.chapter,
      paragraphMode: settings.paragraphMode,
      versesLength: verses.length,
    );
    final List<List<Verse>> paragraphGroups;
    final Map<int, int> verseToItemMap;
    final Map<int, int> itemToVerseIndex;
    if (cached != null) {
      paragraphGroups = cached.groups;
      verseToItemMap = cached.verseToItem;
      itemToVerseIndex = cached.itemToVerseIndex;
    } else {
      paragraphGroups = settings.paragraphMode
          ? _BibleReadingPaneState._groupIntoParagraphs(verses)
          : verses.map((v) => [v]).toList();
      final vToI = <int, int>{};
      final iToV = <int, int>{0: 0};
      int vIdx = 0;
      for (int g = 0; g < paragraphGroups.length; g++) {
        iToV[g + 1] = vIdx;
        for (int v = 0; v < paragraphGroups[g].length; v++) {
          vToI[vIdx] = g + 1;
          vIdx++;
        }
      }
      verseToItemMap = vToI;
      itemToVerseIndex = iToV;
      mp.setCachedParagraphGrouping(
        book: widget.book,
        chapter: widget.chapter,
        paragraphMode: settings.paragraphMode,
        versesLength: verses.length,
        groups: paragraphGroups,
        verseToItem: verseToItemMap,
        itemToVerseIndex: itemToVerseIndex,
      );
    }

    // Only the active page contributes to mp.verseToItemMap (used by
    // pendingJump / selection / highlight). If two alive pages both
    // wrote, one chapter's map would clobber another's.
    if (widget.isActive) {
      mp.setVerseToItemMap(verseToItemMap);
    }

    final hasParagraphData = paragraphGroups.any((g) => g.length > 1);
    final isSelected = mp.selectedVerses.isNotEmpty;
    final dc = widget.deviceClass;

    return Padding(
      padding: EdgeInsets.only(
        right: ResponsiveBreakpoints.readingPadding(dc),
      ),
      child: ScrollablePositionedList.builder(
        itemCount: paragraphGroups.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            // 2026-05-24 (v1.3.14): tighten the gap between the
            // floating chrome and the first verse. The chrome
            // itself measures roughly (status-bar inset + 44 px)
            // tall — vertical padding 4 px + IconButton minHeight
            // 36 px + bottom 4 px. The previous spacer
            // (topInset + 64*menuScale + 12) reserved ~32 px of
            // empty space below the chrome at default scale,
            // which the user reported felt "太大" (too big).
            // New value reserves ~8 px breathing room below the
            // chrome at scale 1.0, scaling proportionally when
            // the user bumps menuScale.
            final topInset = MediaQuery.of(context).padding.top;
            return SizedBox(
                height: topInset + 48 * settings.menuScale + 4);
          }
          final groupIdx = index - 1;
          if (groupIdx < paragraphGroups.length) {
            final group = paragraphGroups[groupIdx];
            int startIdx = 0;
            for (int g = 0; g < groupIdx; g++) {
              startIdx += paragraphGroups[g].length;
            }
            final isFirst = groupIdx == 0;
            SectionHeading? heading;
            if (settings.showSectionTitles) {
              final firstVerse = group.first;
              final englishBook =
                  toEnglish(firstVerse.book) ?? firstVerse.book;
              heading = SectionTitleService.headingAt(
                version: mp.currentVersion,
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
              final intro = BookIntroService.forBook(englishBook);
              if (intro != null) {
                rendered = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
          final bottomInset = MediaQuery.of(context).padding.bottom;
          final isPhoneWidth =
              MediaQuery.of(context).size.width < 560;
          final extra = isSelected
              ? (isPhoneWidth
                  ? 200 * settings.menuScale
                  : 132 * settings.menuScale)
              : 96 * settings.menuScale;
          return SizedBox(height: bottomInset + extra);
        },
        itemScrollController: _controllers.itemScrollController,
        itemPositionsListener: _controllers.itemPositionsListener,
        scrollOffsetController: _controllers.scrollOffsetController,
        scrollOffsetListener: _controllers.scrollOffsetListener,
      ),
    );
  }
}

/// a Positioned(bottom: 0) opaque strip with 5 reader tools:
///   ◀ Prev chapter   📝 My Notes (opens Library)
///   Aa Font sheet   ¶/⟂ Paragraph mode toggle   Next chapter ▶
/// Slides off-screen via AnimatedSlide(0, 1.4) when [visible] is false,
/// and IgnorePointer prevents the hidden bar from catching taps.
/// Hidden when verses are selected (the _SelectionActionBar takes over).
class _BibleReaderBottomBar extends StatelessWidget {
  final bool visible;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onOpenNotes;
  // 2026-05-22 (v1.2.72): Illustrations button — opens the maps
  // picker sheet directly from the bottom bar (was previously buried
  // in the floating-header overflow menu). null hides it gracefully
  // when no chapter is selected.
  final VoidCallback? onOpenIllustrations;
  final VoidCallback onFontSize;
  final bool paragraphMode;
  final VoidCallback onToggleParagraphMode;
  final DeviceClass deviceClass;
  final String locale;

  const _BibleReaderBottomBar({
    required this.visible,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onOpenNotes,
    required this.onOpenIllustrations,
    required this.onFontSize,
    required this.paragraphMode,
    required this.onToggleParagraphMode,
    required this.deviceClass,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final iconSize =
        (settings.fontSize.clamp(16.0, 28.0) * settings.menuScale)
            .toDouble();
    final iconPad = (iconSize * 0.45).clamp(6.0, 10.0);
    // Bottom bar goes edge-to-edge horizontally so the surface meets
    // both screen sides (no margin gap). The inset value used by the
    // top header doesn't apply here — flush bottom-bars are the
    // WeDevote convention.
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.4),
          // 2026-05-22 (v1.2.71): smoother chrome animation.
          // 320 ms + easeInOutCubic feels considerably less abrupt
          // than the previous 200 ms easeOutCubic — both bars now
          // ease in/out at the same pace.
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          child: _GlassSurface(
            // Top-rounded only + opaque so the surface fills all the
            // way down to the screen edge (including the home-indicator
            // safe area), eliminating the previous background-gap.
            radius: 22,
            opaque: true,
            topRoundedOnly: true,
            child: SafeArea(
              top: false,
              // Inner padding keeps the buttons above the home indicator
              // even though the surface itself extends underneath it.
              // Center + ConstrainedBox(maxWidth: 560) keeps the 5
              // buttons grouped on iPad / desktop / wide browsers —
              // surface still goes edge-to-edge but the icons don't
              // drift apart to the corners. On phones (< 560 px wide)
              // the constraint is a no-op — buttons fill width.
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 4 * settings.menuScale,
                        vertical: 4 * settings.menuScale),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                      _BottomBarBtn(
                        icon: Icons.chevron_left_rounded,
                        tooltip:
                            uiStrings['previousChapter']?[locale] ?? 'Previous',
                        onTap: onPrevChapter,
                        iconSize: iconSize,
                        iconPad: iconPad,
                        scheme: scheme,
                      ),
                      _BottomBarBtn(
                        icon: Icons.sticky_note_2_outlined,
                        tooltip:
                            uiStrings['tabNotes']?[locale] ?? 'Notes',
                        onTap: onOpenNotes,
                        iconSize: iconSize,
                        iconPad: iconPad,
                        scheme: scheme,
                      ),
                      _BottomBarBtn(
                        // 2026-05-22 (v1.2.72): Illustrations — sits
                        // between Notes and Font, opens the Maps /
                        // Illustrations bottom-sheet (For this chapter /
                        // For this book / All illustrations).
                        icon: Icons.collections_outlined,
                        tooltip:
                            uiStrings['maps']?[locale] ?? 'Illustrations',
                        onTap: onOpenIllustrations,
                        iconSize: iconSize,
                        iconPad: iconPad,
                        scheme: scheme,
                      ),
                      _BottomBarBtn(
                        icon: Icons.text_fields_rounded,
                        tooltip:
                            uiStrings['fontSize']?[locale] ?? 'Font size',
                        onTap: onFontSize,
                        iconSize: iconSize,
                        iconPad: iconPad,
                        scheme: scheme,
                      ),
                      _BottomBarBtn(
                        // Paragraph mode ON → icon shows "switch to
                        // verse mode"; OFF → icon shows "switch to
                        // paragraph mode". Matches the top-header
                        // toggle so users can flip from either side.
                        icon: paragraphMode
                            ? Icons.format_list_numbered_rounded
                            : Icons.subject_rounded,
                        tooltip: paragraphMode
                            ? (uiStrings['verseMode']?[locale] ?? 'Verse mode')
                            : (uiStrings['paragraphMode']?[locale] ??
                                'Paragraph mode'),
                        onTap: onToggleParagraphMode,
                        iconSize: iconSize,
                        iconPad: iconPad,
                        scheme: scheme,
                        activeColor: paragraphMode ? scheme.primary : null,
                      ),
                      _BottomBarBtn(
                        icon: Icons.chevron_right_rounded,
                        tooltip: uiStrings['nextChapter']?[locale] ?? 'Next',
                        onTap: onNextChapter,
                        iconSize: iconSize,
                        iconPad: iconPad,
                        scheme: scheme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

/// Single icon button for [_BibleReaderBottomBar]. Greyed-out when
/// [onTap] is null; coloured to [activeColor] when the tool is in
/// its "on" state (currently bookmarked, currently listening).
class _BottomBarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double iconSize;
  final double iconPad;
  final ColorScheme scheme;
  final Color? activeColor;

  const _BottomBarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.iconSize,
    required this.iconPad,
    required this.scheme,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
        : (activeColor ?? scheme.onSurface);
    // Hit-target floor: 44 px (Apple HIG) / Material 48 dp. Even when
    // the user has shrunk the text, the bar's buttons must remain
    // comfortable to tap on phones — otherwise the bar becomes a
    // frustrating mis-tap factory on small screens.
    final hitSize = (iconSize + 2 * iconPad).clamp(44.0, 64.0);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: hitSize / 2,
        containedInkWell: false,
        child: SizedBox(
          width: hitSize,
          height: hitSize,
          child: Center(
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
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
  /// Optional widget rendered immediately below the glass header
  /// (still inside the same SafeArea + Positioned region). Used for
  /// the "Today's Reading" card when a reading plan is active.
  final Widget? belowHeader;

  /// 2026-05-21 (v1.2.70): WeDevote-style auto-hide. When false the
  /// header slides up off-screen with a 200 ms animation and stops
  /// catching pointer events.
  final bool chromeVisible;

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
    this.belowHeader,
    this.chromeVisible = true,
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
    // 2026-05-22 (v1.2.71): no more horizontal inset — header is now
    // edge-to-edge (matches bottom-bar pattern).

    // 2026-05-22 (v1.2.71): top header has an edge-to-edge opaque
    // backdrop that extends UP through the status-bar/notch area so
    // there's no visible gap above the floating card. The existing
    // rounded card still sits on top of the backdrop with horizontal
    // margins (Padding below restores the inset).
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !chromeVisible,
        child: AnimatedSlide(
          offset: chromeVisible ? Offset.zero : const Offset(0, -1.4),
          // 2026-05-22 (v1.2.71): smoother chrome animation — matches
          // the bottom bar's timing.
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          // 2026-05-22 (v1.2.71): single edge-to-edge surface that
          // matches the bottom bar's pattern — opaque background,
          // ONLY the bottom corners rounded, surface flush to screen
          // top (covers status-bar / notch area). The previous "inner
          // rounded card with border" inside a Material backdrop made
          // the header read as a floating pill; now it's a single
          // solid bar like the bottom toolbar.
          child: _GlassSurface(
            radius: 22,
            opaque: true,
            bottomRoundedOnly: true,
            child: SafeArea(
            bottom: false,
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
                          // 2026-06-21: leading button is HOME, not a
                          // back-arrow. On iPad split view the back-arrow
                          // (←) collided visually with the sidebar-toggle
                          // / secondary-pane close chevrons — "两个左
                          // arrow" the user found confusing. A home icon
                          // reads unambiguously and jumps straight to the
                          // Dashboard root (what `maybePop` did anyway
                          // when the reader was pushed from home). The
                          // old right-side home action is removed since
                          // it now lives here (no duplicate home icons).
                          // Hidden in the split-view secondary pane
                          // (where `onClose` already sits in this slot).
                          if (onClose == null &&
                              Navigator.of(context).canPop())
                            IconButton(
                              onPressed: () => Navigator.of(context)
                                  .popUntil((r) => r.isFirst),
                              icon: Icon(Icons.home_rounded,
                                  size: iconSize),
                              padding: EdgeInsets.all(iconPad),
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              tooltip:
                                  uiStrings['home']?[locale] ?? 'Home',
                            ),
                          if (onClose != null)
                            IconButton(
                              onPressed: onClose,
                          icon: Icon(Icons.close_rounded, size: iconSize),
                          padding: EdgeInsets.all(iconPad),
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          tooltip: uiStrings['tooltipClose']?[locale] ??
                              'Close',
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
                        // 2026-06-14 (v1.3.73): the book name gets layout
                        // PRIORITY (higher flex) over the version chip. The
                        // version PopupMenuButton used to be unbounded, so a
                        // long localized label (e.g. 新译本 / 原文释经版) took
                        // its full intrinsic width and the Flexible book name
                        // yielded all the way to an empty ellipsis at narrow
                        // widths — "书卷不见了". Now both are Flexible and the
                        // book keeps the larger share; the version ellipsizes.
                        Flexible(
                          flex: 3,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onBookTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              // 2026-05-07: short-book-name policy.
                              // User refined the threshold after
                              // testing 390 / 414 / 747 widths: the
                              // full localized name fits at >= 390 px,
                              // so the cutoff dropped from 450 to 390.
                              // Below 390 we fold to the short form
                              // (帖前 / 1Th); at or above we keep the
                              // formal name. Applies to all locales
                              // uniformly.
                              child: Builder(builder: (ctx) {
                                final screenW =
                                    MediaQuery.of(ctx).size.width;
                                final useShort = screenW < 390;
                                return Text(
                                  useShort
                                      ? '${shortBookName(book, locale)} $chapter'
                                      : '$book $chapter',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                    decoration: TextDecoration.none,
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 2,
                          // 2026-06-22 (v1.3.102): language-grouped popup
                          // — third design pass. Earlier attempts:
                          //   • v1.3.98 modal bottom sheet — user found it
                          //     foreign ("不和谐", slid up from bottom).
                          //   • v1.3.100 custom PopupMenuEntry subclass —
                          //     crashed iPhone Safari deep inside
                          //     PopupMenuRoute layout. Reverted in v1.3.101.
                          // This pass uses the safer pattern:
                          //   - InkWell on the chip → computes the chip's
                          //     RelativeRect and calls
                          //     `showLanguageGroupedVersionMenu`.
                          //   - That uses `showMenu` with ONE regular
                          //     `PopupMenuItem(enabled: false)` whose child
                          //     is a `StatefulBuilder`-style body managing
                          //     the language tab + version rows. NO custom
                          //     PopupMenuEntry subclass.
                          //   - Selected version returns via the Future;
                          //     we forward to `onVersionSelected` (the
                          //     existing pipeline — untouched).
                          // Shared by primary + split-view secondary panes.
                          child: Builder(builder: (chipCtx) {
                            return Tooltip(
                              message: uiStrings['changeVersion']
                                      ?[settings.locale] ??
                                  'Change Version',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final box = chipCtx.findRenderObject()
                                      as RenderBox?;
                                  final overlay = Overlay.of(chipCtx)
                                      .context
                                      .findRenderObject() as RenderBox?;
                                  if (box == null || overlay == null) return;
                                  final topLeft = box.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay);
                                  final bottomRight = box.localToGlobal(
                                      box.size.bottomRight(Offset.zero),
                                      ancestor: overlay);
                                  final position = RelativeRect.fromLTRB(
                                    topLeft.dx,
                                    bottomRight.dy + 4,
                                    overlay.size.width - bottomRight.dx,
                                    overlay.size.height - bottomRight.dy,
                                  );
                                  final picked =
                                      await showLanguageGroupedVersionMenu(
                                    context: chipCtx,
                                    position: position,
                                    currentVersion: version,
                                    settings: settings,
                                  );
                                  if (picked != null) {
                                    onVersionSelected(picked);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: Text(
                                    shortBibleVersionLabel(version),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: settings.fontFamily,
                                      fontFamilyFallback: kCjkFontFallback,
                                      fontSize: fontSize * 0.85,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
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
                    // 2026-06-21: the Home action moved to the LEADING
                    // slot (it replaced the back-arrow). Keeping a second
                    // home button here would show two home icons on the
                    // primary pane, so the right-side one is gone.
                    // 2026-05-24 (v1.3.14): hide the overflow menu in
                    // the split-view secondary pane. User asked for
                    // this — the secondary pane exists only for
                    // version-comparison reading, so Settings /
                    // Library / Highlights / Synopsis / Maps /
                    // Trivia / Listen / etc. (all of which the
                    // primary pane already exposes) just add noise
                    // and risk the user changing app state from a
                    // throwaway pane. `onClose == null` reliably
                    // identifies the primary pane — `home_page.dart`
                    // only sets `onClose` on the secondary
                    // BibleReadingPane.
                    if (onClose == null)
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
                        // 2026-05-24 (v1.3.19): "Listen to chapter"
                        // menu item removed with the 朗读 feature.
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
                        // Round 56: chapter-aware Bible Trivia. Per
                        // user request, the trivia catalogue should
                        // also surface inline from the reader (like
                        // the illustrations / sermons / synopsis
                        // entries above) so users discover relevant
                        // entries without having to leave their
                        // reading.
                        final triviaCount = trivia.triviaForChapter(
                          englishBook: toEnglish(book) ?? book,
                          chapter: chapter,
                        ).length;
                        items.add(PopupMenuItem(
                          value: 'trivia',
                          onTap: () => trivia.showBibleTriviaSheet(
                            context: context,
                            englishBook: toEnglish(book) ?? book,
                            chapter: chapter,
                            locale: locale,
                            settings: context.read<AppSettings>(),
                          ),
                          child: _menuRow(
                            context,
                            icon: triviaCount > 0
                                ? Icons.auto_awesome_rounded
                                : Icons.auto_awesome_outlined,
                            iconColor: triviaCount > 0
                                ? scheme.primary
                                : null,
                            label:
                                uiStrings['bibleTrivia']?[locale] ??
                                    'Bible Trivia',
                            trailing: triviaCount > 0
                                ? '$triviaCount'
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
      ),
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
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                  // 2026-05-24 (v1.2.94): was VisualDensity.compact (~40 px)
        // which violates Apple HIG's 44 pt minimum. Standard density
        // keeps the bar a touch taller but every icon is reliably
        // tappable on phones.
        visualDensity: VisualDensity.standard,
                  padding: EdgeInsets.zero,
                  // 2026-05-10 (v1.2.31): bump min tap target from
                  // 32 → 48 dp for Material/WCAG a11y. Glyph stays
                  // at 18 dp.
                  constraints: const BoxConstraints(
                      minWidth: 48, minHeight: 48),
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
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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

/// 2026-06-18 (v1.3.90): localize the book-name part of a book-intro
/// keyPassage. The data stores it in English (e.g. "John 3:16",
/// "Matthew 28:18-20", "Psalm 23"); this swaps the leading book token
/// for the reading-version-aware name ([localeAwareBookName]) while
/// keeping the chapter:verse(-range) numbers verbatim. Uses the intro's
/// own canonical [BookIntro.englishBook] (every keyPassage references its
/// own book) so the "Psalm" vs canonical "Psalms" spelling can't trip up
/// the name lookup.
String localizeKeyPassage(
    String keyPassage, String englishBook, String locale, String? version) {
  final kp = keyPassage.trim();
  final m = RegExp(r'^(.+?)\s+(\d.*)$').firstMatch(kp);
  if (m == null) return kp; // no numeric tail — leave untouched
  final numeric = m.group(2)!;
  return '${localeAwareBookName(englishBook, locale, version)} $numeric';
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
      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
      fontSize: (fs - 2).clamp(13.0, 16.0).toDouble(),
      color: scheme.onSurface,
      height: 1.55,
    );
    final labelStyle = TextStyle(
      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                            localizeKeyPassage(
                              intro.keyPassage,
                              intro.englishBook,
                              locale,
                              context
                                  .read<MainProvider>()
                                  .currentVersion,
                            ),
                            style: TextStyle(
                              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
