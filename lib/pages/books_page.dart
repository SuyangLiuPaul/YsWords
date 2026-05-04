import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/book_chapter_picker.dart';
import 'package:yswords/utils/responsive.dart';

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
        child: _buildContent(context, providerOverride!),
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
          actions: const [HomeIconButton()],
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
              currentBook: bookIdx,
              currentChapter: chapterIdx,
              onChapterSelected: (book, chapter) {
                final matched = mainProvider.verses
                    .where((v) => v.book == book && v.chapter == chapter)
                    .toList();
                if (matched.isEmpty) return;
                mainProvider.setCurrentChapter(book: book, chapter: chapter);
                mainProvider.updateCurrentVerse(verse: matched.first);
                // Round 56 fix: don't slam to top if a pendingJump
                // was set by the picker's verse-pick step. The
                // previous unconditional jumpToTop was clobbering
                // the user's verse-level pick. Only jump-to-top when
                // there's nothing more specific queued.
                if (!mainProvider.hasPendingJump) {
                  mainProvider.jumpToTop();
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
