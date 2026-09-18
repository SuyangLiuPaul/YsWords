import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/widgets/home_icon_button.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/book_chapter_picker.dart';
import 'package:yahwehs_words/utils/navigate_to_chapter_verse.dart';
import 'package:yahwehs_words/utils/responsive.dart';

class BooksPage extends StatelessWidget {
  final int chapterIdx;
  final String bookIdx;
  final MainProvider? providerOverride;

  const BooksPage({
    super.key,
    required this.chapterIdx,
    required this.bookIdx,
    this.providerOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (providerOverride != null) {
      return ChangeNotifierProvider<MainProvider>.value(
        value: providerOverride!,
        child: Consumer<MainProvider>(
          builder: (ctx, mainProvider, _) => _buildContent(ctx, mainProvider),
        ),
      );
    }
    return Consumer<MainProvider>(
      builder: (context, mainProvider, _) => _buildContent(context, mainProvider),
    );
  }

  Widget _buildContent(BuildContext context, MainProvider mainProvider) {
    final settings = Provider.of<AppSettings>(context);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) {
          Get.back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          title: Text(
              uiStrings['bibleBooks']?[settings.locale] ?? 'Bible Books'),
          actions: const [LanguageSwitcherButton(), HomeIconButton()],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveBreakpoints.isTabletOrWider(
                      MediaQuery.of(context).size.width)
                  ? 800
                  : double.infinity,
            ),
            child: BookChapterPicker(
              // Where the reader is NOW, not where it was when this route
              // was pushed. `bookIdx`/`chapterIdx` are constructor
              // arguments frozen at push time, and the picker only
              // re-syncs itself in `didUpdateWidget` — so with frozen
              // props it can never learn that the reader moved, and it
              // went on offering the verses of a chapter that was no
              // longer on screen.
              currentBook: mainProvider.currentBook ?? bookIdx,
              currentChapter: mainProvider.currentChapter ?? chapterIdx,
              onChapterSelected: (book, chapter, {int? verse}) {
                if (!navigateToChapterVerse(mainProvider,
                    book: book, chapter: chapter, verse: verse)) {
                  return;
                }
                Get.back();
              },
            ),
          ),
        ),
      ),
    );
  }
}
