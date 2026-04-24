import 'package:flutter/material.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/build_verse_content_spans.dart';

class VerseWidget extends StatelessWidget {
  final Verse verse;
  final int index;
  final bool hasParagraphData;

  const VerseWidget(
      {super.key,
      required this.verse,
      required this.index,
      this.hasParagraphData = false});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        final locale = settings.locale;
        final isSelected = mainProvider.isSelected(verse);
        final isHighlighted = mainProvider.highlightIndex == index;
        final isReferenceLine = verse.paragraphType == 'reference';
        final inParagraphMode = settings.paragraphMode;
        final effectiveParagraphStart = inParagraphMode
            ? (hasParagraphData
                ? (verse.isParagraphStart == true)
                : true)
            : false;

        final spans = buildVerseContentSpans(
          verse: verse,
          context: context,
          settings: settings,
          locale: locale,
          isSelected: isSelected,
          superscriptVerseNum: inParagraphMode,
        );

        double leftIndent;
        double topSpacer;
        double vertPadding;
        if (inParagraphMode) {
          if (isReferenceLine) {
            leftIndent = settings.fontSize * 3;
            topSpacer = 0;
          } else if (effectiveParagraphStart) {
            leftIndent = settings.fontSize * 2;
            topSpacer = settings.fontSize * 0.8;
          } else {
            leftIndent = 16;
            topSpacer = 0;
          }
          vertPadding = 2;
        } else {
          leftIndent = isReferenceLine ? 24 : 16;
          topSpacer = (verse.isParagraphStart == true) ? 10 : 0;
          vertPadding = 8;
        }

        return Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: () {
              mainProvider.toggleVerse(verse: verse);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topSpacer > 0) SizedBox(height: topSpacer),
                Container(
                  width: double.infinity,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : isHighlighted
                          ? Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.3)
                          : Colors.transparent,
                  padding: EdgeInsets.fromLTRB(
                      leftIndent, vertPadding, 16, vertPadding),
                  child: RichText(
                    textAlign: TextAlign.start,
                    text: TextSpan(
                      children: spans,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
