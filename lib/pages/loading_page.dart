import 'dart:async';
// 2026-05-20 (v1.2.67): `dart:js_interop` was here, blocking
// native compile. Replaced with a conditional-export helper —
// see lib/utils/clear_cache_helper.dart.
import 'package:yswords/utils/clear_cache_helper.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import '../models/app_settings.dart';
import '../models/verse.dart';
import '../providers/main_provider.dart';
import '../services/daily_verse_fallback.dart';
import '../services/daily_verse_service.dart';
import '../services/fetch_verses.dart';
import '../services/fetch_books.dart';
import '../constants/text_patterns.dart';
import '../constants/ui_strings.dart';
import '../utils/reference_parser.dart';
import '../utils/responsive.dart';
import '../utils/version_mapper.dart' show translateBookName;
import 'home_page.dart';

class LoadingPage extends StatefulWidget {
  final List<Verse> verses;

  /// Optional advance callback. When provided, it is used instead of a
  /// Navigator pushReplacement so the surrounding scaffold remains in
  /// the widget tree.
  final VoidCallback? onAdvance;

  const LoadingPage({super.key, required this.verses, this.onAdvance});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  Timer? _autoAdvance;
  bool _retrying = false;

  /// 2026-06-12 (v1.3.65 robustness): bounded AUTO-retry when the boot
  /// load fails. FetchVerses already retries 3× internally per attempt;
  /// this adds an outer self-heal so a transient asset/network failure
  /// (e.g. a verse-JSON download interrupted during a deploy or a
  /// network blip) recovers on its own instead of dead-ending on the
  /// "Failed to load" scaffold until the user taps Retry. After the
  /// budget is spent the manual scaffold stays as the escape hatch.
  Timer? _autoRetry;
  int _autoRetryCount = 0;
  static const int _kMaxAutoRetries = 3;

  /// 2026-07-21: patience escalation. A fetch can legitimately still
  /// be in flight (see `loading` in build()) well past what feels
  /// like a reasonable wait — a slow/degraded connection (mainland
  /// China accessing a Netlify-hosted global CDN, for one concrete
  /// example) can genuinely take this long without anything having
  /// failed. Rather than leave the user staring at a static "Loading
  /// fast…" with zero signal that anything is still happening, flip
  /// this after a generous threshold to (a) switch to a message that
  /// acknowledges the wait instead of implying it should be instant,
  /// and (b) reveal a manual "Reload page" escape hatch — so even in
  /// the worst case (a genuine hang, not just slowness) the user
  /// isn't trapped with literally no control on screen.
  Timer? _patienceTimer;
  bool _showPatienceHatch = false;
  static const Duration _kPatienceThreshold = Duration(seconds: 15);

  /// 2026-07-21 (v1.3.140): auto-escalation to the SAME recovery the
  /// manual "Reload page (clear cache)" button performs. Confirmed
  /// via a live field report: a user's boot genuinely hung (`FetchVerses`
  /// exhausted all 3 internal attempts — 20/40/60 s), the renderer
  /// was NOT the cause (iOS Safari/WebKit never runs skwasm — no
  /// WasmGC support — so it was already on the canvaskit/JS path both
  /// before and after the v1.3.139 renderer revert), but manually
  /// tapping the reload-cache button fixed it instantly. That's the
  /// signature of a stale/corrupt Service Worker cache surviving
  /// across a deploy — plausible here given this session shipped 5
  /// rapid back-to-back deploys (v1.3.135→139) in quick succession,
  /// exactly the kind of churn that can leave a client's SW pointing
  /// at content that's since been overwritten. `_retry()`'s
  /// `rootBundle.evict()` only clears Flutter's in-memory Dart cache —
  /// it can't force the Service Worker itself to stop serving a stale
  /// cached response. Rather than rely on the user noticing and
  /// tapping the button themselves, auto-escalate to the same hard
  /// reload after a grace period past when the button appears. Safe
  /// to do silently here specifically because LoadingPage is the
  /// SPLASH — there is no in-progress user data (no note being typed,
  /// no scroll position) that a reload could lose.
  Timer? _autoHardReload;
  static const Duration _kAutoHardReloadThreshold = Duration(seconds: 25);

