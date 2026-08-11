/// Strong's-tagged translation text — the data behind "tap a word to
/// see the original".
///
/// YsWords already shipped `assets/originals/` (the Greek/Hebrew of a
/// whole verse) and `assets/strongs/` (the lexicon). What was missing
/// was the join between them and the Chinese: which *word* on screen
/// renders which original word. Without it, tapping 创造 in Genesis 1:1
/// could only ever report the verse.
///
/// 和合本【雅伟】简体版 is tagged and cleared for use here, so
/// `cuvs-yhwh` can answer per word. Ported from SeekSparks, whose
/// importer produced these assets.
///
/// **Simplified only.** There is no Traditional tagged set — producing
/// one means running the Simplified tagging through a 简→繁 conversion,
/// and this app has no converter. So `cuvs-yhwh-tr` is deliberately
/// absent from [taggedVersions], and the UI must not offer the gesture
/// on that version rather than offering one that silently does nothing.
///
/// One file per book under `assets/tagged/<version>/<book>.json`,
/// loaded lazily and cached — the set is 13 MB, far too much to hold
/// eagerly on a phone.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/utils/scripture_markup.dart'
    show isReferentGloss;

/// One run of translation text and the original-language word behind it.
@immutable
class TaggedRun {
  const TaggedRun({
    required this.text,
    required this.strongs,
    this.implied = const [],
    this.grammar = const [],
  });

  /// The translation text as printed, punctuation included.
  final String text;

  /// Primary Strong's number, or '' for text the tagger left unmarked
  /// (opening quotes, inserted connectives).
  final String strongs;

  /// Numbers the original has that this text does not render — the
  /// Hebrew direct-object marker אֵת, the Greek article. Worth showing
  /// as secondary, never as the word's own identity.
  final List<String> implied;

  /// Grammar codes: Hebrew stem/aspect, Greek tense-voice-mood.
  final List<String> grammar;

  bool get isTagged => strongs.isNotEmpty;

  factory TaggedRun.fromJson(Map<String, dynamic> j) => TaggedRun(
        text: (j['w'] ?? '') as String,
        strongs: (j['s'] ?? '') as String,
        implied: ((j['i'] as List?) ?? const []).cast<String>(),
        grammar: ((j['g'] as List?) ?? const []).cast<String>(),
      );
}

class TaggedTextService {
  /// Version codes that have a tagged asset set. Checked before any
  /// load so an untagged version costs nothing.
  /// 2026-08-07: kjvs / lxxwh / cuvs-plus join them, imported from
  /// Eagle's View by `tools/import_eaglesview.py`. That module tags
  /// BOTH testaments, so the English and Chinese columns are now tagged
  /// in the Old Testament too — previously only the BSB reached back
  /// past Malachi.
  /// Versions with a tagged asset set. Checked before any load, so an
  /// untagged version costs nothing.
  ///
  /// Only the Simplified 雅伟版. SeekSparks also tags bsb / kjvs /
  /// lxxwh / cuvs-plus, but YsWords does not ship those versions, and
  /// `cuvs-yhwh-tr` has no tagged set at all — see the library note.
  static const Set<String> taggedVersions = {
    'cuvs-yhwh',
  };


  static final Map<String, Map<String, List<TaggedRun>>> _cache = {};
  static final Map<String, Future<Map<String, List<TaggedRun>>>> _inflight = {};

  static bool supports(String version) =>
      taggedVersions.contains(version.toLowerCase());

  /// The tagged runs for one verse, or null when this version has no
  /// tagging or the verse is missing. Callers fall back to plain text.
  static Future<List<TaggedRun>?> forVerse({
    required String version,
    required String englishBook,
    required int chapter,
    required int verse,
  }) async {
    if (!supports(version)) return null;
    final book = await _book(version, englishBook);
    return book?['$chapter:$verse'];
  }

