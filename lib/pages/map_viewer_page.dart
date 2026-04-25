import 'package:flutter/material.dart';
import 'package:yswords/models/bible_map.dart';

class MapViewerPage extends StatelessWidget {
  final BibleMap map;
  final String locale;

  const MapViewerPage({super.key, required this.map, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(map.localizedTitle(locale)),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.asset(
                  'assets/maps/${map.file}',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image,
                        size: 64, color: scheme.outline),
                  ),
                ),
              ),
            ),
          ),
          if (map.localizedDescription(locale).isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: scheme.surfaceContainerLow,
              child: Text(
                map.localizedDescription(locale),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