  /// Splash verse — locked ONCE per mount. The user sees the same
  /// verse on the splash AS the dashboard's "Verse of the Day", which
  /// reinforces the day's theme.
  ///
  /// Resolution order:
  ///   1. `DailyVerseService.todayRef()` → parse → match against
  ///      `widget.verses` for the active Bible version. Same logic
  ///      the dashboard uses, so splash and dashboard always agree.
  ///   2. If today's reference doesn't resolve in this version (book
  ///      missing, etc.) OR resolution takes longer than the 1.2 s
  ///      grace period, fall back to a random pick from the loaded
  ///      bundle so the splash never sits empty.
  ///
  /// Once locked, no rebuild causes a re-pick — eliminates the
  /// "verse twitching" issue from before round 43.
  Verse? _splashVerse;
  bool _splashVerseLocked = false;
  Timer? _dailyVerseFallback;
  // 2026-05-10 (v1.2.28): one-shot guard so build()'s safety-net
  // reschedule of `_scheduleAdvanceIfReady` doesn't keep
  // re-cancelling the Timer on every Consumer rebuild during
  // eager pre-load (which fires notifyListeners 12 times).
  // Reset to false in `_retry` so the manual retry path can
  // schedule a fresh advance.
  bool _advanceScheduledOnce = false;

  @override
  void initState() {
    super.initState();
    _resolveDailyVerseForSplash();
    _scheduleAdvanceIfReady();
    _patienceTimer = Timer(_kPatienceThreshold, () {
      if (!mounted) return;
      setState(() => _showPatienceHatch = true);
    });
    // 10 s grace period after the manual button appears (15 s) before
    // performing the same recovery automatically. Re-checks the actual
    // state when it fires rather than assuming — if boot succeeded in
    // the meantime (including the 3 s pre-advance grace window
    // `_scheduleAdvanceIfReady` uses), this is a silent no-op.
    if (kIsWeb) {
      _autoHardReload = Timer(_kAutoHardReloadThreshold, () {
        if (!mounted) return;
        final mp = context.read<MainProvider>();
        final stillStuck = mp.bootInFlight ||
            _retrying ||
            mp.loadError != null ||
            mp.verses.isEmpty;
        if (stillStuck) _hardReload();
      });
    }
  }

  /// Try the curated daily-verse first; if it doesn't resolve in time,
  /// fall back to a random pick. Either way `_splashVerse` is set
  /// exactly once.
  Future<void> _resolveDailyVerseForSplash() async {
    if (_splashVerseLocked) return;

    // 2026-05-24 (v1.3.2): bumped 1.2 s → 5 s. Previously the
    // splash would lock to a random verse if daily_verses.json
    // hadn't loaded within 1.2 s — but on cold-start web /
    // first-launch native, the JSON can take 2-3 s to fetch +
    // parse alongside the 5-10 MB Bible bundle. The 1.2 s budget
    // raced with cold-start and the user reported "loading page
    // verse is not daily verse" — they were seeing the random
    // fallback fire before todayRef() returned. 5 s is well past
    // the realistic cold-start window. main.dart now also calls
    // DailyVerseService.preload() at bootstrap so subsequent
    // todayRef() calls are synchronous-fast and this timer almost
    // never fires.
    _dailyVerseFallback = Timer(const Duration(milliseconds: 5000), () {
      if (_splashVerseLocked) return;
      _lockRandom();
      if (mounted) setState(() {});
    });

    try {
      final ref = await DailyVerseService.todayRef();
      if (_splashVerseLocked) return; // fallback already fired
      if (ref == null) {
        _lockRandom();
      } else {
        final v = _resolveRefAgainstBundle(ref);
        if (v != null) {
          _splashVerse = v;
          _splashVerseLocked = true;
        } else {
          // Same logic the dashboard uses: when the user is on an
          // NT-only edition (LJK1 / LJK2) and today's verse is OT,
          // pull the text from the same-language full-canon bundle
          // (CUVS-YHWH). Falls back to a random local pick if the
          // fallback bundle also can't resolve (e.g. malformed ref).
          final v2 = await _resolveRefViaFallback(ref);
          if (_splashVerseLocked) return;
          if (v2 != null) {
            _splashVerse = v2;
            _splashVerseLocked = true;
          } else {
            _lockRandom();
          }
        }
      }
    } catch (_) {
      if (!_splashVerseLocked) _lockRandom();
    } finally {
      _dailyVerseFallback?.cancel();
      _dailyVerseFallback = null;
      if (mounted) setState(() {});
    }
  }

