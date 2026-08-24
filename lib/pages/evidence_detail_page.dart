import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/motion.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/jump_to_reference.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show localizedReferenceLabel;
import 'package:yswords/widgets/confidence_badge.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

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
class EvidenceDetailPage extends StatefulWidget {
  final BibleEvidence evidence;
  const EvidenceDetailPage({super.key, required this.evidence});

  @override
  State<EvidenceDetailPage> createState() => _EvidenceDetailPageState();
}

class _EvidenceDetailPageState extends State<EvidenceDetailPage> {
  // 2026-05-23 (v1.2.80): hero is now a swipeable PageView showing all
  // images in the evidence.images array. Dot indicator below tracks
  // the current page so the user knows there are siblings to swipe to.
  late final PageController _imagePageController;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  BibleEvidence get evidence => widget.evidence;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final fs = settings.fontSize;
    final images = evidence.images;
    final hasImage = images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          evidence.localizedTitle(locale),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 2026-05-24 (v1.3.19): ListenButton (AI TTS) removed with
          // the rest of the 朗读 feature.
          IconButton(
            tooltip: uiStrings['share']?[locale] ?? 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context, locale),
          ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Hero image gallery — swipeable PageView showing every
              // image in `evidence.images`. v1.2.81: made discovery
              // much more obvious. User reported "iOS doesn't show
              // many images, web app also doesn't, like Hittite
              // Empire" — the data has 4 images, the gallery was
              // there, but the 6-px dot indicator was too subtle to
              // notice. Now: prominent counter chip + arrow hints
              // + thumbnail filmstrip below.
              if (hasImage)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 240,
                            width: double.infinity,
                            child: PageView.builder(
                              controller: _imagePageController,
                              itemCount: images.length,
                              physics: images.length > 1
                                  ? const PageScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              onPageChanged: (i) =>
                                  setState(() => _imageIndex = i),
                              itemBuilder: (_, i) => Image.network(
                                images[i],
                                fit: BoxFit.cover,
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.prefer,
                                cacheWidth: 1200,
                                cacheHeight: 480,
                                errorBuilder: (_, __, ___) =>
                                    _HeroShimmer(
                                  category: evidence.category,
                                  showCategoryIcon: true,
                                ),
                                loadingBuilder: (_, child, p) {
                                  if (p == null) return child;
                                  return _HeroShimmer(
                                      category: evidence.category);
                                },
                              ),
                            ),
                          ),
                          // "N/total" counter chip — top-right of
                          // the hero, only when there's more than one
                          // image. Dark background + white text reads
                          // over any photo.
                          if (images.length > 1)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius:
                                      BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library_outlined,
                                        size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_imageIndex + 1}/${images.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Side-arrow hints — make swipe affordance
                          // explicit. Tapping advances by one image
                          // (in case the user prefers tap-to-advance
                          // over swipe).
                          if (images.length > 1 && _imageIndex > 0)
                            Positioned(
                              left: 4,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _ArrowChip(
                                  icon: Icons.chevron_left_rounded,
                                  onTap: () => _imagePageController
                                      .previousPage(
                                    duration: AppMotion.standard,
                                    curve: AppMotion.enter,
                                  ),
                                ),
                              ),
                            ),
                          if (images.length > 1 &&
                              _imageIndex < images.length - 1)
                            Positioned(
                              right: 4,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _ArrowChip(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: () => _imagePageController.nextPage(
                                    duration: AppMotion.standard,
                                    curve: AppMotion.enter,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Below the hero: thumbnail filmstrip. Each
                    // thumbnail is tappable to jump directly to that
                    // page. Active thumbnail gets a colored ring.
                    if (images.length > 1) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final active = i == _imageIndex;
                            return InkWell(
                              onTap: () => _imagePageController.animateToPage(
                                i,
                                duration: AppMotion.standard,
                                curve: AppMotion.enter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 72,
                                height: 56,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: active
                                        ? scheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Image.network(
                                  images[i],
                                  fit: BoxFit.cover,
                                  webHtmlElementStrategy:
                                      WebHtmlElementStrategy.prefer,
                                  cacheWidth: 200,
                                  cacheHeight: 144,
                                  errorBuilder: (_, __, ___) =>
                                      _HeroShimmer(
                                    category: evidence.category,
                                    showCategoryIcon: true,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                )
              else
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: _HeroShimmer(
                    category: evidence.category,
                    showCategoryIcon: true,
                  ),
                ),
              const SizedBox(height: 16),

              // Title + confidence badge row.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      evidence.localizedTitle(locale),
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                      label: evidence.localizedCategory(locale),
                    ),
                  if (evidence.localizedTimeline(locale).isNotEmpty)
                    _Meta(
                      icon: Icons.schedule,
                      label: evidence.localizedTimeline(locale),
                    ),
                  if (evidence.localizedDiscoveryDate(locale).isNotEmpty)
                    _Meta(
                      icon: Icons.event_outlined,
                      label: evidence.localizedDiscoveryDate(locale),
                    ),
                  if (evidence.localizedLocation(locale).isNotEmpty)
                    _Meta(
                      icon: Icons.place_outlined,
                      label: evidence.localizedLocation(locale),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary.
              if (evidence.localizedSummary(locale).isNotEmpty) ...[
                Text(
                  evidence.localizedSummary(locale),
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
                        onOpen: (segment) =>
                            _openSegment(context, segment),
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
    final currentVersion = context.read<MainProvider>().currentVersion;
    final body = StringBuffer()
      ..writeln(evidence.localizedTitle(locale))
      ..writeln('— ${evidence.localizedConfidenceLevel(locale)} | '
          '${evidence.localizedCategory(locale)} | '
          '${localizedReferenceLabel(evidence.scriptureReference, locale, currentVersion)}')
      ..writeln()
      ..writeln(evidence.localizedSummary(locale))
      ..writeln()
      ..writeln(evidence.localizedDescription(locale));
    await ClipboardHelper.shareOrCopy(context, body.toString().trim(),
        title: evidence.localizedTitle(locale));
  }

  /// Cross-link to the reader at the cited verse. Uses the
  /// `MainProvider.setPendingJump` handshake so the scroll +
  /// highlight fire whenever the reader is actually ready, instead
  /// of relying on a fragile timer. See
  /// `lib/widgets/bible_reading_pane.dart` for the consumer side.
  ///
  /// **Version fallback**: many evidence entries cite OT books
  /// (`2 Kings 25:27-30`, `1 Chronicles 29:1`, `Nehemiah 3:26-27`, …),
  /// but the user might be reading an NT-only translation like LJK1
  /// or LJK2. In that case the verse simply isn't in `mp.verses` and
  /// the previous version of this method silently returned with no
  /// navigation — looking like the link was dead.
  ///
  /// We now mirror the daily-verse fallback strategy: if the current
  /// version doesn't have the book, transparently switch to a
  /// full-canon companion (CUVS-YHWH for Simplified, CUVS-YHWH-TR
  /// for Traditional, ESV for English) for the duration of this jump,
  /// reload verses, retry the lookup, then navigate. A SnackBar tells
  /// the user we switched so they're not confused when the version
  /// label changes in the reader header.
  Future<void> _openSegment(
      BuildContext context, CitationSegment segment) async {
    final ref = segment.target;
    if (ref == null) {
      final locale = context.read<AppSettings>().locale;
      final msg = (uiStrings['couldNotParseRef']?[locale] ??
              "Couldn't parse reference: {ref}")
          .replaceFirst('{ref}', segment.text);
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
    pushPage(const HomePage(), routeName: '/HomePage');
  }
}

/// Floating navigation chip overlaid on the hero gallery for the
/// Bible Evidence detail page. Black-on-white circular button — the
/// user can tap-to-advance one image without having to swipe, which
/// is the standard discoverability pattern for image galleries on
/// the web (Instagram + Wikipedia commons viewer both use it).
class _ArrowChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowChip({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

/// Category-tinted gradient shown while the detail hero image loads
/// OR when there's no image / it errors out. Used in BOTH cases so
/// the user never sees the 80-px emoji that older builds emitted.
/// Same visual language as evidence_page.dart's `_ShimmerPlaceholder`
/// to keep grid + detail consistent.
class _HeroShimmer extends StatelessWidget {
  final String category;
  final bool showCategoryIcon;
  const _HeroShimmer({
    required this.category,
    this.showCategoryIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (accent, icon) = switch (category) {
      'Manuscripts' => (scheme.tertiary, Icons.menu_book_outlined),
      'Archaeology' => (scheme.primary, Icons.terrain_outlined),
      'History'     => (scheme.secondary, Icons.account_balance_outlined),
      'Science'     => (scheme.tertiary, Icons.science_outlined),
      _             => (scheme.primary, Icons.image_outlined),
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.08),
            scheme.surfaceContainerHighest.withValues(alpha: 0.42),
          ],
        ),
      ),
      child: showCategoryIcon
          ? Center(
              child: Icon(
                icon,
                size: 64,
                color: accent.withValues(alpha: 0.55),
              ),
            )
          : null,
    );
  }
}

// v1.2.78: `_IconHero` removed. Was the 80-px emoji hero shown when an
// entry had no image or when Image.network errored out; replaced by
// `_HeroShimmer(showCategoryIcon: true)` which uses a Material category
// icon over the gradient — no emoji.

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
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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

/// The 「经文对应」 affordance under an evidence entry.
///
/// One cited passage renders as ONE flowing chip; two or more render as
/// a chip each. 2026-08-16, from the phone: 「那个经文其实是两个，但是按了
/// 好像只能去一个，另个去不了」 — the chip was a single tap target that
/// always jumped to the first reference, so every passage after the
/// first was unreachable. Reading the citation and not being able to
/// follow it is the same defect class as printing the wrong one: the
/// card offers a passage it does not actually give.
///
/// 21 of the 225 entries cite more than one passage — 17 with `;` and 4
/// with a comma. A comma continuation is chipped exactly as the source
/// wrote it (「52」, 「37-38」), not expanded, so the card goes on citing
/// what the entry cites; the chips sit in source order, which is how the
/// citation reads on paper.
///
/// Separate chips rather than a `TapGestureRecognizer` per span — an
/// outer `InkWell` and a span recognizer both enter the gesture arena,
/// and the flowing-paragraph layout below was itself a fix that a `Row`
/// broke. 204 of the 225 entries go down the single-reference path.
///
/// A citation that resolves to nothing renders as plain text on BOTH
/// paths. The multi path already did; the single one wired `onTap`
/// unconditionally and could only answer "couldn't parse", which is an
/// affordance that lies about the citation rather than a link that is
/// merely broken.
class _ReferenceChip extends StatelessWidget {
  final String reference;
  final String locale;
  final void Function(CitationSegment) onOpen;

  const _ReferenceChip({
    required this.reference,
    required this.locale,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final segments = splitCitation(reference);
    if (segments.length > 1) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final segment in segments)
            _SegmentChip(
              segment: segment,
              locale: locale,
              onTap: segment.target == null ? null : () => onOpen(segment),
            ),
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final currentVersion = context.watch<MainProvider>().currentVersion;
    final whole = segments.isEmpty
        ? CitationSegment(reference.trim(), parseReference(reference))
        : segments.first;
    // Laid out as ONE flowing paragraph, not a Row.
    //
    // 2026-08-11, second report on this chip. Making the reference
    // Flexible stopped it being cut off, but a Row places its trailing
    // children beside the whole text BLOCK, not after the last word —
    // so with two references the 「→ 阅读经文」 sat at the end of line
    // one and 「10:26」 continued underneath it. Correct, and unreadable.
    //
    // WidgetSpans put the icons in the text stream, so everything wraps
    // together and the affordance always follows the last reference,
    // however many there are.
    final label = Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.menu_book_outlined,
                  size: 16, color: scheme.primary),
            ),
          ),
          TextSpan(
            text: localizedReferenceLabel(reference, locale, currentVersion),
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: settings.fontSize,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          if (whole.target != null) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward,
                    size: 14, color: scheme.primary),
              ),
            ),
            TextSpan(
              text: uiStrings['readInBible']?[locale] ?? 'Read',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize:
                    (settings.fontSize - 3).clamp(11.0, 15.0).toDouble(),
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (whole.target == null) {
      return Padding(padding: padding, child: label);
    }
    return Material(
      color: scheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOpen(whole),
        child: Padding(padding: padding, child: label),
      ),
    );
  }
}

/// One cited passage of a multi-reference citation.
///
/// [onTap] is null when the segment resolves to nothing, so an
/// unresolvable part is shown as plain text rather than as a tap target
/// that can only answer "couldn't parse".
class _SegmentChip extends StatelessWidget {
  final CitationSegment segment;
  final String locale;
  final VoidCallback? onTap;

  const _SegmentChip({
    required this.segment,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final currentVersion = context.watch<MainProvider>().currentVersion;
    final label = Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.menu_book_outlined,
                  size: 16, color: scheme.primary),
            ),
          ),
          TextSpan(
            text:
                localizedReferenceLabel(segment.text, locale, currentVersion),
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: settings.fontSize,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          if (onTap != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.arrow_forward,
                    size: 14, color: scheme.primary),
              ),
            ),
        ],
      ),
    );
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (onTap == null) {
      return Padding(padding: padding, child: label);
    }
    return Material(
      color: scheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(padding: padding, child: label),
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
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
