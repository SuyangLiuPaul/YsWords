// Lightweight markdown → TextSpan parser for AI responses.
//
// Why this exists: Gemini ignores explicit "no markdown" prompts and
// ships emphasis markers anyway — `**bold**`, `***bold-italic***`,
// occasional `# heading` lines, `- bullet` lists. Rendering them as
// plain `Text(...)` surfaces literal asterisks in the UI ("why it is
// like ** which means it is not formatted well"). This util converts
// the markdown to a list of `TextSpan`s suitable for `RichText` /
// `SelectableText.rich` so the user sees actual bold / italic / bullets.
//
// Originated as a private helper inside `lib/widgets/originals_sheet.dart`
// (v1.2.31). Extracted into this util in v1.2.38 so the same parser
// is shared by every AI surface (search_page AI ref reasons,
// evidence_page Q&A answer body, settings_page tier detail panel,
// originals_sheet word-study explanation chunks + fellBackToFlash
// notice).
//
// Handles in order of fragility:
//   • leading `# `, `## `, `### ` heading markers — stripped; line
//     rendered bold instead.
//   • horizontal rules (`---` / `___` / `***` on their own line) —
//     dropped.
//   • leading `- ` / `* ` / `+ ` bullet markers — replaced with `• `.
//   • inline `***x***` → bold + italic.
//   • inline `**x**`   → bold.
//   • inline `*x*` / `_x_` → italic (single-char delim, narrow pattern
//     so we don't false-match on `[Genesis 1:1]` style annotations).
//
// Anything not matching falls through verbatim.

import 'package:flutter/widgets.dart';

// Hoisted regex instances. `_parseAiMarkdown` previously constructed
// 3 fresh RegExps per line plus 1 inline pattern per call (3N + 1
// `RegExp.compile` invocations per N-line AI render). One cached
// instance per pattern is reused across calls.
final RegExp _kAiMdHorizontalRule = RegExp(r'^\s*([-_*])\1{2,}\s*$');
final RegExp _kAiMdHeading = RegExp(r'^\s*#{1,6}\s+(.+?)\s*#*\s*$');
final RegExp _kAiMdBullet = RegExp(r'^(\s*)[-*+]\s+(.+)$');
final RegExp _kAiMdInlinePattern = RegExp(
  // 1: ***bold-italic*** | 2: **bold** | 3: *italic* | 4: _italic_
  r'\*\*\*([^*\n]+?)\*\*\*'
  r'|\*\*([^*\n]+?)\*\*'
  r'|(?<!\w)\*([^*\n]+?)\*(?!\w)'
  r'|(?<!\w)_([^_\n]+?)_(?!\w)',
);

/// Parse [input] markdown into a list of [TextSpan]s with [base]
/// as the default style. Returned spans plug straight into
/// `RichText(text: TextSpan(children: spans))` or
/// `SelectableText.rich(TextSpan(children: spans))`.
List<TextSpan> parseAiMarkdown(
  String input, {
  required TextStyle base,
}) {
  final boldItalic =
      base.copyWith(fontWeight: FontWeight.w800, fontStyle: FontStyle.italic);
  final bold = base.copyWith(fontWeight: FontWeight.w800);
  final italic = base.copyWith(fontStyle: FontStyle.italic);

  // Pre-process line-level markdown: headings + rules + bullets.
  final lines = input.split('\n');
  final cleaned = <String>[];
  for (final ln in lines) {
    final stripped = ln.trimRight();
    // Horizontal rule.
    if (_kAiMdHorizontalRule.hasMatch(stripped)) continue;
    // Heading — replace with `**heading**\n` so the inline pass
    // turns it into a bold line.
    final headingMatch = _kAiMdHeading.firstMatch(stripped);
    if (headingMatch != null) {
      cleaned.add('**${headingMatch.group(1)!}**');
      continue;
    }
    // Bullet — turn into a • line so the inline pass keeps it
    // visually distinct without leaving a stray asterisk.
    final bulletMatch = _kAiMdBullet.firstMatch(stripped);
    if (bulletMatch != null) {
      cleaned.add('${bulletMatch.group(1)}• ${bulletMatch.group(2)}');
      continue;
    }
    cleaned.add(stripped);
  }
  final body = cleaned.join('\n');

  // Inline pass: walk left-to-right, emitting bold-italic / bold /
  // italic / plain spans as we hit each delimiter. Greedy on the
  // `***` pattern first so we don't mis-tokenise it as `**` + `*`.
  final spans = <TextSpan>[];
  int idx = 0;
  for (final m in _kAiMdInlinePattern.allMatches(body)) {
    if (m.start > idx) {
      spans.add(TextSpan(text: body.substring(idx, m.start), style: base));
    }
    final bi = m.group(1);
    final b = m.group(2);
    final i1 = m.group(3);
    final i2 = m.group(4);
    if (bi != null) {
      spans.add(TextSpan(text: bi, style: boldItalic));
    } else if (b != null) {
      spans.add(TextSpan(text: b, style: bold));
    } else if (i1 != null) {
      spans.add(TextSpan(text: i1, style: italic));
    } else if (i2 != null) {
      spans.add(TextSpan(text: i2, style: italic));
    }
    idx = m.end;
  }
  if (idx < body.length) {
    spans.add(TextSpan(text: body.substring(idx), style: base));
  }
  return spans;
}
