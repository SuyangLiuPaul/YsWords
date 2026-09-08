class BibleVersionInfo {
  final String value;
  final String shortLabel;
  final String menuLabel;

  /// 2026-08-02 (v1.3.160): fallback label for the top-bar version
  /// pill on narrow screens (< 390 px, same breakpoint the book/
  /// chapter title already uses). Only set for editions whose
  /// [shortLabel] is long enough to visibly truncate inside the pill
  /// at that width (currently just 和合本雅伟版) — everything else
  /// falls back to [shortLabel] itself via [narrowChipLabel].
  final String? narrowLabel;

  /// 2026-06-22: which language family this edition belongs to, so the
  /// version picker can group the editions under English / 繁體 / 简体
  /// tabs instead of one long flat list. Values match the app locale
  /// codes: `en`, `zh-Hant`, `zh-Hans`.
  ///
  /// 2026-09-08: and `el`, which is the first value here that is NOT an
  /// app locale — the interface is not offered in Greek and nothing
  /// suggests it should be. This field names the language of the TEXT;
  /// it only ever looked like a locale code because until now every
  /// edition happened to be in a language the interface also spoke.
  /// [bibleLanguageOrder] and the picker's `_langLabel` are the two
  /// places that have to learn a new value.
  final String language;

  /// Round 56 user feedback: "和合本新译本should mention which year
  /// version". Year / edition info shown in the version-picker
  /// secondary line so the reader knows which published edition the
  /// asset corresponds to (1919 vs 1989 CUV; 1992 vs 2011 CNV; etc.).
  /// Empty string when not applicable / unknown.
  final String editionYear;

  const BibleVersionInfo({
    required this.value,
    required this.shortLabel,
    required this.menuLabel,
    required this.language,
    this.editionYear = '',
    this.narrowLabel,
  });
}

