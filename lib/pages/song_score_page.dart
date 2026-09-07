import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/song_copy.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/song_download_service.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/route_paths.dart' show songSubPagePath;
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/song_actions.dart';

/// Sheet music, shown inside the app.
///
/// 579 of 606 songs publish a PDF and every one of them used to leave
/// the app — on a phone that means a browser tab, a download prompt, or
/// (on iOS) Safari's own viewer, and no way back to the song that was
/// playing. Music you are meant to sing along to should not cost you
/// your place in the queue.
///
/// Source precedence, and it matters:
///   1. the downloaded file — a song taken offline has its score
///      offline too, which is the whole point of downloading it
///   2. the cached blob, on web, for the same reason
///   3. the network, through the same same-origin proxy the audio uses
///
/// (3) is not optional on web. `pdfrx` fetches the PDF with a normal
/// XHR, and none of the four church servers send
/// `Access-Control-Allow-Origin` — the request would be blocked before
/// a byte arrived. [SongPlayerService.resolvePlaybackUrl] rewrites it
/// onto our own origin; on native it returns the URL untouched, so
/// phones still stream straight from the church.
class SongScorePage extends StatefulWidget {
  final Song song;
  final String locale;
  const SongScorePage({super.key, required this.song, required this.locale});

  /// Whether the in-app viewer is available here.
  ///
  /// pdfrx renders through PDFium, which ships for every target this
  /// app builds — so unlike the video player there is no platform to
  /// exclude. Kept as a named predicate anyway so the call sites read
  /// the same as the video ones and a future gap has somewhere to go.
  static bool get isSupported => true;

  static Future<void> open(
      BuildContext context, Song song, String locale) async {
    if (song.scoreUrl == null) return;
    if (!isSupported) {
      await LinkOpener.openOrWarn(context, song.scoreUrl!, locale: locale);
      return;
    }
    // URL-routing Stage 5 (`docs/url-routing-plan.md` §6 batch 4). This
    // was a raw `Navigator.of(context).push(MaterialPageRoute(...))` —
    // one of the only two pushes in the app that bypassed `pushPage`
    // entirely, which §2 called out as "a real gap the 'pushPage is the
    // only way pages are pushed' assumption would have missed." A raw
    // MaterialPageRoute has no route name at all, so it could never
    // reach the address bar however the router was built. Routed
    // through `pushPage` with the registered path instead, so the score
    // is shareable and Back behaves like every other page's.
    await pushPage<void>(
      SongScorePage(song: song, locale: locale),
      routeName: songSubPagePath(song.id, 'score'),
    );
  }

  @override
  State<SongScorePage> createState() => _SongScorePageState();
}

class _SongScorePageState extends State<SongScorePage> {
  /// Bumped by Try again. It keys the viewer, so a retry builds a NEW
  /// PdfViewer rather than asking the failed one to reconsider —
  /// pdfrx caches its failure and would return it again.
  int _attempt = 0;

  Song get song => widget.song;
  String get locale => widget.locale;

  void _retry() => setState(() => _attempt++);

