import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/biblical_person.dart';
import 'package:yswords/services/family_tree_service.dart';

/// True visual tree from the dataset root (Adam) down to the
/// current focus, plus the focus's children fanned out below.
///
/// **Pattern**: a vertical generational cascade, the canonical way
/// genealogy charts render top-down. Each generation is a row,
/// connected to the next by a short vertical line. Only the spine
/// stays expanded in full size; off-spine siblings sit as compact
/// chip rows tucked beside or below their generation, so the
/// 70-deep Adam→Jesus lineage stays scannable on a phone.
///
/// **Layout**:
///
/// ```
///                  ┌──────┐
///                  │ Adam │   ← root (focus tinted card)
///                  └──┬───┘
///                     │
///        [Cain] [Abel]   ← off-spine siblings of next spine member
///                     │
///                  ┌──┴───┐
///                  │ Seth │   ← spine member
///                  └──┬───┘
///                     │
///                  ┌──┴───┐
///                  │Enosh │   ← spine member (no off-spine siblings)
///                  └──┬───┘
///                     ⋮
///                  ┌──┴───┐
///                  │FOCUS │   ← highlighted background + thick border
///                  └──┬───┘
///                     │
///        [child 1] [child 2] [child 3]   ← fan of children
/// ```
///
/// Tap any card → opens the detail sheet.
/// Long-press / double-tap any non-focus card → reframe focus.
/// Pinch-zoom + pan via [InteractiveViewer] for navigating the
/// whole tree on small screens.
class FamilyVisualTree extends StatefulWidget {
  /// Dataset root — the topmost card on the tree (typically Adam).
  final BiblicalPerson root;

  /// Current focus — the spine extends from [root] down to here.
  /// The focus card is the most prominent, and the children of the
  /// focus are fanned out one row below.
  final BiblicalPerson focus;

  /// Locale for name/year/summary rendering.
  final String locale;

  /// Free-text query to highlight matching nodes. Doesn't change
  /// the tree shape — the spine is always the same — but draws a
  /// subtle tertiary-tinted background on any card whose
  /// name/summary contains the query. The host page still owns
  /// query state.
  final String query;

  /// Tap a node body → opens the detail sheet on the host.
  final void Function(BiblicalPerson) onPersonTap;

  /// Long-press / double-tap a non-focus card → reframe so that
  /// person becomes the new spine focus.
  final void Function(BiblicalPerson) onRefocus;

  const FamilyVisualTree({
    super.key,
    required this.root,
    required this.focus,
    required this.locale,
    required this.onPersonTap,
    required this.onRefocus,
    this.query = '',
  });

  @override
  State<FamilyVisualTree> createState() => _FamilyVisualTreeState();
}

class _FamilyVisualTreeState extends State<FamilyVisualTree> {
  final TransformationController _viewerController =
      TransformationController();

