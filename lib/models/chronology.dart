/// Models for the interactive chronology chart, loaded from
/// `assets/bible_chronology.json` (built by
/// `tools/build_bible_chronology.py`).
///
/// The chart's unit is **Anno Mundi** — years since Creation. That is
/// deliberate: Genesis 5 and 11 state *intervals* (X was N years old
/// when he fathered Y; he lived M years), and intervals are what the
/// text actually gives. A BC year is an interval plus an anchor, and the
/// anchor is the contested part. So AM is stored, BC is derived through
/// a named [ChronologyScheme], and the scheme is shown on screen rather
/// than folded silently into the numbers.
library;

/// One chronology scheme — a named way of anchoring AM 0 to a BC year.
///
/// Only [supported] schemes have lifelines plotted. The unsupported ones
/// are carried anyway so the reader can see WHICH question is open: the
/// Masoretic, Septuagint and Samaritan genealogies disagree by roughly
/// 1,500 years, and a chart that mentioned only its own scheme would
/// read as though there were nothing to disagree about.
class ChronologyScheme {
  final String id;
  final bool supported;

  /// BC year that AM 0 is anchored to (4004 for Ussher).
  final int creationBc;

  final String nameEn;
  final String nameZhHans;
  final String nameZhHant;
  final String noteEn;
  final String noteZhHans;
  final String noteZhHant;

  const ChronologyScheme({
    required this.id,
    required this.supported,
    required this.creationBc,
    required this.nameEn,
    required this.nameZhHans,
    required this.nameZhHant,
    required this.noteEn,
    required this.noteZhHans,
    required this.noteZhHant,
  });

  String localizedName(String locale) =>
      _pick(locale, nameEn, nameZhHans, nameZhHant);
  String localizedNote(String locale) =>
      _pick(locale, noteEn, noteZhHans, noteZhHant);

  /// AM year → signed BC/AD year (negative = BC), on this anchor.
  int amToYear(int am) {
    final bc = creationBc - am;
    // There is no year 0: 1 BC is followed by AD 1.
    return bc > 0 ? -bc : (1 - bc);
  }

  factory ChronologyScheme.fromJson(Map<String, dynamic> j) =>
      ChronologyScheme(
        id: j['id'] as String,
        supported: j['supported'] as bool? ?? false,
        creationBc: (j['creationBc'] as num).toInt(),
        nameEn: j['nameEn'] as String? ?? '',
        nameZhHans: j['nameZhHans'] as String? ?? '',
        nameZhHant: j['nameZhHant'] as String? ?? '',
        noteEn: j['noteEn'] as String? ?? '',
        noteZhHans: j['noteZhHans'] as String? ?? '',
        noteZhHant: j['noteZhHant'] as String? ?? '',
      );
}

/// A descent band — the reference sheet's one genuinely good idea,
/// which is that colouring lifelines by line of descent makes the shape
/// of the genealogy visible at a glance.
class ChronologyLine {
  final String id;
  final String colorHex;
  final String nameEn;
  final String nameZhHans;
  final String nameZhHant;

  const ChronologyLine({
    required this.id,
    required this.colorHex,
    required this.nameEn,
    required this.nameZhHans,
    required this.nameZhHant,
  });

  String localizedName(String locale) =>
      _pick(locale, nameEn, nameZhHans, nameZhHant);

  /// `#RRGGBB` → 0xFFRRGGBB. Falls back to a neutral grey rather than
  /// throwing, so a typo in the asset degrades to a dull bar instead of
  /// a blank page.
  int get colorValue => _hexToArgb(colorHex);

  factory ChronologyLine.fromJson(Map<String, dynamic> j) => ChronologyLine(
        id: j['id'] as String,
        colorHex: j['colorHex'] as String? ?? '#555555',
        nameEn: j['nameEn'] as String? ?? '',
        nameZhHans: j['nameZhHans'] as String? ?? '',
        nameZhHant: j['nameZhHant'] as String? ?? '',
      );
}

/// One person's bar on the chart.
class Lifeline {
  /// Matches an `id` in `assets/family_tree.json`.
  final String personId;
  final String lineId;
  final String scheme;

  final String nameEn;
  final String nameZhHans;
  final String nameZhHant;

  final String? fatherId;

  final int birthAm;

  /// Null when Scripture gives no death year. Drawn open-ended rather
  /// than guessed. (Empty today; the field exists so a later pass can
  /// add Ham, Japheth, Isaac and the rest without a schema change.)
  final int? deathAm;

  final int lifespan;