const bibleVersions = <BibleVersionInfo>[
  BibleVersionInfo(
    value: 'kjv',
    shortLabel: 'KJV',
    menuLabel: 'King James Version',
    language: 'en',
    editionYear: '1611 / 1769 revision',
  ),
  BibleVersionInfo(
    value: 'leb',
    shortLabel: 'LEB',
    menuLabel: 'Lexham English Bible',
    language: 'en',
    editionYear: '2012',
  ),
  BibleVersionInfo(
    value: 'nasb',
    shortLabel: 'NASB',
    menuLabel: 'New American Standard Bible',
    language: 'en',
    editionYear: '2020 update',
  ),
  // CSB, added 2026-09-07. Licence, and the two questions that had to
  // be answered before it could ship, are in `docs/permissions/` — the
  // 2017 Holman grant, Pastor Raymond's extension of it to this app,
  // and the owner's decision on worldwide distribution.
  //
  // The text is NOT the module as received. `tools/import_csb.py`
  // restores the divine name in 967 verses where the source had lost
  // CSB's own small-caps LORD and left "Lord" behind — Deuteronomy 6:4
  // among them. `docs/csb-divine-name-restorations.md` lists every one.
  BibleVersionInfo(
    value: 'csb',
    shortLabel: 'CSB',
    menuLabel: 'Christian Standard Bible',
    language: 'en',
    editionYear: '2017',
  ),
  // ====== 2026-09-08: four texts from the 雅伟的话 export ======
  //
  // Built by `tools/import_ydh_texts.py` out of the SQLite that project
  // already exports (`Yahwehdehua/app/build/bible.db`) — a credential-
  // free file, unlike the MariaDB `import_csb.py` reads. The markup
  // mapping, tag by tag, is in that script's docstring.
  //
  // **Two of the six texts in that export are NOT here, and neither
  // omission is an oversight.**
  //
  //   * **Septuagint (`lxxs`) — held for a few hours, then SHIPPED.**
  //     The reflex is "the Septuagint is ancient, so it is public
  //     domain", and it is the wrong reflex: what carries copyright is
  //     the modern critical EDITION.
  //     `Yahwehdehua/PROJECT_STATE.md` records its own survey finding
  //     no source that was at once available, authoritative and clearly
  //     licensed — Rahlfs is claimed by the German Bible Society, CATSS
  //     needs a signed agreement — and the module that ended up in the
  //     database did not settle it: the note recording its arrival says
  //     「授权仍归 Peter 判断」, the licence is still Peter's to judge.
  //     Nothing in a theWord module even names its edition.
  //
  //     It was held on that basis, and the owner then decided
  //     otherwise: 「用 yahwehdehua lxxs 版本吧」, 2026-09-08, said after
  //     he was shown this position AND the alternative — that the
  //     sibling app's `lxxwh` is Eagle's View's electronic edition,
  //     whose grant IS written down. He chose this module knowing that.
  //     It is his call to make; what this repo owes is that the About
  //     row then says only what is known. It does: the row names the
  //     module's provenance and does NOT claim public domain, because
  //     nobody has established that. See `docs/permissions/README.md`.
  //   * **CSB (Yahweh) (`hcsbs`).** It is the `csb` directly above.
  //     Same module, `bsapp_bible_hcsbs`, which `tools/import_csb.py`
  //     already built `assets/csb.json` from: 26,298 of 31,102 verses
  //     byte-identical, 1,633 differing only in whitespace, and the
  //     rest only by that importer's own punctuation and divine-name
  //     repairs. Adding it would ship 6 MB of a licensed text twice —
  //     and the row labelled "(Yahweh)" would be the one with FEWER
  //     occurrences of the name: the raw module reads Yahweh in 5,041
  //     verses and the shipped `csb` in 5,805, Deuteronomy 6:4 among
  //     the difference. `docs/permissions/README.md` carries the
  //     measurement.
  //
  // Both stay buildable — `python3 tools/import_ydh_texts.py lxx` and
  // `... csb-yhwh` — so answering either question is an asset, an entry
  // here and an About-page row, not a fresh investigation.
  // Plain BSB is NOT here, and that is deliberate. It was imported
  // alongside `bsb-yhwh` on 2026-09-08 and removed the same day on the
  // owner's instruction: 「bsbs 不用，就 bsb yahweh 版本导入」 — import
  // the Yahweh edition, not the plain one.
  //
  // The measurement behind that call, so nobody re-litigates it: after
  // the app's render-time LORD → Yahweh rewrite the two texts display
  // identically in all but 636 verses (2.0%) — 299 "Lord GOD" → "Lord
  // Yahweh", 27 "Yah", 310 NT κύριος restorations. Plain BSB was 5.9 MB
  // buying a difference the reader mostly could not see, and it is the
  // same relation the owner settled for `cuvs-plus` in SeekSparks the
  // same day with 「有雅+ 就不用和合本+了」.
  //
  // Not a licensing question — the BSB is public domain outright since
  // 2023-04-30 and was the one text here that needed no grant. It stays
  // buildable: `python3 tools/import_ydh_texts.py bsb`.
  BibleVersionInfo(
    value: 'bsb-yhwh',
    shortLabel: 'BSB (Yahweh)',
    menuLabel: 'Berean Standard Bible (Yahweh)',
    language: 'en',
    editionYear: 'BSB · divine name restored',
    // 'BSB (Yahweh)' is twelve characters in a pill that shares its row
    // with the book-title pill and the trailing icon cluster — see the
    // v1.3.161 note on that chip in `bible_reading_pane.dart`, which
    // gave up on screen-width thresholds precisely because the chip
    // never gets the whole width. `test/version_chip_label_width_test
    // .dart` measures every narrow label against 雅伟版, the widest one
    // the chip was fixed for.
    narrowLabel: 'BSB-Y',
  ),
  BibleVersionInfo(
    value: 'asv-yhwh',
    shortLabel: 'ASV (Yahweh)',
    menuLabel: 'American Standard Version (Yahweh)',
    language: 'en',
    editionYear: '1901 · divine name restored',
    narrowLabel: 'ASV-Y',
  ),
  // The first edition here that is neither English nor Chinese, and the
  // reason [bibleLanguageOrder] grew a fourth entry. It is NT-only, so
  // it also needs a [bibleVersionFullCanonFallback] — see the bottom of
  // this file for which edition it falls back to and why that one.
  BibleVersionInfo(
    value: 'wh',
    shortLabel: 'WH',
    menuLabel: 'Westcott-Hort Greek NT',
    language: 'el',
    editionYear: '1881',
  ),
  // The Greek Old Testament, so `el` now covers both testaments across
  // two rows rather than one NT-only row. OT-only, so it needs a
  // [bibleVersionFullCanonFallback] for the same reason `wh` does.
  //
  // `editionYear` is deliberately NOT a year. Every other row here can
  // name the edition it is; this one cannot, because the module does
  // not say, and inventing "Rahlfs" or "1935" to fill the field would
  // be the app asserting a fact nobody has established — about the one
  // text whose licence turns on exactly which edition it is.
  BibleVersionInfo(
    value: 'lxx',
    shortLabel: 'LXX',
    menuLabel: 'Septuagint (Greek OT)',
    language: 'el',
    editionYear: 'critical edition unnamed by the module',
  ),
  // NIV (New International Version) was previously listed here.
  // Removed in 2026-05 — Biblica / Zondervan retain commercial
  // copyright on the full text and we cannot redistribute the bundled
  // JSON without an explicit publisher licence. Users seeking NIV
  // should follow Bible Gateway / YouVersion. The asset file
  // `assets/niv.json` was also removed in the same change.
  BibleVersionInfo(
    value: 'cuvs-yhwh',
    // 2026-08-02 (v1.3.157): was 'CUVS(简)' — user asked for Chinese
    // versions to show Chinese labels instead of the Latin
    // abbreviation, for both the Simplified and Traditional edition
    // ("中文应该用中文的，繁体也是两个版本").
    // 2026-08-02 (v1.3.159): dropped the "(简)" suffix — user pointed
    // out the simplified/traditional characters themselves already
    // make that obvious ("看字就知道") — and switched to the fuller
    // "和合本雅伟版" name instead of the shortened "雅伟版".
    shortLabel: '和合本雅伟版',
    menuLabel: '和合本雅伟版(简体)',
    language: 'zh-Hans',
    // 2026-08-04: the "基于和合本 1919 / 现代标点 1989" sub-line was dropped at
    // the user's request — the two 雅伟版 rows were the only ones carrying a
    // note in the version picker, which made the list look inconsistent next
    // to the 梁家铿译本 rows (no editionYear). `editionYear` defaults to ''
    // and is only rendered by version_picker_sheet.dart behind an isNotEmpty
    // guard, so omitting it simply hides the line.
    // 2026-08-02 (v1.3.160): "和合本雅伟版" truncates inside the top-bar
    // pill on narrow phones — falls back to the shorter "雅伟版" there.
    narrowLabel: '雅伟版',
  ),
  BibleVersionInfo(
    value: 'cuvs-yhwh-tr',
    shortLabel: '和合本雅偉版',
    // 2026-08-31: was '和合本雅伟版(繁體)' — 伟 is SIMPLIFIED, inside the
    // label whose entire job is to mark the Traditional edition, while
    // the shortLabel one line up already read 雅偉. Found while
    // generating the static /read/ pages, where it would have been
    // printed on 1,256 crawlable Traditional page titles. Fixed at the
    // user's instruction (「繁体那两个名字也一起改了」), and it follows the
    // rule the 2026-05-10 雅威→雅偉 change already set down: this
    // project's canonical simp→trad pairing is 雅伟 → 雅偉.
    menuLabel: '和合本雅偉版(繁體)',
    language: 'zh-Hant',
    // 2026-08-04: sub-line removed — see the 简体 entry above.
    narrowLabel: '雅偉版',
  ),
  // 2026-08-09: these were the only Chinese editions with NO narrowLabel,
  // so the top-bar pill had nothing shorter to fall back to and cut
  // "梁家铿(简)" down to "梁家…" — which names neither the translator nor
  // the script, the two things the label exists to carry. Worse, BOTH rows
  // truncated to the identical "梁家…", so the 简/繁 distinction — the only
  // thing separating them — was exactly what got cut.
  //
  // 梁简 / 梁繁 at the user's request. The 雅伟版 rows above have carried a
  // narrowLabel since v1.3.160 for precisely this reason; this is that fix
  // reaching the two rows it missed. The wide labels are unchanged, because
  // "梁家铿(简)" is the right thing to show when there is room for it.
  BibleVersionInfo(
    value: 'biblexg-v2',
    shortLabel: '梁家铿(简)',
    menuLabel: '梁家铿译本(简体)',
    language: 'zh-Hans',
    narrowLabel: '梁简',
  ),
  // 2026-08-31: both labels below said 梁家铿 — SIMPLIFIED 铿 — on the
  // Traditional row, next to a correctly-Traditional 譯本(繁體). The
  // translator's name was the one part not being converted.
  //
  // Not a judgement call in the end, though it looked like one: a
  // person's name is exactly the kind of thing a project might
  // deliberately leave in one spelling. This project does not. The
  // Traditional About-page line already reads 梁家鏗譯本
  // (ui_strings.dart, key 'zh-Hant'), and every Traditional discussion
  // in test/ writes 梁家鏗. These two labels were the outliers, not the
  // convention. Fixed at the user's instruction; a guard in
  // test/bible_versions_language_test.dart now fails if any zh-Hant
  // label picks up a Simplified character again.
  BibleVersionInfo(
    value: 'biblexg-v2-tr',
    shortLabel: '梁家鏗(繁)',
    menuLabel: '梁家鏗譯本(繁體)',
    language: 'zh-Hant',
    narrowLabel: '梁繁',
  ),
];