  /// Match a canonical English reference (e.g. "John 3:16") against
  /// the loaded verse bundle for the user's active Bible version.
  /// Mirrors the dashboard's `_resolveDailyVerse` so the splash and
  /// the dashboard show literally the same Verse object.
  Verse? _resolveRefAgainstBundle(String ref) {
    if (widget.verses.isEmpty) return null;
    final parsed = parseReference(ref);
    if (parsed == null) return null;
    String? activeVersion;
    try {
      activeVersion = context.read<MainProvider>().currentVersion;
    } catch (_) {}
    final localBook = activeVersion == null
        ? parsed.englishBook
        : translateBookName(parsed.englishBook, activeVersion);
    final targetVerse = parsed.verseStart ?? 1;
    for (final v in widget.verses) {
      if (v.book == localBook &&
          v.chapter == parsed.chapter &&
          v.verse == targetVerse) {
        return v;
      }
    }
    // Same book/chapter, any verse — better than no match.
    for (final v in widget.verses) {
      if (v.book == localBook && v.chapter == parsed.chapter) {
        return v;
      }
    }
    return null;
  }

  /// Try resolving the reference via DailyVerseFallback. Used when
  /// the primary version (e.g. LJK1) doesn't ship the requested
  /// book. Returns null when no fallback exists OR the fallback
  /// bundle also doesn't contain the verse.
  Future<Verse?> _resolveRefViaFallback(String ref) async {
    final parsed = parseReference(ref);
    if (parsed == null) return null;
    String? activeVersion;
    try {
      activeVersion = context.read<MainProvider>().currentVersion;
    } catch (_) {}
    if (activeVersion == null) return null;
    final result = await DailyVerseFallback.resolve(
      englishBook: parsed.englishBook,
      chapter: parsed.chapter,
      verseNumber: parsed.verseStart ?? 1,
      currentVersion: activeVersion,
    );
    return result?.verse;
  }

  void _lockRandom() {
    if (_splashVerseLocked) return;
    // Prefer the live provider list — widget.verses is a snapshot
    // taken at LoadingPage construction time and can be empty if the
    // FetchVerses future hadn't completed yet. Falling back to the
    // provider lets us still pick a random verse instead of stranding
    // the user on the bare "No verses available" screen.
    var pool = widget.verses;
    if (pool.isEmpty) {
      try {
        pool = context.read<MainProvider>().verses;
      } catch (_) {
        pool = const [];
      }
    }
    if (pool.isEmpty) return;
    _splashVerse = (List<Verse>.from(pool)..shuffle()).first;
    _splashVerseLocked = true;
  }

