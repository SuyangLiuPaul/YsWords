import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/entry_copy.dart';
import 'package:yswords/widgets/left_accent_card.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/chronology.dart';
import 'package:yswords/models/timeline_event.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/chronology_service.dart';
import 'package:yswords/services/timeline_service.dart';
import 'package:yswords/widgets/chronology_chart.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Bible timeline — chronological view of ~97 key biblical events
/// from Creation (~4000 BC) to John on Patmos (~95 AD), modelled
/// on BibleHub's timeline structure but localized and visually
/// nicer.
///
/// Layout (per row):
///   [Year column 90 px]   ●   [Title + refs chips on tap-expand
///                              shows description]
///
/// Era section dividers (Antediluvian / Patriarchs / Mosaic /
/// Conquest / Monarchy / Exile / Inter-testamental / NT) reuse the
/// family-tree era palette.
///
/// Search at top filters by title / description / id.
/// Tap a verse-ref chip → jumps to that verse in the reader.
///
/// 2026-09-03: the page now hosts TWO views, switched by the segmented
/// control under the AppBar.
///
///   • [TimelineView.events] — the list above. "What happened, in order."
///   • [TimelineView.chart]  — [ChronologyChart]. "Who was alive at the
///                             same time", which a list of points cannot
///                             express, because points have no duration.
///
/// The chart is a second VIEW rather than a second page on purpose. The
/// queue item that asked for it (`docs/autonomous-queue.md`, user
/// 2026-08-12) named the outcome to avoid in as many words: "shipping a
/// second, prettier timeline beside the existing one". One page, one
/// dataset family, two lenses.
enum TimelineView { events, chart }

/// `/chronology` — the timeline page opened on its chart view.
///
/// A named class rather than a second `GetPage` pointing at
/// `BibleTimelinePage`, because a registered route in this app is
/// identified by its page class: `test/url_routing_stage3_sync_test.dart`
/// keys `getPages` and the §3 table of `docs/url-routing-plan.md` off the
/// class name, so one class cannot hold two paths. It is four lines and
/// no state — the page is still one page.
class ChronologyChartPage extends StatelessWidget {
  const ChronologyChartPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const BibleTimelinePage(initialView: TimelineView.chart);
}

class BibleTimelinePage extends StatefulWidget {
  /// Which view opens first. `/timeline` lands on the event list;
  /// `/chronology` and the Featured card land on the chart.
  final TimelineView initialView;

  const BibleTimelinePage({
    super.key,
    this.initialView = TimelineView.events,
  });

  @override
  State<BibleTimelinePage> createState() => _BibleTimelinePageState();
}

class _BibleTimelinePageState extends State<BibleTimelinePage> {
  Future<List<TimelineEvent>>? _future;
  Future<ChronologyData>? _chronologyFuture;
  String _query = '';
  late final TextEditingController _searchController;
  final Set<String> _expanded = <String>{};
  late TimelineView _view;

