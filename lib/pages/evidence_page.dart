import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/pages/evidence_detail_page.dart';
import 'package:yswords/services/ai_search_service.dart';
import 'package:yswords/services/bible_evidence_service.dart';
import 'package:yswords/widgets/confidence_badge.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Browse the migrated Biblical Evidence Archive — 209 archaeological,
/// manuscript, scientific, and historical findings that intersect
/// with biblical accounts. Search box + category + confidence
/// filters; tap a card to open the full description.
class EvidencePage extends StatefulWidget {
  /// When non-null, the list is pre-filtered to evidences referencing
  /// this English book name. Used by the reader's "Evidence for
  /// this chapter" entry point.
  final String? filterBook;

  /// When [filterBook] AND this are both set, narrow further to the
  /// specific chapter — entries whose [scriptureReference] either
  /// covers this chapter directly (e.g. "Genesis 1:1") or spans a
  /// chapter range that includes it (e.g. "Genesis 1:1-2:3"). Avoids
  /// the previous behaviour where reading Genesis 1 surfaced
  /// Genesis-37 evidences whose images had nothing to do with the
  /// chapter on screen.
  final int? filterChapter;

  const EvidencePage({super.key, this.filterBook, this.filterChapter});

  @override
  State<EvidencePage> createState() => _EvidencePageState();
}

class _EvidencePageState extends State<EvidencePage> {
  List<BibleEvidence> _all = const [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryFilter;
  String? _confidenceFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await BibleEvidenceService.all();
    if (!mounted) return;
    // Narrow chain: chapter (most specific) -> book -> archive-wide.
    // Each step falls back to the broader scope if it would otherwise
    // strand the user on an empty page; better to show neighbouring
    // entries than nothing at all when curated coverage is thin.
    var filtered = list;
    if (widget.filterBook != null) {
      if (widget.filterChapter != null) {
        final byChapter = BibleEvidenceService.forChapter(
          list,
          widget.filterBook!,
          widget.filterChapter!,
        );
        if (byChapter.isNotEmpty) {
          filtered = byChapter;
        } else {
          final byBook = BibleEvidenceService.forBook(
            list,
            widget.filterBook!,
          );
          filtered = byBook.isNotEmpty ? byBook : list;
        }
      } else {
        final byBook = BibleEvidenceService.forBook(
          list,
          widget.filterBook!,
        );
        filtered = byBook.isNotEmpty ? byBook : list;
      }
    }
    setState(() {
      _all = filtered;
      _loading = false;
    });
  }

