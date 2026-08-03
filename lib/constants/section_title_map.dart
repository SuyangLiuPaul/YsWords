/// Maps each Bible-version code to the section-title set it should
/// render in the reading pane. New title sets can be authored in
/// `assets/section_titles.json` and added here without touching any
/// other code.
///
/// Decisions per the user's plan:
///   • CUV-derived translations (CUVS-YHWH, LJK2) reuse the master
///     CUV title set — the verse layout matches CUV closely so
///     reusing its headings is editorially correct.
///   • All three English versions share a neutral 'english-classic'
///     set — NIV/NASB/ESV headings are copyright protected and not
///     redistributable.
const sectionTitleSetByVersion = <String, String>{
  // English family — neutral classic-style headings.
  'kjv': 'english-classic',
  'leb': 'english-classic',
  'nasb': 'english-classic',
  // 'niv' entry removed in 2026-05 along with the NIV version itself
  // (see lib/constants/bible_versions.dart for the licence rationale).

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