  @override
  void initState() {
    super.initState();
    _future = TimelineService.instance.loadAll();
    _view = widget.initialView;
    // Loaded lazily: someone who only ever opens the event list should
    // not pay for the chart's asset.
    if (_view == TimelineView.chart) {
      _chronologyFuture = ChronologyService.instance.load();
    }
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          _view == TimelineView.chart
              ? (uiStrings['chronologyChart']?[locale] ?? 'Chronology chart')
              : (uiStrings['bibleTimeline']?[locale] ?? 'Bible Timeline'),
        ),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              _viewSwitcher(locale, scheme),
              Expanded(
                child: _view == TimelineView.chart
                    ? _buildChart(locale, scheme)
                    : _buildEvents(locale, scheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The two-lens control. A `SegmentedButton` rather than tabs: there
  /// are exactly two, and a `TabBar` would imply the chart is more event
  /// list than it is.
  Widget _viewSwitcher(String locale, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<TimelineView>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
              TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          segments: [
            ButtonSegment(
              value: TimelineView.events,
              icon: const Icon(Icons.timeline_rounded, size: 16),
              label: Text(
                uiStrings['chronologyTabEvents']?[locale] ?? 'Events',
              ),
            ),
            ButtonSegment(
              value: TimelineView.chart,
              icon: const Icon(Icons.stacked_bar_chart_rounded, size: 16),
              label: Text(
                uiStrings['chronologyTabChart']?[locale] ?? 'Lifelines',
              ),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (s) => setState(() {
            _view = s.first;
            _chronologyFuture ??= ChronologyService.instance.load();
          }),
        ),
      ),
    );
  }

  Widget _buildChart(String locale, ColorScheme scheme) {
    return FutureBuilder<ChronologyData>(
      future: _chronologyFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}'
                ': ${snap.error}',
                style: TextStyle(color: scheme.error),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ChronologyChart(
          data: snap.data!,
          locale: locale,
          onTapRef: (raw) => _jumpToRef(context, raw),
        );
      },
    );
  }

  Widget _buildEvents(String locale, ColorScheme scheme) {
    return FutureBuilder<List<TimelineEvent>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                // 2026-05-10 (v1.2.21): localised via shared
                // `loadErrorTitle` ui-string.
                child: Text(
                  '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}: ${snap.error}',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            );
          }
          final all = snap.data!;
          final q = sanitizeForSearch(_query.trim()).toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all.where((e) {
                  final hay = [
                    e.titleEn,
                    e.titleZhHans,
                    e.titleZhHant,
                    e.descEn,
                    e.descZhHans,
                    e.descZhHant,
                    e.id,
                  ].join(' ').toLowerCase();
                  return hay.contains(q);
                }).toList();

          // Group by era while preserving chronological order.
          final items = <_ListItem>[];
          String? lastEra;
          for (final e in filtered) {
            if (e.era != lastEra) {
              items.add(_ListItem.eraHeader(e.era));
              lastEra = e.era;
            }
            items.add(_ListItem.event(e));
          }

          // The 960 pt cap and the outer Center now live on the page's
          // body, shared with the chart view, so this returns the column
          // bare.
          return Column(
                children: [
                  _buildSearchField(locale),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          (uiStrings['bibleTimelineCount']?[locale] ??
                                  '{count} events')
                              .replaceAll(
                                  '{count}', '${filtered.length}'),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              uiStrings['bibleTimelineNoMatches']
                                      ?[locale] ??
                                  'No events match.',
                              style: TextStyle(
                                color: scheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 32),
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final it = items[i];
                              if (it.isEra) {
                                return _EraDivider(
                                  era: it.eraKey!,
                                  locale: locale,
                                  scheme: scheme,
                                );
                              }
                              final ev = it.event!;
                              return _EventTile(
                                event: ev,
                                locale: locale,
                                scheme: scheme,
                                expanded: _expanded.contains(ev.id),
                                onToggleExpand: () => setState(() {
                                  if (_expanded.contains(ev.id)) {
                                    _expanded.remove(ev.id);
                                  } else {
                                    _expanded.add(ev.id);
                                  }
                                }),
                                onTapRef: (raw) =>
                                    _jumpToRef(context, raw),
                              );
                            },
                          ),
                  ),
                ],
              );
        },
      );
  }

  // 2026-08-02 (round 60): filled rounded "pill" search field,
  // matching the capsule language now used across Home / Search /
  // Sermons / Bible Evidence instead of a generic Material outline.
  Widget _buildSearchField(String locale) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          isDense: true,
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: scheme.onSurfaceVariant),
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
          hintText: uiStrings['bibleTimelineSearchHint']?[locale] ??
              'Search events, descriptions…',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Future<void> _jumpToRef(BuildContext context, String raw) async {
    // Same resolver the chip's affordance is drawn from, so the two
    // cannot come apart. The null branch below is unreachable from a
    // tap now — a chip that cannot open is not tappable — and is kept
    // only for callers that arrive some other way.
    final ref = firstResolvableReference(raw);
    if (ref == null) {
      final locale = context.read<AppSettings>().locale;
      final msg = (uiStrings['couldNotParseRef']?[locale] ??
              "Couldn't parse reference: {ref}")
          .replaceFirst('{ref}', raw);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    final mp = context.read<MainProvider>();
    final result =
        await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    Navigator.of(context).maybePop();
    // 2026-05-24 (v1.3.6): explicit routeName — see main.dart for
    // the duplicate-HomePage-detection rationale.
    pushPage(const HomePage(),
        routeName: '/HomePage');
  }
}

// ── List item type ──────────────────────────────────────────────

