import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart' show bookNameToEnglish;
import 'package:yswords/utils/floating_toast.dart' show showFloatingToast;
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;

/// Modal bottom sheet that previews a Bible reference in-place
/// without navigating away. Used by the sermon detail page so
/// readers can peek at verses without losing their place in the
/// sermon text.
///
/// Two display modes:
/// 1. **Range** (default): only the specific verses cited in the
///    reference (e.g. for "John 3:16-18", just verses 16, 17, 18).
/// 2. **Full chapter**: the entire chapter, with the cited verse(s)
///    visually highlighted. User toggles via the expand button in
///    the sheet header.
///
/// The sheet has its own copy / share / "open in reader" actions.
class VersePopupSheet extends StatefulWidget {
  final BibleReference reference;
  const VersePopupSheet({super.key, required this.reference});

  @override
  State<VersePopupSheet> createState() => _VersePopupSheetState();
}

class _VersePopupSheetState extends State<VersePopupSheet> {
  bool _fullChapter = false;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Resolve the cited verses out of MainProvider's loaded
  /// dataset. We match by english book + chapter (+ verse range
  /// when in [_fullChapter]=false mode).
  List<Verse> _resolveVerses(MainProvider mp) {
    final ref = widget.reference;
    final all = mp.verses;
    final results = <Verse>[];
    for (final v in all) {
      final enBook = bookNameToEnglish[v.book] ?? v.book;
      if (enBook != ref.englishBook) continue;
      if (v.chapter != ref.chapter) continue;
      if (!_fullChapter && ref.verseStart != null) {
        final n = v.verse;
        final start = ref.verseStart!;
        final end = ref.verseEnd ?? start;
        if (n < start || n > end) continue;
      }
      results.add(v);
    }
    return results;
  }

  /// Verses fall in the cited range — used to highlight them
  /// when in full-chapter mode.
  bool _isCited(Verse v) {
    final ref = widget.reference;
    if (ref.verseStart == null) return false;
    return v.verse >= ref.verseStart! &&
        v.verse <= (ref.verseEnd ?? ref.verseStart!);
  }

  String _refLabel(String locale) {
    final ref = widget.reference;
    final book = localeAwareBookName(ref.englishBook, locale);
    if (_fullChapter || ref.verseStart == null) {
      return '$book ${ref.chapter}';
    }
    if (ref.verseEnd != null && ref.verseEnd! > ref.verseStart!) {
      return '$book ${ref.chapter}:${ref.verseStart}-${ref.verseEnd}';
    }
    return '$book ${ref.chapter}:${ref.verseStart}';
  }

  Future<void> _copyAll(List<Verse> verses, String locale) async {
    if (verses.isEmpty) return;
    final book = localeAwareBookName(widget.reference.englishBook, locale);
    final buf = StringBuffer();
    buf.writeln('${_refLabel(locale)}\n');
    for (final v in verses) {
      buf.writeln('${v.verse}. ${v.text}');
    }
    final scheme = Theme.of(context).colorScheme;
    bool ok = true;
    try {
      await Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    showFloatingToast(
      context,
      message: ok
          ? (uiStrings['copied']?[locale] ?? 'Copied!')
          : (uiStrings['shareLinkFailed']?[locale] ??
              'Copy failed — clipboard unavailable'),
      icon: ok
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      background: ok ? scheme.primary : scheme.error,
    );
    // Reference unused param warning suppression.
    book.length;
  }

  Future<void> _openInReader() async {
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(
        reference: widget.reference, mp: mp);
    if (!mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !mounted) return;
    Navigator.of(context).maybePop(); // close the popup first
    if (!mounted) return;
    Get.to(() => const HomePage(), transition: Transition.rightToLeft);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final mp = context.watch<MainProvider>();
    final verses = _resolveVerses(mp);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.32,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetCtx, draggable) {
        return Column(
          children: [
            // Drag handle.
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header: ref label + actions + close.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _refLabel(locale),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Toggle: range ↔ full chapter.
                  IconButton(
                    icon: Icon(
                      _fullChapter
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                      size: 22,
                    ),
                    tooltip: _fullChapter
                        ? (uiStrings['versePopupCollapse']?[locale] ??
                            'Show only cited verses')
                        : (uiStrings['versePopupExpand']?[locale] ??
                            'Show full chapter'),
                    onPressed: () =>
                        setState(() => _fullChapter = !_fullChapter),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: uiStrings['copySelection']?[locale] ??
                        'Copy',
                    onPressed: () => _copyAll(verses, locale),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    tooltip: uiStrings['versePopupOpenReader']
                            ?[locale] ??
                        'Open in reader',
                    onPressed: _openInReader,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: uiStrings['close']?[locale] ?? 'Close',
                    onPressed: () => Navigator.of(sheetCtx).maybePop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body: verse list.
            Expanded(
              child: verses.isEmpty
                  ? _buildEmpty(locale, scheme)
                  : ListView.builder(
                      controller: draggable,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: verses.length,
                      itemBuilder: (_, i) =>
                          _buildVerseTile(verses[i], settings, scheme),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(String locale, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 36,
                color: scheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              uiStrings['versePopupNotFound']?[locale] ??
                  "Verse text not loaded — try \"Open in reader\".",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseTile(Verse v, AppSettings settings, ColorScheme scheme) {
    final cited = _isCited(v);
    final highlight = _fullChapter && cited;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: highlight
            ? BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                  width: 0.7,
                ),
              )
            : null,
        padding: highlight
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : EdgeInsets.zero,
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: settings.fontSize,
              color: scheme.onSurface,
              height: 1.55,
            ),
            children: [
              TextSpan(
                text: '${v.verse} ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontSize: settings.fontSize - 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              TextSpan(text: v.text),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience entry point — show a [VersePopupSheet] modal for
/// the given parsed reference.
Future<void> showVersePopup(BuildContext context, BibleReference ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => VersePopupSheet(reference: ref),
  );
}