  static Future<Map<String, List<TaggedRun>>?> _book(
      String version, String englishBook) async {
    final key = '${version.toLowerCase()}/${_fileName(englishBook)}';
    final hit = _cache[key];
    if (hit != null) return hit;
    final loaded = await (_inflight[key] ??= _load(key));
    return loaded.isEmpty ? null : loaded;
  }

  static Future<Map<String, List<TaggedRun>>> _load(String key) async {
    try {
      final raw = await rootBundle.loadString('assets/tagged/$key.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final out = <String, List<TaggedRun>>{
        for (final e in decoded.entries)
          if (!carriesImporterMarkup(e.value as List))
            e.key: reuniteGlossRuns((e.value as List)
                .map((r) => TaggedRun.fromJson(r as Map<String, dynamic>))
                .toList(growable: false)),
      };
      _cache[key] = out;
      return out;
    } catch (_) {
      // A missing book is normal for a version with a partial canon;
      // cache the emptiness so we do not retry on every verse.
      _cache[key] = const {};
      return const {};
    }
  }

  /// A leftover Strong's marker in the printed text — `<WH7931s>`,
  /// `主#`, a bare `WH853x`.
  ///
  /// The Originals sheet prints these runs *instead of* the verse, so a
  /// marker that survives the import is shown to the reader as
  /// scripture: 詩篇 7:5 read `使<WH7931s>我的榮耀歸於灰塵` in 183
  /// verses' worth of places. The data is repaired
  /// (`tools/repair_tagged_markup.py`), and two verses could not be
  /// settled from evidence because the marker swallowed a Chinese
  /// character the reading asset shows belongs in a different clause.
  ///
  /// Dropping the whole verse rather than scrubbing the run: the
  /// gesture is worth less than the text, and the sheet already falls
  /// back to the reader's own verse when a verse has no tagging.
  @visibleForTesting
  static bool carriesImporterMarkup(List<dynamic> runs) {
    for (final r in runs) {
      final w = (r as Map<String, dynamic>)['w'];
      if (w is String && _importerMarkup.hasMatch(w)) return true;
    }
    return false;
  }

  static final RegExp _importerMarkup =
      RegExp(r'[<>#]|[Ww][HhGgJjMm][0-9]+');

