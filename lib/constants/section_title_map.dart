/// Maps each Bible-version code to the section-title set it should
/// render in the reading pane. New title sets can be authored in
/// `assets/section_titles.json` and added here without touching any
/// other code.
///
/// Decisions per the user's plan:
///   • CUV-derived translations (CUVS-YHWH, LJK2) reuse the master
///     CUV title set — the verse layout matches CUV closely so
///     reusing its headings is editorially correct.
///   • All English versions share a neutral 'english-classic' set —
///     NIV/NASB/ESV headings are copyright protected and not
///     redistributable.
const sectionTitleSetByVersion = <String, String>{
  // English family — neutral classic-style headings.
  'kjv': 'english-classic',
  'leb': 'english-classic',
  'nasb': 'english-classic',
  'csb': 'english-classic',
  // 'niv' entry removed in 2026-05 along with the NIV version itself
  // (see lib/constants/bible_versions.dart for the licence rationale).
  // 2026-09-08, from the 雅伟的话 export. All four take the same
  // classic-style English set, including the Greek New Testament: the
  // headings are the app's own editorial furniture rather than part of
  // any of these texts, they are keyed by English book and chapter, and
  // a reader who has chosen the Greek is not helped by a chapter that
  // silently loses the heading every other version shows.
  //
  // The BSB's own headings are NOT used, and could not be: they live in
  // the source module as `<note>`s, which `import_ydh_texts.py` drops
  // with their text. The CSB module's `<TS>` headings get the same
  // treatment for the same reason — see that script's docstring.
  'bsb-yhwh': 'english-classic',
  'asv-yhwh': 'english-classic',
  'wh': 'english-classic',

  // Yahweh-edition CUV uses the master CUV title set.
  'cuvs-yhwh': 'cuv',
  'cuvs-yhwh-tr': 'cuv-tr',

  // LJK2 (梁家铿译本 第二版) uses CUV titles.
  'biblexg-v2': 'cuv',
  'biblexg-v2-tr': 'cuv-tr',
};

/// When a primary title set has no entry for a given chapter, the
/// service falls back to the corresponding "fallback set" if one is
/// configured here.
const sectionTitleFallbackSet = <String, String>{};

String sectionTitleSetFor(String version) =>
    sectionTitleSetByVersion[version] ?? '';

String? sectionTitleFallbackFor(String setId) =>
    sectionTitleFallbackSet[setId];
