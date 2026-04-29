import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/build_verse_content_spans.dart';
import 'package:yswords/utils/responsive.dart';

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
        final highlightColor = mainProvider.getHighlightColor(verse);
        final isNoted = mainProvider.isVerseNoted(verse);
        final isBookmarked = mainProvider.isBookmarked(verse);
        final isReferenceLine = verse.paragraphType == 'reference';
        final inParagraphMode = settings.paragraphMode;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final highlightAlpha = isDark ? 0.55 : 0.35;

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
          onTextTap: () => mainProvider.toggleVerse(verse: verse),
        ));

        // Layout: indent + top gap depend on mode and paragraph context
        late final double leftIndent;
        late final double topGap;
        late final double vertPadding;

        final dc = ResponsiveBreakpoints.classOf(
            MediaQuery.of(context).size.width);
        final baseIndent = ResponsiveBreakpoints.verseIndent(dc);

        if (inParagraphMode) {
          if (isReferenceLine) {
            leftIndent = settings.fontSize * 2;
          } else {
            leftIndent = baseIndent + 4;
          }
          // Suppress gap on the first item; tiny gap between paragraphs
          topGap = (!isFirst && (isReferenceLine || verse.isParagraphStart))
              ? settings.fontSize * 0.35
              : 0;
          vertPadding = (settings.fontSize * 0.1).clamp(1.0, 4.0);
        } else {
          // Verse-by-verse mode. Bumped vertPadding minimum to 6.0
          // so each verse meets the Material 48dp tap-target rule
          // even at the smallest font size — pre-fix users had to
          // poke at thin verses (~24dp tall) to trigger selection.
          leftIndent = isReferenceLine ? baseIndent + 8 : baseIndent;
          topGap = (!isFirst && verse.isParagraphStart) ? settings.fontSize * 0.4 : 0;
          vertPadding = (settings.fontSize * 0.4).clamp(6.0, 12.0);
        }

        return Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            // Subtle visible feedback so the user knows the tap registered.
            // Pre-fix had both at Colors.transparent which made it feel
            // like nothing was happening even when the tap did go through.
            highlightColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.06),
            splashColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.10),
            onTap: () => mainProvider.toggleVerse(verse: verse),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topGap > 0) SizedBox(height: topGap),
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : isHighlighted
                              ? Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: highlightAlpha)
                              : highlightColor != null
                                  ? highlightColor
                                      .withValues(alpha: highlightAlpha)
                                  : Colors.transparent,
                      padding: EdgeInsets.fromLTRB(
                          leftIndent, vertPadding, baseIndent, vertPadding),
                      child: RichText(
                        textAlign: TextAlign.start,
                        text: TextSpan(
                          style: settings.boldVerseText
                              ? const TextStyle(fontWeight: FontWeight.w600)
                              : null,
                          children: spans,
                        ),
                      ),
                    ),
                    // Tiny note / bookmark badges anchored to the right
                    // edge of the verse container. Only render when the
                    // verse has the corresponding annotation, so the
                    // reading view stays clean for un-annotated verses.
                    if (isNoted || isBookmarked)
                      Positioned(
                        top: 2,
                        right: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isNoted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.sticky_note_2,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            if (isBookmarked)
                              Icon(
                                Icons.bookmark_rounded,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.6),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