  List<BibleEvidence> _filtered(String locale) {
    var list = _all;
    if (_categoryFilter != null) {
      list = list.where((e) => e.category == _categoryFilter).toList();
    }
    if (_confidenceFilter != null) {
      list = list
          .where((e) => e.confidenceLevel == _confidenceFilter)
          .toList();
    }
    return BibleEvidenceService.search(list, _query, locale);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final isWide = MediaQuery.of(context).size.width >= 720;
    final maxW = isWide ? 1100.0 : double.infinity;
    final crossAxisCount = isWide ? 2 : 1;

    final filtered = _filtered(locale);
    final categories = _all.map((e) => e.category).toSet().toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          widget.filterBook != null
              ? (uiStrings['evidenceForBook']?[locale] ?? 'Evidence — ')
                      .replaceAll('{book}', widget.filterBook!) +
                  widget.filterBook!
              : (uiStrings['bibleEvidence']?[locale] ?? 'Bible Evidence'),
        ),
        actions: [
          IconButton(
            tooltip: uiStrings['askAi']?[locale] ?? 'Ask AI',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => _openAiDialog(context, locale),
          ),
          const HomeIconButton(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  children: [
                    // Search.
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: settings.fontSize),
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.search, size: 20),
                          hintText:
                              uiStrings['search']?[locale] ?? 'Search',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                        onChanged: (s) =>
                            setState(() => _query = s.trim()),
                      ),
                    ),
                    // Filter chip rows: category + confidence.
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12),
                        children: [
                          _Chip(
                            label: uiStrings['allCategories']?[locale] ??
                                'All',
                            selected: _categoryFilter == null,
                            onTap: () =>
                                setState(() => _categoryFilter = null),
                          ),
                          for (final c in categories)
                            _Chip(
                              label: _categoryLabel(c, locale),
                              selected: _categoryFilter == c,
                              onTap: () => setState(() {
                                _categoryFilter =
                                    _categoryFilter == c ? null : c;
                              }),
                            ),
                          const SizedBox(width: 12),
                          for (final lvl in const [
                            'Definitive',
                            'Strong',
                            'Circumstantial'
                          ])
                            _Chip(
                              label: _confidenceLabel(lvl, locale),
                              selected: _confidenceFilter == lvl,
                              outlineColor: _confidenceColor(lvl),
                              onTap: () => setState(() {
                                _confidenceFilter =
                                    _confidenceFilter == lvl ? null : lvl;
                              }),
                            ),
                        ],
                      ),
                    ),
                    // Result count.
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            (uiStrings['resultsCount']?[locale] ??
                                    '{n} results')
                                .replaceAll(
                                    '{n}', filtered.length.toString()),
                            style: TextStyle(
                              fontSize:
                                  (settings.fontSize - 3)
                                      .clamp(11.0, 14.0)
                                      .toDouble(),
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (filtered.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            uiStrings['noResults']?[locale] ??
                                'No results',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refreshEvidence,
                          child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                              12, 4, 12, 16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 220,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _EvidenceCard(
                            evidence: filtered[i],
                            locale: locale,
                            onTap: () => Get.to(
                              () => EvidenceDetailPage(
                                  evidence: filtered[i]),
                              transition: Transition.rightToLeft,
                            ),
                          ),
                        ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _refreshEvidence() async {
    await BibleEvidenceService.refresh();
    if (!mounted) return;
    final list = await BibleEvidenceService.all();
    if (!mounted) return;
    final filtered = widget.filterBook != null
        ? BibleEvidenceService.forBook(list, widget.filterBook!)
        : list;
    setState(() {
      _all = filtered.isEmpty ? list : filtered;
    });
  }

  void _openAiDialog(BuildContext context, String locale) {
    showDialog(
      context: context,
      builder: (_) => _AiSearchDialog(
        locale: locale,
        all: _all,
        onCitationTap: (ev) {
          Navigator.of(context).pop();
          Get.to(
            () => EvidenceDetailPage(evidence: ev),
            transition: Transition.rightToLeft,
          );
        },
      ),
    );
  }

  String _categoryLabel(String c, String locale) =>
      uiStrings['category$c']?[locale] ?? c;

  String _confidenceLabel(String c, String locale) =>
      uiStrings['confidence$c']?[locale] ?? c;

  Color _confidenceColor(String c) {
    switch (c) {
      case 'Definitive':
        return const Color(0xFF2E7D32);
      case 'Strong':
        return Theme.of(context).colorScheme.primary;
      case 'Circumstantial':
      default:
        return const Color(0xFFEF6C00);
    }
  }
}

class _EvidenceCard extends StatelessWidget {
  final BibleEvidence evidence;
  final String locale;
  final VoidCallback onTap;

  const _EvidenceCard({
    required this.evidence,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final imgUrl =
        evidence.images.isNotEmpty ? evidence.images.first : null;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero image / icon fallback.
              SizedBox(
                height: 100,
                child: imgUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _IconFallback(icon: evidence.icon),
                          loadingBuilder: (_, child, p) {
                            if (p == null) return child;
                            return _IconFallback(icon: evidence.icon);
                          },
                        ),
                      )
                    : _IconFallback(icon: evidence.icon),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            evidence.localizedTitle(locale),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: settings.fontFamily,
                              fontSize: (settings.fontSize - 1)
                                  .clamp(13.0, 18.0)
                                  .toDouble(),
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConfidenceBadge(
                          level: evidence.confidenceLevel,
                          color:
                              evidence.confidenceColor(scheme),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      evidence.localizedSummary(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: (settings.fontSize - 3)
                            .clamp(11.0, 15.0)
                            .toDouble(),
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 13, color: scheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            evidence.scriptureReference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: settings.fontFamily,
                              fontSize: (settings.fontSize - 4)
                                  .clamp(11.0, 14.0)
                                  .toDouble(),
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconFallback extends StatelessWidget {
  final String icon;
  const _IconFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Text(icon, style: const TextStyle(fontSize: 36)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? outlineColor;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlineColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final accent = outlineColor ?? scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: accent.withValues(alpha: 0.18),
        side: BorderSide(
            color: selected ? accent : scheme.outlineVariant,
            width: selected ? 1.4 : 1),
        labelStyle: TextStyle(
          fontFamily: settings.fontFamily,
          fontSize:
              (settings.fontSize - 2).clamp(12.0, 16.0).toDouble(),
          fontWeight: FontWeight.w600,
          color: selected ? accent : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Modal dialog wrapping the Cloud Functions AI search (Gemini proxy).
///
/// Wired but graceful — if the Cloud Function isn't deployed yet, the
/// 404/CORS error surfaces as a SnackBar inside the dialog rather than
/// crashing or blocking the page. Citations link straight to the
/// matching `EvidenceDetailPage`.
class _AiSearchDialog extends StatefulWidget {
  final String locale;
  final List<BibleEvidence> all;
  final void Function(BibleEvidence) onCitationTap;

  const _AiSearchDialog({
    required this.locale,
    required this.all,
    required this.onCitationTap,
  });

  @override
  State<_AiSearchDialog> createState() => _AiSearchDialogState();
}

class _AiSearchDialogState extends State<_AiSearchDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _notice; // shown when AI was unavailable but local matches found
  AiSearchResult? _result;
  // When AI is unavailable, we surface a local keyword match so the
  // feature still does something useful. These are domain entries
  // matched by `BibleEvidenceService.search()`, not Gemini citations.
  List<BibleEvidence> _localMatches = const [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) return;
    setState(() {
      _busy = true;
      _notice = null;
      _result = null;
      _localMatches = const [];
    });
    final r = await AiSearchService.ask(query: q, locale: widget.locale);
    if (!mounted) return;

    if (r.unavailable) {
      // AI service down / not deployed. Don't show a scary error —
      // run the same query through the local keyword index and
      // return those matches instead, with a small note explaining
      // the fallback.
      final local =
          BibleEvidenceService.search(widget.all, q, widget.locale);
      setState(() {
        _busy = false;
        _result = r; // keep so the unavailable note surface
        _notice = r.unavailableReason;
        _localMatches = local.take(12).toList();
      });
      return;
    }

    setState(() {
      _busy = false;
      _result = r;
    });
  }

  /// Resolve a citation id back to the loaded evidence list so we can
  /// hand a real model object to the navigator. Built lazily so we
  /// only pay the O(n) cost on first citation tap, then O(1) for
  /// every tap after.
  Map<String, BibleEvidence>? _idMap;
  BibleEvidence? _resolve(String id) {
    final m = _idMap ??= {for (final e in widget.all) e.id: e};
    return m[id];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final locale = widget.locale;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(uiStrings['askAi']?[locale] ?? 'Ask AI'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: settings.fontSize,
              ),
              decoration: InputDecoration(
                hintText: uiStrings['askAiHint']?[locale] ??
                    'e.g. What evidence supports the Exodus?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => _ask(),
            ),
            const SizedBox(height: 12),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            // AI-unavailable notice — neutral tone, not red. Sits
            // above whatever local matches we found.
            if (_notice != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: scheme.outlineVariant
                          .withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _notice!,
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: (settings.fontSize - 2)
                              .clamp(11.0, 14.0)
                              .toDouble(),
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Local keyword fallback ─────────────────────────────
            // Shown when the AI service is unavailable. Same evidence
            // entries the main filter chip search would return, but
            // accessed inline in the dialog so the user gets results
            // for "What evidence supports the Exodus?" type queries
            // without needing the function deployed.
            if (_localMatches.isNotEmpty) ...[
              Text(
                uiStrings['keywordMatches']?[locale] ??
                    'Keyword matches',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize:
                      (settings.fontSize - 2).clamp(11.0, 14.0).toDouble(),
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              for (final ev in _localMatches)
                _LocalMatchTile(
                  evidence: ev,
                  locale: locale,
                  onTap: () => widget.onCitationTap(ev),
                ),
            ],
            if (_result != null &&
                _result!.answer.isNotEmpty &&
                !_result!.unavailable) ...[
              Text(
                _result!.answer,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: settings.fontSize,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              if (_result!.citations.isNotEmpty)
                Text(
                  uiStrings['citations']?[locale] ?? 'Citations',
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize:
                        (settings.fontSize - 2).clamp(11.0, 14.0).toDouble(),
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 6),
              for (final c in _result!.citations)
                _CitationTile(
                  citation: c,
                  onTap: () {
                    final ev = _resolve(c.id);
                    if (ev != null) widget.onCitationTap(ev);
                  },
                ),
            ],
            // Empty state — only when we genuinely got nothing back
            // (AI returned no answer AND local found nothing AND
            // nothing's loading).
            if (!_busy &&
                _result != null &&
                _result!.answer.isEmpty &&
                _result!.citations.isEmpty &&
                _localMatches.isEmpty)
              Text(
                uiStrings['noResults']?[locale] ?? 'No results',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(uiStrings['close']?[locale] ?? 'Close'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _ask,
          icon: const Icon(Icons.send_outlined, size: 16),
          label: Text(uiStrings['ask']?[locale] ?? 'Ask'),
        ),
      ],
    );
  }
}

/// One row in the local-keyword fallback list shown when the Cloud
/// Function is unreachable. Renders the matched BibleEvidence's
/// title + scripture reference so the user can immediately spot
/// relevant entries and tap through.
class _LocalMatchTile extends StatelessWidget {
  final BibleEvidence evidence;
  final String locale;
  final VoidCallback onTap;
  const _LocalMatchTile({
    required this.evidence,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            Text(evidence.icon,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evidence.localizedTitle(locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (evidence.scriptureReference.isNotEmpty)
                    Text(
                      evidence.scriptureReference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: 12,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

class _CitationTile extends StatelessWidget {
  final AiCitation citation;
  final VoidCallback onTap;
  const _CitationTile({required this.citation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 14, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    citation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (citation.scriptureReference.isNotEmpty)
                    Text(
                      citation.scriptureReference,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
