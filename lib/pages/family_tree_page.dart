import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/biblical_person.dart';
import 'package:yswords/services/family_tree_service.dart';
import 'package:yswords/utils/biblical_role.dart' show localizedRole;
import 'package:yswords/utils/theme_color_helpers.dart';
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
  late final ScrollController _scrollController;

  /// Persons whose children rows are visible. Search auto-unions
  /// in ancestor chains so matches are revealed in context.
  final Set<String> _expanded = {};

  /// Era keys that are currently collapsed. Default state is "all
  /// sections collapsed" so the page opens as a clean TOC view of
  /// 8 era headers + comparison table — the user clicks into the
  /// era they're interested in. Once a section is opened, every
  /// person inside is rendered in full (see `_load`).
  final Set<String> _collapsedEras = {};

  /// Per-era anchor keys so the bridge chips at the end of one
  /// section can `Scrollable.ensureVisible` the next section into
  /// view when tapped.
  final Map<String, GlobalKey> _eraKeys = {};

  /// Per-person row keys, populated lazily as rows render. Used so
  /// a bridge-leaf tap can scroll *the destination person's row*
  /// into view (not just the section header) and so we can
  /// highlight that row with a flash for a few seconds.
  final Map<String, GlobalKey> _personKeys = {};

  /// Person id currently being flashed as "you just jumped here".
  /// Cleared by [_highlightTimer] after [_kHighlightDuration].
  String? _recentlyJumpedTo;
  Timer? _highlightTimer;
  static const Duration _kHighlightDuration = Duration(seconds: 3);

  /// Bridge map: "at the end of era X, link to person Y (and Z) who
  /// continues the lineage in the next era." Drives the
  /// "Continues with: …" footer row inside each expanded section.
  /// Mosaic and NT are dead-ends (no canonical continuation), so
  /// their lists are empty.
  static const Map<String, List<String>> _eraBridges = {
    'antediluvian': ['noah'],
    'post_flood': ['abraham'],
    'patriarchs': ['kohath', 'perez'],
    'mosaic': [],
    'davidic_line': ['david'],
    // Kings era bridges to BOTH Matthew's exile chain (via
    // Shealtiel, son of Jeconiah) and Luke's Lukan Lineage (via
    // Mattatha, descendant of Nathan son of David).
    'kings': ['shealtiel', 'mattatha_lk_31'],
    'exile': ['joseph_father_of_jesus'],
    'lukan_lineage': ['mary'],
    'nt': [],
  };

  /// Canonical era ordering — drives the order of section blocks.
  static const List<String> _eraOrder = [
    'antediluvian',
    'post_flood',
    'patriarchs',
    'mosaic',
    'davidic_line',
    'kings',
    'exile',
    'lukan_lineage',
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
    _scrollController = ScrollController();
    // Default-collapse every section. User opens what they're
    // interested in; a search match auto-uncollapses its section.
    _collapsedEras.addAll(_eraOrder);
    for (final e in _eraOrder) {
      _eraKeys[e] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _personKeyFor(String id) =>
      _personKeys.putIfAbsent(id, () => GlobalKey());

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

  /// Tiered relevance search. Returns only the **best non-empty
  /// tier** of matches so a search for "Jesus" returns just Jesus
  /// (exact name match) rather than every ancestor whose summary
  /// happens to mention Him.
  ///
  /// Tiers, in priority order:
  ///   1. Exact name match (any of en / zh-Hans / zh-Hant)
  ///   2. Name starts with
  ///   3. Name contains
  ///   4. Role contains (e.g. "PATRIARCH" → all patriarchs)
  ///   5. Summary contains (catch-all — only used if all earlier
  ///      tiers are empty)
  ///
  /// Within a tier, results are sorted by canonical era order so
  /// the user sees the chronological flow (Adam first, NT last).
  List<BiblicalPerson> _filtered(
      List<BiblicalPerson> all, String query) {
    final q = sanitizeForSearch(query).toLowerCase();
    if (q.isEmpty) return const [];

    int eraIndexOf(BiblicalPerson p) {
      final i = _eraOrder.indexOf(p.era ?? '');
      return i < 0 ? _eraOrder.length : i;
    }

    final tiers = <int, List<BiblicalPerson>>{};
    void addTier(int tier, BiblicalPerson p) {
      tiers.putIfAbsent(tier, () => <BiblicalPerson>[]).add(p);
    }

    for (final p in all) {
      final names = <String>[
        p.name.toLowerCase(),
        (p.nameZhHans ?? '').toLowerCase(),
        (p.nameZhHant ?? '').toLowerCase(),
      ];
      final role = (p.role ?? '').toLowerCase();
      final summary = [
        p.summary,
        p.summaryZhHans ?? '',
        p.summaryZhHant ?? '',
      ].join(' ').toLowerCase();

      if (names.any((n) => n.isNotEmpty && n == q)) {
        addTier(1, p);
      } else if (names.any((n) => n.startsWith(q))) {
        addTier(2, p);
      } else if (names.any((n) => n.contains(q))) {
        addTier(3, p);
      } else if (role.isNotEmpty && role.contains(q)) {
        addTier(4, p);
      } else if (summary.contains(q)) {
        addTier(5, p);
      }
    }

    // Aggregation rules:
    //   • If ANY name match (tiers 1-3): return all name matches.
    //     "Joseph" → 4 results (tribe + father of Jesus + 2 Lukan
    //     Josephs); "Jesus" → 1 result (only Jesus exactly).
    //   • Otherwise role matches (tier 4) — e.g. "PATRIARCH"
    //     surfaces every patriarch.
    //   • Otherwise summary matches (tier 5) as a last-resort
    //     catch-all so users can find people by topic keywords.
    List<BiblicalPerson> sortByEra(List<BiblicalPerson> xs) {
      xs.sort((a, b) => eraIndexOf(a).compareTo(eraIndexOf(b)));
      return xs;
    }

    final nameHits = <BiblicalPerson>[
      for (final t in [1, 2, 3])
        if (tiers.containsKey(t)) ...tiers[t]!,
    ];
    if (nameHits.isNotEmpty) return sortByEra(nameHits);
    if (tiers.containsKey(4)) return sortByEra(tiers[4]!);
    if (tiers.containsKey(5)) return sortByEra(tiers[5]!);
    return const [];
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
                // 2026-05-10 (v1.2.21): localised — was hardcoded
                // English. Reuses `loadErrorTitle` ui-string that
                // LoadingPage's error scaffold already uses, with
                // the raw error suffixed for diagnostics.
                child: Text(
                  '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}: ${snap.error}',
                  style: TextStyle(color: scheme.error),
                ),
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
                    // Search-active: show a clean flat search-results
                    // list instead of the article. Tapping a result
                    // clears the query and jumps to that person in
                    // their era's section. This is what the user
                    // asked for — search should "just show the one"
                    // matched person, not auto-expand the whole
                    // article inline.
                    child: filtered == null
                        ? _buildArticle(
                            data: data,
                            byEra: byEra,
                            spine: spine,
                            matchIds: matchIds,
                            ancestorIds: ancestorIds,
                            locale: locale,
                            scheme: scheme,
                          )
                        : filtered.isEmpty
                            ? _buildNoMatches(locale, scheme)
                            : _buildSearchResults(
                                matches: filtered,
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

  // ── Search results panel ────────────────────────────────────────

  /// Flat list of matched persons shown WHILE search is active.
  /// Replaces the article body so the user sees only the matches —
  /// addresses the "search shows nothing useful" report. Tapping a
  /// result clears the query and jumps to that person's row in the
  /// era's section (which auto-uncollapses).
  Widget _buildSearchResults({
    required List<BiblicalPerson> matches,
    required String locale,
    required ColorScheme scheme,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: matches.length,
      itemBuilder: (_, i) => _SearchResultTile(
        person: matches[i],
        locale: locale,
        scheme: scheme,
        onTap: () {
          final p = matches[i];
          // Clear the query so the article body comes back, then
          // post-frame jump to this person's row + flash highlight.
          _searchController.clear();
          setState(() => _query = '');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final era = p.era;
            if (era != null && era.isNotEmpty) {
              _jumpToEra(era, personId: p.id);
            } else {
              _showDetail(p);
            }
          });
        },
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
      // Resolve bridge people to objects for the "continues with"
      // footer chips. Bridges may live in a different era than the
      // current one (that's the whole point — they link forward).
      final bridges = <BiblicalPerson>[];
      final bridgeIds = _eraBridges[era] ?? const <String>[];
      for (final bid in bridgeIds) {
        final bp = data.svc.byId(bid);
        if (bp != null) bridges.add(bp);
      }
      sections.add(KeyedSubtree(
        key: _eraKeys[era],
        child: _EraSection(
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
          bridges: bridges,
          onJumpToEra: _jumpToEra,
          onJumpToSpouse: _jumpToSpouse,
          recentlyJumpedTo: _recentlyJumpedTo,
          personKeyFor: _personKeyFor,
        ),
      ));
    }

    return ListView(
      controller: _scrollController,
      // Force every section to be laid out eagerly (instead of
      // lazily as items scroll into view). Without this, sections
      // below the viewport don't have a settled RenderBox, so
      // their GlobalKey.currentContext is null and bridge jumps
      // (e.g. Patriarchs → Lukan Lineage) silently no-op with a
      // "no context for lukan_lineage / mattatha_lk_31" debug.
      // We only have 9 list items (8 sections + comparison table)
      // so the memory cost is trivial.
      // v1.3.95 (Flutter 3.44): dropped the deprecated `cacheExtent:
      // double.infinity` (its replacement now takes a ScrollCacheExtent
      // object). Only 9 items here, so the default cache extent is fine.
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

  /// Bridge-chip / bridge-leaf tap handler. Uncollapses the target
  /// era, scrolls the destination's row into view, and flashes
  /// the destination person with a temporary highlight tint so the
  /// user gets unambiguous "you landed here" feedback.
  ///
  /// Uses an explicit [ScrollController.animateTo] with offset
  /// computed from `RenderAbstractViewport.getOffsetToReveal` —
  /// this is more reliable across Flutter web than the older
  /// `Scrollable.ensureVisible` path, which had a timing bug where
  /// jumps to deeper sections (Perez → Davidic Line, Kohath under
  /// Levi) would silently no-op while jumps to closer sections
  /// (Kohath via the bridge footer chip) happened to fire.
  void _jumpToEra(String era, {String? personId}) {
    setState(() {
      _collapsedEras.remove(era);
      _recentlyJumpedTo = personId;
    });

    _highlightTimer?.cancel();
    if (personId != null) {
      _highlightTimer = Timer(_kHighlightDuration, () {
        if (!mounted) return;
        setState(() => _recentlyJumpedTo = null);
      });
    }

    // The diagnostic SnackBar that fires post-scroll covers both
    // "tap reached us" and "scroll succeeded" feedback in one
    // message, so we don't need a separate immediate one here.

    // Aggressive deferral chain: postFrame → postFrame → 250 ms.
    // Layout for a 40-row Lukan Lineage body completes well
    // within this on phones, so the destination row's RenderBox
    // always has a settled non-zero position before we measure.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          _scrollToTarget(era: era, personId: personId);
        });
      });
    });
  }

  /// Spouse-chip tap handler. If the spouse has an era assigned,
  /// jump-and-highlight their row in that era's section. Otherwise
  /// fall back to opening the detail sheet (for orphan spouses
  /// without era data — rare in our dataset).
  void _jumpToSpouse(BiblicalPerson s) {
    final era = s.era;
    if (era != null && era.isNotEmpty) {
      _jumpToEra(era, personId: s.id);
    } else {
      _showDetail(s);
    }
  }

  void _scrollToTarget({required String era, String? personId}) {
    if (!_scrollController.hasClients) return;
    BuildContext? ctx;
    if (personId != null) {
      ctx = _personKeys[personId]?.currentContext;
    }
    ctx ??= _eraKeys[era]?.currentContext;
    if (ctx == null) {
      // Diagnostic SnackBar so the user knows the tap fired but
      // the destination context wasn't ready.
      _showJumpDebug('no context for $era / $personId');
      return;
    }
    final box = ctx.findRenderObject();
    if (box is! RenderBox) {
      _showJumpDebug('no RenderBox for $era / $personId');
      return;
    }
    final viewport = RenderAbstractViewport.of(box);
    final reveal = viewport.getOffsetToReveal(box, 0.05);
    final position = _scrollController.position;
    final raw = reveal.offset;
    final clamped = raw.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final wasAt = position.pixels;
    _scrollController.jumpTo(clamped);
    _showJumpDebug(
        'jumped: was=${wasAt.toInt()} → ${clamped.toInt()} (raw=${raw.toInt()})');
  }

  /// Show a debug SnackBar describing what the jump did. Helps
  /// pinpoint whether the issue is missing context, missing render
  /// box, wrong offset, or no scrolling at all.
  void _showJumpDebug(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 11)),
      duration: const Duration(milliseconds: 2400),
      behavior: SnackBarBehavior.floating,
    ));
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
  final List<BiblicalPerson> bridges;
  final void Function(String era, {String? personId}) onJumpToEra;
  final void Function(BiblicalPerson) onJumpToSpouse;
  final String? recentlyJumpedTo;
  final GlobalKey Function(String id) personKeyFor;

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
    required this.bridges,
    required this.onJumpToEra,
    required this.onJumpToSpouse,
    required this.recentlyJumpedTo,
    required this.personKeyFor,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eraColor(era);
    // 2026-05-10 (v1.2.36): brightness-aware era foreground used
    // for the era title text + the chevron / history_edu icons +
    // the people-count badge. Backgrounds (gradient + alpha-15
    // badge fill + alpha-30 border) keep the raw deep era hue.
    final fg = _eraColorOn(Theme.of(context).brightness, era);
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
                    color: fg,
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.history_edu, size: 16, color: fg),
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
                            color: fg,
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
                        color: fg,
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
                  if (bridges.isNotEmpty)
                    _BridgeFooter(
                      bridges: bridges,
                      locale: locale,
                      scheme: scheme,
                      eraColor: color,
                      onTapBridge: (target) {
                        // Tap = jump only. Pass the person id so
                        // the destination row gets a flash highlight
                        // and the scroll lands on the row, not just
                        // the section header.
                        final targetEra = target.era;
                        if (targetEra != null) {
                          onJumpToEra(targetEra, personId: target.id);
                        }
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Recursively render a node's subtree. In-era children expand
  /// recursively (full subtree); **cross-era** children render as
  /// "bridge leaves" — single-row markers with a `→ {next era}`
  /// indicator that tap-jumps the user to that next section. So
  /// the user sees Lamech → Noah (→ Post-Flood) inside the
  /// Antediluvian section, instead of the chain abruptly ending
  /// at Lamech.
  Widget _buildSubtree(
    BiblicalPerson p, {
    required int depth,
    required Set<String> eraIds,
    required Set<String> seen,
  }) {
    if (!seen.add(p.id)) return const SizedBox.shrink();

    final allKids = <BiblicalPerson>[];
    final inEraKids = <BiblicalPerson>[];
    final crossEraKids = <BiblicalPerson>[];
    for (final cid in p.childIds) {
      final c = svc.byId(cid);
      if (c == null) continue;
      allKids.add(c);
      if (eraIds.contains(cid)) {
        if (!seen.contains(cid)) inEraKids.add(c);
      } else if ((c.era ?? '').isNotEmpty) {
        crossEraKids.add(c);
      }
    }
    final hasAnyKids =
        inEraKids.isNotEmpty || crossEraKids.isNotEmpty;
    final isExpanded = !hasAnyKids
        ? false
        : (expanded.contains(p.id) || ancestorIds.contains(p.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          // Per-person key so _jumpToEra(..., personId: ...) can
          // scroll directly to this row and the flash-highlight
          // can re-target on each rebuild.
          key: personKeyFor(p.id),
          child: _PersonRow(
            person: p,
            depth: depth,
            locale: locale,
            scheme: scheme,
            svc: svc,
            showExpander: hasAnyKids,
            isExpanded: isExpanded,
            isMatch: matchIds.contains(p.id),
            isRecentlyJumped: recentlyJumpedTo == p.id,
            onToggleExpand:
                hasAnyKids ? () => onTogglePerson(p.id) : null,
            // Tap row body = expand/collapse children when this
            // person has any. For leaf nodes (no kids) tap falls
            // back to opening the detail sheet so the action isn't
            // a no-op.
            onTap: hasAnyKids
                ? () => onTogglePerson(p.id)
                : () => onTapPerson(p),
            onOpenDetail: () => onTapPerson(p),
            onTapSpouse: onTapPerson,
            onJumpToSpouse: onJumpToSpouse,
          ),
        ),
        if (isExpanded) ...[
          for (final c in inEraKids)
            _buildSubtree(
              c,
              depth: depth + 1,
              eraIds: eraIds,
              seen: seen,
            ),
          for (final c in crossEraKids)
            _BridgeLeafRow(
              person: c,
              depth: depth + 1,
              locale: locale,
              scheme: scheme,
              svc: svc,
              onTapPerson: onTapPerson,
              onJumpToEra: onJumpToEra,
              isRecentlyJumped: recentlyJumpedTo == c.id,
            ),
        ],
      ],
    );
  }
}

