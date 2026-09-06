/// One sermon record from `assets/sermon_library/index.json`.
///
/// A SEPARATE corpus from `assets/sermons/` (the 429 expository
/// sermons of one preacher that `lib/models/sermon.dart` describes).
/// This one is 940 records fetched from fuyindiantai.org — 福音电台,
/// a radio ministry — carrying 71 distinct `author` values. Where the
/// two corpora hold the same sermon, `SermonLibraryService.load` hides
/// the copy from here; see that method.
///
/// Field names mirror the JSON verbatim. Nothing here repairs,
/// normalises or re-spells anything the fetcher wrote: the fetcher's
/// own `_meta.suspectDateNote` says values it could not accept are
/// "stored verbatim and flagged … nothing is inferred or repaired",
/// and the app has no business being cleverer than the ingest about
/// data it did not fetch.
library;

import 'package:yswords/constants/sermon_credit.dart' show sermonPreacher;

/// Minimum body length, in characters, at which a body is worth
/// opening.
///
/// 843 of the 940 records ship a body file; 841 of those are >= 200
/// characters. The two below the line are stubs (one of them is
/// zero-length). A row that opens onto an empty page is worse than a
/// row that says up front it has no text, so [LibrarySermon.hasText]
/// gates on this rather than on the raw `hasBody` flag.
const int kLibraryMinBodyChars = 200;

/// Who a record with no `author` is credited to.
///
/// Not invented here: `_meta.rightsNote` in the asset says it in so
/// many words — "where `author` is null, or `authorKind` is
/// \"programme\", the credit is to 福音电台". 27 records have no
/// author, and the station itself is separately named as the author of
/// 3 more (one of which is dropped for having nothing to open), so the
/// fold produces one row of 28 rather than a nameless bucket beside a
/// named one that means the same thing.
const String kLibraryFallbackCredit = '福音电台';

/// A speaker's `authorKind` as the fetcher classified it.
///
/// `person` for the 890 records spoken by a named individual, and
/// `programme` for the 23 credited to 奇妙恩典 — which is the name of
/// a radio programme, not of a human being. 27 records carry no
/// author at all and no kind; those are credited to
/// [kLibraryFallbackCredit].
const String kAuthorKindPerson = 'person';
const String kAuthorKindProgramme = 'programme';

class LibrarySermon {
  /// The WordPress post id — an int, and the only stable key. The
  /// `slug` is percent-encoded Chinese and the `refcode` is not
  /// unique across the corpus.
  final int id;

  /// The station's own shelf code ("HC01", "sm09"). Display-only.
  final String refcode;

  /// The title, in Simplified Chinese. Every one of the 940 records
  /// has `language: "zh"`; there are no English titles to fall back
  /// to, which is why this is a plain [String] and not a per-locale
  /// map the way [Sermon.titles] is.
  final String title;

  final String url;
  final String language;

  /// The upstream date string, verbatim. **Do not parse this for
  /// ordering** — use [publishedAt], which refuses the one corrupt
  /// value. See [dateSuspect].
  final String date;

  /// True when the fetcher could not accept the upstream `date`.
  ///
  /// Exactly one record is flagged: id 2967, 约书亚(2), whose date
  /// reads `0214-07-02T11:19:11`. A naive parse puts it in the year
  /// 214 and sorts it a millennium and a half before the rest of the
  /// corpus. [publishedAt] returns null for it, so every date-ordered
  /// view treats it as undated.
  final bool dateSuspect;

  /// The speaker's name as the CMS records it, or null for the 27
  /// records with no author. Simplified Chinese for all but five
  /// (e.g. "Grace Xu", "Daniel Seidenberg 牧师").
  final String? author;

  /// Where the fetcher found [author]: `taxonomy` (889), `legacy_field`
  /// (24) or `none` (27). Kept for debugging; the UI never shows it.
  final String? authorSource;

  /// [kAuthorKindPerson], [kAuthorKindProgramme], or null when there
  /// is no author.
  final String? authorKind;

  final String? series;

  /// The Bible book this sermon expounds, as a Chinese book name
  /// ("马太福音"). Null for 479 of the 940.
  final String? book;

  final List<String> programmes;
  final List<String> audioUrls;
  final List<String> transcriptDocUrls;
  final List<String> mobileTranscriptUrls;
  final List<String> videoUrls;

  final bool hasBody;
  final int bodyChars;

  /// Path of the body file RELATIVE to the library root, as written
  /// by the fetcher: `bodies/2444.txt`. Empty when there is no body.
  final String bodyFile;

