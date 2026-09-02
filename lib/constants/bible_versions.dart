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
  /// version picker can group the ~14 editions under English / 繁體 /
  /// 简体 tabs instead of one long flat list. Values match the app
  /// locale codes: `en`, `zh-Hant`, `zh-Hans`.
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

/// Versions hidden from the picker (currently none — CUV, CNV, and
/// LJK1 were removed outright in 2026-08 rather than hidden; see
/// git history for the rationale). Kept as a mechanism in case a
/// future edition needs to be superseded without breaking old
/// shared links.
const disabledVersions = <String>{};

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
const kWebRestrictedVersions = <String>{'nasb', 'leb'};

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
List<String> get bibleLanguageOrder {
  const order = ['en', 'zh-Hant', 'zh-Hans'];
  final present = availableVersions.map((v) => v.language).toSet();
  return order.where(present.contains).toList();
}

/// The available versions belonging to [language] (`en` / `zh-Hant` /
/// `zh-Hans`), in catalog order.
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
  }
  return null;
}
