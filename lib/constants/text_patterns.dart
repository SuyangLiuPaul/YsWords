/// Shared regex patterns and text utilities for verse annotation handling.
///
/// Used across loading_page, home_page, search_page, verse_widget, and
/// fetch_verses to ensure consistent text processing.

/// Matches `<note:...>` tags embedded in verse text.
final notePattern = RegExp(r'<note:([^>]+)>');

/// Matches `{...}` curly-brace annotations (cross-references, commentary).
final bracePattern = RegExp(r'\{([^}]+)\}');

/// Matches `[...]` square-bracket annotations (emphasis, alternative readings).
final squarePattern = RegExp(r'\[([^\]]+)\]');

/// Matches any annotation token: braces, brackets, or note tags.
final combinedPattern = RegExp(r'(\{[^}]+\}|\[[^\]]+\]|<note:[^>]+>)');

/// Strips all annotation markup from verse text, returning clean readable text.
String sanitizeVerseText(String text) {
  return text
      .replaceAll('\n', '')
      .replaceAll(notePattern, '')
      .replaceAll(bracePattern, '')
      .trim();
}

/// Strips annotations but preserves square-bracket content (used for display).
String sanitizeForSearch(String text) {
  return text
      .replaceAll(notePattern, '')
      .replaceAll(bracePattern, '')
      .trim();
}
