import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/build_verse_content_spans.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/bible_reading_pane.dart' show showNoteEditor;
import 'package:yswords/widgets/block_note_card.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

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
    if (group.isEmpty) return const SizedBox.shrink();

    // 2026-05-24 (v1.3.15) PERF: Consumer2 → Selector. Pre-fix the
    // whole paragraph group rebuilt on every `notifyListeners()` of
    // MainProvider — fired by scroll updates (currentVerse tracking),
    // selection on ANY other verse in the chapter, highlight clears,
    // bookmark / note mutations on unrelated verses, etc. With a
    // typical chapter holding 20-50 paragraph groups, that's 20-50
    // RichText rebuilds (~250 InlineSpan allocations each) per tap.
    //
    // The Selector below collapses the dependency to just the state
    // this specific group cares about:
    //   • `localHighlight` — -1 unless the highlight index falls
    //     inside THIS group (then the in-group offset). Groups not
    //     containing the highlight skip rebuild when highlight
    //     moves elsewhere.
    //   • Per-verse (isSelected / isBookmarked / isNoted /
    //     highlightColor) for every verse in the group.
    //
    // shouldRebuild uses `listEquals` because Dart's default List
    // equality is identity-based. The Selector function still runs
    // on every notify, but it's O(group.length * 4) ≈ 20 hash
    // lookups — vs. the full RichText rebuild it now avoids.
    return Selector<MainProvider, List<Object?>>(
      selector: (_, mp) {
        final hi = mp.highlightIndex;
        final localHighlight = (hi != null &&
                hi >= startVerseIndex &&
                hi < startVerseIndex + group.length)
            ? hi - startVerseIndex
            : -1;
        return [
          localHighlight,
          for (final v in group) ...[
            mp.isSelected(v),
            mp.isBookmarked(v),
            mp.isVerseNoted(v),
            mp.getHighlightColor(v),
          ],
        ];
      },
      shouldRebuild: (prev, curr) => !listEquals(prev, curr),
      builder: (context, _, __) {
        // `context.read` doesn't subscribe — the Selector above
        // owns the subscription. Reads still return live state.
        final mainProvider = context.read<MainProvider>();
        // 2026-07-20 PERF: watch<AppSettings>() -> scoped select. This
        // builder already runs inside the Selector<MainProvider,...>
        // above that isolates MainProvider-driven rebuilds (v1.3.15);
        // watching the *full* AppSettings undid that isolation on the
        // settings side instead — any AppSettings field change (locale,
        // theme, primaryColor, paragraphMode, dozens of others) rebuilt
        // every visible paragraph group. Select only the fields this
        // builder (and buildVerseContentSpans / BlockNoteCard, which it
        // calls) actually read. Same pattern already used for
        // LiquidGlassButton / _GreetingCard / _CountTile.
        context.select<AppSettings, (String, double, String, double, bool)>(
            (s) => (
                  s.locale,
                  s.fontSize,
                  s.fontFamily,
                  s.lineSpacing,
                  s.boldVerseText,
                ));
        final settings = context.read<AppSettings>();
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
            // 2026-05-24 (v1.3.37): the note glyph is now a direct
            // tap target — tapping opens the existing note editor
            // for that verse, skipping the select-verse → bottom-bar
            // "note" two-tap flow. User-reported as a UX gap:
            // "在verse上那个note标签现在需要选中经文再按note才打开".
            //
            // The GestureDetector sits in a WidgetSpan so the icon
            // remains inline with the surrounding RichText. behaviour
            // is opaque so the parent verse-tap (selection toggle)
            // doesn't fire on the glyph's bounding box.
            allSpans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 1),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showNoteEditor(
                    context: context,
                    verses: [verse],
                    locale: locale,
                    mainProvider: mainProvider,
                  ),
                  child: Icon(
                    Icons.sticky_note_2,
                    size: settings.fontSize * 0.78,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.7),
                  ),
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

          // 2026-05-19 (v1.2.55): the v1.2.53 cross-version LEB
          // insights chip was removed per user feedback. LEB's
          // own `{clarification}` + `<note: …>` annotations
          // continue to render inline via `buildVerseContentSpans`
          // (clickable highlighted phrase + popup); biblexg-v2's
          // notes render the same way. No additional overlay
          // for non-native versions.

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

        // 2026-05-24 (v1.3.4) PERF: RepaintBoundary isolates this
        // paragraph group's paint layer — see VerseWidget for the
        // same rationale.
        return RepaintBoundary(child: Material(
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
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                // 2026-05-19 (v1.2.57): block-level editorial footnotes.
                // LJK2 ships ~563 of these — e.g. Matt 1:16's
                // "16节注：「基督」是希伯来语…" which the upstream
                // mattwhatsup.github.io site renders as a small
                // indented paragraph between v16 and v17. Each verse's
                // `blockNotes` is rendered as its own subtle box BELOW
                // the verse content, matching the upstream layout.
                for (final verse in group)
                  for (final note in verse.blockNotes)
                    BlockNoteCard(note: note, settings: settings),
              ],
            ),
          ),
        ));
      },
    );
  }
}

// 2026-05-19 (v1.2.57): the BlockNoteCard widget was extracted to
// `lib/widgets/block_note_card.dart` so verse_widget.dart (verse-
// by-verse mode) can render block notes the same way as paragraph
// mode. See that file for the BlockNoteCard implementation.
