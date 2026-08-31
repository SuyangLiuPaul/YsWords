/// Minimal XML reader — enough to prove a sitemap parses and to pull
/// element text out of it. `package:xml` is not a dependency of this app
/// and two test files do not justify adding it to the shipped dependency
/// tree.
///
/// Extracted from `test/seo_meta_test.dart` on 2026-08-31 when
/// `test/prerender_bible_test.dart` needed the same parser: the sitemap
/// became an INDEX naming five GENERATED children, and both files have to
/// read XML to check the two halves agree.
library;

class XmlDocument {
  final String _src;
  const XmlDocument._(this._src);

  static XmlDocument parse(String rawSrc) {
    if (!rawSrc.trimLeft().startsWith('<?xml')) {
      throw FormatException('missing XML declaration');
    }
    // Comments first, exactly as a real parser does. The sitemaps are
    // heavily commented on purpose and those comments name the very tags
    // checked below — `<url>`, `<lastmod>` — as prose. Documentation of a
    // decision must not read as an unclosed element.
    final src = rawSrc.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    // Tag balance: catches a truncated file or an unclosed element,
    // which is the realistic way these files break.
    final opens = RegExp(r'<([a-zA-Z][\w:-]*)(\s[^>]*)?>').allMatches(src);
    final stack = <String>[];
    for (final m in opens) {
      final full = m.group(0)!;
      if (full.endsWith('/>')) continue;
      stack.add(m.group(1)!);
    }
    for (final m in RegExp(r'</([a-zA-Z][\w:-]*)>').allMatches(src)) {
      final name = m.group(1)!;
      if (!stack.contains(name)) {
        throw FormatException('closing tag </$name> was never opened');
      }
      stack.remove(name);
    }
    if (stack.isNotEmpty) {
      throw FormatException('unclosed tag(s): ${stack.join(', ')}');
    }
    return XmlDocument._(src);
  }

  /// Name of the first real element. A String, not a wrapper type:
  /// returning a private class from a public getter trips
  /// `library_private_types_in_public_api`, and one name is all any
  /// assertion here needs.
  String get rootName {
    final m = RegExp(r'<([a-zA-Z][\w:-]*)').firstMatch(_src);
    if (m == null) throw FormatException('no root element');
    return m.group(1)!;
  }

  List<String> findAll(String tag) => RegExp('<$tag>\\s*([^<]*?)\\s*</$tag>')
      .allMatches(_src)
      .map((m) => m.group(1)!)
      .toList();
}
