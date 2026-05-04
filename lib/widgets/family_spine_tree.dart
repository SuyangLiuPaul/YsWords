import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/biblical_person.dart';
import 'package:yswords/services/family_tree_service.dart';

/// Top-down "spine tree" view of the Bible family tree.
///
/// **Pattern**: a real tree starting from the dataset's canonical
/// root (Adam), but with **only the spine to the current focus
/// expanded**. Every off-spine branch collapses to a single header
/// row with a `+` chevron so the user can crack it open manually
/// when they want to.
///
/// Why this layout (round 58, replacing the round-57 horizontal
/// descendant chart):
///   - The user explicitly asked: "from root down, … other branch
///     should be closed but the main branch from root should be
///     there for tracking back". This widget is that: the spine
///     stays open as a permanent trail; siblings stay shut.
///   - Adam → Jesus is 70 generations deep; a fully-expanded tree
///     sprawls. The spine pattern keeps the visual depth bounded
///     to (spine length + N children of focus + 1 row per sibling).
///   - Search composes naturally: when a query matches a node,
///     we auto-expand the ancestor path so it's visible without
///     hunting.
///
/// **Visual**:
///
/// ```
///   Adam · AM 0–930 (930y)                       ✦ on spine
///   ├─ Cain                                       (collapsed)
///   ├─ Abel                                       (collapsed)
///   └─ Seth · AM 130–1042 (912y)                 ✦
///      └─ Enosh · AM 235–1140 (905y)             ✦
///         └─ Kenan · AM 325–1235 (910y)          ✦
///            …
/// ```
class FamilySpineTree extends StatefulWidget {
  /// Dataset root (typically Adam in the MVP corpus).
  final BiblicalPerson root;

  /// Current focus — the spine extends from [root] down to here. UI
  /// signals this row visually with a primary-color highlight.
  final BiblicalPerson focus;

  /// User locale.
  final String locale;

  /// Optional search query — when non-empty, matching nodes get
  /// highlighted and their ancestor paths auto-expand so each match
  /// is immediately visible.
  final String query;

  /// Tap a node body → opens the detail sheet on the host page.
  final void Function(BiblicalPerson) onPersonTap;

  /// Long-press / double-tap a node → makes them the new focus.
  /// Host updates the spine and rebuilds.
  final void Function(BiblicalPerson) onRefocus;

  const FamilySpineTree({
    super.key,
    required this.root,
    required this.focus,
    required this.locale,
    required this.onPersonTap,
    required this.onRefocus,
    this.query = '',
  });

  @override
  State<FamilySpineTree> createState() => _FamilySpineTreeState();
}

class _FamilySpineTreeState extends State<FamilySpineTree> {
  /// Person ids the user has manually expanded *in addition to* the
  /// computed spine. Survives focus changes so the user doesn't lose
  /// their context when they reframe.
  final Set<String> _userExpanded = {};

  /// Cached spine — list of person ids on the path root → focus.
  /// Recomputed on focus changes via [didUpdateWidget].
  Set<String> _spine = const {};

  @override
  void initState() {
    super.initState();
    _spine = _computeSpine();
  }

  @override
  void didUpdateWidget(FamilySpineTree old) {
    super.didUpdateWidget(old);
    if (old.focus.id != widget.focus.id || old.root.id != widget.root.id) {
      _spine = _computeSpine();
    }
  }

  /// Walk down from root following childIds toward focus. We use a
  /// BFS so the first found path wins (deterministic). Returns the
  /// set of person ids on the spine including both endpoints.
  Set<String> _computeSpine() {
    final svc = FamilyTreeService.instance;
    final start = widget.root.id;
    final goal = widget.focus.id;
    if (start == goal) return {start};
    final cameFrom = <String, String>{};
    final queue = <String>[start];
    final seen = <String>{start};
    String? hit;
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (cur == goal) {
        hit = cur;
        break;
      }
      final p = svc.byId(cur);
      if (p == null) continue;
      for (final c in p.childIds) {
        if (seen.contains(c)) continue;
        seen.add(c);
        cameFrom[c] = cur;
        queue.add(c);
      }
    }
    if (hit == null) return {start};
    final out = <String>{goal};
    var cur = goal;
    while (cameFrom.containsKey(cur)) {
      cur = cameFrom[cur]!;
      out.add(cur);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = widget.query.trim().toLowerCase();
    // When searching, every matching node's ancestor chain gets
    // pre-expanded so the match is visible without manual expansion.
    final searchExpansion = query.isEmpty
        ? const <String>{}
        : _ancestorsOfMatches(query);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: _NodeView(
        person: widget.root,
        depth: 0,
        spine: _spine,
        userExpanded: _userExpanded,
        searchExpansion: searchExpansion,
        focusId: widget.focus.id,
        locale: widget.locale,
        scheme: scheme,
        query: query,
        onPersonTap: widget.onPersonTap,
        onRefocus: widget.onRefocus,
        onToggleExpand: (id) => setState(() {
          if (_userExpanded.contains(id)) {
            _userExpanded.remove(id);
          } else {
            _userExpanded.add(id);
          }
        }),
      ),
    );
  }

  /// Find all person ids whose name/summary matches [query] and
  /// return the union of every ancestor path so the matches
  /// auto-show. Doesn't include the matches themselves — those
  /// render under the parent that's auto-expanded.
  Set<String> _ancestorsOfMatches(String query) {
    final svc = FamilyTreeService.instance;
    final out = <String>{};
    // Map each id to its parent (via fatherId). Walk all known
    // people, BFS from root if desired, but since the dataset is
    // small (~70 people) we can just iterate everyone.
    void addAncestors(String id) {
      var cur = id;
      while (true) {
        final p = svc.byId(cur);
        if (p == null) break;
        if (p.fatherId == null) break;
        out.add(p.fatherId!);
        cur = p.fatherId!;
      }
    }
    final all = svc.allOrEmpty();
    for (final p in all) {
      final hay = [
        p.name,
        p.nameZhHans ?? '',
        p.nameZhHant ?? '',
        p.id,
        p.summary,
        p.summaryZhHans ?? '',
        p.summaryZhHant ?? '',
      ].join(' ').toLowerCase();
      if (hay.contains(query)) {
        addAncestors(p.id);
      }
    }
    return out;
  }
}

