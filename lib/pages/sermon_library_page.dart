import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/library_sermon.dart';
import 'package:yswords/pages/sermon_library_speaker_page.dart';
import 'package:yswords/services/sermon_library_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/press_scale.dart';
import 'package:yswords/widgets/scroll_to_top_on_status_bar_tap.dart';
import 'package:yswords/widgets/sermon_library_chrome.dart';

/// The 福音电台 sermon library, browsable by speaker.
///
/// A SEPARATE corpus from the 289 on `SermonsPage`, and deliberately a
/// separate surface: those are one man's expository series with
/// preaching dates from 1979–80 and bodies in three languages, these
/// are 937 radio messages by 71 credited speakers with publication
/// dates from 2014–24 and one language. Merging the two lists would
/// merge two date semantics and two provenances into rows a reader
/// could not tell apart.
///
/// **Three pages, not collapsible groups.** The obvious move was to
/// copy `SermonsPage`'s `ExpansionTile` topic groups, and it is the
/// wrong one twice over. 张成牧师 has 201 sermons, and 201 rows inside
/// one expansion tile is the setup that produced a real bug in this
/// codebase — a list test that passed against anything at all, because
/// rows inside a collapsed `ExpansionTile` are never built and
/// `find.byIcon` therefore found nothing whatever was inserted. At the
/// other end, 52 speakers have exactly one sermon: 52 disclosure
/// controls that disclose one row each. So: an index of speakers here,
/// their sermons on [SermonLibrarySpeakerPage], one sermon on
/// `SermonLibrarySermonPage`.
///
/// **The name is on the row, and that is doctrine 1, not a breach of
/// it.** `sermons_page.dart` puts its preacher in the AppBar because
/// with one preacher the name is constant down 289 rows and a constant
/// repeated is an advert. Here the name is the varying fact — it is
/// what the reader is choosing between — so it belongs on the row, and
/// the byline above is the source that published them all.
class SermonLibraryPage extends StatefulWidget {
  const SermonLibraryPage({super.key});

  @override
  State<SermonLibraryPage> createState() => _SermonLibraryPageState();
}

class _SermonLibraryPageState extends State<SermonLibraryPage> {
  late final Future<SermonLibrary> _future;
  late final ScrollController _scrollController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = SermonLibraryService.instance.load();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uiStrings['sermonLibrary']?[locale] ?? 'Sermon Library',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            // The byline names the SOURCE, not a person. 71 speakers
            // means no one name is true of the page; the station that
            // published all of them is.
            Text(
              uiStrings['sermonLibrarySource']?[locale] ?? 'FYDT 福音电台',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                fontFamilyFallback: kCjkFontFallback,
                color: (Theme.of(context).appBarTheme.foregroundColor ??
                        scheme.onPrimary)
                    .withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: FutureBuilder<SermonLibrary>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            // Not degraded to an empty list on purpose: an empty
            // library and a missing asset look identical from the
            // outside, and only one of them is normal.
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
          final library = snap.data!;
          final q = _query.trim().toLowerCase();
          final speakers = q.isEmpty
              ? library.speakers
              : [
                  for (final s in library.speakers)
                    if (s.name.toLowerCase().contains(q) ||
                        librarySpeakerDisplayName(s.name, locale)
                            .toLowerCase()
                            .contains(q))
                      s,
                ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                    hintText: uiStrings['sermonLibrarySearchHint']?[locale] ??
                        'Search speakers',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Both counts DERIVED from what was loaded. Neither
                    // 71 nor 937 is written down anywhere in this
                    // feature, so the sentence survives the corpus
                    // growing or shrinking — the failure
                    // `sermon_credit.dart` records as the 289-vs-587
                    // bug was a number nobody could check.
                    Text(
                      _summary(library, locale),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SermonLibraryLanguageNote(locale: locale),
                  ],
                ),
              ),
              Expanded(
                child: speakers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            uiStrings['sermonLibraryNoSpeakers']?[locale] ??
                                'No speakers match your search.',
                            style: TextStyle(
                              color:
                                  scheme.onSurface.withValues(alpha: 0.6),
                              fontFamilyFallback: kCjkFontFallback,
                            ),
                          ),
                        ),
                      )
                    : ScrollToTopOnStatusBarTap(
                        controller: _scrollController,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          // +1 for the rights footer, which sits at the
                          // foot of the list rather than pinned: it is
                          // a notice attached to the work, not a
                          // control, and it should scroll away.
                          itemCount: speakers.length + 1,
                          itemBuilder: (context, i) {
                            if (i == speakers.length) {
                              return SermonLibraryRights(
                                  text: library.rightsFor(locale));
                            }
                            final s = speakers[i];
                            return _SpeakerRow(
                              speaker: s,
                              locale: locale,
                              onTap: () => pushPage(
                                  SermonLibrarySpeakerPage(speakerKey: s.key)),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _summary(SermonLibrary library, String locale) {
    final tmpl = uiStrings['sermonLibrarySpeakers']?[locale] ??
        '{speakers} speakers · {count} sermons';
    return tmpl
        .replaceAll('{speakers}', library.speakers.length.toString())
        .replaceAll('{count}', library.sermons.length.toString());
  }
}

/// One speaker: their name, how many sermons, and — for the one row
/// that is a radio programme rather than a person — a label saying so.
///
/// **The count is on the row and it earns its place there.** It runs
/// from 201 down to 1; it is the variable the reader is choosing on,
/// which is precisely what `sermonAudioClause`'s rule admits. What that
/// rule bans is a mark true of every row, and it is why the count is
/// plain subtitle text rather than a badge: 52 speakers have exactly
/// one sermon, and 52 identical pills reading "1" would be the
/// decoration the rule is about even though the number is not.
class _SpeakerRow extends StatelessWidget {
  final LibrarySpeaker speaker;
  final String locale;
  final VoidCallback onTap;

  const _SpeakerRow({
    required this.speaker,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tmpl = uiStrings['sermonLibrarySermonCount']?[locale] ??
        '{count} sermons';
    return PressScale(
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              speaker.isProgramme
                  ? Icons.radio_outlined
                  : Icons.record_voice_over_outlined,
              size: 18,
              color: scheme.primary,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  librarySpeakerDisplayName(speaker.name, locale),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Exactly one row carries this — 奇妙恩典, whose
              // `authorKind` is "programme". A list headed "speakers"
              // that silently included a radio show would be a small
              // lie, and a mark true of one row in 71 is the opposite
              // of decoration.
              if (speaker.isProgramme) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    uiStrings['sermonLibraryProgramme']?[locale] ??
                        'Programme',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSecondaryContainer,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            tmpl.replaceAll('{count}', speaker.count.toString()),
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.6),
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          trailing: Icon(Icons.chevron_right,
              size: 20, color: scheme.onSurface.withValues(alpha: 0.4)),
          onTap: onTap,
        ),
      ),
    );
  }
}
