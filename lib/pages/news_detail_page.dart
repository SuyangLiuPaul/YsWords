import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/news_article.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/jump_to_reference.dart';
import 'package:yswords/utils/reference_parser.dart'
    show BibleReference, parseReference;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Full-page view of a [NewsArticle]: image, title, summary, thematic
/// Bible verse + reflection, and a tap-target to jump into the reader
/// at the cited verse (same pattern as `EvidenceDetailPage`).
///
/// 2026-05-22 (v1.2.72): now hosts a horizontal [PageView] so the user
/// can swipe left/right between sibling articles without popping back
/// to the index. Callers pass the full visible list + the index of the
/// tapped article. The convenience constructor [NewsDetailPage.single]
/// preserves the old "open one article" call shape for places like the
/// dashboard's standalone "share" card.
class NewsDetailPage extends StatefulWidget {
  final List<NewsArticle> articles;
  final int initialIndex;

  const NewsDetailPage({
    super.key,
    required this.articles,
    required this.initialIndex,
  }) : assert(articles.length > 0, 'NewsDetailPage requires at least one article');

  /// Back-compat constructor for callers that have only a single
  /// article and no sibling list to swipe through.
  NewsDetailPage.single({super.key, required NewsArticle article})
      : articles = [article],
        initialIndex = 0;

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Clamp defensively — caller might pass a stale index after the
    // articles list shrinks under them (refresh-while-open race). The
    // ctor assert guarantees `articles.length >= 1`, so `length - 1`
    // is always a valid upper bound here.
    final upper = widget.articles.length - 1;
    final raw = widget.initialIndex;
    _currentIndex = raw < 0 ? 0 : (raw > upper ? upper : raw);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  NewsArticle get _current => widget.articles[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final article = _current;
    final totalCount = widget.articles.length;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        // Wrap the row in LayoutBuilder so the source label can shrink
        // when the AppBar gets narrow (iPhone SE-class viewports + a
        // long source name like "The Guardian Australia"). Without this
        // the N/total chip can get pushed off-screen behind the action
        // icons.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                article.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            if (totalCount > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${_currentIndex + 1}/$totalCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: uiStrings['share']?[locale] ?? 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(article, context, locale),
          ),
          IconButton(
            tooltip: uiStrings['openSource']?[locale] ?? 'Open original',
            icon: const Icon(Icons.open_in_new_outlined),
            onPressed: () => _openOrCopySource(article, context, locale),
          ),
          const HomeIconButton(),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: totalCount,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final a = widget.articles[index];
          return _NewsDetailBody(
            article: a,
            settings: settings,
            locale: locale,
            scheme: scheme,
            onOpenReference: () => _openReference(a, context),
            onOpenOrCopySource: () =>
                _openOrCopySource(a, context, locale),
          );
        },
      ),
    );
  }

  // -----------------------------------------------------------------
  // Helpers — now keyed by the article they operate on so they can be
  // re-used for any swiped page, not just the initial one.
  // -----------------------------------------------------------------

  /// Open the source article in a new browser tab (web) — falls back
  /// to copy-link-to-clipboard if window.open is blocked or we're on
  /// a non-web platform without `url_launcher`. Either way the user
  /// gets to the article.
  Future<void> _openOrCopySource(
      NewsArticle article, BuildContext context, String locale) async {
    if (article.link.isEmpty) return;
    if (LinkOpener.isAvailable) {
      final ok = await LinkOpener.open(article.link);
      if (ok) return;
    }
    if (!context.mounted) return;
    // Web pop-up was blocked OR native target with no launcher —
    // give the user the URL via clipboard.
    await ClipboardHelper.shareOrCopy(
      context,
      article.link,
      title: article.source,
    );
  }

  Future<void> _share(
      NewsArticle article, BuildContext context, String locale) async {
    final body = StringBuffer()
      ..writeln(article.title(locale))
      ..writeln('— ${article.source} | ${article.verse.reference}')
      ..writeln()
      ..writeln(article.summary(locale))
      ..writeln()
      ..writeln(article.reflection(locale))
      ..writeln()
      ..writeln(article.verse.text(locale))
      ..writeln()
      ..writeln(article.link);
    await ClipboardHelper.shareOrCopy(
      context,
      body.toString().trim(),
      title: article.title(locale),
    );
  }

  /// Same cross-link mechanic as `EvidenceDetailPage._openReference`.
  /// Hands the target verse off to the reader via
  /// `MainProvider.setPendingJump`; the reader executes the scroll
  /// + highlight on its first build that has both the scroll-list
  /// controller attached AND the verseToItemMap populated. This
  /// replaces a fragile 320ms timer that often missed cold-start
  /// and version-switch builds.
  Future<void> _openReference(
      NewsArticle article, BuildContext context) async {
    // Mirror EvidenceDetailPage._openReference: tolerate multi-reference
    // strings like "Romans 8:28; Psalm 23:1" by trying the full string
    // first, then each semicolon-separated segment. News pipeline emits
    // single references today, but the defensive split future-proofs
    // against any pipeline change that adds compound refs.
    final raw = article.verse.reference;
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

/// One swipeable detail page. Stateless — the host [NewsDetailPage]
/// recreates this on each page-change via [PageView.builder].
class _NewsDetailBody extends StatelessWidget {
  final NewsArticle article;
  final AppSettings settings;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback onOpenReference;
  final VoidCallback onOpenOrCopySource;

  const _NewsDetailBody({
    required this.article,
    required this.settings,
    required this.locale,
    required this.scheme,
    required this.onOpenReference,
    required this.onOpenOrCopySource,
  });

  @override
  Widget build(BuildContext context) {
    final fs = settings.fontSize;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Section + source kicker.
            Text(
              '${_sectionLabel(article.section, locale)}  ·  '
              '${article.source}',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (fs - 3).clamp(11.0, 14.0).toDouble(),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              article.title(locale),
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (fs + 6).clamp(20.0, 32.0).toDouble(),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                height: 1.25,
              ),
            ),
            if (article.publishedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                _formatPublished(article.publishedAt!),
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: (fs - 3).clamp(11.0, 14.0).toDouble(),
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Hero image — falls back to a section-tinted placeholder
            // when no image was extracted (and when Image.network
            // errors out, e.g. CORS-blocked CDN). Pre-fix the
            // detail page just had a void where the image should be.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // 2026-05-07: webHtmlElementStrategy=prefer uses
              // <img> HTML element instead of XHR + canvas blit.
              // News-feed CDNs typically lack
              // Access-Control-Allow-Origin headers, so the
              // canvaskit XHR path was producing visible CORS
              // errors in the browser console for every detail
              // page open. <img> displays without same-origin
              // restrictions and silences that noise.
              child: (article.image != null && article.image!.isNotEmpty)
                  ? Image.network(
                      article.image!,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy:
                          WebHtmlElementStrategy.prefer,
                      // 2026-05-08 (v1.0.1 perf): hero image is
                      // displayed at 240 px tall on screens up to
                      // ~600 px wide. 1200 px cache width is
                      // generous (2× DPR) without holding the
                      // 4K/8K source bitmap in RAM.
                      cacheWidth: 1200,
                      cacheHeight: 480,
                      errorBuilder: (_, __, ___) =>
                          _ImagePlaceholder(section: article.section),
                    )
                  : _ImagePlaceholder(section: article.section),
            ),
            const SizedBox(height: 16),
            // Lede / standfirst — short summary in bold, then the
            // long-form body if the pipeline pulled one in.
            Text(
              article.summary(locale),
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (fs + 1).clamp(14.0, 18.0).toDouble(),
                color: scheme.onSurface,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_shouldShowBody(article, locale)) ...[
              const SizedBox(height: 14),
              _ArticleBody(
                text: article.body(locale),
                settings: settings,
                locale: locale,
                scheme: scheme,
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onOpenOrCopySource,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(
                (uiStrings['readOriginal']?[locale] ??
                        'Read original at {source}')
                    .replaceAll('{source}', article.source),
              ),
            ),
            const SizedBox(height: 24),

            // Bible reflection block.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book,
                          size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        uiStrings['bibleReflection']?[locale] ??
                            'Bible reflection',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontFamilyFallback: kCjkFontFallback,
                          fontSize:
                              (fs - 2).clamp(11.0, 14.0).toDouble(),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      article.verse.theme(locale),
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize:
                            (fs - 3).clamp(11.0, 14.0).toDouble(),
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.reflection(locale),
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: (fs).clamp(14.0, 18.0).toDouble(),
                      color: scheme.onSurface,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: onOpenReference,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories,
                              size: 16, color: scheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              article.verse.reference,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontFamilyFallback: kCjkFontFallback,
                                fontSize: (fs - 1)
                                    .clamp(13.0, 16.0)
                                    .toDouble(),
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward,
                              size: 14, color: scheme.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.verse.text(locale),
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize:
                          (fs - 1).clamp(13.0, 16.0).toDouble(),
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------

  /// Returns true when the long-form body adds meaningful content
  /// beyond the summary. Pipeline already guards against duplication
  /// for newly-built stories; this check additionally handles older
  /// cached payloads where body == summary, and the case where the
  /// requested locale's body is missing entirely.
  bool _shouldShowBody(NewsArticle article, String locale) {
    final body = article.body(locale).trim();
    if (body.isEmpty) return false;
    final summary = article.summary(locale).trim();
    if (body == summary) return false;
    // Body that's only slightly longer than the summary is usually
    // just the same first paragraph — not worth showing twice.
    if (body.length < summary.length + 80) return false;
    // Strong overlap signal: the summary is the literal opening
    // chunk of the body. Many RSS feeds publish identical text in
    // both slots.
    if (body.startsWith(summary)) {
      final extra = body.substring(summary.length).trim();
      if (extra.length < 80) return false;
    }
    return true;
  }

  String _sectionLabel(String id, String locale) {
    final m = uiStrings['newsSection${_cap(id)}'];
    if (m != null && m[locale] != null) return m[locale]!;
    return id.toUpperCase();
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatPublished(DateTime t) {
    // YYYY-MM-DD HH:mm — keep it simple, no intl dep.
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

/// Renders the long-form article body. Splits on blank lines so
/// paragraph spacing is honoured; falls back to a single block when
/// the source text didn't carry double-newlines.
class _ArticleBody extends StatelessWidget {
  final String text;
  final AppSettings settings;
  final String locale;
  final ColorScheme scheme;

  const _ArticleBody({
    required this.text,
    required this.settings,
    required this.locale,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final fs = settings.fontSize;
    // Split on 1+ blank line OR explicit double-newline. Most cleaned
    // RSS bodies arrive as one big paragraph; that's still readable
    // because the Text widget wraps naturally.
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final paras = paragraphs.isEmpty ? [text] : paragraphs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paras.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Text(
            paras[i],
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: fs.clamp(14.0, 18.0).toDouble(),
              color: scheme.onSurface,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// Section-tinted placeholder shown in place of the hero image when
/// the article has none (or the image URL fails to load). Avoids the
/// jarring void where a photo was meant to go.
class _ImagePlaceholder extends StatelessWidget {
  final String section;
  const _ImagePlaceholder({required this.section});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = section == 'china'
        ? scheme.tertiary
        : section == 'australia'
            ? scheme.secondary
            : scheme.primary;
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_outlined,
          size: 56,
          color: accent.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
