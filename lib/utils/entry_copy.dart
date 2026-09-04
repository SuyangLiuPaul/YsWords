/// Clipboard shapes for "one content entry" — a timeline event, an
/// evidence item, a video, a sermon, a song row.
///
/// Built when copy went from a handful of bespoke call sites to
/// something wanted on most content pages (2026-09-05). One formatter
/// rather than one per page, because the alternative is five pages that
/// each decided separately whether the reference list gets a comma or a
/// semicolon, and a user pasting from two of them notices.
///
/// The rules are deliberately dull, which is the point of a clipboard
/// format: every part is optional, blank parts vanish rather than
/// leaving empty lines, and nothing is ever invented to fill a gap.
library;

/// One entry as plain lines: heading, body, refs, url — in that order,
/// each on its own line, blanks omitted.
///
/// [refs] are joined with `'; '` on a single line. They are short by
/// nature (`Genesis 12:1`), a list of them reads as one thought, and
/// giving each its own line makes a three-reference event look longer
/// than its description.
///
/// Returns `''` when everything is empty — the caller should not offer
/// a copy button in that state, and an empty string is a quieter
/// failure than a clipboard full of newlines.
String formatEntryForCopy({
  String? heading,
  String? body,
  Iterable<String> refs = const <String>[],
  String? url,
}) {
  final lines = <String>[];
  void add(String? s) {
    final t = s?.trim() ?? '';
    if (t.isNotEmpty) lines.add(t);
  }

  add(heading);
  add(body);
  final cleanRefs = refs.map((r) => r.trim()).where((r) => r.isNotEmpty);
  if (cleanRefs.isNotEmpty) lines.add(cleanRefs.join('; '));
  add(url);
  return lines.join('\n');
}

/// Several entries, separated by a blank line.
///
/// A blank line and not a rule of dashes: the result is pasted into
/// notes and messages far more often than into anything that renders
/// markdown, and a separator that survives as literal `---` in a chat
/// message is worse than plain spacing.
///
/// Entries that format to nothing are dropped, so a list with two
/// usable rows out of five copies as two rows rather than as two rows
/// and three blank gaps.
String formatEntriesForCopy(Iterable<String> entries) =>
    entries.map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n\n');
