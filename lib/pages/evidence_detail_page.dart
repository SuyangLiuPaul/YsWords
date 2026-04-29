import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/widgets/confidence_badge.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Full-page view of one [BibleEvidence] entry.
///
/// Layout:
///   • Hero image (or icon fallback)
///   • Title + confidence badge
///   • Quick metadata (location, discovered, timeline, category)
///   • Summary
///   • Detailed description
///   • Scripture correlation block — tap the reference to jump
///     into the reader at that chapter
///   • Academic sources (copy-on-tap)
class EvidenceDetailPage extends StatelessWidget {
  final BibleEvidence evidence;
  const EvidenceDetailPage({super.key, required this.evidence});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final fs = settings.fontSize;
    final hasImage = evidence.images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          evidence.localizedTitle(locale),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: uiStrings['share']?[locale] ?? 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context, locale),
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
              // Hero image area.
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    evidence.images.first,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _IconHero(icon: evidence.icon),
                  ),
                )
              else
                _IconHero(icon: evidence.icon),
              const SizedBox(height: 16),

              // Title + confidence badge row.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      evidence.localizedTitle(locale),
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: (fs + 6).clamp(20.0, 32.0).toDouble(),
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConfidenceBadge(
                    level: evidence.confidenceLevel,
                    color: evidence.confidenceColor(scheme),
                    prominent: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Metadata chips.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (evidence.category.isNotEmpty)
                    _Meta(
                      icon: Icons.category_outlined,
                      label: evidence.category,
                    ),
                  if (evidence.timeline.isNotEmpty)
                    _Meta(
                      icon: Icons.schedule,
                      label: evidence.timeline,
                    ),
                  if (evidence.discoveryDate.isNotEmpty)
                    _Meta(
                      icon: Icons.event_outlined,
                      label: evidence.discoveryDate,
                    ),
                  if (evidence.location.isNotEmpty)
                    _Meta(
                      icon: Icons.place_outlined,
                      label: evidence.location,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary.
              if (evidence.localizedSummary(locale).isNotEmpty) ...[
                Text(
                  evidence.localizedSummary(locale),
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: fs,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurface,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Description.
              if (evidence.localizedDescription(locale).isNotEmpty) ...[
                _Section(
                  label: uiStrings['evidenceDescription']?[locale] ??
                      'Description',
                  child: Text(
                    evidence.localizedDescription(locale),
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: fs,
                      color: scheme.onSurface,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Scripture correlation + tappable reference.
              _Section(
                label: uiStrings['scripturalCorrelation']?[locale] ??
                    'Scriptural correlation',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (evidence
                        .localizedCorrelation(locale)
                        .isNotEmpty) ...[
                      Text(
                        evidence.localizedCorrelation(locale),
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: fs,
                          color: scheme.onSurface,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (evidence.scriptureReference.isNotEmpty)
                      _ReferenceChip(
                        reference: evidence.scriptureReference,
                        locale: locale,
                        onTap: () => _openReference(context),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Academic sources.
              if (evidence.academicSources.isNotEmpty) ...[
                _Section(
                  label: uiStrings['academicSources']?[locale] ??
                      'Academic sources',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final src in evidence.academicSources)
                        _SourceTile(text: src),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, String locale) async {
    final body = StringBuffer()
      ..writeln(evidence.localizedTitle(locale))
      ..writeln('— ${evidence.confidenceLevel} | '
          '${evidence.category} | ${evidence.scriptureReference}')
      ..writeln()
      ..writeln(evidence.localizedSummary(locale))
      ..writeln()
      ..writeln(evidence.localizedDescription(locale));
    await ClipboardHelper.shareOrCopy(context, body.toString().trim(),
        title: evidence.localizedTitle(locale));
  }

  void _openReference(BuildContext context) {
    final ref = parseReference(evidence.scriptureReference);
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
      final relIdx =
          matches.indexWhere((v) => v.verse == hit.verse);
      if (relIdx < 0) return;
      mp.jumpToIndex(index: relIdx);
      mp.setHighlightIndex(relIdx);
      Future.delayed(const Duration(milliseconds: 900),
          () => mp.clearHighlightIndex());
    });
  }
}

class _IconHero extends StatelessWidget {
  final String icon;
  const _IconHero({required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(icon, style: const TextStyle(fontSize: 80)),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize:
                  (settings.fontSize - 3).clamp(11.0, 15.0).toDouble(),
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize:
                  (settings.fontSize - 3).clamp(11.0, 15.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: scheme.primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  final String reference;
  final String locale;
  final VoidCallback onTap;

  const _ReferenceChip({
    required this.reference,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    return Material(
      color: scheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                reference,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: settings.fontSize,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward,
                  size: 14, color: scheme.primary),
              const SizedBox(width: 2),
              Text(
                uiStrings['readInBible']?[locale] ?? 'Read',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize:
                      (settings.fontSize - 3).clamp(11.0, 15.0).toDouble(),
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String text;
  const _SourceTile({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    // No url_launcher dep yet — tap copies the citation. The user
    // can paste into a browser tab if there's a link in there.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await ClipboardHelper.copyWithFeedback(context, text);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Icon(
                  Icons.format_quote,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: (settings.fontSize - 2)
                        .clamp(12.0, 17.0)
                        .toDouble(),
                    color: scheme.onSurface,
                    height: 1.4,
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
