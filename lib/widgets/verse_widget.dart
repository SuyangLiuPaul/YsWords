import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/build_verse_content_spans.dart';

/// Renders a single verse. Used by:
///   - Verse-by-verse mode for every verse
///   - Paragraph mode when a paragraph happens to contain exactly one verse
///     (e.g. an isolated reference line)
class VerseWidget extends StatelessWidget {
  final Verse verse;
  final int index;
  final bool hasParagraphData;

  /// True when this verse opens the chapter (suppresses the top gap).
  final bool isFirst;

  const VerseWidget({
    super.key,
    required this.verse,
    required this.index,
    this.hasParagraphData = false,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        final locale = settings.locale;
        final isSelected = mainProvider.isSelected(verse);
        final isHighlighted = mainProvider.highlightIndex == index;
        final isReferenceLine = verse.paragraphType == 'reference';
        final inParagraphMode = settings.paragraphMode;

        final spans = <InlineSpan>[];

        // First-line indent (paragraph mode, paragraph-start, non-reference)
        if (inParagraphMode &&
            !isReferenceLine &&
            (verse.isParagraphStart || !hasParagraphData)) {
          spans.add(WidgetSpan(
            child: SizedBox(width: settings.fontSize * 1.6),
          ));
        }

        spans.addAll(buildVerseContentSpans(
          verse: verse,
          context: context,
          settings: settings,
          locale: locale,
          isSelected: isSelected,
          superscriptVerseNum: inParagraphMode,
        ));

        // Layout: indent + top gap depend on mode and paragraph context
        late final double leftIndent;
        late final double topGap;
        late final double vertPadding;

        if (inParagraphMode) {
          if (isReferenceLine) {
            leftIndent = settings.fontSize * 2;
          } else {
            leftIndent = 20;
          }
          // Suppress gap on the first item; tiny gap between paragraphs
          topGap = (!isFirst &&
                  (isReferenceLine || verse.isParagraphStart))
              ? settings.fontSize * 0.35
              : 0;
          vertPadding = 2;
        } else {
          // Verse-by-verse mode
          leftIndent = isReferenceLine ? 24 : 16;
          topGap = (!isFirst && verse.isParagraphStart) ? 8 : 0;
          vertPadding = 6;
        }

        return Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: () => mainProvider.toggleVerse(verse: verse),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topGap > 0) SizedBox(height: topGap),
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
