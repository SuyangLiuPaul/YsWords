import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// The two lines every 福音电台 library surface owes its reader, and
/// the one rule about where they go.
///
/// The rule comes from `sermons_page.dart`'s `sermonAudioClause`: a
/// mark that is true of every row is decoration, and decoration
/// teaches a reader to stop seeing marks. Both of these are true of
/// the whole corpus — all 937 records are Simplified Chinese, and one
/// rights line covers all of them — so each appears ONCE per surface
/// and never on a row.

/// "These sermons are in Chinese. No English text exists."
///
/// Shown on the speaker index and on a sermon, which are the two
/// places a reader can arrive at cold. Not on the per-speaker list,
/// which is only reachable through the index that already said it.
///
/// Three real sentences, not one translated twice. The English states
/// an absence and promises nothing — there is no English edition of
/// any of these 937 and none is coming from this app. The Traditional
/// tells a 繁體 reader why the characters look the way they do: the
/// corpus is Simplified, the app converts nothing at runtime, and the
/// alternative to saying so is a reader who thinks the rendering is
/// broken. See `test/tw_sermon_orthography_test.dart` for why an
/// in-app conversion is not on the table — the app's one Traditional
/// sermon edition was produced offline and calibrated against a human
/// Traditional text, and no such text exists for this corpus.
class SermonLibraryLanguageNote extends StatelessWidget {
  final String locale;
  const SermonLibraryLanguageNote({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      uiStrings['sermonLibraryChineseOnly']?[locale] ??
          'These sermons are in Chinese. No English text exists.',
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: scheme.onSurface.withValues(alpha: 0.6),
        fontFamilyFallback: kCjkFontFallback,
      ),
    );
  }
}

/// "© 福音电台 及各讲员 · 经授权使用", read out of the asset.
///
/// [text] comes from `SermonLibrary.rightsFor` — that is, from
/// `_meta.rights` in `index.json` — and is never composed here. The
/// rights line belongs to the corpus, so a re-ingest that changes it
/// changes what the app prints, and no release is needed to correct
/// a credit.
///
/// Renders nothing at all when the asset carries no rights string,
/// rather than a lone "©".
class SermonLibraryRights extends StatelessWidget {
  final String text;
  const SermonLibraryRights({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Text(
        text.trim(),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: scheme.onSurface.withValues(alpha: 0.5),
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
    );
  }
}
