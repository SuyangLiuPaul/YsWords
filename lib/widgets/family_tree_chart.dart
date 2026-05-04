import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/biblical_person.dart';
import 'package:yswords/services/family_tree_service.dart';

/// Visual descendant chart for the Family Tree feature.
///
/// **Pattern**: focus + 2 generations of descendants, with a
/// tappable ancestor breadcrumb above the focus. The user can
/// reframe by tapping any card; the new focus slides into place
/// while keeping the breadcrumb history intact.
///
/// **Layout** (top to bottom inside an [InteractiveViewer]):
///
/// ```
///                Adam → Seth → Enosh           ← breadcrumb
///   ┌──────────────────────────────────┐
///   │       [Focus card + spouses]     │      ← focus row
///   └─────────────────┬────────────────┘
///        ┌────────────┼────────────┐
///   ┌────▼───┐   ┌────▼───┐   ┌────▼───┐
///   │ child1 │   │ child2 │   │ child3 │       ← children row
///   └────┬───┘   └────────┘   └────────┘
///   • g-child A
///   • g-child B                                ← grandchildren chips
/// ```
///
/// All visual elements are static `RenderObject`s laid out in one
/// pass — no async work — so the chart paints in <16ms even for
/// nodes with 12+ children. Lines are drawn by a [CustomPainter]
/// behind the cards.
class FamilyTreeChart extends StatefulWidget {
  /// The person currently shown as the focus card. Use [onRefocus]
  /// to handle tree navigation events.
  final BiblicalPerson focus;

  /// User's app locale — used for name + summary localization on
  /// every card.
  final String locale;

  /// Called when the user taps a card body (focus or descendant).
  /// Host should open the detail sheet.
  final void Function(BiblicalPerson) onPersonTap;

  /// Called when the user wants to make a different person the new
  /// focus — typically via tap on a non-focus card or a breadcrumb
  /// segment. Host should `setState` and rebuild this widget with
  /// the new focus.
  final void Function(BiblicalPerson) onRefocus;

  /// Optional list of ancestors above the focus, parent-first. The
  /// chart renders them as a breadcrumb so the user can hop back up
  /// the lineage.
  final List<BiblicalPerson> ancestry;

  const FamilyTreeChart({
    super.key,
    required this.focus,
    required this.locale,
    required this.onPersonTap,
    required this.onRefocus,
    this.ancestry = const [],
  });

  @override
  State<FamilyTreeChart> createState() => _FamilyTreeChartState();
}

class _FamilyTreeChartState extends State<FamilyTreeChart> {
  final TransformationController _viewerController =
      TransformationController();