class _ListItem {
  final String? eraKey;
  final TimelineEvent? event;
  const _ListItem._({this.eraKey, this.event});
  factory _ListItem.eraHeader(String era) => _ListItem._(eraKey: era);
  factory _ListItem.event(TimelineEvent e) => _ListItem._(event: e);
  bool get isEra => eraKey != null;
}

// ── Era divider ─────────────────────────────────────────────────

class _EraDivider extends StatelessWidget {
  final String era;
  final String locale;
  final ColorScheme scheme;
  const _EraDivider({
    required this.era,
    required this.locale,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    // 2026-05-10 (v1.2.36): the icon/text use the brightness-aware
    // variant so they stay readable on the dark theme; the gradient
    // and border keep the raw era colour because they're decorative
    // accents (low alpha + thin border) where the deeper hue is
    // appropriate.
    final color = _eraColor(era);
    final fg = _eraColorOn(Theme.of(context).brightness, era);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.0),
          ],
        ),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_edu, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            _eraLabel(era, locale),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Event tile ──────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final TimelineEvent event;
  final String locale;
  final ColorScheme scheme;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final void Function(String raw) onTapRef;

  const _EventTile({
    required this.event,
    required this.locale,
    required this.scheme,
    required this.expanded,
    required this.onToggleExpand,
    required this.onTapRef,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eraColor(event.era);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleExpand,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year column.
              SizedBox(
                width: 90,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    event.displayYear(locale),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
              // Bullet on the timeline rail.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surface,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LeftAccentCard(
                  // v1.3.x: was Container(BoxDecoration(border:
                  // Border(left:...), borderRadius:...)) — non-uniform
                  // border + radius throws in Border.paint.
                  padding:
                      const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  background: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  accentColor: color.withValues(alpha: 0.55),
                  accentWidth: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.localizedTitle(locale),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Only while expanded: collapsed, this list
                          // is a dense timeline rail and a copy icon on
                          // every row would compete with the years for
                          // the eye. Expanded is also the only state
                          // where the description — the part worth
                          // taking — is on screen.
                          if (expanded)
                            IconButton(
                              icon: const Icon(Icons.copy_outlined),
                              iconSize: 16,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              tooltip: uiStrings['copySelection']?[locale] ??
                                  'Copy',
                              onPressed: () =>
                                  ClipboardHelper.copyWithFeedback(
                                context,
                                formatEntryForCopy(
                                  heading: '${event.displayYear(locale)} — '
                                      '${event.localizedTitle(locale)}',
                                  body: event.localizedDesc(locale),
                                  refs: event.refs.map(
                                      (r) => localizedTimelineRef(r, locale)),
                                ),
                              ),
                            ),
                          Icon(
                            expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: scheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.localizedDesc(locale),
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                scheme.onSurface.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (event.refs.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final r in event.refs)
                              _RefChip(
                                raw: r,
                                locale: locale,
                                scheme: scheme,
                                // Null when nothing in the citation
                                // opens — see [_RefChip].
                                onTap: firstResolvableReference(r) == null
                                    ? null
                                    : () => onTapRef(r),
                              ),
                          ],
                        ),
                      ],
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
}

/// One verse-reference chip under an event.
///
/// [onTap] is null when nothing in the citation resolves to a passage
/// the app can open, and then the chip is drawn as plain text rather
/// than as a link. It used to be an unconditional `VoidCallback`, which
/// meant every citation LOOKED navigable and an unresolvable one could
/// answer only 「Couldn't parse reference」 — the same defect the
/// evidence chip was fixed for. Today's `assets/bible_timeline.json`
/// resolves 123 of 123, so nothing on screen changes; what changes is
/// what happens when an import does not, which
/// `test/reference_chip_unresolvable_test.dart` pins.
/// A raw canonical reference (`Genesis 12:1`) in the reader's language.
///
/// Top-level rather than a method on [_RefChip] because the copy button
/// needs the identical string: what lands on the clipboard should be
/// what was on the screen, not the English the data happens to store.
/// Unparseable input is returned untouched — the event still cites it,
/// and inventing a localisation for something we could not parse would
/// be worse than showing the raw form.
String localizedTimelineRef(String raw, String locale) {
  final p = parseReference(raw);
  if (p == null) return raw;
  final book = localeAwareBookName(p.englishBook, locale);
  final tail = p.toString().replaceFirst(p.englishBook, '');
  return '$book$tail';
}

