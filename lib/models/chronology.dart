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
  int get colorValue {
    final hex = colorHex.replaceFirst('#', '');
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null || hex.length != 6) return 0xFF555555;
    return 0xFF000000 | parsed;
  }

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

/// A dated event drawn as a tick on the chart's ruler.
class ChronologyMarker {
  final String id;
  final int am;
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
  });

  String localizedTitle(String locale) =>
      _pick(locale, titleEn, titleZhHans, titleZhHant);

  factory ChronologyMarker.fromJson(Map<String, dynamic> j) =>
      ChronologyMarker(
        id: j['id'] as String,
        am: (j['am'] as num).toInt(),
        refs: (j['refs'] as List?)?.cast<String>() ?? const [],
        titleEn: j['titleEn'] as String? ?? '',
        titleZhHans: j['titleZhHans'] as String? ?? '',
        titleZhHant: j['titleZhHant'] as String? ?? '',
      );
}

/// The whole parsed asset.
class ChronologyData {
  final String defaultScheme;
  final int spanStartAm;
  final int spanEndAm;
  final List<ChronologyScheme> schemes;
  final List<ChronologyLine> lines;
  final List<Lifeline> lifelines;
  final List<ChronologyMarker> markers;

  /// Trilingual sentence naming the descent lines this chart does NOT
  /// draw, and why. Shown in the legend, not hidden in a tooltip.
  final Map<String, String> undrawnLines;

  const ChronologyData({
    required this.defaultScheme,
    required this.spanStartAm,
    required this.spanEndAm,
    required this.schemes,
    required this.lines,
    required this.lifelines,
    required this.markers,
    required this.undrawnLines,
  });

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

  String localizedUndrawn(String locale) {
    if (locale == 'zh-Hant') {
      return undrawnLines['zh-Hant'] ?? undrawnLines['en'] ?? '';
    }
    if (locale.startsWith('zh')) {
      return undrawnLines['zh-Hans'] ?? undrawnLines['en'] ?? '';
    }
    return undrawnLines['en'] ?? '';
  }

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
    return ChronologyData(
      defaultScheme: meta['defaultScheme'] as String? ?? '',
      spanStartAm: (meta['spanStartAm'] as num?)?.toInt() ?? 0,
      spanEndAm: (meta['spanEndAm'] as num?)?.toInt() ?? 0,
      schemes: ((j['schemes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyScheme.fromJson)
          .toList(),
      lines: ((j['lines'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyLine.fromJson)
          .toList(),
      lifelines: lifelines,
      markers: markers,
      undrawnLines:
          ((meta['undrawnLines'] as Map?) ?? const {}).map<String, String>(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
  }
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
