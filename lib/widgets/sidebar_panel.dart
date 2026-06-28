import 'package:flutter/material.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:yswords/widgets/book_chapter_picker.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

class SidebarPanel extends StatelessWidget {
  final String currentBook;
  final int currentChapter;
  final void Function(String book, int chapter) onChapterSelected;
  final VoidCallback onClose;

  const SidebarPanel({
    super.key,
    required this.currentBook,
    required this.currentChapter,
    required this.onChapterSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;

    return Consumer<MainProvider>(
      builder: (context, mainProvider, _) {
        return DefaultTextStyle.merge(
          style: TextStyle(
            color: scheme.onSurface,
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          ),
          // Material ancestor is required for ExpansionTile/InkWell/Ink
          // inside BookChapterPicker to render correctly. The iPhone
          // path uses Scaffold (which provides Material); the iPad
          // sidebar previously had only a Container and the inner
          // book list silently failed to draw.
          child: Material(
          color: scheme.surface,
          child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            uiStrings['bibleBooks']?[settings.locale] ??
                                'Bible Books',
                            style: TextStyle(
                              fontSize: settings.fontSize.clamp(14.0, 18.0),
                              fontWeight: FontWeight.w700,
                              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              color: scheme.onSurface,
                              decoration: TextDecoration.none,
                              decorationColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.chevron_left_rounded),
                        iconSize: settings.fontSize.clamp(18.0, 24.0),
                        tooltip:
                            uiStrings['close']?[settings.locale] ?? 'Close',
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: BookChapterPicker(
                  currentBook: currentBook,
                  currentChapter: currentChapter,
                  onChapterSelected: onChapterSelected,
                ),
              ),
            ],
          ),
        ),
        ),
        );
      },
    );
  }
}