class _RefChip extends StatelessWidget {
  final String raw;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback? onTap;
  const _RefChip({
    required this.raw,
    required this.locale,
    required this.scheme,
    required this.onTap,
  });

  String _localized() => localizedTimelineRef(raw, locale);

  @override
  Widget build(BuildContext context) {
    // The citation is still printed either way — the event cites it and
    // the row goes on saying so. Only the affordance is withdrawn.
    final navigable = onTap != null;
    final fg = navigable
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.55);
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: navigable
            ? scheme.primaryContainer.withValues(alpha: 0.25)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: navigable
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 11, color: fg),
          const SizedBox(width: 3),
          // Flexible, not a bare Text: a citation the parser rejects is
          // printed RAW, and raw can be prose — `Various NT references`
          // is a real value in the evidence corpus — which overflows
          // this row on a phone and throws in debug. A parsed citation
          // is short enough that this never engages. `Wrap` hands its
          // children the line's maxWidth, so the flex has something to
          // resolve against.
          Flexible(
            child: Text(
              _localized(),
              style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (!navigable) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: body,
      ),
    );
  }
}

// ── Era helpers (palette mirrors family tree) ──────────────────

String _eraLabel(String era, String locale) {
  const labels = {
    'antediluvian': {
      'en': 'Antediluvian (Creation → Flood)',
      'zh-Hans': '洪水之前（创世 → 洪水）',
      'zh-Hant': '洪水之前（創世 → 洪水）',
    },
    'patriarchs': {
      'en': 'Patriarchs (Abraham → Joseph)',
      'zh-Hans': '列祖时代（亚伯拉罕 → 约瑟）',
      'zh-Hant': '列祖時代（亞伯拉罕 → 約瑟）',
    },
    'mosaic': {
      'en': 'Exodus & Wilderness',
      'zh-Hans': '出埃及与旷野',
      'zh-Hant': '出埃及與曠野',
    },
    'conquest': {
      'en': 'Conquest & Judges',
      'zh-Hans': '征服与士师',
      'zh-Hant': '征服與士師',
    },
    'monarchy': {
      'en': 'United & Divided Monarchy',
      'zh-Hans': '联合与分裂王国',
      'zh-Hant': '聯合與分裂王國',
    },
    'exile': {
      'en': 'Exile & Return',
      'zh-Hans': '被掳与回归',
      'zh-Hant': '被擄與回歸',
    },
    'intertestamental': {
      'en': 'Inter-Testamental Period',
      'zh-Hans': '两约之间',
      'zh-Hant': '兩約之間',
    },
    'nt': {
      'en': 'New Testament',
      'zh-Hans': '新约',
      'zh-Hant': '新約',
    },
  };
  return labels[era]?[locale] ?? era.toUpperCase();
}

Color _eraColor(String era) {
  switch (era) {
    case 'antediluvian':
      return const Color(0xFF6B5E3F);
    case 'patriarchs':
      return const Color(0xFF8C5A2F);
    case 'mosaic':
      return const Color(0xFFB42E2E);
    case 'conquest':
      return const Color(0xFF2F7C5C);
    case 'monarchy':
      return const Color(0xFF2A4FB0);
    case 'exile':
      return const Color(0xFF5F3F86);
    case 'intertestamental':
      return const Color(0xFF505590);
    case 'nt':
      return const Color(0xFFB8860B);
  }
  return const Color(0xFF555555);
}

/// 2026-05-10 (v1.2.36): brightness-aware variant of `_eraColor`.
/// User reported that era titles ("OT / NT / Patriarchs / …") were
/// hard to read in dark mode — the palette above is tuned for light
/// surfaces (lightness ~33–44 %) and fades into the dark theme's
/// `#121212`-ish surface. Lightening via `Color.lerp(c, Colors.white,
/// 0.45)` keeps the era's hue (so colour-coding still works) while
/// pushing the value high enough to clear the WCAG contrast threshold
/// against a dark surface.
///
/// Use this everywhere a hardcoded era colour is rendered as text /
/// icon / chip-foreground; raw `_eraColor` is fine for backgrounds /
/// borders / accents that DON'T need to clear contrast.
Color _eraColorOn(Brightness brightness, String era) {
  final base = _eraColor(era);
  if (brightness == Brightness.dark) {
    return Color.lerp(base, Colors.white, 0.45) ?? base;
  }
  return base;
}
