import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/song_download_service.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/widgets/localized_back_button.dart';

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
class SongScorePage extends StatelessWidget {
  final Song song;
  final String locale;
  const SongScorePage({super.key, required this.song, required this.locale});

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
      return PdfViewer.file(localPath, params: _params(context));
    }

    final blob = downloads.offlineScoreSourceFor(song);
    final target = blob ?? SongPlayerService.resolvePlaybackUrl(url);
    // The proxy rewrite yields a root-relative path ('/song-media/…').
    // Resolving against Uri.base makes it absolute without hard-coding
    // an origin, so it is correct on every deploy target.
    return PdfViewer.uri(
      Uri.base.resolve(target),
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
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
            if (url != null) ...[
              const SizedBox(height: 16),
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongScorePage(song: song, locale: locale),
      ),
    );
  }
}
