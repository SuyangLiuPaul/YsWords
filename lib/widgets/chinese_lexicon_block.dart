import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/chinese_lexicon_service.dart';
import 'package:yswords/widgets/cbol_reference_text.dart';

/// The Chinese BDB/Thayer article, rendered under the CBOL definition
/// that YsWords already shows.
///
/// **It is placed under, and labelled as, a second source — never in
/// place of the first.** Both blocks describe the same Strong's number,
/// and they come from different publishers under different licences
/// (CBOL is CC-BY-NC-SA and carries its own attribution line inside the
/// originals sheet; this one is used with the yahwehdehua.net
/// publisher's permission). A reader who sees two Chinese paragraphs
/// with no label between them reads the second as a contradiction of
/// the first, so [_header] states the relationship in words —
/// 「同一编号的完整词条」, the fuller entry for the same number — before
/// any of it is shown. Replacing the CBOL block with this one was
/// rejected: the CBOL gloss is the one-line answer the reader usually
/// wants, it has Traditional text where this module has none, and
/// dropping it would silently drop its attribution too.
///
/// Two shapes, from one source:
///
///   * [ChineseLexiconBlock] — the word article: lemma, transliteration,
///     etymology, numbered senses, 钦定本 counts.
///   * [ChineseGrammarCodes] — the decoded grammar codes for a tagged
///     run. These are a note about the FORM on the line, not a
///     definition of the word, so they render as their own boxed rows
///     above the article rather than as another field inside it.
///
/// Both render nothing at all when they have nothing to say, so a
/// caller can place them unconditionally.
class ChineseLexiconBlock extends StatelessWidget {
  const ChineseLexiconBlock({
    super.key,
    required this.entry,
    required this.locale,
    this.fontSize = 14,
  });

  /// The resolved article. A grammar-code entry is not an article and
  /// is refused here — pass it to [ChineseGrammarCodes] instead.
  final ChineseLexEntry entry;

  final String locale;

  /// Body text size, so the block tracks the reader's font-size setting
  /// on the surfaces that honour it.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (entry.isGrammarCode || entry.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final headword = [entry.lemma, entry.translit]
        .where((s) => s.isNotEmpty)
        .join('  ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: scheme.secondary.withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(scheme),
          if (headword.isNotEmpty)
            _field(scheme, _s('chineseLexLemma', 'Lemma'), headword),
          if (entry.etymology.isNotEmpty)
            _field(scheme, _s('chineseLexOrigin', 'Origin'), entry.etymology),
          if (entry.senses.isNotEmpty)
            _field(scheme, _s('chineseLexSenses', 'Definition'),
                entry.senses.join('\n')),
          if (entry.usage.isNotEmpty)
            _field(scheme, _s('chineseLexUsage', 'KJV usage'), entry.usage),
          if (ChineseLexiconService.isSimplifiedOnly(locale)) ...[
            const SizedBox(height: 6),
            Text(
              _s('chineseLexSimplifiedOnly',
                  'This lexicon is published in Simplified Chinese only.'),
              style: TextStyle(
                fontSize: fontSize - 3,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  /// The line that keeps this from reading as a second, conflicting
  /// answer to the definition above it.
  Widget _header(ColorScheme scheme) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          _s('chineseLexTitle', 'Fuller entry for the same number '
              '(BDB / Thayer, Chinese edition)'),
          style: TextStyle(
            fontSize: fontSize - 3.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSecondaryContainer,
            letterSpacing: 0.4,
          ),
        ),
      );

  /// One labelled row of the article.
  ///
  /// The senses cite scripture inline in CBOL's `#…|` notation, so the
  /// value goes through [CbolReferenceText] rather than a plain
  /// [TextSpan]: the delimiters come off and every citation the parser
  /// can resolve becomes a tap into the reader. This is the surface
  /// that gets the links because it is the one holding the raw asset —
  /// `StrongsEntry` flattens its own fields to plain text before any
  /// widget sees them, since the six places it is printed have room for
  /// one line, not for a target.
  Widget _field(ColorScheme scheme, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Semantics(
          label: value.contains('#')
              ? cbolReferenceSemanticsLabel(locale)
              : null,
          child: CbolReferenceText(
            source: value,
            label: '$label  ',
            labelStyle: TextStyle(
              fontSize: fontSize,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
            style: TextStyle(
              fontSize: fontSize,
              height: 1.45,
              color: scheme.onSurface,
            ),
          ),
        ),
      );
}

/// The decoded grammar codes for one tagged run — H8804, G5656 and the
/// 282 others the corpus uses.
///
/// **Nothing else in the app can explain one of these.** They are in
/// `TaggedRun.grammar` for every book of `assets/tagged/cuvs-yhwh/`,
/// 98,861 occurrences of them, and both shipped Strong's lexicons stop
/// short of the range they live in — so before this widget the field was
/// parsed by [TaggedRun] and read by nobody. See
/// `lib/services/chinese_lexicon_service.dart` for the census.
///
/// Rendered as boxed rows keyed by the code itself, so a reader who has
/// seen the number somewhere else recognises it here. The Hebrew codes
/// read in English and the Greek in Chinese; that is the source module's
/// own asymmetry and is shown as it stands rather than half-translated.
class ChineseGrammarCodes extends StatelessWidget {
  const ChineseGrammarCodes({
    super.key,
    required this.codes,
    this.fontSize = 13,
  });

  /// Resolved grammar entries, in the order the run lists them.
  /// Anything that is not a grammar code is skipped.
  final List<ChineseLexEntry> codes;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final shown = codes.where((c) => c.isGrammarCode).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in shown)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: scheme.tertiary.withValues(alpha: 0.25),
                width: 0.6,
              ),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${c.number}  ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                TextSpan(
                  text: c.parsing.join(' · '),
                  style: TextStyle(color: scheme.onSurface),
                ),
              ]),
              style: TextStyle(fontSize: fontSize, height: 1.4),
            ),
          ),
      ],
    );
  }
}
