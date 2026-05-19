import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/note_reference_parser.dart'
    show NoteReferenceMatch;
import 'package:yswords/utils/version_mapper.dart' show translateBookName;

/// 2026-05-19 (v1.2.61): Inline preview sheet for verse references
/// embedded in a saved note.
///
/// User flow:
///   1. View a note in Library → tap any `[John 3:16]` reference
///   2. This sheet slides up from the bottom showing JUST the
///      referenced verse(s) — text + verse numbers
///   3. Tap "Expand" to see the whole chapter for context
///   4. Tap "Collapse" to return to the referenced verses only
///   5. Tap "Open in Reader" for full navigation (closes the sheet
///      AND the surrounding Library page, lands in the Bible reader
///      with smooth-scroll + highlight from v1.2.50)
///   6. Tap close / swipe down to dismiss without navigating
///
/// Replaces the v1.2.59 "tap ref → immediately navigate" behaviour,
/// which forced the user out of their note-reading context just to
/// glance at a cross-reference. Preview-first is the WeDevote-style
/// pattern the user asked for.
Future<void> showNoteReferencePreviewSheet({
  required BuildContext context,
  required NoteReferenceMatch ref,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => _NoteReferencePreviewSheet(ref: ref),
  );
}

class _NoteReferencePreviewSheet extends StatefulWidget {
  final NoteReferenceMatch ref;
  const _NoteReferencePreviewSheet({required this.ref});

  @override
  State<_NoteReferencePreviewSheet> createState() =>
      _NoteReferencePreviewSheetState();
}

class _NoteReferencePreviewSheetState
    extends State<_NoteReferencePreviewSheet> {
  bool _expanded = false;

  /// Returns the verses to show in the sheet body.
  ///
  /// - Collapsed: ONLY the verses in `ref.verses` (the spec the
  ///   user wrote — single, range, or comma-list).
  /// - Expanded: the WHOLE chapter (every verse in `ref.englishBook`
  ///   chapter `ref.chapter`), so the user gets surrounding context
  ///   without leaving the note.
  ///
  /// Each verse is highlighted if it's part of the original ref —
  /// expanded mode keeps the reference verses visually distinct
  /// from the context verses.
  List<Verse> _versesToShow(MainProvider mp) {
    final ref = widget.ref;
    final localBook = translateBookName(ref.englishBook, mp.currentVersion);
    final chapterAll = mp.verses
        .where((v) =>
            (v.book == localBook || v.book == ref.englishBook) &&
            v.chapter == ref.chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));

    if (_expanded) return chapterAll;
    return chapterAll
        .where((v) => ref.verses.contains(v.verse))
        .toList();
  }

  String _refLabel() {
    final ref = widget.ref;
    final verses = ref.verses;
    if (verses.length == 1) {
      return '${ref.englishBook} ${ref.chapter}:${verses.first}';
    }
    // Compact display: '1:2-5' or '1:2,5,7,9-10'
    final parts = <String>[];
    var start = verses.first;
    var end = start;
    for (var i = 1; i < verses.length; i++) {
      final v = verses[i];
      if (v == end + 1) {
        end = v;
      } else {
        parts.add(start == end ? '$start' : '$start-$end');
        start = v;
        end = v;
      }
    }
    parts.add(start == end ? '$start' : '$start-$end');
    return '${ref.englishBook} ${ref.chapter}:${parts.join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final mp = context.watch<MainProvider>();
    final locale = settings.locale;
    final verses = _versesToShow(mp);

    return DraggableScrollableSheet(
      initialChildSize: _expanded ? 0.85 : 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header: reference label + close
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded,
                    color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _refLabel(),
                    style: TextStyle(
                      fontSize: settings.fontSize + 1,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      fontFamily: settings.fontFamily,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: uiStrings['close']?[locale] ?? 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Body verses
          Expanded(
            child: verses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        uiStrings['notePreviewMissing']?[locale] ??
                            "This passage isn't in your current Bible "
                                "version. Open it in the reader to switch "
                                "versions.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: settings.fontSize - 2,
                          color: scheme.onSurfaceVariant,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: verses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final v = verses[i];
                      final isPartOfRef = widget.ref.verses.contains(v.verse);
                      final isContextOnly = _expanded && !isPartOfRef;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPartOfRef
                              ? scheme.primaryContainer
                                  .withValues(alpha: 0.45)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: settings.fontSize,
                              fontFamily: settings.fontFamily,
                              height: 1.5,
                              color: isContextOnly
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                            children: [
                              TextSpan(
                                text: '${v.verseLabel} ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary
                                      .withValues(alpha: isContextOnly ? 0.6 : 1.0),
                                ),
                              ),
                              TextSpan(text: sanitizeForSearch(v.text)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Footer actions
          Container(
            padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  icon: Icon(
                    _expanded
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    color: scheme.primary,
                  ),
                  label: Text(
                    _expanded
                        ? (uiStrings['notePreviewCollapse']?[locale] ??
                            'Collapse')
                        : (uiStrings['notePreviewExpand']?[locale] ??
                            'Expand chapter'),
                    style: TextStyle(color: scheme.primary),
                  ),
                  onPressed: verses.isEmpty
                      ? null
                      : () => setState(() => _expanded = !_expanded),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    uiStrings['notePreviewOpenReader']?[locale] ??
                        'Open in Reader',
                  ),
                  onPressed: () => _openInReader(mp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openInReader(MainProvider mp) {
    final ref = widget.ref;
    final localBook = translateBookName(ref.englishBook, mp.currentVersion);
    Verse? target;
    for (final book in [localBook, ref.englishBook]) {
      final hits = mp.verses
          .where((v) =>
              v.book == book &&
              v.chapter == ref.chapter &&
              v.verse == ref.verses.first)
          .toList();
      if (hits.isNotEmpty) {
        target = hits.first;
        break;
      }
    }
    if (target == null) return;
    // Close the sheet first, then run the standard pendingJump
    // flow so the reader's post-frame consumer takes over with
    // smooth-scroll + highlight from v1.2.50.
    Navigator.of(context).pop();
    jumper.prepareJumpToVerse(target, mp);
    Get.off(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
  }
}
