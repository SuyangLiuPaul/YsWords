// Native half of `song_file_saver.dart`. See that file's doc for the
// per-platform destinations and why each one.

import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'song_file_saver.dart' show SaveOutcome, SaveSaved, SaveFailed;

bool get songFileSaverSupported => true;

const _downloads = MethodChannel('yswords/downloads');

Future<SaveOutcome> songFileSaverSave(
    {required String url, required String fileName, required String mime}) async {
  try {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
    if (res.statusCode != 200) return SaveFailed('HTTP ${res.statusCode}');
    if (res.bodyBytes.length < 64) return const SaveFailed('empty body');

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Through MediaStore into the public Downloads (API 29+); the
        // temp file is only the hand-over.
        final tmp = File('${(await getTemporaryDirectory()).path}/$fileName');
        await tmp.writeAsBytes(res.bodyBytes, flush: true);
        try {
          final where = await _downloads.invokeMethod<String>('saveToDownloads', {
            'path': tmp.path,
            'name': fileName,
            'mime': mime,
          });
          if (where != null) return SaveSaved(where);
        } on PlatformException catch (e) {
          return SaveFailed('${e.code}: ${e.message}');
        } finally {
          try {
            await tmp.delete();
          } catch (_) {}
        }
        // Older Android: the app's own external files folder, which a
        // file manager can still reach under Android/data.
        final dir = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/$fileName');
        await f.writeAsBytes(res.bodyBytes, flush: true);
        return SaveSaved(f.path);

      case TargetPlatform.iOS:
        // Documents, which Info.plist's UIFileSharingEnabled shows in the
        // Files app as On My iPhone › 雅伟之言.
        final dir = await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/$fileName');
        await f.writeAsBytes(res.bodyBytes, flush: true);
        return const SaveSaved('files-app');

      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        final dir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/$fileName');
        await f.writeAsBytes(res.bodyBytes, flush: true);
        return SaveSaved(f.path);

      case TargetPlatform.fuchsia:
        return const SaveFailed('unsupported platform');
    }
  } catch (e) {
    return SaveFailed('$e');
  }
}
