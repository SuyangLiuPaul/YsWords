/// 2026-06-11 audit: extracted from `_AiExplainSheet._cleanExplanation`
/// (bible_reading_pane.dart) so the defensive cleanup of Gemini verse
/// explanations is a pure, unit-tested function instead of private
/// widget logic. History: v1.3.57 rewrote the server prompt to force
/// flowing prose after the model leaked a "快速思考：" preamble and
/// markdown outlines into the sheet — this client-side strip is the
/// second line of defence when the model ignores the prompt.
library;

/// Removes model-formatting artifacts from an AI verse explanation:
///
///  1. A leading thinking preamble ("快速思考：…", "Thinking: …") up to
///     the first blank line (or first newline when there is no blank
///     line).
///  2. A markdown heading marker on what is then the first line
///     (`### 约翰福音 3:16` → `约翰福音 3:16`).
///  3. Stray bold/italic pair markers (`**` / `__`) anywhere — the
///     prompt bans markdown, so when the model slips these render as
///     literal asterisks in the sheet.
///
/// Clean prose passes through unchanged, and the function is
/// idempotent.
String cleanAiExplanation(String raw) {
  var t = raw.trim();

  final lead = RegExp(
      r'^\s*(快速思考|思考过程|思考|Quick thinking|Thinking)\s*[:：]',
      caseSensitive: false);
  if (lead.hasMatch(t)) {
    final para = t.indexOf('\n\n');
    if (para > 0) {
      t = t.substring(para).trim();
    } else {
      final nl = t.indexOf('\n');
      if (nl > 0) t = t.substring(nl).trim();
    }
  }

  t = t.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
  t = t.replaceAll('**', '').replaceAll('__', '');

  return t.trim();
}