  /// Verse citations for BOTH ends of the bar. Never empty — every year
  /// on this chart has to be traceable, and
  /// `test/bible_chronology_test.dart` enforces it.
  final List<String> refs;

  /// The arithmetic in one sentence, per locale, so a reader can check
  /// the number instead of trusting it.
  final String derivationEn;
  final String derivationZhHans;
  final String derivationZhHant;

  /// Optional caveat shown under the derivation.
  final String noteEn;
  final String noteZhHans;
  final String noteZhHant;

  const Lifeline({
    required this.personId,
    required this.lineId,
    required this.scheme,
    required this.nameEn,
    required this.nameZhHans,
    required this.nameZhHant,
    required this.fatherId,
    required this.birthAm,
    required this.deathAm,
    required this.lifespan,
    required this.refs,
    required this.derivationEn,
    required this.derivationZhHans,
    required this.derivationZhHant,
    this.noteEn = '',
    this.noteZhHans = '',
    this.noteZhHant = '',
  });

  String localizedName(String locale) =>
      _pick(locale, nameEn, nameZhHans, nameZhHant);
  String localizedDerivation(String locale) =>
      _pick(locale, derivationEn, derivationZhHans, derivationZhHant);
  String localizedNote(String locale) =>
      _pick(locale, noteEn, noteZhHans, noteZhHant);

  /// End of the bar for layout purposes when the death year is unknown.
  int endAm(int spanEndAm) => deathAm ?? spanEndAm;

  bool aliveAt(int am) =>
      am >= birthAm && (deathAm == null || am <= deathAm!);

  factory Lifeline.fromJson(Map<String, dynamic> j) => Lifeline(
        personId: j['personId'] as String,
        lineId: j['lineId'] as String? ?? '',
        scheme: j['scheme'] as String? ?? '',
        nameEn: j['nameEn'] as String? ?? '',
        nameZhHans: j['nameZhHans'] as String? ?? '',
        nameZhHant: j['nameZhHant'] as String? ?? '',
        fatherId: j['fatherId'] as String?,
        birthAm: (j['birthAm'] as num).toInt(),
        deathAm: (j['deathAm'] as num?)?.toInt(),
        lifespan: (j['lifespan'] as num?)?.toInt() ?? 0,
        refs: (j['refs'] as List?)?.cast<String>() ?? const [],
        derivationEn: j['derivationEn'] as String? ?? '',
        derivationZhHans: j['derivationZhHans'] as String? ?? '',
        derivationZhHant: j['derivationZhHant'] as String? ?? '',
        noteEn: j['noteEn'] as String? ?? '',
        noteZhHans: j['noteZhHans'] as String? ?? '',
        noteZhHant: j['noteZhHant'] as String? ?? '',
      );
}

/// How a tick got its position on the AM axis. The distinction the
/// chart is not allowed to blur: a [computed] year is the sum of ages
/// Genesis 5 and 11 state, a [placed] one is a scholar's placement
/// converted through the anchor.
enum AmBasis { computed, placed }

/// One era band — background orientation across 4,100 years, taken from
/// the eras `assets/bible_timeline.json` already carries so the two
/// views of the page band the same centuries the same colour.
///
/// A band runs from its era's first dated thing to the next era's, so
/// the bands tile the axis. Two eras genuinely overlap in the sources
/// (Moses dies and Jordan is crossed in the same year), which is why a
/// band is an orientation device and the precise claim is the tick.
class ChronologyEra {
  final String id;
  final int startAm;
  final int endAm;
  final String colorHex;
  final String nameEn;
  final String nameZhHans;
  final String nameZhHant;

  const ChronologyEra({
    required this.id,
    required this.startAm,
    required this.endAm,
    required this.colorHex,
    required this.nameEn,
    required this.nameZhHans,
    required this.nameZhHant,
  });

  String localizedName(String locale) =>
      _pick(locale, nameEn, nameZhHans, nameZhHant);

  int get colorValue => _hexToArgb(colorHex);

  factory ChronologyEra.fromJson(Map<String, dynamic> j) => ChronologyEra(
        id: j['id'] as String,
        startAm: (j['startAm'] as num).toInt(),
        endAm: (j['endAm'] as num).toInt(),
        colorHex: j['colorHex'] as String? ?? '#555555',
        nameEn: j['nameEn'] as String? ?? '',
        nameZhHans: j['nameZhHans'] as String? ?? '',
        nameZhHant: j['nameZhHant'] as String? ?? '',
      );
}

/// A dated event drawn as a tick on the chart. Used for BOTH layers —
/// the computed markers and the placed events — because they differ in
/// exactly one load-bearing way, [amBasis], and giving them one type
/// makes it impossible to render one while forgetting the other.
class ChronologyMarker {
  final String id;
  final int am;