  /// Put a referent gloss back together.
  ///
  /// The 和合本雅伟版 tagger walked the text word by word and treated
  /// `主[雅伟]` as if the bracket were ordinary prose, so in 193 verses
  /// the gloss straddles a run boundary: `主 [` carries G2962 (κύριος)
  /// and the run that follows opens `雅伟] 的使者` carrying G32
  /// (ἄγγελος). Two failures, one cause.
  ///
  ///   * On screen the halves are laid out as separate words, so the
  ///     bracket prints with a gap inside it — the `主 [ 雅伟]` a
  ///     reader sees in the KWIC pane, where the keyword column can
  ///     end up holding nothing but an orphan `[`.
  ///   * The closing half is TAGGED, and tagged with the wrong number.
  ///     Hovering 雅伟 in Matthew 2:13 answers "angel", because the
  ///     gloss inherited the Strong's of whatever followed it. 雅伟
  ///     renders no Greek word at all — the word it names is the one
  ///     printed IN FRONT of it — so a number of its own is an answer
  ///     to a question the text does not ask.
  ///
  /// Which word that is varies, and the fix does not assume: usually
  /// 主/κύριος, but δεσπότης at Jude 1:4, θεός at Acts 16:32, and at
  /// Romans 4:17 a preposition phrase that swallowed the 主. The rule
  /// is positional, not lexical.
  ///
  /// The gloss therefore belongs to the run that OPENED it. Restricted
  /// to the closed token set (see `bracketSpanKind`), which is why this
  /// cannot touch the brackets that legitimately span several runs:
  /// LXX/WH marks doubtful text as `[το αυτο]` and the NASB brackets
  /// whole disputed verses, and there every word inside is a real word
  /// with a real number of its own. Measured over the shipped assets
  /// this rewrites cuvs-yhwh alone — 198 verses — and leaves bsb,
  /// kjvs, lxxwh, cuvs-plus and nsn-plus byte-identical.
  @visibleForTesting
  static List<TaggedRun> reuniteGlossRuns(List<TaggedRun> runs) {
    var seen = false;
    for (final r in runs) {
      if (r.text.contains('[')) {
        seen = true;
        break;
      }
    }
    if (!seen) return runs;

    final texts = <String>[];
    // Text already pulled forward out of the run about to be read.
    String? carried;
    for (var i = 0; i < runs.length; i++) {
      var text = carried == null
          ? runs[i].text
          : runs[i].text.substring(carried.length);
      carried = null;
      final open = text.lastIndexOf('[');
      if (open >= 0 && !text.substring(open).contains(']') &&
          i + 1 < runs.length) {
        final next = runs[i + 1].text;
        final close = next.indexOf(']');
        if (close >= 0) {
          final body = text.substring(open + 1) + next.substring(0, close);
          if (isReferentGloss(body)) {
            carried = next.substring(0, close + 1);
            text += carried;
          }
        }
      }
      texts.add(_tightenGloss(text));
    }

    // The importer also spaced the bracket off from the Chinese around
    // it (`主 [雅伟] 的道`), and after reuniting the trailing half of
    // that spacing sits at the head of the NEXT run where no
    // within-string pass can see it.
    for (var i = 0; i < texts.length - 1; i++) {
      if (!_endsWithGloss(texts[i])) continue;
      final head = texts[i + 1].trimLeft();
      if (head.isEmpty || !_cjk.hasMatch(head[0])) continue;
      texts[i] = texts[i].trimRight();
      texts[i + 1] = head;
    }

    final out = <TaggedRun>[];
    for (var i = 0; i < runs.length; i++) {
      // A run whose text was entirely gloss has no printed word left to
      // carry a number. None exist in the shipped assets; dropping is
      // the honest answer if one ever does.
      if (texts[i].isEmpty && runs[i].text.isNotEmpty) continue;
      out.add(TaggedRun(
        text: texts[i],
        strongs: runs[i].strongs,
        implied: runs[i].implied,
        grammar: runs[i].grammar,
      ));
    }
    return List.unmodifiable(out);
  }

  static final RegExp _cjk = RegExp(r'[　-〿一-鿿＀-￯]');
  static final RegExp _bracket = RegExp(r'\[([^\[\]]*)\]');
  static final RegExp _glossAtEnd = RegExp(r'\[([^\[\]]*)\]$');

  /// Close the gap the importer left on either side of a gloss, but
  /// only where the neighbour is CJK — English spacing around a
  /// bracket is correct and must survive.
  static String _tightenGloss(String s) {
    if (!s.contains('[')) return s;
    return s
        .replaceAllMapped(
          RegExp('(${_cjk.pattern})[ \\t]+(${_bracket.pattern})'),
          (m) => isReferentGloss(m.group(3) ?? '')
              ? '${m.group(1)}${m.group(2)}'
              : m.group(0)!,
        )
        .replaceAllMapped(
          RegExp('(${_bracket.pattern})[ \\t]+(${_cjk.pattern})'),
          (m) => isReferentGloss(m.group(2) ?? '')
              ? '${m.group(1)}${m.group(3)}'
              : m.group(0)!,
        );
  }

  static bool _endsWithGloss(String s) {
    final m = _glossAtEnd.firstMatch(s.trimRight());
    return m != null && isReferentGloss(m.group(1) ?? '');
  }

  /// "1 Corinthians" → "1_corinthians", matching the importer's output
  /// and the existing assets/originals/ naming.
  static String _fileName(String englishBook) =>
      englishBook.toLowerCase().replaceAll(' ', '_');
}