// ── Bridge footer ──────────────────────────────────────────────

/// "Continues with: [Person] [Person]" footer at the bottom of an
/// expanded era section. Each person chip is tappable — tap to
/// uncollapse + scroll to whichever section they live in (the next
/// era in canonical order) and open the detail sheet for them.
class _BridgeFooter extends StatelessWidget {
  final List<BiblicalPerson> bridges;
  final String locale;
  final ColorScheme scheme;
  final Color eraColor;
  final void Function(BiblicalPerson) onTapBridge;

  const _BridgeFooter({
    required this.bridges,
    required this.locale,
    required this.scheme,
    required this.eraColor,
    required this.onTapBridge,
  });

  @override
  Widget build(BuildContext context) {
    // 2026-05-10 (v1.2.36): brightness-aware foreground for the
    // "Continues with" icon + label so it stays readable on the
    // dark theme. The translucent backdrop + border keeps the raw
    // era hue.
    final fg = _readableEraFg(context, eraColor);
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: eraColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: eraColor.withValues(alpha: 0.3),
          width: 0.7,
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Icon(Icons.east_rounded, size: 14, color: fg),
          const SizedBox(width: 2),
          Text(
            uiStrings['familyTreeContinuesWith']?[locale] ??
                'Continues with',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: fg,
            ),
          ),
          for (final p in bridges)
            _BridgeChip(
              person: p,
              locale: locale,
              scheme: scheme,
              eraColor: eraColor,
              onTap: () => onTapBridge(p),
            ),
        ],
      ),
    );
  }
}

