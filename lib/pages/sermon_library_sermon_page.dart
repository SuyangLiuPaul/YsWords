import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/library_sermon.dart';
import 'package:yswords/pages/sermon_detail_page.dart' show SermonByIdPage;
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/sermon_library_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/app_scroll_behavior.dart'
    show kSelectableTextPhysics;
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/sermon_library_chrome.dart';

/// One sermon from the 福音电台 library.
///
/// Addressed by post id rather than by a `LibrarySermon`, so a cold
/// entry point can be added later without changing the widget.
class SermonLibrarySermonPage extends StatefulWidget {
  final int sermonId;
  const SermonLibrarySermonPage({super.key, required this.sermonId});

  @override
  State<SermonLibrarySermonPage> createState() =>
      _SermonLibrarySermonPageState();
}

class _SermonLibrarySermonPageState extends State<SermonLibrarySermonPage> {
  late final Future<_SermonPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SermonPageData> _load() async {
    final library = await SermonLibraryService.instance.load();
    final sermon = library.byId[widget.sermonId];
    final body = sermon == null
        ? null
        : await SermonLibraryService.instance.loadBody(sermon);
    return _SermonPageData(library: library, sermon: sermon, body: body);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<_SermonPageData>(
      future: _future,
      builder: (context, snap) {
        final sermon = snap.data?.sermon;
        return Scaffold(
          appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(
              sermon?.title ?? uiStrings['sermon']?[locale] ?? 'Sermon',
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            actions: const [LanguageSwitcherButton(), HomeIconButton()],
          ),
          body: Builder(builder: (context) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}: ${snap.error}',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (sermon == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    uiStrings['sermonNotFound']?[locale] ?? 'Sermon not found.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }
            return _SermonBody(
              data: snap.data!,
              sermon: sermon,
              settings: settings,
            );
          }),
        );
      },
    );
  }
}

class _SermonPageData {
  final SermonLibrary library;
  final LibrarySermon? sermon;
  final String? body;
  const _SermonPageData({
    required this.library,
    required this.sermon,
    required this.body,
  });
}

class _SermonBody extends StatelessWidget {
  final _SermonPageData data;
  final LibrarySermon sermon;
  final AppSettings settings;

  const _SermonBody({
    required this.data,
    required this.sermon,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final body = data.body;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The speaker's name, once, here.
          //
          // Not a repeat of the AppBar on the list page one tap back:
          // it is the ONLY occurrence on this screen, and a reader who
          // arrived by a deep link or a search has passed under no
          // header at all. Doctrine 1 puts the credit where the reader
          // can find it once, not nowhere.
          Text(
            librarySpeakerDisplayName(sermon.credit, locale),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.primary,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Labelled "published", never bare — this is the
              // WordPress publication date, not the date it was
              // preached, and the app's other sermon pages print
              // preaching dates in the same slot. The one record with a
              // corrupt upstream year shows nothing here rather than a
              // date fifteen centuries wrong.
              if (sermon.publishedAt != null)
                Text(
                  (uiStrings['sermonLibraryPublished']?[locale] ??
                          'Published {date}')
                      .replaceAll('{date}', sermon.displayDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              if ((sermon.series ?? '').isNotEmpty)
                _Chip(text: sermon.series!, scheme: scheme),
              if ((sermon.book ?? '').isNotEmpty)
                _Chip(text: sermon.book!, scheme: scheme),
              for (final p in sermon.programmes) _Chip(text: p, scheme: scheme),
            ],
          ),
          const SizedBox(height: 10),
          SermonLibraryLanguageNote(locale: locale),
          // The link exists only where the grading says `confirmed`,
          // and it is read from the data on every load — so the pass
          // adjudicating the 36 `probable` pairs makes links appear
          // and disappear with no change here. An unadjudicated
          // candidate gets nothing, which is `MatthewMessage`'s rule:
          // no confirmed counterpart, no link rather than a plausible
          // one.
          if (data.library.refs.confirmedPairFor(sermon.id) != null) ...[
            const SizedBox(height: 12),
            _CounterpartCard(
              appSermonId:
                  data.library.refs.confirmedPairFor(sermon.id)!.appId,
              locale: locale,
            ),
          ],
          const SizedBox(height: 16),
          if (body == null)
            _NoTranscript(sermon: sermon, locale: locale)
          else
            _VerbatimBody(body: body, settings: settings),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(
                uiStrings['sermonLibraryOpenSource']?[locale] ??
                    'Open on fuyindiantai.org',
                style: const TextStyle(fontFamilyFallback: kCjkFontFallback),
              ),
              onPressed: sermon.url.isEmpty
                  ? null
                  : () => LinkOpener.openOrWarn(context, sermon.url),
            ),
          ),
          SermonLibraryRights(text: data.library.rightsFor(locale)),
        ],
      ),
    );
  }
}

