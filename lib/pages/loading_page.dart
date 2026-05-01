import 'dart:async';
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
    final mainProvider = context.read<MainProvider>();
    try {
      await FetchVerses.execute(mainProvider: mainProvider);
      await FetchBooks.execute(mainProvider: mainProvider);
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
      mainProvider.setLoadError(e.toString());
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
                  Text(
                    '${verse.book} ${verse.chapter}:${verse.verseLabel}',
                    style: TextStyle(
                      fontSize: settings.fontSize * 0.9,
                      color: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
