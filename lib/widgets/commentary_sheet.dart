import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/app_scroll_behavior.dart'
    show kSelectableTextPhysics;
import 'package:yswords/models/verse.dart';
import 'package:yswords/services/commentary_service.dart';
import 'package:yswords/utils/version_mapper.dart';

/// Renders a commentary string. `**` delimits a bold run and is the only
/// markup `tools/build_commentary_jfb.py` emits, so this is the whole parser.
/// A stray unmatched `**` degrades to plain text rather than swallowing the
/// rest of the paragraph.
class CommentaryText extends StatelessWidget {
  final String text;
  final double fontSize;

  const CommentaryText({
    super.key,
    required this.text,
    required this.fontSize,
  });

  /// Splits [raw] into (isBold, run) pairs on `**` delimiters.
  static List<(bool, String)> parse(String raw) {
    final out = <(bool, String)>[];
    var i = 0;
    var bold = false;
    while (i < raw.length) {
      final next = raw.indexOf('**', i);
      if (next < 0) {
        out.add((bold, raw.substring(i)));
        break;
      }
      if (next > i) out.add((bold, raw.substring(i, next)));
      bold = !bold;
      i = next + 2;
    }
    return out.where((r) => r.$2.isNotEmpty).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SelectableText.rich(
      // The commentary sits in the sheet's ListView; without this the
      // SelectableText keeps its own scrollable and swallows a drag meant
      // for the sheet. See test/selectable_text_scroll_test.dart.
      scrollPhysics: kSelectableTextPhysics,
      TextSpan(
        children: [
          for (final (bold, run) in parse(text))
            TextSpan(
              text: run,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: bold
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
      style: TextStyle(fontSize: fontSize, height: 1.55),
    );
  }
}

/// Body of the commentary sheet. Loads the book lazily on first build and
/// shows the single block covering the selected verse.
class CommentarySheetBody extends StatefulWidget {
  final String englishBook;

  /// Book name as the reader currently sees it, for the header.
  final String displayBook;
  final int chapter;
  final int verse;
  final String locale;
  final double fontSize;
  final ScrollController? scrollController;

  const CommentarySheetBody({
    super.key,
    required this.englishBook,
    required this.displayBook,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.fontSize,
    this.scrollController,
  });

  @override
  State<CommentarySheetBody> createState() => _CommentarySheetBodyState();
}

class _CommentarySheetBodyState extends State<CommentarySheetBody> {
  late Future<CommentaryBook?> _future;

  @override
  void initState() {
    super.initState();
    _future = CommentaryService.forBook(widget.englishBook);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final headerLabel = uiStrings['commentary']?[locale] ?? 'Commentary';
    final reference = '${widget.displayBook} '
        '${widget.chapter}:${widget.verse}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
          child: Row(
            children: [
              Icon(Icons.article_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headerLabel,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(reference,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                scheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<CommentaryBook?>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final book = snap.data;
              final block = book?.forVerse(widget.chapter, widget.verse);
              if (book == null || block == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      uiStrings['commentaryNone']?[locale] ??
                          'No commentary is available for this verse yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65)),
                    ),
                  ),
                );
              }
              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  if (block.heading.isNotEmpty) ...[
                    Text(
                      block.heading,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Text(
                      block.rangeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  CommentaryText(
                      text: block.text, fontSize: widget.fontSize),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // The copyright expired well over a century ago, but the
                  // queue item asks for the credit anyway and it costs one
                  // line. Full evidence: docs/jfb-commentary-licence.md.
                  Text(
                    '${book.authors}, ${book.title} '
                    '(${book.firstPublished}). '
                    '${uiStrings['commentaryPublicDomain']?[locale] ?? 'Public domain.'}',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Opens the commentary sheet for the first of [verses].
///
/// Public so `bible_reading_pane.dart` only has to add a button and one call
/// — the sheet, its state and its renderer all live here.
void showCommentarySheet({
  required BuildContext context,
  required List<Verse> verses,
  required String locale,
  required double fontSize,
}) {
  if (verses.isEmpty) return;
  final sorted = [...verses]..sort((a, b) {
      final c = a.chapter.compareTo(b.chapter);
      return c != 0 ? c : a.verse.compareTo(b.verse);
    });
  final source = sorted.first;
  final englishBook = toEnglish(source.book) ?? source.book;

  showModalBottomSheet<void>(
    // useSafeArea: without it Flutter wraps the sheet in
    // MediaQuery.removePadding(removeTop: true), so any SafeArea INSIDE the
    // sheet sees padding.top == 0 and draws under the clock and the notch.
    useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 900),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Scaffold(
        backgroundColor: Colors.transparent,
        body: CommentarySheetBody(
          englishBook: englishBook,
          displayBook: source.book,
          chapter: source.chapter,
          verse: source.verse,
          locale: locale,
          fontSize: fontSize,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}