  const LibrarySermon({
    required this.id,
    required this.refcode,
    required this.title,
    required this.url,
    required this.language,
    required this.date,
    required this.dateSuspect,
    required this.author,
    required this.authorSource,
    required this.authorKind,
    required this.series,
    required this.book,
    required this.programmes,
    required this.audioUrls,
    required this.transcriptDocUrls,
    required this.mobileTranscriptUrls,
    required this.videoUrls,
    required this.hasBody,
    required this.bodyChars,
    required this.bodyFile,
  });

  static List<String> _strings(Object? v) => v is List
      ? [for (final e in v) if (e != null) e.toString()]
      : const <String>[];

  factory LibrarySermon.fromJson(Map<String, dynamic> j) => LibrarySermon(
        id: (j['id'] as num).toInt(),
        refcode: j['refcode'] as String? ?? '',
        title: (j['title'] as String? ?? '').trim(),
        url: j['url'] as String? ?? '',
        language: j['language'] as String? ?? '',
        date: j['date'] as String? ?? '',
        dateSuspect: j['dateSuspect'] as bool? ?? false,
        author: (j['author'] as String?)?.trim(),
        authorSource: j['authorSource'] as String?,
        authorKind: j['authorKind'] as String?,
        series: j['series'] as String?,
        book: j['book'] as String?,
        programmes: _strings(j['programmes']),
        audioUrls: _strings(j['audioUrls']),
        transcriptDocUrls: _strings(j['transcriptDocUrls']),
        mobileTranscriptUrls: _strings(j['mobileTranscriptUrls']),
        videoUrls: _strings(j['videoUrls']),
        hasBody: j['hasBody'] as bool? ?? false,
        bodyChars: (j['bodyChars'] as num?)?.toInt() ?? 0,
        bodyFile: j['bodyFile'] as String? ?? '',
      );

  /// There is a body long enough to be worth opening. See
  /// [kLibraryMinBodyChars] — 841 of 940.
  bool get hasText =>
      hasBody && bodyFile.isNotEmpty && bodyChars >= kLibraryMinBodyChars;

  /// There is at least one resolved recording — 673 of 940.
  bool get hasAudio => audioUrls.isNotEmpty;

  /// The publication date, or **null when it must be treated as
  /// undated**.
  ///
  /// Three ways to get null, and all three are deliberate:
  ///
  ///   1. [dateSuspect] — the fetcher already refused this value.
  ///   2. it does not parse.
  ///   3. the year is before 1980, which is the same guard the fetcher
  ///      applies. It is duplicated here on purpose: the flag and the
  ///      value are two independent locks on the same trap, so a
  ///      re-ingest that shipped `0214-…` *without* the flag still
  ///      could not put 约书亚(2) at the top of a date-sorted list.
  ///      `test/sermon_library_service_test.dart` breaks each lock
  ///      separately to prove neither one is carrying the other.
  ///
  /// Note this is the WordPress PUBLICATION date, not the date the
  /// sermon was preached. The UI must not call it a preaching date.
  DateTime? get publishedAt {
    if (dateSuspect) return null;
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return null;
    if (parsed.year < 1980) return null;
    return parsed;
  }

  /// "2020-06-01", or "—" when [publishedAt] is null.
  ///
  /// Deliberately ISO rather than the "8 Apr 1979" of [Sermon] — the
  /// month names there are English, and this corpus has no English
  /// surface to put them on.
  String get displayDate {
    final d = publishedAt;
    if (d == null) return '—';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Who this sermon is credited to on screen — the `author`, or
  /// [kLibraryFallbackCredit] for the 27 records that have none. See
  /// that constant: the fallback is the asset's own instruction, not
  /// this app's guess about who preached.
  String get credit => author ?? kLibraryFallbackCredit;

  /// This record has something a reader can actually open — text, a
  /// recording, or both.
  ///
  /// False for exactly 3 of the 940: one with no body and no audio,
  /// and two whose bodies are 60 and 63 characters. A row that opens
  /// onto nothing is worse than an absent row, so
  /// `SermonLibraryService.load` drops them and every count the UI
  /// shows is a count of rows the reader can act on.
  bool get isOpenable => hasText || hasAudio;

  /// Case-insensitive substring match over the fields a reader could
  /// plausibly be searching for. The body is NOT searched — it is not
  /// loaded until the sermon is opened.
  bool matchesQuery(String lowercaseQuery) {
    if (lowercaseQuery.isEmpty) return true;
    if (title.toLowerCase().contains(lowercaseQuery)) return true;
    if (refcode.toLowerCase().contains(lowercaseQuery)) return true;
    if ((series ?? '').toLowerCase().contains(lowercaseQuery)) return true;
    if ((book ?? '').toLowerCase().contains(lowercaseQuery)) return true;
    for (final p in programmes) {
      if (p.toLowerCase().contains(lowercaseQuery)) return true;
    }
    return false;
  }
}

/// One name in the library's index of speakers, with the sermons
/// credited to it.
///
/// **Identity is the raw `author` string and nothing else.** The
/// corpus contains 小珊姊妹 (151 sermons) and 小珊 (1), which are
/// almost certainly one person, and 福音电台 (3) which is also the
/// station's name and the documented credit for the 27 unattributed
/// records. Merging any of those would be this app deciding who
/// somebody is on the strength of a substring. `MatthewMessage` in
/// `sermon_service.dart` already settled this class of question —
/// "a sermon with no confirmed counterpart shows no link rather than
/// a plausible one" — and a merged speaker is a much larger claim
/// than a link. If the church confirms the identities, the fix
/// belongs in the fetcher, where it can be recorded and reviewed.
class LibrarySpeaker {
  /// The credit this bucket carries — an `author` verbatim, or
  /// [kLibraryFallbackCredit] for the records that have none.
  final String name;

