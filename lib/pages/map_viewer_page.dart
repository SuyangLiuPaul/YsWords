import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_map.dart';
import 'package:provider/provider.dart';

class MapViewerPage extends StatelessWidget {
  final BibleMap map;
  final String locale;

  const MapViewerPage({super.key, required this.map, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desc = map.localizedDescription(locale);
    final settings = context.watch<AppSettings>();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // Full-screen zoomable map
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.asset(
                'assets/maps/${map.file}',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: scheme.outline),
                      const SizedBox(height: 8),
                      Text(
                        uiStrings['noMapsForChapter']?[locale] ??
                            'Map unavailable',
                        style: TextStyle(color: scheme.outline, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating glass header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    8, 8, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.78),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
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
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    map.localizedTitle(locale),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13 * settings.menuScale,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  if (desc.isNotEmpty)
                                    Text(
                                      desc,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11 * settings.menuScale,
                                        color: scheme.onSurfaceVariant,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
