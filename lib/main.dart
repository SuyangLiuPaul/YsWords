import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yswords/constants/build_flags.dart';
import 'package:yswords/models/sermon.dart';
import 'package:yswords/pages/dashboard_page.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/loading_page.dart';
import 'package:yswords/pages/sermon_detail_page.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart' show BibleReference;
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/daily_verse_service.dart';
import 'package:yswords/services/error_reporter.dart';
import 'package:yswords/utils/breadcrumb_observer.dart';
import 'package:yswords/services/notification_scheduler.dart'
    as notif_scheduler;
import 'package:yswords/services/realtime_db_sync_service.dart';
import 'package:yswords/services/offline_pack_service.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/book_intro_service.dart';
import 'package:yswords/services/section_title_service.dart';
import 'package:yswords/services/url_sync_service.dart';
import 'package:provider/provider.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/theme_accent.dart'
    show darkReadingAccent, onAccentColor;

void main() {
  // 2026-06-11 audit: silence debugPrint in release builds. ~100
  // callsites across services/pages log sync + auth detail; debugPrint
  // is NOT stripped from release builds, so on web all of it landed in
  // the browser console (information disclosure + log spam). One
  // global no-op here beats guarding every callsite. ErrorReporter is
  // unaffected — it reports via its own pipeline, not debugPrint.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // 2026-06-11 (v1.3.61): snapshot the deep-link hash before the
  // engine boots — by first frame, Flutter web reports the initial
  // route and overwrites the URL fragment, losing any shared link
  // (`#/revelation/17:1?v=biblexg-v2`) before UrlSyncService.init
  // gets to read it. Native targets no-op.
  UrlSyncService.captureBootHash();

  // 2026-05-24 (v1.3.21): wrap the whole entrypoint in
  // runZonedGuarded so uncaught zone errors (async work that
  // bubbles past PlatformDispatcher) still reach the reporter.
  // ErrorReporter.init() inside the zone installs the
  // FlutterError.onError + PlatformDispatcher hooks itself, so
  // we don't pre-set them here — ErrorReporter chains them
  // properly.
  runZonedGuarded<void>(() {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorReporter.init();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => MainProvider()),
          ChangeNotifierProvider(create: (context) => AppSettings()),
        ],
        child: const MainApp(),
      ),
    );
  }, (error, stack) {
    ErrorReporter.report(error, stack, source: 'Zone');
  });
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  bool _loading = true;

  /// Watchdog that forces the splash off after 4 s even if bootstrap
  /// is still grinding. Stored in a field (Round 56 audit fix) so we
  /// can cancel it on dispose — without this, hot-restart in dev or
  /// a fast unmount in prod would still tick and try to call
  /// setState on a disposed State.
  Timer? _splashWatchdog;

  @override
  void initState() {
    super.initState();
    // 2026-05-24 (v1.3.22): subscribe to lifecycle events so we can
    // receive `didHaveMemoryPressure()` callbacks from iOS / Android.
    // See the override below for the cache-drop behaviour.
    WidgetsBinding.instance.addObserver(this);
    _splashWatchdog = Timer(const Duration(seconds: 4), () {
      if (_loading && mounted) {
        setState(() {
          _loading = false;
        });
      }
    });
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _splashWatchdog?.cancel();
    super.dispose();
  }

  /// 2026-05-24 (v1.3.22): OS low-memory hook.
  ///
  /// Triggered by iOS `UIApplicationDidReceiveMemoryWarningNotification`
  /// or Android `onTrimMemory(TRIM_MEMORY_RUNNING_LOW)` /
  /// `TRIM_MEMORY_RUNNING_CRITICAL`. Before we shipped this hook the
  /// app held 13 parsed verse lists (~78 MB) + the paragraph LRU
  /// (~30 MB) + the Flutter image cache in RAM at all times. On
  /// iPhone-SE-class devices and mid-range Android the OS could
  /// silently terminate us with no chance to clean up — the user
  /// would just see the app "crash" when they backgrounded it.
  ///
  /// We now respond by dropping the three caches the OS most wants
  /// us to surrender. The reading pane's CURRENT verse list and
  /// paragraph map are unaffected — they're held via reference in
  /// the active providers, not the LRU.
  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    debugPrint('[v1.3.22] OS memory pressure — dropping caches');
    try {
      // Tier 1: Flutter image cache (avatars, evidence images, news
      // thumbs, illustrations).
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {/* ignore */}
    try {
      // Tier 2: verse + paragraph LRU caches on MainProvider.
      // Provider's dropCachesOnMemoryPressure() preserves the
      // currently-active version (drop only inactive entries).
      if (mounted) {
        context.read<MainProvider>().dropCachesOnMemoryPressure();
      }
    } catch (_) {/* ignore */}
    // Leave a breadcrumb so the error monitor knows we cleared
    // caches — useful context if a crash follows shortly after.
    ErrorReporter.breadcrumb('memory:pressure', data: 'caches dropped');
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final mainProvider = context.read<MainProvider>();
    final appSettings = context.read<AppSettings>();

    try {
      // Profiles must be initialised before MainProvider.restoreState
      // because that step reads highlights / notes / bookmarks under
      // the active profile's namespace. Same goes for ReadingPlanService
      // calls that fire while the home page builds.
      await ProfileService.instance.init();
      // Firebase auth is best-effort — falls through gracefully if
      // the user hasn't filled in lib/firebase_options.dart yet.
      // After auth init we wire up CloudSyncService so any future
      // local changes mirror to Firestore (when signed in).
      //
      // 2026-05-09 (v1.2.0 — China mode): in the China build, skip
      // Firebase init entirely. `*.googleapis.com` /
      // `*.firebaseio.com` / `accounts.google.com` are all blocked
      // by the Great Firewall, so the call sits there for the full
      // 4 s watchdog window before the splash gives up. Skipping
      // makes the boot instant. RealtimeDbSyncService and Drive
      // sync are also no-ops in this mode — they only do anything
      // once a Firebase user signs in, and that's impossible without
      // Firebase Auth working.
      if (!kChinaMode) {
        // 2026-07-21: bounded. `CloudAuthService.instance.init()`
        // makes multiple awaited network calls to Google's own
        // servers (`Firebase.initializeApp()`, then
        // `auth.getRedirectResult()`) — both blocked or heavily
        // throttled on networks that can't reach Google (mainland
        // China's Great Firewall being the most common case; the
        // China-flavor build sidesteps this entirely by skipping
        // Firebase, see the comment above, but nothing stopped an
        // INTERNATIONAL-flavor user from being on such a network).
        // Without a bound, a blocked/degraded path here could stall
        // the ENTIRE boot sequence — including FetchVerses, which
        // runs after this — for as long as the browser's own TCP/TLS
        // timeout takes, far longer than any reasonable splash wait.
        // User report: "in china very slow then loaded, aus faster" —
        // this is why. Firebase auth was never required to read the
        // Bible, so cap it generously and let boot proceed without
        // cloud auth if it doesn't settle in time; CloudAuthService
        // keeps trying on its own ChangeNotifier timeline and
        // Settings' sign-in becomes available once (if) it resolves.
        try {
          await CloudAuthService.instance.init().timeout(
                const Duration(seconds: 8),
              );
        } catch (e, st) {
          debugPrint('CloudAuthService.init timed out or failed: $e\n$st');
        }
        // Round 56 day-3 (2026-05-06): switched cloud sync from
        // Firestore (CloudSyncService) to Google Drive AppData
        // (DriveSyncService). User reported the Firestore path was
        // not actually syncing across devices reliably — likely
        // because Flutter web's Firestore WebChannel transport is
        // blocked on some networks and the IndexedDB cross-tab sync
        // is fragile. Drive AppData is plain HTTPS to drive.googleapis
        // .com, lives in the user's own Drive (no Firebase costs),
        // and needs zero setup ("appDataFolder" is automatic — no
        // folder picker). CloudSyncService is left in place as a
        // legacy migration source but no longer init'd.
        RealtimeDbSyncService.instance.init();
      }
      // 2026-05-07 (v18 audit): the three pre-warm calls below are
      // intentionally unawaited (best-effort hydration that should
      // not block the splash → home transition). But silently
      // dropping their failures meant a stuck cache in production
      // never surfaced. We attach a debug-only catchError so the
      // failure shows up in the browser console without escalating
      // to a user-facing error.
      // Restore "what's been pre-downloaded for offline" so the
      // Settings → Offline Pack card can render an accurate label
      // on first paint instead of flickering "Not downloaded".
      // ignore: unawaited_futures
      OfflinePackService.instance.hydrate().catchError((Object e, StackTrace st) {
        debugPrint('OfflinePackService.hydrate failed: $e\n$st');
      });
      // Pre-warm the section-titles cache so the first chapter
      // render already has paragraph headings ready.
      // ignore: unawaited_futures
      SectionTitleService.ensureLoaded().catchError((Object e, StackTrace st) {
        debugPrint('SectionTitleService.ensureLoaded failed: $e\n$st');
      });
      // ignore: unawaited_futures
      BookIntroService.ensureLoaded().catchError((Object e, StackTrace st) {
        debugPrint('BookIntroService.ensureLoaded failed: $e\n$st');
      });
      // 2026-05-19 (v1.2.55): reverted the v1.2.53 cross-version
      // LEB translator-insights overlay. User feedback: "remove
      // that LEB notes format from all other versions" — LEB's
      // notes are tied to LEB's specific phrasing, so projecting
      // them into KJV / CUV / CNV pages was noisy and tonally
      // off. The inline `[supplied]` / `{clarification}` +
      // `<note:>` format that's NATIVELY in LEB + biblexg-v2
      // continues to render as before; only the cross-version
      // overlay layer was dropped.
      await appSettings.loadSettings();
      await mainProvider.restoreState();

      if (mainProvider.verses.isEmpty) {
        // 2026-05-10 (v1.2.10): pass an onAttempt callback so the
        // loading splash can show "Retrying… (2/3)" instead of just
        // sitting on the logo while a transient asset-fetch failure
        // gets retried. The default 3 attempts × 12 s timeout means
        // up to ~37 s wall-clock before we bail to the manual
        // error scaffold — but in practice the first attempt
        // succeeds within a couple seconds.
        await FetchVerses.execute(
          mainProvider: mainProvider,
          onAttempt: (attempt, _) =>
              mainProvider.setLoadProgress(attempt, 3),
        );
      }
      await FetchBooks.execute(mainProvider: mainProvider);
      // Clear the in-flight progress now that the load settled
      // (whether it succeeded or threw — the catch block below also
      // resets it). Splash subtitle disappears.
      mainProvider.setLoadProgress(0, 0);

      if (mainProvider.verses.isEmpty) {
        mainProvider.setLoadError('empty');
      } else {
        mainProvider.setLoadError(null);
      }

      // Validate restored state or fallback
      if (mainProvider.currentBook != null &&
          mainProvider.currentChapter != null &&
          mainProvider.verses.any((v) =>
              v.book == mainProvider.currentBook &&
              v.chapter == mainProvider.currentChapter)) {
        final match = mainProvider.verses.firstWhere(
          (v) =>
              v.book == mainProvider.currentBook &&
              v.chapter == mainProvider.currentChapter,
          orElse: () => mainProvider.verses.first,
        );
        mainProvider.updateCurrentVerse(verse: match);
      } else if (mainProvider.verses.isNotEmpty) {
        final firstVerse = mainProvider.verses.first;
        mainProvider.setCurrentChapter(
            book: firstVerse.book, chapter: firstVerse.chapter);
        mainProvider.updateCurrentVerse(verse: firstVerse);
      }
    } catch (e, st) {
      debugPrint('Bootstrap failed: $e\n$st');
      mainProvider.setLoadError(e.toString());
      // Clear the splash subtitle on failure too — the load-error
      // scaffold takes over from here.
      mainProvider.setLoadProgress(0, 0);
    }

    // 2026-05-10 (v1.2.25 — restored eager-all-13): user noticed
    // the splash showed "Loading versions: 4/4" instead of all 13
    // and chose option B (slower boot, splash shows full 1/13 →
    // 13/13 progress, every post-boot switch is instant for the
    // entire session). Reverts the v1.2.22 hybrid split back to
    // v1.2.18's all-eager pattern but inherits the v1.2.19+
    // bug fixes (paragraph-cache LRU evict on version switch,
    // pendingJump clear, etc).
    //
    // 2026-05-24 (v1.3.4) PERF: NON-BLOCKING version preload.
    // v1.2.25 made this `await`-blocking, so splash sat for ~25 s
    // until all 13 Bible versions had been json.decode'd into the
    // in-memory LRU. User: "performance improve entirely". The
    // cold-start wait was by far the most visible perf cost.
    //
    // New: fire-and-forget. The user's active version is already
    // loaded above (via setVerses from FetchVerses). All OTHER
    // versions stream into the LRU in the background, one at a
    // time, after splash dismisses. The user can read / navigate /
    // search immediately; if they switch to an un-loaded version
    // before its background load completes, the on-demand
    // FetchVerses path (already wired for this case) loads it
    // synchronously in ~1 s. Most users stay on one or two
    // versions and never notice.
    //
    // Memory parity: same final state (~78 MB across all
    // versions); only the timing of when the slots fill changes.
    // 2026-06-11 (v1.3.61) PERF: web no longer eager-preloads the other
    // 12 versions. On native that loop reads local asset files — cheap,
    // and it's what makes version switches instant. On WEB each version
    // is a network download (0.5–1.4 MB brotli each, ~10 MB+ per cold
    // session in total) plus a main-thread json.decode of a 2–9 MB
    // string — real mobile data cost and visible jank while the user is
    // already reading. The on-demand switch path (FetchVerses) loads a
    // version in ~1–2 s when actually requested, and the service worker
    // caches each fetched bundle so later sessions are instant anyway.
    if (mainProvider.verses.isNotEmpty && !kIsWeb) {
      // ignore: unawaited_futures
      _eagerPreloadAllVersions(mainProvider).catchError(
          (Object e, StackTrace st) =>
              debugPrint('background version preload failed: $e'));
    }

    // 2026-05-24 (v1.3.2): eager-preload the daily-verses pool so
    // the splash's todayRef() lookup is synchronous-fast and
    // doesn't race with the splash's fallback timer. Fire-and-
    // forget — the result is cached inside DailyVerseService and
    // any callers that arrive before the load completes await on
    // the same in-flight Future via the service's internal
    // `_loading` guard.
    // ignore: unawaited_futures
    DailyVerseService.preload();

    // 2026-05-19 (v1.2.54): URL sync layer — keep the browser URL
    // in lockstep with the reader state (book / chapter / verse /
    // version). Web-only: native targets dispatch to the no-op
    // stub. Runs AFTER restoreState + FetchVerses so the boot URL
    // (if any) sees a populated `mp.verses` and can find the
    // referenced book + chapter / verse. On native, this is a
    // single function call that returns immediately.
    // ignore: unawaited_futures
    UrlSyncService.init(
      mainProvider: mainProvider,
      appSettings: appSettings,
    ).catchError((Object e, StackTrace st) {
      debugPrint('UrlSyncService.init failed: $e\n$st');
    });

    // 2026-05-24 (v1.3.0): refresh scheduled notification content on
    // every cold start. Cancels stale fires and re-creates the
    // enabled categories with today's verse / evidence / sermon.
    // Fire-and-forget — scheduler init is internally guarded so it
    // can't block app launch.
    // ignore: unawaited_futures
    notif_scheduler.rescheduleAll(appSettings).catchError(
      (Object e, StackTrace st) =>
          debugPrint('notif scheduler init failed: $e'),
    );

    // Clears the false-positive "Failed to load" window — see
    // MainProvider.bootInFlight doc comment. Set before the `_loading`
    // setState so LoadingPage's very next build already sees the
    // accurate state, regardless of which listener rebuilds first.
    mainProvider.setBootInFlight(false);

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  /// 2026-05-10 (v1.2.25 — restored from v1.2.18): eager pre-load
  /// of ALL 13 Bible versions before the splash dismisses. User
  /// chose this trade ("反正第一次用才 load version") again after
  /// noticing v1.2.22's hybrid stopped at "4/4" in the splash
  /// progress.
  ///
  /// Sequential, no-gap parse of all 12 non-active versions
  /// (~15-25 s). Updates `MainProvider.versionPreloadProgress`
  /// so the splash paints "Loading versions: 5/12" while the
  /// user waits. Total cold-boot wall-clock: 1-3 s for the
  /// active version + ~15-25 s for the other 12 = ~20-30 s
  /// splash before home appears.
  ///
  /// Order: simplified Chinese staples (largest user base) →
  /// English → traditional Chinese → LJK 1/2 NT-only specialty.
  /// Most-likely-next picks land in the LRU first, so even if
  /// the user is impatient and force-quits during pre-load,
  /// the first session-start switches still hit the cache.
  ///
  /// `preloadVersion` is best-effort — swallows failures so a
  /// single missing asset doesn't block boot.
  Future<void> _eagerPreloadAllVersions(MainProvider mainProvider) async {
    if (!mounted) return;
    const candidates = <String>[
      // Simplified Chinese staples — largest user base.
      'cuvs-yhwh',
      'cuv',
      'cnv',
      // English flagships.
      'kjv',
      'nasb',
      'leb',
      // Traditional Chinese variants.
      'cuv-tr',
      'cuvs-yhwh-tr',
      'cnv-tr',
      // LJK 1/2 — NT-only specialty translations.
      'biblexg',
      'biblexg-v2',
      'biblexg-tr',
      'biblexg-v2-tr',
    ];
    final toLoad =
        candidates.where((v) => v != mainProvider.currentVersion).toList();
    final total = toLoad.length;
    for (int i = 0; i < total; i++) {
      if (!mounted) return;
      mainProvider.setVersionPreloadProgress(i + 1, total);
      // Yield once per iteration so the splash actually repaints
      // before the next ~1 s json.decode hogs the main thread.
      await Future<void>.delayed(Duration.zero);
      await mainProvider.preloadVersion(toLoad[i]);
    }
    if (!mounted) return;
    mainProvider.setVersionPreloadProgress(0, 0);
    debugPrint('Eager pre-load complete: $total versions');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        // v1.3.21: keep ErrorReporter informed of the current
        // locale so crash reports show which language string was
        // on screen. Cheap call — early-returns when unchanged.
        ErrorReporter.setLocale(settings.locale);
        // Round 56: switched from `colorSchemeSeed` (default
        // tonal-palette variant) to an explicit
        // `ColorScheme.fromSeed(... vibrant ...)`. The default
        // Material-3 mapping desaturates the seed quite hard, so a
        // user picking pure red would see a muted brick on the app —
        // the user's complaint of "the color doesn't seem to affect
        // the app much". The `vibrant` variant pushes primary much
        // closer to the seed, with high-chroma accents on every
        // Material widget that uses `scheme.primary`.
        final lightScheme = ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        );
        // 2026-06-13 (v1.3.68): dark mode now tracks the user's chosen
        // theme colour like light mode does. Material-3's
        // `fromSeed(... dark ...)` maps `primary` to a pale, low-chroma
        // tone-80 of the seed — so verse numbers, note/bookmark glyphs,
        // and section headers (all of which read `colorScheme.primary`,
        // see lib/utils/build_verse_content_spans.dart) looked washed-out
        // and generic in dark mode, NOT the hue the user picked (user
        // report: "dark mode 没有根据 theme color"). We keep the seeded
        // palette for every container / surface / error tone (the dark
        // AppBar deliberately stays on `primaryContainer`, which is the
        // low-chroma tint that reads well at the top of the screen), and
        // only override `primary` (+ its contrast `onPrimary`) with a
        // hue-faithful, dark-legible derivation of the seed. That keeps
        // the chosen colour recognisable on every accent without making
        // the AppBar garish.
        final seededDark = ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        );
        final darkAccent = darkReadingAccent(settings.primaryColor);
        final darkScheme = seededDark.copyWith(
          primary: darkAccent,
          onPrimary: onAccentColor(darkAccent),
        );
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          // 2026-06-28 (v1.3.111): graceful fallback for UNKNOWN named routes.
          // Diagnosed by source-map-deobfuscating a prod (v1.3.102) crash
          // report ("Null check operator used on a null value", Android web):
          // on Flutter web a browser/back/deep-link navigation to a URL path
          // the app doesn't register reaches the Navigator with an unknown
          // route name. The app sets only `home:` (no routes/onGenerateRoute),
          // so Flutter fell through to `onUnknownRoute` — which was null —
          // crashing inside `_WidgetsAppState._onUnknownRoute`. Returning the
          // app root for any unknown route means a stray URL never crashes;
          // the user just lands on the home screen. (Get.to(...) pushes
          // anonymous routes and is unaffected by this handler.)
          onUnknownRoute: (RouteSettings settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => _RootRouter(
              initialVerses:
                  Provider.of<MainProvider>(ctx, listen: false).verses,
            ),
          ),
          themeMode: settings.themeMode,
          theme: ThemeData(
            fontFamily: settings.fontFamily,
            // 2026-05-08 (v1.1.0 — Liquid Glass / v1.1.2 — system
            // defaults): a comprehensive OS-native font fallback
            // chain. Each entry tries the next platform's
            // canonical UI font; the first one Flutter / the
            // browser can resolve wins. Order:
            //   • CJK fallback (bundled) → NotoSansSC-YsWords — added
            //     2026-05-24 v1.3.31; works on Flutter web CanvasKit
            //     where the CSS-only system fonts below are invisible
            //     to Skia. See `lib/utils/font_catalog.dart` for the
            //     full rationale.
            //   • Apple devices → -apple-system / SF Pro
            //   • Windows → Segoe UI
            //   • Android → Roboto
            //   • Linux GNOME → Cantarell
            //   • Linux KDE / generic → Noto Sans
            //   • CJK fallback → 微软雅黑 / 思源黑体
            //   • Universal → Arial / Helvetica / sans-serif
            // The 'system' font option in the catalogue routes to
            // the leading -apple-system token, which on every
            // non-Apple platform falls through this list naturally.
            fontFamilyFallback: const [
              '-apple-system',
              'BlinkMacSystemFont',
              'SF Pro Text',
              'SF Pro',
              'Segoe UI',
              'Helvetica Neue',
              'Cantarell',
              'Noto Sans',
              // 2026-05-24 (v1.3.31): bundled CJK subset goes here in
              // the global theme so EVERY widget (AppBar titles, menu
              // labels, dialog text, etc.) gets CJK coverage on web.
              // Verse text + word spans already use kCjkFontFallback
              // which has the same entry. Cheap to list twice — the
              // engine just walks until it finds a glyph.
              'NotoSansSC-YsWords',
              'Microsoft YaHei',
              '微软雅黑',
              'Source Han Sans SC',
              '思源黑体',
              'PingFang SC',
              'Roboto',
              'Arial',
              'Helvetica',
              'sans-serif',
            ],
            textTheme: ThemeData.light().textTheme.copyWith(
                  bodyLarge: ThemeData.light().textTheme.bodyLarge?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: settings.fontSize,
                      ),
                  bodyMedium: ThemeData.light().textTheme.bodyMedium?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: settings.fontSize - 2,
                      ),
                  titleLarge: ThemeData.light().textTheme.titleLarge?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: settings.fontSize + 4,
                      ),
                ),
            colorScheme: lightScheme,
            // 2026-05-08 (v1.1.0): Card & Dialog corner radii bumped
            // to 18 to match Apple's iOS 26 shape language (concentric
            // with the new 24-radius outer surfaces). The app's bespoke
            // Container-backed cards (welcome disclaimer, feedback
            // intro, etc) get the LiquidGlassCard primitive directly;
            // every Card(...) inherits from this theme.
            cardTheme: CardThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            // Tint the AppBar with primary so the user's chosen color
            // is immediately visible at the top of every page, not
            // just on FAB / Switch / Slider accents. Foreground is
            // `onPrimary` (white on saturated colors, dark on light
            // pastels — ColorScheme.fromSeed picks the right contrast).
            appBarTheme: AppBarTheme(
              backgroundColor: lightScheme.primary,
              foregroundColor: lightScheme.onPrimary,
              elevation: 0,
            ),
            // Round 56: explicit TabBar colours so tabs hosted in
            // a primary-coloured AppBar stay readable. Default
            // labelColor inherits AppBar foreground but unselected
            // tabs get a low-opacity treatment that user reported
            // as "看不清". Force selected = full onPrimary,
            // unselected = onPrimary @ 78% — clearly distinct
            // states without sacrificing contrast.
            tabBarTheme: TabBarThemeData(
              labelColor: lightScheme.onPrimary,
              unselectedLabelColor:
                  lightScheme.onPrimary.withValues(alpha: 0.78),
              indicatorColor: lightScheme.onPrimary,
            ),
          ),
          darkTheme: ThemeData(
            fontFamily: settings.fontFamily,
            // 2026-05-08 (v1.1.0 / v1.1.2): same comprehensive OS-
            // native font fallback chain as light theme. See light
            // theme above for the rationale + per-platform mapping.
            // 2026-05-24 (v1.3.31): bundled NotoSansSC-YsWords added
            // for CanvasKit CJK coverage (see light theme comment).
            fontFamilyFallback: const [
              '-apple-system',
              'BlinkMacSystemFont',
              'SF Pro Text',
              'SF Pro',
              'Segoe UI',
              'Helvetica Neue',
              'Cantarell',
              'Noto Sans',
              'NotoSansSC-YsWords',
              'Microsoft YaHei',
              '微软雅黑',
              'Source Han Sans SC',
              '思源黑体',
              'PingFang SC',
              'Roboto',
              'Arial',
              'Helvetica',
              'sans-serif',
            ],
            textTheme: ThemeData.dark().textTheme.copyWith(
                  bodyLarge: ThemeData.dark().textTheme.bodyLarge?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: settings.fontSize,
                        color: Color(0xFFCCCCCC),
                      ),
                  bodyMedium: ThemeData.dark().textTheme.bodyMedium?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: settings.fontSize - 2,
                        color: Color(0xFFCCCCCC),
                      ),
                  titleLarge: ThemeData.dark().textTheme.titleLarge?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: settings.fontSize + 4,
                        color: Color(0xFFCCCCCC),
                      ),
                ),
            inputDecorationTheme: InputDecorationTheme(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF888888)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFCCCCCC), width: 2),
              ),
              hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
            ),
            colorScheme: darkScheme,
            brightness: Brightness.dark,
            cardTheme: CardThemeData(
              color: Color(0xFF1F1F1F),
              elevation: 2,
              // 2026-05-08 (v1.1.0): bumped from 8 to 18 to match
              // light theme's new concentric-with-Liquid-Glass radii.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            // Dark AppBar uses primaryContainer (a low-chroma dark
            // tint of the user's color) instead of primary itself —
            // a saturated AppBar bg in dark mode reads as garish. The
            // primary still shows up on FAB / Switch / Slider /
            // selected chips / section headers via scheme.primary.
            appBarTheme: AppBarTheme(
              backgroundColor: darkScheme.primaryContainer,
              foregroundColor: darkScheme.onPrimaryContainer,
              elevation: 0,
            ),
            tabBarTheme: TabBarThemeData(
              labelColor: darkScheme.onPrimaryContainer,
              unselectedLabelColor:
                  darkScheme.onPrimaryContainer.withValues(alpha: 0.78),
              indicatorColor: darkScheme.onPrimaryContainer,
            ),
            sliderTheme: const SliderThemeData(
              inactiveTrackColor: Color(0xFF424242),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF333333),
                foregroundColor: Color(0xFFCCCCCC),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFFCCCCCC),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFFCCCCCC),
                side: BorderSide(color: Color(0xFFCCCCCC)),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
              titleTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: settings.fontSize + 2,
                fontWeight: FontWeight.bold,
              ),
              contentTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: settings.fontSize,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: Color(0xFF2C2C2C),
              contentTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: settings.fontSize * 0.85,
              ),
            ),
            dividerColor: Color(0xFF424242),
            iconTheme: const IconThemeData(
              color: Color(0xFFCCCCCC),
            ),
          ),
          builder: (context, child) {
            return ScrollConfiguration(
              behavior:
                  const MaterialScrollBehavior().copyWith(scrollbars: true),
              child: child!,
            );
          },
          // 2026-05-24 (v1.3.21): BreadcrumbObserver auto-records
          // every push/pop so error reports include the navigation
          // trail leading up to the crash.
          navigatorObservers: [BreadcrumbObserver(), _UrlRestoreObserver()],
          home: _loading
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : _RootRouter(
                  initialVerses:
                      Provider.of<MainProvider>(context, listen: false).verses,
                ),
        );
      },
    );
  }
}