  @override
  void didUpdateWidget(FamilyVisualTree old) {
    super.didUpdateWidget(old);
    if (old.focus.id != widget.focus.id) {
      _viewerController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final svc = FamilyTreeService.instance;
    final spine = _computeSpine(svc);
    final query = widget.query.trim().toLowerCase();
    final focusChildren = [
      for (final id in widget.focus.childIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];

    return InteractiveViewer(
      transformationController: _viewerController,
      minScale: 0.5,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < spine.length; i++) ...[
              if (i > 0) _VerticalConnector(scheme: scheme),
              if (i > 0)
                _OffSpineSiblings(
                  spineMember: spine[i],
                  parent: spine[i - 1],
                  locale: widget.locale,
                  scheme: scheme,
                  query: query,
                  onTap: widget.onPersonTap,
                  onRefocus: widget.onRefocus,
                ),
              _SpineCard(
                person: spine[i],
                isFocus: i == spine.length - 1,
                isRoot: i == 0,
                locale: widget.locale,
                scheme: scheme,
                query: query,
                onTap: () => widget.onPersonTap(spine[i]),
                onRefocus: i == spine.length - 1
                    ? null
                    : () => widget.onRefocus(spine[i]),
              ),
            ],
            if (focusChildren.isNotEmpty) ...[
              _VerticalConnector(scheme: scheme, height: 24),
              _ChildrenFan(
                children: focusChildren,
                locale: widget.locale,
                scheme: scheme,
                query: query,
                onTap: widget.onPersonTap,
                onRefocus: widget.onRefocus,
              ),
            ] else ...[
              const SizedBox(height: 24),
              Text(
                uiStrings['familyTreeFocusLeaf']?[widget.locale] ??
                    'No descendants in this dataset.',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// BFS from root following childIds toward focus. Returns the
  /// person list along the path including both endpoints, in
  /// root-first order. Same algorithm as round-58's
  /// [FamilySpineTree] but exposes the full list (not just an id
  /// set) so we can render in order.
  List<BiblicalPerson> _computeSpine(FamilyTreeService svc) {
    final start = widget.root.id;
    final goal = widget.focus.id;
    if (start == goal) return [widget.root];
    final cameFrom = <String, String>{};
    final queue = <String>[start];
    final seen = <String>{start};
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (cur == goal) break;
      final p = svc.byId(cur);
      if (p == null) continue;
      for (final c in p.childIds) {
        if (seen.contains(c)) continue;
        seen.add(c);
        cameFrom[c] = cur;
        queue.add(c);
      }
    }
    if (!cameFrom.containsKey(goal)) return [widget.root];
    final ids = <String>[goal];
    var cur = goal;
    while (cameFrom.containsKey(cur)) {
      cur = cameFrom[cur]!;
      ids.add(cur);
    }
    return [for (final id in ids.reversed) svc.byId(id)!];
  }
}

// ── Spine card ───────────────────────────────────────────────────

/// One generation's primary card. Larger and tinted for the focus,
/// smaller and outlined for ancestors. Tap → detail sheet,
/// long-press / double-tap → reframe (only for non-focus members).
class _SpineCard extends StatelessWidget {
  final BiblicalPerson person;
  final bool isFocus;
  final bool isRoot;
  final String locale;
  final ColorScheme scheme;
  final String query;
  final VoidCallback onTap;
  final VoidCallback? onRefocus;

  const _SpineCard({
    required this.person,
    required this.isFocus,
    required this.isRoot,
    required this.locale,
    required this.scheme,
    required this.query,
    required this.onTap,
    this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    final years = person.displayYears(locale);
    final isMatch = query.isNotEmpty && _matches(person, query);
    final width = isFocus ? 200.0 : 156.0;
    return Tooltip(
      message: onRefocus != null
          ? (uiStrings['familyTreeLongPressRefocus']?[locale] ??
              'Tap for details · long-press to focus')
          : person.localizedName(locale),
      child: Material(
        color: isFocus
            ? scheme.primaryContainer.withValues(alpha: 0.7)
            : isMatch
                ? scheme.tertiaryContainer.withValues(alpha: 0.45)
                : scheme.surfaceContainerHigh,
        elevation: isFocus ? 3 : 1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          onLongPress: onRefocus,
          onDoubleTap: onRefocus,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: width,
            padding: EdgeInsets.symmetric(
              horizontal: isFocus ? 14 : 12,
              vertical: isFocus ? 10 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocus
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.35),
                width: isFocus ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isRoot)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      uiStrings['familyTreeRootLabel']?[locale] ?? 'ROOT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: scheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                Text(
                  person.localizedName(locale),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isFocus ? 15 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (years.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    years,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Off-spine siblings cluster ───────────────────────────────────

/// The siblings of a spine member — i.e. the OTHER children of
/// that spine member's parent, who are not on the spine
/// themselves. Rendered as a Wrap of compact chips just above
/// the spine card. Tap a chip → reframe focus on that sibling.
/// Hidden when the parent has no off-spine children (e.g. Seth
/// has only Enosh in the dataset, so above Enosh nothing renders).
class _OffSpineSiblings extends StatelessWidget {
  final BiblicalPerson spineMember;
  final BiblicalPerson parent;
  final String locale;
  final ColorScheme scheme;
  final String query;
  final void Function(BiblicalPerson) onTap;
  final void Function(BiblicalPerson) onRefocus;

  const _OffSpineSiblings({
    required this.spineMember,
    required this.parent,
    required this.locale,
    required this.scheme,
    required this.query,
    required this.onTap,
    required this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    final svc = FamilyTreeService.instance;
    final siblings = [
      for (final id in parent.childIds)
        if (id != spineMember.id && svc.byId(id) != null) svc.byId(id)!,
    ];
    if (siblings.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < siblings.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _SiblingChip(
                  person: siblings[i],
                  locale: locale,
                  scheme: scheme,
                  query: query,
                  onTap: () => onTap(siblings[i]),
                  onRefocus: () => onRefocus(siblings[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SiblingChip extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRefocus;

  const _SiblingChip({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.query,
    required this.onTap,
    required this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    final kids = person.childIds.length;
    final years = person.displayYears(locale);
    final isMatch = query.isNotEmpty && _matches(person, query);
    return Tooltip(
      message: uiStrings['familyTreeLongPressRefocus']?[locale] ??
          'Tap for details · long-press to focus',
      child: Material(
        color: isMatch
            ? scheme.tertiaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          onLongPress: onRefocus,
          onDoubleTap: onRefocus,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.localizedName(locale),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (kids > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+$kids',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (years.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      years,
                      style: TextStyle(
                        fontSize: 9,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Children fan ─────────────────────────────────────────────────

/// Children of the focus laid out in a horizontal Wrap below the
/// focus card. Tap any → detail sheet; long-press / double-tap →
/// reframe. Tied to the focus by a single vertical connector
/// rendered above this widget by the host.
class _ChildrenFan extends StatelessWidget {
  final List<BiblicalPerson> children;
  final String locale;
  final ColorScheme scheme;
  final String query;
  final void Function(BiblicalPerson) onTap;
  final void Function(BiblicalPerson) onRefocus;

  const _ChildrenFan({
    required this.children,
    required this.locale,
    required this.scheme,
    required this.query,
    required this.onTap,
    required this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _ChildCard(
                person: children[i],
                locale: locale,
                scheme: scheme,
                query: query,
                onTap: () => onTap(children[i]),
                onRefocus: () => onRefocus(children[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRefocus;

  const _ChildCard({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.query,
    required this.onTap,
    required this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    final years = person.displayYears(locale);
    final kids = person.childIds.length;
    final isMatch = query.isNotEmpty && _matches(person, query);
    return Tooltip(
      message: uiStrings['familyTreeLongPressRefocus']?[locale] ??
          'Tap for details · long-press to focus',
      child: Material(
        color: isMatch
            ? scheme.tertiaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHigh,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          onLongPress: onRefocus,
          onDoubleTap: onRefocus,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        person.localizedName(locale),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (kids > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+$kids',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (years.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    years,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Connector ───────────────────────────────────────────────────

class _VerticalConnector extends StatelessWidget {
  final ColorScheme scheme;
  final double height;
  const _VerticalConnector({required this.scheme, this.height = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      color: scheme.primary.withValues(alpha: 0.45),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────

bool _matches(BiblicalPerson p, String query) {
  if (query.isEmpty) return false;
  final hay = [
    p.name,
    p.nameZhHans ?? '',
    p.nameZhHant ?? '',
    p.summary,
    p.summaryZhHans ?? '',
    p.summaryZhHant ?? '',
  ].join(' ').toLowerCase();
  return hay.contains(query);
}
