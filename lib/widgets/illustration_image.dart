// 2026-05-23 (v1.2.83): single image widget that dispatches based on
// BibleMap.source — bundled asset vs. yswords-data CDN vs. legacy
// Wikimedia URL. Used by every place that renders a map / illustration
// thumbnail or hero (map_viewer_page, bible_reading_pane's _MapThumb,
// map picker sheet, etc.) so the dispatch logic isn't duplicated
// across three call sites.
//
// Before this widget existed, `assets/maps/${map.file}` was hard-coded
// — silently broken for the 1041 entries whose `file` was a URL
// rather than a local filename. The thumbnail strip rendered the
// broken-image fallback icon instead of the actual painting.

import 'package:flutter/material.dart';

import 'package:yswords/models/bible_map.dart';

class IllustrationImage extends StatelessWidget {
  final BibleMap map;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final WidgetBuilder? errorBuilder;
  final WidgetBuilder? loadingBuilder;

  const IllustrationImage({
    super.key,
    required this.map,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = errorBuilder ?? _defaultError;
    if (!map.hasImage) return Builder(builder: fallback);

    final loading = loadingBuilder;

    if (map.source == 'asset') {
      return Image.asset(
        map.assetPath,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (c, _, __) => fallback(c),
      );
    }

    // 'cdn' and 'legacy_url' both go through Image.network. Same
    // `webHtmlElementStrategy: prefer` we use everywhere else for
    // external images that lack CORS headers.
    return Image.network(
      map.imageUrl,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (c, _, __) => fallback(c),
      loadingBuilder: loading == null
          ? null
          : (c, child, p) {
              if (p == null) return child;
              return loading(c);
            },
    );
  }

  Widget _defaultError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Icon(Icons.collections_outlined, size: 22, color: scheme.outline),
    );
  }
}
