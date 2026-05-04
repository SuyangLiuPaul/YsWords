import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/biblical_person.dart';
import 'package:yswords/services/family_tree_service.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/person_detail_sheet.dart';

/// Browseable Bible family tree, modelled on the structure of the
/// Wikipedia article *"Genealogies in the Bible"*:
///
///   * **Sectioned per family / era.** Eight collapsible sections
///     (Antediluvian / Post-Flood / Patriarchs / Mosaic / Davidic
///     Line / Kings of Judah / Exile & Return / New Testament).
///     Each section is a self-contained mini-tree — the walk
///     descends only into same-era children, so Levi appears in
///     "Patriarchs" but his Mosaic-era descendants (Kohath,
///     Jochebed → Aaron / Moses / Miriam) live under the
///     "Mosaic" section instead. No more 96-deep walls.
///   * **Comparison table at the bottom.** Linear Adam → Jesus
///     chain (rows) × Bible-source columns (Genesis 5 / Genesis
///     11 / 1 Chronicles 1 / Ruth 4 / Matthew 1 / Luke 3); cells
///     ✓ when the person's refs include that book/chapter. Tap
///     any row → detail sheet. Horizontally scrollable on
///     phones.
///   * **Search**: filter-as-you-type. Sections that contain
///     matches auto-uncollapse; ancestor rows auto-expand;
///     matches get a tertiary tint.
///   * **Tap behaviour**: chevron toggles children, row body tap
///     opens the detail sheet. Conventional, least-surprise.
///
/// Per-row info (kept across iterations): role pill, year span,
/// spouse chips inline, verse-ref count badge, accent stripe
/// (priestly red, royal blue, messianic gold, prophetic purple).
class FamilyTreePage extends StatefulWidget {
  const FamilyTreePage({super.key});

