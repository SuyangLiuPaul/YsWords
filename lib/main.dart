import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/loading_page.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/widgets/stacked_card_nav.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

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

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      if (_loading && mounted) {
        setState(() {
          _loading = false;
        });
      }
    });
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final mainProvider = context.read<MainProvider>();
    final appSettings = context.read<AppSettings>();

    try {
      await appSettings.loadSettings();
      await mainProvider.restoreState();

      if (mainProvider.verses.isEmpty) {
        await FetchVerses.execute(mainProvider: mainProvider);
      }
      await FetchBooks.execute(mainProvider: mainProvider);

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
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            fontFamily: settings.fontFamily,
            fontFamilyFallback: ['Roboto', 'Arial', 'Helvetica'],
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
            colorSchemeSeed: settings.primaryColor,
          ),
          darkTheme: ThemeData(
            fontFamily: settings.fontFamily,
            fontFamilyFallback: ['Roboto', 'Arial', 'Helvetica'],
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
            colorSchemeSeed: settings.primaryColor,
            brightness: Brightness.dark,
            cardTheme: CardThemeData(
              color: Color(0xFF1F1F1F),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              foregroundColor: Color(0xFFCCCCCC),
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
              : StackedCardScaffold(
                  child: _RootRouter(
                    initialVerses:
                        Provider.of<MainProvider>(context, listen: false)
                            .verses,
                  ),
                ),
        );
      },
    );
  }
}

/// Root child of [StackedCardScaffold]: shows the loading splash first and
/// swaps to [HomePage] in place once verses are ready, so the surrounding
/// stacked-card scaffold persists across the transition.
class _RootRouter extends StatefulWidget {
  final List<Verse> initialVerses;
  const _RootRouter({required this.initialVerses});

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _showHome = false;

  void _advance() {
    if (!mounted || _showHome) return;
    setState(() => _showHome = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showHome) return const HomePage();
    return LoadingPage(
      verses: widget.initialVerses,
      onAdvance: _advance,
    );
  }
}
