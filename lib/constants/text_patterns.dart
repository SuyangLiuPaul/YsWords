// Shared regex patterns and text utilities for verse annotation handling.
// Used across loading_page, home_page, search_page, verse_widget, and
// fetch_verses to ensure consistent text processing.

/// Matches `<note:...>` tags embedded in verse text.
final notePattern = RegExp(r'<note:([^>]+)>');

/// Matches `{...}` curly-brace annotations (cross-references, commentary).
final bracePattern = RegExp(r'\{([^}]+)\}');

/// Matches `[...]` square-bracket annotations (emphasis, alternative readings).
final squarePattern = RegExp(r'\[([^\]]+)\]');

/// Matches any annotation token: braces, brackets, or note tags.
final combinedPattern = RegExp(r'(\{[^}]+\}|\[[^\]]+\]|<note:[^>]+>)');

/// Round 56: pilcrow (¶) and the very-similar paragraph mark unicode
/// characters appear in some Bible versions (KJV-style asset files
/// keep them as paragraph markers). User feedback "有的 bible
/// version 里面有 ¶ 看起来很不舒服" — strip them everywhere we
/// render verse text. Trailing whitespace they leave behind is
/// collapsed too.
final _pilcrowPattern = RegExp(r'[¶§]\s*');

/// Round 56: divine-name normalization. The asset files for the
/// non-YHWH versions render the Tetragrammaton as `耶和华` /
/// `耶和華` / `the LORD` / `LORD`. The user wants `雅伟` (S),
/// `雅偉` (T), and `Yahweh` everywhere in the app, regardless of
/// which version asset file the text came from. We do this at the
/// render-side sanitizer rather than rewriting the asset JSONs so
/// the original files stay verifiable against upstream Bible data.
///
/// 2026-05-10 (v1.2.33): traditional output corrected from `雅威`
/// (might/awe) → `雅偉` (great) — the project's canonical
/// simp→trad pairing is 雅伟 → 雅偉, but this normalisation path
/// (and several other surfaces) historically used `雅威`. The user
/// reported "很多地方寫雅威但是需要雅偉". Every traditional CUV
/// reader sees this output, so it's the highest-impact site.
///
/// Matters of detail:
///   • English: only ALL-CAPS `LORD` / `the LORD` is replaced.
///     Mixed-case "Lord" refers to Adonai / kyrios (Jesus) and
///     stays as-is.
///   • Chinese: both Simplified and Traditional source text might
///     leak through depending on which CUVS variant the user opens.
///     We map both shapes to the corresponding Yahweh form for the
///     user's screen.
String _normalizeDivineNames(String text) {
  var out = text;
  // Chinese — must come before any English work, but order between
  // Hans/Hant doesn't matter (different glyphs).
  out = out.replaceAll('耶和华', '雅伟');
  out = out.replaceAll('耶和華', '雅偉');
  // English — whole-word, case-sensitive on the all-caps form so we
  // don't disturb "Lord" (Adonai/kyrios) or proper nouns.
  out = out.replaceAllMapped(
    RegExp(r'\bthe LORD\b'),
    (_) => 'Yahweh',
  );
  out = out.replaceAllMapped(
    RegExp(r'\bThe LORD\b'),
    (_) => 'Yahweh',
  );
  out = out.replaceAllMapped(
    RegExp(r'\bLORD\b'),
    (_) => 'Yahweh',
  );
  return out;
}

/// Strips popup-only annotation markup from verse text, returning
/// clean readable text suitable for clipboard copy. Preserves the
/// inner content of `{clarification}` and `[supplied]` brackets
/// because that content IS part of the verse text — it's just
/// editorial markup for which words were supplied vs. translated
/// vs. clarified. Only `<note: …>` (which renders as a popup, not
/// inline text) is fully stripped.
///
/// 2026-05-19 (v1.2.56): user reported copy-paste of LEB Matt 2:18
/// produced "...because ." — the `{they exist no longer}` content
/// was being discarded along with the braces. Was a bug: braces are
/// MARKUP, the phrase inside is content. Both `sanitizeVerseText`
/// (copy path) and `sanitizeForSearch` (search-index + previews +
/// most copy paths) now keep the inner phrase. `<note: …>` continues
/// to be fully stripped because it's a separate popup, not inline
/// verse text.
String sanitizeVerseText(String text) {
  return _collapsePostStripDuplicates(_normalizeDivineNames(text
          .replaceAll('\n', '')
          .replaceAll(notePattern, '')
          .replaceAllMapped(bracePattern, (m) => m.group(1) ?? '')
          .replaceAll(_pilcrowPattern, ''))
      .trim());
}

/// Strips annotations but preserves square-bracket content + the
/// inner content of `{clarification}` braces. See `sanitizeVerseText`
/// for the v1.2.56 rationale on brace preservation.
String sanitizeForSearch(String text) {
  return _collapsePostStripDuplicates(_normalizeDivineNames(text
          .replaceAll(notePattern, '')
          .replaceAllMapped(bracePattern, (m) => m.group(1) ?? '')
          .replaceAll(_pilcrowPattern, ''))
      .trim());
}