/// Versions hidden from the picker on EVERY platform (CUV, CNV, and
/// LJK1 were removed outright in 2026-08 rather than hidden; see git
/// history for the rationale).
///
/// 2026-09-04 — `nasb` joins it, at the owner's instruction. This is the
/// escalation the note on [kWebRestrictedVersions] anticipated two days
/// earlier: that change hid the NASB on web only, "pending the
/// publisher's answer", on the reasoning that bundling inside a native
/// app is a materially weaker act than serving a downloadable file. The
/// owner has now decided not to wait on that answer, so the edition is
/// offered nowhere.
///
/// **Hidden, not removed.** `assets/nasb.json` is still declared in
/// `pubspec.yaml` and still ships inside the native binary; what changes
/// is that nothing links to it. That is deliberate and reversible — the
/// full NIV treatment (entry AND asset deleted) remains the next step if
/// the answer comes back no, and it is the owner's call to take, not
/// something to tidy up on the way past.
///
/// Nothing else needs touching, and that is by design rather than luck:
///   * [resolvableVersion] already coerces a stored or defaulted `nasb`
///     into the nearest available edition of the same language — English
///     lands on the KJV, which is public domain and can never be
///     restricted. Both `MainProvider` defaults already call it (they
///     were changed to on 2026-09-02, for the web strip).
///   * `version_preloader.dart` filters its warm-up queue through
///     [availableVersions], so the NASB drops out of it too.
/// `test/nasb_hidden_test.dart` pins the whole chain.
const disabledVersions = <String>{'nasb'};

