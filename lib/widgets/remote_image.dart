import 'package:flutter/material.dart';

/// `Image.network` that fails fast, fails quietly, and fails once.
///
/// 2026-08-11, crash report from an iPhone on v1.4.39:
///
///     SocketException: Operation timed out (OS Error: ..., errno = 60)
///       #10 NetworkImage._loadAsync
///       #15 ScrollAwareImageProvider.resolveStreamForKey
///
/// The song-list artwork thumbnails, pointed at fydt.org, which was
/// refusing connections all night. Three separate problems, all of them
/// in how `Image.network` behaves rather than in the URLs:
///
/// **1. There is no timeout.** `NetworkImage` exposes no knob for one —
/// it hands the request to `HttpClient` and waits for the OS, which on
/// iOS is ~60s and surfaces as errno 60. Scrolling a list of songs from
/// an unreachable host opens one such socket per row and holds them all.
///
/// **2. Every row retries independently, forever.** Nothing remembers
/// that the host just failed, so the cost is paid per row, per rebuild,
/// per scroll back. [_failedAt] memoises failures per URL so a dead host
/// is asked once and then left alone for [_retryAfter] — and comes back
/// on its own when the site does.
///
/// **3. Full-size decodes into a 40×40 slot.** The same report carried a
/// `memory:pressure — caches dropped` breadcrumb. Album art is served at
/// full resolution; decoding it at display size instead is the
/// difference between kilobytes and megabytes per thumbnail. Callers
/// pass [cacheWidth]/[cacheHeight] and get exactly that.
///
/// The error is also swallowed deliberately. An unreachable image is not
/// a defect worth a crash report — it is a church web server having a
/// bad night, and it must not drown the reporter that real bugs arrive
/// through.
///
/// ---
///
/// 2026-08-12, second report, `/NowPlayingPage`, same exception and same
/// `NetworkImage._loadAsync` frame. **Two of the three problems above
/// survived the first fix, and the queue's reading of the third was
/// wrong.** Taking them in reverse:
///
/// **The crash report was already gone.** `ScrollAwareImageProvider` in
/// the stack proves the source was an `Image` widget, and since Flutter
/// 3.10 an `Image` carrying an `errorBuilder` installs a blank
/// *ephemeral* error listener in `_stopListeningToStream` precisely so a
/// stream that fails after disposal still has something to swallow it
/// (flutter/flutter#97077). `ImageStreamCompleter.reportError` only
/// falls through to `FlutterError.reportError` when the listener list
/// comes back empty, and with an `errorBuilder` it never does. Every
/// `Image.network` in `lib/` has one (`image_network_audit_test.dart`),
/// and this widget always passes one. The 08-12 report came from a phone
/// still running a build from before the 08-11 conversion — it was
/// filed the day AFTER the fix that removed it.
///
/// **The failure was not being memoised at all when it mattered.** The
/// memo used to be written from `errorBuilder`, which is the *widget's*
/// error path — and errno 60 is the OS connect timeout, ~75 seconds. No
/// Now Playing page and no scrolled list row survives that. Leave the
/// page, or scroll the row off, and the socket fails onto a widget that
/// no longer exists: nothing is recorded, and the next row pays another
/// 75 seconds. The memo now hangs off the image provider
/// ([_MemoisingImage]) instead of the widget, so a failure is recorded
/// whether or not anyone is still looking.
///
/// **One dead host still cost one dead socket per URL.** The memo was
/// keyed by URL, so 199 fydt songs meant 199 first attempts. A failure
/// that says the HOST is unreachable — a socket, TLS or timeout error,
/// as opposed to a 404 for one file — now mutes the whole host. That is
/// the difference between one 75-second wait and one per row.
class RemoteImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  /// Shown while loading, on failure, and when [url] is null — so the
  /// caller never has to reason about which of those it is looking at.
  /// It must be a complete, presentable state on its own.
  final Widget Function(BuildContext context) fallback;

  /// Decode size in raw pixels. Pass `logicalSize * devicePixelRatio`.
  final int? cacheWidth;
  final int? cacheHeight;

  /// Wraps the image once it is actually on screen — for a scrim, a
  /// border, anything that must not appear over the fallback.
  final Widget Function(BuildContext context, Widget image)? onLoaded;

  /// Kept because the rest of this app depends on it: several external
  /// image hosts send no `Access-Control-Allow-Origin`, and on web
  /// `prefer` makes Flutter render a real `<img>` element instead of
  /// decoding bytes it is not allowed to read. Anything converted to
  /// `RemoteImage` must carry its original value over — dropping it
  /// looks like nothing on native and silently blanks the image on web.
  final WebHtmlElementStrategy webHtmlElementStrategy;

  const RemoteImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.onLoaded,
    this.webHtmlElementStrategy = WebHtmlElementStrategy.never,
  });

  static final Map<String, DateTime> _failedAt = {};

  /// Hosts that answered with a connection-level failure — see
  /// [_isHostUnreachable]. Separate from [_failedAt] because the entry
  /// covers every URL on that host, including ones never tried.
  static final Map<String, DateTime> _failedHostAt = {};

  /// Long enough that a down host is not re-probed while the user
  /// scrolls, short enough that recovery needs no restart.
  static const _retryAfter = Duration(minutes: 10);

  static bool _expired(Map<String, DateTime> memo, String key) {
    final at = memo[key];
    if (at == null) return true;
    if (DateTime.now().difference(at) > _retryAfter) {
      memo.remove(key);
      return true;
    }
    return false;
  }

  static bool _recentlyFailed(String url) {
    if (!_expired(_failedAt, url)) return true;
    final host = _hostOf(url);
    return host != null && !_expired(_failedHostAt, host);
  }

  static String? _hostOf(String url) {
    final host = Uri.tryParse(url)?.host;
    return (host == null || host.isEmpty) ? null : host;
  }

  /// Whether [error] says the HOST is unreachable rather than one file
  /// being missing. A 404 must stay scoped to its own URL — muting a
  /// whole host because one song's cover moved would blank artwork that
  /// is perfectly fine.
  ///
  /// Matched as text on purpose: `SocketException`, `HandshakeException`
  /// and friends live in `dart:io`, which this widget cannot import
  /// because it is built for web too. On web the browser reports a
  /// blocked fetch as `NetworkImageLoadException`, so web keeps the
  /// per-URL behaviour — there is no host-level signal to act on.
  static bool _isHostUnreachable(Object error) {
    final s = error.toString();
    return s.contains('SocketException') ||
        s.contains('HandshakeException') ||
        s.contains('TimeoutException') ||
        s.contains('ClientException');
  }

  /// The single write site for both memos, called only from
  /// [_MemoisingImage] — the one place where the URL and the exception
  /// are guaranteed to belong to each other.
  static void _noteFailure(String url, Object error) {
    final firstTime = !_failedAt.containsKey(url);
    _failedAt[url] = DateTime.now();
    final host = _hostOf(url);
    if (host != null && _isHostUnreachable(error)) {
      _failedHostAt[host] = DateTime.now();
    }
    if (firstTime) {
      debugPrint('[RemoteImage] $url failed, muted for '
          '${_retryAfter.inMinutes}m: $error');
    }
  }

  /// Let a pull-to-refresh give a recovered host an immediate second
  /// chance instead of waiting out the TTL.
  static void clearFailureMemo() {
    _failedAt.clear();
    _failedHostAt.clear();
  }

  @visibleForTesting
  static int get failureCount => _failedAt.length;

  @visibleForTesting
  static int get hostFailureCount => _failedHostAt.length;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty || _recentlyFailed(u)) {
      return fallback(context);
    }
    return Image(
      // What `Image.network` builds internally, with the memo spliced
      // in. Keeping the key-producing providers identical means the
      // image cache cannot tell the difference.
      image: _MemoisingImage(
        ResizeImage.resizeIfNeeded(
          cacheWidth,
          cacheHeight,
          NetworkImage(u, webHtmlElementStrategy: webHtmlElementStrategy),
        ),
        u,
      ),
      fit: fit,
      // Renders the failure; does NOT record it. `_ImageState` clears
      // `_lastException` only when a frame arrives or the listener is
      // recreated — not when the provider changes — so on the frame
      // after the song changes this fires with the PREVIOUS song's
      // exception under the new song's URL. Recording from here
      // therefore blames whichever host happens to be showing next.
      // `_MemoisingImage` binds the URL to the load itself, so it
      // cannot make that mistake.
      errorBuilder: (context, error, _) => fallback(context),
      frameBuilder: (context, image, frame, wasSyncLoaded) {
        // Until a frame exists the fallback IS the presentation — no
        // spinner, no grey box, no layout shift when it resolves.
        if (frame == null && !wasSyncLoaded) return fallback(context);
        return onLoaded?.call(context, image) ?? image;
      },
    );
  }
}

