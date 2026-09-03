import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// The secondary line under a tapped run of the tagged Chinese verse:
/// the OTHER original words that run's span covers.
///
/// **What `i` is, and what this line may therefore claim.** The tagged
/// corpus gives every run a primary number `s` and a list `i`. `s` is
/// "this Chinese renders that original word". `i` is weaker and
/// different in kind: the importer recorded that the stretch of original
/// this run covers ALSO contains those words. It is not a second opinion
/// about the tapped word, so the line says *other words this text
/// covers* and never "also means" or "or". Where the two are confused a
/// reader is told the app is claiming something it is not.
///
/// It is deliberately weaker than `s` on screen as well as in wording:
/// it renders BELOW the verse line and below the original-word chips
/// that already carry the tapped run's own number, at
/// [kImpliedFontSize] against the verse's [kTaggedVerseFontSize], with
/// no accent card and `onSurfaceVariant` rather than `onSurface`.
///
/// **Why it exists.** Until 2026-09-03 `TaggedRun.implied` was parsed
/// and read by no widget at all, so any number that was no run's `s`
/// could not be tapped anywhere. Measured over the shipped corpus that
/// hid a number in **21,230 verses** whose original really contains it —
/// 39,534 (verse, number) pairs. `test/implied_coverage_census_test.dart`
/// holds the measurement.
///
/// **What is filtered, and why each is a claim we decline to make.**
///
///   * A number equal to the run's own `s`. Printing it under the label
///     "other words" would say the span covers that word twice.
///   * `H0` / `G0`. Not Strong's numbers — the tagger's marker for
///     translation-supplied text (see [TaggedRun.isSuppliedMarker]).
///   * A number the lexicon cannot answer. The chip's whole content is
///     the lemma and gloss the entry supplies; without an entry it would
///     print a bare number that opens 「Lexicon entry not found」. No
///     number in the shipped corpus is currently in this state — the
///     guard is for the next import, and is pinned by a test rather than
///     left to be discovered on a reader's screen.
///
/// When nothing survives the filter the widget renders nothing at all.
class ImpliedCoverageLine extends StatelessWidget {
  const ImpliedCoverageLine({
    super.key,
    required this.run,
    required this.lexicon,
    required this.locale,
    this.onTapNumber,
  });

  /// The run the reader tapped.
  final TaggedRun run;

  /// Resolved lexicon entries by Strong's number. A key that is missing,
  /// or present with a null value, is a number the lexicon cannot
  /// answer — both are treated as "no entry".
  final Map<String, StrongsEntry?> lexicon;

  final String locale;

  /// Invoked with the Strong's number when the reader taps a chip.
  final void Function(String number)? onTapNumber;

  /// The numbers this line will print, in corpus order, deduplicated.
  ///
  /// Static so the census test can ask the widget's own question of the
  /// whole corpus instead of restating the rules.
  static List<String> visibleNumbers(
    TaggedRun run,
    Map<String, StrongsEntry?> lexicon,
  ) {
    final out = <String>[];
    for (final number in run.implied) {
      if (number.isEmpty) continue;
      if (number == run.strongs) continue;
      if (TaggedRun.isSuppliedMarker(number)) continue;
      if (lexicon[number] == null) continue;
      if (out.contains(number)) continue;
      out.add(number);
    }
    return out;
  }

  /// The tapped run's text, as printed in the label. Long runs are
  /// elided so a whole clause cannot push the chips off the first
  /// screen — 〔或译：…〕 apparatus runs are the reason.
  static String labelText(String text) {
    final trimmed = text.trim();
    return trimmed.characters.length <= 12
        ? trimmed
        : '${trimmed.characters.take(12)}…';
  }

  @override
  Widget build(BuildContext context) {
    final numbers = visibleNumbers(run, lexicon);
    if (numbers.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final label = (uiStrings['impliedCoverageLabel']?[locale] ??
            'Other original words “{w}” also covers')
        .replaceAll('{w}', labelText(run.text));
    final note = uiStrings['impliedCoverageNote']?[locale] ??
        'The tagger recorded these as falling inside the original this '
            'text covers. They are not the tapped word\'s own number.';
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: kImpliedFontSize,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final number in numbers)
                _ImpliedChip(
                  number: number,
                  entry: lexicon[number]!,
                  locale: locale,
                  onTap: onTapNumber == null
                      ? null
                      : () => onTapNumber!(number),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(
              fontSize: kImpliedNoteFontSize,
              fontStyle: FontStyle.italic,
              height: 1.35,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tagged verse line's own size. The implied line must stay under
/// it, so both constants live together and a change to one is visibly a
/// change to the relationship.
const double kTaggedVerseFontSize = 14;
const double kImpliedFontSize = 11;
const double kImpliedNoteFontSize = 10;

class _ImpliedChip extends StatelessWidget {
  const _ImpliedChip({
    required this.number,
    required this.entry,
    required this.locale,
    this.onTap,
  });

  final String number;
  final StrongsEntry entry;
  final String locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gloss = entry.localizedGloss(locale);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          // No fill and a hairline outline: the primary answer's badge
          // is a filled primary-tinted pill, and this must not read as
          // its equal.
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Forced LTR: a Strong's number reads left-to-right even
            // beside a Hebrew lemma.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                number,
                style: TextStyle(
                  fontSize: kImpliedNoteFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              entry.lemma,
              style: TextStyle(
                fontSize: kImpliedFontSize + 1,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            if (gloss.isNotEmpty) ...[
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  gloss,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: kImpliedFontSize,
                    color: scheme.onSurfaceVariant,
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
