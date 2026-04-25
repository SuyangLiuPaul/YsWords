import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/verse.dart';
import '../providers/main_provider.dart';
import '../services/fetch_verses.dart';
import '../services/fetch_books.dart';
import '../constants/text_patterns.dart';
import '../constants/ui_strings.dart';
import '../utils/responsive.dart';
import 'home_page.dart';

class LoadingPage extends StatefulWidget {
  final List<Verse> verses;

  /// Optional advance callback. When provided (e.g. by a persistent
  /// scaffold like StackedCardScaffold), it is used instead of a
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

  @override
  void initState() {
    super.initState();
    _scheduleAdvanceIfReady();
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

    // Shuffle a COPY so we don't mutate the canonical verse order
    final verse = widget.verses.isNotEmpty
        ? (List<Verse>.from(widget.verses)..shuffle()).first
        : null;

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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: verse == null
            ? Text(
                uiStrings['noVersesAvailable']?[settings.locale] ??
                    'No verses available',
              )
            : Column(
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