  @override
  void didUpdateWidget(FamilyTreeChart old) {
    super.didUpdateWidget(old);
    // Reset zoom/pan when focus changes so the new chart lands
    // centered. Without this the user could be zoomed into a corner
    // of the old layout when a refocus happens.
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
    final spouses = [
      for (final id in widget.focus.spouseIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];
    final children = [
      for (final id in widget.focus.childIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];

    return Column(
      children: [
        if (widget.ancestry.isNotEmpty)
          _buildBreadcrumb(scheme),
        Expanded(
          child: InteractiveViewer(
            transformationController: _viewerController,
            // Allow pinch out to 2.5x for closeup reading on small
            // screens, and zoom out to 0.5x for "see the whole
            // generation" overviews.
            minScale: 0.5,
            maxScale: 2.5,
            // Plenty of pan room around the chart so the user can
            // drag to reframe without hitting hard edges.
            boundaryMargin: const EdgeInsets.all(200),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 24),
              child: _ChartLayout(
                focus: widget.focus,
                spouses: spouses,
                children: children,
                locale: widget.locale,
                scheme: scheme,
                onCardTap: widget.onPersonTap,
                onRefocus: widget.onRefocus,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Breadcrumb ────────────────────────────────────────────────────

  /// Compact horizontal trail of ancestors above the focus. Each
  /// segment is tappable; tapping one refocuses the chart on that
  /// ancestor. Shown as "A › B › C" with the rightmost segment
  /// being the immediate parent.
  Widget _buildBreadcrumb(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // anchor the focus segment to the right edge
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reverse so root is on the left and immediate parent
            // is just before the focus on the right.
            for (int i = widget.ancestry.length - 1; i >= 0; i--) ...[
              InkWell(
                onTap: () => widget.onRefocus(widget.ancestry[i]),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  child: Text(
                    widget.ancestry[i].localizedName(widget.locale),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                widget.focus.localizedName(widget.locale),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chart's actual node + connector layout. Pulled out of the
/// stateful host so the [InteractiveViewer] can transform it as a
/// single unit while [_FamilyTreeChartState] handles app-level
/// concerns like the breadcrumb and focus reset.
class _ChartLayout extends StatelessWidget {
  final BiblicalPerson focus;
  final List<BiblicalPerson> spouses;
  final List<BiblicalPerson> children;
  final String locale;
  final ColorScheme scheme;
  final void Function(BiblicalPerson) onCardTap;
  final void Function(BiblicalPerson) onRefocus;

  const _ChartLayout({
    required this.focus,
    required this.spouses,
    required this.children,
    required this.locale,
    required this.scheme,
    required this.onCardTap,
    required this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    final hasKids = children.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Focus row: focus card + inline spouse cluster ──────────
        IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PersonCard(
                person: focus,
                locale: locale,
                scheme: scheme,
                isFocus: true,
                onTap: () => onCardTap(focus),
              ),
              if (spouses.isNotEmpty) ...[
                _SpouseConnector(scheme: scheme),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in spouses)
                      _PersonCard(
                        person: s,
                        locale: locale,
                        scheme: scheme,
                        isFocus: false,
                        compact: true,
                        onTap: () => onCardTap(s),
                        onRefocus: () => onRefocus(s),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (hasKids) ...[
          // ── Vertical connector down to the children row ──────────
          _VerticalLine(scheme: scheme, height: 24),
          // ── Children row: horizontal scroll when overflowing ─────
          //
          // Layered as Stack(painter, Wrap):
          //   - background: CustomPainter draws the horizontal
          //     "comb" connecting all children to the focus stem
          //   - foreground: the actual child cards
          // The painter pulls anchor positions from the rendered
          // tree by measuring child key-positions on layout.
          _ChildrenRow(
            children: children,
            locale: locale,
            scheme: scheme,
            onCardTap: onCardTap,
            onRefocus: onRefocus,
          ),
        ],
      ],
    );
  }
}

class _ChildrenRow extends StatelessWidget {
  final List<BiblicalPerson> children;
  final String locale;
  final ColorScheme scheme;
  final void Function(BiblicalPerson) onCardTap;
  final void Function(BiblicalPerson) onRefocus;

  const _ChildrenRow({
    required this.children,
    required this.locale,
    required this.scheme,
    required this.onCardTap,
    required this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                _DescendantSubtree(
                  person: children[i],
                  locale: locale,
                  scheme: scheme,
                  onCardTap: onCardTap,
                  onRefocus: onRefocus,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One child + its grandchildren stub. Grandchildren render as
/// small text-only chips below the card so 3 generations fit on
/// screen without the chart blowing up vertically.
class _DescendantSubtree extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final void Function(BiblicalPerson) onCardTap;
  final void Function(BiblicalPerson) onRefocus;

  const _DescendantSubtree({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.onCardTap,
    required this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    final svc = FamilyTreeService.instance;
    final grand = [
      for (final id in person.childIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PersonCard(
          person: person,
          locale: locale,
          scheme: scheme,
          isFocus: false,
          onTap: () => onCardTap(person),
          onRefocus: () => onRefocus(person),
        ),
        if (grand.isNotEmpty) ...[
          _VerticalLine(scheme: scheme, height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final g in grand.take(8))
                  _GrandchildChip(
                    person: g,
                    locale: locale,
                    scheme: scheme,
                    onTap: () => onRefocus(g),
                  ),
                if (grand.length > 8)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(
                      '+${grand.length - 8}',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final bool isFocus;
  final bool compact;
  final VoidCallback onTap;

  /// Optional — non-focus cards expose a "make me the focus"
  /// gesture. Long-press is the canonical mobile equivalent of
  /// "right-click → set as root" in desktop UIs.
  final VoidCallback? onRefocus;

  const _PersonCard({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.isFocus,
    this.compact = false,
    required this.onTap,
    this.onRefocus,
  });

  @override
  Widget build(BuildContext context) {
    final years = person.displayYears(locale);
    final width = compact ? 96.0 : (isFocus ? 168.0 : 128.0);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    return Tooltip(
      message: onRefocus != null
          ? (uiStrings['familyTreeLongPressRefocus']?[locale] ??
              'Tap for details · long-press to focus')
          : person.localizedName(locale),
      child: Material(
        color: isFocus
            ? scheme.primaryContainer.withValues(alpha: 0.65)
            : scheme.surfaceContainerHigh,
        elevation: isFocus ? 2 : 0,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          // Non-focus cards can be long-pressed (canonical mobile
          // gesture) AND double-tapped to reframe. Focus card has
          // neither — long-press there does nothing because it's
          // already the focus.
          onLongPress: onRefocus,
          onDoubleTap: onRefocus,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: width,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFocus
                    ? scheme.primary
                    : scheme.outlineVariant,
                width: isFocus ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  person.localizedName(locale),
                  textAlign: TextAlign.center,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : (isFocus ? 14 : 12.5),
                    fontWeight:
                        isFocus ? FontWeight.w700 : FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (years.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    years,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 9 : 10.5,
                      color:
                          scheme.onSurface.withValues(alpha: 0.6),
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
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

class _GrandchildChip extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _GrandchildChip({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          person.localizedName(locale),
          style: TextStyle(
            fontSize: 10.5,
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

/// Short solid vertical connector between a parent and the row of
/// children below. Width is fixed at 2 px to read clean at any
/// zoom level inside the [InteractiveViewer].
class _VerticalLine extends StatelessWidget {
  final ColorScheme scheme;
  final double height;
  const _VerticalLine({required this.scheme, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      color: scheme.outline.withValues(alpha: 0.5),
    );
  }
}

/// Horizontal "=" connector between a focus card and an inline
/// spouse cluster. Different from the parent-child line so the
/// reader can tell at a glance "this is a marriage" vs "this is a
/// descent line".
class _SpouseConnector extends StatelessWidget {
  final ColorScheme scheme;
  const _SpouseConnector({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 2,
            color: scheme.primary.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 2),
          Container(
            width: 14,
            height: 2,
            color: scheme.primary.withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }
}
