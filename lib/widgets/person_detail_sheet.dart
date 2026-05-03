import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/biblical_person.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/family_tree_service.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart';

/// Bottom sheet showing the full record for one [BiblicalPerson].
/// Sections (in render order):
///   - name + life-years header
///   - localized 1-2 sentence summary
///   - parents (chips, tap to navigate to their record)
///   - spouses (chips, tap to navigate)
///   - children (chips, tap to navigate)
///   - patrilineal ancestry trail (collapsed; expand to see lineage)
///   - verse references (chips, tap to jump the reader to the verse)
class PersonDetailSheet extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ScrollController scrollController;

  /// Called when the user taps another person's chip (parent /
  /// spouse / child / ancestor). The host re-opens this same sheet
  /// for the new person, so the user can hop along the lineage.
  final void Function(BiblicalPerson)? onPersonTap;

  const PersonDetailSheet({
    super.key,
    required this.person,
    required this.locale,
    required this.scrollController,
    this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final svc = FamilyTreeService.instance;
    final father = person.fatherId == null ? null : svc.byId(person.fatherId!);
    final mother = person.motherId == null ? null : svc.byId(person.motherId!);
    final spouses = [
      for (final id in person.spouseIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];
    final children = [
      for (final id in person.childIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];
    final years = person.displayYears(locale);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          person.localizedName(locale),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (years.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            years,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          person.localizedSummary(locale),
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 16),
        if (father != null || mother != null)
          _section(
            scheme: scheme,
            label: uiStrings['familyTreeParents']?[locale] ?? 'Parents',
            children: [
              if (father != null)
                _personChip(context, father, scheme, prefix:
                    uiStrings['familyTreeFather']?[locale] ?? 'Father'),
              if (mother != null)
                _personChip(context, mother, scheme, prefix:
                    uiStrings['familyTreeMother']?[locale] ?? 'Mother'),
            ],
          ),
        if (spouses.isNotEmpty)
          _section(
            scheme: scheme,
            label: spouses.length == 1
                ? (uiStrings['familyTreeSpouse']?[locale] ?? 'Spouse')
                : (uiStrings['familyTreeSpouses']?[locale] ?? 'Spouses'),
            children: [
              for (final s in spouses) _personChip(context, s, scheme),
            ],
          ),
        if (children.isNotEmpty)
          _section(
            scheme: scheme,
            label: uiStrings['familyTreeChildren']?[locale] ?? 'Children',
            children: [
              for (final c in children) _personChip(context, c, scheme),
            ],
          ),
        if (person.refs.isNotEmpty) ...[
          const SizedBox(height: 4),
          _section(
            scheme: scheme,
            label: uiStrings['familyTreeReferences']?[locale] ??
                'Verse references',
            children: [
              for (final ref in person.refs)
                _refChip(context, ref, scheme),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _AncestryTrail(person: person, locale: locale, scheme: scheme),
      ],
    );
  }

  Widget _section({
    required ColorScheme scheme,
    required String label,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _personChip(
    BuildContext context,
    BiblicalPerson p,
    ColorScheme scheme, {
    String? prefix,
  }) {
    final years = p.displayYears(locale);
    return ActionChip(
      avatar: Icon(Icons.person_outline, size: 14, color: scheme.primary),
      label: Text(
        prefix == null
            ? '${p.localizedName(locale)}${years.isEmpty ? '' : '  ($years)'}'
            : '$prefix: ${p.localizedName(locale)}',
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () => onPersonTap?.call(p),
      visualDensity: VisualDensity.compact,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      side: BorderSide(color: scheme.outlineVariant),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _refChip(BuildContext context, String ref, ColorScheme scheme) {
    return ActionChip(
      avatar: Icon(Icons.menu_book_outlined, size: 14, color: scheme.primary),
      label: Text(ref, style: const TextStyle(fontSize: 12)),
      onPressed: () => _jumpToRef(context, ref),
      visualDensity: VisualDensity.compact,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.18),
      side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Future<void> _jumpToRef(BuildContext context, String raw) async {
    // Take only the first segment of `;`-separated chains so the
    // parser handles e.g. "Genesis 1:26-27" cleanly.
    final ref = parseReference(raw);
    if (ref == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text("Couldn't parse: $raw"),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    Navigator.of(context).maybePop();
    Get.to(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
  }
}

/// Collapsible patrilineal trail — Adam → … → person. Useful for
/// orienting where this person sits in the canonical line. Hidden
/// by default to keep the sheet focused on immediate family; the
/// section header is tappable to reveal/hide.
class _AncestryTrail extends StatefulWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  const _AncestryTrail({
    required this.person,
    required this.locale,
    required this.scheme,
  });

  @override
  State<_AncestryTrail> createState() => _AncestryTrailState();
}

class _AncestryTrailState extends State<_AncestryTrail> {
  bool _expanded = false;
  List<BiblicalPerson>? _trail;

  @override
  void initState() {
    super.initState();
    FamilyTreeService.instance
        .patrilineage(widget.person)
        .then((t) => mounted ? setState(() => _trail = t) : null);
  }

  @override
  Widget build(BuildContext context) {
    final trail = _trail;
    if (trail == null || trail.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: widget.scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    uiStrings['familyTreeAncestry']?[widget.locale] ??
                        'Patrilineal ancestry',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: widget.scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            Text(
              // Reverse so the trail reads top-down: Adam → … → father → person.
              [
                for (final a in trail.reversed) a.localizedName(widget.locale),
                widget.person.localizedName(widget.locale),
              ].join(' → '),
              style: TextStyle(
                fontSize: 13,
                color: widget.scheme.onSurface.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
