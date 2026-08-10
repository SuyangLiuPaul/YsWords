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

  const RemoteImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.onLoaded,
  });

  static final Map<String, DateTime> _failedAt = {};

  /// Long enough that a down host is not re-probed while the user
  /// scrolls, short enough that recovery needs no restart.
  static const _retryAfter = Duration(minutes: 10);

  static bool _recentlyFailed(String url) {
    final at = _failedAt[url];
    if (at == null) return false;
    if (DateTime.now().difference(at) > _retryAfter) {
      _failedAt.remove(url);
      return false;
    }
    return true;
  }

  /// Let a pull-to-refresh give a recovered host an immediate second
  /// chance instead of waiting out the TTL.
  static void clearFailureMemo() => _failedAt.clear();

  @visibleForTesting
  static int get failureCount => _failedAt.length;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty || _recentlyFailed(u)) {
      return fallback(context);
    }
    return Image.network(
      u,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, _) {
        _failedAt[u] = DateTime.now();
        debugPrint('[RemoteImage] $u failed, muted for '
            '${_retryAfter.inMinutes}m: $error');
        return fallback(context);
      },
      frameBuilder: (context, image, frame, wasSyncLoaded) {
        // Until a frame exists the fallback IS the presentation — no
        // spinner, no grey box, no layout shift when it resolves.
        if (frame == null && !wasSyncLoaded) return fallback(context);
        return onLoaded?.call(context, image) ?? image;
      },
    );
  }
}