/// 2026-09-02: editions we may not redistribute as a fetchable file, and
/// therefore do not ship in the WEB bundle.
///
/// Measured against prod on 2026-09-02, before this change:
///
///     /assets/assets/nasb.json  200  7,215,432   31,090 verses
///     /assets/assets/leb.json   200  8,812,100
///     /assets/assets/kjv.json   200  7,604,330   (public domain — fine)
///
/// Flutter web writes every declared asset into `build/web/assets/assets/`,
/// where anyone can fetch the whole translation as one file. NASB is The
/// Lockman Foundation's and LEB is Logos/Faithlife's; both are licensed for
/// *quotation* (Lockman's gratis policy caps it at 1,000 verses and forbids
/// storing more than that in an electronic retrieval system), not for
/// redistribution of the complete text. **LEB had never been named in any
/// licensing note** — every write-up said NASB alone — which is exactly how
/// it survived the 2026-08-31 prerender exclusion: that one covers `/read/`
/// pages and never touched the asset bundle.
///
/// This hides them on web only, pending the publisher's answer. It is
/// deliberately NOT the NIV treatment (removed outright in 2026-05, entry
/// and asset both) because bundling inside a native app is a materially
/// weaker act than serving a downloadable file, and the request may yet
/// come back yes. If it comes back no, do what NIV got.
///
/// Two halves, and BOTH are needed — this constant alone would leave the
/// files sitting there for anyone who knows the URL:
///   * here, so the picker does not offer an edition whose asset is gone;
///   * `tools/release_web.sh`, which deletes the files out of `build/web`
///     after every `flutter build web`.
/// `test/web_restricted_versions_test.dart` fails if either half goes away.
/// 2026-09-04 — the LEB comes back out of this set, at the owner's
/// instruction, and is served on the web again.
///
/// It went in two days earlier on the reasoning above, but note what that
/// same paragraph already conceded: **the LEB had never been named in any
/// licensing note.** Every write-up, and every earlier exclusion, said
/// NASB alone. It was swept in by caution rather than by anything anyone
/// had actually established about Logos/Faithlife's terms, and the owner
/// has decided not to keep an edition off the site on that basis.
///
/// The concern the strip answers is real and unchanged, so it is worth
/// stating plainly rather than quietly dropping: `flutter build web`
/// writes every declared asset into `build/web/assets/assets/`, so
/// serving the LEB on the web means the complete text is one GET away at
/// a predictable URL (8,812,100 bytes, measured 2026-09-02). There is no
/// middle setting — Flutter web either publishes the asset or does not —
/// short of moving the text behind a server-side API, which is a
/// different piece of work. That trade is the owner's to make and this
/// records that they made it.
///
/// What is left here is the NASB, which is also in [disabledVersions] and
/// so is offered on no platform at all. The set still has a job: it drives
/// the asset strip in `tools/release_web.sh`, and hiding an edition from
/// the picker while still shipping its file for anyone who knows the URL
/// would be theatre.
const kWebRestrictedVersions = <String>{'nasb'};

