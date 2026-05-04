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
/// `雅威` (T), and `Yahweh` everywhere in the app, regardless of
/// which version asset file the text came from. We do this at the
/// render-side sanitizer rather than rewriting the asset JSONs so
/// the original files stay verifiable against upstream Bible data.
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
  out = out.replaceAll('耶和華', '雅威');
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

/// Strips all annotation markup from verse text, returning clean readable text.
String sanitizeVerseText(String text) {
  return _normalizeDivineNames(text
          .replaceAll('\n', '')
          .replaceAll(notePattern, '')
          .replaceAll(bracePattern, '')
          .replaceAll(_pilcrowPattern, ''))
      .trim();
}

/// Strips annotations but preserves square-bracket content (used for display).
String sanitizeForSearch(String text) {
  return _normalizeDivineNames(text
          .replaceAll(notePattern, '')
          .replaceAll(bracePattern, '')
          .replaceAll(_pilcrowPattern, ''))
      .trim();
}

/// Render-time cleanup for a single chunk of verse text inside a
/// pre-split InlineSpan list — strips pilcrows, normalizes divine
/// names, but preserves leading/trailing whitespace so adjacent
/// chunks don't collide. Used by `buildVerseContentSpans`.
String displayCleanup(String chunk) {
  return _normalizeDivineNames(
      chunk.replaceAll(_pilcrowPattern, ''));
}
