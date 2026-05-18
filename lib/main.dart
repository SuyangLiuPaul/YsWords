import 'dart:async';
import 'package:flutter/foundation.dart';
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
import 'package:yswords/pages/welcome_page.dart';
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart' show BibleReference;
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/realtime_db_sync_service.dart';
import 'package:yswords/services/offline_pack_service.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/book_intro_service.dart';
import 'package:yswords/services/leb_insights_service.dart';
import 'package:yswords/services/section_title_service.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = FlutterError.dumpErrorToConsole;
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
    return true;
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MainProvider()),
        ChangeNotifierProvider(create: (context) => AppSettings()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
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
    _splashWatchdog?.cancel();
    super.dispose();
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
        await CloudAuthService.instance.init();
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
      // 2026-05-18 (v1.2.53): pre-warm the LEB translator-insights
      // cache. Parses ~30 k verses, extracts ~23 k <note: …>
      // annotations into a chapter-verse-keyed map. Fire-and-
      // forget — the first chapter render usually arrives after
      // the parse completes (~50 ms on web). Until ready,
      // `LebInsightsService.notesFor` returns an empty list and
      // no chip is shown, so there's no UI flicker.
      // ignore: unawaited_futures
      LebInsightsService.instance.init().catchError((Object e, StackTrace st) {
        debugPrint('LebInsightsService.init failed: $e\n$st');
      });
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
    // Splash blocks for ~25 s on cold boot. After it dismisses
    // ALL 13 versions are in the LRU; switching between any of
    // them is a microsecond cache swap (no overlay). Same trade
    // as v1.2.18: long-but-explicable splash → flawless reading
    // experience.
    if (mainProvider.verses.isNotEmpty) {
      await _eagerPreloadAllVersions(mainProvider);
    }

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
        final darkScheme = ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        );
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            fontFamily: settings.fontFamily,
            // 2026-05-08 (v1.1.0 — Liquid Glass / v1.1.2 — system
            // defaults): a comprehensive OS-native font fallback
            // chain. Each entry tries the next platform's
            // canonical UI font; the first one Flutter / the
            // browser can resolve wins. Order:
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
                        fontFamily: settings.fontFamily,
                        fontSize: settings.fontSize,
                      ),
                  bodyMedium: ThemeData.light().textTheme.bodyMedium?.copyWith(
                        fontFamily: settings.fontFamily,
                        fontSize: settings.fontSize - 2,
                      ),
                  titleLarge: ThemeData.light().textTheme.titleLarge?.copyWith(
                        fontFamily: settings.fontFamily,
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
            fontFamilyFallback: const [
              '-apple-system',
              'BlinkMacSystemFont',
              'SF Pro Text',
              'SF Pro',
              'Segoe UI',
              'Helvetica Neue',
              'Cantarell',
              'Noto Sans',
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
                        fontFamily: settings.fontFamily,
                        fontSize: settings.fontSize,
                        color: Color(0xFFCCCCCC),
                      ),
                  bodyMedium: ThemeData.dark().textTheme.bodyMedium?.copyWith(
                        fontFamily: settings.fontFamily,
                        fontSize: settings.fontSize - 2,
                        color: Color(0xFFCCCCCC),
                      ),
                  titleLarge: ThemeData.dark().textTheme.titleLarge?.copyWith(
                        fontFamily: settings.fontFamily,
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

class _RootRouter extends StatefulWidget {
  final List<Verse> initialVerses;
  const _RootRouter({required this.initialVerses});

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _showHome = false;
  bool _welcomeDone = false;
  bool _deepLinkHandled = false;

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
        Get.to(() => const HomePage(),
            transition: Transition.rightToLeft);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show the welcome / sign-in gate the first time the app is
    // opened on a given device. After it's dismissed (either by
    // continuing as Guest or by signing in) the gate stays out of
    // the way; the switcher in Settings remains the entry point.
    final showGate =
        _showHome && !_welcomeDone && !ProfileService.instance.seenWelcome;
    if (showGate) {
      return WelcomePage(
        onDone: () {
          if (!mounted) return;
          setState(() => _welcomeDone = true);
        },
      );
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
