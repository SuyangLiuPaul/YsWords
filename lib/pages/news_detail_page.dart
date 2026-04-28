import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/news_article.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/reference_parser.dart' show parseReference;
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Full-page view of a single [NewsArticle]: image, title, summary,
/// thematic Bible verse + reflection, and a tap-target to jump into
/// the reader at the cited verse (same pattern as `EvidenceDetailPage`).
class NewsDetailPage extends StatelessWidget {
  final NewsArticle article;
  const NewsDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final fs = settings.fontSize;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          article.source,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: uiStrings['share']?[locale] ?? 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context, locale),
          ),
          IconButton(
            tooltip: uiStrings['openSource']?[locale] ?? 'Open original',
            icon: const Icon(Icons.open_in_new_outlined),
            onPressed: () => _copySource(context, locale),
          ),
          const HomeIconButton(),
        ],
      ),
      body: Center(
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
                  fontSize: (fs - 3).clamp(10.0, 13.0).toDouble(),
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
                    fontSize: (fs - 3).clamp(10.0, 13.0).toDouble(),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (article.image != null && article.image!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    article.image!,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                article.summary(locale),
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: (fs + 1).clamp(14.0, 18.0).toDouble(),
                  color: scheme.onSurface,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _copySource(context, locale),
                icon: const Icon(Icons.link, size: 16),
                label: Text(
                  (uiStrings['readOriginal']?[locale] ??
                          'Copy link to {source}')
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
                            fontSize: (fs - 2)
                                .clamp(11.0, 14.0)
                                .toDouble(),
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
                          fontSize: (fs - 3)
                              .clamp(10.0, 13.0)
                              .toDouble(),
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
                        fontSize:
                            (fs).clamp(14.0, 18.0).toDouble(),
                        color: scheme.onSurface,
                        height: 1.55,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _openReference(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(Icons.auto_stories,
                                size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              article.verse.reference,
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontSize: (fs - 1)
                                    .clamp(13.0, 16.0)
                                    .toDouble(),
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
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
                        fontSize: (fs - 1)
                            .clamp(13.0, 16.0)
                            .toDouble(),
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
      ),
    );
  }

  // -----------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------

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

  /// We don't depend on url_launcher (see comment in evidence_detail_page.dart).
  /// Tap copies the URL so the user can paste it into a browser.
  Future<void> _copySource(BuildContext context, String locale) async {
    if (article.link.isEmpty) return;
    await ClipboardHelper.shareOrCopy(
      context,
      article.link,
      title: article.source,
    );
  }

  Future<void> _share(BuildContext context, String locale) async {
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
  void _openReference(BuildContext context) {
    final ref = parseReference(article.verse.reference);
    if (ref == null) return;
    final mp = context.read<MainProvider>();
    final localBook = translateBookName(ref.englishBook, mp.currentVersion);
    final matches = mp.verses
        .where((v) => v.book == localBook && v.chapter == ref.chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    if (matches.isEmpty) return;
    final target = ref.verseStart ?? matches.first.verse;
    final hit = matches.firstWhere(
      (v) => v.verse == target,
      orElse: () => matches.first,
    );
    mp.setCurrentChapter(book: hit.book, chapter: hit.chapter);
    mp.updateCurrentVerse(verse: hit);
    Get.to(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
    Future.delayed(const Duration(milliseconds: 320), () {
      final relIdx = matches.indexWhere((v) => v.verse == hit.verse);
      if (relIdx < 0) return;
      mp.jumpToIndex(index: relIdx);
      mp.setHighlightIndex(relIdx);
      Future.delayed(const Duration(milliseconds: 900),
          () => mp.clearHighlightIndex());
    });
  }
}
