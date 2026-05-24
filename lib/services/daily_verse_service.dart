import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// Loads a curated list of well-known reference strings and returns
/// one per calendar day. Two devices on the same day see the same
/// verse — selection is `dayOfYear % count`, deterministic and
/// timezone-independent (we use the local calendar day, not UTC,
/// because users think of "today's verse" in their own timezone).
///
/// Round 56 (continued — shuffle): user feedback "for daily verse,
/// can you shuffle? dont need to be the same bible books everyday.
/// should be random". Source list is grouped by book so consecutive
/// days kept landing on the same book (Psalms had 604 entries, with
/// 17 % consecutive same-book pairs across the corpus). We now apply
/// a deterministic Fisher-Yates shuffle with a fixed seed at load
/// time. Same day on every device → same verse (rotation stays
/// stable), but consecutive days are now drawn from book-mixed
/// positions instead of marching through Psalms then Jeremiah etc.
class DailyVerseService {
  static List<String>? _cache;
  static Future<List<String>>? _loading;

  static Future<List<String>> _load() async {
    final raw =
        await rootBundle.loadString('assets/daily_verses.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['verses'] as List).cast<String>().toList();
    // Fixed-seed Fisher-Yates shuffle — same answer on every device,
    // every install, every cold start. Picked seed 20260506 (the date
    // this round of changes shipped) so we have a fixed anchor; if
    // the rotation ever needs to be re-shuffled (e.g. a major v2 of
    // the curated list) bumping this seed gives a fresh order.
    final rng = Random(20260506);
    for (int i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }

  /// Epoch for the rotation: 2026-01-01. The day index used to pick
  /// today's verse is `daysSinceEpoch % list.length`. See [todayRef]
  /// for the why behind this constant.
  static final DateTime _epoch = DateTime(2026, 1, 1);

  /// Returns the canonical English reference (e.g. "John 3:16") for
  /// today, or null if the asset failed to load. Caller is
  /// responsible for parsing + resolving via reference_parser.
  ///
  /// 2026-05-24 (v1.3.2) BUG FIX: previous formula was
  /// `dayOfYear % list.length`. `dayOfYear` is 0-365 and
  /// `list.length` is 3650 → the modulo was always a no-op, only
  /// indices 0-365 ever picked, and every year repeated the same
  /// verse on the same date (2026-05-24 == 2027-05-24 == 2028-05-24…).
  /// The 10-year-no-repeat promise the asset's _meta makes was
  /// never honoured.
  ///
  /// Fix: anchor on a fixed epoch (2026-01-01 = the date the
  /// curated list was finalised) and count days since then. The
  /// modulo against `list.length` (3650) now genuinely rotates
  /// across the whole pool, cycling back after ~10 years exactly
  /// as the corpus intends. Same-day-different-device → same index
  /// (calendar-day boundary, no UTC drift) because we use local
  /// DateTime and `inDays` rounds to whole days.
  ///
  /// Backwards compat: in 2026, `daysSinceEpoch ∈ 0..364` which
  /// happens to equal `dayOfYear`. So users testing on 2026 dates
  /// see the SAME verse as the broken formula — no perceived
  /// regression today, just correct behaviour from 2027 onward.
  static Future<String?> todayRef({DateTime? now}) async {
    _cache ??= await (_loading ??= _load());
    final list = _cache;
    if (list == null || list.isEmpty) return null;
    final n = now ?? DateTime.now();
    // Whole-calendar-day boundary, timezone-independent. Negative
    // dates (before 2026-01-01) are handled by mathematical modulo
    // — if `daysSinceEpoch` is negative we add `list.length` to
    // wrap into [0, list.length).
    final today = DateTime(n.year, n.month, n.day);
    final daysSinceEpoch = today.difference(_epoch).inDays;
    final idx =
        ((daysSinceEpoch % list.length) + list.length) % list.length;
    return list[idx];
  }

  /// 2026-05-24 (v1.3.2): eager pre-load for splash. main.dart calls
  /// this at startup so by the time the LoadingPage queries
  /// `todayRef()` the JSON is already parsed + cached in memory and
  /// the response is synchronous-fast. Eliminates the cold-start
  /// race where the splash's 1.2 s fallback timer would lock to a
  /// random verse if daily_verses.json hadn't loaded yet.
  static Future<void> preload() async {
    if (_cache != null) return;
    await (_loading ??= _load());
  }

  /// Round 56 (continued — Lookup recommended verses): returns the
  /// last [n] days' worth of daily-verse references, newest first.
  /// Each entry is `(date, ref)` so the caller can label chips with
  /// "Today / Yesterday / 2 days ago" without recomputing the
  /// rotation. Year boundaries are handled by the same modular
  /// arithmetic [todayRef] uses, so the rotation doesn't reset on
  /// Jan 1.
  ///
  /// Returns an empty list if the asset failed to load. Always at
  /// most [n] entries; fewer when n exceeds the dataset (would
  /// otherwise repeat).
  static Future<List<DailyVerseEntry>> recentRefs(int n,
      {DateTime? now}) async {
    _cache ??= await (_loading ??= _load());
    final list = _cache;
    if (list == null || list.isEmpty) return const [];
    final base = now ?? DateTime.now();
    final cap = n.clamp(1, list.length);
    final out = <DailyVerseEntry>[];
    // 2026-05-24 (v1.3.2): use the same epoch-anchored rotation as
    // todayRef. Previous formula used `dayOfYear % list.length`
    // which only ever indexed verses 0..365 — see the comment on
    // todayRef for why that was broken.
    for (int back = 0; back < cap; back++) {
      final day = DateTime(base.year, base.month, base.day)
          .subtract(Duration(days: back));
      final daysSinceEpoch = day.difference(_epoch).inDays;
      final idx =
          ((daysSinceEpoch % list.length) + list.length) % list.length;
      out.add(DailyVerseEntry(date: day, ref: list[idx]));
    }
    return out;
  }
}

/// One entry in the daily-verse history surfaced by
/// [DailyVerseService.recentRefs]. Date is the local-calendar day
/// the rotation pegged the reference to (today, today-1, …); ref
/// is the canonical English reference.
class DailyVerseEntry {
  final DateTime date;
  final String ref;
  const DailyVerseEntry({required this.date, required this.ref});
}

/// Round 56 (continued — themes): user feedback "for recommended
/// verse, no need to mention today yesterday etc. but show the
/// theme of the verse somehow". 3 650 daily-verse entries are too
/// many to author per-verse themes for, so this is a layered
/// classifier:
///   1) per-(book, chapter) overrides for a handful of famous
///      passages (Genesis 1, Psalm 23, Isaiah 53, John 3, Romans 8,
///      1 Cor 13, …). Chapter-level granularity catches
///      'Romans 8:28' as 'Providence' rather than the generic
///      'Salvation' for the rest of Romans.
///   2) book-level fallback covering all 66 books with a
///      one-phrase topical label (Genesis → Beginnings,
///      Psalms → Worship, Proverbs → Wisdom, John → Life,
///      Revelation → Final Hope, etc.).
///
/// Returns a uiStrings KEY (not a localized string) so the caller
/// can resolve via the user's locale.
String themeKeyFor(String englishBook, int chapter) {
  // Famous-chapter overrides first.
  final pair = '$englishBook|$chapter';
  final override = _chapterOverrides[pair];
  if (override != null) return override;
  // Book-level fallback.
  return _bookThemes[englishBook] ?? 'verseThemeGeneral';
}

const Map<String, String> _chapterOverrides = {
  'Genesis|1': 'verseThemeCreation',
  'Genesis|2': 'verseThemeCreation',
  'Genesis|3': 'verseThemeFall',
  'Exodus|3': 'verseThemeCalling',
  'Exodus|14': 'verseThemeDeliverance',
  'Exodus|20': 'verseThemeCommandments',
  'Deuteronomy|6': 'verseThemeShema',
  'Joshua|1': 'verseThemeCourage',
  'Ruth|1': 'verseThemeLoyalty',
  '1 Samuel|17': 'verseThemeFaith',
  'Psalms|1': 'verseThemeBlessing',
  'Psalms|19': 'verseThemeRevelation',
  'Psalms|22': 'verseThemeServant',
  'Psalms|23': 'verseThemeShepherd',
  'Psalms|46': 'verseThemeRefuge',
  'Psalms|51': 'verseThemeRepentance',
  'Psalms|91': 'verseThemeRefuge',
  'Psalms|119': 'verseThemeWord',
  'Psalms|139': 'verseThemeKnown',
  'Psalms|150': 'verseThemePraise',
  'Proverbs|3': 'verseThemeTrust',
  'Ecclesiastes|3': 'verseThemeTime',
  'Isaiah|9': 'verseThemeMessianic',
  'Isaiah|40': 'verseThemeComfort',
  'Isaiah|53': 'verseThemeServant',
  'Isaiah|55': 'verseThemeInvitation',
  'Jeremiah|29': 'verseThemeHope',
  'Jeremiah|31': 'verseThemeNewCovenant',
  'Daniel|3': 'verseThemeFaithfulness',
  'Daniel|6': 'verseThemeFaithfulness',
  'Matthew|5': 'verseThemeBeatitudes',
  'Matthew|6': 'verseThemePrayer',
  'Matthew|7': 'verseThemeNarrowWay',
  'Matthew|28': 'verseThemeCommission',
  'Mark|10': 'verseThemeServant',
  'Luke|15': 'verseThemeReturning',
  'Luke|24': 'verseThemeResurrection',
  'John|1': 'verseThemeWordIncarnate',
  'John|3': 'verseThemeBornAgain',
  'John|10': 'verseThemeShepherd',
  'John|14': 'verseThemeWayTruthLife',
  'John|15': 'verseThemeAbiding',
  'John|17': 'verseThemeUnity',
  'Acts|1': 'verseThemeMission',
  'Acts|2': 'verseThemePentecost',
  'Romans|3': 'verseThemeSalvation',
  'Romans|5': 'verseThemeReconciliation',
  'Romans|8': 'verseThemeAssurance',
  'Romans|12': 'verseThemeLivingSacrifice',
  '1 Corinthians|13': 'verseThemeLove',
  '1 Corinthians|15': 'verseThemeResurrection',
  'Galatians|5': 'verseThemeSpiritFruit',
  'Ephesians|2': 'verseThemeGrace',
  'Ephesians|6': 'verseThemeArmor',
  'Philippians|2': 'verseThemeHumility',
  'Philippians|4': 'verseThemePeace',
  'Colossians|3': 'verseThemeNewSelf',
  '1 Timothy|6': 'verseThemeContentment',
  '2 Timothy|3': 'verseThemeScripture',
  'Hebrews|11': 'verseThemeFaith',
  'Hebrews|12': 'verseThemeRunning',
  'James|1': 'verseThemeTrials',
  '1 Peter|2': 'verseThemeChosen',
  '1 John|4': 'verseThemeLove',
  'Revelation|21': 'verseThemeNewCreation',
  'Revelation|22': 'verseThemeReturn',
};

const Map<String, String> _bookThemes = {
  // OT — narrative + law + wisdom + prophets.
  'Genesis': 'verseThemeBeginnings',
  'Exodus': 'verseThemeDeliverance',
  'Leviticus': 'verseThemeHoliness',
  'Numbers': 'verseThemeWilderness',
  'Deuteronomy': 'verseThemeCovenant',
  'Joshua': 'verseThemeConquest',
  'Judges': 'verseThemeJudges',
  'Ruth': 'verseThemeLoyalty',
  '1 Samuel': 'verseThemeKingdom',
  '2 Samuel': 'verseThemeKingdom',
  '1 Kings': 'verseThemeKingdom',
  '2 Kings': 'verseThemeKingdom',
  '1 Chronicles': 'verseThemeChronicle',
  '2 Chronicles': 'verseThemeChronicle',
  'Ezra': 'verseThemeReturn',
  'Nehemiah': 'verseThemeRebuilding',
  'Esther': 'verseThemeProvidence',
  'Job': 'verseThemeSuffering',
  'Psalms': 'verseThemeWorship',
  'Proverbs': 'verseThemeWisdom',
  'Ecclesiastes': 'verseThemeMeaning',
  'Song of Solomon': 'verseThemeLove',
  'Isaiah': 'verseThemeProphecy',
  'Jeremiah': 'verseThemeProphecy',
  'Lamentations': 'verseThemeLament',
  'Ezekiel': 'verseThemeVision',
  'Daniel': 'verseThemeKingdom',
  'Hosea': 'verseThemeFaithfulness',
  'Joel': 'verseThemeProphecy',
  'Amos': 'verseThemeJustice',
  'Obadiah': 'verseThemeProphecy',
  'Jonah': 'verseThemeMercy',
  'Micah': 'verseThemeJustice',
  'Nahum': 'verseThemeProphecy',
  'Habakkuk': 'verseThemeFaith',
  'Zephaniah': 'verseThemeProphecy',
  'Haggai': 'verseThemeRebuilding',
  'Zechariah': 'verseThemeMessianic',
  'Malachi': 'verseThemeProphecy',
  // NT — gospels + history + epistles + apocalypse.
  'Matthew': 'verseThemeKingdom',
  'Mark': 'verseThemeServant',
  'Luke': 'verseThemeMercy',
  'John': 'verseThemeLife',
  'Acts': 'verseThemeMission',
  'Romans': 'verseThemeSalvation',
  '1 Corinthians': 'verseThemeChurch',
  '2 Corinthians': 'verseThemeMinistry',
  'Galatians': 'verseThemeFreedom',
  'Ephesians': 'verseThemeUnity',
  'Philippians': 'verseThemeJoy',
  'Colossians': 'verseThemeChrist',
  '1 Thessalonians': 'verseThemeReturn',
  '2 Thessalonians': 'verseThemeReturn',
  '1 Timothy': 'verseThemePastoral',
  '2 Timothy': 'verseThemePastoral',
  'Titus': 'verseThemePastoral',
  'Philemon': 'verseThemeForgiveness',
  'Hebrews': 'verseThemeFaith',
  'James': 'verseThemeLiving',
  '1 Peter': 'verseThemeSuffering',
  '2 Peter': 'verseThemePromise',
  '1 John': 'verseThemeLove',
  '2 John': 'verseThemeTruth',
  '3 John': 'verseThemeTruth',
  'Jude': 'verseThemeContending',
  'Revelation': 'verseThemeFinalHope',
};
