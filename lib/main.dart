import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yswords/pages/loading_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    PlatformDispatcher.instance.onError = (e, st) {
      print('UNCAUGHT: $e\n$st');
      return true;
    };
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
    Timer(Duration(seconds: 8), () {
      if (_loading) {
        setState(() {
          _loading = false; // Optionally handle timeout behavior here.
        });
      }
    });
    Future.microtask(() async {
      final mainProvider = Provider.of<MainProvider>(context, listen: false);
      final appSettings = Provider.of<AppSettings>(context, listen: false);

      // Load settings and Bible content
      await appSettings.loadSettings();

      bool localResourcesReady = await FetchVerses.testLoadLocal();
      if (!localResourcesReady) {
        // If updates are disabled but no local data exists, fetch once to populate it:
        if (!appSettings.allowUpdates) {
          await FetchVerses.execute(
            mainProvider: mainProvider,
            settings: appSettings,
          );
          // recheck
          localResourcesReady = await FetchVerses.testLoadLocal();
        }
        appSettings.setLockAllowUpdates(true);
      } else {
        appSettings.setLockAllowUpdates(false);
      }

      await mainProvider.restoreState();

      if (mainProvider.verses.isEmpty) {
        if (appSettings.allowUpdates) {
          await FetchVerses.execute(
            mainProvider: mainProvider,
            settings: appSettings,
          );
        } else {
          await FetchVerses.loadLocalOnly(
            mainProvider: mainProvider,
          );
        }
      }

      await FetchBooks.execute(
          mainProvider: mainProvider, settings: appSettings);

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
        );
        mainProvider.updateCurrentVerse(verse: match);
      } else if (mainProvider.verses.isNotEmpty) {
        final firstVerse = mainProvider.verses.first;
        mainProvider.setCurrentChapter(
            book: firstVerse.book, chapter: firstVerse.chapter);
        mainProvider.updateCurrentVerse(verse: firstVerse);
      }

      setState(() {
        _loading = false;
      });
    });
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
            colorScheme: const ColorScheme.dark(
              surface: Color(0xFF1A1A1A),
              background: Color(0xFF121212),
              primary: Color(0xFFCCCCCC),
              onPrimary: Colors.black,
              onSurface: Color(0xFFCCCCCC),
            ),
            scaffoldBackgroundColor: Color(0xFF121212),
            cardColor: const Color(0xFF1A1A1A),
            cardTheme: CardTheme(
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
            dialogTheme: DialogTheme(
              backgroundColor: Color(0xFF1E1E1E),
              titleTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              contentTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 16,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: Color(0xFF2C2C2C),
              contentTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 14,
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
              : LoadingPage(
                  verses:
                      Provider.of<MainProvider>(context, listen: false).verses),
        );
      },
    );
  }
}
