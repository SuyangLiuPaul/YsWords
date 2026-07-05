import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/spiritual_giant_categories.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/spiritual_giant.dart';
import 'package:yswords/pages/spiritual_giant_detail_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/spiritual_giant_service.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Fixed accent palette (one per category, in [giantCategoryOrder]).
/// Mid-tone hues chosen to stay legible with white text in both light
/// and dark themes — a nod to the colored-circle grid in the source
/// material. Indexed via [giantCategoryColorIndex].
const List<Color> kGiantPalette = <Color>[
  Color(0xFFB4884D), // fathers      — warm gold
  Color(0xFFA24B4B), // reformers    — deep red
  Color(0xFFC1683A), // revival      — burnt orange
  Color(0xFF4E7CA8), // preachers    — steel blue
  Color(0xFF4C8C6E), // missions     — green
  Color(0xFF7A6CA8), // deeper-life  — muted purple
  Color(0xFFB07750), // faith        — terracotta
  Color(0xFFB58A2E), // hymns        — amber
  Color(0xFFAA4B6B), // chinese      — rose
];

Color giantAccent(String categoryId) =>
    kGiantPalette[giantCategoryColorIndex(categoryId) % kGiantPalette.length];

/// Category-grouped browser for the 属灵伟人小传 / Spiritual Giants corpus.
///
/// Layout intentionally mirrors [SermonsPage] so the two content
/// modules feel consistent:
///   - AppBar with back + home
///   - free-text search field
///   - collapsible category groups ([ExpansionTile] in bordered cards)
///   - tap a row → [SpiritualGiantDetailPage]
class SpiritualGiantsPage extends StatefulWidget {
  const SpiritualGiantsPage({super.key});

  @override
  State<SpiritualGiantsPage> createState() => _SpiritualGiantsPageState();
}

class _SpiritualGiantsPageState extends State<SpiritualGiantsPage> {
  Future<Map<String, List<SpiritualGiant>>>? _future;
  String _query = '';

  /// Last-opened figure id, for the flash-highlight on return — mirrors
  /// the sermons list "you were last reading this" affordance.
  String? _lastReadId;
  Timer? _flashTimer;
  bool _flashActive = false;

  late final ScrollController _scrollController;
  Timer? _scrollPersistTimer;
  static const String _kListScrollKey = 'giants_list_scroll';
  static const String _kLastReadKey = 'giants_last_read';

  @override
  void initState() {
    super.initState();
    _future = SpiritualGiantService.instance.loadByCategory();
    _scrollController = ScrollController()..addListener(_onScroll);
    _restoreState();
  }

