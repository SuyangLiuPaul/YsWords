/// 2026-09-08: which translation the Exegesis sheet draws its
/// interlinear against, and how that one is picked.
///
/// The sheet used to answer only "what are this verse's original
/// words", one card per word with its number and a gloss. The owner
/// asked for what 微读圣经 and 精读圣经 do instead — 「我想好像微读圣经
/// 一样可以选译本 我提供这么多 然后这样看也容易些」 — a running line of a
/// translation the reader actually reads, with the numbers set into it:
///
///     地<0776>是<01961>空虚<08414>混沌<0922>，渊<08415>面<06440>黑暗<02822>；
///
/// That needs an EDITION, because the numbers are attached to a
/// particular rendering: `assets/tagged/<version>/<book>.json` holds one
/// run of that edition's own printed text per original word. So the
/// sheet grows a picker, and this file is the part of the picker worth
/// testing — which rows it may show, and which row it opens on.
///
/// He had already asked once, on 2026-09-07, for both apps. It was built
/// in SeekSparks and never here, and the Exegesis sheet in THIS app was
/// worse off than that history suggests: `originals_sheet.dart` has
/// rendered a numbered running line since it was ported, but only for
/// the version the reader was on, and `assets/tagged/` held exactly one
/// directory. A reader on 和合本雅偉版 **繁體** — which is the version in
/// the screenshot he sent — got word cards and nothing else. Two of the
/// three pieces of work behind this file were therefore data, not UI.
///
/// ## Which editions may be offered
///
/// [interlinearEditions] is an INTERSECTION, and both halves are load
/// bearing:
///
///   * `TaggedTextService.taggedVersions` — the editions that have the
///     alignment at all. Four.
///   * `availableVersions` — the editions the app is willing to show a
///     reader anywhere. That is where `disabledVersions` and
///     `kWebRestrictedVersions` are applied.
///
/// A hand-written list here would be the way a withdrawn edition
/// silently comes back. `nasb` is the live example: it is in
/// `disabledVersions` at the owner's instruction pending the publisher's
/// answer, its asset still ships inside the native binary, and the only
/// reason nothing links to it is that every list of editions in this app
/// is computed from `availableVersions`. If the NASB were ever tagged,
/// this file would have to keep on not offering it without being edited,
/// and the intersection is how that happens.
///
/// `wh` (Westcott-Hort) is not offered, and that is the tagged set's
/// doing rather than this file's: an interlinear of the Greek original
/// against itself is a different feature, and its module's morphology
/// tags want a `g` field the importer does not build for it. See
/// `TaggedTextService.taggedVersions`.
///
/// ## Rejected: a hand-ordered "best first" list
///
/// The order is `availableVersions`' own catalogue order. A ranking —
/// BSB first because it is the most completely aligned, say — would be
/// this file having an opinion about which translation is better, which
/// is not its business and not one the catalogue anywhere else
/// expresses.
///
/// Flutter-free apart from what it imports; nothing here touches an
/// asset, so every rule below is a pure function a test can call.
library;

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// The edition codes the interlinear picker may list, in catalogue order.
///
/// Computed rather than const because `availableVersions` is: it narrows
/// on `_kIsWeb`, and `disabledVersions` is read there rather than copied
/// here.
List<String> get interlinearEditions => [
      for (final v in availableVersions)
        if (TaggedTextService.supports(v.value)) v.value,
    ];

/// Why the sheet is showing the edition it is showing.
///
/// The sheet prints a sentence for [substituted] and stays quiet for the
/// other two, which is the whole reason this is an enum and not a bool.
/// A reader whose Bible has no tagging is not shown an empty box and is
/// not shown someone else's translation unannounced; they are told which
/// edition they are looking at and why it is not theirs.
enum InterlinearSource {
  /// The reader picked this edition themselves.
  chosen,

  /// It is the edition they are reading, which happens to be tagged.
  current,

  /// Their edition has no tagging, so this is the nearest one that has.
  /// The only value the sheet says anything about.
  substituted,

  /// Nothing is offerable at all. Unreachable while any tagged edition
  /// ships; represented because "the list is empty" and "the list has a
  /// first element" must not be the same code path.
  none,
}

/// The edition to draw, and how it was arrived at.
typedef InterlinearChoice = ({String? version, InterlinearSource source});

/// Pick the edition for a sheet opened on [currentVersion].
///
/// [chosen] is the reader's own standing pick (`''` when they have never
/// touched the picker). It wins whenever it is still offerable, and is
/// ignored rather than honoured when it is not — an edition can leave
/// `availableVersions` between one launch and the next, and a stored
/// code is not a promise that it still exists.
///
/// After that: the edition being read, then the nearest one in the same
/// LANGUAGE, then the catalogue's own cross-language neighbour for that
/// edition, then the first offered.
///
/// **`zh-Hans` and `zh-Hant` are NOT folded together here, and that is
/// the difference from SeekSparks' copy of this rule.** That app folds
/// them because it has no Traditional tagged set and simplified Chinese
/// is a better answer for a 繁體 reader than English is. This app has
/// one as of today — deriving it is what the owner's screenshot was
/// about — so a 梁家鏗譯本(繁體) reader gets 和合本雅偉版(繁體), in their
/// own script, and folding the two families would hand them the
/// Simplified edition for no reason.
InterlinearChoice resolveInterlinearEdition({
  String chosen = '',
  String? currentVersion,
}) {
  final offered = interlinearEditions;
  if (offered.isEmpty) return (version: null, source: InterlinearSource.none);

  if (offered.contains(chosen)) {
    return (version: chosen, source: InterlinearSource.chosen);
  }

  final current = currentVersion?.toLowerCase();
  if (current != null && offered.contains(current)) {
    return (version: current, source: InterlinearSource.current);
  }

  if (current != null) {
    final wanted = _languageOf(current);
    if (wanted != null) {
      for (final code in offered) {
        if (_languageOf(code) == wanted) {
          return (version: code, source: InterlinearSource.substituted);
        }
      }
    }
    // No tagged edition in this reader's own language. The catalogue
    // has already answered this question once, for the one edition it
    // can arise for: `bibleVersionFullCanonFallback('wh')` is
    // `bsb-yhwh`, chosen there as "which English to show beside a Greek
    // text" — a modern translation of the same critical text the WH
    // represents. Asking it again here rather than inventing a second
    // answer means the Greek reader sees the same neighbour in the
    // Exegesis sheet that they already see on the daily-verse card.
    final neighbour = bibleVersionFullCanonFallback(current);
    if (neighbour != null && offered.contains(neighbour)) {
      return (version: neighbour, source: InterlinearSource.substituted);
    }
  }
  return (version: offered.first, source: InterlinearSource.substituted);
}

/// The catalogue's language for a code, or null for one it does not
/// know.
///
/// Null rather than [bibleVersionLanguage]'s `zh-Hans` guess: an
/// imported edition has no language, and a code with no language cannot
/// steer a fallback. It falls through to the neighbour rule and then to
/// "the first offered" instead of being guessed at as Chinese.
String? _languageOf(String code) {
  for (final v in availableVersions) {
    if (v.value == code) return v.language;
  }
  return null;
}
