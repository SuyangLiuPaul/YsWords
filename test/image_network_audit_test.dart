import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every remote image in the app, audited as source.
///
/// The queue carried an item saying "convert the other
/// `Image.network` calls to `RemoteImage`", then corrected itself:
/// they already carry `errorBuilder`, a decode cap and
/// `webHtmlElementStrategy`, so there is nothing to fix. Re-audited
/// 2026-09-03 — the correction was right in substance and wrong in
/// two details worth pinning rather than re-deriving:
///
///   • There are **9** such call sites, not 14.
///   • **6** carried all three. Three did not: both thumbnails in
///     `videos_page.dart` had only `errorBuilder`, and
///     `profile_avatar.dart` had no `webHtmlElementStrategy`.
///
/// Neither gap was what the item feared. `webHtmlElementStrategy`
/// exists for hosts that send no `Access-Control-Allow-Origin`;
/// `i.ytimg.com` and `lh3.googleusercontent.com` both answer
/// `access-control-allow-origin: *`, so its absence is correct there,
/// not an oversight. And a decode cap on a 480×360 YouTube
/// `hqdefault.jpg` would save nothing.
///
/// The videos thumbnails moved to `RemoteImage` anyway, for the
/// failure memo alone — `i.ytimg.com` is blocked behind the GFW, which
/// is a user population this app explicitly ships for. See
/// `videos_page.dart`'s `_player` for that argument in full.
///
/// This test is the durable half: an `Image.network` with no
/// `errorBuilder` shows the user a broken-image glyph, and that must
/// never be added by accident.
void main() {
  /// Every `Image.network(...)` argument list in lib/, excluding the
  /// one inside `RemoteImage` itself, as `(file, line, body)`.
  List<({String file, int line, String body})> callSites() {
    final out = <({String file, int line, String body})>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('remote_image.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final f in files) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r'Image\.network\(').allMatches(src)) {
        // Balance from the opening paren so nested calls in the
        // argument list (errorBuilder closures, mostly) stay inside.
        var depth = 0;
        var end = src.length;
        for (var i = m.end - 1; i < src.length; i++) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        out.add((
          file: f.path,
          line: '\n'.allMatches(src.substring(0, m.start)).length + 1,
          body: src.substring(m.end, end),
        ));
      }
    }
    return out;
  }

  test('there are still remote images to audit', () {
    // If this hits zero the rest of the file is vacuously true, which
    // is the one way an audit test rots without failing.
    expect(callSites(), isNotEmpty);
  });

  test('every Image.network handles its own failure', () {
    final naked = callSites()
        .where((s) => !s.body.contains('errorBuilder'))
        .map((s) => '${s.file}:${s.line}')
        .toList();
    expect(naked, isEmpty,
        reason: 'an Image.network with no errorBuilder renders the '
            "platform's broken-image glyph when the host is down. Add "
            'one, or use RemoteImage.');
  });

  test('the YouTube thumbnails go through RemoteImage', () {
    // The conversion this item actually produced. Stated as an
    // absence, because the point is that the raw call is gone: a
    // future edit that reaches for Image.network here would restore a
    // timeout-less socket to a host a whole region cannot reach.
    final src = File('lib/pages/videos_page.dart').readAsStringSync();
    expect(src, isNot(contains('Image.network(')));
    expect(RegExp(r'RemoteImage\(').allMatches(src), hasLength(2));
  });

  test('nobody added webHtmlElementStrategy by cargo cult', () {
    // `prefer` lays out a real <img> instead of decoding bytes, and it
    // is the right answer only for a host that withholds CORS. Both
    // hosts reached from videos_page send `access-control-allow-origin:
    // *`, so adding it there would be a change made by analogy rather
    // than by measurement — the failure mode this repo keeps writing
    // notes about.
    // Matched with the colon: the parameter being *passed*, not the
    // doc comment above `_player` that explains why it is not.
    final src = File('lib/pages/videos_page.dart').readAsStringSync();
    expect(src, isNot(contains('webHtmlElementStrategy:')));
  });

  test('the sites that do carry the CORS workaround still carry it', () {
    // Dropping it looks like nothing on native and silently blanks the
    // image on web, so it is exactly the kind of parameter a tidy-up
    // deletes. These hosts (church servers, illustration CDNs) send no
    // CORS headers.
    const needsCors = [
      'lib/pages/evidence_page.dart',
      'lib/pages/evidence_detail_page.dart',
      'lib/pages/dashboard_page.dart',
      'lib/widgets/illustration_image.dart',
      'lib/pages/songs_page.dart',
    ];
    for (final path in needsCors) {
      final src = File(path).readAsStringSync();
      expect(src, contains('webHtmlElementStrategy:'),
          reason: '$path lost its cross-origin strategy; its images will '
              'blank on web while looking fine on iOS');
    }
  });
}