  /// [kAuthorKindPerson], [kAuthorKindProgramme] or null.
  final String? kind;

  /// This speaker's sermons, newest first with undated last. See
  /// `SermonLibraryService.load`.
  final List<LibrarySermon> sermons;

  const LibrarySpeaker({
    required this.name,
    required this.kind,
    required this.sermons,
  });

  int get count => sermons.length;

  /// True for 奇妙恩典 only — a programme, not a person. The UI owes
  /// the reader that distinction, because a list headed "speakers"
  /// that silently includes a radio show is a small lie.
  bool get isProgramme => kind == kAuthorKindProgramme;

  /// How many of [sermons] reached this bucket through
  /// [kLibraryFallbackCredit] rather than through a real `author`
  /// field — 27 of the 28 in the 福音电台 row, 0 everywhere else.
  ///
  /// The bucket's own page states this. A reader who is shown 28
  /// sermons under the station's name is owed the fact that 27 of
  /// them are there because nobody was credited, not because the
  /// station preached them.
  int get unattributedCount {
    var n = 0;
    for (final s in sermons) {
      if (s.author == null) n += 1;
    }
    return n;
  }

  /// A stable key for URLs and widget keys: the name verbatim. The
  /// index of a speaker in the sorted list would move whenever the
  /// corpus changed, so position is not usable as a key.
  String get key => name;
}

/// A speaker's name as it should appear in [locale].
///
/// **Almost always the name verbatim, in every locale.** The corpus is
/// Simplified Chinese and there is no Traditional or English edition
/// of any of these names. Converting them at runtime was ruled out on
/// the evidence: the repo's one Simplified-to-Traditional precedent
/// (`test/tw_sermon_orthography_test.dart`) is legitimate because it
/// was calibrated against an existing human Traditional text and then
/// ruled glyph by glyph against the printed 和合本, and no such
/// reference exists here. (That tool's NAME is deliberately not
/// written anywhere in `lib/`:
/// `test/bible_evidence_untranslated_hant_test.dart` asserts no file
/// here mentions it but the one docstring that legitimately does, and
/// that assertion is how a render-time converter gets caught the day
/// somebody adds one.) Roughly sixty of the seventy-one names would
/// convert mechanically; the rest are pen names where picking a glyph
/// means guessing what the name MEANS — 干贝儿 is 乾, 幹 or 干
/// depending on a reading nobody has confirmed — and a table that is
/// right sixty times and a guess eleven times is a guess, because the
/// reader cannot tell which row is which. Romanising for the English
/// locale fails the same way: "Liang Shui" is a plausible name 凉水
/// may not use.
///
/// **The one carve-out is not an exception to that rule.** 198 of
/// these records are by the same man as the app's other sermon corpus,
/// and his name in all three locales is already owner-ruled and
/// shipped in `sermon_credit.dart` — "H.H." and all. Reusing a ruling
/// is not making one, and printing 张熙和牧师 on this page while the
/// Sermons page two taps away prints 張熙和牧師 would be the app
/// disagreeing with itself about one person.
String librarySpeakerDisplayName(String name, String locale) =>
    name == sermonPreacher('zh-Hans') ? sermonPreacher(locale) : name;
