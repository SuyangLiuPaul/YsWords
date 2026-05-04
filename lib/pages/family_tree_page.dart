import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/biblical_person.dart';
import 'package:yswords/services/family_tree_service.dart';
import 'package:yswords/widgets/family_visual_tree.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/person_detail_sheet.dart';

/// Browseable Bible family tree. Top of the page is a search field
/// that filters by name (any locale) or summary text. Below the
/// search is an indented expandable tree starting from canonical
/// roots (Adam + Eve in the MVP dataset). Tapping the chevron
/// expands a node to show its children inline; tapping the row body
/// opens the [PersonDetailSheet] with full info + verse refs.
class FamilyTreePage extends StatefulWidget {
  const FamilyTreePage({super.key});

  @override
  State<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends State<FamilyTreePage> {
  Future<_TreeData>? _future;
  String _query = '';
  // Persons whose children are currently visible in LIST mode.
  // Adam is opened by default so the user sees the immediate
  // descendants without having to expand first.
  final Set<String> _expanded = {'adam'};

  // Display mode. Tree = visual descendant chart with focus reframe.
  // List = the indented expandable outline (the round-56 default).
  // Tree is now the default because it makes the lineage immediately
  // legible; list stays available as a fallback for deep linear
  // browsing or for users who prefer outline-style data.
  _ViewMode _viewMode = _ViewMode.tree;

  // Current focus person in tree mode. Defaults to Adam (the root
  // of the dataset). Tapping a non-focus card sets a new focus and
  // rebuilds the chart; the breadcrumb keeps the trail back to Adam
  // so the user always knows where they are.
  String _treeFocusId = 'adam';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TreeData> _load() async {
    final svc = FamilyTreeService.instance;
    final all = await svc.loadAll();
    final roots = await svc.roots();
    return _TreeData(all: all, roots: roots);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['familyTree']?[locale] ?? 'Family Tree'),
        actions: [
          // Tree / List toggle. Single icon flips between modes; the
          // tooltip describes the OTHER mode (the one tapping will
          // switch you to) — that's the standard pattern for a
          // mode-flip control. The toggle sits in the AppBar where
          // the user can find it without scrolling.
          IconButton(
            icon: Icon(_viewMode == _ViewMode.tree
                ? Icons.list_alt_rounded
                : Icons.account_tree_outlined),
            tooltip: _viewMode == _ViewMode.tree
                ? (uiStrings['familyTreeViewList']?[locale] ?? 'List view')
                : (uiStrings['familyTreeViewChart']?[locale] ?? 'Chart view'),
            onPressed: () => setState(() {
              _viewMode = _viewMode == _ViewMode.tree
                  ? _ViewMode.list
                  : _ViewMode.tree;
            }),
          ),
          const HomeIconButton(),
        ],
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
              : _filtered(data.all, _query.trim(), locale);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: uiStrings['familyTreeSearchHint']?[locale] ??
                        'Search by name or biography…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      _summary(
                        all: data.all,
                        filtered: filtered,
                        locale: locale,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // Tree mode handles search inline (auto-expands
                // ancestor paths to every match). List mode doesn't
                // do path-expansion so it falls back to the flat
                // search-results panel.
                child: _viewMode == _ViewMode.tree
                    ? _buildChart(data, locale, scheme, _query)
                    : (filtered != null
                        ? _buildSearchResults(filtered, locale, scheme)
                        : _buildListMode(data, locale, scheme)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Filter ────────────────────────────────────────────────────────

  /// Plain substring match across all locales' name + summary +
  /// English id (so power users can grep "manasseh" in any locale).
  /// Returns `null` to mean "no filter active" upstream.
  List<BiblicalPerson> _filtered(
      List<BiblicalPerson> all, String query, String locale) {
    final q = sanitizeForSearch(query).toLowerCase();
    return all.where((p) {
      final hay = [
        p.name,
        p.nameZhHans ?? '',
        p.nameZhHant ?? '',
        p.id,
        p.summary,
        p.summaryZhHans ?? '',
        p.summaryZhHant ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  String _summary({
    required List<BiblicalPerson> all,
    required List<BiblicalPerson>? filtered,
    required String locale,
  }) {
    if (filtered != null) {
      final tmpl = uiStrings['familyTreeFilterCount']?[locale];
      if (tmpl != null) {
        return tmpl
            .replaceAll('{count}', filtered.length.toString())
            .replaceAll('{total}', all.length.toString());
      }
      return '${filtered.length} of ${all.length} people';
    }
    final tmpl = uiStrings['familyTreeTotalCount']?[locale];
    if (tmpl != null) {
      return tmpl.replaceAll('{total}', all.length.toString());
    }
    return '${all.length} people';
  }

  /// Tree mode body — the round-59 visual tree. Renders top-down
  /// from the dataset root (Adam) as a vertical generational
  /// cascade. The spine path stays as a single column of large
  /// cards connected by short vertical lines; off-spine siblings
  /// of each spine member render as compact chips just above their
  /// generation (with a "+N" badge when they have children of their
  /// own); the focus's own children fan out below the focus card.
  /// Pinch-zoom and pan via InteractiveViewer make it usable on
  /// small screens for the deep canonical lineage.
  Widget _buildChart(
      _TreeData data, String locale, ColorScheme scheme, String query) {
    final svc = FamilyTreeService.instance;
    final root = data.roots.isNotEmpty ? data.roots.first : null;
    if (root == null) return const SizedBox.shrink();
    final focus = svc.byId(_treeFocusId) ?? root;
    return FamilyVisualTree(
      root: root,
      focus: focus,
      locale: locale,
      query: query,
      onPersonTap: _showDetail,
      onRefocus: (p) => setState(() => _treeFocusId = p.id),
    );
  }

  /// List (outline) mode body. Same indented expandable tree the
  /// page used to render exclusively — kept as the alternative view
  /// for users who prefer outline-style data or want to scroll
  /// through long unbroken lineages.
  Widget _buildListMode(
      _TreeData data, String locale, ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        for (final root in data.roots)
          _buildNode(root, depth: 0, locale: locale, scheme: scheme),
      ],
    );
  }

  Widget _buildSearchResults(
      List<BiblicalPerson> rows, String locale, ColorScheme scheme) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            uiStrings['familyTreeNoMatches']?[locale] ??
                'No one matches that search.',
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _buildPersonRow(
        rows[i],
        depth: 0,
        locale: locale,
        scheme: scheme,
        showExpander: false,
      ),
    );
  }

  // ── Tree node ─────────────────────────────────────────────────────

  /// Recursive node builder. Renders the person row + (when
  /// expanded) inlined child nodes one indent deeper. Indent caps at
  /// 6 levels so deeply nested kings (David → Solomon → Rehoboam → …)
  /// don't slide off the right edge — beyond that we keep adding
  /// rows but stop indenting further.
  Widget _buildNode(
    BiblicalPerson p, {
    required int depth,
    required String locale,
    required ColorScheme scheme,
  }) {
    final isExpanded = _expanded.contains(p.id);
    final hasKids = p.childIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPersonRow(
          p,
          depth: depth,
          locale: locale,
          scheme: scheme,
          showExpander: hasKids,
          isExpanded: isExpanded,
          onToggleExpand: hasKids
              ? () => setState(() {
                    if (isExpanded) {
                      _expanded.remove(p.id);
                    } else {
                      _expanded.add(p.id);
                    }
                  })
              : null,
        ),
        if (isExpanded && hasKids)
          for (final child in _resolvedChildren(p))
            _buildNode(child,
                depth: (depth + 1).clamp(0, 6),
                locale: locale,
                scheme: scheme),
      ],
    );
  }

