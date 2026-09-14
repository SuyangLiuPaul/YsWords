import 'package:flutter/material.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/app_scroll_behavior.dart'
    show kSelectableTextPhysics;
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
///     pinned beneath the verse — e.g. LJK2 Matt 1:16's
///     "16节注：「基督」是希伯来语「弥赛亚」的希腊文译音…"
///
/// 2026-09-14: it is no longer always open. 「sword这个部分没有collapse」
/// — 梁家鏗's apparatus is not a footnote-sized thing. 羅馬書 8:26 carries
/// two of these, one of which is a bare list of forty-odd references, and
/// between them they push the scripture off a phone screen entirely. The
/// card now opens on a tap and shows its first line when closed, which is
/// the same move the inline `<note: …>` markers made on the same day —
/// see `build_verse_content_spans.dart`. One tap target, one behaviour,
/// whichever kind of note the reader meets.
///
/// Closed by DEFAULT, and that is the whole point: an expander that
/// starts open saves nobody anything. The state lives in this widget, so
/// scrolling away and back closes it again and nothing has to be
/// threaded through the verse list.
///
/// Style is intentionally quiet: ~0.82× verse font, italic, low-
/// contrast primary-tint fill + 3 px left rule. The verse text
/// stays primary and the commentary reads as supplementary
/// background.
class BlockNoteCard extends StatefulWidget {
  final String note;
  final AppSettings settings;

  const BlockNoteCard({super.key, required this.note, required this.settings});

  @override
  State<BlockNoteCard> createState() => _BlockNoteCardState();
}

class _BlockNoteCardState extends State<BlockNoteCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final settings = widget.settings;
    final scheme = Theme.of(context).colorScheme;
    final dc = ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width);
    final baseIndent = ResponsiveBreakpoints.verseIndent(dc);
    final bodyStyle = TextStyle(
      fontSize: settings.fontSize * 0.82,
      fontFamily: settings.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      height: settings.lineSpacing,
      fontStyle: FontStyle.italic,
      color: Theme.of(context).textTheme.bodyMedium?.color,
    );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Closed: the first line IS the tap target, so the reader
            // sees what the note is about before deciding. A plain Text
            // and not a SelectableText — a selectable widget takes the
            // tap as a caret placement and the card would never open.
            if (!_open)
              InkWell(
                onTap: () => setState(() => _open = true),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.expand_more,
                        size: settings.fontSize * 0.82,
                        color: scheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            // Open: the full note, selectable, with the close affordance
            // on its own row. Copying a footnote is the reason this is a
            // SelectableText at all, so it must be the selectable one.
            if (_open) ...[
              SelectableText(
                note.trim(),
                scrollPhysics: kSelectableTextPhysics,
                style: bodyStyle,
              ),
              InkWell(
                onTap: () => setState(() => _open = false),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.expand_less,
                      size: settings.fontSize * 0.82,
                      color: scheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