/// The sermon body, exactly as the corpus stores it.
///
/// **Paragraphs are split on a SINGLE newline, and that is the whole
/// point.** All 843 body files in this corpus are paragraph-per-line —
/// measured, not assumed: zero of them contain a blank-line gap. The
/// other corpus's renderer in `sermon_detail_page.dart` splits on
/// `\n\s*\n`, and reusing it here would collapse every file into one
/// unbroken block of up to 202 paragraphs. That is not a layout
/// difference, it is the deletion of every paragraph break the
/// transcriber made. Nothing here inserts a break either.
/// Re-paragraphing or re-punctuating a preacher is making an
/// expressive decision he did not make; that rule is stated in
/// `sermon_detail_page.dart` and it is the same rule.
///
/// The three typography levers are the ones that page already settled,
/// and they change no character of the text: a line measure in `em` so
/// it tracks the reader's own font size (30 em, the CJK figure, since
/// every body here is Chinese), a 1.75 line height, and a two-em
/// first-line indent written as two U+3000 IDEOGRAPHIC SPACE
/// characters — a real space, because a leading `WidgetSpan` in
/// selectable text lands in the clipboard as U+FFFC.
class _VerbatimBody extends StatelessWidget {
  final String body;
  final AppSettings settings;

  const _VerbatimBody({required this.body, required this.settings});

  /// Split on single newlines, dropping only blank lines. Exposed for
  /// the test that proves a body keeps its paragraph count.
  static List<String> paragraphsOf(String body) => [
        for (final p in body.split('\n'))
          if (p.trim().isNotEmpty) p.trim(),
      ];

  @override
  Widget build(BuildContext context) {
    final fontSize = settings.fontSize;
    final paragraphs = paragraphsOf(body);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: fontSize * 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in paragraphs)
              Padding(
                padding: EdgeInsets.only(bottom: fontSize * 0.3),
                child: SelectableText(
                  '　　$p',
                  scrollPhysics: kSelectableTextPhysics,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.75,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown for the 96 records that have a recording and no transcript.
class _NoTranscript extends StatelessWidget {
  final LibrarySermon sermon;
  final String locale;
  const _NoTranscript({required this.sermon, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          uiStrings['sermonLibraryNoText']?[locale] ??
              'This sermon has no transcript.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      ),
    );
  }
}

/// "The app also holds another text of this sermon."
///
/// **It says that and nothing more.** These two corpora hold
/// independent renderings of the same preaching, not copies — the
/// scripture-fingerprint grading that found them reports 6-gram
/// containment peaking at 0.153 across all 105 candidate pairs — and
/// which rendering a reader should prefer is being settled elsewhere,
/// with evidence, and can differ pair by pair: two texts can be the
/// same sermon and still be a bad swap if one of them is truncated or
/// covers only part of the other. A card that announced a winner would
/// be printing a judgement this page does not hold. What it is for is
/// that a reader who meets both entries is told they are one sermon
/// instead of being left to wonder.
class _CounterpartCard extends StatelessWidget {
  final String appSermonId;
  final String locale;
  const _CounterpartCard({required this.appSermonId, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings['sermonLibraryAlsoInApp']?[locale] ??
                'The app also holds another text of this sermon.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: scheme.onSurface.withValues(alpha: 0.75),
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              // `SermonByIdPage` is the app's own by-id resolver for
              // the other corpus — it already handles an id that is no
              // longer in the index by saying so rather than by
              // redirecting somewhere plausible.
              onPressed: () => pushPage(
                SermonByIdPage(id: appSermonId),
                routeName: '/sermons/$appSermonId',
              ),
              child: Text(
                uiStrings['sermonLibraryOpenCounterpart']?[locale] ??
                    'Open the other text',
                style: const TextStyle(fontFamilyFallback: kCjkFontFallback),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _Chip({required this.text, required this.scheme});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: scheme.onPrimaryContainer,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      );
}
