/// Bundled site icon per song source — the mark shown on rows whose
/// source publishes no artwork of its own.
///
/// 2026-09-03. The user asked for it directly: "没有封面的你可以用他们来源
/// 的封面做为歌曲的吗？我相信网站都有相应的网站特有的封面图". They were
/// right that every source has one, and measurement says it is worth
/// doing: of the 621 songs in the catalogue, **168 carry no
/// `artworkUrl`** — cahaya 47, cdc 107, fydt 14, cgdc 0.
///
/// It was 359 when this was written. The same day's re-check of CDC
/// found 191 real per-song covers the catalogue had recorded as
/// non-existent (`tools/add_cdc_artwork.py`), which is the better
/// answer wherever it is available — a real cover beats a site logo,
/// and this is the floor under the rest, not a substitute.
///
/// **Bundled, not hot-linked.** Four more remote images behind every
/// list row is the shape of the failure that produced the `errno = 60`
/// crash report: a down host, no timeout, one socket per row. An asset
/// cannot hang, cannot 404 and cannot be slow, so the fallback for a
/// missing image is never itself a missing image.
///
/// **Where each file came from** (fetched 2026-09-03, byte-for-byte as
/// the site serves it, so provenance stays checkable):
///
///   fydt    apple-touch-icon 180×180
///           fuyindiantai.org/wp-content/uploads/2020/08/
///             cropped-fydt_site_icon-180x180.jpg
///   cahaya  apple-touch-icon 180×180
///           cahayapengharapan.org/wp-content/uploads/2022/03/
///             cropped-cpm-ico-180x180.jpg
///   cgdc    apple-touch-icon 180×180
///           cgdc.hk/wp-content/uploads/2026/05/
///             cropped-cgdc_hk_website_icon-180x180.jpg
///   cdc     48×48 frame of the shortcut icon, re-encoded as PNG
///           christiandiscipleschurch.org/sites/default/files/
///             pictures/flav.ico
///
/// **CDC is the correction to the earlier note in the queue**, which
/// said "every one of these WordPress sites publishes a 180×180
/// apple-touch-icon". Three do. `christiandiscipleschurch.org` is
/// Drupal (danland theme), not WordPress: its `<head>` declares one
/// `rel="shortcut icon"` and nothing else, and the .ico ships exactly
/// two frames — 48×48 and 32×32. 48 is the largest square mark that
/// site publishes, and it is the source with 298 of the 359 songs, so
/// this is the one that had to be taken as found rather than wished
/// bigger. It is soft when scaled to a 120 px slot on a 3× screen.
/// Do not upscale it in the asset: that stores blur instead of
/// producing it, and costs bytes for the privilege.
///
/// 48×48 would be indefensible as a *cover* — a favicon blown up to
/// fill a slot looks worse than an empty one. It is defensible as what
/// it is here: a tint under a 0.68 wash behind the play glyph, checked
/// by rendering it rather than by argument. If CDC's rows ever need a
/// real cover, the answer is the church's own per-song artwork, which
/// 191 of them now have.
///
/// The site's own banner (`pictures/logo.jpg`, 950×170) was rejected —
/// a wordmark cropped to a square is either unreadable or arbitrary —
/// and so was `pictures_small/music-small.jpg`, which is a photograph
/// of musicians and would read as album art the song does not have.
/// A site icon says where the song came from. That is the whole claim
/// it is allowed to make.
library;

/// Source key (`Song.source`) → bundled asset path.
///
/// A source missing from this map degrades to the plain play button,
/// which is a complete presentation on its own — so a new source
/// appearing in the catalogue is a missing nicety, never a hole.
/// `test/song_source_icon_test.dart` fails when the catalogue gains a
/// source this map does not cover, so "never got around to it" cannot
/// pass silently.
const Map<String, String> songSourceIcons = {
  'fydt': 'assets/song_sources/fydt.jpg',
  'cahaya': 'assets/song_sources/cahaya.jpg',
  'cdc': 'assets/song_sources/cdc.png',
  'cgdc': 'assets/song_sources/cgdc.jpg',
};

/// The bundled mark for [source], or null when there is none.
String? songSourceIcon(String? source) =>
    source == null ? null : songSourceIcons[source];
