import 'package:flutter/material.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/build_verse_content_spans.dart';

class ParagraphGroupWidget extends StatelessWidget {
  final List<Verse> group;
  final int startVerseIndex;

  const ParagraphGroupWidget({
    super.key,
    required this.group,
    required this.startVerseIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        final locale = settings.locale;
        final isReference =
            group.isNotEmpty && group.first.paragraphType == 'reference';
        final isParagraphStart =
            group.isNotEmpty && group.first.isParagraphStart == true;

        // Build flowing spans for all verses, with per-verse tap handling
        final allSpans = <InlineSpan>[];
        for (int i = 0; i < group.length; i++) {
          final verse = group[i];
          final isSelected = mainProvider.isSelected(verse);
          final isHighlighted =
              mainProvider.highlightIndex == startVerseIndex + i;

          Color? bgColor;
          if (isSelected) {
            bgColor = Theme.of(context).colorScheme.primaryContainer;
          } else if (isHighlighted) {
            bgColor = Theme.of(context)
                .colorScheme
                .secondary
                .withValues(alpha: 0.3);
          }

          allSpans.addAll(buildVerseContentSpans(
            verse: verse,
            context: context,
            settings: settings,
            locale: locale,
            isSelected: isSelected || isHighlighted,
            superscriptVerseNum: true,
            onTextTap: () => mainProvider.toggleVerse(verse: verse),
            spanBgColor: bgColor,
          ));
        }

        // Compute indent
        double leftIndent;
        if (isReference) {
          leftIndent = settings.fontSize * 3;
        } else if (isParagraphStart) {
          leftIndent = settings.fontSize * 2;
        } else {
          leftIndent = 16;
        }

        return Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isParagraphStart)
                SizedBox(height: settings.fontSize * 0.8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(leftIndent, 4, 16, 4),
                child: RichText(
                  textAlign: TextAlign.start,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: settings.fontSize,
                      fontFamily: settings.fontFamily,
                      height: settings.lineSpacing,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontStyle:
                          isReference ? FontStyle.italic : FontStyle.normal,
                    ),
                    children: allSpans,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
