/// Who preached the sermons.
///
/// The library is 429 expository sermons by one man, and until now a
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
/// Counted from `assets/sermons/index.json`. The app used to claim
/// **587**, which came from summing each sermon's `parts` and then
/// calling the total a number of sermons — it is not even the right sum
/// (that is 889). A number a reader cannot check is exactly the kind of
/// wrong that gets believed, so it is derived here in one place and
/// asserted against the real asset in the test.
// 429 from 2026-09-06: the 289 expository sermons this corpus began
// as, plus 140 of Pastor Eric Chang's messages merged in from the
// 福音电台 library. 141 of his records there were new. 16 of those had
// audio and no transcript, and all 16 were transcribed.
//
// The 16th, library 6012 (ws01, 活着就是基督), does not add a 430th
// record, and the reason changed on 2026-09-07 without the number
// moving. It was held back at first because it is the same sermon as
// app CP37 and the adjudication row said `refuted`, so merging it would
// have shipped that sermon twice. The row said `refuted` only for want
// of a library body to check the identity against; transcribing 6012
// supplied one, and the pair then measured ABOVE a pair already graded
// `confirmed`. So it is a duplicate after all — and the owner chose
// which text the corpus should carry, since CP37's Chinese is a machine
// translation of the English camp recording and 6012's is a machine
// transcript of the Chinese radio delivery, leaving no rule to decide.
// 6012's text now IS CP37's Chinese body. CP37 keeps its id, its slot
// and its English.
//
// So the corpus is 429 either way: 141 new minus the one that turned
// out to be a sermon already here.
const int sermonCount = 429;

/// Substituted into any `uiStrings` entry containing `{name}`.
String withPreacher(String template, String locale) =>
    template.replaceAll('{name}', sermonPreacher(locale));