/// `kIsWeb`, spelled out rather than imported.
///
/// `package:flutter/foundation.dart` would be the obvious import and is the
/// wrong one here: `tools/prerender_bible.dart` imports this file and runs
/// under plain `dart run` inside `release_web.sh`, where foundation.dart's
/// transitive `dart:ui` does not exist. This is the same one-line
/// definition foundation.dart itself uses
/// (`flutter/lib/src/foundation/constants.dart:83`), and it is const, so
/// the whole branch is tree-shaken out of native builds.
const bool _kIsWeb = bool.fromEnvironment('dart.library.js_interop');

/// Versions shown in the picker (excludes disabled ones, and on web the
/// unlicensed ones whose assets are stripped from the bundle).
List<BibleVersionInfo> get availableVersions => bibleVersions
    .where((v) => !disabledVersions.contains(v.value))
    .where((v) => !(_kIsWeb && kWebRestrictedVersions.contains(v.value)))
    .toList();

/// Coerce a version code to one this build can actually load.
///
/// **This is the guard v1.4.193/194 shipped without, and it cost a boot
/// crash on every English-locale web client.** Hiding the restricted
/// editions from the picker was never enough:
///
///   * `restoreState` sets `currentVersion = 'nasb'` for a fresh
///     `locale == 'en'` install, and again in the v1.3.46 migration —
///     neither goes anywhere near the picker;
///   * a returning reader has `nasb` or `leb` in `SharedPreferences`
///     from before the strip.
///
/// Either way boot reached `FetchVerses.execute` → `rootBundle
/// .loadString('assets/nasb.json')` → *Unable to load asset*, and the
/// app never painted. Reported from four sites within ten minutes.
///
/// Falls back inside the same language family — English lands on KJV,
/// which is public domain and can never be restricted — and only leaves
/// the family if that family is somehow empty.
String resolvableVersion(String version) =>
    resolvableVersionFrom(version, availableVersions);

