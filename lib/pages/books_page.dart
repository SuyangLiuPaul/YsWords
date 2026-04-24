import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/book_chapter_picker.dart';
import 'package:yswords/utils/responsive.dart';

class BooksPage extends StatelessWidget {
  final int chapterIdx;
  final String bookIdx;
  const BooksPage({super.key, required this.chapterIdx, required this.bookIdx});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return Consumer<MainProvider>(
      builder: (context, mainProvider, child) {
        return Scaffold(
          appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(
                uiStrings['bibleBooks']?[settings.locale] ?? 'Bible Books'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveBreakpoints.isDesktopOrWider(
                        MediaQuery.of(context).size.width)
                    ? 800
                    : double.infinity,
              ),
              child: BookChapterPicker(
                currentBook: bookIdx,
                currentChapter: chapterIdx,
                onChapterSelected: (book, chapter) {
                  final matched = mainProvider.verses
                      .where((v) => v.book == book && v.chapter == chapter)
                      .toList();
                  if (matched.isEmpty) return;
                  mainProvider.setCurrentChapter(book: book, chapter: chapter);
                  mainProvider.updateCurrentVerse(verse: matched.first);
                  mainProvider.jumpToTop();
                  Get.back();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
