/// 2026-05-24 (v1.2.91): shared relative-time formatter ("5 分钟前 /
/// 5 minutes ago"). Pulled out of settings_page.dart's private
/// `_relative` helper so the search-page recent-queries rows can
/// reuse the same formatting without duplicating the logic.
///
/// Format buckets (locale-aware, with zh-Hans / zh-Hant / en):
///   < 30 s        → "刚刚" / "just now"
///   < 60 s        → "不到一分钟前" / "less than a minute ago"
///   < 60 min      → "5 分钟前" / "5 minutes ago"
///   < 24 h        → "3 小时前" / "3 hours ago"
///   otherwise     → "2 天前" / "2 days ago"
///
/// Caller is expected to render the result as a small caption. The
/// helper does not refresh on its own — wrap in a periodic rebuild
/// (e.g. a 30 s Timer) if you need the label to stay accurate while
/// the screen is open.
String relativeTime(DateTime when, String locale) {
  // Normalise both sides to UTC so a viewer crossing a DST boundary
  // doesn't produce a negative difference for a stamp written 30 min
  // ago. `when` may have been constructed locally — fine, .toUtc()
  // is a no-op for already-UTC times.
  final now = DateTime.now().toUtc();
  final whenUtc = when.toUtc();
  final diff = now.difference(whenUtc);
  // Clamp clock-skew futures (remote-sync clients may stamp slightly
  // ahead of the local clock) to "just now" rather than rendering
  // "-3 seconds ago".
  if (diff.isNegative) return _justNow(locale);
  final isZh = locale.startsWith('zh');
  if (diff.inSeconds < 30) return _justNow(locale);
  if (diff.inMinutes < 1) {
    return isZh ? '不到一分钟前' : 'less than a minute ago';
  }
  if (diff.inMinutes < 60) {
    return isZh
        ? '${diff.inMinutes} 分钟前'
        : '${diff.inMinutes} minute${diff.inMinutes == 1 ? "" : "s"} ago';
  }
  if (diff.inHours < 24) {
    return isZh
        ? '${diff.inHours} 小时前'
        : '${diff.inHours} hour${diff.inHours == 1 ? "" : "s"} ago';
  }
  return isZh
      ? '${diff.inDays} 天前'
      : '${diff.inDays} day${diff.inDays == 1 ? "" : "s"} ago';
}

String _justNow(String locale) =>
    locale.startsWith('zh') ? '刚刚' : 'just now';
