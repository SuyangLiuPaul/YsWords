import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/news_article.dart';
import 'package:yswords/pages/news_detail_page.dart';
import 'package:yswords/services/daily_news_service.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Browse the migrated DailyNews bundle — bilingual world / China /
/// Australia headlines paired with thematic Bible reflections.
///
/// Layout
///   • Phone: stacked sections, each a list of headline rows.
///   • Tablet/desktop: two-column — headline list on the left and
///     "Bible Lens" sticky panel on the right (mirrors the original
///     Astro design).
class DailyNewsPage extends StatefulWidget {
  const DailyNewsPage({super.key});

  @override
  State<DailyNewsPage> createState() => _DailyNewsPageState();
}

class _DailyNewsPageState extends State<DailyNewsPage> {
  DailyNewsBundle? _bundle;
  NewsArticle? _selected;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await DailyNewsService.load();
      if (!mounted) return;
      setState(() {
        _bundle = b;
        _selected = b.allArticles.isNotEmpty ? b.allArticles.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _manualRefresh() async {
    // Guard against double-taps and overlapping refreshes — without
    // this, two near-simultaneous taps would race and the slower
    // response could overwrite a fresher one (out-of-order resolve).
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await DailyNewsService.refresh();
      final b = await DailyNewsService.load();
      if (!mounted) return;
      setState(() {
        _bundle = b;
        // Preserve current selection if it still exists.
        final keep =
            _selected != null && b.allArticles.any((a) => a.id == _selected!.id)
                ? _selected
                : (b.allArticles.isNotEmpty ? b.allArticles.first : null);
        _selected = keep;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final isWide = MediaQuery.of(context).size.width >= 880;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['dailyNews']?[locale] ?? 'Daily News'),
        actions: [
          IconButton(
            tooltip: uiStrings['refresh']?[locale] ?? 'Refresh',
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined),
            onPressed: _refreshing ? null : _manualRefresh,
          ),
          const HomeIconButton(),
        ],
      ),
      body: _bundle == null
          ? Center(
              child: _error != null
                  ? _ErrorState(
                      error: _error!,
                      locale: locale,
                      settings: settings,
                      onRetry: _load,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          uiStrings['loading']?[locale] ?? 'Loading…',
                          style: TextStyle(
                              fontFamily: settings.fontFamily,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
            )
          : (_bundle!.allArticles.isEmpty
              ? _EmptyState(
                  locale: locale,
                  settings: settings,
                  onRetry: _manualRefresh,
                )
              : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isWide
                    ? _buildTwoColumn(context, locale, settings)
                    : _buildSingleColumn(context, locale, settings),
              ),
            )),
    );
  }

