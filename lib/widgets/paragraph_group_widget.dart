import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/build_verse_content_spans.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/leb_insight_chip.dart';

/// Renders a group of consecutive verses as one flowing paragraph (RichText).
/// Used in paragraph mode. Eliminates per-verse line breaks so verses read
/// as continuous prose, similar to printed Bibles or WeDevote (微读圣经).
class ParagraphGroupWidget extends StatelessWidget {
  final List<Verse> group;
  final int startVerseIndex;

  /// True when this is the first paragraph in the chapter — suppresses the
  /// inter-paragraph gap so the chapter starts flush with the header.
  final bool isFirst;

  const ParagraphGroupWidget({
    super.key,
    required this.group,
    required this.startVerseIndex,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        if (group.isEmpty) return const SizedBox.shrink();

        final locale = settings.locale;
        final isReference = group.first.paragraphType == 'reference';
        final isParagraphStart = group.first.isParagraphStart == true;

        // Build flowing spans for the whole group. Every span — including
        // the indent placeholder and inter-verse separators — gets a tap
        // recognizer so there are NO dead zones between verses. Pre-fix
        // bug: the gap-spans had no recognizer, so taps that landed on
        // whitespace fell through to the InkWell whose onTap was `null`
        // when the paragraph had >1 verse, requiring users to retry.
        final allSpans = <InlineSpan>[];

        // First-line indent for paragraph starts (true Chinese book style).
        // Reference blocks use a deeper indent on every line via container padding.
        if (isParagraphStart && !isReference) {
          allSpans.add(WidgetSpan(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  mainProvider.toggleVerse(verse: group.first),
              child: SizedBox(
                width: settings.fontSize * 1.6,
                height: settings.fontSize * settings.lineSpacing,
              ),
            ),
          ));
        }

        for (int i = 0; i < group.length; i++) {
          final verse = group[i];
          final isSelected = mainProvider.isSelected(verse);
          final isHighlighted =
              mainProvider.highlightIndex == startVerseIndex + i;
          // Bookmark + note indicators — verse-by-verse mode shows
          // them as a positioned icon in the top-right corner of
          // each verse container; paragraph mode has no per-verse
          // container, so we render tiny inline glyphs right before
          // the verse number instead. Pre-fix paragraph mode was
          // silent about which verses were bookmarked.
          final isBookmarked = mainProvider.isBookmarked(verse);
          final isNoted = mainProvider.isVerseNoted(verse);

          Color? bgColor;
          final highlightColor = mainProvider.getHighlightColor(verse);
          if (isSelected || isHighlighted) {
            // 2026-05-17 (v1.2.50): unified selection + highlight
            // to `primaryContainer`. The earlier `secondary` tint
            // (v1.2.49) was still too subtle on parchment / muted
            // themes — users reported "search verse not
            // highlighted". `primaryContainer` is the same bold
            // colour a manually-tapped verse gets, so the search-
            // jump target is now unmistakable. Auto-clears after
            // the 3.5 s timer in bible_reading_pane.dart.
            bgColor = Theme.of(context).colorScheme.primaryContainer;
          } else if (highlightColor != null) {
            bgColor = highlightColor.withValues(alpha: 0.35);
          }

          // 2026-05-17 (v1.2.51): paragraph mode hides the target
          // verse inside a continuous block of text — even with
          // the primaryContainer wash (v1.2.50) it can be hard to
          // spot mid-paragraph at a glance. Inline arrow marker
          // before the verse number when isHighlighted draws the
          // eye to the exact spot. Auto-clears with the highlight
          // after 3.5 s (bible_reading_pane.dart's tryJump).
          if (isHighlighted) {
            allSpans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(
                  Icons.east_rounded,
                  size: settings.fontSize * 0.9,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ));
          }
          if (isBookmarked) {
            allSpans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 1),
                child: Icon(
                  Icons.bookmark_rounded,
                  size: settings.fontSize * 0.85,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ));
          }
          if (isNoted) {
            allSpans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 1),
                child: Icon(
                  Icons.sticky_note_2,
                  size: settings.fontSize * 0.78,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.7),
                ),
              ),
            ));
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

          // 2026-05-18 (v1.2.53): cross-version LEB insights chip.
          // Renders a small (i) icon inline after this verse's
          // content when LEB has a translator note for the same
          // chapter:verse AND user is reading a non-LEB version
          // AND the setting is enabled. Returns null otherwise,
          // so the if-let pattern is the cleanest.
          final lebChip = buildLebInsightChip(
            verse: verse,
            context: context,
            settings: settings,
            currentVersion: mainProvider.currentVersion,
            isSelected: isSelected || isHighlighted,
          );
          if (lebChip != null) {
            allSpans.add(lebChip);
          }

          // Inter-verse separator — assign tap to the verse just rendered
          // so a tap on the whitespace toggles that verse instead of
          // doing nothing.
          if (i < group.length - 1) {
            allSpans.add(TextSpan(
              text: ' ',
              recognizer: TapGestureRecognizer()
                ..onTap = () => mainProvider.toggleVerse(verse: verse),
            ));
          }
        }

        // Outer indent (left margin of the whole block, applied to every line)
        // Reference blocks: deeper indent + italic
        // Normal paragraphs: small breathing room
        final dc = ResponsiveBreakpoints.classOf(
            MediaQuery.of(context).size.width);
        final baseIndent = ResponsiveBreakpoints.verseIndent(dc);
        final double vPad = (settings.fontSize * 0.1).clamp(1.0, 4.0);
        final EdgeInsets blockPadding = isReference
            ? EdgeInsets.fromLTRB(settings.fontSize * 2, vPad, baseIndent, vPad)
            : EdgeInsets.fromLTRB(baseIndent + 4, vPad, baseIndent, vPad);

        // Inter-paragraph gap — small and only between paragraphs (not at top)
        final double topGap = (!isFirst && (isParagraphStart || isReference))
            ? settings.fontSize * 0.35
            : 0;

        return Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            // Subtle splash so taps that land on the block margins
            // (outside any text span) still give visible feedback.
            // The actual selection is handled by the per-verse span
            // recognizers above when the tap is on text.
            highlightColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.05),
            splashColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.08),
            // Single-verse paragraphs: tap anywhere in the block toggles.
            // Multi-verse paragraphs: leave it null so the per-verse span
            // recognizers can disambiguate which verse to toggle.
            onTap: group.length == 1
                ? () => mainProvider.toggleVerse(verse: group.first)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topGap > 0) SizedBox(height: topGap),
                Container(
                  width: double.infinity,
                  padding: blockPadding,
                  child: RichText(
                    textAlign: TextAlign.start,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: settings.fontSize,
                        fontFamily: settings.fontFamily,
                        height: settings.lineSpacing,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: settings.boldVerseText
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontStyle:
                            isReference ? FontStyle.italic : FontStyle.normal,
                      ),
                      children: allSpans,
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