  List<BiblicalPerson> _resolvedChildren(BiblicalPerson p) {
    final svc = FamilyTreeService.instance;
    return [for (final id in p.childIds) svc.byId(id)].whereType<BiblicalPerson>().toList();
  }

  Widget _buildPersonRow(
    BiblicalPerson p, {
    required int depth,
    required String locale,
    required ColorScheme scheme,
    required bool showExpander,
    bool isExpanded = false,
    VoidCallback? onToggleExpand,
  }) {
    final indent = depth * 14.0;
    final years = p.displayYears(locale);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetail(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: showExpander
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 18,
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
                      Text(
                        p.localizedName(locale),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (years.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            years,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.6),
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
            // Expand path so the navigated-to person is visible in
            // LIST mode, and refocus the chart so TREE mode lands on
            // the new person too. Both states stay coherent
            // regardless of which mode the user is in.
            setState(() {
              if (other.fatherId != null) _expanded.add(other.fatherId!);
              if (other.motherId != null) _expanded.add(other.motherId!);
              _expanded.add(other.id);
              _treeFocusId = other.id;
            });
            _showDetail(other);
          },
        ),
      ),
    );
  }
}

class _TreeData {
  final List<BiblicalPerson> all;
  final List<BiblicalPerson> roots;
  const _TreeData({required this.all, required this.roots});
}

/// Display mode for the page body. Controlled by the AppBar toggle.
enum _ViewMode { tree, list }
