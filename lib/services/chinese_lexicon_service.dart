/// The Chinese BDB + Thayer lexicon — the deeper entry underneath the
/// CBOL gloss YsWords already shows.
///
/// Ported from SeekSparks (`lib/services/chinese_lexicon_service.dart`,
/// 2026-08-06), which imported the two assets with
/// `tools/import_yahweh_modules.py` from the MySword module the pastor
/// at yahwehdehua.net publishes and cleared for use. That is the same
/// permission `assets/tagged/cuvs-yhwh/` already ships under, so the
/// licensing question was settled before this file existed.
///
/// **This does not replace the CBOL gloss.** `StrongsEntry.glossZh` /
/// `definitionZh` stay exactly where they are and keep their
/// CC-BY-NC-SA attribution line. This is the fuller article for the
/// same number: lemma, transliteration, etymology with its TWOT/TDNT
/// reference, the 钦定本 (KJV) rendering counts, and numbered senses —
/// the shape a printed lexicon entry has, rather than a one-line
/// definition. Every surface that shows both must say which is which.
///
/// **The grammar codes are the reason this was worth porting.**
/// `assets/tagged/cuvs-yhwh/` carries 98,861 grammar-code occurrences
/// over 284 distinct codes (H8804 「Mood -Perfect」, G5656 「时态 - 简单
/// 过去式」 …). `TaggedRun.grammar` has parsed them since the tagged set
/// landed and **no widget read the field**, because nothing could
/// answer one: `assets/strongs/hebrew.json` stops at H8674 and
/// `greek.json` at G5624, so the existing lexicons decode **0 of 284**.
/// This module decodes **278 of 284**. The six it misses
/// (G25332, H19661, H57004, H59763, H61006, H87899) are malformed
/// concatenations in the tagging, not gaps in the module — they are out
/// of Strong's range on both sides, and [lookup] returns null for them
/// rather than inventing a reading. Measured and pinned by
/// `test/chinese_lexicon_test.dart`.
///
/// **SCRIPT: the module is Simplified Chinese only.** A `zh-Hant`
/// reader is shown the Simplified text rather than nothing, and told
/// so — see [isSimplifiedOnly]. Converting it was rejected for the
/// same reason `tagged_text_service.dart` rejects a Traditional tagged
/// set: this app has no 简→繁 converter, and a silent machine
/// conversion of a lexicon is worse than an honest label. The
/// Traditional CBOL gloss (`glossZhTw`) is unaffected and still shows
/// above this block.
///
/// **SIZE — read before changing the load strategy.** The two files are
/// 3.4 MB (2.14 MB + 1.25 MB). They are NOT on the boot path and must
/// not be put there: `web/app_shell_sw.js` precaches a six-entry
/// minimal shell only and is network-first by design, so a bundled
/// asset costs nothing until something calls
/// `rootBundle.loadString` — which is once per language, on the first
/// lookup that needs that side, and never for a reader who does not
/// open a word study. Loading both eagerly would put 3.4 MB in front of
/// first paint for everyone; do not "simplify" [_load] into a
/// constructor or an app-start warm-up.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One entry, in the shape the source module stores it.
///
/// A number is either a word or a grammar code, never both: a word
/// carries [lemma]/[senses], a grammar code carries [parsing] and
/// nothing else. [isGrammarCode] is how a caller tells them apart, and
/// the two render differently — a decoded code is a parsing note about
/// the form on the line, not a definition of it.
@immutable
class ChineseLexEntry {
  const ChineseLexEntry({
    required this.number,
    this.lemma = '',
    this.translit = '',
    this.etymology = '',
    this.usage = '',
    this.senses = const [],
    this.parsing = const [],
  });

  /// Strong's number or grammar code, upper-cased ('H430', 'H8804').
  final String number;

  /// The Hebrew/Greek headword, e.g. שׁמים / Ἰσαάκ.
  final String lemma;

  final String translit;

  /// Derivation, TWOT/TDNT reference and part of speech as one line:
  /// 「字根已不使用, 意为崇高; TWOT - 2407a; 阳性名词」.
  final String etymology;

  /// KJV rendering counts: 「钦定本 - heaven 398, air 21, …; 420」.
  final String usage;

  /// Numbered senses, already split one per line by the importer.
  final List<String> senses;

  /// Present INSTEAD of everything above when [number] is a grammar
  /// code: 「时态 - 简单过去式 见 5777」, 「语态 - 主动 见 5784」.
  ///
  /// The Greek codes are Chinese; the Hebrew ones are the module's own
  /// English ('Stem -Qal See [H8851]'). That asymmetry is the source's,
  /// not a porting bug — it is reported as it stands rather than
  /// half-translated.
  final List<String> parsing;