  @override
  void dispose() {
    _scrollPersistTimer?.cancel();
    _flashTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_kLastReadKey);
    final savedOffset = prefs.getDouble(_kListScrollKey);
    if (!mounted) return;
    setState(() {
      _lastReadId = lastId;
      _flashActive = lastId != null;
    });
    if (lastId != null) {
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _flashActive = false);
      });
    }
    if (savedOffset != null && savedOffset > 0) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(savedOffset.clamp(0.0, max));
    }
  }

  void _onScroll() {
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer =
        Timer(const Duration(milliseconds: 600), _persistScroll);
  }

  Future<void> _persistScroll() async {
    if (!_scrollController.hasClients) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kListScrollKey, _scrollController.position.pixels);
  }

  Future<void> _openGiant(SpiritualGiant g) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastReadKey, g.id);
    if (!mounted) return;
    // Nudge the synced state so the dashboard's "Resume biography"
    // hero refreshes on return — mirrors sermons_page._openSermon,
    // which relies on the same RealtimeDbSyncService listener the
    // dashboard uses to reload its resume cards.
    // ignore: unawaited_futures
    context.read<MainProvider>().saveCurrentState();
    setState(() {
      _lastReadId = g.id;
      _flashActive = false;
    });
    await Get.to(
      () => SpiritualGiantDetailPage(giant: g),
      transition: Transition.rightToLeft,
    );
    if (!mounted) return;
    setState(() => _flashActive = true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flashActive = false);
    });
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
          uiStrings['spiritualGiants']?[locale] ?? 'Spiritual Giants',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: const [HomeIconButton()],
      ),
      body: FutureBuilder<Map<String, List<SpiritualGiant>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}: ${snap.error}',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            );
          }
          final groups = _filtered(snap.data!, _query, locale);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: uiStrings['giantsSearchHint']?[locale] ??
                        'Search by name…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _summaryLine(groups, locale),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: groups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            uiStrings['giantsNoMatches']?[locale] ??
                                'No one matches your search.',
                            style: TextStyle(
                                color:
                                    scheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ),
                      )
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final entry in groups.entries)
                            _CategoryGroup(
                              category: entry.key,
                              giants: entry.value,
                              lastReadId: _lastReadId,
                              flashActive: _flashActive,
                              onTap: _openGiant,
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<SpiritualGiant>> _filtered(
      Map<String, List<SpiritualGiant>> all, String query, String locale) {
    if (query.isEmpty) return all;
    final q = query.toLowerCase();
    final out = <String, List<SpiritualGiant>>{};
    for (final e in all.entries) {
      final hits = e.value.where((g) {
        if (g.years.toLowerCase().contains(q)) return true;
        for (final v in g.name.values) {
          if (v.toLowerCase().contains(q)) return true;
        }
        for (final v in g.role.values) {
          if (v.toLowerCase().contains(q)) return true;
        }
        if (localizedGiantCategory(e.key, locale)
            .toLowerCase()
            .contains(q)) {
          return true;
        }
        return false;
      }).toList();
      if (hits.isNotEmpty) out[e.key] = hits;
    }
    return out;
  }

  String _summaryLine(
      Map<String, List<SpiritualGiant>> groups, String locale) {
    final n = groups.values.fold<int>(0, (a, b) => a + b.length);
    final t = groups.length;
    final tmpl = uiStrings['giantsCountTemplate']?[locale];
    if (tmpl != null) {
      return tmpl
          .replaceAll('{count}', n.toString())
          .replaceAll('{groups}', t.toString());
    }
    return '$n figures across $t groups';
  }
}

class _CategoryGroup extends StatelessWidget {
  final String category;
  final List<SpiritualGiant> giants;
  final String? lastReadId;
  final bool flashActive;
  final Future<void> Function(SpiritualGiant) onTap;

  const _CategoryGroup({
    required this.category,
    required this.giants,
    required this.lastReadId,
    required this.flashActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.watch<AppSettings>().locale;
    final accent = giantAccent(category);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: Container(
          width: 10,
          height: 36,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(
          localizedGiantCategory(category, locale),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _subtitle(giants.length, locale),
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        initiallyExpanded:
            lastReadId != null && giants.any((g) => g.id == lastReadId),
        children: [
          for (final g in giants)
            _GiantRow(
              giant: g,
              accent: accent,
              isLastRead: g.id == lastReadId,
              flashActive: flashActive,
              onTap: () => onTap(g),
            ),
        ],
      ),
    );
  }

  String _subtitle(int n, String locale) {
    final tmpl = uiStrings['giantsGroupCount']?[locale];
    if (tmpl != null) return tmpl.replaceAll('{count}', '$n');
    return '$n figure${n == 1 ? '' : 's'}';
  }
}

class _GiantRow extends StatelessWidget {
  final SpiritualGiant giant;
  final Color accent;
  final bool isLastRead;
  final bool flashActive;
  final VoidCallback onTap;

  const _GiantRow({
    required this.giant,
    required this.accent,
    required this.isLastRead,
    required this.flashActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.watch<AppSettings>().locale;
    final showFlash = isLastRead && flashActive;
    final name = giant.localizedName(locale);
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: showFlash
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        border: showFlash
            ? Border.all(
                color: scheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              )
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: accent,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (giant.years.isNotEmpty)
                Text(
                  giant.years,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              Text(
                giant.localizedRole(locale),
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        trailing: Icon(Icons.chevron_right,
            size: 20, color: scheme.onSurface.withValues(alpha: 0.4)),
        onTap: onTap,
      ),
    );
  }
}