/// v1.3.62 UX: the web engine writes the pushed route's minified name
/// into the URL fragment (`#/minified:Xt`), clobbering the canonical
/// share link. This observer asks the URL-sync layer to restore the
/// proper `#/<book>/<chapter>?v=` fragment shortly after every
/// push/pop. No-op on native (stub dispatch).
class _UrlRestoreObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      UrlSyncService.onRouteChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      UrlSyncService.onRouteChanged();
}

class _RootRouter extends StatefulWidget {
  final List<Verse> initialVerses;
  const _RootRouter({required this.initialVerses});

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _showHome = false;
  bool _deepLinkHandled = false;

  /// v1.3.62 UX: set (via the UrlSyncService callback) when a boot
  /// hash deep link (`#/<book>/<ch>?v=`) was applied — the next home
  /// build pushes the reader so shared links open the verse directly
  /// instead of parking the user on the Dashboard. A flag + rebuild
  /// (rather than navigating from the callback) because the apply can
  /// finish before OR after the home page appears.
  bool _bootHashLandingPending = false;

  @override
  void initState() {
    super.initState();
    UrlSyncService.setBootDeepLinkCallback(() {
      if (!mounted) return;
      setState(() => _bootHashLandingPending = true);
    });
  }

  void _advance() {
    if (!mounted || _showHome) return;
    setState(() => _showHome = true);
    _handleDeepLink();
  }