  @override
  Widget build(BuildContext context) {
    final url = song.scoreUrl;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: uiStrings['copySelection']?[locale] ?? 'Copy',
            // The song's own details, not the score file's URL: the
            // score is an image or a PDF behind a link that means
            // nothing pasted on its own, while the title and source are
            // what someone writing "which hymn was that" actually
            // wants. [songCopyText] already carries the source page.
            onPressed: () => ClipboardHelper.copyWithFeedback(
                context, songCopyText(song, locale)),
          ),
          // The song's link, not the score's. A shared PDF URL opens a
          // file; a shared song opens the song, score button and all.
          SongShareButton(song: song, locale: locale),
          if (url != null)
            IconButton(
              tooltip: uiStrings['songsOpenOriginal']?[locale] ??
                  'Original page',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => LinkOpener.openOrWarn(context, url, locale: locale),
            ),
        ],
      ),
      body: url == null ? _noScore(context) : _viewer(context, url),
    );
  }

  Widget _viewer(BuildContext context, String url) {
    final downloads = SongDownloadService.instance;

    final localPath = downloads.localScorePathFor(song);
    if (localPath != null) {
      return PdfViewer.file(
        localPath,
        key: ValueKey('score-file-${song.id}-$_attempt'),
        params: _params(context),
      );
    }

    final blob = downloads.offlineScoreSourceFor(song);
    final target = blob ?? SongPlayerService.resolvePlaybackUrl(url);
    // The proxy rewrite yields a root-relative path ('/song-media/…').
    // Resolving against Uri.base makes it absolute without hard-coding
    // an origin, so it is correct on every deploy target.
    return PdfViewer.uri(
      Uri.base.resolve(target),
      key: ValueKey('score-${song.id}-$_attempt'),
      params: _params(context),
    );
  }

  PdfViewerParams _params(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PdfViewerParams(
      backgroundColor: scheme.surfaceContainerLowest,
      // Engravings are dense; letting the reader in close is the
      // difference between usable and decorative on a phone.
      sizeDelegateProvider:
          PdfViewerSizeDelegateProviderLegacy(maxScale: 8),
      loadingBannerBuilder: (_, __, ___) =>
          const Center(child: CircularProgressIndicator()),
      errorBannerBuilder: (_, error, __, ___) => _loadFailed(context, error),
    );
  }

  /// A failure here is almost always the church's server or the
  /// network, not the file — so say what happened and leave a way out
  /// rather than showing an empty grey page.
  Widget _loadFailed(BuildContext context, Object error) {
    final scheme = Theme.of(context).colorScheme;
    final url = song.scoreUrl;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              uiStrings['songsScoreFailed']?[locale] ??
                  'The sheet music could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            // A reason, in words, instead of the raw exception.
            //
            // 2026-08-11 the user was shown "TimeoutException after
            // 0:00:05.000000: Future not completed", which tells them
            // nothing they can act on and looks like the app is broken.
            // A timeout here means the PDF's host did not answer — for
            // this song, fydt.org, which serves 578 of the 559 shown
            // songs' media and is unreachable from their network.
            Text(
              _describe(error, url, locale),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
            if (url != null) ...[
              const SizedBox(height: 16),
              // Retry first: for a timeout it is the fix, and leaving
              // the app for the original page is a much bigger ask.
              ...[
                FilledButton.tonalIcon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(uiStrings['retry']?[locale] ?? 'Try again'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => LinkOpener.openOrWarn(context, url, locale: locale),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(uiStrings['songsOpenOriginal']?[locale] ??
                    'Original page'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noScore(BuildContext context) => Center(
        child: Text(
          uiStrings['songsNoScore']?[locale] ??
              'This song has no sheet music.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );

}

/// Turn a load failure into something a reader can act on.
///
/// Falls back to the raw error for anything unrecognised — an
/// unhelpful string beats hiding a failure mode nobody anticipated.
///
/// **Says what happened, not what it means.** The first version of this
/// claimed "this network cannot reach it", and a screenshot showed why
/// that was wrong: the sheet music for a Christian Disciples Church
/// song failed while a Christian Disciples Church song was *playing*
/// from the same host in the mini-player underneath. The host was
/// reachable; pdfrx's fetch had simply given up after five seconds. A
/// timeout on our own short deadline is not evidence about the
/// network, and stating it as one sends the reader to debug their
/// wifi over what a retry would fix.
String _describe(Object? error, String? url, String locale) {
  final e = '$error'.toLowerCase();
  final host = url == null ? null : Uri.tryParse(url)?.host;

  // A refusal IS evidence about reachability; a timeout is not.
  final refused = e.contains('socketexception') ||
      e.contains('failed host lookup') ||
      e.contains('connection refused');
  if (refused) {
    return (uiStrings['songsScoreUnreachable']?[locale] ??
            'No answer from {host}. The file is there — this network '
                'cannot reach it.')
        .replaceFirst('{host}', host ?? '?');
  }

  if (e.contains('timeout')) {
    return (uiStrings['songsScoreTimedOut']?[locale] ??
            '{host} did not respond in time. Try again — a slow '
                'connection is enough to cause this.')
        .replaceFirst('{host}', host ?? '?');
  }

  return '$error';
}

/// URL-routing Stage 5 (`docs/url-routing-plan.md` §6 batch 4): the
/// cold-load resolver behind `/songs/:songId/score`.
///
/// Same shape as `SermonByIdPage` / `VideoSeriesByIdPage` /
/// `EvidenceByIdPage` / `MapByIdPage`: `GetPage.page`'s signature is
/// synchronous and the catalogue lookup is not, so the async id → [Song]
/// step gets its own widget rather than being faked at the route level.
/// Spinner while resolving, an explicit localized not-found for an
/// unknown id — never a silent redirect, per the rule Stage 4 set for
/// `/sermons/:id`: a bad shared link should say it's bad.
///
/// A song that exists but publishes no score renders the same
/// not-found state the page itself already shows for a null
/// `scoreUrl` — [SongScorePage] handles that case internally, so this
/// wrapper only answers "is there such a song."
class SongScoreByIdPage extends StatefulWidget {
  final String id;
  const SongScoreByIdPage({super.key, required this.id});

  @override
  State<SongScoreByIdPage> createState() => _SongScoreByIdPageState();
}

class _SongScoreByIdPageState extends State<SongScoreByIdPage> {
  Song? _song;
  bool _resolving = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final found = await SongService.byId(widget.id);
    if (!mounted) return;
    setState(() {
      _song = found;
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final locale = Provider.of<AppSettings>(context, listen: false).locale;
    final song = _song;
    if (song == null) return SongNotFoundScaffold(locale: locale);
    return SongScorePage(song: song, locale: locale);
  }
}

/// The not-found body shared by both song sub-page resolvers
/// (`/songs/:songId/score`, `/songs/:songId/video`). Extracted because
/// the two are word-for-word identical and the string is the same one —
/// what a stale link is missing is the song, not the score or the video.
class SongNotFoundScaffold extends StatelessWidget {
  final String locale;
  const SongNotFoundScaffold({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const LocalizedBackButton()),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            uiStrings['songNotFound']?[locale] ?? 'Song not found.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}