/// Recursive node row + indented children. Stateless because all
/// expansion state lives in the parent [_FamilySpineTreeState].
class _NodeView extends StatelessWidget {
  final BiblicalPerson person;
  final int depth;
  final Set<String> spine;
  final Set<String> userExpanded;
  final Set<String> searchExpansion;
  final String focusId;
  final String locale;
  final ColorScheme scheme;
  final String query;
  final void Function(BiblicalPerson) onPersonTap;
  final void Function(BiblicalPerson) onRefocus;
  final void Function(String id) onToggleExpand;

  const _NodeView({
    required this.person,
    required this.depth,
    required this.spine,
    required this.userExpanded,
    required this.searchExpansion,
    required this.focusId,
    required this.locale,
    required this.scheme,
    required this.query,
    required this.onPersonTap,
    required this.onRefocus,
    required this.onToggleExpand,
  });

  bool get _onSpine => spine.contains(person.id);
  bool get _isFocus => person.id == focusId;
  bool get _matchesQuery {
    if (query.isEmpty) return false;
    final hay = [
      person.name,
      person.nameZhHans ?? '',
      person.nameZhHant ?? '',
      person.summary,
      person.summaryZhHans ?? '',
      person.summaryZhHant ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(query);
  }

  /// Should this node's children be visible right now?
  ///
  ///   1. Yes if on spine — that's the whole point of the spine view.
  ///   2. Yes if user explicitly cracked it open (chevron tap).
  ///   3. Yes if a search match lives in its subtree — we auto-
  ///      expand the ancestor path so the match isn't hidden.
  ///   4. No otherwise — the branch stays collapsed and the user
  ///      sees just the header row with a `+` chevron.
  bool get _expanded =>
      _onSpine ||
      userExpanded.contains(person.id) ||
      searchExpansion.contains(person.id);

  @override
  Widget build(BuildContext context) {
    final svc = FamilyTreeService.instance;
    final children = [
      for (final id in person.childIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];
    final hasKids = children.isNotEmpty;
    final indent = depth * 18.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: _NodeRow(
            person: person,
            locale: locale,
            scheme: scheme,
            isFocus: _isFocus,
            onSpine: _onSpine,
            isMatch: _matchesQuery,
            hasChildren: hasKids,
            isExpanded: _expanded,
            onTap: () => onPersonTap(person),
            onRefocus: () => onRefocus(person),
            onToggleExpand: hasKids ? () => onToggleExpand(person.id) : null,
          ),
        ),
        if (_expanded && hasKids)
          for (final c in children)
            _NodeView(
              person: c,
              depth: depth + 1,
              spine: spine,
              userExpanded: userExpanded,
              searchExpansion: searchExpansion,
              focusId: focusId,
              locale: locale,
              scheme: scheme,
              query: query,
              onPersonTap: onPersonTap,
              onRefocus: onRefocus,
              onToggleExpand: onToggleExpand,
            ),
      ],
    );
  }
}

class _NodeRow extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final bool isFocus;
  final bool onSpine;
  final bool isMatch;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onRefocus;
  final VoidCallback? onToggleExpand;

  const _NodeRow({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.isFocus,
    required this.onSpine,
    required this.isMatch,
    required this.hasChildren,
    required this.isExpanded,
    required this.onTap,
    required this.onRefocus,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final years = person.displayYears(locale);
    final bg = isFocus
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : isMatch
            ? scheme.tertiaryContainer.withValues(alpha: 0.45)
            : Colors.transparent;
    final borderColor = isFocus
        ? scheme.primary
        : onSpine
            ? scheme.primary.withValues(alpha: 0.35)
            : Colors.transparent;
    return Tooltip(
      message: uiStrings['familyTreeLongPressRefocus']?[locale] ??
          'Tap for details · long-press to focus',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onRefocus,
          onDoubleTap: onRefocus,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: hasChildren
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 16,
                          icon: Icon(isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right),
                          onPressed: onToggleExpand,
                          tooltip: isExpanded
                              ? (uiStrings['familyTreeCollapse']?[locale] ??
                                  'Collapse')
                              : (uiStrings['familyTreeExpand']?[locale] ??
                                  'Expand'),
                        )
                      : const SizedBox.shrink(),
                ),
                if (onSpine && !isFocus)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.bookmark,
                      size: 12,
                      color: scheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        person.localizedName(locale),
                        style: TextStyle(
                          fontSize: isFocus ? 14 : 13,
                          fontWeight: isFocus
                              ? FontWeight.w700
                              : (onSpine
                                  ? FontWeight.w600
                                  : FontWeight.w500),
                          color: scheme.onSurface,
                        ),
                      ),
                      if (years.isNotEmpty)
                        Text(
                          '· $years',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