  void _scheduleAdvanceIfReady() {
    final mainProvider = context.read<MainProvider>();
    if (mainProvider.loadError != null || mainProvider.verses.isEmpty) {
      // Stay on the splash with the error UI; do not auto-advance.
      return;
    }
    _autoAdvance?.cancel();
    _autoAdvance = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final advance = widget.onAdvance;
      if (advance != null) {
        advance();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    });
  }

  /// Schedule one auto-retry with linear backoff (2 s, 4 s, 6 s) while
  /// budget remains and no retry is already in flight. Idempotent — a
  /// pending timer isn't re-armed. Called from build() whenever the
  /// error state is showing for a genuine load failure.
  void _maybeScheduleAutoRetry() {
    if (_retrying || _autoRetry != null) return;
    if (_autoRetryCount >= _kMaxAutoRetries) return;
    _autoRetryCount++;
    final delay = Duration(seconds: 2 * _autoRetryCount);
    _autoRetry = Timer(delay, () {
      _autoRetry = null;
      if (!mounted) return;
      final mp = context.read<MainProvider>();
      // Only auto-retry if still in a real error state.
      if (mp.loadError != null || mp.verses.isEmpty) {
        _retry();
      }
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    _autoRetry?.cancel();
    _autoRetry = null;
    setState(() => _retrying = true);
    final mainProvider = context.read<MainProvider>();
    // Clear the previous error first so the UI immediately reflects
    // that retry has started — without this, a retry that lands on
    // the same error string never triggers a rebuild and the user
    // can't tell whether the button did anything.
    mainProvider.setLoadError(null);
    // Bust the paragraph-map cache. If the FIRST load failed mid-way
    // (e.g. service worker returned a partial response, network
    // hiccup) the cache may have stuck a corrupt-or-incomplete copy
    // that subsequent retries would happily reuse, making the
    // button feel broken until the user did a full page refresh.
    // Round 56 user feedback: "if you press retry it doesn't work,
    // do you have to refresh the page". Clearing the cache is
    // exactly the recovery step that a page refresh produced
    // implicitly.
    FetchVerses.clearParagraphCache();
    try {
      // 2026-05-10 (v1.2.10): same onAttempt wiring as main.dart's
      // bootstrap so the manual-retry path also shows "Retrying…
      // (2/3)" if an internal retry kicks in. Manual-retry +
      // internal-retry stack: pressing Retry once gives up to 3
      // FetchVerses attempts, so the user effectively gets 6
      // attempts total (one 3-attempt cycle on auto-boot, then 3
      // more on the manual click).
      await FetchVerses.execute(
        mainProvider: mainProvider,
        onAttempt: (attempt, _) =>
            mainProvider.setLoadProgress(attempt, 3),
      );
      await FetchBooks.execute(mainProvider: mainProvider);
      mainProvider.setLoadProgress(0, 0);
      if (mainProvider.verses.isNotEmpty) {
        final first = mainProvider.verses.first;
        if (mainProvider.currentBook == null ||
            mainProvider.currentChapter == null) {
          mainProvider.setCurrentChapter(
              book: first.book, chapter: first.chapter);
          mainProvider.updateCurrentVerse(verse: first);
        }
        mainProvider.setLoadError(null);
      } else {
        mainProvider.setLoadError('empty');
      }
    } catch (e) {
      // Now that FetchVerses.execute rethrows (it used to swallow),
      // the user gets the actual cause — e.g. an asset-load failure
      // that includes the path that 404'd, instead of a generic
      // "verses are empty" message.
      mainProvider.setLoadError(e.toString());
      mainProvider.setLoadProgress(0, 0);
    }
    if (!mounted) return;
    // 2026-05-10 (v1.2.29): allow the build()-side safety net to
    // re-arm after a manual retry. Reset POST-await so a rebuild
    // triggered earlier by `setLoadError(null)` (line ~230) can't
    // pre-fire a stale-cached-verses Timer mid-fetch. Without this
    // post-await placement, an in-flight retry whose verses cache
    // is non-empty could advance to home with stale data while the
    // FetchVerses retry is still grinding. (The race is latent in
    // current code — loadError is only set when verses ARE empty —
    // but the defensive ordering closes it for free.)
    _advanceScheduledOnce = false;
    setState(() => _retrying = false);
    _scheduleAdvanceIfReady();
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _autoRetry?.cancel();
    _dailyVerseFallback?.cancel();
    _patienceTimer?.cancel();
    _autoHardReload?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final mainProvider = context.watch<MainProvider>();
    // 2026-07-21: a fetch is legitimately still running — either the
    // original cold-boot bootstrap (main.dart's `_bootstrap()`, which
    // can take up to ~60 s on a slow connection but gets cut loose
    // from the splash by an unrelated 4 s watchdog) or a manual retry
    // from this page. While either is true, `verses.isEmpty` is the
    // EXPECTED state, not evidence of failure — see
    // MainProvider.bootInFlight's doc comment for the full story.
    final loading = mainProvider.bootInFlight || _retrying;
    final hasError = !loading &&
        (mainProvider.loadError != null || mainProvider.verses.isEmpty);

    if (hasError) {
      // v1.3.65: kick off a bounded auto-retry so a transient boot
      // failure self-heals before the user has to do anything. The
      // manual Retry / Clear-cache buttons stay as the escape hatch
      // once the auto budget is spent.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeScheduleAutoRetry();
      });
      return _buildErrorScaffold(context, settings);
    }

    // 2026-05-10 (v1.2.28): safety-net reschedule. Bug: when the
    // splash watchdog in `_AppRoot` (4 s) fires BEFORE
    // FetchVerses.execute resolves on slow connections, LoadingPage
    // gets mounted with empty `mainProvider.verses` and the initState
    // call to `_scheduleAdvanceIfReady` returns early without
    // arming the 3 s auto-advance Timer. Once verses arrive (and the
    // eager pre-load runs to 12/12), no one re-arms it — the user
    // sees the splash stuck on "Loading versions: 12/12".
    //
    // Fix: the first time we observe a non-error build (verses
    // populated, no loadError), schedule the advance via a post-
    // frame callback so it runs AFTER the current build completes.
    // The `_advanceScheduledOnce` flag prevents the eager pre-load's
    // 12 notifyListeners callbacks from cancelling-and-rearming the
    // Timer on every rebuild (which would never let it fire).
    if (!_advanceScheduledOnce) {
      _advanceScheduledOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleAdvanceIfReady();
      });
    }

    // 2026-07-21: opportunistic re-lock. `_resolveDailyVerseForSplash()`
    // only runs once (in initState) and both of its resolution paths —
    // the todayRef() lookup and the 5 s fallback timer — bail out
    // without locking when the verse pool is empty at the moment they
    // run (see `_lockRandom()`). On the exact slow-boot path this file
    // now handles gracefully (mainProvider.verses still empty past the
    // 4 s splash watchdog), that resolution window closes before verses
    // exist, so `_splashVerse` was getting stuck permanently null even
    // after a fully successful background load — which then fell
    // through to the error scaffold below for a load that never
    // actually failed. Retry here on every build once verses exist;
    // `_lockRandom()` is idempotent (no-ops once locked) so this is
    // free on the common fast-load path where locking already
    // succeeded in initState.
    if (!_splashVerseLocked && mainProvider.verses.isNotEmpty) {
      _lockRandom();
    }

    // Frozen by _resolveDailyVerseForSplash() — either today's
    // curated daily verse (matches the dashboard's "Verse of the
    // Day") or a random fallback. The splash shows just the logo
    // + name during the brief async resolve.
    final verse = _splashVerse;

    final original = verse?.text.replaceAll('\n', '') ?? '';
    final raw = sanitizeForSearch(original);
    // Split so that each [word] is its own part
    final parts = raw
        .splitMapJoin(
          squarePattern,
          onMatch: (m) => '||${m[0]}||',
          onNonMatch: (n) => n,
        )
        .split('||');

    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final s = ResponsiveBreakpoints.spacingScale(dc);
    final logoSize = ResponsiveBreakpoints.loadingLogoSize(dc);

    // When _splashVerse is null but mainProvider.verses isn't empty,
    // we'd otherwise sit with bare text and no way out — the auto-
    // advance timer might also be cancelled. Reuse the error scaffold
    // (with retry button) so the user always has a way to recover
    // without quit-and-relaunch. This is the path the user hit when
    // they reported "sometimes it says no verse but should have".
    //
    // 2026-07-21: EXCEPT while a fetch is still legitimately running
    // (`loading` — see above) — `_splashVerse` can't resolve because
    // there's nothing to pick from yet (verses is still empty), which
    // is expected, not a failure. Show the friendly booting scaffold
    // instead of the alarming error one; it clears itself the moment
    // verses land and this widget rebuilds.
    if (verse == null) {
      return loading
          ? _buildBootingScaffold(context, settings)
          : _buildErrorScaffold(context, settings);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // v1.3.75: tint the loading logo with the chosen theme
                  // colour so it matches the themed app icon + the
                  // "YsWords / 雅偉之言" text below. loading.png is a single-
                  // hue silhouette (mostly #295E8C with alpha edges), so a
                  // srcIn tint recolours it cleanly without losing the mark.
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      'assets/loading.png',
                      width: logoSize,
                      height: logoSize,
                    ),
                  ),
                  SizedBox(height: 24 * s),
                  Column(
                    children: [
                      Text(
                        'YsWords',
                        style: TextStyle(
                          fontSize: settings.fontSize * 1.2,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4 * s),
                      Text(
                        '雅伟之言',
                        style: TextStyle(
                          fontSize: settings.fontSize * 1.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 48 * s),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0 * s),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: parts.map<InlineSpan>((part) {
                          final match = squarePattern.firstMatch(part);
                          if (match != null) {
                            return TextSpan(
                              text: match.group(1),
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                height: 1.5,
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.dotted,
                                decorationColor:
                                    Theme.of(context).colorScheme.primary,
                                decorationThickness: 2.0,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            );
                          } else {
                            return TextSpan(
                              text: part,
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                height: 1.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            );
                          }
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 8 * s),
                  // 2026-05-10 (v1.2.21): added maxLines + overflow.
                  // The reference (e.g. "1 Thessalonians 5:16-18")
                  // could clip on narrow viewports; ellipsis is
                  // the expected fallback rather than wrapping.
                  Text(
                    '${verse.book} ${verse.chapter}:${verse.verseLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: settings.fontSize * 0.9,
                      color: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                  // 2026-05-10 (v1.2.10): in-flight load-progress
                  // subtitle. While the asset fetch is running we
                  // paint either "Loading verses…" (attempt 1, the
                  // common case — silent on fast networks) or
                  // "Retrying… (n/m)" (attempts 2+, when the user
                  // would otherwise wonder if the app is frozen).
                  // Goes away as soon as the load settles.
                  // 2026-05-10 (v1.2.18): added a third state to
                  // this subtitle. Priority: version-pre-load
                  // progress > verse-load retry > "Loading verses…".
                  // Only ONE shows at a time.
                  if (mainProvider.loadAttempt > 0 ||
                      mainProvider.versionPreloadTotal > 0) ...[
                    SizedBox(height: 18 * s),
                    Text(
                      mainProvider.versionPreloadTotal > 0
                          ? ((uiStrings['loadingVersionsProgress']
                                      ?[settings.locale] ??
                                  'Loading versions: {n}/{total}')
                              .replaceFirst(
                                  '{n}',
                                  mainProvider.versionPreloadCount
                                      .toString())
                              .replaceFirst(
                                  '{total}',
                                  mainProvider.versionPreloadTotal
                                      .toString()))
                          : (mainProvider.loadAttempt <= 1
                              ? (uiStrings['loadingVerses']
                                      ?[settings.locale] ??
                                  'Loading verses…')
                              : ((uiStrings['retryingAttempt']
                                          ?[settings.locale] ??
                                      'Retrying… ({n}/{max})')
                                  .replaceFirst(
                                      '{n}',
                                      mainProvider.loadAttempt
                                          .toString())
                                  .replaceFirst(
                                      '{max}',
                                      mainProvider.loadMaxAttempts
                                          .toString()))),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: settings.fontSize * 0.85,
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        color: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.color
                            ?.withValues(alpha: 0.65),
                      ),
                    ),
                    SizedBox(height: 10 * s),
                    // Determinate when we already have exact counts
                    // for free (version pre-load); indeterminate
                    // during the verse-fetch retry sub-phase, where
                    // there's no real progress signal to show.
                    _buildDownloadBar(
                      context,
                      value: mainProvider.versionPreloadTotal > 0
                          ? mainProvider.versionPreloadCount /
                              mainProvider.versionPreloadTotal
                          : null,
                    ),
                  ],
                  // 2026-07-21: same patience escalation as the
                  // booting scaffold. This normal splash is the one
                  // that actually gets stuck showing on a genuinely
                  // slow boot — `_splashVerse` can resolve (via the
                  // 5 s random-fallback) well before FetchVerses does,
                  // and the loadAttempt/versionPreload subtitle above
                  // only covers the FetchVerses sub-phase, not e.g. a
                  // slow/blocked Firebase-auth network call earlier in
                  // `_bootstrap()` — which otherwise left this screen
                  // showing zero signal that anything was happening.
                  if (loading) _buildPatienceFooter(context, settings),
                ],
              ),
      ),
    );
  }

  /// 2026-07-21: friendly "still loading" scaffold — logo + spinner +
  /// a "loading fast" message, no alarming cloud-off icon and no
  /// Retry button (there's nothing to retry; the in-flight fetch just
  /// needs more time). Shown instead of `_buildErrorScaffold` whenever
  /// `loading` is true in build(), i.e. the cold-boot bootstrap or a
  /// manual retry is genuinely still running. Once that fetch resolves
  /// (success OR final failure) this widget rebuilds into either the
  /// normal verse splash or the real error scaffold.
  Widget _buildBootingScaffold(BuildContext context, AppSettings settings) {
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final s = ResponsiveBreakpoints.spacingScale(dc);
    final logoSize = ResponsiveBreakpoints.loadingLogoSize(dc);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.primary,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                'assets/loading.png',
                width: logoSize,
                height: logoSize,
              ),
            ),
            SizedBox(height: 24 * s),
            Text(
              'YsWords',
              style: TextStyle(
                fontSize: settings.fontSize * 1.2,
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4 * s),
            Text(
              '雅伟之言',
              style: TextStyle(
                fontSize: settings.fontSize * 1.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 40 * s),
            Text(
              uiStrings['bootLoadingMessage']?[settings.locale] ??
                  'Loading fast…',
              style: TextStyle(
                fontSize: settings.fontSize * 0.9,
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                color: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.color
                    ?.withValues(alpha: 0.75),
              ),
            ),
            SizedBox(height: 12 * s),
            _buildDownloadBar(context),
            _buildPatienceFooter(context, settings),
          ],
        ),
      ),
    );
  }

  /// 2026-07-21: web download progress bar. User feedback: a bare
  /// spinner reads as ambiguous ("is this frozen or working?"); a
  /// progress bar reads unambiguously as "actively downloading" —
  /// and since it's only ever visible while `loading` is true, it
  /// naturally shows up almost exclusively on a genuine first-time
  /// (uncached) load: once the service worker has the Bible-JSON
  /// asset cached, the fetch resolves near-instantly and this bar
  /// barely has time to render. Deliberately indeterminate (no byte-
  /// level tracking) EXCEPT for the one sub-case where exact progress
  /// is already free: `versionPreloadCount`/`versionPreloadTotal`.
  /// `rootBundle.loadString()` (what `FetchVerses` actually uses) has
  /// no progress API, so a byte-accurate bar would mean rewriting the
  /// core fetch path — the same code both of today's earlier
  /// incidents touched — for a purely cosmetic win. Not worth the
  /// risk; scoped to UI only.
  Widget _buildDownloadBar(BuildContext context, {double? value}) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 4,
          backgroundColor: scheme.primary.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation<Color>(
            scheme.primary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  /// 2026-07-21: shared "still waiting, here's an out" footer for both
  /// the booting scaffold and the normal (verse-resolved) splash — the
  /// latter is the one a genuinely slow boot (e.g. a blocked/degraded
  /// path to a Google auth server on a network like mainland China's)
  /// actually gets stuck showing, since the daily-verse resolve can
  /// succeed well before FetchVerses does. Renders nothing until
  /// `_showPatienceHatch` flips (15 s in), then reveals a single
  /// "clear cache & reload" button — just one control, no extra
  /// copy — so the user always has SOMETHING to do rather than a
  /// static screen with no signal of whether it's working or frozen.
  Widget _buildPatienceFooter(BuildContext context, AppSettings settings) {
    if (!_showPatienceHatch || !kIsWeb) return const SizedBox.shrink();
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final s = ResponsiveBreakpoints.spacingScale(dc);
    return Padding(
      padding: EdgeInsets.only(top: 20 * s),
      child: TextButton.icon(
        onPressed: _hardReload,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text(
          uiStrings['hardReloadPage']?[settings.locale] ??
              'Reload page (clear cache)',
          style: TextStyle(
            fontSize: (settings.fontSize - 2).clamp(11.0, 14.0),
            fontFamily: settings.fontFamily,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, AppSettings settings) {
    final title =
        uiStrings['loadErrorTitle']?[settings.locale] ?? 'Failed to load';
    final body = uiStrings['loadErrorBody']?[settings.locale] ??
        'Could not load Bible verses. Please check your connection and retry.';
    final retryLabel = uiStrings['retry']?[settings.locale] ?? 'Retry';

    // 2026-05-10 (v1.2.12): pull mainProvider here so the new
    // "Show details" expander + the conditional sizing of the
    // Reload-page button can read `loadError`. listen: false
    // because rebuild on loadError changes is already triggered
    // by the parent's `context.watch<MainProvider>()` in build().
    final mainProvider =
        Provider.of<MainProvider>(context, listen: false);

    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final s = ResponsiveBreakpoints.spacingScale(dc);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32 * s),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64 * s,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 16 * s),
              Text(
                title,
                style: TextStyle(
                  fontSize: settings.fontSize * 1.1,
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: settings.fontSize,
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  height: 1.5,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 24 * s),
              ElevatedButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: _retrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  retryLabel,
                  style: TextStyle(
                    fontSize: settings.fontSize,
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
              // 2026-05-10 (v1.2.12): "Reload page" escape hatch.
              // The Retry button above re-runs FetchVerses inside
              // the same page lifecycle. If the actual reason for
              // failure is a stale service-worker bundle (which
              // CAN happen right after a fresh deploy, even with
              // the no-cache headers) then any number of in-page
              // retries will hit the same broken code. This button
              // calls into web/index.html's
              // window.yswordsClearCacheAndReload() which
              // unregisters every SW + nukes every cache bucket
              // before doing a hard `location.reload()`. User-
              // localStorage (profiles / bookmarks / settings)
              // stays intact — only browser/SW cache is cleared.
              // Web-only; on native (future) this row is hidden.
              if (kIsWeb) ...[
                SizedBox(height: 8 * s),
                TextButton.icon(
                  onPressed: _retrying ? null : _hardReload,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    uiStrings['hardReloadPage']?[settings.locale] ??
                        'Reload page (clear cache)',
                    style: TextStyle(
                      fontSize: (settings.fontSize - 2)
                          .clamp(11.0, 14.0),
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
              ],
              // Diagnostic: collapsible "Show details" expanding to
              // the raw error message. Helps the user describe what
              // failed when they report it; lets the dev see real
              // stack traces in the wild without console access.
              if (mainProvider.loadError != null &&
                  mainProvider.loadError != 'empty') ...[
                SizedBox(height: 12 * s),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 320 * s),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.symmetric(
                          horizontal: 8 * s),
                      childrenPadding: EdgeInsets.fromLTRB(
                          12 * s, 0, 12 * s, 8 * s),
                      title: Text(
                        uiStrings['showDetails']?[settings.locale] ??
                            'Show details',
                        style: TextStyle(
                          fontSize: (settings.fontSize - 2)
                              .clamp(11.0, 14.0),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      children: [
                        SelectableText(
                          mainProvider.loadError!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: (settings.fontSize - 4)
                                .clamp(10.0, 12.0),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Last-resort recovery: nuke every browser/SW cache bucket and
  /// reload the page. The same JS helper Settings → "Clear cache &
  /// reload" uses, just exposed on the load-error scaffold so users
  /// don't have to reach a working dashboard before they can fix a
  /// stale-bundle problem.
  void _hardReload() {
    if (!kIsWeb) return;
    clearCacheAndReload();
  }
}