  /// On first show of the home page, inspect the URL for share
  /// query parameters (`?sermon=ID` or
  /// `?verse=Book:Chapter:Verse`) and auto-navigate to the
  /// referenced content. Lets shared links from the app's share
  /// buttons actually open what they promise.
  Future<void> _handleDeepLink() async {
    if (_deepLinkHandled) return;
    _deepLinkHandled = true;
    Uri? uri;
    try {
      uri = Uri.base;
    } catch (_) {
      return;
    }
    final params = uri.queryParameters;
    final sermonId = params['sermon'];
    if (sermonId != null && sermonId.isNotEmpty) {
      // Deferred so the dashboard finishes building first.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final svc = SermonService.instance;
        final all = await svc.loadIndex();
        Sermon? s;
        for (final c in all) {
          if (c.id == sermonId) {
            s = c;
            break;
          }
        }
        if (s != null && mounted) {
          Get.to(() => SermonDetailPage(sermon: s!),
              transition: Transition.rightToLeft);
        }
      });
      return;
    }
    final verse = params['verse'];
    if (verse != null && verse.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final parts = verse.split(':');
        if (parts.length != 3) return;
        final book = parts[0];
        final ch = int.tryParse(parts[1]);
        final v = int.tryParse(parts[2]);
        if (ch == null || v == null || !mounted) return;
        final ref = BibleReference(
            englishBook: book, chapter: ch, verseStart: v, verseEnd: v);
        final mp = context.read<MainProvider>();
        final result = await jumper.resolveAndPrepareJump(
            reference: ref, mp: mp);
        if (!mounted) return;
        await jumper.showJumpResultSnackBar(context, result);
        if (!mounted) return;
        // 2026-05-24 (v1.3.6): explicit routeName so the
        // verse_popup_sheet "Open in Reader" path can detect an
        // existing HomePage in the stack and pop to it instead of
        // pushing a duplicate. Get's auto-name resolves the
        // closure's runtimeType to something unpredictable like
        // `/_Closure` — explicit '/HomePage' is the only reliable
        // detection key.
        Get.to(() => const HomePage(),
            routeName: '/HomePage',
            transition: Transition.rightToLeft);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // v1.3.62 UX: boot deep link → land in the reader. Runs once,
    // post-frame, after the gate is out of the way; the reader opens
    // on the book/chapter the URL-sync apply already set. Same
    // explicit routeName convention as the notification-tap path
    // above so popUntil-based dedupe keeps working.
    if (_showHome && _bootHashLandingPending) {
      _bootHashLandingPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Get.to(() => const HomePage(),
            routeName: '/HomePage', transition: Transition.rightToLeft);
      });
    }
    // After Round 32: Dashboard is the home / root page. The Bible
    // reader (HomePage) is pushed on top via Dashboard's "Continue
    // reading" tile. This gives users a personal landing page with
    // greeting + today's reading + bookmark counts instead of
    // dropping straight into a verse list, which felt like a
    // sub-page rather than a home.
    return _showHome
        ? const DashboardPage()
        : LoadingPage(
            verses: widget.initialVerses,
            onAdvance: _advance,
          );
  }
}