  bool get isGrammarCode => parsing.isNotEmpty;

  /// True when the module has the number but nothing to say about it.
  /// Treated as a miss by [lookup] so a caller falls through to the
  /// English lexicon instead of rendering an empty panel.
  bool get isEmpty => lemma.isEmpty && senses.isEmpty && parsing.isEmpty;

  factory ChineseLexEntry.fromJson(String number, Map<String, dynamic> j) =>
      ChineseLexEntry(
        number: number.toUpperCase(),
        lemma: (j['l'] ?? '') as String,
        translit: (j['t'] ?? '') as String,
        etymology: (j['e'] ?? '') as String,
        usage: (j['u'] ?? '') as String,
        senses: ((j['s'] as List?) ?? const []).cast<String>(),
        parsing: ((j['p'] as List?) ?? const []).cast<String>(),
      );
}

/// Lazy, per-language loader for the two Chinese lexicon assets.
///
/// Mirrors [StrongsService]'s shape deliberately: Hebrew and Greek load
/// independently, so an NT-only session never pays the Hebrew cost.
class ChineseLexiconService {
  /// The source is Simplified only, so a Traditional reader sees
  /// Simplified glyphs in this block. Surfaced so the UI can say so
  /// rather than letting a 繁體 reader read it as a failed conversion.
  static bool isSimplifiedOnly(String locale) =>
      locale.toLowerCase().startsWith('zh-hant');

  /// True when this locale should be offered the Chinese lexicon at
  /// all. An English reader is not shown it — the English column is
  /// already Strong's plus the derivation line, and a Chinese article
  /// under it would be noise.
  static bool appliesTo(String locale) =>
      locale.toLowerCase().startsWith('zh');

  static final Map<String, Map<String, ChineseLexEntry>> _cache = {};
  static final Map<String, Future<Map<String, ChineseLexEntry>>> _inflight = {};

  /// Asset basename for a number's side, or null when the number is
  /// neither Hebrew nor Greek.
  static String? _fileFor(String number) {
    if (number.isEmpty) return null;
    final head = number[0].toUpperCase();
    if (head == 'H') return 'bdb_zh';
    if (head == 'G') return 'thayer_zh';
    return null;
  }

  /// The entry for a Strong's number or a grammar code, or null when
  /// the module has nothing usable for it.
  ///
  /// Null is the ordinary answer for the six malformed tagging codes
  /// and for anything the caller passes that is not a Strong's-shaped
  /// number; callers fall back to what they were already showing
  /// rather than printing a gap.
  static Future<ChineseLexEntry?> lookup(String number) async {
    final file = _fileFor(number);
    if (file == null) return null;
    final table = await _table(file);
    final hit = table[number.toUpperCase()];
    return (hit == null || hit.isEmpty) ? null : hit;
  }

  /// [lookup] for a list of codes, in order, dropping the ones the
  /// module cannot answer.
  ///
  /// Exists for the grammar codes on a tagged run, which arrive
  /// together and are always rendered together. Sequential rather than
  /// concurrent on purpose: they are all on the same side, so the
  /// first call does the one load and the rest hit [_cache].
  static Future<List<ChineseLexEntry>> lookupGrammar(
      Iterable<String> codes) async {
    final out = <ChineseLexEntry>[];
    for (final code in codes) {
      final hit = await lookup(code);
      if (hit != null && hit.isGrammarCode) out.add(hit);
    }
    return out;
  }

  static Future<Map<String, ChineseLexEntry>> _table(String file) {
    final cached = _cache[file];
    if (cached != null) return Future.value(cached);
    return _inflight[file] ??= _load(file);
  }

  static Future<Map<String, ChineseLexEntry>> _load(String file) async {
    try {
      final raw = await rootBundle.loadString('assets/strongs/$file.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final out = <String, ChineseLexEntry>{
        for (final e in decoded.entries)
          e.key.toUpperCase():
              ChineseLexEntry.fromJson(e.key, e.value as Map<String, dynamic>),
      };
      _cache[file] = out;
      return out;
    } catch (_) {
      // Cache the emptiness. A missing or unparseable asset must not
      // mean a failed 2 MB bundle read on every subsequent word tap —
      // and the failure has to stay silent at this layer, because the
      // surfaces above simply show what they showed before the port.
      _cache[file] = const {};
      return const {};
    } finally {
      _inflight.remove(file);
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _cache.clear();
    _inflight.clear();
  }
}