  @override
  State<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends State<FamilyTreePage> {
  Future<_TreeData>? _future;
  String _query = '';
  late final TextEditingController _searchController;

  /// Persons whose children rows are visible. Search auto-unions
  /// in ancestor chains so matches are revealed in context.
  final Set<String> _expanded = {};

  /// Era keys that the user has manually collapsed. Inverted from
  /// the more typical "expanded" set so the default state is "all
  /// sections open" without having to enumerate every era at
  /// startup.
  final Set<String> _collapsedEras = {};

  /// Canonical era ordering — drives the order of section blocks.
  static const List<String> _eraOrder = [
    'antediluvian',
    'post_flood',
    'patriarchs',
    'mosaic',
    'davidic_line',
    'kings',
    'exile',
    'nt',
  ];

  /// Bible-source columns for the comparison table at the bottom.
  /// Each tuple = (column label key, list of "Book Chapter"
  /// prefixes that count as a hit). The label key resolves through
  /// ui_strings for short table headers.
  static const List<(String, List<String>)> _comparisonColumns = [
    ('familyTreeColGen5', ['Genesis 5']),
    ('familyTreeColGen11', ['Genesis 11']),
    ('familyTreeColChron1', ['1 Chronicles 1', '1 Chronicles 2', '1 Chronicles 3']),
    ('familyTreeColRuth4', ['Ruth 4']),
    ('familyTreeColMatt1', ['Matthew 1']),
    ('familyTreeColLuke3', ['Luke 3']),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_TreeData> _load() async {
    final svc = FamilyTreeService.instance;
    final all = await svc.loadAll();
    // Default-expand every parent in the dataset so each section's
    // mini-tree shows its full lineage on first load (Wikipedia-
    // style "everything visible"). User can collapse via chevrons.
    for (final p in all) {
      if (p.childIds.isNotEmpty) {
        _expanded.add(p.id);
      }
    }
    return _TreeData(all: all, svc: svc);
  }

  // ── Filter helpers ───────────────────────────────────────────────

  List<BiblicalPerson> _filtered(
      List<BiblicalPerson> all, String query) {
    final q = sanitizeForSearch(query).toLowerCase();
    return all.where((p) {
      final hay = [
        p.name,
        p.nameZhHans ?? '',
        p.nameZhHant ?? '',
        p.id,
        p.role ?? '',
        p.summary,
        p.summaryZhHans ?? '',
        p.summaryZhHant ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Set<String> _ancestorsOf(BiblicalPerson p, FamilyTreeService svc) {
    final out = <String>{p.id};
    var cur = p;
    for (var i = 0; i < 200; i++) {
      final pid = cur.fatherId ?? cur.motherId;
      if (pid == null || out.contains(pid)) break;
      out.add(pid);
      final next = svc.byId(pid);
      if (next == null) break;
      cur = next;
    }
    return out;
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['familyTree']?[locale] ?? 'Family Tree'),
        actions: const [HomeIconButton()],
      ),
      body: FutureBuilder<_TreeData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load: ${snap.error}',
                    style: TextStyle(color: scheme.error)),
              ),
            );
          }
          final data = snap.data!;
          final filtered = _query.trim().isEmpty
              ? null
              : _filtered(data.all, _query.trim());

          // Compute match + ancestor sets so sections auto-expand
          // around matches.
          final matchIds = <String>{};
          final ancestorIds = <String>{};
          if (filtered != null) {
            for (final m in filtered) {
              matchIds.add(m.id);
              ancestorIds.addAll(_ancestorsOf(m, data.svc));
            }
          }

          // Era → list of people in that era. Used by sections.
          final byEra = <String, List<BiblicalPerson>>{
            for (final e in _eraOrder) e: <BiblicalPerson>[],
          };
          for (final p in data.all) {
            final era = p.era;
            if (era != null && byEra.containsKey(era)) {
              byEra[era]!.add(p);
            }
          }

          // Adam → Jesus spine for the comparison table. Walk
          // father chain backwards from Jesus and reverse.
          final spine = _computeAdamToJesus(data);

          // Cap the content width so on a wide iPad / desktop the
          // article doesn't sprawl edge-to-edge — readability over
          // 960 px lines tanks. On phones this is a no-op.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  _buildSearchField(locale),
                  _buildSummary(
                    data: data,
                    filtered: filtered,
                    locale: locale,
                    scheme: scheme,
                  ),
                  Expanded(
                    child: filtered != null && filtered.isEmpty
                        ? _buildNoMatches(locale, scheme)
                        : _buildArticle(
                            data: data,
                            byEra: byEra,
                            spine: spine,
                            matchIds: matchIds,
                            ancestorIds: ancestorIds,
                            locale: locale,
                            scheme: scheme,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoMatches(String locale, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          uiStrings['familyTreeNoMatches']?[locale] ??
              'No one matches that search.',
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  // ── Search field ────────────────────────────────────────────────

  Widget _buildSearchField(String locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          hintText: uiStrings['familyTreeSearchHint']?[locale] ??
              'Search by name or biography…',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _buildSummary({
    required _TreeData data,
    required List<BiblicalPerson>? filtered,
    required String locale,
    required ColorScheme scheme,
  }) {
    final s = filtered != null
        ? (uiStrings['familyTreeFilterCount']?[locale] ??
                '{count} of {total} people')
            .replaceAll('{count}', filtered.length.toString())
            .replaceAll('{total}', data.all.length.toString())
        : (uiStrings['familyTreeTotalCount']?[locale] ??
                '{total} people')
            .replaceAll('{total}', data.all.length.toString());

    // "Are most sections collapsed?" → if so the toggle button
    // says "Expand all", otherwise "Collapse all". We compute on
    // the eras that actually have people; otherwise an empty era
    // would skew the heuristic.
    final eraCount = _eraOrder.length;
    final allCollapsed = _collapsedEras.length >= eraCount;
    final toggleLabel = allCollapsed
        ? (uiStrings['familyTreeExpandAll']?[locale] ?? 'Expand all')
        : (uiStrings['familyTreeCollapseAll']?[locale] ?? 'Collapse all');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          // Power-user lever — flip every section open / closed at
          // once. Toggles between "expand all sections" and
          // "collapse all sections" based on the current global
          // state.
          TextButton.icon(
            onPressed: () => setState(() {
              if (allCollapsed) {
                _collapsedEras.clear();
              } else {
                _collapsedEras
                  ..clear()
                  ..addAll(_eraOrder);
              }
            }),
            icon: Icon(
              allCollapsed
                  ? Icons.unfold_more_rounded
                  : Icons.unfold_less_rounded,
              size: 16,
            ),
            label: Text(
              toggleLabel,
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Article body ────────────────────────────────────────────────

  Widget _buildArticle({
    required _TreeData data,
    required Map<String, List<BiblicalPerson>> byEra,
    required List<BiblicalPerson> spine,
    required Set<String> matchIds,
    required Set<String> ancestorIds,
    required String locale,
    required ColorScheme scheme,
  }) {
    final sections = <Widget>[];
    for (final era in _eraOrder) {
      final eraPeople = byEra[era] ?? const <BiblicalPerson>[];
      if (eraPeople.isEmpty) continue;
      final hasMatch = matchIds.any((id) =>
          eraPeople.any((p) => p.id == id));
      // Auto-uncollapse any section that contains a match.
      final isCollapsed = _collapsedEras.contains(era) && !hasMatch;
      sections.add(_EraSection(
        era: era,
        people: eraPeople,
        svc: data.svc,
        locale: locale,
        scheme: scheme,
        isCollapsed: isCollapsed,
        onToggle: () => setState(() {
          if (_collapsedEras.contains(era)) {
            _collapsedEras.remove(era);
          } else {
            _collapsedEras.add(era);
          }
        }),
        expanded: _expanded,
        ancestorIds: ancestorIds,
        matchIds: matchIds,
        onTogglePerson: (id) => setState(() {
          if (_expanded.contains(id)) {
            _expanded.remove(id);
          } else {
            _expanded.add(id);
          }
        }),
        onTapPerson: _showDetail,
      ));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ...sections,
        _ComparisonTable(
          spine: spine,
          locale: locale,
          scheme: scheme,
          matchIds: matchIds,
          comparisonColumns: _comparisonColumns,
          onTapPerson: _showDetail,
        ),
      ],
    );
  }

  // ── Adam → Jesus spine ─────────────────────────────────────────

  /// Walk fatherId backwards from Jesus to the topmost ancestor
  /// (Adam) and reverse to get the canonical genealogy as a flat
  /// list. If Jesus isn't in the dataset, fall back to whichever
  /// NT-era person we can reach.
  List<BiblicalPerson> _computeAdamToJesus(_TreeData data) {
    final svc = data.svc;
    final start =
        svc.byId('jesus') ?? svc.byId('joseph_father_of_jesus');
    if (start == null) return const [];
    final out = <BiblicalPerson>[start];
    var cur = start;
    final seen = <String>{cur.id};
    for (var i = 0; i < 200; i++) {
      final pid = cur.fatherId ?? cur.motherId;
      if (pid == null || seen.contains(pid)) break;
      final next = svc.byId(pid);
      if (next == null) break;
      seen.add(pid);
      out.add(next);
      cur = next;
    }
    return out.reversed.toList();
  }

  // ── Detail sheet ───────────────────────────────────────────────

  Future<void> _showDetail(BiblicalPerson p) async {
    final settings = context.read<AppSettings>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => PersonDetailSheet(
          person: p,
          locale: settings.locale,
          scrollController: scrollController,
          onPersonTap: (other) {
            Navigator.of(sheetCtx).maybePop();
            _showDetail(other);
          },
        ),
      ),
    );
  }
}

// ── Era section ────────────────────────────────────────────────

class _EraSection extends StatelessWidget {
  final String era;
  final List<BiblicalPerson> people;
  final FamilyTreeService svc;
  final String locale;
  final ColorScheme scheme;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final Set<String> expanded;
  final Set<String> ancestorIds;
  final Set<String> matchIds;
  final void Function(String id) onTogglePerson;
  final void Function(BiblicalPerson) onTapPerson;

  const _EraSection({
    required this.era,
    required this.people,
    required this.svc,
    required this.locale,
    required this.scheme,
    required this.isCollapsed,
    required this.onToggle,
    required this.expanded,
    required this.ancestorIds,
    required this.matchIds,
    required this.onTogglePerson,
    required this.onTapPerson,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eraColor(era);
    // Section roots = people in this era whose parent is NOT in
    // this era (or has no parent). Spouses-in (no parent) are
    // shown inline as chips on their husband's row, so we exclude
    // anyone who is in someone-else-in-era's spouseIds.
    final eraIds = people.map((p) => p.id).toSet();
    final indexOf = <String, int>{
      for (var i = 0; i < people.length; i++) people[i].id: i,
    };

    // "Inline spouse" = someone who married into the lineage and
    // should appear as a `═ Spouse` chip on their husband's row,
    // not as a separate section root. Two cases:
    //
    //   1. Their partner has a parent in the dataset → partner is
    //      the anchor, this person is the chip.
    //   2. Mutual no-parent pair (e.g. Adam ↔ Eve, where both
    //      reciprocate spouseIds but neither has a parent). Without
    //      a tiebreaker BOTH would be filtered → the section ends
    //      up with zero roots (the antediluvian bug). Resolve by
    //      keeping whichever person appears earlier in the dataset
    //      and filtering the other.
    bool isInlineSpouse(BiblicalPerson p) {
      if (p.fatherId != null || p.motherId != null) return false;
      for (final s in people) {
        if (s.id == p.id) continue;
        if (!s.spouseIds.contains(p.id)) continue;
        // s claims p as spouse.
        if (s.fatherId != null || s.motherId != null) {
          // s has parent → s is anchor, p is the chip.
          return true;
        }
        // Mutual no-parent pair → keep the earlier-indexed one.
        final pi = indexOf[p.id] ?? 0;
        final si = indexOf[s.id] ?? 0;
        if (pi > si) return true;
      }
      return false;
    }

    final roots = people.where((p) {
      final pid = p.fatherId ?? p.motherId;
      final hasParentInEra = pid != null && eraIds.contains(pid);
      return !hasParentInEra && !isInlineSpouse(p);
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header — collapse/expand the whole era.
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(8),
                  bottom: isCollapsed
                      ? const Radius.circular(8)
                      : Radius.zero,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCollapsed
                        ? Icons.chevron_right
                        : Icons.expand_more,
                    size: 22,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.history_edu, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _eraLabel(era, locale),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: color,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _eraSubtitle(era, locale),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${people.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final root in roots)
                    _buildSubtree(
                      root,
                      depth: 0,
                      eraIds: eraIds,
                      seen: <String>{},
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Recursively render a node's subtree, but only descend into
  /// children whose era matches this section. Each person renders
  /// at most once per section via [seen].
  Widget _buildSubtree(
    BiblicalPerson p, {
    required int depth,
    required Set<String> eraIds,
    required Set<String> seen,
  }) {
    if (!seen.add(p.id)) return const SizedBox.shrink();
    final hasKidsInEra = p.childIds.any((id) {
      if (seen.contains(id)) return false;
      return eraIds.contains(id) && svc.byId(id) != null;
    });
    final isExpanded = !hasKidsInEra
        ? false
        : (expanded.contains(p.id) || ancestorIds.contains(p.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PersonRow(
          person: p,
          depth: depth,
          locale: locale,
          scheme: scheme,
          svc: svc,
          showExpander: hasKidsInEra,
          isExpanded: isExpanded,
          isMatch: matchIds.contains(p.id),
          onToggleExpand:
              hasKidsInEra ? () => onTogglePerson(p.id) : null,
          onTap: () => onTapPerson(p),
          onTapSpouse: onTapPerson,
        ),
        if (isExpanded)
          for (final cid in p.childIds)
            if (eraIds.contains(cid))
              if (svc.byId(cid) != null)
                _buildSubtree(
                  svc.byId(cid)!,
                  depth: depth + 1,
                  eraIds: eraIds,
                  seen: seen,
                ),
      ],
    );
  }
}

// ── Person row ────────────────────────────────────────────────

class _PersonRow extends StatelessWidget {
  final BiblicalPerson person;
  final int depth;
  final String locale;
  final ColorScheme scheme;
  final FamilyTreeService svc;
  final bool showExpander;
  final bool isExpanded;
  final bool isMatch;
  final VoidCallback? onToggleExpand;
  final VoidCallback onTap;
  final void Function(BiblicalPerson) onTapSpouse;

  const _PersonRow({
    required this.person,
    required this.depth,
    required this.locale,
    required this.scheme,
    required this.svc,
    required this.showExpander,
    required this.isExpanded,
    required this.isMatch,
    required this.onToggleExpand,
    required this.onTap,
    required this.onTapSpouse,
  });

  @override
  Widget build(BuildContext context) {
    // Indent caps at depth 6; deeper rows stop sliding right.
    final clampedDepth = depth > 6 ? 6 : depth;
    final indent = clampedDepth * 14.0;
    final years = person.displayYears(locale);
    final accent = _accentTheme(person.accent);
    final accentLine = accent?.line ?? scheme.outline;
    final spouses = [for (final id in person.spouseIds) svc.byId(id)]
        .whereType<BiblicalPerson>()
        .toList();

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Material(
        color: isMatch
            ? scheme.tertiaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: accent != null
                      ? accentLine.withValues(alpha: 0.6)
                      : scheme.outlineVariant.withValues(alpha: 0.5),
                  width: accent != null ? 3 : 1.5,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: showExpander
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 30, minHeight: 30),
                          iconSize: 20,
                          icon: Icon(isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right),
                          onPressed: onToggleExpand,
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            person.localizedName(locale),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          for (final s in spouses)
                            _SpouseChip(
                              spouse: s,
                              locale: locale,
                              scheme: scheme,
                              onTap: () => onTapSpouse(s),
                            ),
                          if ((person.role ?? '').isNotEmpty)
                            _RolePill(
                              label: person.role!,
                              accent: accent,
                              scheme: scheme,
                            ),
                          if (person.refs.isNotEmpty)
                            _RefBadge(
                              count: person.refs.length,
                              scheme: scheme,
                            ),
                        ],
                      ),
                      if (years.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            years,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.62),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18,
                    color: scheme.onSurface.withValues(alpha: 0.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// ── Comparison table ──────────────────────────────────────────

class _ComparisonTable extends StatefulWidget {
  final List<BiblicalPerson> spine;
  final String locale;
  final ColorScheme scheme;
  final Set<String> matchIds;
  final List<(String, List<String>)> comparisonColumns;
  final void Function(BiblicalPerson) onTapPerson;

  const _ComparisonTable({
    required this.spine,
    required this.locale,
    required this.scheme,
    required this.matchIds,
    required this.comparisonColumns,
    required this.onTapPerson,
  });

  @override
  State<_ComparisonTable> createState() => _ComparisonTableState();
}

class _ComparisonTableState extends State<_ComparisonTable> {
  /// Collapsed by default — the table is ~50 rows tall and would
  /// otherwise dominate the page. Header stays visible so the
  /// feature is discoverable; tap to expand.
  bool _collapsed = true;

  @override
  Widget build(BuildContext context) {
    final spine = widget.spine;
    final locale = widget.locale;
    final scheme = widget.scheme;
    final matchIds = widget.matchIds;
    final comparisonColumns = widget.comparisonColumns;
    final onTapPerson = widget.onTapPerson;

    if (spine.isEmpty) return const SizedBox.shrink();

    final headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      color: scheme.onSurface.withValues(alpha: 0.85),
    );
    final cellStyle = TextStyle(
      fontSize: 12,
      color: scheme.onSurface,
    );

    Widget headerCell(String text, {double width = 70}) => Container(
          width: width,
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            border: Border(
              right: BorderSide(
                  color: scheme.outlineVariant
                      .withValues(alpha: 0.6)),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: headerStyle,
          ),
        );

    Widget bodyCell({
      required Widget child,
      double width = 70,
      bool isMatch = false,
      VoidCallback? onTap,
    }) {
      final cell = Container(
        width: width,
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMatch
              ? scheme.tertiaryContainer.withValues(alpha: 0.45)
              : null,
          border: Border(
            right: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5)),
            bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: child,
      );
      if (onTap == null) return cell;
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: cell),
      );
    }

    // Column widths — base layout that always horizontally scrolls
    // on phones (~640 px wide content). The outer LayoutBuilder
    // below expands these proportionally on iPad / desktop so the
    // table fills the available width instead of leaving a gap.
    const double baseGenW = 50;
    const double baseNameW = 130;
    const double baseYearW = 100;
    const double baseSourceW = 60;
    final baseTotal = baseGenW +
        baseNameW +
        baseYearW +
        comparisonColumns.length * baseSourceW;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tappable header — toggles the table body open/closed.
            // Header text stays visible when collapsed so the
            // feature is discoverable but not dominant.
            InkWell(
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Icon(
                      _collapsed
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      size: 22,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.table_view_rounded,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            uiStrings['familyTreeComparisonTitle']
                                    ?[locale] ??
                                'Comparison of genealogies',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: scheme.primary,
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 2),
                            child: Text(
                              uiStrings['familyTreeComparisonSubtitle']
                                      ?[locale] ??
                                  'Adam → Jesus by canonical Bible source',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${spine.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_collapsed) const SizedBox.shrink(),
            if (!_collapsed)
              // Width-adaptive: on phones (< baseTotal px) we
              // horizontally scroll. On iPad / desktop we expand
              // every column proportionally so the table fills its
              // container instead of leaving whitespace.
              LayoutBuilder(builder: (ctx, c) {
              final scale = c.maxWidth > baseTotal
                  ? c.maxWidth / baseTotal
                  : 1.0;
              final genW = baseGenW * scale;
              final nameW = baseNameW * scale;
              final yearW = baseYearW * scale;
              final sourceW = baseSourceW * scale;

              final headerRow = Row(
                children: [
                  headerCell(
                      uiStrings['familyTreeColGen']?[locale] ?? 'Gen',
                      width: genW),
                  headerCell(
                      uiStrings['familyTreeColName']?[locale] ?? 'Name',
                      width: nameW),
                  headerCell(
                      uiStrings['familyTreeColYears']?[locale] ?? 'Years',
                      width: yearW),
                  for (final col in comparisonColumns)
                    headerCell(
                        uiStrings[col.$1]?[locale] ?? col.$1,
                        width: sourceW),
                ],
              );

              final rows = <Widget>[];
              for (var i = 0; i < spine.length; i++) {
                final p = spine[i];
                final isMatch = matchIds.contains(p.id);
                final years = p.displayYears(locale);
                rows.add(Row(
                  children: [
                    bodyCell(
                      child: Text('${i + 1}',
                          style: cellStyle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface
                                .withValues(alpha: 0.55),
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          )),
                      width: genW,
                      isMatch: isMatch,
                    ),
                    bodyCell(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          p.localizedName(locale),
                          style: cellStyle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: scheme.primary
                                .withValues(alpha: 0.3),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      width: nameW,
                      isMatch: isMatch,
                      onTap: () => onTapPerson(p),
                    ),
                    bodyCell(
                      child: Text(
                        years,
                        style: cellStyle.copyWith(
                          fontSize: 10.5,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                          color: scheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      width: yearW,
                      isMatch: isMatch,
                    ),
                    for (final col in comparisonColumns)
                      bodyCell(
                        child: _hasSourceRef(p, col.$2)
                            ? Icon(Icons.check,
                                size: 16,
                                color: scheme.primary
                                    .withValues(alpha: 0.85))
                            : Text(
                                '·',
                                style: TextStyle(
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                        width: sourceW,
                        isMatch: isMatch,
                      ),
                  ],
                ));
              }

              final body = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [headerRow, ...rows],
              );

              if (scale > 1.0) {
                return body;
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: body,
              );
            }),
          ],
        ),
      ),
    );
  }

  bool _hasSourceRef(BiblicalPerson p, List<String> prefixes) {
    for (final r in p.refs) {
      for (final prefix in prefixes) {
        if (r.startsWith(prefix)) return true;
      }
    }
    return false;
  }
}

// ── Era label / colour ────────────────────────────────────────

String _eraSubtitle(String era, String locale) {
  const map = {
    'antediluvian': 'familyTreeEraSubAntediluvian',
    'post_flood': 'familyTreeEraSubPostFlood',
    'patriarchs': 'familyTreeEraSubPatriarchs',
    'mosaic': 'familyTreeEraSubMosaic',
    'davidic_line': 'familyTreeEraSubDavidic',
    'kings': 'familyTreeEraSubKings',
    'exile': 'familyTreeEraSubExile',
    'nt': 'familyTreeEraSubNt',
  };
  final key = map[era];
  if (key == null) return '';
  return uiStrings[key]?[locale] ?? '';
}

String _eraLabel(String era, String locale) {
  const labels = {
    'antediluvian': {
      'en': 'Antediluvian (Adam → Lamech)',
      'zh-Hans': '洪水之前（亚当 → 拉麦）',
      'zh-Hant': '洪水之前（亞當 → 拉麥）',
    },
    'post_flood': {
      'en': 'Post-Flood Patriarchs',
      'zh-Hans': '洪水之后的列祖',
      'zh-Hant': '洪水之後的列祖',
    },
    'patriarchs': {
      'en': 'Patriarchs of Israel',
      'zh-Hans': '以色列列祖',
      'zh-Hant': '以色列列祖',
    },
    'mosaic': {
      'en': 'Mosaic / Levitical',
      'zh-Hans': '摩西时代 / 利未支派',
      'zh-Hant': '摩西時代 / 利未支派',
    },
    'davidic_line': {
      'en': 'Pre-Monarchy / Davidic Line',
      'zh-Hans': '王朝之前 / 大卫世系',
      'zh-Hant': '王朝之前 / 大衛世系',
    },
    'kings': {
      'en': 'Kings of Judah',
      'zh-Hans': '犹大列王',
      'zh-Hant': '猶大列王',
    },
    'exile': {
      'en': 'Exile & Return',
      'zh-Hans': '被掳与回归',
      'zh-Hant': '被擄與回歸',
    },
    'nt': {
      'en': 'New Testament',
      'zh-Hans': '新约',
      'zh-Hant': '新約',
    },
  };
  return labels[era]?[locale] ?? era;
}

Color _eraColor(String era) {
  switch (era) {
    case 'antediluvian':
      return const Color(0xFF6B5E3F);
    case 'post_flood':
      return const Color(0xFF2F7C5C);
    case 'patriarchs':
      return const Color(0xFF8C5A2F);
    case 'mosaic':
      return const Color(0xFFB42E2E);
    case 'davidic_line':
      return const Color(0xFF505590);
    case 'kings':
      return const Color(0xFF2A4FB0);
    case 'exile':
      return const Color(0xFF5F3F86);
    case 'nt':
      return const Color(0xFFB8860B);
  }
  return const Color(0xFF555555);
}

// ── Accent palette / pills / badges ──────────────────────────────

class _AccentTheme {
  final Color tint;
  final Color line;
  const _AccentTheme(this.tint, this.line);
}

_AccentTheme? _accentTheme(String? accent) {
  switch (accent) {
    case 'priestly':
      return const _AccentTheme(Color(0xFFF8D7D7), Color(0xFFB42E2E));
    case 'royal':
      return const _AccentTheme(Color(0xFFD8E4F8), Color(0xFF2A4FB0));
    case 'messianic':
      return const _AccentTheme(Color(0xFFFAE6B0), Color(0xFFB8860B));
    case 'prophetic':
      return const _AccentTheme(Color(0xFFE5D7F4), Color(0xFF6B3FA0));
  }
  return null;
}

class _RolePill extends StatelessWidget {
  final String label;
  final _AccentTheme? accent;
  final ColorScheme scheme;
  const _RolePill({
    required this.label,
    required this.accent,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final fg = accent?.line ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: fg.withValues(alpha: 0.4),
          width: 0.7,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: fg,
        ),
      ),
    );
  }
}

class _SpouseChip extends StatelessWidget {
  final BiblicalPerson spouse;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _SpouseChip({
    required this.spouse,
    required this.locale,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = scheme.secondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: c.withValues(alpha: 0.4),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '═',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                spouse.localizedName(locale),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefBadge extends StatelessWidget {
  final int count;
  final ColorScheme scheme;
  const _RefBadge({required this.count, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: scheme.tertiary.withValues(alpha: 0.35),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded,
              size: 10, color: scheme.tertiary),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: scheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeData {
  final List<BiblicalPerson> all;
  final FamilyTreeService svc;
  const _TreeData({required this.all, required this.svc});
}