  Widget _buildSingleColumn(
      BuildContext context, String locale, AppSettings settings) {
    return RefreshIndicator(
      onRefresh: _manualRefresh,
      child: ListView(
        // Always-scrollable physics so RefreshIndicator can pull
        // even when the list is shorter than the viewport.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Masthead(bundle: _bundle!, locale: locale, settings: settings),
          const SizedBox(height: 8),
          for (final s in _bundle!.sections) ...[
            _SectionHeader(
                section: s, locale: locale, settings: settings),
            for (final a in s.items)
              _HeadlineRow(
                article: a,
                locale: locale,
                settings: settings,
                selected: false,
                onTap: () => _open(a),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoColumn(
      BuildContext context, String locale, AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: RefreshIndicator(
              onRefresh: _manualRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                _Masthead(
                    bundle: _bundle!,
                    locale: locale,
                    settings: settings),
                const SizedBox(height: 8),
                for (final s in _bundle!.sections) ...[
                  _SectionHeader(
                      section: s,
                      locale: locale,
                      settings: settings),
                  for (final a in s.items)
                    _HeadlineRow(
                      article: a,
                      locale: locale,
                      settings: settings,
                      selected: _selected?.id == a.id,
                      onTap: () => _open(a),
                      onHover: () => setState(() => _selected = a),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 4,
            child: _selected == null
                ? const SizedBox.shrink()
                // Wrap in a SingleChildScrollView so the panel can be
                // taller than the viewport without clipping (image +
                // reflection + verse can easily exceed phone-tablet
                // heights, especially in Chinese where verse text is
                // longer).
                : SingleChildScrollView(
                    child: _BibleLensPanel(
                      article: _selected!,
                      locale: locale,
                      settings: settings,
                      onOpen: () => _open(_selected!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _open(NewsArticle a) {
    Get.to(
      () => NewsDetailPage(article: a),
      transition: Transition.rightToLeft,
    );
  }
}

class _Masthead extends StatelessWidget {
  final DailyNewsBundle bundle;
  final String locale;
  final AppSettings settings;
  const _Masthead({
    required this.bundle,
    required this.locale,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fs = settings.fontSize;
    final dateLabel = bundle.editionDate.isNotEmpty
        ? bundle.editionDate
        : (bundle.generatedAt?.toIso8601String().substring(0, 10) ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings['dailyNewsTagline']?[locale] ??
                'News through a biblical lens',
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs - 2).clamp(11.0, 15.0).toDouble(),
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateLabel,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs + 2).clamp(15.0, 22.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final NewsSection section;
  final String locale;
  final AppSettings settings;
  const _SectionHeader({
    required this.section,
    required this.locale,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fs = settings.fontSize;
    final accent = _sectionAccent(section.id, scheme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 4, height: 22, color: accent),
          const SizedBox(width: 10),
          Text(
            section.title(locale),
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs + 1).clamp(14.0, 20.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${section.items.length}',
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs - 3).clamp(11.0, 14.0).toDouble(),
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Color _sectionAccent(String sectionId, ColorScheme scheme) {
  switch (sectionId) {
    case 'china':
      return Colors.red.shade700;
    case 'australia':
      return Colors.green.shade700;
    case 'world':
    default:
      return scheme.primary;
  }
}

class _HeadlineRow extends StatelessWidget {
  final NewsArticle article;
  final String locale;
  final AppSettings settings;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onHover;

  const _HeadlineRow({
    required this.article,
    required this.locale,
    required this.settings,
    required this.selected,
    required this.onTap,
    this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fs = settings.fontSize;
    return MouseRegion(
      onEnter: onHover == null ? null : (_) => onHover!(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  article.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: (fs - 4).clamp(11.0, 14.0).toDouble(),
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  article.title(locale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: (fs - 1).clamp(13.0, 17.0).toDouble(),
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky right-column "Bible Lens" panel mirroring the original Astro
/// design. Updates as the user hovers over a headline.
class _BibleLensPanel extends StatelessWidget {
  final NewsArticle article;
  final String locale;
  final AppSettings settings;
  final VoidCallback onOpen;

  const _BibleLensPanel({
    required this.article,
    required this.locale,
    required this.settings,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fs = settings.fontSize;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings['bibleLens']?[locale] ?? 'Bible Lens',
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs - 3).clamp(11.0, 14.0).toDouble(),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            article.source,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs - 2).clamp(11.0, 14.0).toDouble(),
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            article.title(locale),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs + 2).clamp(15.0, 22.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              height: 1.3,
            ),
          ),
          if (article.image != null && article.image!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                article.image!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              article.verse.theme(locale),
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (fs - 3).clamp(11.0, 14.0).toDouble(),
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            article.reflection(locale),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs - 1).clamp(13.0, 16.0).toDouble(),
              color: scheme.onSurface,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            article.verse.reference,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs - 2).clamp(11.0, 14.0).toDouble(),
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            article.verse.text(locale),
            // Cap so the panel stays compact even when the verse is
            // long; the full text is always available on the detail
            // page reachable via the button below.
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: (fs - 1).clamp(13.0, 16.0).toDouble(),
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onOpen,
            icon: const Icon(Icons.read_more, size: 16),
            label: Text(uiStrings['readFullStory']?[locale] ??
                'Read full story'),
          ),
        ],
      ),
    );
  }
}


/// Friendly empty state — shown when the bundle parsed but contains
/// zero articles (e.g. cron failed and produced an empty payload).
/// Tap-to-retry triggers a manual refresh.
class _EmptyState extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  final Future<void> Function() onRetry;

  const _EmptyState({
    required this.locale,
    required this.settings,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper_outlined,
                size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              uiStrings["newsEmptyTitle"]?[locale] ??
                  "No news available",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (settings.fontSize + 2).clamp(14.0, 22.0),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              uiStrings["newsEmptyBody"]?[locale] ??
                  "The cron may have skipped this window. Pull down or tap retry to fetch the latest.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (settings.fontSize - 2).clamp(11.0, 15.0),
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(uiStrings["retry"]?[locale] ?? "Retry"),
            ),
          ],
        ),
      ),
    );
  }
}

/// Friendly error state — shown when the very first load failed
/// (no cache, no bundle, no network). Different from EmptyState in
/// that we have *no* data to show, not even stale.
class _ErrorState extends StatelessWidget {
  final String error;
  final String locale;
  final AppSettings settings;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.error,
    required this.locale,
    required this.settings,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 56, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              uiStrings["loadErrorTitle"]?[locale] ?? "Failed to load",
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (settings.fontSize + 2).clamp(14.0, 22.0),
                fontWeight: FontWeight.w700,
                color: scheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (settings.fontSize - 2).clamp(11.0, 14.0),
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(uiStrings["retry"]?[locale] ?? "Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