/// The rule behind [resolvableVersion], with the candidate list passed in.
///
/// Split out because `availableVersions` narrows on `_kIsWeb`, which is a
/// compile-time const — false under `flutter test`, so a test on the VM
/// cannot exercise the web behaviour through [resolvableVersion] at all.
/// Every assertion about where an English reader lands when NASB is
/// stripped has to go through this door, and a browser check is not a
/// substitute: the one I ran took the fresh-install branch and never
/// touched this path.
String resolvableVersionFrom(
  String version,
  List<BibleVersionInfo> available,
) {
  if (available.any((v) => v.value == version)) return version;
  final lang = bibleVersionLanguage(version);
  for (final v in available) {
    if (v.language == lang) return v.value;
  }
  return available.isNotEmpty ? available.first.value : version;
}

/// The order languages appear in the version picker's language selector.
/// English first, then Traditional, then Simplified — matches the way
/// the user phrased it ("英语繁体简体"). Only languages that actually have
/// at least one available version are kept (defensive against a future
/// all-disabled language).
///
/// 2026-09-08: `el` joins it, LAST, for the Westcott-Hort Greek NT.
///
/// The alternative considered and rejected was filing the WH under `en`
/// rather than growing the selector. It would have been the smaller
/// change — no fourth pill, no new label string, and the picker's
/// `languages.length > 1` branches all stay as they were. It is also
/// simply untrue: the tab is captioned "English", and the rows under it
/// are English translations a reader chooses between. A Greek New
/// Testament is not one of those, and putting it there would make the
/// tab a lie in order to save a string.
///
/// Last rather than first because it is the specialist's row: the three
/// language tabs above it are for reading, and this one is for checking
/// what was read. Being last also means the ordering the user asked for
/// — 英语繁体简体 — is still the ordering they see.
List<String> get bibleLanguageOrder {
  const order = ['en', 'zh-Hant', 'zh-Hans', 'el'];
  final present = availableVersions.map((v) => v.language).toSet();
  return order.where(present.contains).toList();
}

/// The available versions belonging to [language] (`en` / `zh-Hant` /
/// `zh-Hans` / `el`), in catalog order.
List<BibleVersionInfo> versionsForLanguage(String language) =>
    availableVersions.where((v) => v.language == language).toList();

/// **The withheld editions are not shown at all — not even greyed out.**
///
/// This went through three positions in one sitting, and the third is
/// the one that holds. v1.4.193 hid them silently. Then the picker
/// listed them disabled with a caption, so a reader who had been using
/// one would know where it went — first captioned 「版权申请中」, then cut
/// back to 「网页版暂不提供」 because a public page announcing a pending
/// licence is a public statement that we are using the text without one.
///
/// The user's last word removed the row itself: 「New American Standard
/// Bible 这些也不要写」. Follow the same reasoning one step further and it
/// is right — naming a translation we cannot serve advertises it, and a
/// greyed-out row is still the app telling every visitor that the NASB
/// is something we have and are not giving them. There is nothing a
/// reader can do with that. `resolvableVersion` already moves anyone
/// carrying a stale NASB/LEB preference onto KJV without a word, which
/// is the outcome that actually matters.
///
/// If a licence comes back, deleting `kWebRestrictedVersions` restores
/// the editions everywhere with no other change.

/// The language family (`en` / `zh-Hant` / `zh-Hans`) of a version code.
/// Falls back to `zh-Hans` for an unknown code (the app's primary
/// audience) so the picker never lands on an empty tab.
String bibleVersionLanguage(String value) {
  for (final v in bibleVersions) {
    if (v.value == value) return v.language;
  }
  return 'zh-Hans';
}

/// 2026-09-08: the edition's full name — 'Berean Standard Bible
/// (Yahweh)', '和合本雅偉版(繁體)' — for a list where the reader is
/// choosing a text rather than glancing at a gutter tag.
///
/// The complaint this answers was filed against the sibling app on the
/// day the Exegesis picker was asked for: 「BGT BSB 雅简这些别人看简写不
/// 知道什么意思」. A picker whose entire purpose is letting a reader
/// choose a text they recognise cannot label its rows with the
/// abbreviation they said they could not read. Falls back to the code
/// itself for an edition the catalogue does not know, the same as
/// [shortBibleVersionLabel].
String fullBibleVersionLabel(String version) {
  for (final v in bibleVersions) {
    if (v.value == version) return v.menuLabel;
  }
  return version;
}

