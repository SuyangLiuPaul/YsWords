// 2026-06-18 (v1.3.91): boolean Strong's-number search.
//
// Lets the user combine original-language word searches with set operators:
//
//   G25 AND G26     → verses that contain BOTH Strong's numbers
//   G25 OR G26      → verses that contain EITHER
//   G25 G26         → implicit AND (adjacent terms)
//   G25* AND H7225  → "G25*" is a PREFIX wildcard: any Greek number whose
//                     digits start with "25" (G25, G250, G251, … G2599)
//
// This file is the PURE logic — a tokeniser/parser plus a set-operation
// evaluator that is given a `refsFor(term)` callback. The concordance data
// and UI live elsewhere (search_page.dart), so this stays unit-testable with
// no asset or Flutter dependency.

/// One term in a boolean query, e.g. `G25` or `H7225*`.
class StrongsTerm {
  /// 'G' (Greek) or 'H' (Hebrew).
  final String prefix;

  /// The digit string exactly as typed, leading zeros stripped ("25").
  final String digits;

  /// True when the term ended with `*` (prefix wildcard).
  final bool wildcard;

  const StrongsTerm({
    required this.prefix,
    required this.digits,
    required this.wildcard,
  });

  /// The canonical Strong's number for a NON-wildcard term (e.g. "G25").
  String get number => '$prefix$digits';

  @override
  String toString() => '$prefix$digits${wildcard ? '*' : ''}';

  @override
  bool operator ==(Object other) =>
      other is StrongsTerm &&
      other.prefix == prefix &&
      other.digits == digits &&
      other.wildcard == wildcard;

  @override
  int get hashCode => Object.hash(prefix, digits, wildcard);
}

/// A parsed boolean query: N terms joined by N-1 operators
/// (`ops[i]` joins `terms[i]` and `terms[i+1]`). Evaluated left to right.
class StrongsBooleanQuery {
  final List<StrongsTerm> terms;
  final List<StrongsOp> ops;
  const StrongsBooleanQuery(this.terms, this.ops);
}

enum StrongsOp { and, or }

final RegExp _termRe = RegExp(r'^([gGhH])0*(\d+)(\*?)$');

/// Parse [input] into a boolean Strong's query, or return null when the
/// input is NOT a boolean Strong's expression (the caller then falls back to
/// single-Strong's / text / AI search). Returns non-null only when the query
/// is genuinely "combined": either 2+ Strong's terms, or a single wildcard
/// term (a single plain number like "G2664" stays null so the existing
/// single-entry lexicon path handles it).
StrongsBooleanQuery? parseStrongsBoolean(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  final tokens = raw.split(RegExp(r'\s+'));
  final terms = <StrongsTerm>[];
  final ops = <StrongsOp>[];
  // Expect: term (op term)* — operators are optional between two terms
  // (adjacent terms imply AND). Anything that isn't a term or a known
  // operator aborts the whole parse (→ null → fall back to text search).
  var expectingTerm = true;
  for (final tok in tokens) {
    final upper = tok.toUpperCase();
    if (!expectingTerm && (upper == 'AND' || upper == '&' || upper == '+')) {
      ops.add(StrongsOp.and);
      expectingTerm = true;
      continue;
    }
    if (!expectingTerm && (upper == 'OR' || upper == '|' || upper == '/')) {
      ops.add(StrongsOp.or);
      expectingTerm = true;
      continue;
    }
    final m = _termRe.firstMatch(tok);
    if (m == null) return null; // not a Strong's term where one was needed
    final digits = m.group(2)!;
    // Reject absurd numbers so plain text like "H1 will" can't masquerade.
    final n = int.tryParse(digits) ?? 0;
    final prefix = m.group(1)!.toUpperCase();
    if (prefix == 'G' && (n < 1 || n > 5700)) return null;
    if (prefix == 'H' && (n < 1 || n > 8700)) return null;
    if (!expectingTerm) {
      // Two terms with no operator between them → implicit AND.
      ops.add(StrongsOp.and);
    }
    terms.add(StrongsTerm(
      prefix: prefix,
      digits: digits,
      wildcard: m.group(3) == '*',
    ));
    expectingTerm = false;
  }
  if (expectingTerm) return null; // trailing operator, e.g. "G25 AND"
  // Only treat as boolean when it's actually combined.
  final isCombined = terms.length >= 2 || (terms.length == 1 && terms[0].wildcard);
  if (!isCombined) return null;
  return StrongsBooleanQuery(terms, ops);
}

/// Evaluate [query] to the set of verse-reference labels (e.g. "John 3:16")
/// that satisfy it. [refsFor] resolves a single term to its occurrence set
/// (handling wildcard expansion + concordance lookup); this function only
/// applies the AND/OR set algebra, left to right.
Set<String> evaluateStrongsBoolean(
  StrongsBooleanQuery query,
  Set<String> Function(StrongsTerm term) refsFor,
) {
  if (query.terms.isEmpty) return <String>{};
  var acc = <String>{...refsFor(query.terms.first)};
  for (var i = 0; i < query.ops.length; i++) {
    final next = refsFor(query.terms[i + 1]);
    if (query.ops[i] == StrongsOp.and) {
      acc = acc.intersection(next);
    } else {
      acc = acc.union(next);
    }
  }
  return acc;
}
