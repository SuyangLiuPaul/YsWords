import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/loading_page.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/widgets/book_chapter_picker.dart';
import 'package:yswords/widgets/chapter_reader_card.dart';
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
              : _RootRouter(
                  initialVerses:
                      Provider.of<MainProvider>(context, listen: false).verses,
                ),
        );
      },
    );
  }
}

/// Hosts the persistent [StackedCardScaffold] and swaps the splash
/// screen for the home reader once verses are ready. Owns the
/// "add a chapter" flow exposed via the scaffold's "+" button: the
/// button is hidden during the splash, then once home is mounted it
/// opens a book/chapter picker as a modal sheet, and selection pushes
/// a [ChapterReaderCard] onto the stack as a brand-new layered card.
class _RootRouter extends StatefulWidget {
  final List<Verse> initialVerses;
  const _RootRouter({required this.initialVerses});

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _showHome = false;
  final GlobalKey<StackedCardScaffoldState> _stackKey = GlobalKey();

  void _advance() {
    if (!mounted || _showHome) return;
    setState(() => _showHome = true);
  }

  void _showAddChapterPicker() {
    final mp = Provider.of<MainProvider>(context, listen: false);
    final settings = Provider.of<AppSettings>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final pickerTitle =
        uiStrings['addChapter']?[settings.locale] ?? 'Add chapter';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final h = MediaQuery.of(sheetCtx).size.height * 0.85;
        return SizedBox(
          height: h,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag handle.
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          pickerTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: BookChapterPicker(
                    currentBook: mp.currentBook ?? '',
                    currentChapter: mp.currentChapter ?? 1,
                    onChapterSelected: (book, chapter) {
                      Navigator.of(sheetCtx).pop();
                      final stack = _stackKey.currentState;
                      if (stack == null) return;
                      stack.push<void>(
                        (_) => ChapterReaderCard(
                          book: book,
                          chapter: chapter,
                        ),
                        label: '$book $chapter',
                        icon: Icons.menu_book_rounded,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final tooltip =
        uiStrings['openAnotherChapter']?[settings.locale] ??
            'Open another chapter';

    return StackedCardScaffold(
      key: _stackKey,
      // The "+" button only lights up once the splash is done — it's
      // meaningless during loading because there's no chapter to read
      // yet and no scaffold consumers below.
      onAddLayer: _showHome ? _showAddChapterPicker : null,
      addLayerTooltip: tooltip,
      child: _showHome
          ? const HomePage()
          : LoadingPage(
              verses: widget.initialVerses,
              onAdvance: _advance,
            ),
    );
  }
}