String shortBibleVersionLabel(String version) {
  return bibleVersions
      .firstWhere(
        (item) => item.value == version,
        orElse: () => BibleVersionInfo(
          value: version,
          shortLabel: version,
          menuLabel: version,
          language: 'zh-Hans',
        ),
      )
      .shortLabel;
}

/// 2026-08-02 (v1.3.160): narrow-screen variant of
/// [shortBibleVersionLabel] — mirrors the book/chapter title's own
/// `screenW < 390` short-name fallback, so the version pill in the
/// reading-pane header never truncates on a phone-width screen. Falls
/// back to [shortBibleVersionLabel] itself for every edition that
/// doesn't define a [BibleVersionInfo.narrowLabel].
String narrowBibleVersionLabel(String version) {
  final info = bibleVersions.firstWhere(
    (item) => item.value == version,
    orElse: () => BibleVersionInfo(
      value: version,
      shortLabel: version,
      menuLabel: version,
      language: 'zh-Hans',
    ),
  );
  return info.narrowLabel ?? info.shortLabel;
}

/// Some bundled versions only ship one Testament — most notably the
/// LJK2 (梁家铿译本) editions are NT-only because the translator's OT
/// work isn't published yet. When the daily-verse lookup hits a book
/// that doesn't exist in those bundles, we fall back to a
/// same-language full-canon bundle instead of showing an empty
/// daily-verse card.
///
/// Returns the version code to fall back to, or null when [version]
/// already has full OT+NT coverage.
String? bibleVersionFullCanonFallback(String version) {
  switch (version) {
    case 'biblexg-v2':    // LJK2 (Simplified Chinese, NT only)
      return 'cuvs-yhwh';      // 和合本雅伟版 (Simplified, full canon)
    case 'biblexg-v2-tr': // LJK2 (Traditional Chinese, NT only)
      return 'cuvs-yhwh-tr';   // 和合本雅伟版 (Traditional, full canon)
    // 2026-09-08: the Westcott-Hort is the first NT-only edition whose
    // own language family has NO full-canon edition to fall back to.
    // The Greek Old Testament that would have been the obvious partner
    // — the Septuagint in the same export — is not shipped, because its
    // licence is unresolved (see the catalogue entry above). So this
    // one leaves its language family, which the two LJK2 rows never
    // have to.
    //
    // BSB rather than the KJV, and that is a deliberate difference from
    // [resolvableVersionFrom], which lands a stranded English reader on
    // the KJV. That function is a SAFETY net — its job is to reach an
    // edition that can never be withdrawn, and the KJV is the oldest
    // thing here. This one is an EDITORIAL choice about which English
    // to show beside a Greek text on the daily-verse card, and there
    // the BSB is the better neighbour: it is a modern translation from
    // the same critical text the WH represents, so the daily verse
    // reads as a companion to the Greek rather than as 1611 English
    // next to 1881 Greek. Both are public domain, so neither can go
    // away.
    //
    // 2026-09-08: this pointed at plain `bsb` for the few hours that
    // edition existed here. It is the same translation — the Yahweh
    // edition differs only in restoring the divine name, which is what
    // this whole app is for — so the reasoning above transfers intact.
    case 'lxx':           // Septuagint (Greek, OT only)
      // The mirror image of `wh` below, and the same partner for the
      // same reason: a reader on the Greek OT who follows a New
      // Testament reference must land somewhere, and BSB (Yahweh) is
      // the modern English this catalogue pairs with Greek.
      return 'bsb-yhwh';
    case 'wh':            // Westcott-Hort (Greek, NT only)
      return 'bsb-yhwh';  // Berean Standard Bible (English, full canon)
  }
  return null;
}
