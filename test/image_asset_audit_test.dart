import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every bundled image in the app, audited as source — the companion to
/// `image_network_audit_test.dart`, and written the day a bundled one
/// did what that file says only remote ones do.
///
/// 2026-09-13, from an iPhone SE (320×568, DPR 2) on web v1.5.25:
///
///     ImageCodecException: Failed to create image from Image.decode
///     boot:step — FetchBooks.execute
///
/// On the web that comes from `createCkImageFromImageElement`:
/// CanvasKit could not make a texture out of the decoded `<img>`. The
/// image was `assets/loading.png` — 1024×1024, so ≈4 MB once decoded
/// whatever the file compresses to — drawn into the splash's small logo
/// slot with no decode cap, on the smallest phone
/// the app ships to, at the tightest moment for memory it has. And with
/// no `errorBuilder` the image stream had no listener to swallow the
/// failure, so it went to `FlutterError.reportError` and arrived as a
/// crash report.
///
/// An asset cannot 404, which is the reason this audit did not exist.
/// It can still fail to *decode*, and then the two rules are the same
/// ones the remote audit already pins:
///
///   * an `errorBuilder`, so a picture that will not paint is a missing
///     picture and not a crash;
///   * a decode cap, so a large bundled image is not decoded at full
///     size into a small slot.
void main() {
  /// Every `Image.asset(...)` argument list in `lib/`, as
  /// `(file, line, body)`.
  List<({String file, int line, String body})> callSites() {
    final out = <({String file, int line, String body})>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final f in files) {
      // Comment-only lines are blanked, not dropped, so a failure's
      // line number still points at the real line. `bible_map.dart`
      // spells `Image.asset('assets/maps/<url>')` inside a doc comment
      // to explain the asset path, and an audit that cannot tell prose
      // from code fails on documentation.
      //
      // Only WHOLE-line comments: cutting at the first `//` anywhere
      // would also cut a URL in a string, and truncating an argument
      // list mid-way unbalances the paren scan below — which would run
      // to the end of the file and swallow every later call site. A
      // trailing comment after real code is left alone.
      final src = f.readAsStringSync().split('\n').map((l) {
        return l.trimLeft().startsWith('//') ? '' : l;
      }).join('\n');
      for (final m in RegExp(r'Image\.asset\(').allMatches(src)) {
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

  test('there are still bundled images to audit', () {
    // If this hits zero the rest of the file is vacuously true, which
    // is the one way an audit test rots without failing.
    expect(callSites(), isNotEmpty);
  });

  test('every Image.asset handles its own failure', () {
    for (final c in callSites()) {
      expect(c.body.contains('errorBuilder'), isTrue,
          reason: '${c.file}:${c.line} — a decode failure with no '
              'errorBuilder is reported as a crash');
    }
  });

  test('every Image.asset decodes at the size it is drawn', () {
    for (final c in callSites()) {
      expect(c.body.contains('cacheWidth'), isTrue,
          reason: '${c.file}:${c.line} — no decode cap');
      expect(c.body.contains('cacheHeight'), isTrue,
          reason: '${c.file}:${c.line} — no decode cap');
    }
  });

  test('the splash mark is still big enough to need the cap', () {
    // The cap is about PIXELS, not bytes. `loading.png` is 1.2 MB on
    // disk, but what the decoder allocates is 1024 × 1024 × 4 ≈ 4 MB
    // whatever the file compresses to — which is why the same rule
    // applies to SeekSparks' splash mark, a 67 KB file of exactly the
    // same dimensions. If this asset is ever redrawn small enough to
    // draw uncapped, say so here rather than deleting the rule.
    final bytes = File('assets/loading.png').readAsBytesSync();
    // PNG: 8-byte signature, then the IHDR chunk — 4 length, 4 type,
    // then width and height as big-endian uint32.
    int be32(int at) =>
        (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) |
        bytes[at + 3];
    expect(String.fromCharCodes(bytes.sublist(12, 16)), 'IHDR');
    final width = be32(16);
    final height = be32(20);
    // 480 = the largest slot the splash ever draws into (240pt on a
    // TV, `ResponsiveBreakpoints.loadingLogoSize`) at DPR 2. The mark
    // is at least that, and a mini-phone's slot is 100pt — so
    // uncapped, the smallest device decodes the most pixels it will
    // never use. That is the asymmetry the cap exists for, and it is
    // why SeekSparks' 512×512 themed marks are capped too despite
    // being a quarter of this one.
    expect(width * height, greaterThanOrEqualTo(480 * 480),
        reason: 'decoded at $width×$height ≈ '
            '${(width * height * 4) ~/ (1024 * 1024)} MB uncapped');
  });
}
