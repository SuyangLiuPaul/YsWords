import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  }

  /// Try the curated daily-verse first; if it doesn't resolve in time,
  /// fall back to a random pick. Either way `_splashVerse` is set
  /// exactly once.
  Future<void> _resolveDailyVerseForSplash() async {
    if (_splashVerseLocked) return;

    // Belt-and-braces: even if everything below times out or
    // throws, we lock to a random pick after 1.2 s so the splash
    // shows *something*. The auto-advance to home is 3 s total, so
    // 1.2 s leaves the user with ~1.8 s of verse view.
    _dailyVerseFallback = Timer(const Duration(milliseconds: 1200), () {
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

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    // 2026-05-10 (v1.2.28): allow the build()-side safety net to
    // re-arm after a manual retry. Without this, a successful
    // recovery wouldn't re-trigger the auto-advance because the
    // one-shot guard was already tripped during the initial
    // (failed) load.
    _advanceScheduledOnce = false;
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
    setState(() => _retrying = false);
    _scheduleAdvanceIfReady();
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _dailyVerseFallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final mainProvider = context.watch<MainProvider>();
    final hasError =
        mainProvider.loadError != null || mainProvider.verses.isEmpty;

    if (hasError) {
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
    if (verse == null) {
      return _buildErrorScaffold(context, settings);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/loading.png',
                    width: logoSize,
                    height: logoSize,
                  ),
                  SizedBox(height: 24 * s),
                  Column(
                    children: [
                      Text(
                        'YsWords',
                        style: TextStyle(
                          fontSize: settings.fontSize * 1.2,
                          fontFamily: settings.fontFamily,
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
                                fontFamily: settings.fontFamily,
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
                                fontFamily: settings.fontFamily,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        SizedBox(width: 10 * s),
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
                          style: TextStyle(
                            fontSize: settings.fontSize * 0.85,
                            fontFamily: settings.fontFamily,
                            color: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.color
                                ?.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
                  fontFamily: settings.fontFamily,
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
                  fontFamily: settings.fontFamily,
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
                    fontFamily: settings.fontFamily,
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
                      fontFamily: settings.fontFamily,
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
    _yswordsClearCacheAndReload();
  }
}

@JS('yswordsClearCacheAndReload')
external void _yswordsClearCacheAndReload();
