import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/media_focus.dart';
import 'package:yswords/utils/youtube_url.dart';
import 'package:yswords/widgets/youtube_embed.dart';

/// A YouTube video, played in a sheet over whatever the user was doing.
///
/// 2026-08-24, the user, looking at the YouTube-only rows in Songs:
/// "歌曲里面有几个是YouTube如果按了去YouTube了，但是web 和ios能不能不跳转
/// 出去，好像WhatsApp那样YouTube对话框在播放音乐，其实整个app都要这样".
/// The videos page had already stopped jumping out (2026-08-23), but it
/// did that with a player built into the page, so every OTHER YouTube
/// link in the app — the Songs chips, the row artwork tap on the 47
/// Cahaya rows, anything a misconception or an evidence note links to —
/// still handed the user to Safari or the YouTube app.
///
/// A page-shaped fix would have meant a player per page. Instead this is
/// one surface, reached from [LinkOpener.openOrWarn], the chokepoint
/// every external link in the app already goes through — which is what
/// makes "其实整个app都要这样" true by construction rather than by 17
/// files remembering.
///
/// The embed itself is not re-implemented here: [youtubeEmbed] already
/// carries the hard-won details (WebKit inline playback, the autoplay
/// that honours the tap that opened this, the wrapper page whose
/// `baseUrl` is what keeps YouTube from answering "Error 153"), and a
/// null return from it still means "this platform cannot embed".

/// Test seam for the embed.
///
/// A widget test runs on the host VM, where the io variant of
/// [youtubeEmbed] happily reports macOS as embeddable and then throws on
/// mount because no webview platform is registered. Injecting a
/// stand-in is the only way to exercise the sheet without a real
/// webview; it is null in every build, and both the capability check and
/// the player go through it so a test cannot get one and not the other.
@visibleForTesting
Widget? Function(String videoId)? debugYoutubeEmbedBuilder;

Widget? _embed(String videoId) =>
    (debugYoutubeEmbedBuilder ?? youtubeEmbed)(videoId);

/// The id of the video [url] points at, but only when this platform can
/// actually play it in-app; null otherwise.
///
/// Two ways to be null and both mean the same thing to a caller — open
/// the link the way you always did:
///   * [url] is not a YouTube video (SoundCloud, the church site, a
///     playlist, a mailto:), or
///   * it is, but [youtubeEmbed] has no player here. Windows and Linux
///     compile `webview_flutter` without an implementation, so the
///     check is a runtime one and lives inside the embed.
String? inAppYoutubeId(String url) {
  final id = youtubeVideoId(url);
  if (id == null) return null;
  return _embed(id) == null ? null : id;
}

/// Play [videoId] in a sheet. [watchUrl] is the address the user tapped,
/// kept for the escape hatch.
///
/// Returns when the sheet closes — which is also when playback stops,
/// since disposing the embed takes the webview (or the `<iframe>`) with
/// it. That is the whole reason the sound does not outlive the sheet.
Future<void> showYoutubeSheet(
  BuildContext context,
  String videoId, {
  required String watchUrl,
  String? locale,
}) async {
  // A video starting silences the hymn. The reverse cannot be honoured:
  // the embed owns its own playback and exposes no pause to us, so this
  // sheet deliberately does NOT register with MediaFocus as something
  // that can be paused. Claiming without registering is exactly that
  // asymmetry, made explicit — the same contract `videos_page._play`
  // documents, and the reason both sit on one side of it.
  await MediaFocus.instance.claim(_youtubeSheetFocus);
  if (!context.mounted) return;

  final loc = locale ?? Localizations.localeOf(context).toLanguageTag();
  await showModalBottomSheet<void>(
    // useSafeArea: without it Flutter wraps the sheet in
    // MediaQuery.removePadding(removeTop: true), so any SafeArea
    // INSIDE the sheet sees padding.top == 0 and does nothing —
    // the header then draws under the clock and the notch.
    useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _YoutubeSheet(
      videoId: videoId,
      locale: loc,
      // Closed over the OPENING context, not the sheet's: the escape
      // hatch pops the sheet before it launches, so by then the sheet's
      // own context is gone and only the page that opened it is left to
      // report a failed launch on.
      onWatchExternally: () async {
        if (!context.mounted) return;
        // openExternally, not openOrWarn: openOrWarn is what routed this
        // link into this sheet, and asking it again would reopen the
        // sheet on top of itself.
        await LinkOpener.openExternally(context, watchUrl, locale: loc);
      },
    ),
  );
}

/// The MediaFocus key. One token for the whole app rather than a State
/// object: this sheet is a function, and two of them cannot be up at
/// once anyway.
final Object _youtubeSheetFocus = Object();

class _YoutubeSheet extends StatelessWidget {
  const _YoutubeSheet({
    required this.videoId,
    required this.locale,
    required this.onWatchExternally,
  });

  final String videoId;
  final String locale;
  final Future<void> Function() onWatchExternally;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final embed = _embed(videoId);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'YouTube',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: uiStrings['close']?[locale] ?? 'Close',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // The 16:9 frame must fit the available HEIGHT, not only
            // the available width.
            //
            // 2026-08-24, caught in review before this shipped and
            // reproduced at four real phone-landscape sizes: sized off
            // width alone, the player demanded ~392 px of height inside
            // a 390 px viewport, so at 844x390 the Column overflowed by
            // 124 px — the video was clipped and the "Watch on YouTube"
            // escape hatch sat entirely below the screen with nothing
            // to scroll. Landscape is not hypothetical here: it is how
            // people watch video, the iOS plist allows both landscape
            // orientations, and nothing in the app calls
            // setPreferredOrientations.
            //
            // maxHeight leaves room for the header row, the escape
            // hatch and the sheet's own padding; the AspectRatio then
            // shrinks to whichever of width or height binds first.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height - 160,
              ),
              child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: const Color(0xFF000000),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  // Never null in practice: nothing opens this sheet
                  // without [inAppYoutubeId] having said yes first, and
                  // it asks the same builder. The fallback is here so a
                  // future caller that skips that check gets an empty
                  // frame with a working "Watch on YouTube" under it
                  // rather than a null-check crash.
                  child: embed ?? const SizedBox.shrink(),
                ),
              ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _watchOnYouTube(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(
                  uiStrings['videosWatchOnYouTube']?[locale] ??
                      'Watch on YouTube',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The escape hatch: comments, captions the embed will not show, the
  /// account the user is signed into. Staying in the app is the default,
  /// not a cage.
  Future<void> _watchOnYouTube(BuildContext sheetContext) async {
    // Close FIRST. The embed keeps playing while the sheet is up, so
    // handing the same video to YouTube on top of it would give the user
    // the thing MediaFocus exists to prevent — two soundtracks at once.
    Navigator.of(sheetContext).maybePop();
    await onWatchExternally();
  }
}
