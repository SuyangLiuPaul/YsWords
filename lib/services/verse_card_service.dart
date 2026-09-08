// Rasterising a [VerseCard] to a PNG, and deciding which translations
// are allowed to become one.
//
// The two halves are here together on purpose. The capture is a dozen
// lines and nobody would give it a file of its own; the licensing gate
// is the part that actually needed thinking about, and it belongs next
// to the only code that can produce the artefact it governs.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';

/// The scale factor `toImage` rasterises the card at.
///
/// **3.0, fixed — deliberately not `MediaQuery.devicePixelRatio`.**
///
/// The reflex is to pass the device's own ratio, and it produces the
/// classic failure: the card looks perfect on screen and the file is
/// soft. A 1× desktop browser exports a 360 px image; the same card
/// from a 2× laptop exports 720; from a 3× phone, 1080. All three look
/// right to the person who made them, because each is being judged on
/// the screen it was made for — and the desktop one is visibly mushy
/// the moment it arrives on somebody's phone. It is also the failure a
/// test is least likely to catch on its own: `flutter_test`'s view
/// reports 3.0, so a device-ratio export would have passed a
/// dimensions assertion on CI and shipped soft to every browser.
///
/// 3.0 × [kVerseCardWidth]'s 360 dp is 1080 px, which is what WeChat
/// Moments, Instagram and X all publish at — hitting it exactly means
/// no resampling anywhere in the chain. Every reader gets the same
/// file from the same verse, whatever they made it on.
///
/// Not 4.0: that is a 1440 px PNG for no visible gain at any size
/// these platforms display, at roughly 1.8× the bytes, and they
/// re-encode it down anyway.
const double kVerseCardPixelRatio = 3.0;

/// Translations that may NOT be turned into a shareable image.
///
/// The reasoning is not "an image is riskier than text" in general —
/// for most of the bundled editions it plainly is not, and this app
/// has always let a reader copy a verse to the clipboard and paste it
/// anywhere. It is that for these two the app cannot point at anything
/// that establishes the permission, and an image is a *new artefact*
/// that leaves the app and travels on its own.
///
///   * **`csb`** — the Christian Standard Bible ships under a written
///     grant with named conditions, filed at
///     `docs/permissions/CSB Holman permissions grant 2017-04-04.pdf`
///     and analysed in the README beside it. Read what that grant is:
///     a non-exclusive ebook/app permission, to Raymond Suen
///     personally, for one named work, in one named territory, gratis
///     for as long as the work is distributed free. Pastor Raymond
///     extended it to this site and the owner decided the territory
///     question. None of that is a grant to emit standalone PNG files
///     of CSB text that then circulate with no app, no About page and
///     no way to withdraw them. Nothing on file speaks to that, so the
///     edition is excluded rather than guessed at. If Holman or the
///     licensee says otherwise, deleting the entry here is the whole
///     change.
///   * **`nasb`** — already in [disabledVersions], offered on no
///     platform since 2026-09-04, and listed here anyway so that this
///     set reads as the complete answer to "which editions cannot
///     become an image" rather than requiring the reader to hold two
///     rules at once.
///
/// Everything else bundled is either public domain (`kjv`), licensed
/// for quotation on terms the app already meets and prints (`leb` —
/// see [kLebAttribution], which the card carries in full), or a
/// ministry text this project publishes with permission and already
/// reproduces at will (`cuvs-yhwh`, `biblexg-v2`, and their
/// Traditional editions).
const Set<String> kVerseImageRestrictedVersions = <String>{'csb', 'nasb'};

/// Whether [version] may be rendered as a shareable image.
bool verseImageAllowed(String version) =>
    !kVerseImageRestrictedVersions.contains(version);

/// The credit line the card prints for [version], in [locale], or null
/// when the edition may not be imaged at all.
///
/// Reads the very same `uiStrings` keys the About page's bundled-texts
/// table reads, so the card cannot drift into a paraphrase of a
/// licence. `docs/permissions/README.md` states the rule this follows:
/// anything a reader is shown must match a document on file. A card is
/// something a reader is shown.
///
/// Editions with nothing owed still get a line — the KJV's "Public
/// domain." It costs nine points of muted type and it makes the rule
/// checkable: every offered edition prints its About-page licence, so
/// a future edition added without one fails
/// `test/verse_card_test.dart` instead of shipping a card with a blank
/// footer.
String? verseCardLicence(String version, String locale) {
  const keys = <String, String>{
    'kjv': 'aboutLicensePublicDomain',
    'leb': 'aboutLicenseLeb',
    'cuvs-yhwh': 'aboutLicenseCuvsYhwh',
    'cuvs-yhwh-tr': 'aboutLicenseCuvsYhwh',
    'biblexg-v2': 'aboutLicenseLjk',
    'biblexg-v2-tr': 'aboutLicenseLjk',
  };
  if (!verseImageAllowed(version)) return null;
  final key = keys[version];
  if (key == null) return null;
  return uiStrings[key]?[locale] ?? uiStrings[key]?['en'];
}

/// Rasterise the [RepaintBoundary] that [boundaryKey] is attached to.
///
/// Returns null rather than throwing when the boundary is not mounted
/// or has not painted — the caller is a share button, and a share
/// button that throws into the zone handler is the crash class
/// `ClipboardHelper.copyText` already had to be rescued from.
///
/// **A boundary that still needs paint returns null rather than
/// waiting for it.** `toImage` rasterises the LAST PAINTED layer, so
/// capturing before the frame lands yields an assertion in debug and
/// the previous style's pixels in release — a "the picker changed but
/// the export didn't" bug. The obvious fix is to await
/// `SchedulerBinding.instance.endOfFrame` first, and it is a trap:
/// under `flutter_test` no frame runs unless the test pumps one, so
/// that await never completes and the whole suite hangs on this line.
/// (Ten minutes were spent finding that out.)
///
/// So the wait is avoided at the source instead. The caller captures
/// BEFORE it sets its own busy state, which means the card's last
/// painted frame is still current and this branch is not reached. If
/// it ever is, null lands the reader on a retryable "couldn't create
/// the image" rather than on a silently stale picture.
Future<Uint8List?> captureVerseCardPng(
  GlobalKey boundaryKey, {
  double pixelRatio = kVerseCardPixelRatio,
}) async {
  ui.Image? image;
  try {
    final object = boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;
    // `debugNeedsPaint` is assert-only — reading it in a release build
    // throws a LateInitializationError — so it is read the way the
    // framework reads its own debug fields. In release the check
    // simply does not happen, which is the right trade: the worst
    // case there is a stale frame, and the alternative is a crash.
    var needsPaint = false;
    assert(() {
      needsPaint = object.debugNeedsPaint;
      return true;
    }());
    if (needsPaint) return null;
    image = await object.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
  }
}

/// A filename a human can recognise in a Downloads folder.
///
/// Chinese book names are kept — every platform this ships to handles
/// UTF-8 filenames, and `约翰福音-3-16.png` is worth more to a Chinese
/// reader than a transliteration would be. Only the characters that
/// actually break a path are replaced.
String verseCardFileName(String reference) {
  final cleaned = reference
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return '${cleaned.isEmpty ? 'verse' : cleaned}.png';
}