/// 2026-05-19 (v1.2.58): clipboard / preview formatter.
///
/// Builds on `sanitizeForSearch` (keeps `[supplied]` + `{clarification}`
/// content, strips `<note:>` popups) and additionally REPLACES INTERNAL
/// `\n` line breaks WITH SPACE — so:
///   • multi-verse copy in any of the 3 formats produces clean inline
///     paragraphs (rather than e.g. one verse spanning 5 lines because
///     it's an OT-poetry quote with embedded line breaks)
///   • the settings-page preview UI matches the real copy output
///     byte-for-byte (the v1.2.56 brace fix landed in `sanitizeForSearch`
///     but the three preview regexes still stripped braces, drifting
///     out of sync)
///
/// `sanitizeVerseText` keeps stripping `\n` outright (single-verse
/// number-tap copy is even more strictly "one line"). `sanitizeForSearch`
/// keeps `\n` (search indexes / library previews where line breaks
/// are inert).
String sanitizeForCopy(String text) {
  return _collapsePostStripDuplicates(_normalizeDivineNames(text
          .replaceAll(notePattern, '')
          .replaceAllMapped(bracePattern, (m) => m.group(1) ?? '')
          .replaceAll(_pilcrowPattern, '')
          .replaceAll('\n', ' '))
      .trim());
}

/// 2026-05-18 (v1.2.52): defensive post-strip cleanup. When an
/// annotation in the source data was bracketed by the SAME
/// punctuation on both sides (e.g. `俄梅戛，<note: …>，是昔在`),
/// stripping the annotation left the punctuation duplicated
/// (`俄梅戛，，是昔在`). User report on Rev 1:8 — "复制经文那里
/// 有两个逗号". 2026-05-18 sweep cleaned the 20 known cases in
/// `cuvs-yhwh.json` + `cuvs-yhwh-tr.json` at the data layer, but
/// this collapse runs at the render layer too as defense-in-
/// depth: any future regression (or edge case we missed) gets
/// silently corrected before the text reaches the user.
///
/// Scope: collapse runs of the same CJK punct (`，。；：？！、`) to
/// one. Also collapses runs of ASCII spaces to one. Doesn't
/// touch repeated alphanumerics or anything else — the only way
/// to legitimately repeat these punct chars is a stripped
/// annotation, and even then the second one is always a typo
/// (no canonical translation puts `，，` adjacent in 1:1 text).
String _collapsePostStripDuplicates(String text) {
  // Repeated CJK / full-width punctuation → one.
  text = text.replaceAllMapped(
    RegExp(r'([，。；：？！、])\1+'),
    (m) => m.group(1)!,
  );
  // Multiple spaces (from English/space-flanked annotations) → one.
  text = text.replaceAll(RegExp(r'  +'), ' ');
  return text;
}

/// Render-time cleanup for a single chunk of verse text inside a
/// pre-split InlineSpan list — strips pilcrows, normalizes divine
/// names, but preserves leading/trailing whitespace so adjacent
/// chunks don't collide. Used by `buildVerseContentSpans`.
String displayCleanup(String chunk) {
  return _normalizeDivineNames(
      chunk.replaceAll(_pilcrowPattern, ''));
}

/// 2026-05-07: collapse stray ASCII spaces that sit between an
/// annotation marker (`[…]`, `{…}`, `<note:…>`) and adjacent CJK
/// text. The CUVS-Yahweh asset (and a few others) ship verses like
/// `主[雅伟] 的道` where the original translation had English-style
/// spacing around the bracketed alternative reading; in Chinese
/// rendering that produces an unmistakable visual gap between
/// `雅伟` and the next character. We collapse the space whenever
/// either side of the gap is a CJK ideograph or full-width
/// punctuation. English contexts (`the [LORD] God`) keep their
/// spaces because the regex matches CJK ranges only.
///
/// Done as a single pre-process pass on the full verse string before
/// it is split by `combinedPattern` — saves duplicating the rule on
/// every chunk and keeps the rendering loop simple. Search
/// (`sanitizeForSearch`) ignores spaces anyway (the search code
/// strips all spaces before matching), so calling this is purely a
/// rendering cleanup.
String collapseAnnotationSpacing(String text) {
  // CJK ideographs: U+4E00–U+9FFF (CJK Unified) plus U+3000–U+303F
  // (CJK punctuation: 　 、。「」 etc.) plus the full-width punctuation
  // block U+FF00–U+FFEF where the half-width ASCII forms typically
  // get mapped.
  const cjkClass = r'[　-〿一-鿿＀-￯]';
  // Drop space between annotation-close (}, ], note > ) and CJK.
  text = text.replaceAllMapped(
    RegExp('([}\\]>])[ \\t]+($cjkClass)'),
    (m) => '${m.group(1)}${m.group(2)}',
  );
  // Drop space between CJK and annotation-open ({, [, <).
  text = text.replaceAllMapped(
    RegExp('($cjkClass)[ \\t]+([{\\[<])'),
    (m) => '${m.group(1)}${m.group(2)}',
  );
  return text;
}
