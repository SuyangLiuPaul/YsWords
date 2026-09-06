/// Who preached the sermons.
///
/// The library is 289 expository sermons by one man, and until now a
/// reader could open any of them and not find out whose they were: the
/// name appeared in exactly three `uiStrings` entries, in three
/// different spellings, none of them on a screen anyone reads.
///
/// So the name lives here, once per language, and every surface
/// composes from it. That is what stops the spellings drifting apart
/// again — `test/sermon_credit_test.dart` fails the build if a second
/// rendering is hardcoded anywhere in `uiStrings`.
///
/// **"H.H." is not decoration.** It is the form the user asked for and
/// the form that distinguishes him from others surnamed Chang. Do not
/// shorten it to "Pastor Eric Chang".
library;

const Map<String, String> _preacherByLocale = {
  'zh-Hans': '张熙和牧师',
  'zh-Hant': '張熙和牧師',
  'en': 'Pastor Eric H.H. Chang',
};

/// The preacher's name in [locale], falling back to English.
String sermonPreacher(String locale) =>
    _preacherByLocale[locale] ?? _preacherByLocale['en']!;

/// How many sermons there are.
///
/// 289, counted from `assets/sermons/index.json`. The app used to claim
/// **587**, which came from summing each sermon's `parts` and then
/// calling the total a number of sermons — it is not even the right sum
/// (that is 889). A number a reader cannot check is exactly the kind of
/// wrong that gets believed, so it is derived here in one place and
/// asserted against the real asset in the test.
// 429 from 2026-09-06: the 289 expository sermons this corpus began
// as, plus 140 of Pastor Eric Chang's messages merged in from the
// 福音电台 library. 141 of his records there were new. 16 of those had
// audio and no transcript; 15 were transcribed and proofread the same
// day and are included here. The 16th, library 6012 (ws01,
// 活着就是基督), is transcribed and deliberately held back: it is the
// same sermon as app CP37, so merging it would ship one sermon twice.
// So the corpus is 429 — 141 minus that one — and not the 430 that
// arithmetic suggests.
const int sermonCount = 429;

/// Substituted into any `uiStrings` entry containing `{name}`.
String withPreacher(String template, String locale) =>
    template.replaceAll('{name}', sermonPreacher(locale));
