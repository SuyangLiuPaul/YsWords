/// Maps each Bible-version code to the section-title set it should
/// render in the reading pane. New title sets can be authored in
/// `assets/section_titles.json` and added here without touching any
/// other code.
///
/// Decisions per the user's plan:
///   • CUV-derived translations (CUVS-YHWH, LJK1, LJK2) reuse the
///     master CUV title set — the verse layout matches CUV closely
///     so reusing its headings is editorially correct.
///   • CNV is a different translation philosophy and ideally has its
///     own headings; not yet authored, so we fall through to CUV.
///   • All four English versions share a neutral 'english-classic'
///     set — NIV/NASB/ESV headings are copyright protected and not
///     redistributable.
const sectionTitleSetByVersion = <String, String>{
  // English family — neutral classic-style headings.
  'kjv': 'english-classic',
  'leb': 'english-classic',
  'nasb': 'english-classic',
  // 'niv' entry removed in 2026-05 along with the NIV version itself
  // (see lib/constants/bible_versions.dart for the licence rationale).

  // CUV proper — the master Chinese set.
  'cuv': 'cuv',
  'cuv-tr': 'cuv-tr',

  // Yahweh-edition CUV uses CUV titles.
  'cuvs-yhwh': 'cuv',
  'cuvs-yhwh-tr': 'cuv-tr',

  // LJK1 (梁家铿译本 第一版) uses CUV titles.
  'biblexg': 'cuv',
  'biblexg-tr': 'cuv-tr',

  // LJK2 (梁家铿译本 第二版) uses CUV titles.
  'biblexg-v2': 'cuv',
  'biblexg-v2-tr': 'cuv-tr',

  // CNV (新译本) — its own set when authored, falls back to CUV via
  // the service layer when a chapter has no CNV-specific entry.
  'cnv': 'cnv',
  'cnv-tr': 'cnv-tr',
};

/// When a primary title set has no entry for a given chapter, the
/// service falls back to the corresponding "fallback set" if one is
/// configured here. CNV → CUV is the canonical use of this — until
/// CNV-specific headings are authored, CNV readers see CUV's.
const sectionTitleFallbackSet = <String, String>{
  'cnv': 'cuv',
  'cnv-tr': 'cuv-tr',
};

String sectionTitleSetFor(String version) =>
    sectionTitleSetByVersion[version] ?? '';

String? sectionTitleFallbackFor(String setId) =>
    sectionTitleFallbackSet[setId];
