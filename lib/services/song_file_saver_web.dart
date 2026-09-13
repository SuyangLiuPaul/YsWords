// Web half of `song_file_saver.dart`: fetch to a blob, click a download
// link. The browser's own Downloads folder and its own progress UI do
// the rest — which is the right answer on the web, where the page has
// no folder of its own to offer.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'song_file_saver.dart' show SaveOutcome, SaveSaved, SaveFailed;

bool get songFileSaverSupported => true;

Future<SaveOutcome> songFileSaverSave(
    {required String url, required String fileName, required String mime}) async {
  try {
    final res = await web.window.fetch(url.toJS).toDart;
    if (!res.ok) return SaveFailed('HTTP ${res.status}');
    final blob = await res.blob().toDart;
    final href = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = href
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.append(a);
    a.click();
    a.remove();
    // Revoked after the click has been dispatched; revoking synchronously
    // can cancel the download in some browsers.
    web.window.setTimeout(
        (() => web.URL.revokeObjectURL(href)).toJS, 10000.toJS);
    return const SaveSaved('browser');
  } catch (e) {
    return SaveFailed('$e');
  }
}
