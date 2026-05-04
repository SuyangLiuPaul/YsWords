import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Logos-style "associated trees" surface — sibling chips plus
    // a chip for the closest tribe / role-tagged ancestor (e.g.
    // for Aaron: Levi (PRIESTLY TRIBE); for Solomon: Judah (ROYAL
    // TRIBE)). These act as one-tap shortcuts to lateral context
    // without the user having to walk back up the chain manually.
    final siblings = _siblingsOf(person, svc);
    final tribeAncestor = _closestTribeAncestor(person, svc);

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Copy-all button: copies the rendered detail content as
            // plain text to the clipboard so the user can paste into
            // notes / messages / docs.
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: uiStrings['familyTreeCopyAll']?[locale] ??
                  'Copy all info',
              onPressed: () => _copyAll(
                context: context,
                father: father,
                mother: mother,
                spouses: spouses,
                children: children,
                siblings: siblings,
                tribeAncestor: tribeAncestor,
              ),
              style: IconButton.styleFrom(
                foregroundColor: scheme.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
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
        if (siblings.isNotEmpty)
          _section(
            scheme: scheme,
            label: uiStrings['familyTreeSiblings']?[locale] ?? 'Siblings',
            children: [
              for (final s in siblings) _personChip(context, s, scheme),
            ],
          ),
        if (tribeAncestor != null)
          _section(
            scheme: scheme,
            label: uiStrings['familyTreeTribeLine']?[locale] ?? 'Tribe / line',
            children: [
              _personChip(context, tribeAncestor, scheme),
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

  /// Format the visible detail-sheet content as plain text and
  /// copy to the system clipboard. Includes the patrilineal trail
  /// (Adam → … → person) per the user's request. Uses the user's
  /// current locale for all names + summary + section labels.
  Future<void> _copyAll({
    required BuildContext context,
    required BiblicalPerson? father,
    required BiblicalPerson? mother,
    required List<BiblicalPerson> spouses,
    required List<BiblicalPerson> children,
    required List<BiblicalPerson> siblings,
    required BiblicalPerson? tribeAncestor,
  }) async {
    String namesOf(List<BiblicalPerson> xs) =>
        xs.map((p) => p.localizedName(locale)).join(', ');

    // Patrilineal trail Adam → … → person, awaited up-front.
    final svc = FamilyTreeService.instance;
    final trail = await svc.patrilineage(person);

    final years = person.displayYears(locale);
    final buf = StringBuffer();
    buf.writeln(person.localizedName(locale));
    if (years.isNotEmpty) buf.writeln(years);
    if ((person.role ?? '').isNotEmpty) {
      buf.writeln(
          '${uiStrings['familyTreeRole']?[locale] ?? 'Role'}: ${person.role}');
    }
    buf.writeln();
    buf.writeln(person.localizedSummary(locale));
    buf.writeln();

    if (father != null || mother != null) {
      final parts = <String>[];
      if (father != null) {
        parts.add(
            '${uiStrings['familyTreeFather']?[locale] ?? 'Father'}: ${father.localizedName(locale)}');
      }
      if (mother != null) {
        parts.add(
            '${uiStrings['familyTreeMother']?[locale] ?? 'Mother'}: ${mother.localizedName(locale)}');
      }
      buf.writeln(
          '${uiStrings['familyTreeParents']?[locale] ?? 'Parents'}: ${parts.join(' · ')}');
    }
    if (spouses.isNotEmpty) {
      final label = spouses.length == 1
          ? (uiStrings['familyTreeSpouse']?[locale] ?? 'Spouse')
          : (uiStrings['familyTreeSpouses']?[locale] ?? 'Spouses');
      buf.writeln('$label: ${namesOf(spouses)}');
    }
    if (children.isNotEmpty) {
      buf.writeln(
          '${uiStrings['familyTreeChildren']?[locale] ?? 'Children'}: ${namesOf(children)}');
    }
    if (siblings.isNotEmpty) {
      buf.writeln(
          '${uiStrings['familyTreeSiblings']?[locale] ?? 'Siblings'}: ${namesOf(siblings)}');
    }
    if (tribeAncestor != null) {
      buf.writeln(
          '${uiStrings['familyTreeTribeLine']?[locale] ?? 'Tribe / line'}: ${tribeAncestor.localizedName(locale)}');
    }

    // Patrilineal ancestry — Adam → … → father → person, top-down.
    if (trail.isNotEmpty) {
      buf.writeln();
      buf.writeln(
          '${uiStrings['familyTreeAncestry']?[locale] ?? 'Patrilineal ancestry'}:');
      final chainTopDown = [
        for (final a in trail.reversed) a.localizedName(locale),
        person.localizedName(locale),
      ];
      buf.writeln('  ${chainTopDown.join(' → ')}');
    }

    if (person.refs.isNotEmpty) {
      buf.writeln();
      buf.writeln(
          '${uiStrings['familyTreeReferences']?[locale] ?? 'Verse references'}:');
      for (final r in person.refs) {
        buf.writeln('  • $r');
      }
    }

    await Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    if (!context.mounted) return;
    // Use rootScaffoldMessenger so the SnackBar shows above the
    // modal bottom sheet (otherwise it can be hidden behind the
    // sheet's surface). 2-second duration gives clear visibility
    // in all three locales.
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              uiStrings['familyTreeCopiedToast']?[locale] ??
                  'Copied to clipboard',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      duration: const Duration(milliseconds: 2000),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 80),
    ));
  }

  /// People with the same father OR mother as [p], excluding [p].
  /// Walks both parents' childIds + dedupes; preserves ordering.
  List<BiblicalPerson> _siblingsOf(
      BiblicalPerson p, FamilyTreeService svc) {
    final out = <BiblicalPerson>[];
    final seen = <String>{p.id};
    void addSiblingsFrom(String? parentId) {
      if (parentId == null) return;
      final parent = svc.byId(parentId);
      if (parent == null) return;
      for (final cid in parent.childIds) {
        if (seen.add(cid)) {
          final c = svc.byId(cid);
          if (c != null) out.add(c);
        }
      }
    }
    addSiblingsFrom(p.fatherId);
    addSiblingsFrom(p.motherId);
    return out;
  }

  /// Walk up the father / mother chain and return the closest
  /// ancestor whose [BiblicalPerson.role] contains "TRIBE" — i.e.
  /// the named tribe / line this person belongs to. e.g. Aaron →
  /// Levi (PRIESTLY TRIBE); Solomon → Judah (ROYAL TRIBE). Returns
  /// null when no ancestor is tribe-labelled (Adam → Noah etc.).
  BiblicalPerson? _closestTribeAncestor(
      BiblicalPerson p, FamilyTreeService svc) {
    var cur = p;
    for (var i = 0; i < 200; i++) {
      final pid = cur.fatherId ?? cur.motherId;
      if (pid == null) return null;
      final next = svc.byId(pid);
      if (next == null) return null;
      if ((next.role ?? '').toUpperCase().contains('TRIBE')) {
        return next;
      }
      cur = next;
    }
    return null;
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
