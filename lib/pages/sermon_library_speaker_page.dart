import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/library_sermon.dart';
import 'package:yswords/pages/sermon_library_sermon_page.dart';
import 'package:yswords/services/sermon_library_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/scroll_to_top_on_status_bar_tap.dart';

/// One speaker's sermons, newest publication first, undated last.
///
/// **The name is in the AppBar and on none of the rows.** That is the
/// same rule `sermons_page.dart` follows and it lands the other way
/// round from the index one page back: there, the name varied between
/// rows and had to be on them; here it is constant down every row of
/// the list, and a constant repeated is an advert rather than a
/// credit.
///
/// Addressed by [speakerKey] — the credit string — rather than by
/// holding a `LibrarySpeaker`, so the page can be constructed before
/// the library has loaded and can be given a URL later without
/// changing shape.
class SermonLibrarySpeakerPage extends StatefulWidget {
  final String speakerKey;
  const SermonLibrarySpeakerPage({super.key, required this.speakerKey});

  @override
  State<SermonLibrarySpeakerPage> createState() =>
      _SermonLibrarySpeakerPageState();
}

class _SermonLibrarySpeakerPageState extends State<SermonLibrarySpeakerPage> {
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
    return FutureBuilder<SermonLibrary>(
      future: _future,
      builder: (context, snap) {
        final speaker = snap.data?.speakerByKey(widget.speakerKey);
        return Scaffold(
          appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(
              // The key IS the name, so the header is right on the
              // first frame instead of appearing a beat after the
              // spinner.
              librarySpeakerDisplayName(widget.speakerKey, locale),
              style: const TextStyle(fontWeight: FontWeight.w600),
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
            if (speaker == null) {
              // A key that names nobody — a stale link, or a corpus
              // that no longer credits this name. Say so; do not
              // bounce back to the index pretending it worked.
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
            final q = _query.trim().toLowerCase();
            final sermons = [
              for (final s in speaker.sermons)
                if (s.matchesQuery(q)) s,
            ];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20, color: scheme.onSurfaceVariant),
                      hintText: uiStrings['sermonLibrarySermonSearchHint']
                              ?[locale] ??
                          'Search title, book or series',
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
                      Text(
                        (uiStrings['sermonLibrarySermonCount']?[locale] ??
                                '{count} sermons')
                            .replaceAll('{count}', sermons.length.toString()),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      // Only ever on the 福音电台 page, and only
                      // because 27 of its records reached it by having
                      // no speaker at all. A reader shown 28 sermons
                      // under the station's name is owed the reason.
                      if (speaker.unattributedCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          (uiStrings['sermonLibraryUnattributed']?[locale] ??
                                  '{count} of these name no speaker upstream '
                                      'and are credited to the station, per '
                                      'its rights note.')
                              .replaceAll('{count}',
                                  speaker.unattributedCount.toString()),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: sermons.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              uiStrings['sermonNoMatches']?[locale] ??
                                  'No sermons match your filters.',
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.6),
                                fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                          ),
                        )
                      : ScrollToTopOnStatusBarTap(
                          controller: _scrollController,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                            itemCount: sermons.length,
                            itemBuilder: (context, i) => _SermonRow(
                              sermon: sermons[i],
                              locale: locale,
                              onTap: () => pushPage(SermonLibrarySermonPage(
                                  sermonId: sermons[i].id)),
                            ),
                          ),
                        ),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

/// One sermon in a speaker's list.
///
/// The date is labelled "published", never bare. These are WordPress
/// publication dates from 2014–24; the app's other sermon list prints
/// PREACHING dates from 1979–80 in the same visual slot, and an
/// unlabelled date here would be read as the same kind of thing. The
/// undated record shows no date line at all rather than a "—".
///
/// "Recording only" appears on the 96 rows that have audio and no
/// transcript, and on no others. It is not a badge saying there is
/// audio — 673 of 937 have that, and a mark on the majority tells the
/// reader nothing — it is a warning that tapping this row will not
/// produce text.
class _SermonRow extends StatelessWidget {
  final LibrarySermon sermon;
  final String locale;
  final VoidCallback onTap;

  const _SermonRow({
    required this.sermon,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final published = sermon.publishedAt == null
        ? null
        : (uiStrings['sermonLibraryPublished']?[locale] ?? 'Published {date}')
            .replaceAll('{date}', sermon.displayDate);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(
        sermon.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (published != null)
              Text(
                published,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            if (!sermon.hasText)
              Text(
                uiStrings['sermonLibraryAudioOnly']?[locale] ??
                    'Recording only',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            if ((sermon.book ?? '').isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sermon.book!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: scheme.onPrimaryContainer,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
          ],
        ),
      ),
      trailing: Icon(Icons.chevron_right,
          size: 20, color: scheme.onSurface.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }
}