/// Forwards every decision to [inner] and does exactly one thing of its
/// own: record the failure, on the provider's timeline rather than the
/// widget's.
///
/// This is where the memo has to live. A 75-second connect timeout
/// outlives the page that started it, and `errorBuilder` — the only
/// error hook a widget has — is gone by then, so the failure went
/// unrecorded exactly in the case the memo exists for.
///
/// [ImageStreamCompleter.addEphemeralErrorListener] is the right hook
/// rather than `addListener`: it fires once, removes itself, and is
/// documented not to affect disposal, so it cannot pin a completer or a
/// decoded image in memory. It is the same mechanism `ResizeImage` uses
/// to evict its own cache key, and the same one `Image` uses to keep a
/// post-disposal failure out of `FlutterError` — which means an
/// unreachable artwork host cannot produce a crash report even if a
/// future edit drops the `errorBuilder` above.
class _MemoisingImage extends ImageProvider<Object> {
  const _MemoisingImage(this.inner, this.url);

  final ImageProvider<Object> inner;
  final String url;

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      inner.obtainKey(configuration);

  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) {
    final completer = inner.loadImage(key, decode);
    completer.addEphemeralErrorListener((exception, _) {
      RemoteImage._noteFailure(url, exception);
    });
    return completer;
  }

  // Equality forwards to `inner` so two RemoteImages for the same URL
  // and decode size stay one entry in the image cache.
  @override
  bool operator ==(Object other) =>
      other is _MemoisingImage && other.inner == inner && other.url == url;

  @override
  int get hashCode => Object.hash(inner, url);
}
