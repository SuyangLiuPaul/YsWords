import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/widgets/left_accent_card.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/timeline_event.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/timeline_service.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
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
class BibleTimelinePage extends StatefulWidget {
  const BibleTimelinePage({super.key});

  @override
  State<BibleTimelinePage> createState() => _BibleTimelinePageState();
}

class _BibleTimelinePageState extends State<BibleTimelinePage> {
  Future<List<TimelineEvent>>? _future;
  String _query = '';
  late final TextEditingController _searchController;
  final Set<String> _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _future = TimelineService.instance.loadAll();
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
          uiStrings['bibleTimeline']?[locale] ?? 'Bible Timeline',
        ),
        actions: const [HomeIconButton()],
      ),
      body: FutureBuilder<List<TimelineEvent>>(
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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
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
              ),
            ),
          );
        },
      ),
    );
  }

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
          hintText: uiStrings['bibleTimelineSearchHint']?[locale] ??
              'Search events, descriptions…',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Future<void> _jumpToRef(BuildContext context, String raw) async {
    final ref = parseReference(raw);
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
    Get.to(() => const HomePage(),
        routeName: '/HomePage',
        transition: Transition.rightToLeft);
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
                                onTap: () => onTapRef(r),
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

class _RefChip extends StatelessWidget {
  final String raw;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _RefChip({
    required this.raw,
    required this.locale,
    required this.scheme,
    required this.onTap,
  });

  String _localized() {
    final p = parseReference(raw);
    if (p == null) return raw;
    final book = localeAwareBookName(p.englishBook, locale);
    final tail = p.toString().replaceFirst(p.englishBook, '');
    return '$book$tail';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded,
                  size: 11, color: scheme.primary),
              const SizedBox(width: 3),
              Text(
                _localized(),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
