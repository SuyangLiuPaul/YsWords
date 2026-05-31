import 'package:flutter/material.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/widgets/left_accent_card.dart';

/// 2026-05-19 (v1.2.57): block-level editorial footnote rendered
/// BELOW a verse. Used by both `paragraph_group_widget` (paragraph
/// mode) and `verse_widget` (verse-by-verse mode).
///
/// Distinct from the inline `<note: …>` popup chip:
///   • inline `<note: …>` is a tappable book-icon glyph beside a
///     specific word — short, popup-style explanation
///   • [BlockNoteCard] is a full paragraph of editorial commentary
///     pinned beneath the verse, always visible — e.g. LJK2 Matt
///     1:16's "16节注：「基督」是希伯来语「弥赛亚」的希腊文译音…"
///
/// Style is intentionally quiet: ~0.82× verse font, italic, low-
/// contrast primary-tint fill + 3 px left rule. The verse text
/// stays primary and the commentary reads as supplementary
/// background.
class BlockNoteCard extends StatelessWidget {
  final String note;
  final AppSettings settings;

  const BlockNoteCard({super.key, required this.note, required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dc = ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width);
    final baseIndent = ResponsiveBreakpoints.verseIndent(dc);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        baseIndent + 16,
        settings.fontSize * 0.25,
        baseIndent + 16,
        settings.fontSize * 0.15,
      ),
      // v1.3.x: was Container(BoxDecoration(border: Border(left:...),
      // borderRadius: only-right)) — a non-uniform border + radius,
      // which throws in Border.paint. LeftAccentCard draws the stripe
      // as a clipped child.
      child: LeftAccentCard(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        background: scheme.primary.withValues(alpha: 0.06),
        accentColor: scheme.primary.withValues(alpha: 0.35),
        accentWidth: 3,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        child: SelectableText(
          note,
          style: TextStyle(
            fontSize: settings.fontSize * 0.82,
            fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
            height: settings.lineSpacing,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
