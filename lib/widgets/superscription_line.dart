import 'package:flutter/material.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/utils/build_verse_content_spans.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';

/// 2026-08-10 (v1.4.37): the unnumbered heading a psalm carries above
/// its first verse — "For the [music] director; with stringed
/// instruments. A psalm of David." The LEB ships 116 of them and the
/// reader used to drop every one.
///
/// Rendered above verse 1 with NO verse number: a superscription is
/// scripture but it is not a verse, and printing a number beside it
/// would tell the reader this translation numbers it, which it does
/// not. It is not selectable and cannot be highlighted for the same
/// reason — see [Verse.superscription].
///
/// It goes through [buildVerseContentSpans] rather than a plain [Text]
/// so its `[editorial insert]` brackets and `<note: …>` markers behave
/// exactly as they do in verse text; the LEB's own note here explains
/// that the Hebrew counts the superscription as verse 1, which is
/// precisely the kind of thing a reader should be able to tap. The
/// synthetic verse is marked `paragraphType: 'reference'` purely to
/// borrow that builder's existing italic treatment, the same one the
/// reader already uses for quoted-scripture lines.
class SuperscriptionLine extends StatelessWidget {
  final Verse verse;
  final AppSettings settings;
  final String locale;

  /// The edition this superscription belongs to, passed in rather than
  /// read from a provider: this is a presentational widget, and
  /// `leb_superscription_test.dart` pumps it on its own with no
  /// MainProvider above it. Reading the provider here compiled fine and
  /// broke that test at runtime — the widget should not know where the
  /// version comes from.
  final String? versionCode;

  const SuperscriptionLine({
    super.key,
    required this.verse,
    required this.settings,
    required this.locale,
    this.versionCode,
  });

  @override
  Widget build(BuildContext context) {
    final dc = ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width);
    final baseIndent = ResponsiveBreakpoints.verseIndent(dc);
    final spans = buildVerseContentSpans(
      verse: Verse(
        book: verse.book,
        chapter: verse.chapter,
        verse: verse.verse,
        verseLabel: '',
        text: verse.superscription,
        paragraphType: 'reference',
      ),
      context: context,
      settings: settings,
      locale: locale,
      isSelected: false,
      showVerseNumber: false,
      versionCode: versionCode,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        baseIndent + 4,
        settings.fontSize * 0.2,
        baseIndent,
        settings.fontSize * 0.15,
      ),
      child: RichText(
        textAlign: TextAlign.start,
        text: TextSpan(
          style: TextStyle(
            fontSize: settings.fontSize,
            fontFamily: settings.fontFamily,
            fontFamilyFallback: kCjkFontFallback,
            height: settings.lineSpacing,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          children: spans,
        ),
      ),
    );
  }
}