  /// Which era band this tick belongs to. Its own era, not the band it
  /// happens to land in — the two can differ where eras overlap.
  final String era;

  /// [AmBasis.computed] for the seven Genesis 5/11 anchors,
  /// [AmBasis.placed] for everything from `bible_timeline.json`.
  final AmBasis amBasis;

  /// Whether this tick gets a "Jump to" chip and a printed label.
  final bool pin;

  /// Signed BC/AD year as the source states it. Null on a computed
  /// marker, whose statement is the AM figure — the BC year is derived
  /// from the anchor, not asserted.
  final int? year;

  /// Where `bible_timeline.json` puts the same event, when it carries
  /// it too, and by how many years the two differ. Shown in the detail
  /// sheet so a deduped disagreement is never silent.
  final int? placedYear;
  final int? placedDeltaYears;

  final List<String> refs;
  final String titleEn;
  final String titleZhHans;
  final String titleZhHant;

  const ChronologyMarker({
    required this.id,
    required this.am,
    required this.refs,
    required this.titleEn,
    required this.titleZhHans,
    required this.titleZhHant,
    this.era = '',
    this.amBasis = AmBasis.computed,
    this.pin = true,
    this.year,
    this.placedYear,
    this.placedDeltaYears,
  });

  bool get isComputed => amBasis == AmBasis.computed;

  String localizedTitle(String locale) =>
      _pick(locale, titleEn, titleZhHans, titleZhHant);

  factory ChronologyMarker.fromJson(Map<String, dynamic> j) =>
      ChronologyMarker(
        id: j['id'] as String,
        am: (j['am'] as num).toInt(),
        era: j['era'] as String? ?? '',
        amBasis: (j['amBasis'] as String? ?? 'computed') == 'placed'
            ? AmBasis.placed
            : AmBasis.computed,
        pin: j['pin'] as bool? ?? true,
        year: (j['year'] as num?)?.toInt(),
        placedYear: (j['placedYear'] as num?)?.toInt(),
        placedDeltaYears: (j['placedDeltaYears'] as num?)?.toInt(),
        refs: (j['refs'] as List?)?.cast<String>() ?? const [],
        titleEn: j['titleEn'] as String? ?? '',
        titleZhHans: j['titleZhHans'] as String? ?? '',
        titleZhHant: j['titleZhHant'] as String? ?? '',
      );
}

/// The stretch where the computed count and the placed events overlap
/// and provably disagree — the ~170-year late-date clash across the
/// patriarchs. Carried as data so the chart can draw it; see the
/// generator for the ordering test that defines it.
class ChronologyContested {
  final int startAm;
  final int endAm;
  final int eventCount;
  final Map<String, String> note;

  const ChronologyContested({
    required this.startAm,
    required this.endAm,
    required this.eventCount,
    required this.note,
  });

  String localizedNote(String locale) => _localeMap(note, locale);

  factory ChronologyContested.fromJson(Map<String, dynamic> j) =>
      ChronologyContested(
        startAm: (j['startAm'] as num).toInt(),
        endAm: (j['endAm'] as num).toInt(),
        eventCount: (j['eventCount'] as num?)?.toInt() ?? 0,
        note: ((j['note'] as Map?) ?? const {}).map<String, String>(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );
}

/// The whole parsed asset.
class ChronologyData {
  final String defaultScheme;
  final int spanStartAm;
  final int spanEndAm;

  /// Last year the Genesis 5/11 arithmetic reaches. Left of it the
  /// chart has lifelines; right of it only placed events. Read off the
  /// bars by the generator rather than assumed to be Abraham's death —
  /// Eber outlives him on the Masoretic count.
  final int computedEndAm;

  final List<ChronologyScheme> schemes;
  final List<ChronologyLine> lines;
  final List<ChronologyEra> eras;
  final List<Lifeline> lifelines;

  /// The computed layer: seven anchors whose year is the sum of stated
  /// ages.
  final List<ChronologyMarker> markers;

  /// The placed layer: `bible_timeline.json`'s events on the AM axis.
  final List<ChronologyMarker> events;

  final ChronologyContested? contested;

  /// Trilingual sentence naming the descent lines this chart does NOT
  /// draw, and why. Shown in the legend, not hidden in a tooltip.
  final Map<String, String> undrawnLines;

  /// Trilingual explanation of the computed/placed boundary. Shown on
  /// the chart, not in a tooltip.
  final Map<String, String> computedNote;

