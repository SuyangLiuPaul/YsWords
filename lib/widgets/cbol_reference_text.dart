import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/cbol_references.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/navigate_to_reader.dart';
import 'package:yswords/utils/reference_parser.dart' show BibleReference;

/// A run of Chinese lexicon text whose scripture citations are live.
///
/// Parity note (BibleWorks 10 help, "Resource windows"): a reference
/// inside a resource window is a target — clicking it moves the browse
/// window there. The Chinese lexicon is the deepest resource this app
/// bundles for a Chinese reader, and until now its references were not
/// merely inert but illegible, printing as `(#路 14:19-30|)`.
///
/// **The tap goes through YsWords' own jump machinery**, not through a
/// callback the caller supplies: `resolveAndPrepareJump` →
/// `showJumpResultSnackBar` → `navigateToReader`. That chain is what
/// every other cross-link surface in the app uses (the verse popup, the
/// evidence detail page, the videos page), and it carries two behaviours
/// a hand-rolled push would lose — it transparently switches to the
/// full-canon version when the reader is on an NT-only translation and
/// the citation is in the Old Testament, and it re-uses an existing
/// HomePage instead of stacking a duplicate one. A citation into
/// Genesis from an NT-only reading version is not a rare case here: it
/// is most of the Hebrew lexicon.
///
/// Stateful because a [TapGestureRecognizer] must be disposed, and this
/// widget builds one per citation. An entry with fifteen citations
/// rebuilding on every scroll frame leaks fifteen a frame otherwise.
class CbolReferenceText extends StatefulWidget {
  const CbolReferenceText({
    super.key,
    required this.source,
    required this.style,
    this.label,
    this.labelStyle,
    this.linkColor,
  });

  /// The lexicon field as it ships, delimiters and all. Passing text a
  /// model has already flattened is not an error, it just yields no
  /// links — there is nothing left to find.
  final String source;

  final TextStyle style;

  /// Optional bold prefix, e.g. the field name in a lexicon article.
  final String? label;
  final TextStyle? labelStyle;

  /// Colour for a resolved citation. Defaults to the scheme's primary.
  final Color? linkColor;

  @override
  State<CbolReferenceText> createState() => _CbolReferenceTextState();
}

class _CbolReferenceTextState extends State<CbolReferenceText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(CbolRun run) async {
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(
      reference: BibleReference(
        englishBook: run.englishBook!,
        chapter: run.chapter!,
        // A hyphen in CBOL is a passage span, so the link opens where
        // the passage opens. `verse` is null when the lexicon cited a
        // whole chapter (`士 4`), and chapter 1 of the reader is the
        // right landing there too.
        verseStart: run.verse,
        verseEnd: run.verse,
      ),
      mp: mp,
    );
    if (!mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !mounted) return;
    navigateToReader(context);
  }

  @override
  Widget build(BuildContext context) {
    // Every build replaces the recognizers, so the old ones must go
    // with it rather than accumulating.
    _release();
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(children: [
        if (widget.label != null)
          TextSpan(
            text: widget.label,
            style: widget.labelStyle ??
                widget.style.copyWith(fontWeight: FontWeight.w700),
          ),
        ...buildCbolSpans(
          source: widget.source,
          baseStyle: widget.style,
          refColor: widget.linkColor ?? scheme.primary,
          onRefTap: _open,
          recognizers: _recognizers,
        ),
      ]),
    );
  }
}

/// The label a screen reader announces for a citation link. Kept beside
/// the widget so a caller wrapping one in [Semantics] does not have to
/// go looking for the key.
String cbolReferenceSemanticsLabel(String locale) =>
    uiStrings['cbolOpenReference']?[locale] ?? 'Open this reference';
