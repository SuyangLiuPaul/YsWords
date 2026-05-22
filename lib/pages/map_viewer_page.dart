import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_map.dart';
import 'package:yswords/services/map_service.dart';
import 'package:yswords/widgets/illustration_image.dart';
import 'package:provider/provider.dart';

/// Full-screen map viewer with a glass header and an optional bottom
/// strip of related maps so the user can switch between them in place.
///
///   - [relatedMaps] is the curated list of maps the user came in with
///     (chapter-level + book-level matches). Shown first.
///   - The strip also lazy-loads the full library so the user can jump
///     to any map in the corpus without bouncing back through the
///     picker.
class MapViewerPage extends StatefulWidget {
  final BibleMap map;
  final String locale;
  final List<BibleMap> relatedMaps;

  const MapViewerPage({
    super.key,
    required this.map,
    required this.locale,
    this.relatedMaps = const [],
  });

  @override
  State<MapViewerPage> createState() => _MapViewerPageState();
}

class _MapViewerPageState extends State<MapViewerPage> {
  late BibleMap _current;
  List<BibleMap> _allMaps = const [];

  @override
  void initState() {
    super.initState();
    _current = widget.map;
    MapService.loadMaps().then((all) {
      if (mounted) setState(() => _allMaps = all);
    });
  }

  /// The strip ordering: relatedMaps first (deduped), then everything
  /// else from the full library.
  List<BibleMap> get _stripMaps {
    final seen = <String>{};
    final out = <BibleMap>[];
    for (final m in widget.relatedMaps) {
      if (seen.add(m.id)) out.add(m);
    }
    for (final m in _allMaps) {
      if (seen.add(m.id)) out.add(m);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<AppSettings>();
    // Prefer the live locale so titles/descriptions retranslate
    // immediately if the user switches language while the map page
    // is open. Fall back to the locale that was passed in by the
    // launching widget, which is still useful when there's no
    // AppSettings ancestor (tests, isolated previews).
    final locale = settings.locale.isNotEmpty ? settings.locale : widget.locale;
    final desc = _current.localizedDescription(locale);
    final showStrip = _stripMaps.length > 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // Full-screen zoomable map. Use a unique key so [InteractiveViewer]
          // resets pan/zoom when the user switches maps from the strip.
          Positioned.fill(
            child: InteractiveViewer(
              key: ValueKey('iv_${_current.id}'),
              minScale: 0.5,
              maxScale: 5.0,
              // 2026-05-23 (v1.2.83): replaced the asset-vs-network
              // duplication with the IllustrationImage helper that
              // dispatches on map.source. Same behaviour for the 55
              // bundled maps; the 1041 paintings now resolve to the
              // yswords-data CDN instead of failing silently.
              child: Center(
                child: IllustrationImage(
                  map: _current,
                  fit: BoxFit.contain,
                  errorBuilder: (_) => _imageFallback(scheme),
                ),
              ),
            ),
          ),

          // Floating glass header — title now wraps to 2 lines so long
          // names like "Paul's Second Missionary Journey" or
          // "保罗第二次传道旅程" don't get truncated by ellipsis.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surface
                            .withValues(alpha: isDark ? 0.74 : 0.82),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant
                              .withValues(alpha: 0.18),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4 * settings.menuScale,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18 * settings.menuScale),
                            padding: EdgeInsets.all(10 * settings.menuScale),
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40),
                            tooltip:
                                uiStrings['back']?[locale] ?? 'Back',
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _current.localizedTitle(locale),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                    style: TextStyle(
                                      fontSize: 14 * settings.menuScale,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                      height: 1.25,
                                    ),
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    SizedBox(height: 2 * settings.menuScale),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11 * settings.menuScale,
                                        color: scheme.onSurfaceVariant,
                                        height: 1.3,
                                      ),
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
                ),
              ),
            ),
          ),

          // Bottom strip of related + all maps.
          if (showStrip)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surface
                              .withValues(alpha: isDark ? 0.74 : 0.82),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: scheme.outlineVariant
                                .withValues(alpha: 0.18),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uiStrings['mapsRelated']?[locale] ??
                                  'Related maps',
                              style: TextStyle(
                                fontSize: 11 * settings.menuScale,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 6 * settings.menuScale),
                            SizedBox(
                              height: 78 * settings.menuScale,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _stripMaps.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (ctx, i) {
                                  final m = _stripMaps[i];
                                  final isCurrent = m.id == _current.id;
                                  final isRelated = widget.relatedMaps
                                      .any((r) => r.id == m.id);
                                  return _StripCard(
                                    map: m,
                                    locale: locale,
                                    isCurrent: isCurrent,
                                    isRelated: isRelated,
                                    menuScale: settings.menuScale,
                                    onTap: () {
                                      if (isCurrent) return;
                                      setState(() => _current = m);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageFallback(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: scheme.outline),
          const SizedBox(height: 8),
          Text(
            'Illustration unavailable',
            style: TextStyle(color: scheme.outline, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _StripCard extends StatelessWidget {
  final BibleMap map;
  final String locale;
  final bool isCurrent;
  final bool isRelated;
  final double menuScale;
  final VoidCallback onTap;

  const _StripCard({
    required this.map,
    required this.locale,
    required this.isCurrent,
    required this.isRelated,
    required this.menuScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = 110 * menuScale;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    border: Border.all(
                      color: isCurrent
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.4),
                      width: isCurrent ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 2026-05-23 (v1.2.83): IllustrationImage helper
                      // — same dispatch logic as the hero, single
                      // source of truth.
                      IllustrationImage(
                        map: map,
                        fit: BoxFit.cover,
                        cacheWidth: 220,
                        errorBuilder: (_) => Icon(
                          Icons.collections,
                          color: scheme.primary,
                        ),
                      ),
                      if (isRelated && !isCurrent)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            // 2026-05-10 (v1.2.23): theme-aware
                            // onPrimary instead of hardcoded white.
                            child: Icon(
                              Icons.bookmark_rounded,
                              color: scheme.onPrimary,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 4 * menuScale),
            Text(
              map.localizedTitle(locale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10 * menuScale,
                fontWeight:
                    isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent ? scheme.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
