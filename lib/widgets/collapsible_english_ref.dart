import 'package:flutter/material.dart';

/// A compact, collapsed-by-default disclosure used in the Chinese
/// exegesis panel to tuck away **English-only** lexicon material
/// (Strong's etymology / derivation, KJV translation counts) so the
/// Chinese reader sees Chinese first and reveals the English reference
/// only on tap.
///
/// Rendered as a borderless [ExpansionTile] (the surrounding theme's
/// divider lines are suppressed) with a translate icon + a muted
/// title. Kept generic so both the originals sheet (释经 panel) and the
/// standalone Strong's entry page can share it.
class CollapsibleEnglishRef extends StatelessWidget {
  const CollapsibleEnglishRef({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Theme(
      // ExpansionTile draws a divider above + below when expanded;
      // suppress it so this reads as an inline disclosure, not a
      // list section.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(Icons.translate,
            size: 16, color: scheme.onSurfaceVariant),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        children: [child],
      ),
    );
  }
}