/// 2026-05-10 (v1.2.36): brightness-aware foreground colour for
/// era-tinted text/icons. The widgets that receive `eraColor` as a
/// constructor parameter (rather than the era key) call this helper
/// to derive a readable variant for the current theme. Mirrors
/// `_eraColorOn(brightness, era)` but operates on a pre-resolved
/// `Color`.
Color _readableEraFg(BuildContext context, Color eraColor) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return Color.lerp(eraColor, Colors.white, 0.45) ?? eraColor;
  }
  return eraColor;
}

class _BridgeChip extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final Color eraColor;
  final VoidCallback onTap;

  const _BridgeChip({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.eraColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _readableEraFg(context, eraColor);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: eraColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: eraColor.withValues(alpha: 0.5),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_pin_rounded,
                  size: 11, color: fg),
              const SizedBox(width: 3),
              Text(
                person.localizedName(locale),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
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
  final bool isRecentlyJumped;
  final VoidCallback? onToggleExpand;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;
  final void Function(BiblicalPerson) onTapSpouse;
  final void Function(BiblicalPerson) onJumpToSpouse;

  const _PersonRow({
    required this.person,
    required this.depth,
    required this.locale,
    required this.scheme,
    required this.svc,
    required this.showExpander,
    required this.isExpanded,
    required this.isMatch,
    required this.isRecentlyJumped,
    required this.onToggleExpand,
    required this.onTap,
    required this.onOpenDetail,
    required this.onTapSpouse,
    required this.onJumpToSpouse,
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
      // Static (non-animated) highlight wrapper. We tried
      // AnimatedContainer here but the 320 ms animation could
      // shift the row's RenderBox during scroll-offset
      // measurement, making the jump land at a stale offset.
      // Switching to a static Container keeps the highlight
      // visible (just no fade-in) and the layout deterministic.
      child: Container(
        decoration: BoxDecoration(
          color: isRecentlyJumped
              ? scheme.primaryContainer.withValues(alpha: 0.7)
              : isMatch
                  ? scheme.tertiaryContainer.withValues(alpha: 0.45)
                  : Colors.transparent,
          border: isRecentlyJumped
              ? Border.all(
                  color: scheme.primary.withValues(alpha: 0.6),
                  width: 1.5,
                )
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Material(
          color: Colors.transparent,
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
                              // Tap a spouse chip → jump to that
                              // person's row in their own era
                              // section (so e.g. Mary on Joseph's
                              // row jumps to Mary in NT section).
                              // Falls back to detail sheet if the
                              // spouse has no era to jump to.
                              onTap: () => onJumpToSpouse(s),
                            ),
                          if ((person.role ?? '').isNotEmpty)
                            _RolePill(
                              label: person.role!,
                              accent: accent,
                              scheme: scheme,
                              locale: locale,
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
                // Info button — explicit, discoverable path to the
                // detail sheet. Tap row body = expand/collapse.
                // Tap this little box = open popup. Matches the
                // human-natural pattern the user asked for.
                _RowInfoButton(
                  scheme: scheme,
                  onPressed: onOpenDetail,
                  locale: locale,
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

}

class _SearchResultTile extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentTheme(person.accent);
    final accentColor = accent?.line ?? scheme.primary;
    final years = person.displayYears(locale);
    final era = person.era ?? '';
    final eraColor = _eraColor(era);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          // Era pill in the era's colour.
                          if (era.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color:
                                    eraColor.withValues(alpha: 0.13),
                                borderRadius:
                                    BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      eraColor.withValues(alpha: 0.4),
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                _eraLabelShort(era, locale),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  // v1.2.36: brightness-aware fg
                                  color: _readableEraFg(
                                      context, eraColor),
                                ),
                              ),
                            ),
                          if ((person.role ?? '').isNotEmpty)
                            _RolePill(
                              label: person.role!,
                              accent: accent,
                              scheme: scheme,
                              locale: locale,
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
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            years,
                            style: TextStyle(
                              fontSize: 12,
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
                Icon(Icons.east_rounded,
                    size: 18, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowInfoButton extends StatelessWidget {
  final ColorScheme scheme;
  final VoidCallback onPressed;
  final String locale;
  const _RowInfoButton({
    required this.scheme,
    required this.onPressed,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: uiStrings['familyTreeOpenDetails']?[locale] ?? 'Details',
      child: InkResponse(
        onTap: onPressed,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: scheme.primary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

// ── Bridge leaf row ──────────────────────────────────────────

/// A single-row marker rendered inside a parent section to surface
/// children whose era is different from the section's era. Shows
/// the person + their spouses inline + a trailing `→ {next era}`
/// tag. Tapping the row jumps to the target era's section AND
/// opens the detail sheet for that person.
class _BridgeLeafRow extends StatelessWidget {
  final BiblicalPerson person;
  final int depth;
  final String locale;
  final ColorScheme scheme;
  final FamilyTreeService svc;
  final void Function(BiblicalPerson) onTapPerson;
  final void Function(String era, {String? personId}) onJumpToEra;
  final bool isRecentlyJumped;

  const _BridgeLeafRow({
    required this.person,
    required this.depth,
    required this.locale,
    required this.scheme,
    required this.svc,
    required this.onTapPerson,
    required this.onJumpToEra,
    required this.isRecentlyJumped,
  });

  @override
  Widget build(BuildContext context) {
    final clampedDepth = depth > 6 ? 6 : depth;
    final indent = clampedDepth * 14.0;
    final years = person.displayYears(locale);
    final accent = _accentTheme(person.accent);
    final accentLine = accent?.line ?? scheme.outline;
    final spouses = [for (final id in person.spouseIds) svc.byId(id)]
        .whereType<BiblicalPerson>()
        .toList();
    final targetEra = person.era ?? '';
    final targetEraColor = _eraColor(targetEra);

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Material(
        color: targetEraColor.withValues(alpha: 0.04),
        child: InkWell(
          // Tap = jump only. Opening the detail sheet here would
          // cover the scroll animation and make the jump feel like
          // it didn't fire. The trailing ⓘ button opens the
          // detail sheet without jumping.
          onTap: () {
            if (targetEra.isNotEmpty) {
              onJumpToEra(targetEra, personId: person.id);
            }
          },
          onLongPress: () => onTapPerson(person),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: accent != null
                      ? accentLine.withValues(alpha: 0.55)
                      : targetEraColor.withValues(alpha: 0.55),
                  width: accent != null ? 3 : 2,
                ),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                // Same width as the chevron column on a regular row,
                // for vertical alignment with siblings.
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 16,
                      color:
                          scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
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
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          for (final s in spouses)
                            _SpouseChip(
                              spouse: s,
                              locale: locale,
                              scheme: scheme,
                              onTap: () => onTapPerson(s),
                            ),
                          if ((person.role ?? '').isNotEmpty)
                            _RolePill(
                              label: person.role!,
                              accent: accent,
                              scheme: scheme,
                              locale: locale,
                            ),
                          // The trailing "→ {next era}" tag. This
                          // is the visual cue that the lineage
                          // continues in another section.
                          _NextEraTag(
                            targetEra: targetEra,
                            targetEraColor: targetEraColor,
                            locale: locale,
                          ),
                        ],
                      ),
                      if (years.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            years,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.55),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.east_rounded,
                    size: 16,
                    // v1.2.36: brightness-aware fg
                    color: _readableEraFg(context, targetEraColor)),
                // Info button — opens detail without jumping. Tap
                // row body = jump to next era; this little box =
                // peek at details first.
                _RowInfoButton(
                  scheme: scheme,
                  onPressed: () => onTapPerson(person),
                  locale: locale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextEraTag extends StatelessWidget {
  final String targetEra;
  final Color targetEraColor;
  final String locale;
  const _NextEraTag({
    required this.targetEra,
    required this.targetEraColor,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _readableEraFg(context, targetEraColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: targetEraColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: targetEraColor.withValues(alpha: 0.5),
          width: 0.7,
        ),
      ),
      child: Text(
        '→ ${_eraLabelShort(targetEra, locale)}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}

/// Shorter, single-word labels for the trailing era tag (so the
/// row stays compact when wrapped). Falls back to the full era
/// label when no short form is registered.
String _eraLabelShort(String era, String locale) {
  const labels = {
    'antediluvian': {'en': 'Antediluvian', 'zh-Hans': '洪水之前', 'zh-Hant': '洪水之前'},
    'post_flood': {'en': 'Post-Flood', 'zh-Hans': '洪水之后', 'zh-Hant': '洪水之後'},
    'patriarchs': {'en': 'Patriarchs', 'zh-Hans': '列祖', 'zh-Hant': '列祖'},
    'mosaic': {'en': 'Mosaic', 'zh-Hans': '摩西时代', 'zh-Hant': '摩西時代'},
    'davidic_line': {'en': 'Davidic Line', 'zh-Hans': '大卫世系', 'zh-Hant': '大衛世系'},
    'kings': {'en': 'Kings', 'zh-Hans': '列王', 'zh-Hant': '列王'},
    'exile': {'en': 'Exile', 'zh-Hans': '被掳', 'zh-Hant': '被擄'},
    'lukan_lineage': {'en': 'Lukan', 'zh-Hans': '路加家谱', 'zh-Hant': '路加家譜'},
    'nt': {'en': 'NT', 'zh-Hans': '新约', 'zh-Hant': '新約'},
  };
  return labels[era]?[locale] ?? _eraLabel(era, locale);
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
                    // Copy-table button: copies the entire
                    // comparison table as a tab-separated text
                    // payload that pastes cleanly into Excel /
                    // Sheets / Numbers / Notion. Tap stops
                    // bubbling so the header's expand/collapse
                    // toggle isn't fired at the same time.
                    _ComparisonCopyButton(
                      spine: spine,
                      comparisonColumns: comparisonColumns,
                      locale: locale,
                      scheme: scheme,
                    ),
                    const SizedBox(width: 4),
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
    'lukan_lineage': 'familyTreeEraSubLukan',
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
    'lukan_lineage': {
      'en': "Lukan Lineage (Mary's line through Nathan)",
      'zh-Hans': '路加家谱（马利亚透过拿单的世系）',
      'zh-Hant': '路加家譜（馬利亞透過拿單的世系）',
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
    case 'lukan_lineage':
      return const Color(0xFF8B3A62);
    case 'nt':
      return const Color(0xFFB8860B);
  }
  return const Color(0xFF555555);
}

/// 2026-05-10 (v1.2.36): brightness-aware variant of `_eraColor`.
/// Mirror of the helper added in `bible_timeline_page.dart` for the
/// same reason — the palette above is tuned for light surfaces and
/// fades into the dark theme's `#121212`-ish surface, making era
/// titles ("Patriarchs / Mosaic / …") hard to read in dark mode.
/// `Color.lerp(c, Colors.white, 0.45)` keeps the era's hue (so
/// colour-coding still works) while pushing the value high enough
/// to clear contrast against a dark surface.
Color _eraColorOn(Brightness brightness, String era) {
  final base = _eraColor(era);
  if (brightness == Brightness.dark) {
    return Color.lerp(base, Colors.white, 0.45) ?? base;
  }
  return base;
}

// ── Comparison-table copy button + floating toast ────────────────

class _ComparisonCopyButton extends StatefulWidget {
  final List<BiblicalPerson> spine;
  final List<(String, List<String>)> comparisonColumns;
  final String locale;
  final ColorScheme scheme;
  const _ComparisonCopyButton({
    required this.spine,
    required this.comparisonColumns,
    required this.locale,
    required this.scheme,
  });

  @override
  State<_ComparisonCopyButton> createState() =>
      _ComparisonCopyButtonState();
}

class _ComparisonCopyButtonState extends State<_ComparisonCopyButton> {
  bool _justCopied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _hasSourceRef(BiblicalPerson p, List<String> prefixes) {
    for (final r in p.refs) {
      for (final prefix in prefixes) {
        if (r.startsWith(prefix)) return true;
      }
    }
    return false;
  }

  String _buildTsv() {
    final loc = widget.locale;
    // Header row: Gen, Name, Years + each source column.
    final cols = <String>[
      uiStrings['familyTreeColGen']?[loc] ?? 'Gen',
      uiStrings['familyTreeColName']?[loc] ?? 'Name',
      uiStrings['familyTreeColYears']?[loc] ?? 'Years',
      for (final col in widget.comparisonColumns)
        uiStrings[col.$1]?[loc] ?? col.$1,
    ];
    final buf = StringBuffer(cols.join('\t'));
    buf.writeln();
    for (var i = 0; i < widget.spine.length; i++) {
      final p = widget.spine[i];
      final row = <String>[
        '${i + 1}',
        p.localizedName(loc),
        p.displayYears(loc),
        for (final col in widget.comparisonColumns)
          _hasSourceRef(p, col.$2) ? '✓' : '',
      ];
      buf.writeln(row.join('\t'));
    }
    return buf.toString().trim();
  }

  Future<void> _handleTap() async {
    final tsv = _buildTsv();
    final ok = await ClipboardHelper.copyText(tsv);
    if (!mounted) return;
    if (!ok) {
      _showFloatingToast(
        context,
        message: uiStrings['familyTreeCopyFailedToast']?[widget.locale] ??
            'Copy failed — clipboard not available',
        icon: Icons.error_outline_rounded,
        background: Theme.of(context).colorScheme.error,
      );
      return;
    }
    _showFloatingToast(
      context,
      message:
          uiStrings['familyTreeCopiedToast']?[widget.locale] ??
              'Copied to clipboard',
      icon: Icons.check_circle_rounded,
      background: Theme.of(context).colorScheme.primary,
    );
    setState(() => _justCopied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _justCopied
          ? (uiStrings['familyTreeCopiedToast']?[widget.locale] ??
              'Copied')
          : (uiStrings['familyTreeCopyAll']?[widget.locale] ??
              'Copy table'),
      onPressed: _justCopied ? null : _handleTap,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (c, a) =>
            ScaleTransition(scale: a, child: c),
        child: _justCopied
            ? Icon(Icons.check_circle_rounded,
                key: const ValueKey('chk'),
                size: 22,
                // Theme-aware green so the "copied" indicator stays
                // vivid in dark mode (was using fixed shade600 which
                // is too dim against dark surfaces).
                color: paletteAccent(context, Colors.green))
            : Icon(Icons.copy_rounded,
                key: const ValueKey('cp'),
                size: 18,
                color: widget.scheme.primary),
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

/// Floating toast pinned to the root overlay so it appears above
/// any modal sheet / dialog. Used by the comparison-table copy
/// button (the detail-sheet uses its own copy of this in
/// person_detail_sheet.dart — same shape).
void _showFloatingToast(
  BuildContext context, {
  required String message,
  required IconData icon,
  required Color background,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) {
    final media = MediaQuery.of(ctx);
    return Positioned(
      left: 0,
      right: 0,
      top: media.padding.top + 24,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  });
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2000), () {
    entry.remove();
  });
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
  final String locale;
  const _RolePill({
    required this.label,
    required this.accent,
    required this.scheme,
    required this.locale,
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
        localizedRole(label, locale),
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

// localizedRole imported from utils/biblical_role.dart

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
