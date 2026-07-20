import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/theme_color_helpers.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/pages/evidence_detail_page.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/ai_search_service.dart';
import 'package:yswords/services/bible_evidence_service.dart';
import 'package:yswords/utils/ai_markdown.dart' show parseAiMarkdown;
import 'package:yswords/utils/jump_to_reference.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/widgets/confidence_badge.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Browse the Biblical Evidence Archive — 225 archaeological,
/// manuscript, scientific, and historical findings that intersect
/// with biblical accounts. Search box + category + confidence
/// filters; tap a card to open the full description. Optional
/// chapter / book pre-filter via [filterBook] + [filterChapter].
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

/// What scope of evidences the page is currently showing. Drives the
/// disclosure banner so the user always knows whether the list is
/// chapter-narrowed, book-narrowed, or showing the full archive.
enum _EvidenceScope { chapter, book, archive }

class _EvidencePageState extends State<EvidencePage> {
  /// The complete archive — kept around so the user can widen out
  /// from chapter -> book -> archive without re-fetching.
  List<BibleEvidence> _allEntries = const [];
  /// The currently shown subset, scoped by [_scope].
  List<BibleEvidence> _all = const [];
  _EvidenceScope _scope = _EvidenceScope.archive;
  /// True when the current [_scope] is the result of falling back
  /// from a more-specific scope that came up empty. Drives the
  /// "showing book-wide because chapter has no curated entries"
  /// hint in the banner.
  bool _scopeWasFallback = false;
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
    var scope = _EvidenceScope.archive;
    var fallback = false;
    if (widget.filterBook != null) {
      if (widget.filterChapter != null) {
        final byChapter = BibleEvidenceService.forChapter(
          list,
          widget.filterBook!,
          widget.filterChapter!,
        );
        if (byChapter.isNotEmpty) {
          filtered = byChapter;
          scope = _EvidenceScope.chapter;
        } else {
          final byBook = BibleEvidenceService.forBook(
            list,
            widget.filterBook!,
          );
          if (byBook.isNotEmpty) {
            filtered = byBook;
            scope = _EvidenceScope.book;
            fallback = true; // chapter -> book widening
          } else {
            filtered = list;
            scope = _EvidenceScope.archive;
            fallback = true; // chapter -> archive widening
          }
        }
      } else {
        final byBook = BibleEvidenceService.forBook(
          list,
          widget.filterBook!,
        );
        if (byBook.isNotEmpty) {
          filtered = byBook;
          scope = _EvidenceScope.book;
        } else {
          filtered = list;
          scope = _EvidenceScope.archive;
          fallback = true; // book -> archive widening
        }
      }
    }
    setState(() {
      _allEntries = list;
      _all = filtered;
      _scope = scope;
      _scopeWasFallback = fallback;
      _loading = false;
    });
  }

  /// User taps the banner to widen scope by one step.
  void _widenScope() {
    if (_scope == _EvidenceScope.chapter && widget.filterBook != null) {
      final byBook =
          BibleEvidenceService.forBook(_allEntries, widget.filterBook!);
      setState(() {
        _all = byBook.isNotEmpty ? byBook : _allEntries;
        _scope = byBook.isNotEmpty
            ? _EvidenceScope.book
            : _EvidenceScope.archive;
        _scopeWasFallback = false;
      });
    } else if (_scope == _EvidenceScope.book) {
      setState(() {
        _all = _allEntries;
        _scope = _EvidenceScope.archive;
        _scopeWasFallback = false;
      });
    }
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
                    // Scope disclosure banner — only shown when the
                    // page is narrowed (chapter or book scope) so the
                    // user knows the list isn't the full archive and
                    // can widen out with one tap. Hidden in the
                    // archive-wide default state.
                    if (_scope != _EvidenceScope.archive)
                      _ScopeBanner(
                        scope: _scope,
                        wasFallback: _scopeWasFallback,
                        book: widget.filterBook,
                        chapter: widget.filterChapter,
                        locale: locale,
                        count: _all.length,
                        onWiden: _widenScope,
                      ),
                    // Search.
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                            fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                            // v1.3.84: 220 → 240. The 100px hero + the
                            // Expanded text block (title + 2-line summary +
                            // tappable scripture row) needed a few px more
                            // than 220 once the block was Expanded (it had
                            // been overflowing the column unboundedly — see
                            // the card). 240 leaves headroom for larger font
                            // scales and taller CJK text without overflow.
                            mainAxisExtent: 240,
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
    // Theme-aware confidence colors — paletteAccent gives shade700 in
    // light (deep green/orange = vivid against light surface) and
    // shade300 in dark (lighter so the indicator pops on dark
    // scaffold). Previously hardcoded shade800 hex values that were
    // too dark to read in dark mode.
    switch (c) {
      case 'Definitive':
        return paletteAccent(context, Colors.green);
      case 'Strong':
        return Theme.of(context).colorScheme.primary;
      case 'Circumstantial':
      default:
        return paletteAccent(context, Colors.orange);
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
    // PERF: scoped select instead of full watch<AppSettings>() — this
    // card is instantiated per evidence entry (225 entries) inside a
    // ListView.builder; an unrelated settings change would otherwise
    // rebuild every mounted card. Same pattern as VerseWidget /
    // ParagraphGroupWidget.
    context.select<AppSettings, (String, double)>(
        (s) => (s.fontFamily, s.fontSize));
    final settings = context.read<AppSettings>();
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
                        // 2026-05-07: prefer <img> tag over canvaskit
                        // XHR fetch — external evidence-image CDNs
                        // generally lack CORS headers.
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.prefer,
                          // 2026-05-08 (v1.0.1 perf): card hero image
                          // is 100 px tall, full card width (~340 px
                          // on mobile, ~480 on tablet). 960 cache px
                          // is 2× the largest card on retina without
                          // holding source bitmaps.
                          cacheWidth: 960,
                          cacheHeight: 240,
                          // 2026-05-22 (v1.2.78): both LOADING and
                          // ERROR fall back to the gradient placeholder
                          // — never the emoji. Earlier rounds left the
                          // emoji on hard image errors, but Wikimedia
                          // rate-limits (429) and CORS surprises mean
                          // a non-trivial fraction of cards rendered as
                          // emoji on first paint. The gradient + small
                          // category icon reads as "loading / image
                          // unavailable" without visual jarring.
                          errorBuilder: (_, __, ___) =>
                              _ShimmerPlaceholder(
                                category: evidence.category,
                                showCategoryIcon: true,
                              ),
                          loadingBuilder: (_, child, p) {
                            if (p == null) return child;
                            return _ShimmerPlaceholder(
                              category: evidence.category,
                            );
                          },
                        ),
                      )
                    : _ShimmerPlaceholder(
                        category: evidence.category,
                        showCategoryIcon: true,
                      ),
              ),
              // v1.3.84: Expanded so this text block gets the tile's
              // BOUNDED remaining height (mainAxisExtent 220 − 100 image).
              // Without it the block was a non-flex child of the outer
              // Column, which hands children UNBOUNDED vertical space — so
              // the `Spacer()` below ("non-zero flex but unbounded
              // constraints") threw and the whole evidence grid failed to
              // lay out (blank page + a cascade of RenderBox-not-laid-out
              // on /EvidencePage, reported from iOS).
              Expanded(
                child: Padding(
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
                              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: (settings.fontSize - 3)
                            .clamp(11.0, 15.0)
                            .toDouble(),
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    // Round 56: scripture-reference row is now its
                    // own tappable surface — tap takes the user
                    // straight to the cited verse in the reader,
                    // bypassing the detail page. User feedback:
                    // "圣经实证不是跟 bible 有关 — fix". Was: card
                    // showed the ref as plain text and only the
                    // detail page exposed a tappable chip, so the
                    // direct connection to scripture was buried.
                    InkWell(
                      onTap: () =>
                          _openReferenceFromCard(context, evidence),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.menu_book_rounded,
                                size: 14, color: scheme.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                evidence.scriptureReference,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                  fontSize: (settings.fontSize - 4)
                                      .clamp(11.0, 14.0)
                                      .toDouble(),
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: scheme.primary
                                      .withValues(alpha: 0.4),
                                  decorationStyle:
                                      TextDecorationStyle.dotted,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded,
                                size: 12,
                                color: scheme.primary
                                    .withValues(alpha: 0.65)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tapping the scripture-reference row on a card jumps the reader
  /// straight to the cited verse, bypassing the detail page. Mirrors
  /// `EvidenceDetailPage._openReference`: parse → resolveAndPrepareJump
  /// (with full-canon companion fallback for OT refs in NT-only
  /// versions) → SnackBar feedback → push HomePage.
  Future<void> _openReferenceFromCard(
      BuildContext context, BibleEvidence evidence) async {
    final raw = evidence.scriptureReference;
    BibleReference? ref = parseReference(raw);
    if (ref == null && raw.contains(';')) {
      for (final part in raw.split(';')) {
        ref = parseReference(part.trim());
        if (ref != null) break;
      }
    }
    if (ref == null) {
      final locale = context.read<AppSettings>().locale;
      final msg = (uiStrings['couldNotParseRef']?[locale] ??
              "Couldn't parse reference: {ref}")
          .replaceFirst('{ref}', raw);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    final mp = context.read<MainProvider>();
    final result = await resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    Get.to(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
  }
}

// v1.2.78: `_IconFallback` removed. Was the 36-px emoji shown on image
// load failure; replaced by `_ShimmerPlaceholder(showCategoryIcon: true)`
// which uses a Material category icon over the gradient — no emoji.

/// Category-tinted gradient placeholder. Used in two cases:
///   • While the hero Image.network is still loading (no icon)
///   • On hard image-load error (with a subtle Material category icon)
/// In both cases this replaces the previous emoji-only fallback —
/// users no longer see a wall of emoji-faces in the grid when images
/// are slow or Wikimedia rate-limits a batch of requests.
class _ShimmerPlaceholder extends StatelessWidget {
  final String category;
  final bool showCategoryIcon;
  const _ShimmerPlaceholder({
    required this.category,
    this.showCategoryIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Map each evidence category to a colour + Material icon. Subtle —
    // desaturated enough that real photos remain the dominant visual
    // once they land, and the placeholder doesn't visually shout when
    // a load fails.
    final (accent, icon) = switch (category) {
      'Manuscripts' => (scheme.tertiary, Icons.menu_book_outlined),
      'Archaeology' => (scheme.primary, Icons.terrain_outlined),
      'History'     => (scheme.secondary, Icons.account_balance_outlined),
      'Science'     => (scheme.tertiary, Icons.science_outlined),
      _             => (scheme.primary, Icons.image_outlined),
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.06),
            scheme.surfaceContainerHighest.withValues(alpha: 0.40),
          ],
        ),
      ),
      child: showCategoryIcon
          ? Center(
              child: Icon(
                icon,
                size: 32,
                color: accent.withValues(alpha: 0.55),
              ),
            )
          : null,
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
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
/// 2026-05-07: Intent fired by the Shortcuts wrapper when the user
/// presses Enter inside the Ask AI text field. Captured by an Actions
/// CallbackAction so we can call _ask() instead of letting the Enter
/// key insert a literal newline (the default for multi-line
/// TextFields).
class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

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
  // 2026-05-07: dialog opened — pick a placeholder query that is
  // (a) different each time and (b) tied to today's evidence so
  // the example feels relevant rather than the stale hardcoded
  // "What evidence supports the Exodus?" the user complained about.
  // Resolved once per dialog mount via [_pickHint] in initState.
  late final String _hintText;
  bool _busy = false;
  String? _notice; // shown when AI was unavailable but local matches found
  AiSearchResult? _result;
  // 2026-05-10 (v1.2.30): generation counter for the AI-ask Future.
  // The Ask button is disabled while `_busy = true` (line 1109), but
  // pressing Enter at the keyboard shortcut (line 927) bypasses that
  // guard. Without this counter, hitting Enter twice in quick succession
  // could let the older response's setState (line 864 / 873) land after
  // the newer one, showing stale results. Bump on every _ask entry +
  // every _ctrl edit (mirrors gemini_key_card.dart's _testGen pattern
  // shipped in v1.2.8).
  int _askGen = 0;

  /// 2026-05-08 (v1.1.10): heuristic — does this AI-failure notice
  /// indicate a quota / not-configured failure that BYOK can solve?
  /// Mirrors the helper in search_page.dart so the inline "Set up
  /// your own Gemini key" button only appears for those cases (not
  /// for e.g. network errors which BYOK won't fix).
  bool _shouldOfferByokForNotice(String? notice) {
    if (notice == null) return false;
    final lower = notice.toLowerCase();
    const triggers = [
      'quota', 'exhausted', 'rate-limit', 'rate limit',
      'not configured', 'gemini_api_key',
      '配额', '用完', '没有配置',
    ];
    for (final t in triggers) {
      if (lower.contains(t)) return true;
    }
    return false;
  }
  // When AI is unavailable, we surface a local keyword match so the
  // feature still does something useful. These are domain entries
  // matched by `BibleEvidenceService.search()`, not Gemini citations.
  List<BibleEvidence> _localMatches = const [];

  @override
  void initState() {
    super.initState();
    _hintText = _pickHint();
  }

  /// Build a placeholder query for the input. 50 % of the time we
  /// pick a question phrased around **today's evidence** (which the
  /// dashboard surfaces via `BibleEvidenceService.todayEvidence`),
  /// so the example feels timely. The other 50 % is a random pick
  /// from a small curated pool of broad questions — keeps the prompt
  /// fresh on repeat opens. Both paths are deterministic by date so
  /// rapid open/close on the same day shows a stable hint instead of
  /// flickering.
  String _pickHint() {
    final locale = widget.locale;
    final isZh = locale.startsWith('zh');
    final isHant = locale == 'zh-Hant';
    final today = BibleEvidenceService.todayEvidence(widget.all);
    final todayTitle =
        today?.title[locale] ?? today?.title['en'] ?? '';
    // Date-based seed so the hint stays stable through the day but
    // rotates the next morning.
    final n = DateTime.now();
    final start = DateTime(n.year, 1, 1);
    final dayOfYear = n.difference(start).inDays;
    final useToday = (dayOfYear % 2 == 0) && todayTitle.isNotEmpty;
    if (useToday) {
      // Question shaped around today's actual evidence entry.
      if (isZh) {
        return isHant
            ? '例如：「$todayTitle」是怎麼證實聖經記載的？'
            : '例如：「$todayTitle」是怎么证实圣经记载的？';
      }
      return 'e.g. How does "$todayTitle" support the biblical record?';
    }
    // Curated pool of broad questions — covers different categories
    // (archaeology, manuscript, science, history) so consecutive
    // openings feel varied even when not riding today's evidence.
    final poolEn = <String>[
      'What evidence supports the Exodus?',
      'How do we know the Bible was preserved accurately?',
      'What archaeological finds confirm King David existed?',
      'Is there evidence outside the Bible for Jesus?',
      'What manuscripts establish the New Testament text?',
      'How does the Tel Dan stele relate to the Bible?',
      'What science is consistent with biblical creation?',
      'What history confirms Pontius Pilate was real?',
    ];
    final poolHans = <String>[
      '出埃及记有什么考古证据？',
      '圣经文本是怎么准确流传至今的？',
      '哪些考古发现证实了大卫王的存在？',
      '圣经之外还有哪些关于耶稣的史料？',
      '哪些抄本确立了新约的文本？',
      '泰勒丹石碑跟圣经有什么关系？',
      '哪些科学发现与圣经的创世记载相符？',
      '哪些史料证明本丢·彼拉多是真实人物？',
    ];
    final poolHant = <String>[
      '出埃及記有什麼考古證據？',
      '聖經文本是怎麼準確流傳至今的？',
      '哪些考古發現證實了大衛王的存在？',
      '聖經之外還有哪些關於耶穌的史料？',
      '哪些抄本確立了新約的文本？',
      '泰勒丹石碑跟聖經有什麼關係？',
      '哪些科學發現與聖經的創世記載相符？',
      '哪些史料證明本丟・彼拉多是真實人物？',
    ];
    final pool = isHant ? poolHant : (isZh ? poolHans : poolEn);
    final raw = pool[dayOfYear % pool.length];
    return isZh ? '例如：$raw' : 'e.g. $raw';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) return;
    final myGen = ++_askGen;
    setState(() {
      _busy = true;
      _notice = null;
      _result = null;
      _localMatches = const [];
    });
    // BYOK (2026-05): forward the user's Gemini key when set so AI
    // search runs against their own AI Studio quota.
    final settings = context.read<AppSettings>();
    final userKey = settings.geminiApiKey;
    final r = await AiSearchService.ask(
      query: q,
      locale: widget.locale,
      userApiKey: userKey.isEmpty ? null : userKey,
      // v1.2.26 — pick the user's chosen AI tier.
      aiModel: settings.aiModel,
    );
    if (!mounted || myGen != _askGen) return;

    if (r.unavailable) {
      // AI service down / not deployed. Don't show a scary error —
      // run the same query through the local keyword index and
      // return those matches instead, with a small note explaining
      // the fallback.
      final local =
          BibleEvidenceService.search(widget.all, q, widget.locale);
      if (myGen != _askGen) return; // re-check after the local match
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
      // 2026-05-11 (v1.2.42): the v1.2.37 fellBackToFlash branch
      // was removed — v1.2.40's switch to gemini-3-flash-preview
      // made Deep work on free tier without silent downgrade.
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
      // 2026-05-22 (v1.2.71): make the dialog scroll when the AI
      // answer + citations overflow the screen — previously the
      // actions row was overlapping the response on phones.
      scrollable: true,
      // Tighter horizontal padding on small screens (phones < 360 px
      // wide were losing ~80 px to default insetPadding).
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(uiStrings['askAi']?[locale] ?? 'Ask AI'),
        ],
      ),
      // ConstrainedBox(maxWidth: 520) — phones get the full available
      // width; iPad / desktop cap at 520 so the dialog doesn't stretch
      // unreasonably wide on big screens.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 2026-05-07: wrap the TextField in a Shortcuts/Actions
            // pair so Enter submits, Shift+Enter inserts a newline.
            // Plain `onSubmitted` doesn't fire when maxLines > 1 —
            // Flutter treats Enter as a literal newline character in
            // that case. The Shortcuts intercept handles Enter
            // explicitly while letting Shift+Enter fall through to
            // the default newline behaviour for users who want a
            // multi-line query.
            Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.enter): _SubmitIntent(),
                SingleActivator(LogicalKeyboardKey.numpadEnter):
                    _SubmitIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _SubmitIntent: CallbackAction<_SubmitIntent>(
                    onInvoke: (_) {
                      _ask();
                      return null;
                    },
                  ),
                },
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: settings.fontSize,
                  ),
                  decoration: InputDecoration(
                    hintText: _hintText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onSubmitted: (_) => _ask(),
                ),
              ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _notice!,
                            style: TextStyle(
                              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              fontSize: (settings.fontSize - 2)
                                  .clamp(11.0, 14.0)
                                  .toDouble(),
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 2026-05-08 (v1.1.10): deep-link to BYOK Settings
                    // when the notice indicates a quota / not-configured
                    // failure AND the user hasn't already set up their
                    // own Gemini key.
                    if (_shouldOfferByokForNotice(_notice) &&
                        !settings.hasUserGeminiKey) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.key_rounded, size: 14),
                          label: Text(
                            uiStrings['aiOpenByokSettings']
                                    ?[widget.locale] ??
                                'Set up your own Gemini API key',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            Get.to(
                              () => const SettingsPage(
                                  initialSection: SettingsSection.ai),
                              transition: Transition.rightToLeft,
                            );
                          },
                        ),
                      ),
                    ],
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
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
              // 2026-05-11 (v1.2.38): render the AI answer through
              // the shared markdown parser so `**bold**` /
              // `*italic*` / `# heading` / `- bullet` Gemini emits
              // displays as actual bold/italic/headings/bullets
              // instead of literal asterisks. User: "why it is
              // like ** which means it is not formatted well".
              SelectableText.rich(
                TextSpan(
                  children: parseAiMarkdown(
                    _result!.answer,
                    base: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: settings.fontSize,
                      height: 1.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_result!.citations.isNotEmpty)
                Text(
                  uiStrings['citations']?[locale] ?? 'Citations',
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
    // PERF: scoped select — see _EvidenceCard for the rationale.
    context.select<AppSettings, String>((s) => s.fontFamily);
    final settings = context.read<AppSettings>();
    // 2026-05-22 (v1.2.78): replaced the 18-px emoji thumbnail with
    // a 32×32 rounded image thumbnail (falls back to a Material
    // category icon on load error). Search-result rows used to be
    // dominated by emoji-faces; now they show the actual artefact
    // preview, matching what users tap through to.
    final firstImage =
        evidence.images.isNotEmpty ? evidence.images.first : null;
    final accent = switch (evidence.category) {
      'Manuscripts' => scheme.tertiary,
      'Archaeology' => scheme.primary,
      'History'     => scheme.secondary,
      'Science'     => scheme.tertiary,
      _             => scheme.primary,
    };
    final categoryIcon = switch (evidence.category) {
      'Manuscripts' => Icons.menu_book_outlined,
      'Archaeology' => Icons.terrain_outlined,
      'History'     => Icons.account_balance_outlined,
      'Science'     => Icons.science_outlined,
      _             => Icons.image_outlined,
    };
    final thumb = Container(
      width: 32,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: firstImage != null
          ? Image.network(
              firstImage,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              cacheWidth: 128,
              cacheHeight: 128,
              errorBuilder: (_, __, ___) => Icon(
                categoryIcon,
                size: 18,
                color: accent.withValues(alpha: 0.7),
              ),
              loadingBuilder: (_, child, p) {
                if (p == null) return child;
                return Center(
                  child: Icon(
                    categoryIcon,
                    size: 18,
                    color: accent.withValues(alpha: 0.55),
                  ),
                );
              },
            )
          : Icon(
              categoryIcon,
              size: 18,
              color: accent.withValues(alpha: 0.7),
            ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            thumb,
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
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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

class _ScopeBanner extends StatelessWidget {
  final _EvidenceScope scope;
  final bool wasFallback;
  final String? book;
  final int? chapter;
  final String locale;
  final int count;
  final VoidCallback onWiden;

  const _ScopeBanner({
    required this.scope,
    required this.wasFallback,
    required this.book,
    required this.chapter,
    required this.locale,
    required this.count,
    required this.onWiden,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = wasFallback
        ? scheme.surfaceContainerHighest
        : scheme.primaryContainer.withValues(alpha: 0.45);
    final onTone = wasFallback ? scheme.onSurface : scheme.onPrimaryContainer;

    String fmt(String key, String fallback) {
      final raw = uiStrings[key]?[locale] ?? fallback;
      return raw
          .replaceAll('{n}', '$count')
          .replaceAll('{book}', book ?? '')
          .replaceAll('{chapter}', '${chapter ?? ''}');
    }

    String headline;
    String widenLabel;
    switch (scope) {
      case _EvidenceScope.chapter:
        headline = fmt('evidenceScopeChapter', '$count entries for ${book ?? ""} $chapter');
        widenLabel = fmt('evidenceWidenBook', 'Show all in ${book ?? ""}');
        break;
      case _EvidenceScope.book:
        if (wasFallback && chapter != null) {
          headline = fmt(
            'evidenceScopeBookFallback',
            'No entries for ${book ?? ""} $chapter — showing all $count from ${book ?? ""}',
          );
        } else {
          headline = fmt('evidenceScopeBook', '$count entries for ${book ?? ""}');
        }
        widenLabel = fmt('evidenceWidenArchive', 'Show full archive');
        break;
      case _EvidenceScope.archive:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            wasFallback ? Icons.info_outline : Icons.tune,
            size: 16,
            color: onTone,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              headline,
              style: TextStyle(fontSize: 13, color: onTone),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onWiden,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widenLabel,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

