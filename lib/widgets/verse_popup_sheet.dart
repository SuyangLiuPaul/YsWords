import 'package:flutter/material.dart';
import 'package:yswords/utils/clipboard_helper.dart';
// 2026-05-24 (v1.3.7): get package no longer used directly here —
// navigateToReader helper encapsulates all push/pop logic.
// import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeVerseText;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
// 2026-05-24 (v1.3.7): home_page direct import gone — navigateToReader
// helper owns the HomePage construction.
// import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart' show bookNameToEnglish;
import 'package:yswords/utils/floating_toast.dart' show showFloatingToast;
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/navigate_to_reader.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

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

  /// True while a force-load of mp.verses is in flight. Used to swap
  /// the empty-state placeholder for a spinner so users don't see a
  /// "Verse text not loaded" message while data is actually loading.
  bool _loadingVerses = false;

  @override
  void initState() {
    super.initState();
    // If the user lands here before bootstrap fetched verses (e.g.
    // tapped a sermon ref straight off the dashboard, or the version
    // hasn't been loaded yet for the cited book), kick off a load so
    // the popup can resolve the citation instead of showing the
    // empty "verse text not loaded" placeholder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVersesLoaded();
    });
  }

  Future<void> _ensureVersesLoaded() async {
    if (!mounted) return;
    final mp = context.read<MainProvider>();
    final hasMatch = mp.verses.any((v) {
      final enBook = bookNameToEnglish[v.book] ?? v.book;
      return enBook == widget.reference.englishBook &&
          v.chapter == widget.reference.chapter;
    });
    if (hasMatch) return;
    setState(() => _loadingVerses = true);
    try {
      // First try: if the version is loaded but the book isn't there
      // (NT-only translation, OT reference), fall back to a full-canon
      // companion via the same resolver the reader uses.
      final result = await jumper.resolveAndPrepareJump(
        reference: widget.reference,
        mp: mp,
      );
      // The resolver may have switched versions to find the verse.
      // We don't navigate here (this is a popup) — we just rely on
      // the side-effects (mp.verses populated) so the rebuild picks
      // up the data.
      if (!mounted) return;
      // Surface a soft notice if a version switch happened, mirroring
      // the reader's "Switched to ..." snackbar.
      if (result.switchedVersion && result.switchedToLabel != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(
            'Switched to ${result.switchedToLabel} for this verse.',
          ),
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingVerses = false);
    }
  }

  // No dispose() override needed — the sheet's scroll controller is
  // owned by DraggableScrollableSheet (passed in via `draggable`),
  // and the post-frame `_ensureVersesLoaded` future already guards on
  // `mounted` before touching state.

  /// Resolve the cited verses out of MainProvider's loaded
  /// dataset. Match by english book + chapter, then filter to the
  /// cited verses unless [_fullChapter] is on.
  ///
  /// 2026-05-20 (v1.2.62): when the reference carries an explicit
  /// `verses` list (compact comma-list refs like `1:2,5,7,9-10`
  /// inserted from a note via the v1.2.61 picker), the per-verse
  /// filter uses set-membership against that list rather than a
  /// contiguous `[start, end]` range. Fully backwards-compatible:
  /// existing sermon refs with `verses=[]` keep the old range
  /// filter.
  List<Verse> _resolveVerses(MainProvider mp) {
    final ref = widget.reference;
    final all = mp.verses;
    final results = <Verse>[];
    final explicitVerses =
        ref.hasExplicitVerses ? ref.verses.toSet() : null;
    for (final v in all) {
      final enBook = bookNameToEnglish[v.book] ?? v.book;
      if (enBook != ref.englishBook) continue;
      if (v.chapter != ref.chapter) continue;
      if (!_fullChapter) {
        if (explicitVerses != null) {
          if (!explicitVerses.contains(v.verse)) continue;
        } else if (ref.verseStart != null) {
          final n = v.verse;
          final start = ref.verseStart!;
          final end = ref.verseEnd ?? start;
          if (n < start || n > end) continue;
        }
      }
      results.add(v);
    }
    return results;
  }

  /// Verses fall in the cited range — used to highlight them
  /// when in full-chapter mode.
  bool _isCited(Verse v) {
    final ref = widget.reference;
    if (ref.hasExplicitVerses) {
      return ref.verses.contains(v.verse);
    }
    if (ref.verseStart == null) return false;
    return v.verse >= ref.verseStart! &&
        v.verse <= (ref.verseEnd ?? ref.verseStart!);
  }

  String _refLabel(String locale) {
    final ref = widget.reference;
    final book = localeAwareBookName(ref.englishBook, locale);
    if (_fullChapter) return '$book ${ref.chapter}';
    if (ref.hasExplicitVerses) {
      // Compact form: '1:2-3,5,7,9-10' built the same way as
      // BibleReference.toString().
      final verses = ref.verses;
      final parts = <String>[];
      int start = verses.first;
      int end = start;
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
      return '$book ${ref.chapter}:${parts.join(',')}';
    }
    if (ref.verseStart == null) return '$book ${ref.chapter}';
    if (ref.verseEnd != null && ref.verseEnd! > ref.verseStart!) {
      return '$book ${ref.chapter}:${ref.verseStart}-${ref.verseEnd}';
    }
    return '$book ${ref.chapter}:${ref.verseStart}';
  }

  Future<void> _copyAll(List<Verse> verses, String locale) async {
    if (verses.isEmpty) return;
    // _refLabel already pulls the locale-aware book name; no need to
    // recompute it separately.
    final buf = StringBuffer();
    buf.writeln('${_refLabel(locale)}\n');
    for (final v in verses) {
      buf.writeln('${v.verse}. ${sanitizeVerseText(v.text)}');
    }
    final scheme = Theme.of(context).colorScheme;
    final ok = await ClipboardHelper.copyText(buf.toString().trim());
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
  }

  Future<void> _openInReader() async {
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(
        reference: widget.reference, mp: mp);
    if (!mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !mounted) return;
    // 2026-05-24 (v1.3.7): delegate to the shared navigateToReader
    // helper. It walks the stack for an existing HomePage (route
    // name '/HomePage' — set by every push site since v1.3.6), pops
    // every route above it, and only pushes a fresh HomePage if
    // none exists. pendingJump (set by resolveAndPrepareJump
    // above) is consumed by whichever HomePage ends up on top.
    navigateToReader(context);
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
            // Body: verse list. 2026-05-20 (v1.2.64): wrapped in
            // AnimatedSwitcher so the expand / collapse toggle on
            // _fullChapter cross-fades between the cited-only and
            // whole-chapter views (250 ms ease-in-out) instead of
            // snapping. Each variant gets a distinct ValueKey so
            // AnimatedSwitcher detects the swap.
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      // v1.3.95 (Flutter 3.44): axisAlignment (double) →
                      // alignment. -1.0 on the default vertical axis == top.
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  );
                },
                child: verses.isEmpty
                    ? (_loadingVerses
                        ? const Center(
                            key: ValueKey('loading'),
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('empty'),
                            child: _buildEmpty(locale, scheme),
                          ))
                    : ListView.builder(
                        key: ValueKey(
                            _fullChapter ? 'full' : 'cited'),
                        controller: draggable,
                        padding:
                            const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: verses.length,
                        itemBuilder: (_, i) => _buildVerseTile(
                            verses[i], settings, scheme),
                      ),
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
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
              // Sanitize annotation markup so the popup shows clean
              // readable prose. The reading pane has rich rendering
              // for `<note:...>` / `{...}` / `[...]`; the popup is
              // a peek surface and renders plain text only.
              TextSpan(text: sanitizeVerseText(v.text)),
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
