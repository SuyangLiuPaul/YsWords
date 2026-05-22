import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/jump_to_reference.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Standalone highlights browser. Filters by color (or "All") and a
/// free-text search box; tap a row to jump to the verse in the
/// reader. Long-press shows actions: copy text, share, remove.
///
/// Until this page existed (Round 34) highlights were only viewable
/// via the modal HighlightsSheet from the floating-header overflow
/// menu — fine for power users but invisible to anyone who didn't
/// know to look. Surfacing them as a peer to Notes / Bookmarks /
/// Plan inside the Library tab structure improves discoverability.
class HighlightsPage extends StatefulWidget {
  const HighlightsPage({super.key});

  @override
  State<HighlightsPage> createState() => _HighlightsPageState();
}

class _HighlightsPageState extends State<HighlightsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  /// Color filter ARGB int, or null for "All colors".
  int? _colorFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final mainProvider = context.watch<MainProvider>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;

    final highlights = mainProvider.highlights;
    final byId = {for (final v in mainProvider.verses) v.id: v};
    final indexById = <String, int>{
      for (int i = 0; i < mainProvider.verses.length; i++)
        mainProvider.verses[i].id: i,
    };

    // Build the displayed list: resolve IDs to verses, apply color
    // filter, apply text-query filter, sort canonically.
    final items = <_HighlightItem>[];
    highlights.forEach((id, color) {
      final v = byId[id];
      if (v == null) return; // Orphaned (different version)
      if (_colorFilter != null && color != _colorFilter) return;
      if (_query.isNotEmpty) {
        final hay =
            '${v.book} ${v.chapter}:${v.verseLabel} ${sanitizeForSearch(v.text)}'
                .toLowerCase();
        if (!hay.contains(_query.toLowerCase())) return;
      }
      items.add(_HighlightItem(verse: v, color: Color(color)));
    });
    items.sort((a, b) => (indexById[a.verse.id] ?? 0)
        .compareTo(indexById[b.verse.id] ?? 0));

    // Color swatches in the filter row come from the actual set of
    // colors the user has used — no point showing a green chip if
    // the user only has yellow highlights.
    final usedColors = highlights.values.toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['highlights']?[locale] ?? 'Highlights'),
        actions: [
          if (highlights.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: uiStrings['copyAll']?[locale] ?? 'Copy all',
              onPressed: () => _copyAll(context, items, settings),
            ),
          const HomeIconButton(),
        ],
      ),
      body: Column(
        children: [
          // Search box.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: uiStrings['search']?[locale] ?? 'Search',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (s) => setState(() => _query = s.trim()),
            ),
          ),
          // Color filter row — All chip + one chip per used color.
          if (usedColors.length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _FilterChip(
                    label: uiStrings['allColors']?[locale] ?? 'All',
                    selected: _colorFilter == null,
                    onTap: () => setState(() => _colorFilter = null),
                  ),
                  for (final argb in usedColors)
                    _ColorFilterChip(
                      color: Color(argb),
                      selected: _colorFilter == argb,
                      onTap: () => setState(() {
                        _colorFilter = _colorFilter == argb ? null : argb;
                      }),
                    ),
                ],
              ),
            ),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    highlights.isEmpty
                        ? (uiStrings['highlightsEmpty']?[locale] ??
                            'No highlights yet. Long-press a verse and pick a color.')
                        : (uiStrings['highlightsNoMatch']?[locale] ??
                            'No highlights match this filter.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _HighlightTile(
                  item: items[i],
                  fontFamily: settings.fontFamily,
                  onTap: () => _navigateToVerse(items[i].verse, mainProvider),
                  onMore: () => _showActions(
                      context, items[i], mainProvider, locale),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToVerse(Verse v, MainProvider mp) {
    // Prepare the pendingJump handshake BEFORE pushing the route, so
    // the reader's post-frame consumer drains it on the very first
    // build that has both the controller attached and the
    // verseToItemMap populated. The previous pattern used a fragile
    // 300 ms `Future.delayed` that often missed cold-start and slow
    // devices, leaving the user stranded at the top of the chapter.
    prepareJumpToVerse(v, mp);
    Get.to(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
  }

  Future<void> _copyAll(
      BuildContext context, List<_HighlightItem> items, AppSettings s) async {
    final buf = StringBuffer();
    for (final it in items) {
      buf.writeln(
          '[${it.verse.book} ${it.verse.chapter}:${it.verse.verseLabel}] '
          '${sanitizeForSearch(it.verse.text)}');
    }
    if (!context.mounted) return;
    await ClipboardHelper.shareOrCopy(context, buf.toString().trim(),
        title: 'YsWords highlights');
  }

  void _showActions(BuildContext context, _HighlightItem it,
      MainProvider mp, String locale) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(uiStrings['share']?[locale] ?? 'Share'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  if (!context.mounted) return;
                  await ClipboardHelper.shareOrCopy(
                    context,
                    '[${it.verse.book} ${it.verse.chapter}:${it.verse.verseLabel}] '
                    '${sanitizeForSearch(it.verse.text)}',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(
                    uiStrings['removeHighlight']?[locale] ?? 'Remove'),
                onTap: () {
                  mp.removeHighlight(verse: it.verse);
                  Navigator.of(sheetCtx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HighlightItem {
  final Verse verse;
  final Color color;
  const _HighlightItem({required this.verse, required this.color});
}

class _HighlightTile extends StatelessWidget {
  final _HighlightItem item;
  final String fontFamily;
  final VoidCallback onTap;
  final VoidCallback onMore;
  const _HighlightTile({
    required this.item,
    required this.fontFamily,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = sanitizeForSearch(item.verse.text);
    return ListTile(
      leading: Container(
        width: 6,
        height: 36,
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(
        '${item.verse.book} ${item.verse.chapter}:${item.verse.verseLabel}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.primary,
          fontFamily: fontFamily,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: scheme.onSurface,
          fontFamily: fontFamily,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: onMore,
      ),
      onTap: onTap,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
          fontSize:
              (settings.fontSize - 2).clamp(12.0, 16.0).toDouble(),
          fontWeight: FontWeight.w600,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ColorFilterChip extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorFilterChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: selected ? 2 : 0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
