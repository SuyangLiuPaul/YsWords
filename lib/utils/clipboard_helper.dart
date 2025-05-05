import 'package:flutter/services.dart';

abstract class ClipboardHelper {
  static Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