  const ChronologyData({
    required this.defaultScheme,
    required this.spanStartAm,
    required this.spanEndAm,
    required this.computedEndAm,
    required this.schemes,
    required this.lines,
    required this.eras,
    required this.lifelines,
    required this.markers,
    required this.events,
    required this.contested,
    required this.undrawnLines,
    required this.computedNote,
  });

  /// Both layers in one axis-ordered list — what the tick lane draws.
  List<ChronologyMarker> get allTicks {
    final all = [...markers, ...events]..sort((a, b) {
        final c = a.am.compareTo(b.am);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return all;
  }

  ChronologyEra? eraById(String id) {
    for (final e in eras) {
      if (e.id == id) return e;
    }
    return null;
  }

  String localizedComputedNote(String locale) =>
      _localeMap(computedNote, locale);

  ChronologyScheme get activeScheme => schemes.firstWhere(
        (s) => s.id == defaultScheme,
        orElse: () => schemes.first,
      );

  ChronologyLine? lineById(String id) {
    for (final l in lines) {
      if (l.id == id) return l;
    }
    return null;
  }

  String localizedUndrawn(String locale) => _localeMap(undrawnLines, locale);

  /// Everyone alive in [am], in chart order.
  List<Lifeline> aliveAt(int am) =>
      lifelines.where((l) => l.aliveAt(am)).toList();

  factory ChronologyData.fromJson(Map<String, dynamic> j) {
    final meta = (j['_meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lifelines = ((j['lifelines'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Lifeline.fromJson)
        .toList()
      ..sort((a, b) => a.birthAm.compareTo(b.birthAm));
    final markers = ((j['markers'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChronologyMarker.fromJson)
        .toList()
      ..sort((a, b) => a.am.compareTo(b.am));
    final events = ((j['events'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChronologyMarker.fromJson)
        .toList()
      ..sort((a, b) => a.am.compareTo(b.am));
    final spanEnd = (meta['spanEndAm'] as num?)?.toInt() ?? 0;
    final contested = (j['contested'] as Map?)?.cast<String, dynamic>();
    return ChronologyData(
      defaultScheme: meta['defaultScheme'] as String? ?? '',
      spanStartAm: (meta['spanStartAm'] as num?)?.toInt() ?? 0,
      spanEndAm: spanEnd,
      // Older builds of the asset had no computed/placed split: the
      // whole span was computed, so falling back to the span end keeps
      // them rendering honestly rather than marking everything placed.
      computedEndAm: (meta['computedEndAm'] as num?)?.toInt() ?? spanEnd,
      schemes: ((j['schemes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyScheme.fromJson)
          .toList(),
      lines: ((j['lines'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyLine.fromJson)
          .toList(),
      eras: ((j['eras'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyEra.fromJson)
          .toList()
        ..sort((a, b) => a.startAm.compareTo(b.startAm)),
      lifelines: lifelines,
      markers: markers,
      events: events,
      contested:
          contested == null ? null : ChronologyContested.fromJson(contested),
      undrawnLines:
          ((meta['undrawnLines'] as Map?) ?? const {}).map<String, String>(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      computedNote:
          ((meta['computedNote'] as Map?) ?? const {}).map<String, String>(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
  }
}

/// `#RRGGBB` → 0xFFRRGGBB, degrading to a neutral grey rather than
/// throwing, so a typo in the asset costs a dull bar, not a blank page.
int _hexToArgb(String colorHex) {
  final hex = colorHex.replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null || hex.length != 6) return 0xFF555555;
  return 0xFF000000 | parsed;
}

String _localeMap(Map<String, String> m, String locale) {
  if (locale == 'zh-Hant') return m['zh-Hant'] ?? m['en'] ?? '';
  if (locale.startsWith('zh')) return m['zh-Hans'] ?? m['en'] ?? '';
  return m['en'] ?? '';
}

String _pick(String locale, String en, String hans, String hant) {
  if (locale == 'zh-Hant' && hant.isNotEmpty) return hant;
  if (locale.startsWith('zh') && hans.isNotEmpty) return hans;
  return en;
}

/// Render an AM year as "AM 1656 · 2348 BC" in the reader's locale.
String formatChronologyYear(
  int am,
  ChronologyScheme scheme,
  String locale,
) {
  final year = scheme.amToYear(am);
  final isZh = locale.startsWith('zh');
  final bc = year < 0
      ? (isZh ? '公元前 ${-year} 年' : '${-year} BC')
      : (isZh ? '公元 $year 年' : 'AD $year');
  if (locale == 'zh-Hant') return '創世紀元 $am · $bc';
  if (isZh) return '创世纪元 $am · $bc';
  return 'AM $am · $bc';
}
