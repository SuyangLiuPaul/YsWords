import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/services/verse_card_export.dart';

/// Keeping the picture, as opposed to handing it to somebody.
///
/// 2026-09-13, owner-reported: 「words share 图片现在为什么不能保存本地
/// 这个要做好」. Two separate things were wrong.
///
/// The first is in `verse_card_export_web.dart` and cannot be exercised
/// from a VM test — it is `navigator.share` — so what is pinned here is
/// the CONTRACT that file has to keep, in the place a reader of this
/// suite will look for it. The share call now carries the file ALONE:
/// iOS treats a share with both a file and text as a text share with an
/// attachment and withholds its image actions, which is exactly "the
/// share sheet has no way to keep the picture".
///
/// The second is that "share" was the only action on offer at all.
void main() {
  test('the web share carries the file and no text beside it', () {
    final src = _read('lib/services/verse_card_export_web.dart');
    // The ShareData that actually goes to the browser.
    expect(src.contains('share(web.ShareData(files: <web.File>[file].toJS))'),
        isTrue,
        reason: 'a `text:` beside the file is what costs iOS its '
            '存储图像 action');
  });

  test('every platform can be asked to save, not only to share', () {
    // The façade's own surface: a reader who wants a copy must not have
    // to find it inside somebody else's share sheet.
    for (final impl in [
      'lib/services/verse_card_export_web.dart',
      'lib/services/verse_card_export_stub.dart',
    ]) {
      expect(_read(impl).contains('saveImage('), isTrue, reason: impl);
    }
    final sheet = _read('lib/widgets/verse_card_sheet.dart');
    expect(sheet.contains('_export(saveOnly: true)'), isTrue,
        reason: 'the sheet needs a control that reaches it');
    expect(sheet.contains('VerseCardExport.canShare'), isTrue,
        reason: 'and only where Share is the primary action, or it '
            'would be the same button twice');
  });

  test('an image that only opened in a tab is not reported as saved', () {
    // The outcome exists and is distinct. iOS Safari ignores `download`
    // on a blob URL; telling the reader "Image downloaded" sends them
    // to look in Files for something that is not there.
    expect(VerseCardDelivery.values, contains(VerseCardDelivery.openedInTab));
    expect(VerseCardDelivery.openedInTab,
        isNot(VerseCardDelivery.downloaded));

    final sheet = _read('lib/widgets/verse_card_sheet.dart');
    expect(sheet.contains('verseCardOpenedInTab'), isTrue,
        reason: 'it needs its own wording');
    // And the sheet must stay open on it: the reader still has to press
    // and hold the picture in the tab that just opened.
    final dismiss = sheet.substring(
        sheet.indexOf('if (outcome == VerseCardDelivery.shared'),
        sheet.indexOf('void _report('));
    expect(dismiss.contains('openedInTab'), isTrue,
        reason: 'named in the dismissal block, as the comment saying '
            'why it is excluded');
    expect(
        dismiss.contains('outcome == VerseCardDelivery.openedInTab'), isFalse,
        reason: 'but never as a reason to close the sheet');
  });
}

String _read(String path) => File(path).readAsStringSync();
